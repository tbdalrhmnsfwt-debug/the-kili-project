/// Exam state: the visible exams, this account's attempts, and the commands
/// the screens drive.
///
/// Every instant here comes from the device clock. Server-authoritative
/// timing, live ranking and the live challenge stay blocked.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/batches/batch_failure.dart';
import '../core/batches/batch_repository.dart';
import '../models/batch_exam.dart';
import 'app_providers.dart';
import 'batch_providers.dart';

/// The batch and exam a screen is about.
typedef BatchExamArgs = ({String batchId, String examId});

String _currentUid(Ref ref) => ref.watch(authUserProvider)?.uid ?? '';

/// The clock every countdown is measured against, so a test can move time.
final examClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Published exams, plus drafts for managers.
final batchExamsProvider = FutureProvider.autoDispose
    .family<List<BatchExam>, String>((ref, batchId) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return const [];
  return ref.watch(batchRepositoryProvider).loadExams(uid, batchId);
});

/// One visible exam.
final batchExamProvider = FutureProvider.autoDispose
    .family<BatchExam, BatchExamArgs>((ref, args) async {
  final exams = await ref.watch(batchExamsProvider(args.batchId).future);
  for (final exam in exams) {
    if (exam.id == args.examId) return exam;
  }
  throw const BatchFailure(BatchFailureCode.notFound, field: 'examId');
});

/// This account's attempts across the whole batch, newest first.
final batchExamAttemptsProvider = FutureProvider.autoDispose
    .family<List<ExamAttempt>, String>((ref, batchId) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return const [];
  return ref.watch(batchRepositoryProvider).loadExamAttempts(uid, batchId);
});

/// The commands the exams screens call.
class BatchExamsController {
  BatchExamsController(this._ref);

  final Ref _ref;

  BatchRepository get _repository => _ref.read(batchRepositoryProvider);
  String get _uid => _ref.read(authUserProvider)?.uid ?? '';

  Future<BatchExam> save(String batchId, BatchExam exam) async {
    final saved = await _repository.saveExam(_uid, batchId, exam);
    _refreshExam(batchId);
    return saved;
  }

  Future<BatchExam> publish(String batchId, String examId) async {
    final published = await _repository.publishExam(_uid, batchId, examId);
    _refreshExam(batchId);
    return published;
  }

  Future<ExamAttempt> start(String batchId, String examId) async {
    final attempt = await _repository.startAttempt(_uid, batchId, examId);
    _refreshAttempts(batchId);
    return attempt;
  }

  Future<ExamAttempt> saveAnswers(
    String batchId,
    String examId,
    String attemptId,
    Map<String, int> answers,
  ) {
    return _repository.saveAttemptAnswers(
      _uid,
      batchId,
      examId,
      attemptId,
      answers,
    );
  }

  Future<ExamAttempt> submit(
    String batchId,
    String examId,
    String attemptId,
    Map<String, int> answers, {
    bool auto = false,
  }) async {
    final attempt = await _repository.submitAttempt(
      _uid,
      batchId,
      examId,
      attemptId,
      answers: answers,
      clientKey: 'attempt:$attemptId',
      auto: auto,
    );
    _refreshAttempts(batchId);
    return attempt;
  }

  void _refreshExam(String batchId) {
    _ref.invalidate(batchExamsProvider(batchId));
    _ref.invalidate(batchExamProvider);
    _ref.invalidate(batchHubDataProvider(batchId));
    _ref.invalidate(batchListProvider);
  }

  void _refreshAttempts(String batchId) {
    _ref.invalidate(batchExamAttemptsProvider(batchId));
    _ref.invalidate(batchHubDataProvider(batchId));
  }
}

final batchExamsControllerProvider =
    Provider<BatchExamsController>(BatchExamsController.new);
