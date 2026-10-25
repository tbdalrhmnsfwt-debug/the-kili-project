/// Batch state for the app.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/batches/batch_claim_service.dart';
import '../core/batches/batch_file_store.dart';
import '../core/batches/batch_join_service.dart';
import '../core/batches/batch_repository.dart';
import '../core/batches/batch_resource_paths.dart';
import '../core/batches/batch_store.dart';
import '../core/batches/hub_summary.dart';
import '../core/batches/local_batch_repository.dart';
import '../core/batches/resource_store.dart';
import '../models/batch.dart';
import '../models/batch_resource.dart';
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

/// The concrete local repository, for services that need its claim/lookup
/// helpers in addition to the shared command surface.
final localBatchRepositoryProvider = Provider<LocalBatchRepository>((ref) {
  return LocalBatchRepository(
    files: ref.watch(batchFileStoreProvider),
    store: ref.watch(localStoreProvider),
  );
});

final batchRepositoryProvider = Provider<BatchRepository>((ref) {
  return ref.watch(localBatchRepositoryProvider);
});

final batchJoinServiceProvider = Provider<BatchJoinService>((ref) {
  return BatchJoinService(
    repository: ref.watch(localBatchRepositoryProvider),
    store: ref.watch(localStoreProvider),
  );
});

/// Resolves a typed code for the active uid. Widget tests override this with
/// an in-memory function so they never touch the file system.
typedef JoinCodeResolver = Future<JoinCodeResolution> Function(String input);

final batchJoinResolverProvider = Provider<JoinCodeResolver>((ref) {
  final service = ref.watch(batchJoinServiceProvider);
  final uid = ref.watch(authUserProvider)?.uid ?? '';
  return (input) => service.resolve(uid: uid, input: input);
});

final batchClaimServiceProvider = Provider<BatchClaimService>((ref) {
  return BatchClaimService(
    repository: ref.watch(localBatchRepositoryProvider),
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

/// Counts and latest items for the hub's four sections.
final batchHubDataProvider = FutureProvider.autoDispose
    .family<BatchHubData, String>((ref, batchId) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) {
    throw StateError('no active account');
  }
  // Reading the batch first keeps the access check in one place.
  await ref.watch(batchDetailProvider(batchId).future);
  final files = ref.watch(batchFileStoreProvider);
  return BatchHubData.load(
    store: BatchStore(directory: files.batchDir(uid, batchId)),
  );
});

/// Books storage usage for a batch, shown on the subjects screen.
final batchStorageProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  batchId,
) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return 0;
  return ref.watch(batchRepositoryProvider).storageUsed(uid, batchId);
});

/// Imports files into the active account's workspaces.
final resourceStoreProvider = Provider<ResourceStore>((ref) {
  final files = ref.watch(batchFileStoreProvider);
  return ResourceStore(
    files: files,
    repository: ref.watch(batchRepositoryProvider),
    thumbnails: PdfResourceThumbnailer(files: files),
  );
});

/// True when a resource's private copy is gone.
///
/// Widget tests override this family so no real I/O runs in the fake-async
/// zone.
typedef ResourceMissingArgs = ({String batchId, String relativePath});

final resourceMissingProvider = FutureProvider.autoDispose
    .family<bool, ResourceMissingArgs>((ref, args) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return false;
  final files = ref.watch(batchFileStoreProvider);
  final exists = await files.fileExists(
    uid: uid,
    batchId: args.batchId,
    relativePath: args.relativePath,
  );
  return !exists;
});

/// Page-one thumbnail bytes for a PDF resource, or null.
typedef ResourceThumbnailArgs = ({String batchId, String resourceId});

final resourceThumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List?, ResourceThumbnailArgs>((ref, args) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return null;
  final files = ref.watch(batchFileStoreProvider);
  return files.readBytes(
    uid: uid,
    batchId: args.batchId,
    relativePath: BatchResourcePaths.thumbnailPath(args.resourceId),
  );
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
    BatchSettings settings = const BatchSettings(),
  }) async {
    final batch = await _repository.createBatch(
      uid: _uid,
      displayName: displayName,
      name: name,
      subjects: subjects,
      settings: settings,
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

  Future<void> deleteSubject(
    String batchId,
    String subjectId, {
    String? moveToSubjectId,
    bool deleteResources = false,
  }) async {
    await _repository.deleteSubject(
      _uid,
      batchId,
      subjectId,
      moveToSubjectId: moveToSubjectId,
      deleteResources: deleteResources,
    );
    _refresh(batchId);
    _refreshStorage(batchId);
  }

  Future<BatchResource> addResource(BatchResource resource) async {
    final saved =
        await _repository.addResource(_uid, resource.batchId, resource);
    _refresh(resource.batchId);
    _refreshStorage(resource.batchId);
    return saved;
  }

  /// Copies a chosen file into the batch and indexes it.
  Future<BatchResource> importResource({
    required String batchId,
    required String subjectId,
    required ResourceKind kind,
    required String sourcePath,
    String? title,
  }) async {
    final resource = await _ref.read(resourceStoreProvider).importFile(
          uid: _uid,
          batchId: batchId,
          subjectId: subjectId,
          kind: kind,
          sourcePath: sourcePath,
          title: title,
        );
    _refresh(batchId);
    _refreshStorage(batchId);
    return resource;
  }

  Future<BatchResource> addNote({
    required String batchId,
    required String subjectId,
    required String title,
    required String note,
  }) async {
    final resource = await _ref.read(resourceStoreProvider).addNote(
          uid: _uid,
          batchId: batchId,
          subjectId: subjectId,
          title: title,
          note: note,
        );
    _refresh(batchId);
    _refreshStorage(batchId);
    return resource;
  }

  Future<void> deleteResource(String batchId, String resourceId) async {
    await _repository.deleteResource(_uid, batchId, resourceId);
    _refresh(batchId);
    _refreshStorage(batchId);
  }

  Future<BatchResource> setStarred(
    String batchId,
    String resourceId,
    bool starred,
  ) async {
    final resource = await _repository.setStarred(
      _uid,
      batchId,
      resourceId,
      starred,
    );
    _refresh(batchId);
    return resource;
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
    _ref.invalidate(batchHubDataProvider(batchId));
    _ref.invalidate(batchListProvider);
  }

  void _refreshStorage(String batchId) {
    _ref.invalidate(batchStorageProvider(batchId));
  }
}

final batchControllerProvider = Provider<BatchController>(BatchController.new);
