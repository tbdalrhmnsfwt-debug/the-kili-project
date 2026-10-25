import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/batches_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_chat.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

/// An in-memory command surface, so widget tests never touch real file I/O
/// inside the fake-async zone.
class _FakeRepository implements BatchRepository {
  _FakeRepository(this.items);

  List<BatchSummary> items;
  final List<String> deleted = [];

  @override
  Future<List<BatchSummary>> listBatches(String uid) async => [...items];

  @override
  Future<void> deleteBatch(String uid, String batchId) async {
    deleted.add(batchId);
    items = [
      for (final item in items)
        if (item.batchId != batchId) item,
    ];
  }

  @override
  Future<int> storageUsed(String uid, String batchId) async => 0;

  @override
  Future<Batch> createBatch({
    required String uid,
    required String displayName,
    required String name,
    required List<String> subjects,
    BatchSettings settings = const BatchSettings(),
  }) =>
      throw UnimplementedError();

  @override
  Future<Batch> updateSettings(
    String uid,
    String batchId,
    BatchSettings settings,
  ) =>
      throw UnimplementedError();

  @override
  Future<BatchSubject> addSubject(String uid, String batchId, String name) =>
      throw UnimplementedError();

  @override
  Future<void> renameSubject(
    String uid,
    String batchId,
    String subjectId,
    String name,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSubject(
    String uid,
    String batchId,
    String subjectId, {
    String? moveToSubjectId,
    bool deleteResources = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<BatchResource> addResource(
    String uid,
    String batchId,
    BatchResource resource,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> deleteResource(
    String uid,
    String batchId,
    String resourceId,
  ) =>
      throw UnimplementedError();

  @override
  Future<BatchResource> setStarred(
    String uid,
    String batchId,
    String resourceId,
    bool starred,
  ) =>
      throw UnimplementedError();

  @override
  Future<ChatPage> loadChat(
    String uid,
    String batchId, {
    ChatCursor? before,
    int limit = 30,
  }) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> sendChatMessage(
    String uid,
    String batchId,
    ChatMessage message,
  ) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> editChatMessage(
    String uid,
    String batchId,
    String messageId,
    String text,
  ) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> deleteChatMessage(
    String uid,
    String batchId,
    String messageId,
  ) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> reactToChatMessage(
    String uid,
    String batchId,
    String messageId,
    String emoji,
    bool reacted,
  ) =>
      throw UnimplementedError();

  @override
  Future<ChatMessage> pinChatMessage(
    String uid,
    String batchId,
    String messageId,
    bool pinned,
  ) =>
      throw UnimplementedError();

  @override
  Future<InviteCodeState> rotateCode(String uid, String batchId) =>
      throw UnimplementedError();

  @override
  Future<InviteCodeState> revokeCode(String uid, String batchId) =>
      throw UnimplementedError();

  @override
  Future<BatchSnapshot> loadBatch(String uid, String batchId) =>
      throw UnimplementedError();
}

void main() {
  const uid = 'guest-test';

  Batch batch({int subjectCount = 2}) {
    final createdAt = DateTime.utc(2026, 10, 25, 8);
    return Batch(
      id: 'batch-1',
      name: 'دفعة تالتة ثانوي',
      ownerUid: uid,
      createdAt: createdAt,
      lastActivityAt: createdAt,
      settings: const BatchSettings(),
      subjects: [
        for (var i = 0; i < subjectCount; i++)
          BatchSubject(
            id: 'subject-$i',
            name: i == 0 ? 'رياضيات' : 'فيزياء',
            order: i,
            createdAt: createdAt,
          ),
      ],
      codeState: InviteCodeState(code: '00000001', createdAt: createdAt),
    );
  }

  BatchSummary summary({int subjectCount = 2}) => BatchSummary(
        batchId: 'batch-1',
        batch: batch(subjectCount: subjectCount),
        resourceCount: 0,
      );

  Widget app(_FakeRepository repository, {double textScale = 1}) {
    return ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore.memory()),
        batchRepositoryProvider.overrideWithValue(repository),
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
      ],
      child: MaterialApp(
        theme: ZakerTheme.light(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const BatchesScreen(),
      ),
    );
  }

  testWidgets('shows the honest empty state', (tester) async {
    await tester.pumpWidget(app(_FakeRepository([])));
    await tester.pumpAndSettle();

    expect(find.text('مفيش دفعات على الجهاز'), findsOneWidget);
    expect(
      find.textContaining('الدفعات بتتحفظ على الجهاز ده لوحده'),
      findsOneWidget,
    );
    expect(find.text('اعمل دفعة'), findsOneWidget);
    expect(find.text('عندك كود؟'), findsOneWidget);
  });

  testWidgets('offers create and join actions without a fake refresh', (
    tester,
  ) async {
    await tester.pumpWidget(app(_FakeRepository([])));
    await tester.pumpAndSettle();

    expect(find.byTooltip('دفعة جديدة'), findsOneWidget);
    expect(find.byTooltip('عندك كود دعوة؟'), findsOneWidget);
    expect(find.byTooltip('تحديث'), findsNothing);
  });

  testWidgets('lists a batch with its subjects and owner code', (tester) async {
    await tester.pumpWidget(app(_FakeRepository([summary()])));
    await tester.pumpAndSettle();

    expect(find.text('دفعة تالتة ثانوي'), findsOneWidget);
    expect(find.textContaining('2 مواد'), findsOneWidget);
    expect(find.textContaining('أنت بس على الجهاز'), findsOneWidget);
    expect(find.textContaining('كود الدخول: 0000 0001'), findsOneWidget);
    expect(find.byTooltip('حذف الدفعة'), findsOneWidget);
  });

  testWidgets('deletes after an explicit confirmation', (tester) async {
    final repository = _FakeRepository([summary()]);
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حذف الدفعة'));
    await tester.pumpAndSettle();
    expect(find.text('حذف الدفعة؟'), findsOneWidget);
    expect(find.textContaining('مفيش نسخة على سيرفر'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(find.text('مفيش دفعات على الجهاز'), findsOneWidget);
    expect(repository.deleted, ['batch-1']);
  });

  testWidgets('cancelling the dialog keeps the batch', (tester) async {
    final repository = _FakeRepository([summary()]);
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حذف الدفعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('دفعة تالتة ثانوي'), findsOneWidget);
    expect(repository.deleted, isEmpty);
  });

  testWidgets('renders an unavailable batch with a delete path', (
    tester,
  ) async {
    final repository = _FakeRepository([
      const BatchSummary(
        batchId: 'broken-1',
        failure: BatchFailure(
          BatchFailureCode.corruptStore,
          detail: 'batch document unreadable',
        ),
      ),
    ]);

    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    expect(find.text('دفعة مش متاحة'), findsOneWidget);
    expect(find.byTooltip('حذف الدفعة'), findsOneWidget);
  });

  testWidgets('survives a narrow RTL surface with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(_FakeRepository([summary()]), textScale: 1.5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('دفعة تالتة ثانوي'), findsOneWidget);
  });
}
