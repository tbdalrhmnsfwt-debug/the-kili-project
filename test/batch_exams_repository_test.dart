import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/local_batch_repository.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_exam.dart';
import 'package:zaker_ai/models/exam.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _SequenceRandom implements Random {
  _SequenceRandom(this.values);

  final List<int> values;
  int _index = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    final value = values[_index % values.length];
    _index++;
    return value % max;
  }
}

void main() {
  late Directory root;
  late BatchFileStore files;
  late _MemoryStore keyValues;
  late LocalBatchRepository repository;
  late Batch batch;
  const uid = 'guest-0123456789';
  final start = DateTime.utc(2026, 10, 25, 8);
  late DateTime now;

  LocalBatchRepository buildRepository() {
    return LocalBatchRepository(
      files: files,
      store: keyValues,
      codes: BatchCodeService(
        random: _SequenceRandom([1, 2, 3, 4, 5, 6, 7, 8]),
      ),
      clock: () => now,
    );
  }

  BatchStore batchStore() =>
      BatchStore(directory: files.batchDir(uid, batch.id));

  Future<void> setRole(BatchRole role) async {
    final document = batchStore();
    final load = await document.batch.load();
    final snapshot = load.value!;
    await document.batch.save(
      snapshot.copyWith(
        members: [
          for (final member in snapshot.members)
            if (member.uid == uid)
              Membership(
                batchId: member.batchId,
                uid: member.uid,
                displayName: member.displayName,
                role: role,
                joinedAt: member.joinedAt,
              )
            else
              member,
        ],
      ),
    );
  }

  ExamQuestion question({
    String id = 'q1',
    String prompt = 'إيه الإجابة؟',
    List<String> options = const ['أ', 'ب'],
    int correct = 0,
  }) {
    return ExamQuestion(
      id: id,
      prompt: prompt,
      answerKind: AnswerKind.multipleChoice,
      options: options,
      correctIndex: correct,
      explanation: 'لأن كده.',
    );
  }

  BatchExam exam({
    String title = 'امتحان الفصل الأول',
    int duration = 30,
    List<ExamQuestion>? questions,
    DateTime? opensAt,
    DateTime? closesAt,
    BatchExamResultsMode mode = BatchExamResultsMode.immediately,
    BatchExamAttemptPolicy policy = BatchExamAttemptPolicy.single,
    int maxAttempts = 1,
  }) {
    return BatchExam(
      id: '',
      batchId: batch.id,
      subjectId: '',
      title: title,
      durationMinutes: duration,
      questions: questions ?? [question()],
      opensAt: opensAt,
      closesAt: closesAt,
      resultsMode: mode,
      attemptPolicy: policy,
      maxAttempts: maxAttempts,
      createdBy: uid,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<BatchExam> publish(BatchExam draft) async {
    final saved = await repository.saveExam(uid, batch.id, draft);
    return repository.publishExam(uid, batch.id, saved.id);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_exams_');
    files = BatchFileStore(root: root);
    keyValues = _MemoryStore();
    now = start;
    repository = buildRepository();
    batch = await repository.createBatch(
      uid: uid,
      displayName: 'طالب',
      name: 'دفعة',
      subjects: const ['رياضيات'],
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Matcher failure(BatchFailureCode code, {String? field}) => isA<BatchFailure>()
      .having((item) => item.code, 'code', code)
      .having((item) => item.field, 'field', field);

  test('drafts are visible to managers and hidden from members', () async {
    final draft = await repository.saveExam(uid, batch.id, exam());
    expect(await repository.loadExams(uid, batch.id), hasLength(1));
    expect(draft.isPublished, isFalse);

    await setRole(BatchRole.member);
    expect(await repository.loadExams(uid, batch.id), isEmpty);

    await setRole(BatchRole.owner);
    await repository.publishExam(uid, batch.id, draft.id);
    await setRole(BatchRole.member);
    final visible = await repository.loadExams(uid, batch.id);
    expect(visible.single.id, draft.id);
    expect(visible.single.isPublished, isTrue);
  });

  test('authoring refuses an empty prompt and duplicate options', () async {
    await expectLater(
      repository.saveExam(
        uid,
        batch.id,
        exam(questions: [question(prompt: '   ')]),
      ),
      throwsA(failure(BatchFailureCode.validationFailed, field: 'prompt')),
    );
    await expectLater(
      repository.saveExam(
        uid,
        batch.id,
        exam(
          questions: [
            question(options: const ['أ', 'أ']),
          ],
        ),
      ),
      throwsA(failure(BatchFailureCode.validationFailed, field: 'options')),
    );
    expect(await repository.loadExams(uid, batch.id), isEmpty);
  });

  test('«after close» requires a close instant and a sane window', () async {
    await expectLater(
      repository.saveExam(
        uid,
        batch.id,
        exam(mode: BatchExamResultsMode.afterClose),
      ),
      throwsA(
        failure(BatchFailureCode.examWindowInvalid, field: 'closesAt'),
      ),
    );
    await expectLater(
      repository.saveExam(
        uid,
        batch.id,
        exam(
          opensAt: start.add(const Duration(hours: 2)),
          closesAt: start.add(const Duration(hours: 1)),
        ),
      ),
      throwsA(failure(BatchFailureCode.examWindowInvalid, field: 'window')),
    );
  });

  test('a published exam is never rewritten', () async {
    final published = await publish(exam());
    await expectLater(
      repository.saveExam(
        uid,
        batch.id,
        published.copyWith(title: 'عنوان جديد'),
      ),
      throwsA(failure(BatchFailureCode.conflict, field: 'exam')),
    );
  });

  test('start is refused outside the availability window', () async {
    final scheduled = await repository.saveExam(
      uid,
      batch.id,
      exam(opensAt: start.add(const Duration(hours: 1))),
    );
    await repository.publishExam(uid, batch.id, scheduled.id);
    await expectLater(
      repository.startAttempt(uid, batch.id, scheduled.id),
      throwsA(failure(BatchFailureCode.examNotOpen)),
    );

    final closed = BatchExam(
      id: 'exam_closed',
      batchId: batch.id,
      subjectId: '',
      title: 'مقفول',
      durationMinutes: 30,
      questions: [question()],
      publishedAt: start.subtract(const Duration(hours: 2)),
      closesAt: start.subtract(const Duration(hours: 1)),
      resultsMode: BatchExamResultsMode.immediately,
      createdBy: uid,
      createdAt: start.subtract(const Duration(hours: 3)),
      updatedAt: start.subtract(const Duration(hours: 3)),
    );
    await batchStore().exams.save([closed]);
    await expectLater(
      repository.startAttempt(uid, batch.id, closed.id),
      throwsA(failure(BatchFailureCode.examClosed)),
    );
  });

  test('the persisted deadline is the earlier of limit and close', () async {
    final open = await publish(
      exam(opensAt: start.subtract(const Duration(minutes: 5))),
    );
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    expect(attempt.deadlineAt, now.add(const Duration(minutes: 30)));

    now = start.add(const Duration(minutes: 1));
    final resumed = await repository.startAttempt(uid, batch.id, open.id);
    expect(resumed.id, attempt.id);
    expect(resumed.deadlineAt, attempt.deadlineAt);

    final capped = await publish(
      exam(
        duration: 60,
        closesAt: start.add(const Duration(minutes: 10)),
      ),
    );
    final cappedAttempt =
        await repository.startAttempt(uid, batch.id, capped.id);
    expect(cappedAttempt.deadlineAt, start.add(const Duration(minutes: 10)));
  });

  test('an expired attempt closes by itself when the student returns',
      () async {
    final open = await publish(
      exam(
        duration: 10,
        policy: BatchExamAttemptPolicy.unlimited,
      ),
    );
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    await repository.saveAttemptAnswers(
      uid,
      batch.id,
      open.id,
      attempt.id,
      {'q1': 1},
    );

    now = start.add(const Duration(minutes: 11));
    final next = await repository.startAttempt(uid, batch.id, open.id);
    expect(next.id, isNot(attempt.id));

    final stored = await repository.loadExamAttempts(uid, batch.id);
    final closed = stored.firstWhere((item) => item.id == attempt.id);
    expect(closed.isSubmitted, isTrue);
    expect(closed.autoSubmitted, isTrue);
    expect(closed.status, ExamAttemptStatus.submitted);
    expect(closed.answers, {'q1': 1});
    expect(closed.correctCount, 0);
    expect(closed.scorePercent, 0);
  });

  test('an expired attempt with no answers is recorded as expired', () async {
    final open = await publish(exam(duration: 10));
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    now = start.add(const Duration(minutes: 11));
    await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {},
      clientKey: 'auto',
      auto: true,
    );
    final stored = (await repository.loadExamAttempts(uid, batch.id)).single;
    expect(stored.status, ExamAttemptStatus.expired);
    expect(stored.autoSubmitted, isTrue);
    expect(stored.scorePercent, 0);
  });

  test('a second submit is a no-op even with different answers', () async {
    final open = await publish(exam());
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    final first = await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 0},
      clientKey: 'one',
    );
    final second = await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 1},
      clientKey: 'two',
    );
    expect(second.answers, {'q1': 0});
    expect(second.submittedAt, first.submittedAt);
    expect(second.scorePercent, 100);
    expect(second.clientKey, 'one');
  });

  test('scoring rounds half up with no speed bonus', () async {
    final questions = [
      for (var index = 1; index <= 3; index++)
        question(
          id: 'q$index',
          prompt: 'سؤال $index',
          options: const ['صح', 'غلط'],
        ),
    ];
    final open = await publish(exam(questions: questions));
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    final result = await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 0, 'q2': 1, 'q3': 0},
      clientKey: 'score',
    );
    expect(result.correctCount, 2);
    expect(result.total, 3);
    expect(result.scorePercent, 67);
    expect(result.status, ExamAttemptStatus.submitted);
  });

  test('one correct answer out of eight rounds 12.5 up to 13', () async {
    final questions = [
      for (var index = 1; index <= 8; index++)
        question(id: 'q$index', prompt: 'سؤال $index'),
    ];
    final open = await publish(exam(questions: questions));
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    final result = await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 0},
      clientKey: 'round',
    );
    expect(result.scorePercent, 13);
    expect(result.correctCount, 1);
  });

  test('unknown questions or options are refused', () async {
    final open = await publish(exam());
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    await expectLater(
      repository.submitAttempt(
        uid,
        batch.id,
        open.id,
        attempt.id,
        answers: const {'q_missing': 0},
        clientKey: 'bad',
      ),
      throwsA(failure(BatchFailureCode.validationFailed, field: 'answers')),
    );
    await expectLater(
      repository.submitAttempt(
        uid,
        batch.id,
        open.id,
        attempt.id,
        answers: const {'q1': 5},
        clientKey: 'bad',
      ),
      throwsA(failure(BatchFailureCode.validationFailed, field: 'answers')),
    );
    final stored = await repository.loadExamAttempts(uid, batch.id);
    expect(stored, hasLength(1));
    expect(stored.single.isSubmitted, isFalse);
  });

  test('saved answers survive until the student resumes', () async {
    final open = await publish(exam());
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    await repository.saveAttemptAnswers(
      uid,
      batch.id,
      open.id,
      attempt.id,
      {'q1': 1},
    );
    final resumed = await repository.startAttempt(uid, batch.id, open.id);
    expect(resumed.id, attempt.id);
    expect(resumed.answers, {'q1': 1});
  });

  test('one attempt is the default and a second start is refused', () async {
    final open = await publish(exam());
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 0},
      clientKey: 'one',
    );
    await expectLater(
      repository.startAttempt(uid, batch.id, open.id),
      throwsA(failure(BatchFailureCode.conflict, field: 'attempts')),
    );
  });

  test('a limited exam allows its cap and then refuses', () async {
    final open = await publish(
      exam(
        policy: BatchExamAttemptPolicy.limited,
        maxAttempts: 2,
      ),
    );
    for (var index = 0; index < 2; index++) {
      final attempt = await repository.startAttempt(uid, batch.id, open.id);
      await repository.submitAttempt(
        uid,
        batch.id,
        open.id,
        attempt.id,
        answers: const {'q1': 0},
        clientKey: 'attempt-$index',
      );
    }
    await expectLater(
      repository.startAttempt(uid, batch.id, open.id),
      throwsA(failure(BatchFailureCode.conflict, field: 'attempts')),
    );
  });

  test('the attempt history keeps the newest twenty', () async {
    final open = await publish(
      exam(policy: BatchExamAttemptPolicy.unlimited),
    );
    for (var index = 0; index < 21; index++) {
      final attempt = await repository.startAttempt(uid, batch.id, open.id);
      await repository.submitAttempt(
        uid,
        batch.id,
        open.id,
        attempt.id,
        answers: const {'q1': 0},
        clientKey: 'attempt-$index',
      );
      now = now.add(const Duration(seconds: 1));
    }
    final history = await repository.loadExamAttempts(uid, batch.id);
    expect(history, hasLength(LocalBatchRepository.maxAttemptsPerExam));
    final directory = Directory(
      '${batchStore().attemptsDirectory.path}/${open.id}',
    );
    final count = await directory
        .list()
        .where((entity) => entity.path.endsWith('.json'))
        .length;
    expect(count, LocalBatchRepository.maxAttemptsPerExam);
  });

  test('a member cannot author, publish or start, but may read', () async {
    final open = await publish(exam());
    await setRole(BatchRole.member);
    await expectLater(
      repository.saveExam(uid, batch.id, exam(title: 'تاني')),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
    await expectLater(
      repository.publishExam(uid, batch.id, open.id),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
    expect(await repository.loadExams(uid, batch.id), hasLength(1));
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    expect(attempt.examId, open.id);
  });

  test('a muted member keeps results and loses the start action', () async {
    final open = await publish(exam());
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 0},
      clientKey: 'muted',
    );
    await setRole(BatchRole.muted);
    expect(await repository.loadExamAttempts(uid, batch.id), hasLength(1));
    await expectLater(
      repository.startAttempt(uid, batch.id, open.id),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
  });

  test('a pending or removed account reads nothing', () async {
    await publish(exam());
    await setRole(BatchRole.pending);
    await expectLater(
      repository.loadExams(uid, batch.id),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
    await setRole(BatchRole.removed);
    await expectLater(
      repository.loadExamAttempts(uid, batch.id),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
  });

  test('an account outside the workspace reads no attempts', () async {
    final open = await publish(exam());
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 0},
      clientKey: 'one',
    );
    await expectLater(
      repository.loadExamAttempts('guest-other', batch.id),
      throwsA(failure(BatchFailureCode.notFound)),
    );
  });

  test('a corrupt exam document is reported, not replaced', () async {
    await batchStore().examsFile.parent.create(recursive: true);
    await batchStore().examsFile.writeAsString('{not json');
    await expectLater(
      repository.loadExams(uid, batch.id),
      throwsA(failure(BatchFailureCode.corruptStore)),
    );
    expect(await batchStore().examsFile.exists(), isFalse);
  });

  test('a missing exam id is not found', () async {
    await expectLater(
      repository.startAttempt(uid, batch.id, 'exam_missing'),
      throwsA(failure(BatchFailureCode.notFound, field: 'examId')),
    );
    expect(
      await repository.loadExamAttempts(uid, batch.id, examId: 'exam_missing'),
      isEmpty,
    );
  });

  test('the audit trail carries no question or answer text', () async {
    final open = await publish(
      exam(
        questions: [
          question(prompt: 'سؤال سرّي', options: const ['إيه', 'مش ده']),
        ],
      ),
    );
    final attempt = await repository.startAttempt(uid, batch.id, open.id);
    await repository.submitAttempt(
      uid,
      batch.id,
      open.id,
      attempt.id,
      answers: const {'q1': 0},
      clientKey: 'audit',
    );
    final audit = await batchStore().audit.load();
    final encoded = jsonEncode([
      for (final entry in audit.value ?? const <AuditEntry>[]) entry.toJson(),
    ]);
    expect(encoded, contains('examPublished'));
    expect(encoded, contains('examAttemptSubmitted'));
    expect(encoded, isNot(contains('سؤال سرّي')));
    expect(encoded, isNot(contains('إيه')));
  });
}
