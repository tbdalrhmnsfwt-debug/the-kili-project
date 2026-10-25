/// Private, per-account file storage for batches.
///
/// Every path is built from validated segments, so a malformed id can never
/// escape the account's directory. Copies are written to a `.part` file,
/// hashed while streaming, and renamed into place.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'batch_failure.dart';

/// A file copied into a batch.
class StoredFile {
  const StoredFile({
    required this.file,
    required this.sha256,
    required this.sizeBytes,
  });

  final File file;
  final String sha256;
  final int sizeBytes;
}

class BatchFileStore {
  BatchFileStore({required this.root});

  /// `<app support>`; batches live below `<root>/batches/<uid>/`.
  final Directory root;

  /// 250 MB, the largest single import guard. PDF-specific screens pass the
  /// document cap of 100 MB instead.
  static const int maxImportBytes = 250 * 1024 * 1024;
  static const int maxPdfBytes = 100 * 1024 * 1024;
  static const int maxImageBytes = 20 * 1024 * 1024;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final RegExp _extensionPattern = RegExp(r'^[A-Za-z0-9]{1,8}$');

  Directory get batchesRoot => Directory(p.join(root.path, 'batches'));

  Directory userDir(String uid) {
    _requireSegment(uid, field: 'uid');
    return Directory(p.join(batchesRoot.path, uid));
  }

  Directory batchDir(String uid, String batchId) {
    _requireSegment(batchId, field: 'batchId');
    return Directory(p.join(userDir(uid).path, batchId));
  }

  File fileInBatch(String uid, String batchId, String relativePath) {
    _requireRelative(relativePath);
    return File(p.join(batchDir(uid, batchId).path, relativePath));
  }

  Future<void> ensureBatchDir(String uid, String batchId) async {
    final dir = batchDir(uid, batchId);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Copies [sourcePath] into [relativePath] inside the batch.
  Future<StoredFile> copyFile({
    required String uid,
    required String batchId,
    required String relativePath,
    required String sourcePath,
    int maxBytes = maxImportBytes,
    String? requiredHeader,
  }) async {
    _requireRelative(relativePath);
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const BatchFailure(BatchFailureCode.missingFile);
    }
    final length = await source.length();
    if (length == 0) {
      throw const BatchFailure(BatchFailureCode.unsupportedFile);
    }
    if (length > maxBytes) {
      throw const BatchFailure(BatchFailureCode.fileTooLarge);
    }
    if (requiredHeader != null) {
      await _requireHeader(source, requiredHeader);
    }

    await ensureBatchDir(uid, batchId);
    final destination = fileInBatch(uid, batchId, relativePath);
    if (!await destination.parent.exists()) {
      await destination.parent.create(recursive: true);
    }
    final part = File('${destination.path}.part');
    final sink = part.openWrite();
    final digestSink = _DigestSink();
    final hashInput = sha256.startChunkedConversion(digestSink);
    var written = 0;
    try {
      await for (final chunk in source.openRead()) {
        written += chunk.length;
        if (written > maxBytes) {
          throw const BatchFailure(BatchFailureCode.fileTooLarge);
        }
        hashInput.add(chunk);
        sink.add(chunk);
      }
      hashInput.close();
      await sink.flush();
      await sink.close();
      if (written == 0) {
        throw const BatchFailure(BatchFailureCode.unsupportedFile);
      }
      await part.rename(destination.path);
    } catch (error) {
      try {
        await sink.close();
      } on FileSystemException {
        // Already failing; the part file is removed below.
      }
      try {
        if (await part.exists()) await part.delete();
      } on FileSystemException {
        // Best-effort cleanup; the caller sees the original error.
      }
      if (error is BatchFailure) rethrow;
      throw _writeFailure(error);
    }
    final digest = digestSink.value;
    return StoredFile(
      file: destination,
      sha256: digest?.toString() ?? '',
      sizeBytes: written,
    );
  }

  /// Copies a resource file using its generated id and extension.
  Future<StoredFile> copyResource({
    required String uid,
    required String batchId,
    required String resourceId,
    required String sourcePath,
    required String extension,
    int maxBytes = maxImportBytes,
  }) async {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    if (!_extensionPattern.hasMatch(ext)) {
      throw const BatchFailure(
        BatchFailureCode.unsupportedFile,
        field: 'extension',
      );
    }
    return copyFile(
      uid: uid,
      batchId: batchId,
      relativePath: 'resources/$resourceId.$ext',
      sourcePath: sourcePath,
      maxBytes: maxBytes,
      requiredHeader: ext == 'pdf' ? '%PDF-' : null,
    );
  }

  /// Writes [bytes] atomically at [relativePath].
  Future<File> writeBytes({
    required String uid,
    required String batchId,
    required String relativePath,
    required List<int> bytes,
  }) async {
    _requireRelative(relativePath);
    await ensureBatchDir(uid, batchId);
    final destination = fileInBatch(uid, batchId, relativePath);
    if (!await destination.parent.exists()) {
      await destination.parent.create(recursive: true);
    }
    final part = File('${destination.path}.part');
    try {
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(destination.path);
    } on FileSystemException catch (error) {
      try {
        if (await part.exists()) await part.delete();
      } on FileSystemException {
        // Best-effort cleanup.
      }
      throw _writeFailure(error);
    }
    return destination;
  }

  /// Deletes a file only when it is inside its batch directory.
  Future<void> deleteFile({
    required String uid,
    required String batchId,
    required String relativePath,
  }) async {
    _requireRelative(relativePath);
    final target = fileInBatch(uid, batchId, relativePath);
    final inside = p.isWithin(batchDir(uid, batchId).path, target.path);
    if (!inside) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    try {
      if (await target.exists()) await target.delete();
    } on FileSystemException {
      throw const BatchFailure(BatchFailureCode.storageFull);
    }
  }

  Future<bool> fileExists({
    required String uid,
    required String batchId,
    required String relativePath,
  }) async {
    _requireRelative(relativePath);
    return fileInBatch(uid, batchId, relativePath).exists();
  }

  /// Removes the whole batch directory.
  Future<void> deleteBatch({
    required String uid,
    required String batchId,
  }) async {
    final dir = batchDir(uid, batchId);
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      throw const BatchFailure(
        BatchFailureCode.corruptStore,
        detail: 'batch delete failed',
      );
    }
  }

  /// Deletes cache folders only; originals are never touched.
  Future<void> pruneCaches({
    required String uid,
    required String batchId,
  }) async {
    for (final name in ['text', 'thumbs']) {
      final dir = Directory(p.join(batchDir(uid, batchId).path, name));
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } on FileSystemException {
        // A cache that cannot be removed is reported by storage usage, not
        // by failing an unrelated action.
      }
    }
  }

  /// Removes leftover `.part` files from interrupted writes.
  Future<void> sweepParts({
    required String uid,
    required String batchId,
  }) async {
    final dir = batchDir(uid, batchId);
    if (!await dir.exists()) return;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.path.endsWith('.part')) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // Cleanup is opportunistic.
    }
  }

  Future<int> storageUsed({
    required String uid,
    required String batchId,
  }) async {
    final dir = batchDir(uid, batchId);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // A file can disappear mid-count; skip it.
        }
      }
    }
    return total;
  }

  Future<int> userStorageUsed(String uid) async {
    final dir = userDir(uid);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // Skip files that vanish during the walk.
        }
      }
    }
    return total;
  }

  /// Lists the batch directory names present for an account.
  Future<List<String>> listBatchDirectories(String uid) async {
    final dir = userDir(uid);
    if (!await dir.exists()) return const [];
    final ids = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        ids.add(p.basename(entity.path));
      }
    }
    return ids;
  }

  Future<void> _requireHeader(File source, String header) async {
    final handle = await source.open();
    try {
      final bytes = await handle.read(header.length);
      final actual = String.fromCharCodes(bytes);
      if (actual != header) {
        throw const BatchFailure(
          BatchFailureCode.unsupportedFile,
          detail: 'header mismatch',
        );
      }
    } finally {
      await handle.close();
    }
  }

  void _requireSegment(String value, {required String field}) {
    if (value.isEmpty || value == '.' || value == '..') {
      throw BatchFailure(BatchFailureCode.validationFailed, field: field);
    }
    if (value.contains('/') ||
        value.contains(r'\') ||
        value.contains('\u0000') ||
        value.length > 128) {
      throw BatchFailure(BatchFailureCode.validationFailed, field: field);
    }
    if (field == 'batchId' && !_idPattern.hasMatch(value)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'batchId',
      );
    }
  }

  void _requireRelative(String relativePath) {
    if (relativePath.isEmpty || relativePath.startsWith('/')) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'path',
      );
    }
    if (relativePath.contains(r'\')) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'path',
      );
    }
    for (final segment in relativePath.split('/')) {
      if (segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          segment.contains('\u0000')) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'path',
        );
      }
    }
  }

  BatchFailure _writeFailure(Object error) {
    if (error is FileSystemException && error.osError?.errorCode == 28) {
      return const BatchFailure(BatchFailureCode.storageFull);
    }
    return const BatchFailure(
      BatchFailureCode.corruptStore,
      detail: 'file write failed',
    );
  }
}

/// Captures the single digest produced by a chunked hash conversion.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
