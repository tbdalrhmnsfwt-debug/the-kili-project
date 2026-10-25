import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/schedules/schedule_draft_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_schedule.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';
import 'package:zaker_ai/providers/schedule_providers.dart';

/// Records schedule commands; every other command is out of scope here.
class _FakeRepository implements BatchRepository {
  _FakeRepository(this.drafts);

  final List<TimetableDraft> drafts;
  final List<TimetableEntry> savedEntries = [];
  final List<String> published = [];
  final List<String> deleted = [];
  BatchFailure? publishFailure;

  @override
  Future<List<TimetableDraft>> loadSchedules(
    String uid,
    String batchId,
  ) async =>
      [...drafts];

  @override
  Future<TimetableDraft> saveScheduleDraft(
    String uid,
    String batchId,
    TimetableDraft draft,
  ) async {
    savedEntries
      ..clear()
      ..addAll(draft.entries);
    final index = drafts.indexWhere((item) => item.id == draft.id);
    if (index >= 0) {
      drafts[index] = draft;
    } else {
      drafts.add(draft);
    }
    return draft;
  }

  @override
  Future<TimetableDraft> publishScheduleDraft(
    String uid,
    String batchId,
    String draftId,
  ) async {
    published.add(draftId);
    final failure = publishFailure;
    if (failure != null) throw failure;
    final index = drafts.indexWhere((item) => item.id == draftId);
    final updated = drafts[index].copyWith(
      status: TimetableDraftStatus.published,
    );
    drafts[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteScheduleDraft(
    String uid,
    String batchId,
    String draftId,
  ) async {
    deleted.add(draftId);
    drafts.removeWhere((item) => item.id == draftId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  const draftId = 'schedule-test';
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
          uid: uid,
          displayName: 'طالب',
          role: role,
          joinedAt: fixed,
        ),
      ],
    );
  }

  TimetableEntry entry({
    String title = 'مراجعة رياضيات',
    int end = 9 * 60,
    List<String> uncertain = const ['endMinutes'],
  }) {
    return TimetableEntry(
      id: 'slot-1',
      dayOfWeek: DateTime.saturday,
      startMinutes: 8 * 60,
      endMinutes: end,
      title: title,
      subjectId: 'subject-0',
      room: 'A',
      teacher: 'أ. محمد',
      confidence: 0.5,
      uncertainFields: uncertain,
      recurrence: TimetableRecurrence.weekly,
    );
  }

  TimetableDraft draft({
    TimetableDraftStatus status = TimetableDraftStatus.draft,
    List<TimetableEntry>? entries,
  }) {
    return TimetableDraft(
      id: draftId,
      batchId: batchId,
      sourceImageFileName: 'schedules/$draftId.png',
      createdAt: fixed,
      updatedAt: fixed,
      status: status,
      entries: entries ?? [entry()],
      warnings: const ['راجع وقت النهاية.'],
    );
  }

  Future<void> openDraft(
    WidgetTester tester, {
    required _FakeRepository repository,
    required BatchSnapshot detail,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith(
            (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
          ),
          batchDetailProvider.overrideWith((ref, id) async => detail),
          scheduleDraftsProvider.overrideWith(
            (ref, id) async => [...repository.drafts],
          ),
          batchRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('قبل'))),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const ScheduleDraftScreen(
          batchId: batchId,
          draftId: draftId,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows rows by day with times and uncertainty labels', (
    tester,
  ) async {
    final repository = _FakeRepository([draft()]);
    await openDraft(
      tester,
      repository: repository,
      detail: snapshot(),
    );

    expect(find.text('مراجعة الجدول'), findsOneWidget);
    expect(find.text('السبت'), findsOneWidget);
    expect(find.text('مراجعة رياضيات'), findsOneWidget);
    expect(find.text('رياضيات'), findsOneWidget);
    expect(find.text('٨:٠٠ ص – ٩:٠٠ ص'), findsOneWidget);
    expect(find.text('قاعة A · أ. محمد'), findsOneWidget);
    expect(find.text('مش متأكدين من: وقت النهاية'), findsOneWidget);
    expect(find.text('قراءة مش مؤكدة'), findsOneWidget);
    expect(
      find.text('صورة الجدول الأصلية محفوظة مع المسودة على الجهاز.'),
      findsOneWidget,
    );
    expect(find.text('انشر الجدول'), findsOneWidget);
    expect(find.byTooltip('حذف الجدول'), findsOneWidget);
  });

  testWidgets('publishing an unfinished draft explains what is missing', (
    tester,
  ) async {
    final repository = _FakeRepository([
      draft(entries: [entry(end: 8 * 60)])
    ])
      ..publishFailure = const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'entries',
        detail: 'incomplete rows',
      );
    await openDraft(
      tester,
      repository: repository,
      detail: snapshot(),
    );

    await tester.tap(find.text('انشر الجدول'));
    await tester.pumpAndSettle();

    expect(repository.published, [draftId]);
    expect(
      find.text('فيه حصص لسه ناقصة. كمّل وقت النهاية والعنوان الأول.'),
      findsOneWidget,
    );
  });

  testWidgets('publishing a complete draft changes the local document', (
    tester,
  ) async {
    final repository = _FakeRepository([draft()]);
    await openDraft(
      tester,
      repository: repository,
      detail: snapshot(),
    );

    await tester.tap(find.text('انشر الجدول'));
    await tester.pumpAndSettle();

    expect(repository.published, [draftId]);
    expect(find.text('الجدول اتنشر.'), findsOneWidget);
  });

  testWidgets('members see the timetable without edit controls',
      (tester) async {
    final repository = _FakeRepository([draft()]);
    await openDraft(
      tester,
      repository: repository,
      detail: snapshot(role: BatchRole.member),
    );

    expect(find.text('انشر الجدول'), findsNothing);
    expect(find.byTooltip('حذف الجدول'), findsNothing);
    expect(find.text('ضيف حصة'), findsNothing);
    expect(
      find.text(
        'انت بتشوف الجدول بس. التعديل والنشر لصاحب الدفعة أو المسؤول.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('editing a row saves it and clears the corrected uncertainty', (
    tester,
  ) async {
    final repository = _FakeRepository([draft()]);
    await openDraft(
      tester,
      repository: repository,
      detail: snapshot(),
    );

    await tester.tap(find.text('مراجعة رياضيات'));
    await tester.pumpAndSettle();

    expect(find.text('حفظ الحصة'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'مراجعة رياضيات متقدمة',
    );
    await tester.tap(find.text('حفظ الحصة'));
    await tester.pumpAndSettle();

    final saved = repository.savedEntries.single;
    expect(saved.title, 'مراجعة رياضيات متقدمة');
    expect(saved.uncertainFields, isNot(contains('title')));
    expect(saved.uncertainFields, contains('endMinutes'));
    expect(find.text('اتحفظ الجدول.'), findsOneWidget);
  });

  testWidgets('deleting asks first, then removes the draft and returns', (
    tester,
  ) async {
    final repository = _FakeRepository([draft()]);
    await openDraft(
      tester,
      repository: repository,
      detail: snapshot(),
    );

    await tester.tap(find.byTooltip('حذف الجدول'));
    await tester.pumpAndSettle();
    expect(find.text('حذف الجدول؟'), findsOneWidget);
    expect(
      find.text('الحصص وصورة الجدول هيتشالوا من الجهاز. مفيش نسخة على سيرفر.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(repository.deleted, [draftId]);
    expect(find.text('قبل'), findsOneWidget);
  });
}
