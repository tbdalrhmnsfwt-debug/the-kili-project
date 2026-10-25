/// Moves guest batches into a signed-in account when the person asks.
///
/// Nothing moves automatically. The service lists what is claimable, remembers
/// which batch ids were declined per (guest, account) pair, and delegates the
/// atomic per-batch move to [LocalBatchRepository.claimBatch].
library;

import 'dart:convert';

import '../../models/batch.dart';
import '../key_value_store.dart';
import 'batch_failure.dart';
import 'batch_repository.dart';
import 'local_batch_repository.dart';

/// One batch that could not be moved.
class BatchClaimFailure {
  const BatchClaimFailure(this.batchId, this.failure);

  final String batchId;
  final BatchFailure failure;
}

/// Which batches moved and which did not.
class BatchClaimResult {
  const BatchClaimResult({required this.moved, required this.failed});

  final List<String> moved;
  final List<BatchClaimFailure> failed;

  int get movedCount => moved.length;
  int get failedCount => failed.length;
  bool get isEmpty => moved.isEmpty && failed.isEmpty;
}

class BatchClaimService {
  BatchClaimService({required this.repository, required this.store});

  final LocalBatchRepository repository;
  final KeyValueStore store;

  static const int _declinedCap = 100;

  /// Guest batches that are not already in the account and were not declined.
  Future<List<Batch>> promptBatches({
    required String guestUid,
    required String accountUid,
  }) async {
    if (guestUid.isEmpty || accountUid.isEmpty || guestUid == accountUid) {
      return const [];
    }
    List<BatchSummary> summaries;
    try {
      summaries = await repository.listBatches(guestUid);
    } on BatchFailure {
      return const [];
    }

    final declined = _declinedIds(guestUid, accountUid);
    final claimable = <Batch>[];
    for (final summary in summaries) {
      final batch = summary.batch;
      if (batch == null || batch.ownerUid != guestUid) continue;
      if (declined.contains(batch.id)) continue;
      try {
        final target = repository.files.batchDir(accountUid, batch.id);
        if (await target.exists()) continue;
      } on BatchFailure {
        continue;
      }
      claimable.add(batch);
    }
    return claimable;
  }

  Future<bool> shouldPrompt({
    required String guestUid,
    required String accountUid,
  }) async {
    final batches = await promptBatches(
      guestUid: guestUid,
      accountUid: accountUid,
    );
    return batches.isNotEmpty;
  }

  /// Remembers «سيبها على الضيف» for these ids so the same batches stop
  /// prompting. A later guest batch gets a new opportunity.
  Future<void> decline({
    required String guestUid,
    required String accountUid,
    required List<String> batchIds,
  }) async {
    if (guestUid.isEmpty || accountUid.isEmpty) return;
    final markers = _readMarkers(guestUid);
    final ids = <String>{...markers[accountUid] ?? const <String>[]};
    ids.addAll(batchIds);
    final capped = ids.length > _declinedCap
        ? ids.toList().sublist(ids.length - _declinedCap)
        : ids.toList();
    markers[accountUid] = capped;
    await _writeMarkers(guestUid, markers);
  }

  Future<BatchClaimResult> claim({
    required String guestUid,
    required String accountUid,
    required List<String> batchIds,
  }) async {
    final moved = <String>[];
    final failed = <BatchClaimFailure>[];
    for (final batchId in batchIds.toSet()) {
      try {
        await repository.claimBatch(
          guestUid: guestUid,
          accountUid: accountUid,
          batchId: batchId,
        );
        moved.add(batchId);
      } on BatchFailure catch (failure) {
        failed.add(BatchClaimFailure(batchId, failure));
      } catch (_) {
        failed.add(
          BatchClaimFailure(
            batchId,
            const BatchFailure(BatchFailureCode.claimFailed),
          ),
        );
      }
    }
    if (moved.isNotEmpty) {
      await _forgetDeclined(guestUid, accountUid, moved);
    }
    return BatchClaimResult(moved: moved, failed: failed);
  }

  static String _declinedKey(String guestUid) => 'batches.claim.v1.$guestUid';

  Map<String, List<String>> _readMarkers(String guestUid) {
    final raw = store.getString(_declinedKey(guestUid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final declined = decoded['declined'];
      if (declined is! Map) return {};
      final result = <String, List<String>>{};
      declined.forEach((key, value) {
        if (key is! String || value is! List) return;
        result[key] = [...value.whereType<String>()];
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Set<String> _declinedIds(String guestUid, String accountUid) {
    return {..._readMarkers(guestUid)[accountUid] ?? const <String>[]};
  }

  Future<void> _writeMarkers(
    String guestUid,
    Map<String, List<String>> markers,
  ) {
    return store.setString(
      _declinedKey(guestUid),
      jsonEncode({
        'declined': {
          for (final entry in markers.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value,
        },
      }),
    );
  }

  Future<void> _forgetDeclined(
    String guestUid,
    String accountUid,
    List<String> moved,
  ) async {
    final markers = _readMarkers(guestUid);
    final ids = <String>{...markers[accountUid] ?? const <String>[]};
    ids.removeAll(moved);
    if (ids.isEmpty) {
      markers.remove(accountUid);
    } else {
      markers[accountUid] = ids.toList();
    }
    await _writeMarkers(guestUid, markers);
  }
}
