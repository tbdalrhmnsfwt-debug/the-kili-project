/// Updates: the local announcements timeline and its commands.
///
/// Posts live in the batch's private directory on this device. Reaching the
/// other members' devices needs a server, so nothing here pretends to deliver
/// a notification.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/batches/batch_repository.dart';
import '../models/batch_update.dart';
import 'app_providers.dart';
import 'batch_providers.dart';

String _currentUid(Ref ref) => ref.watch(authUserProvider)?.uid ?? '';

/// Every update the reader may see, pinned first and newest first.
final batchUpdatesProvider = FutureProvider.autoDispose
    .family<List<BatchUpdate>, String>((ref, batchId) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return const [];
  return ref.watch(batchRepositoryProvider).loadUpdates(uid, batchId);
});

/// Commands used by the update screens. Each one refreshes the reads.
class BatchUpdatesController {
  BatchUpdatesController(this._ref);

  final Ref _ref;

  BatchRepository get _repository => _ref.read(batchRepositoryProvider);

  String get _uid {
    final uid = _ref.read(authUserProvider)?.uid ?? '';
    if (uid.isEmpty) throw StateError('no active account');
    return uid;
  }

  Future<BatchUpdate> publish(
    String batchId, {
    required String title,
    required String body,
  }) async {
    final update = await _repository.publishUpdate(
      _uid,
      batchId,
      title: title,
      body: body,
    );
    _refresh(batchId);
    return update;
  }

  Future<BatchUpdate> edit(
    String batchId,
    String updateId, {
    required String title,
    required String body,
  }) async {
    final update = await _repository.editUpdate(
      _uid,
      batchId,
      updateId,
      title: title,
      body: body,
    );
    _refresh(batchId);
    return update;
  }

  Future<void> delete(String batchId, String updateId) async {
    await _repository.deleteUpdate(_uid, batchId, updateId);
    _refresh(batchId);
  }

  Future<BatchUpdate> markRead(String batchId, String updateId) async {
    final update = await _repository.markUpdateRead(_uid, batchId, updateId);
    _refresh(batchId);
    return update;
  }

  void _refresh(String batchId) {
    _ref.invalidate(batchUpdatesProvider(batchId));
    _ref.invalidate(batchHubDataProvider(batchId));
    // The batches list carries the unread count.
    _ref.invalidate(batchListProvider);
  }
}

final batchUpdatesControllerProvider =
    Provider<BatchUpdatesController>(BatchUpdatesController.new);
