import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/hub_summary.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/admin/batch_admin_screen.dart';
import 'package:zaker_ai/features/batches/admin/batch_settings_screen.dart';
import 'package:zaker_ai/features/batches/admin/join_requests_screen.dart';
import 'package:zaker_ai/features/batches/admin/members_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/providers/admin_providers.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

class _FakeAdminRepository implements BatchRepository {
  _FakeAdminRepository(this.snapshot);

  BatchSnapshot snapshot;
  int rotations = 0;
  int revocations = 0;
  int deletions = 0;
  int settingsSaves = 0;

  @override
  Future<BatchSnapshot> loadBatch(String uid, String batchId) async => snapshot;

  @override
  Future<List<BatchSummary>> listBatches(String uid) async => [
        BatchSummary(batchId: snapshot.batch.id, batch: snapshot.batch),
      ];

  @override
  Future<int> storageUsed(String uid, String batchId) async => 2048;

  @override
  Future<InviteCodeState> rotateCode(String uid, String batchId) async {
    rotations++;
    final state = InviteCodeState(
      code: '87654321',
      createdAt: snapshot.batch.createdAt,
      rotationCount: rotations,
    );
    snapshot = snapshot.copyWith(
      batch: snapshot.batch.copyWith(codeState: state),
    );
    return state;
  }

  @override
  Future<InviteCodeState> revokeCode(String uid, String batchId) async {
    revocations++;
    final state = snapshot.batch.codeState.copyWith(
      revokedAt: snapshot.batch.createdAt,
    );
    snapshot = snapshot.copyWith(
      batch: snapshot.batch.copyWith(codeState: state),
    );
    return state;
  }

  @override
  Future<Batch> updateSettings(
    String uid,
    String batchId,
    BatchSettings settings,
  ) async {
    settingsSaves++;
    snapshot = snapshot.copyWith(
      batch: snapshot.batch.copyWith(settings: settings),
    );
    return snapshot.batch;
  }

  @override
  Future<void> deleteBatch(String uid, String batchId) async {
    deletions++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'guest-owner';
  const batchId = 'batch-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  BatchSnapshot snapshot({
    String ownerUid = uid,
    BatchRole role = BatchRole.member,
    BatchSettings settings = const BatchSettings(),
  }) {
    return BatchSnapshot(
      batch: Batch(
        id: batchId,
        name: 'دفعة تالتة ثانوي',
        ownerUid: ownerUid,
        createdAt: fixed,
        lastActivityAt: fixed,
        settings: settings,
        subjects: [
          BatchSubject(
            id: 'subject-0',
            name: 'رياضيات',
            order: 0,
            createdAt: fixed,
          ),
        ],
        codeState: InviteCodeState(code: '12345678', createdAt: fixed),
      ),
      members: [
        Membership(
          batchId: batchId,
          uid: ownerUid,
          displayName: 'المعلم',
          role: BatchRole.owner,
          joinedAt: fixed,
        ),
        if (ownerUid != uid)
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

  BatchHubData emptyHub() => const BatchHubData(
        updates: [],
        updatesAvailable: true,
        exams: [],
        examsAvailable: true,
        schedules: [],
        schedulesAvailable: true,
        lastMessage: null,
        chatAvailable: true,
      );

  Future<void> tallScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget app({
    required _FakeAdminRepository repository,
    required String initialLocation,
    String viewerUid = uid,
    List<AuditEntry> audit = const [],
    double textScale = 1,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/batches',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('الدفعات هنا'))),
        ),
        GoRoute(
          path: '/batches/:batchId/admin',
          builder: (context, state) => BatchAdminScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/admin/settings',
          builder: (context, state) => BatchSettingsScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/admin/members',
          builder: (context, state) => BatchMembersScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/admin/requests',
          builder: (context, state) => BatchJoinRequestsScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/subjects',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('المواد هنا'))),
        ),
        GoRoute(
          path: '/batches/:batchId/schedules',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('المواعيد هنا'))),
        ),
        GoRoute(
          path: '/batches/:batchId/updates',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('المستجدات هنا'))),
        ),
        GoRoute(
          path: '/batches/:batchId/exams',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('الامتحانات هنا'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => AuthUser(uid: viewerUid, displayName: 'طالب'),
        ),
        batchRepositoryProvider.overrideWithValue(repository),
        batchDetailProvider
            .overrideWith((ref, id) async => repository.snapshot),
        batchHubDataProvider.overrideWith((ref, id) async => emptyHub()),
        batchStorageProvider.overrideWith((ref, id) async => 2048),
        batchAuditProvider.overrideWith((ref, id) async => audit),
      ],
      child: MaterialApp.router(
        theme: ZakerTheme.light(),
        routerConfig: router,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  testWidgets('the owner sees local administration and blocked joins',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        repository: _FakeAdminRepository(snapshot()),
        initialLocation: '/batches/$batchId/admin',
        audit: [
          AuditEntry(
            id: 'audit-1',
            batchId: batchId,
            actorUid: uid,
            action: 'batchCreated',
            at: fixed,
          ),
          AuditEntry(
            id: 'audit-2',
            batchId: batchId,
            actorUid: uid,
            action: 'codeRotated',
            at: fixed.add(const Duration(minutes: 1)),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة الدفعة'), findsOneWidget);
    expect(find.textContaining('مفيش طلبات'), findsOneWidget);
    expect(find.textContaining('محتاجين سيرفر'), findsWidgets);
    expect(find.text('كود جديد'), findsOneWidget);
    expect(find.text('مراجعة المحتوى'), findsOneWidget);
    expect(find.text('إنشاء الدفعة'), findsOneWidget);
    expect(find.text('توليد كود دعوة جديد'), findsOneWidget);
    expect(find.textContaining('السجل محلي'), findsOneWidget);
    expect(find.text('احذف الدفعة'), findsOneWidget);
  });

  testWidgets('rotating and revoking the code each ask first', (tester) async {
    await tallScreen(tester);
    final repository = _FakeAdminRepository(snapshot());
    await tester.pumpWidget(
      app(
        repository: repository,
        initialLocation: '/batches/$batchId/admin',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('كود جديد'));
    await tester.pumpAndSettle();
    expect(find.text('توليد كود جديد؟'), findsOneWidget);
    expect(repository.rotations, 0);

    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();
    expect(repository.rotations, 0);

    await tester.tap(find.text('كود جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ولّد كود'));
    await tester.pumpAndSettle();
    expect(repository.rotations, 1);

    await tester.tap(find.widgetWithText(OutlinedButton, 'وقف الكود'));
    await tester.pumpAndSettle();
    expect(find.text('إيقاف كود الدعوة؟'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'وقف الكود'));
    await tester.pumpAndSettle();
    expect(repository.revocations, 1);
  });

  testWidgets('deleting a batch needs confirmation and leaves the screen',
      (tester) async {
    await tallScreen(tester);
    final repository = _FakeAdminRepository(snapshot());
    await tester.pumpWidget(
      app(
        repository: repository,
        initialLocation: '/batches/$batchId/admin',
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'احذف الدفعة'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'احذف الدفعة'));
    await tester.pumpAndSettle();
    expect(find.text('حذف الدفعة؟'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();
    expect(repository.deletions, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, 'احذف الدفعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'احذف الدفعة'));
    await tester.pumpAndSettle();

    expect(repository.deletions, 1);
    expect(find.text('الدفعات هنا'), findsOneWidget);
  });

  testWidgets('a plain member cannot open administration', (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        repository: _FakeAdminRepository(
          snapshot(ownerUid: 'guest-other'),
        ),
        initialLocation: '/batches/$batchId/admin',
        viewerUid: uid,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الإدارة مش متاحة للحساب ده'), findsOneWidget);
    expect(find.text('احذف الدفعة'), findsNothing);
    expect(find.text('كود جديد'), findsNothing);
  });

  testWidgets('settings save the upload and reminder policies', (tester) async {
    await tallScreen(tester);
    final repository = _FakeAdminRepository(snapshot());
    await tester.pumpWidget(
      app(
        repository: repository,
        initialLocation: '/batches/$batchId/admin/settings',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرفع للمسؤول بس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تذكيرات المواعيد للأعضاء'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'احفظ الإعدادات'));
    await tester.pumpAndSettle();

    expect(repository.settingsSaves, 1);
    expect(repository.snapshot.batch.settings.uploadsAdminOnly, isFalse);
    expect(repository.snapshot.batch.settings.allowMemberReminders, isFalse);
  });

  testWidgets('closing member uploads asks before it saves', (tester) async {
    await tallScreen(tester);
    final repository = _FakeAdminRepository(
      snapshot(settings: const BatchSettings(uploadsAdminOnly: false)),
    );
    await tester.pumpWidget(
      app(
        repository: repository,
        initialLocation: '/batches/$batchId/admin/settings',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرفع للمسؤول بس'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'احفظ الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('تقفل الرفع للأعضاء؟'), findsOneWidget);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(repository.settingsSaves, 0);
    expect(find.text('احفظ الإعدادات'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'احفظ الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اقفل الرفع'));
    await tester.pumpAndSettle();

    expect(repository.settingsSaves, 1);
    expect(repository.snapshot.batch.settings.uploadsAdminOnly, isTrue);
  });

  testWidgets('a non-owner cannot change settings', (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        repository: _FakeAdminRepository(
          snapshot(ownerUid: 'guest-other', role: BatchRole.admin),
        ),
        initialLocation: '/batches/$batchId/admin/settings',
        viewerUid: uid,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الإعدادات لصاحب الدفعة بس'), findsOneWidget);
    expect(find.text('احفظ الإعدادات'), findsNothing);
  });

  testWidgets('the join-request screen offers no fake decisions',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        repository: _FakeAdminRepository(snapshot()),
        initialLocation: '/batches/$batchId/admin/requests',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مفيش طلبات انضمام'), findsOneWidget);
    expect(find.textContaining('محتاجة سيرفر'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'موافقة'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'رفض'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'موافقة'), findsNothing);
  });

  testWidgets('the members screen lists local roles and no actions',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        repository: _FakeAdminRepository(
          snapshot(ownerUid: 'guest-other', role: BatchRole.admin),
        ),
        initialLocation: '/batches/$batchId/admin/members',
        viewerUid: uid,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('صاحب الدفعة'), findsOneWidget);
    expect(find.text('مسؤول'), findsOneWidget);
    expect(find.textContaining('الدعوة والكتم والإزالة محتاجين سيرفر'),
        findsOneWidget);
    expect(find.text('ادعُ عضو'), findsNothing);
  });

  testWidgets('administration fits a narrow RTL screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(
        repository: _FakeAdminRepository(snapshot()),
        initialLocation: '/batches/$batchId/admin',
        textScale: 1.5,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('إدارة الدفعة'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
