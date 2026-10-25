import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/chat_store.dart';
import 'package:zaker_ai/models/batch_chat.dart';

void main() {
  late Directory root;
  late ChatStore store;
  final fixed = DateTime.utc(2026, 10, 25, 8);
  var tick = 0;

  DateTime clock() => fixed.add(Duration(seconds: tick++));

  ChatMessage text(
    String id,
    String body, {
    DateTime? at,
    String? clientKey,
    String author = 'owner-1',
  }) {
    return ChatMessage(
      id: id,
      batchId: 'batch-1',
      channelId: 'main',
      authorUid: author,
      authorName: 'طالب',
      kind: ChatMessageKind.text,
      text: body,
      createdAt: at ?? fixed,
      clientKey: clientKey ?? 'key_$id',
    );
  }

  ChatMessage voice(String id, {int durationMs = 4000}) {
    return ChatMessage(
      id: id,
      batchId: 'batch-1',
      channelId: 'main',
      authorUid: 'owner-1',
      authorName: 'طالب',
      kind: ChatMessageKind.voice,
      voiceFileName: '$id.m4a',
      voiceDurationMs: durationMs,
      createdAt: fixed,
      clientKey: 'key_$id',
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('zaker_chat_');
    store = ChatStore(directory: root, clock: clock);
    tick = 0;
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('returns messages oldest first and pages from the newest end', () async {
    for (var i = 0; i < 35; i++) {
      await store.append(
        text(
          'msg-$i',
          'رسالة $i',
          at: fixed.add(Duration(minutes: i)),
          clientKey: 'clientkey$i',
        ),
      );
    }

    final newest = await store.page();
    expect(newest.messages, hasLength(30));
    expect(newest.hasMore, isTrue);
    expect(newest.messages.first.id, 'msg-5');
    expect(newest.messages.last.id, 'msg-34');

    final older = await store.page(
      before: ChatCursor(
        createdAt: newest.messages.first.createdAt,
        id: newest.messages.first.id,
      ),
    );
    expect(older.messages.map((message) => message.id),
        ['msg-0', 'msg-1', 'msg-2', 'msg-3', 'msg-4']);
    expect(older.hasMore, isFalse);
  });

  test('a repeated client key returns the stored message without duplicating',
      () async {
    final first =
        await store.append(text('msg-1', 'أول', clientKey: 'dupkey_1'));
    final second = await store.append(
      text('msg-2', 'تاني', clientKey: 'dupkey_1'),
    );

    expect(second.id, first.id);
    expect((await store.page()).messages, hasLength(1));
  });

  test('a duplicate id is a conflict', () async {
    await store.append(text('msg-1', 'أول', clientKey: 'clientkey1'));
    expect(
      () => store.append(text('msg-1', 'تاني', clientKey: 'clientkey2')),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.conflict,
        ),
      ),
    );
  });

  test('a reply to a missing message is refused', () async {
    final reply = ChatMessage(
      id: 'msg-2',
      batchId: 'batch-1',
      channelId: 'main',
      authorUid: 'owner-1',
      authorName: 'طالب',
      kind: ChatMessageKind.text,
      text: 'رد',
      replyToId: 'missing',
      createdAt: fixed,
      clientKey: 'clientkey2',
    );
    expect(
      () => store.append(reply),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.notFound,
        ),
      ),
    );
  });

  test('editing sets text and editedAt, and refuses voice notes', () async {
    await store.append(text('msg-1', 'قبل'));
    final edited = await store.edit('msg-1', 'بعد');
    expect(edited.text, 'بعد');
    expect(edited.editedAt, isNotNull);

    await store.append(voice('msg-2'));
    expect(
      () => store.edit('msg-2', 'نص'),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.validationFailed,
        ),
      ),
    );
  });

  test('deleting clears the content, leaves a tombstone and blocks reactions',
      () async {
    await store.append(text('msg-1', 'سر'));
    await store.append(voice('msg-2'));

    final textTombstone = await store.delete('msg-1');
    expect(textTombstone.isDeleted, isTrue);
    expect(textTombstone.text, isEmpty);
    expect(textTombstone.reactions, isEmpty);

    final voiceTombstone = await store.delete('msg-2');
    expect(voiceTombstone.isDeleted, isTrue);
    expect(voiceTombstone.voiceFileName, isEmpty);
    expect(voiceTombstone.voiceDurationMs, isNull);

    expect(
      () => store.react('msg-1', '👍', 'owner-1', true),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.notFound,
        ),
      ),
    );
    expect(
      () => store.setPinned('msg-1', true),
      throwsA(isA<BatchFailure>()),
    );
  });

  test('a reaction is deduplicated per uid and can be removed', () async {
    await store.append(text('msg-1', 'مرحبا'));

    var updated = await store.react('msg-1', '👍', 'member-1', true);
    updated = await store.react('msg-1', '👍', 'member-1', true);
    expect(updated.reactions['👍'], {'member-1'});

    updated = await store.react('msg-1', '👍', 'member-2', true);
    expect(updated.reactions['👍'], {'member-1', 'member-2'});

    updated = await store.react('msg-1', '👍', 'member-1', false);
    expect(updated.reactions['👍'], {'member-2'});

    updated = await store.react('msg-1', '👍', 'member-2', false);
    expect(updated.reactions.containsKey('👍'), isFalse);
  });

  test('refuses emoji outside the palette', () async {
    await store.append(text('msg-1', 'مرحبا'));
    expect(
      () => store.react('msg-1', '🔥', 'owner-1', true),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.validationFailed,
        ),
      ),
    );
  });

  test('pins and unpins without touching the text', () async {
    await store.append(text('msg-1', 'مهم'));
    final pinned = await store.setPinned('msg-1', true);
    expect(pinned.pinned, isTrue);
    expect(pinned.text, 'مهم');
    final unpinned = await store.setPinned('msg-1', false);
    expect(unpinned.pinned, isFalse);
  });

  test('refuses text over the limit and control characters', () async {
    expect(
      () => store.append(
        text('msg-1', 'ا' * (ChatStore.maxTextChars + 1)),
      ),
      throwsA(isA<BatchFailure>()),
    );
    expect(
      () => store.append(text('msg-2', 'نص\u0000فاسد')),
      throwsA(isA<BatchFailure>()),
    );
  });

  test('a corrupt chat document throws instead of being overwritten', () async {
    final chatDir = Directory('${root.path}/chat')..createSync();
    File('${chatDir.path}/main.json').writeAsStringSync('{oops');

    expect(
      () => store.append(text('msg-1', 'جديد')),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.corruptStore,
        ),
      ),
    );
    final raw = File('${chatDir.path}/main.json').readAsStringSync();
    expect(raw, '{oops');
    expect(() => jsonDecode(raw), throwsFormatException);
  });
}
