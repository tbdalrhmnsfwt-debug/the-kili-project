import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/updates/batch_updates_screen.dart';
import 'package:zaker_ai/features/batches/updates/update_detail_screen.dart';
import 'package:zaker_ai/features/batches/updates/update_editor_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_update.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

/// Records update commands; every other command is out of scope here.
class _FakeRepository implements BatchRepository {
  _FakeRepository(this.updates);

  List<BatchUpdate> updates;
  final List<BatchUpdate> published = [];
  final List<String> edited = [];
  final List<String> deleted = [];
  final List<String> markedRead = [];
  BatchFailure? readFailure;

  @override
  Future<List<BatchUpdate>> loadUpdates(String uid, String batchId) async {
    final failure = readFailure;
    if (failure != null) throw failure;
    return [...updates];
  }

  @override
  Future<BatchUpdate> publishUpdate(
    String uid,
    String batchId, {
    required String title,
    required String body,
  }) async {
    final update = BatchUpdate(
      id: 'update-new',
      batchId: batchId,
      authorUid: uid,
      authorName: 'طالب',
      title: title.trim(),
      body: body.trim(),
      createdAt: DateTime.utc(2026, 10, 25, 9),
      kind: BatchUpdateKind.announcement,
    );
    updates = [update, ...updates];
    published.add(update);
    return update;
  }

  @override
  Future<BatchUpdate> editUpdate(
    String uid,
    String batchId,
    String updateId, {
    required String title,
    required String body,
  }) async {
    final index = updates.indexWhere((item) => item.id == updateId);
    final updated = updates[index].copyWith(
      title: title.trim(),
      body: body.trim(),
      editedAt: DateTime.utc(2026, 10, 25, 10),
    );
    updates[index] = updated;
    edited.add(updateId);
    return updated;
  }

  @override
  Future<void> deleteUpdate(
    String uid,
    String batchId,
    String updateId,
  ) async {
    deleted.add(updateId);
    updates = [
      for (final item in updates)
        if (item.id != updateId) item,
    ];
  }

  @override
  Future<BatchUpdate> markUpdateRead(
    String uid,
    String batchId,
    String updateId,
  ) async {
    markedRead.add(updateId);
    final index = updates.indexWhere((item) => item.id == updateId);
    final updated = updates[index].copyWith(
      readBy: {...updates[index].readBy, uid},
    );
    updates[index] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  BatchSnapshot snapshot({BatchRole role = BatchRole.owner}) {
    return BatchSnapshot(
      batch: Batch(
        id: batchId,
        name: 'دفعة تالتة ثانوي',
        ownerUid: uid,
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

  BatchUpdate update(
    String id,
    String title, {
    String body = '',
    bool read = false,
    bool pinned = false,
    int minutes = 0,
  }) {
    return BatchUpdate(
      id: id,
      batchId: batchId,
      authorUid: uid,
      authorName: 'طالب',
      title: title,
      body: body,
      createdAt: fixed.add(Duration(minutes: minutes)),
      kind: BatchUpdateKind.announcement,
      pinned: pinned,
      readBy: read ? {uid} : const {},
    );
  }

  Future<void> open(
    WidgetTester tester, {
    required _FakeRepository repository,
    BatchRole role = BatchRole.owner,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/batches/$batchId/updates',
      routes: [
        GoRoute(
          path: '/batches/:batchId/updates',
          builder: (context, state) => BatchUpdatesScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/updates/new',
          builder: (context, state) => UpdateEditorScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/updates/:updateId/edit',
          builder: (context, state) => UpdateEditorScreen(
            batchId: state.pathParameters['batchId'] ?? '',
            original: state.extra as BatchUpdate?,
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/updates/:updateId',
          builder: (context, state) => UpdateDetailScreen(
            batchId: state.pathParameters['batchId'] ?? '',
            updateId: state.pathParameters['updateId'] ?? '',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith(
            (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
          ),
          batchDetailProvider
              .overrideWith((ref, id) async => snapshot(role: role)),
          batchRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: ZakerTheme.light(),
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the timeline with its local-only notice', (
    tester,
  ) async {
    await open(
      tester,
      repository: _FakeRepository([
        update('u1', 'مراجعة يوم الخميس',
            body: 'هنراجع الفصل الأول.', pinned: true),
        update('u2', 'واجب الأسبوع', read: true, minutes: 5),
      ]),
    );

    expect(
      find.textContaining('إشعار لباقي الأعضاء محتاج سيرفر'),
      findsOneWidget,
    );
    expect(find.text('مراجعة يوم الخميس'), findsOneWidget);
    expect(find.text('واجب الأسبوع'), findsOneWidget);
    expect(find.text('هنراجع الفصل الأول.'), findsOneWidget);
    expect(find.textContaining('إعلان · طالب'), findsNWidgets(2));
    expect(find.textContaining('· جديد'), findsOneWidget);
    expect(find.textContaining('· مقروء'), findsOneWidget);
  });

  testWidgets('an empty timeline invites the owner to write', (tester) async {
    await open(tester, repository: _FakeRepository([]));

    expect(find.text('مفيش مستجدات لسه'), findsOneWidget);
    expect(find.text('اكتب مستجد'), findsOneWidget);
    expect(find.text('مستجد جديد'), findsOneWidget);
  });

  testWidgets('a reader sees the timeline without a composer', (tester) async {
    await open(
      tester,
      repository: _FakeRepository([update('u1', 'مستجد')]),
      role: BatchRole.member,
    );

    expect(find.text('مستجد جديد'), findsNothing);
    expect(find.text('اكتب مستجد'), findsNothing);

    await tester.tap(find.text('مستجد'));
    await tester.pumpAndSettle();

    expect(find.text('مستجد'), findsOneWidget);
    expect(find.byTooltip('تعديل المستجد'), findsNothing);
    expect(find.byTooltip('حذف المستجد'), findsNothing);
  });

  testWidgets('an owner publishes a new update', (tester) async {
    final repository = _FakeRepository([]);
    await open(tester, repository: repository);

    await tester.tap(find.text('مستجد جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '  حصة إضافية  ');
    await tester.enterText(
        find.byType(TextField).last, ' يوم الجمعة الساعة ٥. ');
    await tester.ensureVisible(find.text('نشر المستجد'));
    await tester.tap(find.text('نشر المستجد'));
    await tester.pumpAndSettle();

    expect(repository.published.single.title, 'حصة إضافية');
    expect(repository.published.single.body, 'يوم الجمعة الساعة ٥.');
    expect(find.text('المستجد اتنشر.'), findsOneWidget);
    expect(find.text('حصة إضافية'), findsOneWidget);
  });

  testWidgets('an empty title is refused before writing', (tester) async {
    final repository = _FakeRepository([]);
    await open(tester, repository: repository);

    await tester.tap(find.text('مستجد جديد'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('نشر المستجد'));
    await tester.tap(find.text('نشر المستجد'));
    await tester.pumpAndSettle();

    expect(find.text('العنوان مطلوب.'), findsOneWidget);
    expect(repository.published, isEmpty);
  });

  testWidgets('opening an unread post marks it read once', (tester) async {
    final repository = _FakeRepository([
      update('u1', 'مراجعة', body: 'كل التفاصيل هنا.'),
    ]);
    await open(tester, repository: repository);

    await tester.tap(find.text('مراجعة'));
    await tester.pumpAndSettle();

    expect(find.text('كل التفاصيل هنا.'), findsOneWidget);
    expect(repository.markedRead, ['u1']);
    expect(repository.updates.single.isReadBy(uid), isTrue);

    // Rebuilding the detail does not send a second mark.
    await tester.pumpAndSettle();
    expect(repository.markedRead, ['u1']);
  });

  testWidgets('an owner edits a post', (tester) async {
    final repository = _FakeRepository([update('u1', 'العنوان القديم')]);
    await open(tester, repository: repository);

    await tester.tap(find.text('العنوان القديم'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تعديل المستجد'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'العنوان الجديد');
    await tester.ensureVisible(find.text('حفظ التعديل'));
    await tester.tap(find.text('حفظ التعديل'));
    await tester.pumpAndSettle();

    expect(repository.edited, ['u1']);
    expect(repository.updates.single.title, 'العنوان الجديد');
    expect(find.text('العنوان الجديد'), findsOneWidget);
  });

  testWidgets('deleting asks first and then removes the post', (tester) async {
    final repository = _FakeRepository([update('u1', 'مستجد')]);
    await open(tester, repository: repository);

    await tester.tap(find.text('مستجد'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('حذف المستجد'));
    await tester.pumpAndSettle();

    expect(find.text('حذف المستجد؟'), findsOneWidget);
    expect(
      find.text('المستجد هيتشال من الجهاز. مفيش نسخة على سيرفر.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['u1']);
    expect(repository.updates, isEmpty);
    expect(find.text('مستجد'), findsNothing);
  });

  testWidgets('a corrupt timeline explains itself and offers a retry', (
    tester,
  ) async {
    final repository = _FakeRepository([update('u1', 'مستجد')])
      ..readFailure = const BatchFailure(BatchFailureCode.corruptStore);
    await open(tester, repository: repository);

    expect(find.text('مقدرناش نقرا المستجدات'), findsOneWidget);
    expect(find.text('بيانات الدفعة اتلفت ومقدرناش نقراها.'), findsOneWidget);

    repository.readFailure = null;
    await tester.tap(find.text('جرّب تاني'));
    await tester.pumpAndSettle();

    expect(find.text('مستجد'), findsOneWidget);
  });
}
