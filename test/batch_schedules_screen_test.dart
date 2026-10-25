import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/schedule_ocr_service.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/schedules/batch_schedules_screen.dart';
import 'package:zaker_ai/features/batches/schedules/schedule_photo_picker.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_schedule.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';
import 'package:zaker_ai/providers/schedule_providers.dart';

class _FakeRepository implements BatchRepository {
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

  TimetableDraft draft(
    String id, {
    TimetableDraftStatus status = TimetableDraftStatus.draft,
    int entries = 1,
    int warnings = 0,
  }) {
    return TimetableDraft(
      id: id,
      batchId: batchId,
      sourceImageFileName: 'schedules/$id.png',
      createdAt: fixed,
      updatedAt: fixed,
      status: status,
      entries: [
        for (var i = 0; i < entries; i++)
          TimetableEntry(
            id: 'slot-$i',
            dayOfWeek: DateTime.saturday,
            startMinutes: 8 * 60 + i * 60,
            endMinutes: 9 * 60 + i * 60,
            title: 'حصة $i',
            recurrence: TimetableRecurrence.weekly,
          ),
      ],
      warnings: [
        for (var i = 0; i < warnings; i++) 'ملاحظة $i',
      ],
    );
  }

  Widget app({
    required BatchSnapshot detail,
    required Future<List<TimetableDraft>> Function() schedules,
    SchedulePhotoPicker? picker,
  }) {
    final router = GoRouter(
      initialLocation: '/batches/$batchId/schedules',
      routes: [
        GoRoute(
          path: '/batches/:batchId/schedules',
          builder: (context, state) => BatchSchedulesScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/schedules/:draftId',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('مراجعة ${state.pathParameters['draftId']}'),
            ),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
        batchDetailProvider.overrideWith((ref, id) async => detail),
        scheduleDraftsProvider.overrideWith((ref, id) => schedules()),
        batchRepositoryProvider.overrideWithValue(_FakeRepository()),
        scheduleOcrServiceProvider.overrideWithValue(
          ScheduleOcrService(
            files: BatchFileStore(root: Directory.systemTemp),
            readHocr: (_) async => '',
          ),
        ),
        if (picker != null)
          schedulePhotoPickerProvider.overrideWithValue(picker),
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

  testWidgets(
      'offers an import from the empty state and keeps a cancelled '
      'pick honest', (tester) async {
    final picks = <SchedulePhotoSource>[];
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        schedules: () async => const [],
        picker: (source) async {
          picks.add(source);
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مفيش مواعيد على الجهاز'), findsOneWidget);
    expect(
      find.textContaining('صور الجدول بتتقرا على الجهاز'),
      findsOneWidget,
    );

    await tester.tap(find.text('استورد صورة الجدول'));
    await tester.pumpAndSettle();
    expect(find.text('صوّر الجدول'), findsOneWidget);
    expect(find.text('اختار صورة من المعرض'), findsOneWidget);

    await tester.tap(find.text('اختار صورة من المعرض'));
    await tester.pumpAndSettle();

    expect(picks, [SchedulePhotoSource.gallery]);
    expect(find.text('مفيش مواعيد على الجهاز'), findsOneWidget);
  });

  testWidgets('members may read but are not offered the import', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        detail: snapshot(role: BatchRole.member),
        schedules: () async => [draft('draft-1')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('استورد صورة الجدول'), findsNothing);
    expect(find.text('مسودة جدول'), findsOneWidget);

    await tester.tap(find.text('مسودة جدول'));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة draft-1'), findsOneWidget);
  });

  testWidgets('separates the published timetable from drafts', (tester) async {
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        schedules: () async => [
          draft('published-1',
              status: TimetableDraftStatus.published, entries: 2),
          draft('draft-1', warnings: 2),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الجدول المنشور'), findsOneWidget);
    expect(find.text('جدول منشور'), findsOneWidget);
    expect(find.textContaining('٢ حصة'), findsOneWidget);
    expect(find.text('مسودات لسه مااتنشرتش'), findsOneWidget);
    expect(find.text('مسودة جدول'), findsOneWidget);
    expect(find.textContaining('٢ ملاحظة للمراجعة'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('shows a corrupt schedule document without hiding the retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        schedules: () async => throw const BatchFailure(
          BatchFailureCode.corruptStore,
          detail: 'schedule document unreadable',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مقدرناش نقرا الجدول'), findsOneWidget);
    expect(
      find.text('بيانات الدفعة اتلفت ومقدرناش نقراها.'),
      findsOneWidget,
    );
    expect(find.text('جرّب تاني'), findsOneWidget);
  });
}
