import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/batch_created_screen.dart';
import 'package:zaker_ai/features/batches/create_batch_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

class _CreateCall {
  const _CreateCall(this.name, this.subjects, this.settings);

  final String name;
  final List<String> subjects;
  final BatchSettings settings;
}

class _FakeRepository implements BatchRepository {
  final List<_CreateCall> creates = [];
  BatchSnapshot? snapshot;

  @override
  Future<Batch> createBatch({
    required String uid,
    required String displayName,
    required String name,
    required List<String> subjects,
    BatchSettings settings = const BatchSettings(),
  }) async {
    final now = DateTime.utc(2026, 10, 25, 8);
    final batch = Batch(
      id: 'batch-1',
      name: name,
      ownerUid: uid,
      createdAt: now,
      settings: settings,
      subjects: [
        for (var i = 0; i < subjects.length; i++)
          BatchSubject(
            id: 'sub-$i',
            name: subjects[i],
            order: i,
            createdAt: now,
          ),
      ],
      codeState: InviteCodeState(code: '00000042', createdAt: now),
      lastActivityAt: now,
    );
    snapshot = BatchSnapshot(
      batch: batch,
      members: [
        Membership(
          batchId: batch.id,
          uid: uid,
          displayName: displayName.isEmpty ? 'ضيف' : displayName,
          role: BatchRole.owner,
          joinedAt: now,
        ),
      ],
    );
    creates.add(_CreateCall(name, [...subjects], settings));
    return batch;
  }

  @override
  Future<BatchSnapshot> loadBatch(String uid, String batchId) async {
    return snapshot!;
  }

  @override
  Future<List<BatchSummary>> listBatches(String uid) async => const [];

  @override
  Future<void> deleteBatch(String uid, String batchId) =>
      throw UnimplementedError();

  @override
  Future<int> storageUsed(String uid, String batchId) async => 0;

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
  Future<InviteCodeState> rotateCode(String uid, String batchId) =>
      throw UnimplementedError();

  @override
  Future<InviteCodeState> revokeCode(String uid, String batchId) =>
      throw UnimplementedError();
}

void main() {
  const uid = 'guest-test';
  const displayName = 'طالب';

  Widget app(_FakeRepository repository, {double textScale = 1}) {
    final router = GoRouter(
      initialLocation: '/batches/create',
      routes: [
        GoRoute(
          path: '/batches/create',
          builder: (context, state) => const CreateBatchScreen(),
        ),
        GoRoute(
          path: '/batches/:batchId/created',
          builder: (context, state) => BatchCreatedScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('الدفعات هنا'))),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore.memory()),
        batchRepositoryProvider.overrideWithValue(repository),
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: displayName),
        ),
      ],
      child: MaterialApp.router(
        theme: ZakerTheme.light(),
        routerConfig: router,
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
      ),
    );
  }

  Finder nameField() => find.byType(TextField).at(0);
  Finder subjectField() => find.byType(TextField).at(1);

  testWidgets('refuses a short name and refuses a duplicate subject', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(app(repository));

    await tester.tap(find.text('كمّل'));
    await tester.pumpAndSettle();
    expect(find.text('اسم الدفعة لازم يكون حرفين على الأقل.'), findsOneWidget);

    await tester.enterText(nameField(), 'دفعة تالتة');
    await tester.enterText(subjectField(), 'رياضيات');
    await tester.tap(find.byTooltip('ضيف المادة'));
    await tester.pumpAndSettle();

    await tester.enterText(subjectField(), 'رياضيات');
    await tester.tap(find.byTooltip('ضيف المادة'));
    await tester.pumpAndSettle();

    expect(find.text('المادة دي موجودة بالفعل.'), findsOneWidget);
    expect(find.textContaining('1 من 30 مواد'), findsOneWidget);
    expect(repository.creates, isEmpty);
  });

  testWidgets('reviews the chosen settings, creates, then shows the code', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(app(repository));

    await tester.enterText(nameField(), 'دفعة تالتة ثانوي');
    await tester.enterText(subjectField(), 'رياضيات');
    await tester.tap(find.byTooltip('ضيف المادة'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('رفع الملفات للمسؤولين بس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رفع الملفات للمسؤولين بس'));
    await tester.ensureVisible(find.text('موافقة على الانضمام'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('موافقة على الانضمام'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('كمّل'));
    await tester.pumpAndSettle();

    expect(find.text('مراجعة الدفعة'), findsOneWidget);
    expect(find.text('صاحب الدفعة: $displayName'), findsOneWidget);
    expect(find.text('رفع الملفات: كل الأعضاء النشطين.'), findsOneWidget);
    expect(find.text('الانضمام: من غير موافقة.'), findsOneWidget);
    expect(find.text('رياضيات'), findsOneWidget);
    expect(repository.creates, isEmpty);

    await tester.tap(find.text('أنشئ الدفعة'));
    await tester.pumpAndSettle();

    expect(repository.creates.single.name, 'دفعة تالتة ثانوي');
    expect(repository.creates.single.subjects, ['رياضيات']);
    expect(repository.creates.single.settings.uploadsAdminOnly, isFalse);
    expect(repository.creates.single.settings.requireApproval, isFalse);

    expect(find.text('الدفعة اتعملت'), findsOneWidget);
    expect(find.text('0000 0042'), findsOneWidget);
    expect(find.text('انسخ'), findsOneWidget);
    expect(find.text('شارك'), findsOneWidget);
    expect(
      find.textContaining('الكود ده طريقة دعوة مش تسجيل دخول'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('رجوع للدفعات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رجوع للدفعات'));
    await tester.pumpAndSettle();
    expect(find.text('الدفعات هنا'), findsOneWidget);
  });

  testWidgets('shows an empty subject list honestly on review', (tester) async {
    await tester.pumpWidget(app(_FakeRepository()));

    await tester.enterText(nameField(), 'دفعة من غير مواد');
    await tester.tap(find.text('كمّل'));
    await tester.pumpAndSettle();

    expect(find.text('من غير مواد'), findsOneWidget);
  });

  testWidgets('survives a narrow RTL surface with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      app(_FakeRepository(), textScale: 1.4),
    );
    await tester.enterText(nameField(), 'دفعة تالتة ثانوي');
    await tester.enterText(subjectField(), 'رياضيات');
    await tester.tap(find.byTooltip('ضيف المادة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كمّل'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('مراجعة الدفعة'), findsOneWidget);
  });
}
