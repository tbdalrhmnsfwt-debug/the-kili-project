/// One JSON document per collection, written atomically with a backup.
library;

import 'dart:convert';
import 'dart:io';

import 'batch_failure.dart';

/// The result of reading a document.
enum DocumentLoadStatus {
  /// No file was ever written.
  missing,

  /// The primary file parsed and has the expected schema.
  ok,

  /// The primary file was corrupt and the `.bak` copy was used.
  recovered,

  /// Neither the primary file nor the backup parsed.
  corrupt,

  /// The file was written by a newer schema than this build understands.
  unsupportedSchema,
}

/// A loaded document plus how it was found.
class DocumentLoad<T> {
  const DocumentLoad(this.status, {this.value, this.failure});

  final DocumentLoadStatus status;
  final T? value;
  final BatchFailure? failure;

  bool get isUsable => value != null;
  bool get isMissing => status == DocumentLoadStatus.missing;
}

/// Persists one typed collection under [file].
///
/// Saving writes `<name>.part`, flushes it, keeps the previous good document
/// as `<name>.bak`, then renames the part into place. Loading falls back to
/// the backup once, quarantining the corrupt primary as
/// `<name>.corrupt-<timestamp>` rather than deleting it.
class DocumentStore<T> {
  DocumentStore({
    required this.file,
    required this.encode,
    required this.decode,
    this.schema = 1,
  });

  final File file;
  final int schema;
  final Map<String, dynamic> Function(T value) encode;
  final T Function(Map<String, dynamic> json) decode;

  File get backupFile => File('${file.path}.bak');
  File get partFile => File('${file.path}.part');

  Future<bool> exists() => file.exists();

  /// Reads the document. Never throws: failures come back in the result so a
  /// corrupt collection cannot take down its neighbours.
  Future<DocumentLoad<T>> load() async {
    if (!await file.exists()) {
      return const DocumentLoad(DocumentLoadStatus.missing);
    }
    final primary = await _read(file);
    if (primary is T) {
      return DocumentLoad(DocumentLoadStatus.ok, value: primary);
    }
    if (primary is _Unsupported) {
      return DocumentLoad(
        DocumentLoadStatus.unsupportedSchema,
        failure: BatchFailure(
          BatchFailureCode.migrationUnsupported,
          detail: 'schema ${primary.schema} > $schema',
        ),
      );
    }

    // The primary failed to parse; keep it for diagnosis and try the backup.
    await _quarantine(file);
    final backup = await _read(backupFile);
    if (backup is T) {
      // Put the good copy back so later reads do not fall back every time.
      try {
        await backupFile.copy(file.path);
      } on FileSystemException {
        // The in-memory recovery still stands if the copy fails.
      }
      return DocumentLoad(DocumentLoadStatus.recovered, value: backup);
    }
    return const DocumentLoad(
      DocumentLoadStatus.corrupt,
      failure: BatchFailure(
        BatchFailureCode.corruptStore,
        detail: 'primary and backup are unreadable',
      ),
    );
  }

  /// Writes [value] atomically. Throws [BatchFailure] on failure, leaving the
  /// previous document intact.
  Future<void> save(T value) async {
    final parent = file.parent;
    try {
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      final body = <String, dynamic>{'schema': schema};
      encode(value).forEach((key, value) {
        if (key != 'schema') body[key] = value;
      });
      final contents = jsonEncode(body);
      await partFile.writeAsString(contents, flush: true);

      // Only preserve a backup that is itself readable.
      if (await file.exists() && await _read(file) is T) {
        await file.copy(backupFile.path);
      }
      // On Android/Linux rename replaces an existing target atomically.
      await partFile.rename(file.path);
    } on FileSystemException catch (error) {
      try {
        if (await partFile.exists()) await partFile.delete();
      } on FileSystemException {
        // The part file is best-effort cleanup; the save already failed.
      }
      throw _writeFailure(error);
    }
  }

  Future<void> delete() async {
    for (final target in [file, backupFile, partFile]) {
      try {
        if (await target.exists()) await target.delete();
      } on FileSystemException {
        // Deleting a collection is best-effort; the caller reports storage
        // errors only when the batch directory itself cannot be removed.
      }
    }
  }

  Future<Object?> _read(File target) async {
    try {
      if (!await target.exists()) return null;
      final raw = await target.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final storedSchema = map['schema'];
      if (storedSchema is! int) return null;
      if (storedSchema != schema) return _Unsupported(storedSchema);
      final payload = Map<String, dynamic>.from(map)..remove('schema');
      return decode(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _quarantine(File target) async {
    try {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      await target.rename('${target.path}.corrupt-$stamp');
    } on FileSystemException {
      // If the rename fails (for example, read-only storage) the original
      // stays where it is; loading still falls back to the backup.
    }
  }

  BatchFailure _writeFailure(FileSystemException error) {
    final code = error.osError?.errorCode == 28
        ? BatchFailureCode.storageFull
        : BatchFailureCode.corruptStore;
    return BatchFailure(code, detail: 'document write failed');
  }
}

class _Unsupported {
  const _Unsupported(this.schema);
  final int schema;
}
