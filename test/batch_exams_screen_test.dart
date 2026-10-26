import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/exams/batch_exams_screen.dart';
import 'package:zaker_ai/features/batches/exams/exam_editor_screen.dart';
import 'package:zaker_ai/features/batches/exams/exam_result_screen.dart';
import 'package:zaker_ai/features/batches/exams/exam_taking_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_exam.dart';
import 'package:zaker_ai/models/exam.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';
import 'package:zaker_ai/providers/exam_providers.dart';

/// An in-memory exam surface, so widget tests never touch file I/O.
class _FakeExamRepository implements BatchRepository {
  _FakeExamRepository({
    required this.exams,
    required this.clock,
    List<ExamAttempt>? attempts,
    this.showDrafts = true,
  }) : attempts = attempts ?? [];

  List<BatchExam> exams;
  List<ExamAttempt> attempts;
  final DateTime Function() clock;
  bool showDrafts;

  final List<BatchExam> saved = [];
  final List<String> published = [];
  int starts = 0;

  @override
  Future<List<BatchExam>> loadExams(String uid, String batchId) async => [
        for (final exam in exams)
          if (showDrafts || exam.isPublished) exam,
      ];

  @override
  Future<List<ExamAttempt>> loadExamAttempts(
    String uid,
    String batchId, {
    String? examId,
  }) async =>
      [
        for (final attempt in attempts)
          if (examId == null || attempt.examId == examId) attempt,
      ];

  @override
  Future<BatchExam> saveExam(
    String uid,
    String batchId,
    BatchExam exam,
  ) async {
    final stored = BatchExam(
      id: exam.id.isEmpty ? 'exam-${exams.length + 1}' : exam.id,
      batchId: batchId,
      subjectId: exam.subjectId,
      title: exam.title.trim(),
      description: exam.description,
      durationMinutes: exam.durationMinutes,
      questions: exam.questions,
      opensAt: exam.opensAt,
      closesAt: exam.closesAt,
      publishedAt: exam.publishedAt,
      resultsMode: exam.resultsMode,
      attemptPolicy: exam.attemptPolicy,
      maxAttempts: exam.maxAttempts,
      createdBy: uid,
      createdAt: exam.createdAt,
      updatedAt: exam.updatedAt,
    );
    saved.add(stored);
    exams = [
      for (final item in exams)
        if (item.id != stored.id) item,
      stored,
    ];
    return stored;
  }

  @override
  Future<BatchExam> publishExam(
    String uid,
    String batchId,
    String examId,
  ) async {
    final index = exams.indexWhere((item) => item.id == examId);
    final publishedExam = exams[index].copyWith(
      publishedAt: clock(),
      updatedAt: clock(),
    );
    exams[index] = publishedExam;
    published.add(examId);
    return publishedExam;
  }

  @override
  Future<ExamAttempt> startAttempt(
    String uid,
    String batchId,
    String examId,
  ) async {
    final active = attempts
        .where((item) => item.examId == examId && item.isActive)
        .firstOrNull;
    if (active != null) return active;
    final exam = exams.firstWhere((item) => item.id == examId);
    starts++;
    final attempt = ExamAttempt(
      id: 'attempt-$starts',
      examId: examId,
      batchId: batchId,
      uid: uid,
      startedAt: clock(),
      deadlineAt: exam.deadlineFor(clock()),
    );
    attempts = [attempt, ...attempts];
    return attempt;
  }

  @override
  Future<ExamAttempt> saveAttemptAnswers(
    String uid,
    String batchId,
    String examId,
    String attemptId,
    Map<String, int> answers,
  ) async {
    final index = attempts.indexWhere((item) => item.id == attemptId);
    final attempt = attempts[index];
    if (attempt.isSubmitted) return attempt;
    final updated = attempt.copyWith(answers: Map.of(answers));
    attempts[index] = updated;
    return updated;
  }

  @override
  Future<ExamAttempt> submitAttempt(
    String uid,
    String batchId,
    String examId,
    String attemptId, {
    required Map<String, int> answers,
    required String clientKey,
    bool auto = false,
  }) async {
    final index = attempts.indexWhere((item) => item.id == attemptId);
    final attempt = attempts[index];
    if (attempt.isSubmitted) return attempt;
    final exam = exams.firstWhere((item) => item.id == examId);
    var correct = 0;
    for (final question in exam.questions) {
      if (answers[question.id] == question.correctIndex) correct++;
    }
    final total = exam.questions.length;
    final updated = attempt.copyWith(
      answers: Map.of(answers),
      submittedAt: clock(),
      autoSubmitted: auto,
      correctCount: correct,
      total: total,
      scorePercent: total == 0 ? 0 : correct * 100 / total,
      status: auto && answers.isEmpty
          ? ExamAttemptStatus.expired
          : ExamAttemptStatus.submitted,
      clientKey: clientKey,
    );
    attempts[index] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);
  late DateTime now;

  setUp(() {
    now = fixed;
  });

  ExamQuestion question({
    String id = 'q1',
    String prompt = 'إيه عاصمة مصر؟',
    List<String> options = const ['أسوان', 'القاهرة'],
  }) {
    return ExamQuestion(
      id: id,
      prompt: prompt,
      answerKind: AnswerKind.multipleChoice,
      options: options,
      correctIndex: 1,
      explanation: 'القاهرة هي العاصمة.',
    );
  }

  BatchExam exam({
    String id = 'exam-1',
    String title = 'امتحان الفصل الأول',
    bool published = true,
    DateTime? opensAt,
    DateTime? closesAt,
    int duration = 30,
    BatchExamResultsMode mode = BatchExamResultsMode.immediately,
    List<ExamQuestion>? questions,
  }) {
    return BatchExam(
      id: id,
      batchId: batchId,
      subjectId: '',
      title: title,
      durationMinutes: duration,
      questions: questions ?? [question()],
      opensAt: opensAt,
      closesAt: closesAt,
      publishedAt: published ? fixed : null,
      resultsMode: mode,
      createdBy: uid,
      createdAt: fixed,
      updatedAt: fixed,
    );
  }

  ExamAttempt attempt({
    String id = 'attempt-1',
    String examId = 'exam-1',
    bool submitted = false,
    Map<String, int> answers = const {},
    DateTime? deadlineAt,
  }) {
    return ExamAttempt(
      id: id,
      examId: examId,
      batchId: batchId,
      uid: uid,
      startedAt: fixed,
      deadlineAt: deadlineAt ?? fixed.add(const Duration(minutes: 30)),
      submittedAt: submitted ? fixed.add(const Duration(minutes: 5)) : null,
      answers: answers,
      correctCount: submitted ? 1 : 0,
      total: submitted ? 1 : 0,
      scorePercent: submitted ? 100 : 0,
      status:
          submitted ? ExamAttemptStatus.submitted : ExamAttemptStatus.active,
    );
  }

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

  Widget app({
    required _FakeExamRepository repository,
    required String initialLocation,
    BatchRole role = BatchRole.owner,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/batches/:batchId/exams/new',
          builder: (context, state) => ExamEditorScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/exams',
          builder: (context, state) => BatchExamsScreen(
            batchId: state.pathParameters['batchId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/exams/:examId/result',
          builder: (context, state) => ExamResultScreen(
            batchId: state.pathParameters['batchId'] ?? '',
            examId: state.pathParameters['examId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/batches/:batchId/exams/:examId',
          builder: (context, state) => ExamTakingScreen(
            batchId: state.pathParameters['batchId'] ?? '',
            examId: state.pathParameters['examId'] ?? '',
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
        batchDetailProvider
            .overrideWith((ref, id) async => snapshot(role: role)),
        batchRepositoryProvider.overrideWithValue(repository),
        examClockProvider.overrideWithValue(() => now),
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

  Future<void> open(
    WidgetTester tester, {
    required _FakeExamRepository repository,
    String location = '/batches/batch-1/exams',
    BatchRole role = BatchRole.owner,
    Size size = const Size(1000, 1600),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        repository: repository,
        initialLocation: location,
        role: role,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the list shows exams and the blocked server features', (
    tester,
  ) async {
    await open(
      tester,
      repository: _FakeExamRepository(
        clock: () => now,
        exams: [
          exam(id: 'exam-1', title: 'امتحان الفصل الأول'),
          exam(id: 'exam-2', title: 'امتحان تجريبي', published: false),
        ],
      ),
    );

    expect(find.text('امتحان الفصل الأول'), findsOneWidget);
    expect(find.text('امتحان تجريبي'), findsOneWidget);
    expect(find.text('امتحان جديد'), findsOneWidget);
    expect(
      find.textContaining('الترتيب المباشر والتحدي محتاجين سيرفر'),
      findsOneWidget,
    );
    expect(find.text('ترتيب باقي الأعضاء محتاج سيرفر.'), findsOneWidget);
    expect(find.text('التحدي المباشر'), findsOneWidget);
    expect(find.textContaining('مفيش تحدي مباشر'), findsOneWidget);
  });

  testWidgets('a reader sees only published exams and no composer', (
    tester,
  ) async {
    await open(
      tester,
      role: BatchRole.member,
      repository: _FakeExamRepository(
        clock: () => now,
        showDrafts: false,
        exams: [
          exam(id: 'exam-1', title: 'امتحان منشور'),
          exam(id: 'exam-2', title: 'مسودة', published: false),
        ],
      ),
    );

    expect(find.text('امتحان منشور'), findsOneWidget);
    expect(find.text('مسودة'), findsNothing);
    expect(find.text('امتحان جديد'), findsNothing);
  });

  testWidgets('an empty list invites the owner to author', (tester) async {
    await open(
      tester,
      repository: _FakeExamRepository(clock: () => now, exams: []),
    );

    expect(find.text('مفيش امتحانات لسه'), findsOneWidget);
    expect(find.text('اعمل امتحان'), findsOneWidget);
  });

  testWidgets('a scheduled exam cannot be started yet', (tester) async {
    await open(
      tester,
      location: '/batches/batch-1/exams/exam-1',
      repository: _FakeExamRepository(
        clock: () => now,
        exams: [
          exam(opensAt: fixed.add(const Duration(hours: 1))),
        ],
      ),
    );

    expect(find.text('الامتحان لسه مفتحش'), findsOneWidget);
    expect(find.text('ابدأ الامتحان'), findsNothing);
  });

  testWidgets('a closed exam says so and offers no start', (tester) async {
    await open(
      tester,
      location: '/batches/batch-1/exams/exam-1',
      repository: _FakeExamRepository(
        clock: () => now,
        exams: [
          exam(closesAt: fixed.subtract(const Duration(hours: 1))),
        ],
      ),
    );

    expect(find.text('الامتحان قفل'), findsOneWidget);
    expect(find.text('ابدأ الامتحان'), findsNothing);
  });

  testWidgets('answering and submitting opens the result', (tester) async {
    final repository = _FakeExamRepository(
      clock: () => now,
      exams: [exam()],
    );
    await open(
      tester,
      location: '/batches/batch-1/exams/exam-1',
      repository: repository,
    );
    expect(find.text('إيه عاصمة مصر؟'), findsNothing);
    await tester.tap(find.text('ابدأ الامتحان'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('إيه عاصمة مصر؟'), findsOneWidget);
    await tester.tap(find.text('القاهرة'));
    await tester.pump();
    await tester.tap(find.textContaining('راجع وسلّم'));
    await tester.pump();
    expect(find.text('تسليم الامتحان؟'), findsOneWidget);
    await tester.tap(find.text('سلّم'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('١٠٠٪'), findsOneWidget);
    expect(find.text('إجابتك: القاهرة'), findsOneWidget);
    expect(find.text('الإجابة الصحيحة: القاهرة'), findsOneWidget);
    expect(repository.starts, 1);
  });

  testWidgets('the clock ending auto submits exactly once', (tester) async {
    final repository = _FakeExamRepository(
      clock: () => now,
      exams: [exam(duration: 1)],
    );
    await open(
      tester,
      location: '/batches/batch-1/exams/exam-1',
      repository: repository,
    );
    await tester.tap(find.text('ابدأ الامتحان'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('القاهرة'));
    await tester.pump();

    now = fixed.add(const Duration(minutes: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('اتسلّمت لوحدها لما الوقت خلص'),
      findsOneWidget,
    );
    expect(find.text('١٠٠٪'), findsOneWidget);
    expect(repository.attempts.single.isSubmitted, isTrue);
    expect(repository.starts, 1);
  });

  testWidgets('«after close» hides the key until the close instant', (
    tester,
  ) async {
    final gated = exam(
      closesAt: fixed.add(const Duration(hours: 1)),
      mode: BatchExamResultsMode.afterClose,
    );
    final repository = _FakeExamRepository(
      clock: () => now,
      exams: [gated],
      attempts: [
        attempt(submitted: true, answers: const {'q1': 1})
      ],
    );
    await open(
      tester,
      location: '/batches/batch-1/exams/exam-1/result',
      repository: repository,
    );

    expect(find.text('النتيجة لسه مقفولة'), findsOneWidget);
    expect(find.textContaining('الإجابة الصحيحة'), findsNothing);
    expect(find.text('١٠٠٪'), findsNothing);
  });

  testWidgets('the result opens after the close instant', (tester) async {
    now = fixed.add(const Duration(hours: 2));
    final gated = exam(
      closesAt: fixed.add(const Duration(hours: 1)),
      mode: BatchExamResultsMode.afterClose,
    );
    await open(
      tester,
      location: '/batches/batch-1/exams/exam-1/result',
      repository: _FakeExamRepository(
        clock: () => now,
        exams: [gated],
        attempts: [
          attempt(submitted: true, answers: const {'q1': 1})
        ],
      ),
    );

    expect(find.text('النتيجة لسه مقفولة'), findsNothing);
    expect(find.text('١٠٠٪'), findsOneWidget);
    expect(find.text('الإجابة الصحيحة: القاهرة'), findsOneWidget);
    expect(find.textContaining('القاهرة هي العاصمة.'), findsOneWidget);
  });

  testWidgets('the editor refuses an empty exam without writing', (
    tester,
  ) async {
    final repository = _FakeExamRepository(clock: () => now, exams: []);
    await open(
      tester,
      size: const Size(1000, 2600),
      repository: repository,
    );
    await tester.tap(find.text('امتحان جديد'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ ونشر'));
    await tester.pumpAndSettle();

    expect(find.text('اكتب عنوان الامتحان.'), findsOneWidget);
    expect(repository.saved, isEmpty);
    expect(repository.published, isEmpty);
  });

  testWidgets('the editor publishes a valid exam', (tester) async {
    final repository = _FakeExamRepository(clock: () => now, exams: []);
    await open(
      tester,
      size: const Size(1000, 2600),
      repository: repository,
    );
    await tester.tap(find.text('امتحان جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'عنوان الامتحان'),
      'امتحان جديد',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'نص السؤال'),
      'إيه عاصمة مصر؟',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'اختيار ١'),
      'أسوان',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'اختيار ٢'),
      'القاهرة',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'اختيار ٣'),
      'الإسكندرية',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'اختيار ٤'),
      'أسيوط',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'تفسير الإجابة'),
      'القاهرة هي العاصمة.',
    );

    await tester.tap(find.text('حفظ ونشر'));
    await tester.pumpAndSettle();

    expect(repository.saved, hasLength(1));
    expect(repository.saved.single.title, 'امتحان جديد');
    expect(repository.saved.single.questions, hasLength(1));
    expect(repository.published, hasLength(1));
    expect(repository.exams.single.isPublished, isTrue);
  });
}
