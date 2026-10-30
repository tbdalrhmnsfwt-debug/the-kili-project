/// Persists the last interactive-test attempt per PDF, on this device only.
///
/// The attempt never leaves the account's private batch directory. There is
/// no scoreboard entry and no other member can read it.
library;

import 'dart:convert';

import '../../models/study_source.dart';
import 'batch_failure.dart';
import 'batch_file_store.dart';

class StudyAttemptStore {
  StudyAttemptStore({required this.files});

  final BatchFileStore files;

  /// The same id shape the batch layer writes, so an id from a route can never
  /// escape the batch directory.
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Storing an unbounded answer map would let one attempt bloat the batch.
  static const int maxAnswerEntries = 200;

  String _relativePath(String resourceId) => 'attempts/study-$resourceId.json';

  Future<StudyAttempt?> load({
    required String uid,
    required String batchId,
    required String resourceId,
  }) async {
    if (uid.isEmpty) return null;
    _checkResourceId(resourceId);
    final bytes = await files.readBytes(
      uid: uid,
      batchId: batchId,
      relativePath: _relativePath(resourceId),
    );
    if (bytes == null) return null;
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map) return null;
      final attempt = StudyAttempt.fromJson(json.cast<String, dynamic>());
      if (attempt.resourceId != resourceId) return null;
      if (attempt.total <= 0) return null;
      if (attempt.correct < 0 || attempt.correct > attempt.total) return null;
      return attempt;
    } catch (_) {
      // A corrupt attempt is treated as absent; it is never shown as a score.
      return null;
    }
  }

  Future<void> save({
    required String uid,
    required String batchId,
    required StudyAttempt attempt,
  }) async {
    if (uid.isEmpty) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    _checkResourceId(attempt.resourceId);
    if (attempt.total <= 0) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'total',
      );
    }
    final answers = <String, int>{};
    for (final entry in attempt.answers.entries) {
      if (answers.length >= maxAnswerEntries) break;
      if (!_idPattern.hasMatch(entry.key)) continue;
      if (entry.value < 0) continue;
      answers[entry.key] = entry.value;
    }
    final bounded = StudyAttempt(
      resourceId: attempt.resourceId,
      answers: Map.unmodifiable(answers),
      correct: attempt.correct.clamp(0, attempt.total),
      total: attempt.total,
      submittedAt: attempt.submittedAt,
    );
    await files.writeBytes(
      uid: uid,
      batchId: batchId,
      relativePath: _relativePath(attempt.resourceId),
      bytes: utf8.encode(jsonEncode(bounded.toJson())),
    );
  }

  static void _checkResourceId(String resourceId) {
    if (!_idPattern.hasMatch(resourceId)) {
      throw const BatchFailure(BatchFailureCode.validationFailed);
    }
  }
}
