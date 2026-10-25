import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/chat_seen_store.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/chat/batch_chat_screen.dart';
import 'package:zaker_ai/features/batches/chat/chat_controller.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_chat.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _ChatRepository implements BatchRepository {
  _ChatRepository(this.messages);

  final List<ChatMessage> messages;

  @override
  Future<ChatPage> loadChat(
    String uid,
    String batchId, {
    ChatCursor? before,
    int limit = 30,
  }) async {
    final eligible = before == null
        ? messages
        : messages
            .where((message) =>
                ChatCursor(createdAt: message.createdAt, id: message.id)
                    .compareTo(before) <
                0)
            .toList();
    final hasMore = eligible.length > limit;
    return ChatPage(
      messages: hasMore ? eligible.sublist(eligible.length - limit) : eligible,
      hasMore: hasMore,
    );
  }

  @override
  Future<ChatMessage> sendChatMessage(
    String uid,
    String batchId,
    ChatMessage message,
  ) async {
    messages.add(message);
    return message;
  }

  @override
  Future<ChatMessage> reactToChatMessage(
    String uid,
    String batchId,
    String messageId,
    String emoji,
    bool reacted,
  ) async {
    final index = messages.indexWhere((message) => message.id == messageId);
    final message = messages[index];
    final byEmoji = {
      for (final entry in message.reactions.entries)
        entry.key: {...entry.value},
    };
    final uids = byEmoji.putIfAbsent(emoji, () => <String>{});
    reacted ? uids.add(uid) : uids.remove(uid);
    if (uids.isEmpty) byEmoji.remove(emoji);
    final updated = message.copyWith(reactions: byEmoji);
    messages[index] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);
  late Directory root;
  late _ChatRepository repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('zaker_chat_screen_');
    repository = _ChatRepository([]);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ChatMessage message(
    String id,
    String text, {
    String authorUid = uid,
    int minutes = 0,
    bool pinned = false,
  }) {
    return ChatMessage(
      id: id,
      batchId: batchId,
      channelId: 'main',
      authorUid: authorUid,
      authorName: authorUid == uid ? 'طالب' : 'زميل',
      kind: ChatMessageKind.text,
      text: text,
      createdAt: fixed.add(Duration(minutes: minutes)),
      pinned: pinned,
      clientKey: 'clientkey$id',
    );
  }

  BatchSnapshot snapshot(BatchRole role) {
    return BatchSnapshot(
      batch: Batch(
        id: batchId,
        name: 'دفعة تالتة ثانوي',
        ownerUid: 'owner-1',
        createdAt: fixed,
        lastActivityAt: fixed,
        settings: const BatchSettings(),
        subjects: const [],
        codeState: InviteCodeState(code: '12345678', createdAt: fixed),
      ),
      members: [
        Membership(
          batchId: batchId,
          uid: uid,
          displayName: 'طالب',
          role: role,
          joinedAt: fixed,
        ),
      ],
    );
  }

  Widget app({BatchRole role = BatchRole.owner}) {
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
        batchDetailProvider.overrideWith((ref, id) async => snapshot(role)),
        chatSeenStoreProvider.overrideWithValue(
          ChatSeenStore(_MemoryStore()),
        ),
        chatControllerProvider.overrideWith(
          (ref, id) => ChatController(
            repository: repository,
            files: BatchFileStore(root: root),
            uid: uid,
            batchId: id,
          ),
        ),
      ],
      child: MaterialApp(
        theme: ZakerTheme.light(),
        home: const BatchChatScreen(batchId: batchId),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> tallScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('shows the local-only note and the saved messages',
      (tester) async {
    await tallScreen(tester);
    repository.messages.addAll([
      message('msg-1', 'أهلا بيكم', authorUid: 'owner-1'),
      message('msg-2', 'شكرًا', minutes: 1),
    ]);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('محادثة محفوظة على الجهاز'),
      findsOneWidget,
    );
    expect(find.text('أهلا بيكم'), findsOneWidget);
    expect(find.text('شكرًا'), findsOneWidget);
    expect(find.text('لسه مفيش رسائل'), findsNothing);
  });

  testWidgets('sends a text message from the composer', (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('لسه مفيش رسائل'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'رسالة جديدة');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('رسالة جديدة'), findsWidgets);
    expect(repository.messages, hasLength(1));
    expect(repository.messages.single.text, 'رسالة جديدة');
  });

  testWidgets('a muted member sees the read-only notice instead of a composer',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(app(role: BatchRole.muted));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('مش مسموح لك تكتب في المحادثة'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('shows a pinned strip for pinned messages', (tester) async {
    await tallScreen(tester);
    repository.messages.add(
      message('msg-1', 'الامتحان يوم الخميس', pinned: true),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.textContaining('الامتحان يوم الخميس'), findsWidgets);
    expect(find.byTooltip('إخفاء المثبت'), findsOneWidget);
  });
}
