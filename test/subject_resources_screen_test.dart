import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/resource_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/batch_file_picker.dart';
import 'package:zaker_ai/features/batches/subjects/subject_resources_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

class _Calls {
  final List<String> importedPaths = [];
  final List<ResourceKind> importedKinds = [];
  final Set<String> failingPaths = {};
  String? noteTitle;
  String? noteText;
}

class _FakeController extends BatchController {
  _FakeController(Ref ref, this.calls) : super(ref);

  final _Calls calls;

  @override
  Future<BatchResource> importResource({
    required String batchId,
    required String subjectId,
    required ResourceKind kind,
    required String sourcePath,
    String? title,
  }) async {
    calls.importedPaths.add(sourcePath);
    calls.importedKinds.add(kind);
    if (calls.failingPaths.contains(sourcePath)) {
      throw const BatchFailure(BatchFailureCode.unsupportedFile);
    }
    return BatchResource(
      id: 'res-${calls.importedPaths.length}',
      batchId: batchId,
      subjectId: subjectId,
      kind: kind,
      title: title ?? 'ملف',
      fileName: 'file.pdf',
      sizeBytes: 1,
      uploaderUid: 'guest-test',
      createdAt: DateTime.utc(2026, 10, 25),
    );
  }

  @override
  Future<BatchResource> addNote({
    required String batchId,
    required String subjectId,
    required String title,
    required String note,
  }) async {
    calls.noteTitle = title;
    calls.noteText = note;
    return BatchResource(
      id: 'note-1',
      batchId: batchId,
      subjectId: subjectId,
      kind: ResourceKind.note,
      title: title,
      note: note,
      uploaderUid: 'guest-test',
      createdAt: DateTime.utc(2026, 10, 25),
    );
  }
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  const subjectId = 'subject-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  Future<void> tallScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  BatchSnapshot snapshot({
    String ownerUid = uid,
    List<BatchResource>? resources,
  }) {
    return BatchSnapshot(
      batch: Batch(
        id: batchId,
        name: 'دفعة',
        ownerUid: ownerUid,
        createdAt: fixed,
        lastActivityAt: fixed,
        settings: const BatchSettings(),
        subjects: [
          BatchSubject(
            id: subjectId,
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
          displayName: 'طالب',
          role: BatchRole.owner,
          joinedAt: fixed,
        ),
      ],
      resources: resources ?? const [],
    );
  }

  BatchResource resource({
    required String id,
    required String title,
    required ResourceKind kind,
    WeekDay? weekDay,
    String fileName = '',
    String note = '',
    int minutes = 0,
  }) {
    return BatchResource(
      id: id,
      batchId: batchId,
      subjectId: subjectId,
      weekDay: weekDay,
      kind: kind,
      title: title,
      fileName: fileName,
      note: note,
      sizeBytes: kind == ResourceKind.note ? 0 : 10,
      uploaderUid: uid,
      createdAt: fixed.add(Duration(minutes: minutes)),
    );
  }

  List<BatchResource> mixed() => [
        resource(
          id: 'res-note',
          title: 'ملاحظة عامة',
          kind: ResourceKind.note,
          note: 'نص',
          minutes: 3,
        ),
        resource(
          id: 'res-missing',
          title: 'ملف ناقص',
          kind: ResourceKind.pdf,
          fileName: 'missing.pdf',
          minutes: 2,
        ),
        resource(
          id: 'res-w1d2',
          title: 'محاضرة أولى',
          kind: ResourceKind.pdf,
          fileName: 'lecture.pdf',
          weekDay: const WeekDay(week: 1, day: 2),
        ),
        resource(
          id: 'res-w1d1',
          title: 'محاضرة تانية',
          kind: ResourceKind.pdf,
          fileName: 'lecture2.pdf',
          weekDay: const WeekDay(week: 1, day: 1),
        ),
      ];

  Widget app({
    required BatchSnapshot detail,
    required _Calls calls,
    Future<List<PickedResourceFile>> Function(ResourceKind kind)? picker,
  }) {
    final router = GoRouter(
      initialLocation: '/batches/$batchId/subjects/$subjectId',
      routes: [
        GoRoute(
          path: '/batches/:batchId/subjects/:subjectId',
          builder: (context, state) => SubjectResourcesScreen(
            batchId: state.pathParameters['batchId'] ?? '',
            subjectId: state.pathParameters['subjectId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/pdf-viewer',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('قارئ PDF'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
        batchDetailProvider.overrideWith((ref, id) async => detail),
        batchFileStoreProvider.overrideWithValue(
          BatchFileStore(root: Directory('/tmp/zaker_widget_test')),
        ),
        batchControllerProvider.overrideWith(
          (ref) => _FakeController(ref, calls),
        ),
        batchFilePickerProvider.overrideWithValue(
          picker ??
              (kind) async => const [
                    PickedResourceFile(
                      name: 'a.pdf',
                      path: '/tmp/a.pdf',
                      sizeBytes: 10,
                    ),
                  ],
        ),
        resourceMissingProvider.overrideWith(
          (ref, args) async => args.relativePath == 'resources/res-missing.pdf',
        ),
        resourceThumbnailProvider.overrideWith((ref, args) async => null),
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

  testWidgets('groups the resources by week and day, ungrouped first',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(detail: snapshot(resources: mixed()), calls: _Calls()),
    );
    await tester.pumpAndSettle();

    expect(find.text('ملاحظة عامة'), findsOneWidget);
    expect(find.text('الأسبوع ١ · اليوم ١'), findsOneWidget);
    expect(find.text('الأسبوع ١ · اليوم ٢'), findsOneWidget);
    expect(find.text('الملف مش موجود على الجهاز.'), findsOneWidget);

    final ungrouped = tester.getTopLeft(find.text('ملاحظة عامة')).dy;
    final missing = tester.getTopLeft(find.text('ملف ناقص')).dy;
    final dayOne = tester.getTopLeft(find.text('الأسبوع ١ · اليوم ١')).dy;
    final dayTwo = tester.getTopLeft(find.text('الأسبوع ١ · اليوم ٢')).dy;
    expect(ungrouped, lessThan(missing));
    expect(missing, lessThan(dayOne));
    expect(dayOne, lessThan(dayTwo));
  });

  testWidgets('shows the empty state and imports a PDF through the sheet',
      (tester) async {
    final calls = _Calls();
    await tallScreen(tester);
    await tester.pumpWidget(
      app(detail: snapshot(), calls: calls),
    );
    await tester.pumpAndSettle();

    expect(find.text('مفيش ملفات في المادة دي'), findsOneWidget);

    await tester.tap(find.text('ضيف ملف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملف PDF'));
    await tester.pumpAndSettle();

    expect(calls.importedPaths, ['/tmp/a.pdf']);
    expect(calls.importedKinds, [ResourceKind.pdf]);
    expect(find.text('اتضاف ١ ملف.'), findsOneWidget);
  });

  testWidgets('reports a partial import with the first real failure',
      (tester) async {
    final calls = _Calls()..failingPaths.add('/tmp/bad.txt');
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        calls: calls,
        picker: (kind) async => const [
          PickedResourceFile(
            name: 'ok.pdf',
            path: '/tmp/ok.pdf',
            sizeBytes: 10,
          ),
          PickedResourceFile(
            name: 'bad.txt',
            path: '/tmp/bad.txt',
            sizeBytes: 10,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ضيف ملف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملف PDF'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('اتضاف ١ من ٢. نوع الملف مش مدعوم.'),
      findsOneWidget,
    );
  });

  testWidgets('adds a text note after both fields are filled', (tester) async {
    final calls = _Calls();
    await tallScreen(tester);
    await tester.pumpWidget(
      app(detail: snapshot(), calls: calls),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ضيف ملف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملاحظة نصية'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'خلاصة');
    await tester.enterText(find.byType(TextField).at(1), 'نص الملاحظة');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(calls.noteTitle, 'خلاصة');
    expect(calls.noteText, 'نص الملاحظة');
    expect(find.text('اتضافت الملاحظة.'), findsOneWidget);
  });

  testWidgets('refuses to save an empty note', (tester) async {
    final calls = _Calls();
    await tallScreen(tester);
    await tester.pumpWidget(
      app(detail: snapshot(), calls: calls),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ضيف ملف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملاحظة نصية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    expect(find.text('اكتب عنوان الملاحظة.'), findsOneWidget);
    expect(find.text('اكتب نص الملاحظة.'), findsOneWidget);
    expect(calls.noteTitle, isNull);
  });

  testWidgets('hides the add action from someone who cannot upload',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(ownerUid: 'someone-else'),
        calls: _Calls(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ضيف ملف'), findsNothing);
    expect(find.text('مفيش ملفات في المادة دي'), findsOneWidget);
  });
}
