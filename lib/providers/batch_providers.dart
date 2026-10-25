/// Batch state for the app.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/batches/batch_file_store.dart';
import '../core/batches/batch_repository.dart';
import '../core/batches/batch_store.dart';
import '../core/batches/local_batch_repository.dart';
import '../models/batch.dart';
import 'app_providers.dart';

/// The app-support directory that holds `batches/`.
///
/// `main` overrides this with the real support directory; tests override it
/// with a temporary directory.
final batchRootDirProvider = Provider<Directory>((ref) {
  throw StateError('batchRootDirProvider must be overridden');
});

final batchFileStoreProvider = Provider<BatchFileStore>((ref) {
  return BatchFileStore(root: ref.watch(batchRootDirProvider));
});

final batchRepositoryProvider = Provider<BatchRepository>((ref) {
  return LocalBatchRepository(
    files: ref.watch(batchFileStoreProvider),
    store: ref.watch(localStoreProvider),
  );
});

String _currentUid(Ref ref) => ref.watch(authUserProvider)?.uid ?? '';

/// The batches visible to the signed-in account or persisted guest.
final batchListProvider = FutureProvider.autoDispose<List<BatchSummary>>((
  ref,
) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return const [];
  return ref.watch(batchRepositoryProvider).listBatches(uid);
});

/// One batch, with the access check applied.
final batchDetailProvider = FutureProvider.autoDispose
    .family<BatchSnapshot, String>((ref, batchId) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) {
    throw StateError('no active account');
  }
  return ref.watch(batchRepositoryProvider).loadBatch(uid, batchId);
});

/// Commands used by screens. Each one invalidates the affected reads.
class BatchController {
  BatchController(this._ref);

  final Ref _ref;

  BatchRepository get _repository => _ref.read(batchRepositoryProvider);

  String get _uid {
    final uid = _ref.read(authUserProvider)?.uid ?? '';
    if (uid.isEmpty) throw StateError('no active account');
    return uid;
  }

  Future<Batch> createBatch({
    required String name,
    required List<String> subjects,
    String displayName = '',
  }) async {
    final batch = await _repository.createBatch(
      uid: _uid,
      displayName: displayName,
      name: name,
      subjects: subjects,
    );
    _ref.invalidate(batchListProvider);
    return batch;
  }

  Future<Batch> updateSettings(String batchId, BatchSettings settings) async {
    final batch = await _repository.updateSettings(_uid, batchId, settings);
    _refresh(batchId);
    return batch;
  }

  Future<BatchSubject> addSubject(String batchId, String name) async {
    final subject = await _repository.addSubject(_uid, batchId, name);
    _refresh(batchId);
    return subject;
  }

  Future<void> renameSubject(
    String batchId,
    String subjectId,
    String name,
  ) async {
    await _repository.renameSubject(_uid, batchId, subjectId, name);
    _refresh(batchId);
  }

  Future<void> deleteSubject(String batchId, String subjectId) async {
    await _repository.deleteSubject(_uid, batchId, subjectId);
    _refresh(batchId);
  }

  Future<InviteCodeState> rotateCode(String batchId) async {
    final state = await _repository.rotateCode(_uid, batchId);
    _refresh(batchId);
    return state;
  }

  Future<InviteCodeState> revokeCode(String batchId) async {
    final state = await _repository.revokeCode(_uid, batchId);
    _refresh(batchId);
    return state;
  }

  Future<void> deleteBatch(String batchId) async {
    await _repository.deleteBatch(_uid, batchId);
    _ref.invalidate(batchListProvider);
  }

  Future<int> storageUsed(String batchId) =>
      _repository.storageUsed(_uid, batchId);

  void refresh() => _ref.invalidate(batchListProvider);

  void _refresh(String batchId) {
    _ref.invalidate(batchDetailProvider(batchId));
    _ref.invalidate(batchListProvider);
  }
}

final batchControllerProvider = Provider<BatchController>(BatchController.new);
