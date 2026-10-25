import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/hub_summary.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/batch_hub_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_chat.dart';
import 'package:zaker_ai/models/batch_exam.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/models/batch_schedule.dart';
import 'package:zaker_ai/models/batch_update.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

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
    int subjectCount = 2,
    int resourceCount = 0,
  }) {
    return BatchSnapshot(
      batch: Batch(
        id: batchId,
        name: 'دفعة تالتة ثانوي',
        ownerUid: ownerUid,
        createdAt: fixed,
        lastActivityAt: fixed,
        settings: const BatchSettings(),
        subjects: [
          for (var i = 0; i < subjectCount; i++)
            BatchSubject(
              id: 'subject-$i',
              name: i == 0 ? 'رياضيات' : 'فيزياء',
              order: i,
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
      resources: [
        for (var i = 0; i < resourceCount; i++)
          BatchResource(
            id: 'res-$i',
            batchId: batchId,
            subjectId: 'subject-0',
            kind: ResourceKind.pdf,
            title: 'ملزمة $i',
            fileName: 'res-$i.pdf',
            sizeBytes: 10,
            uploaderUid: ownerUid,
            createdAt: fixed.add(Duration(minutes: i)),
          ),
      ],
    );
  }

  BatchHubData hub({
    List<BatchUpdate> updates = const [],
    bool updatesAvailable = true,
    List<BatchExam> exams = const [],
    bool examsAvailable = true,
    List<TimetableDraft> schedules = const [],
    bool schedulesAvailable = true,
    ChatMessage? lastMessage,
    bool chatAvailable = true,
  }) {
    return BatchHubData(
      updates: updates,
      updatesAvailable: updatesAvailable,
      exams: exams,
      examsAvailable: examsAvailable,
      schedules: schedules,
      schedulesAvailable: schedulesAvailable,
      lastMessage: lastMessage,
      chatAvailable: chatAvailable,
    );
  }

  BatchUpdate update(String id, String title, {bool read = false}) {
    return BatchUpdate(
      id: id,
      batchId: batchId,
      authorUid: uid,
      authorName: 'طالب',
      title: title,
      body: '',
      createdAt: fixed,
      kind: BatchUpdateKind.announcement,
      readBy: read ? {uid} : const {},
    );
  }

  BatchExam exam(String title) {
    return BatchExam(
      id: 'exam-1',
      batchId: batchId,
      subjectId: 'subject-0',
      title: title,
      durationMinutes: 30,
      questions: const [],
      createdBy: uid,
      createdAt: fixed,
      updatedAt: fixed,
      publishedAt: fixed,
    );
  }

  TimetableDraft schedule(
      {TimetableDraftStatus status = TimetableDraftStatus.draft}) {
    return TimetableDraft(
      id: 'draft-1',
      batchId: batchId,
      sourceImageFileName: 'table.png',
      createdAt: fixed,
      updatedAt: fixed,
      status: status,
      entries: const [],
    );
  }

  ChatMessage message(String text) {
    return ChatMessage(
      id: 'msg-1',
      batchId: batchId,
      channelId: 'main',
      authorUid: uid,
      authorName: 'طالب',
      kind: ChatMessageKind.text,
      createdAt: fixed,
      text: text,
    );
  }

  Widget app({
    required BatchSnapshot detail,
    required BatchHubData data,
  }) {
    final router = GoRouter(
      initialLocation: '/batches/$batchId',
      routes: [
        GoRoute(
          path: '/batches/:batchId',
          builder: (context, state) => BatchHubScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/subjects',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('المواد هنا'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
        batchDetailProvider.overrideWith((ref, id) async => detail),
        batchHubDataProvider.overrideWith((ref, id) async => data),
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

  testWidgets('renders the four sections in order with an honest header',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(resourceCount: 1),
        data: hub(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('دفعة تالتة ثانوي'), findsOneWidget);
    expect(find.text('صاحب الدفعة'), findsOneWidget);
    expect(find.text('عضو واحد على الجهاز'), findsOneWidget);
    expect(find.text('1234 5678'), findsOneWidget);
    expect(find.text('٢ مادة · ١ ملف'), findsOneWidget);
    expect(find.text('لسه مفيش رسائل'), findsOneWidget);
    expect(find.text('محادثة على الجهاز'), findsOneWidget);

    final materials = tester.getTopLeft(find.text('المواد')).dy;
    final schedules = tester.getTopLeft(find.text('المواعيد')).dy;
    final updates = tester.getTopLeft(find.text('المستجدات')).dy;
    final exams = tester.getTopLeft(find.text('امتحانات')).dy;
    expect(materials, lessThan(schedules));
    expect(schedules, lessThan(updates));
    expect(updates, lessThan(exams));
  });

  testWidgets('shows the empty state of each collection', (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        data: hub(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مفيش مواعيد لسه.'), findsOneWidget);
    expect(find.text('مفيش مستجدات لسه.'), findsOneWidget);
    expect(find.text('مفيش امتحانات لسه.'), findsOneWidget);
    expect(find.text('لسه مفيش رسائل'), findsOneWidget);
  });

  testWidgets('keeps a corrupt collection isolated from the rest',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        data: hub(
          updatesAvailable: false,
          schedulesAvailable: false,
          exams: [exam('امتحان الأسبوع')],
          chatAvailable: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مقدرناش نقرا ملف المستجدات.'), findsOneWidget);
    expect(find.text('مقدرناش نقرا ملف المواعيد.'), findsOneWidget);
    expect(find.text('مقدرناش نقرا المحادثة.'), findsOneWidget);
    expect(find.text('امتحان الأسبوع'), findsOneWidget);
    expect(find.text('١ امتحان'), findsOneWidget);
    expect(find.text('مقدرناش نقرا ملف الامتحانات.'), findsNothing);
    expect(find.text('المواد'), findsOneWidget);
  });

  testWidgets('shows the latest update, its unread badge and the last message',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        data: hub(
          updates: [
            update('u1', 'مستجد قديم', read: true),
            update('u2', 'مراجعة يوم الخميس'),
          ],
          lastMessage: message('هنبدأ الساعة سبعة'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مراجعة يوم الخميس'), findsOneWidget);
    expect(find.text('1 جديد'), findsOneWidget);
    expect(find.text('طالب: هنبدأ الساعة سبعة'), findsOneWidget);
  });

  testWidgets('does not count a timetable draft as a published schedule',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        data: hub(schedules: [schedule()]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('فيه جدول لسه مسودة ومااتنشرش.'), findsOneWidget);
    expect(find.text('مفيش حصص منشورة'), findsOneWidget);
  });

  testWidgets('opens the subjects screen from the materials card',
      (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(),
        data: hub(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('المواد'));
    await tester.pumpAndSettle();

    expect(find.text('المواد هنا'), findsOneWidget);
  });

  testWidgets('hides the owner code from a non-owner', (tester) async {
    await tallScreen(tester);
    await tester.pumpWidget(
      app(
        detail: snapshot(ownerUid: 'someone-else'),
        data: hub(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('كود الدعوة'), findsNothing);
    expect(find.text('عضو'), findsOneWidget);
  });
}
