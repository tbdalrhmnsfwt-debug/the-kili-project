/// App-private storage for the PDF library.
///
/// Nothing here ever touches a file the user picked: imports are copied into
/// [documentsDir], and deleting an entry only removes that copy. The class is
/// Flutter-free (only `dart:io`) so it can be verified on plain Dart.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Why an import was refused.
enum PdfImportFailure { invalidHeader, empty, storage }

/// A refused import.
class PdfImportException implements Exception {
  const PdfImportException(this.failure);

  final PdfImportFailure failure;

  @override
  String toString() => 'PdfImportException(${failure.name})';
}

/// Owns the library's directories and file operations.
class PdfLibraryStore {
  PdfLibraryStore({required this.rootDir, required this.cacheDir});

  final Directory rootDir;
  final Directory cacheDir;

  Directory get documentsDir => Directory('${rootDir.path}/pdf_library');
  Directory get thumbsDir => Directory('${cacheDir.path}/pdf_thumbs');
  Directory get sessionTempDir => Directory('${cacheDir.path}/pdf_session_tmp');

  /// Media the studio copied in: audio notes, video explanations and images.
  Directory get annotationsDir => Directory('${rootDir.path}/pdf_annotations');

  /// Flattened PDFs and project packages the user exported.
  Directory get exportsDir => Directory('${rootDir.path}/pdf_exports');

  File baseFile(String id) => File('${documentsDir.path}/$id.pdf');
  File thumbFile(String id) => File('${thumbsDir.path}/$id.png');
  File sessionTempFile(String id) => File('${sessionTempDir.path}/$id.pdf');

  /// The folder holding one document's annotation media.
  Directory annotationDir(String docKey) =>
      Directory('${annotationsDir.path}/${_safeSegment(docKey)}');

  /// A file inside [annotationDir], never outside it.
  File annotationAsset(String docKey, String fileName) =>
      File('${annotationDir(docKey).path}/${_safeSegment(fileName)}');

  /// A destination for an export, never outside the exports folder.
  File exportFile(String fileName) =>
      File('${exportsDir.path}/${_safeSegment(fileName)}');

  /// Creates the directories the library writes to.
  Future<void> ensureReady() async {
    await documentsDir.create(recursive: true);
    await thumbsDir.create(recursive: true);
    await sessionTempDir.create(recursive: true);
    await annotationsDir.create(recursive: true);
    await exportsDir.create(recursive: true);
  }

  /// A single path segment with no separators or traversal.
  static String _safeSegment(String raw) {
    final value = raw.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final cleaned = value.replaceAll('..', '_');
    return cleaned.isEmpty ? 'item' : cleaned;
  }

  /// Whether [header] starts with `%PDF-`.
  static bool looksLikePdf(List<int> header) {
    const magic = [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
    if (header.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (header[i] != magic[i]) return false;
    }
    return true;
  }

  /// Streams [bytes] into `<id>.pdf` and returns the number of bytes written.
  ///
  /// The first five bytes are validated before anything is written, so a
  /// rejected import leaves no file behind.
  Future<int> copyIn(Stream<List<int>> bytes, String id) async {
    await ensureReady();
    final iterator = StreamIterator<List<int>>(bytes);
    final head = BytesBuilder(copy: false);
    var reachedEnd = false;
    var total = 0;
    try {
      while (head.length < 5) {
        if (!await iterator.moveNext()) {
          reachedEnd = true;
          break;
        }
        head.add(iterator.current);
      }
      final headBytes = head.takeBytes();
      total = headBytes.length;
      if (total == 0) throw const PdfImportException(PdfImportFailure.empty);
      if (!looksLikePdf(headBytes)) {
        throw const PdfImportException(PdfImportFailure.invalidHeader);
      }

      final part = File('${baseFile(id).path}.part');
      final sink = part.openWrite();
      var sinkClosed = false;
      try {
        sink.add(headBytes);
        if (!reachedEnd) {
          while (await iterator.moveNext()) {
            final chunk = iterator.current;
            total += chunk.length;
            sink.add(chunk);
          }
        }
        await sink.flush();
        await sink.close();
        sinkClosed = true;
        await part.rename(baseFile(id).path);
        return total;
      } on Object {
        if (!sinkClosed) {
          await sink.close().catchError((_) {});
        }
        if (await part.exists()) {
          await part.delete().catchError((_) => part);
        }
        rethrow;
      }
    } on PdfImportException {
      rethrow;
    } on Object {
      throw const PdfImportException(PdfImportFailure.storage);
    } finally {
      await iterator.cancel();
    }
  }

  /// Removes the app's copy and thumbnail for [id].
  Future<void> deleteEntry(String id) async {
    final files = <File>[baseFile(id), thumbFile(id)];
    if (await thumbsDir.exists()) {
      await for (final entity in thumbsDir.list()) {
        final name =
            entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
        if (name.startsWith('$id.') && entity is File) files.add(entity);
      }
    }
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // A missing or locked file must not block removing the entry.
      }
    }
  }

  /// Deletes every session temp file; nothing there is durable.
  Future<void> sweepTemp() async {
    try {
      if (await sessionTempDir.exists()) {
        await for (final entity in sessionTempDir.list()) {
          try {
            await entity.delete(recursive: true);
          } on FileSystemException {
            continue;
          }
        }
      }
      await sessionTempDir.create(recursive: true);
    } on FileSystemException {
      // Best effort: a failed sweep must never stop the app from starting.
    }
  }

  /// Writes a thumbnail atomically.
  Future<void> writeThumbnail(String id, Uint8List png) async {
    await thumbsDir.create(recursive: true);
    final target = thumbFile(id);
    final part = File('${target.path}.part');
    await part.writeAsBytes(png, flush: true);
    await part.rename(target.path);
  }
}
