import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_access.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/chat_store.dart';
import 'package:zaker_ai/core/batches/local_batch_repository.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_chat.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late Directory root;
  late BatchFileStore files;
  late LocalBatchRepository repository;
  final fixed = DateTime.utc(2026, 10, 25, 8);
  const ownerUid = 'owner-1';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_chat_repo_');
    files = BatchFileStore(root: root);
    repository = LocalBatchRepository(
      files: files,
      store: _MemoryStore(),
      clock: () => fixed,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// Creates a batch as [ownerUid], then writes a copy of its snapshot into
  /// [uid]'s own workspace with the given role, mirroring how a member's
  /// device would hold its local copy.
  Future<String> addMember(String uid, BatchRole role) async {
    final created = await repository.createBatch(
      uid: ownerUid,
      displayName: 'صاحب الدفعة',
      name: 'دفعة اختبار',
      subjects: const [],
    );
    final snapshot = await repository.loadBatch(ownerUid, created.id);
    final copy = snapshot.copyWith(
      members: [
        ...snapshot.members,
        Membership(
          batchId: created.id,
          uid: uid,
          displayName: 'عضو',
          role: role,
          joinedAt: fixed,
        ),
      ],
    );
    await BatchStore(directory: files.batchDir(uid, created.id)).batch.save(
          copy,
        );
    return created.id;
  }

  ChatMessage message(
    String authorUid,
    String batchId, {
    String id = 'msg-1',
    String text = 'رسالة',
    String? clientKey,
  }) {
    return ChatMessage(
      id: id,
      batchId: batchId,
      channelId: 'main',
      authorUid: authorUid,
      authorName: 'عضو',
      kind: ChatMessageKind.text,
      text: text,
      createdAt: fixed,
      clientKey: clientKey ?? 'clientkey1',
    );
  }

  test('a muted member can read but cannot write, react or pin', () async {
    final id = await addMember('member-1', BatchRole.muted);

    expect(await repository.loadChat('member-1', id), isNotNull);
    expect(
      () => repository.sendChatMessage(
        'member-1',
        id,
        message('member-1', id),
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.notAuthorized,
        ),
      ),
    );
    expect(
      () => repository.reactToChatMessage(
        'member-1',
        id,
        'msg-1',
        '👍',
        true,
      ),
      throwsA(isA<BatchFailure>()),
    );
    expect(
      () => repository.pinChatMessage('member-1', id, 'msg-1', true),
      throwsA(isA<BatchFailure>()),
    );
  });

  test('pending and removed roles cannot open the chat', () async {
    final pendingId = await addMember('pending-1', BatchRole.pending);
    final removedId = await addMember('removed-1', BatchRole.removed);

    expect(
      () => repository.loadChat('pending-1', pendingId),
      throwsA(isA<BatchFailure>()),
    );
    expect(
      () => repository.loadChat('removed-1', removedId),
      throwsA(isA<BatchFailure>()),
    );
  });

  test(
      'a member sends, edits their own message, but cannot pin or edit '
      'someone else\'s', () async {
    final id = await addMember('member-1', BatchRole.member);

    final sent = await repository.sendChatMessage(
      'member-1',
      id,
      message('member-1', id),
    );
    expect(sent.authorUid, 'member-1');

    final edited = await repository.editChatMessage(
      'member-1',
      id,
      sent.id,
      'نص معدّل',
    );
    expect(edited.text, 'نص معدّل');
    expect(edited.editedAt, isNotNull);

    expect(
      () => repository.pinChatMessage('member-1', id, sent.id, true),
      throwsA(isA<BatchFailure>()),
    );

    // Another author's message in the same local workspace: a plain member
    // may not delete it (only owners and admins hold deleteAnyMessage).
    await ChatStore(directory: files.batchDir('member-1', id)).append(
      message(ownerUid, id, id: 'owner-msg', clientKey: 'clientkey2'),
    );
    expect(
      () => repository.deleteChatMessage('member-1', id, 'owner-msg'),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.notAuthorized,
        ),
      ),
    );
  });

  test('an owner can pin, and deleting a voice note removes its file',
      () async {
    final batch = await repository.createBatch(
      uid: ownerUid,
      displayName: 'صاحب الدفعة',
      name: 'دفعة اختبار',
      subjects: const [],
    );
    final source = File('${root.path}/clip.m4a')
      ..writeAsBytesSync([0, 0, 0, 0]);
    final relativePath = ChatStore.voicePath('msg-voice');
    await files.copyFile(
      uid: ownerUid,
      batchId: batch.id,
      relativePath: relativePath,
      sourcePath: source.path,
    );
    await repository.sendChatMessage(
      ownerUid,
      batch.id,
      ChatMessage(
        id: 'msg-voice',
        batchId: batch.id,
        channelId: 'main',
        authorUid: ownerUid,
        authorName: 'صاحب الدفعة',
        kind: ChatMessageKind.voice,
        voiceFileName: 'msg-voice.m4a',
        voiceDurationMs: 4000,
        createdAt: fixed,
        clientKey: 'clientkey1',
      ),
    );

    final pinned = await repository.pinChatMessage(
      ownerUid,
      batch.id,
      'msg-voice',
      true,
    );
    expect(pinned.pinned, isTrue);

    final deleted = await repository.deleteChatMessage(
      ownerUid,
      batch.id,
      'msg-voice',
    );
    expect(deleted.isDeleted, isTrue);
    expect(
      await files.fileExists(
        uid: ownerUid,
        batchId: batch.id,
        relativePath: relativePath,
      ),
      isFalse,
    );

    final audit = await BatchStore(
      directory: files.batchDir(ownerUid, batch.id),
    ).audit.load();
    final actions = audit.value!.map((entry) => entry.action).toList();
    expect(actions, contains('chatMessagePinned'));
    expect(actions, contains('chatMessageDeleted'));
  });

  test('a voice message without its private file is refused', () async {
    final batch = await repository.createBatch(
      uid: ownerUid,
      displayName: 'صاحب الدفعة',
      name: 'دفعة اختبار',
      subjects: const [],
    );
    expect(
      () => repository.sendChatMessage(
        ownerUid,
        batch.id,
        ChatMessage(
          id: 'msg-voice',
          batchId: batch.id,
          channelId: 'main',
          authorUid: ownerUid,
          authorName: 'صاحب الدفعة',
          kind: ChatMessageKind.voice,
          voiceFileName: 'msg-voice.m4a',
          voiceDurationMs: 4000,
          createdAt: fixed,
          clientKey: 'clientkey1',
        ),
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.missingFile,
        ),
      ),
    );
  });

  test('a member cannot send a message attributed to someone else', () async {
    final id = await addMember('member-1', BatchRole.member);
    expect(
      () => repository.sendChatMessage(
        'member-1',
        id,
        message(ownerUid, id),
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.notAuthorized,
        ),
      ),
    );
  });

  test('the access matrix grants pinning only to owners and admins', () {
    expect(BatchAccess.can(BatchRole.owner, BatchAction.pinMessage), isTrue);
    expect(BatchAccess.can(BatchRole.admin, BatchAction.pinMessage), isTrue);
    expect(BatchAccess.can(BatchRole.member, BatchAction.pinMessage), isFalse);
    expect(BatchAccess.can(BatchRole.muted, BatchAction.pinMessage), isFalse);
    expect(BatchAccess.can(BatchRole.muted, BatchAction.viewChat), isTrue);
    expect(BatchAccess.can(BatchRole.muted, BatchAction.sendMessage), isFalse);
  });
}
