/// The batch command surface.
///
/// [LocalBatchRepository] is the only implementation in this build. A future
/// server-backed repository implements the same methods; screens never read
/// files or know where a batch is stored.
library;

import '../../models/batch.dart';
import '../../models/batch_chat.dart';
import '../../models/batch_exam.dart';
import '../../models/batch_resource.dart';
import '../../models/batch_schedule.dart';
import '../../models/batch_update.dart';
import 'batch_failure.dart';
import 'batch_store.dart';

/// A row on the batches list.
class BatchSummary {
  const BatchSummary({
    required this.batchId,
    this.batch,
    this.resourceCount = 0,
    this.unreadUpdates = 0,
    this.failure,
  });

  final String batchId;

  /// Null when the batch document could not be read.
  final Batch? batch;
  final int resourceCount;
  final int unreadUpdates;
  final BatchFailure? failure;

  bool get isAvailable => batch != null;
  String get name => batch?.name ?? '';
  DateTime get lastActivityAt =>
      batch?.lastActivityAt ??
      batch?.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// How a typed invite code matched the local batch documents.
enum CodeMatchKind {
  /// No local batch has this code.
  none,

  /// A batch on this account has this active code.
  active,

  /// A batch on this account kept this code but it was revoked.
  revoked,
}

/// The result of looking up a code without creating a membership.
class CodeMatch {
  const CodeMatch.none()
      : kind = CodeMatchKind.none,
        snapshot = null;

  const CodeMatch.active(BatchSnapshot this.snapshot)
      : kind = CodeMatchKind.active;

  const CodeMatch.revoked()
      : kind = CodeMatchKind.revoked,
        snapshot = null;

  final CodeMatchKind kind;
  final BatchSnapshot? snapshot;
}

/// Commands shared by the local and future remote repositories.
///
/// Every method validates its input, re-checks the access matrix when a
/// membership exists, and throws [BatchFailure] rather than returning a
/// partial success.
abstract interface class BatchRepository {
  Future<List<BatchSummary>> listBatches(String uid);

  /// Loads one batch and verifies the current uid is a reader.
  Future<BatchSnapshot> loadBatch(String uid, String batchId);

  Future<Batch> createBatch({
    required String uid,
    required String displayName,
    required String name,
    required List<String> subjects,
    BatchSettings settings = const BatchSettings(),
  });

  Future<Batch> updateSettings(
    String uid,
    String batchId,
    BatchSettings settings,
  );

  Future<BatchSubject> addSubject(String uid, String batchId, String name);

  Future<void> renameSubject(
    String uid,
    String batchId,
    String subjectId,
    String name,
  );

  Future<void> deleteSubject(
    String uid,
    String batchId,
    String subjectId, {
    String? moveToSubjectId,
    bool deleteResources = false,
  });

  /// Indexes an already copied resource. The caller owns the file.
  Future<BatchResource> addResource(
    String uid,
    String batchId,
    BatchResource resource,
  );

  /// Removes the index entry and then its private files.
  Future<void> deleteResource(String uid, String batchId, String resourceId);

  /// Stars or unstars a resource for the current uid only.
  Future<BatchResource> setStarred(
    String uid,
    String batchId,
    String resourceId,
    bool starred,
  );

  /// Every timetable draft and published timetable the reader may see.
  Future<List<TimetableDraft>> loadSchedules(String uid, String batchId);

  /// Inserts or replaces one draft. New drafts need import rights; changes to
  /// an existing draft need edit rights.
  Future<TimetableDraft> saveScheduleDraft(
    String uid,
    String batchId,
    TimetableDraft draft,
  );

  /// Publishes a draft after requiring every row to be complete.
  Future<TimetableDraft> publishScheduleDraft(
    String uid,
    String batchId,
    String draftId,
  );

  /// Removes a draft and then its private photo.
  Future<void> deleteScheduleDraft(
    String uid,
    String batchId,
    String draftId,
  );

  /// Every update the reader may see, pinned first and newest first.
  Future<List<BatchUpdate>> loadUpdates(String uid, String batchId);

  /// Posts an announcement authored by [uid].
  Future<BatchUpdate> publishUpdate(
    String uid,
    String batchId, {
    required String title,
    required String body,
  });

  /// Rewrites an existing update and records the edit time.
  Future<BatchUpdate> editUpdate(
    String uid,
    String batchId,
    String updateId, {
    required String title,
    required String body,
  });

  Future<void> deleteUpdate(String uid, String batchId, String updateId);

  /// Marks the update read by [uid]. Repeating it changes nothing.
  Future<BatchUpdate> markUpdateRead(
    String uid,
    String batchId,
    String updateId,
  );

  /// Published exams for readers; managers also see drafts.
  Future<List<BatchExam>> loadExams(String uid, String batchId);

  /// Creates or updates a draft. A published exam is never rewritten.
  Future<BatchExam> saveExam(String uid, String batchId, BatchExam exam);

  /// Makes a draft visible to members. Idempotent for a published exam.
  Future<BatchExam> publishExam(String uid, String batchId, String examId);

  /// This account's attempts, newest first, for one exam or the whole batch.
  Future<List<ExamAttempt>> loadExamAttempts(
    String uid,
    String batchId, {
    String? examId,
  });

  /// Starts a new attempt, or resumes the running one.
  Future<ExamAttempt> startAttempt(String uid, String batchId, String examId);

  /// Saves answers while the attempt runs, so a restart does not lose them.
  Future<ExamAttempt> saveAttemptAnswers(
    String uid,
    String batchId,
    String examId,
    String attemptId,
    Map<String, int> answers,
  );

  /// Scores and closes an attempt. A second submit is a no-op.
  Future<ExamAttempt> submitAttempt(
    String uid,
    String batchId,
    String examId,
    String attemptId, {
    required Map<String, int> answers,
    required String clientKey,
    bool auto = false,
  });

  /// The newest chat messages older than [before].
  Future<ChatPage> loadChat(
    String uid,
    String batchId, {
    ChatCursor? before,
    int limit = 30,
  });

  /// Appends [message]; a repeated client key returns the stored one.
  Future<ChatMessage> sendChatMessage(
    String uid,
    String batchId,
    ChatMessage message,
  );

  Future<ChatMessage> editChatMessage(
    String uid,
    String batchId,
    String messageId,
    String text,
  );

  /// Leaves a tombstone and removes any voice file. Never logs the text.
  Future<ChatMessage> deleteChatMessage(
    String uid,
    String batchId,
    String messageId,
  );

  Future<ChatMessage> reactToChatMessage(
    String uid,
    String batchId,
    String messageId,
    String emoji,
    bool reacted,
  );

  Future<ChatMessage> pinChatMessage(
    String uid,
    String batchId,
    String messageId,
    bool pinned,
  );

  Future<InviteCodeState> rotateCode(String uid, String batchId);

  Future<InviteCodeState> revokeCode(String uid, String batchId);

  Future<void> deleteBatch(String uid, String batchId);

  Future<int> storageUsed(String uid, String batchId);
}
