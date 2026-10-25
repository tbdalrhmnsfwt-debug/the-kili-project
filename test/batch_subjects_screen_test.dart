import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/subjects/batch_subjects_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

class _Calls {
  String? addedName;
  String? deletedSubjectId;
  String? moveToSubjectId;
  bool deleteResources = false;
}

class _FakeController extends BatchController {
  _FakeController(Ref ref, this.calls) : super(ref);

  final _Calls calls;

  @override
  Future<BatchSubject> addSubject(String batchId, String name) async {
    calls.addedName = name;
    return BatchSubject(
      id: 'created',
      name: name,
      order: 5,
      createdAt: DateTime.utc(2026, 10, 25),
    );
  }

  @override
  Future<void> deleteSubject(
    String batchId,
    String subjectId, {
    String? moveToSubjectId,
    bool deleteResources = false,
  }) async {
    calls.deletedSubjectId = subjectId;
    calls.moveToSubjectId = moveToSubjectId;
    calls.deleteResources = deleteResources;
  }
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  Future<void> tallScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  BatchSnapshot snapshot({
    String ownerUid = uid,
    List<String> subjectNames = const ['رياضيات', 'فيزياء'],
    Map<String, int> resourceCounts = const {},
  }) {
    final subjects = [
      for (var i = 0; i < subjectNames.length; i++)
        BatchSubject(
          id: 'subject-$i',
          name: subjectNames[i],
          order: i,
          createdAt: fixed,
        ),
    ];
    return BatchSnapshot(
      batch: Batch(
        id: batchId,
        name: 'دفعة',
        ownerUid: ownerUid,
        createdAt: fixed,
        lastActivityAt: fixed,
        settings: const BatchSettings(),
        subjects: subjects,
        codeState: InviteCodeState(code: '12345678', createdAt: fixed),
      ),
      members: [
        Membership(
          batchId: batchId,
          uid: ownerUid,
          displayName: 'طالب',
          role: BatchRole.owner,
          joinedAt: fixed,
        ),
      ],
      resources: [
        for (final subject in subjects)
          for (var i = 0; i < (resourceCounts[subject.id] ?? 0); i++)
            BatchResource(
              id: '${subject.id}-res-$i',
              batchId: batchId,
              subjectId: subject.id,
              kind: ResourceKind.note,
              title: 'ملاحظة $i',
              note: 'نص',
              uploaderUid: ownerUid,
              createdAt: fixed,
            ),
      ],
    );
  }

  Widget app({
    required BatchSnapshot detail,
    required _Calls calls,
  }) {
    final router = GoRouter(
      initialLocation: '/batches/$batchId/subjects',
      routes: [
        GoRoute(
          path: '/batches/:batchId/subjects',
          builder: (context, state) => BatchSubjectsScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/subjects/:subjectId',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('الملفات هنا'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
        batchDetailProvider.overrideWith((ref, id) async => detail),
        batchStorageProvider.overrideWith((ref, id) async => 1024),
        batchControllerProvider.overrideWith(
          (ref) => _FakeController(ref, calls),
        ),
      ],
      child: MaterialApp.router(
        theme: ZakerTheme.light(),
        routerConfig: router,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('lists the subjects in order with their resource counts',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(resourceCounts: {'subject-0': 3}),
        calls: _Calls(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('رياضيات'), findsOneWidget);
    expect(find.text('فيزياء'), findsOneWidget);
    expect(find.text('٣ ملف'), findsOneWidget);
    expect(find.text('مفيش ملفات'), findsOneWidget);
    expect(
        find.text('المساحة المستخدمة على الجهاز: ١ كيلوبايت'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('رياضيات')).dy,
      lessThan(tester.getTopLeft(find.text('فيزياء')).dy),
    );
  });

  testWidgets('shows the empty state and adds the first subject',
      (tester) async {
    final calls = _Calls();
    await tallScreen(tester);
    await tester.pumpWidget(
      app(detail: snapshot(subjectNames: const []), calls: calls),
    );
    await tester.pumpAndSettle();

    expect(find.text('مفيش مواد'), findsOneWidget);

    await tester.tap(find.text('ضيف مادة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  كيمياء  ');
    await tester.tap(find.text('ضيف'));
    await tester.pumpAndSettle();

    expect(calls.addedName, 'كيمياء');
  });

  testWidgets('moves a deleted subject\'s resources to another subject',
      (tester) async {
    final calls = _Calls();
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(resourceCounts: {'subject-0': 3}),
        calls: calls,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المادة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('٣ ملف'), findsWidgets);
    await tester.tap(find.text('انقلها لـ فيزياء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المادة'));
    await tester.pumpAndSettle();

    expect(calls.deletedSubjectId, 'subject-0');
    expect(calls.moveToSubjectId, 'subject-1');
    expect(calls.deleteResources, isFalse);
  });

  testWidgets('deletes the resources only after the counted choice',
      (tester) async {
    final calls = _Calls();
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(resourceCounts: {'subject-0': 2}),
        calls: calls,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المادة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('امسح الملفات (٢)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المادة'));
    await tester.pumpAndSettle();

    expect(calls.deletedSubjectId, 'subject-0');
    expect(calls.moveToSubjectId, isNull);
    expect(calls.deleteResources, isTrue);
  });

  testWidgets('asks only for confirmation when the subject is empty',
      (tester) async {
    final calls = _Calls();
    await tallScreen(tester);
    await tester.pumpWidget(
      app(detail: snapshot(), calls: calls),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المادة'));
    await tester.pumpAndSettle();

    expect(find.text('مفيش ملفات جواها.'), findsNothing);
    expect(
      find.textContaining('مفيش ملفات جواها'),
      findsOneWidget,
    );
    expect(find.text('امسح الملفات (٠)'), findsNothing);

    await tester.tap(find.text('حذف المادة'));
    await tester.pumpAndSettle();
    expect(calls.deletedSubjectId, 'subject-0');
    expect(calls.deleteResources, isFalse);
    expect(calls.moveToSubjectId, isNull);
  });

  testWidgets('hides subject management from a non-owner', (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(ownerUid: 'someone-else'),
        calls: _Calls(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('مادة جديدة'), findsNothing);
  });

  testWidgets('opens the resources of a subject', (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(detail: snapshot(), calls: _Calls()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('رياضيات'));
    await tester.pumpAndSettle();

    expect(find.text('الملفات هنا'), findsOneWidget);
  });
}
