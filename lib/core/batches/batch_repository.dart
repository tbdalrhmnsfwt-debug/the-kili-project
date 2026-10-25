/// The batch command surface.
///
/// [LocalBatchRepository] is the only implementation in this build. A future
/// server-backed repository implements the same methods; screens never read
/// files or know where a batch is stored.
library;

import '../../models/batch.dart';
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

  Future<void> deleteSubject(String uid, String batchId, String subjectId);

  Future<InviteCodeState> rotateCode(String uid, String batchId);

  Future<InviteCodeState> revokeCode(String uid, String batchId);

  Future<void> deleteBatch(String uid, String batchId);

  Future<int> storageUsed(String uid, String batchId);
}
