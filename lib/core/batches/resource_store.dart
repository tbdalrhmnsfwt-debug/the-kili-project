/// Importing files and notes into a batch.
///
/// This is the only layer that copies a user-chosen file into private storage.
/// Validation happens before the copy, and a failed index write removes the
/// copy again, so the document and the disk never disagree about a resource.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/batch_resource.dart';
import '../pdf/pdf_page_geometry.dart';
import '../pdf/pdf_render_channel.dart';
import 'batch_failure.dart';
import 'batch_file_store.dart';
import 'batch_ids.dart';
import 'batch_repository.dart';
import 'batch_resource_paths.dart';

/// A file the user chose, before it is copied into the batch.
class PickedResourceFile {
  const PickedResourceFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  final String name;

  /// Null when the picker could not expose a readable path.
  final String? path;
  final int sizeBytes;
}

/// Builds the page-one thumbnail for a copied PDF.
///
/// A missing thumbnail is a normal state, so every implementation swallows its
/// own failures.
abstract interface class ResourceThumbnailer {
  Future<void> generate({
    required String uid,
    required String batchId,
    required String resourceId,
    required String sourcePath,
  });
}

class ResourceStore {
  ResourceStore({
    required this.files,
    required this.repository,
    this.thumbnails,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BatchFileStore files;
  final BatchRepository repository;
  final ResourceThumbnailer? thumbnails;
  final DateTime Function() _clock;

  static const int maxTitleChars = 120;
  static const int maxNoteChars = 20000;

  /// Copies [sourcePath] into the batch and indexes it.
  ///
  /// Accepts PDFs and the audio containers the player understands; anything
  /// else fails before a byte is copied.
  Future<BatchResource> importFile({
    required String uid,
    required String batchId,
    required String subjectId,
    required ResourceKind kind,
    required String sourcePath,
    String? title,
  }) async {
    if (kind == ResourceKind.note) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'kind',
      );
    }
    final name = p.basename(sourcePath);
    final extension = BatchResourcePaths.extensionOf(name);
    if (extension == null) {
      throw const BatchFailure(
        BatchFailureCode.unsupportedFile,
        field: 'extension',
      );
    }
    if (kind == ResourceKind.pdf) {
      if (extension != 'pdf') {
        throw const BatchFailure(
          BatchFailureCode.unsupportedFile,
          field: 'extension',
        );
      }
    } else if (!BatchResourcePaths.isAudioExtension(extension)) {
      throw const BatchFailure(
        BatchFailureCode.unsupportedFile,
        field: 'extension',
      );
    }

    final cleanTitle = _titleFor(title, name);
    final resourceId = newEntityId('res');
    final StoredFile stored;
    try {
      stored = await files.copyResource(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
        sourcePath: sourcePath,
        extension: extension,
        maxBytes: kind == ResourceKind.pdf
            ? BatchFileStore.maxPdfBytes
            : BatchFileStore.maxImportBytes,
      );
    } on FileSystemException {
      throw const BatchFailure(
        BatchFailureCode.corruptStore,
        detail: 'import copy failed',
      );
    }

    final resource = BatchResource(
      id: resourceId,
      batchId: batchId,
      subjectId: subjectId,
      kind: kind,
      title: cleanTitle,
      fileName: name,
      mime: _mimeFor(extension),
      sizeBytes: stored.sizeBytes,
      uploaderUid: uid,
      createdAt: _clock(),
      sha256: stored.sha256,
    );
    try {
      final saved = await repository.addResource(uid, batchId, resource);
      if (kind == ResourceKind.pdf && thumbnails != null) {
        try {
          await thumbnails!.generate(
            uid: uid,
            batchId: batchId,
            resourceId: resourceId,
            sourcePath: stored.file.path,
          );
        } on Object {
          // The card falls back to a glyph.
        }
      }
      return saved;
    } on Object {
      await _discard(uid: uid, batchId: batchId, resource: resource);
      rethrow;
    }
  }

  /// Creates a text note. No file is written.
  Future<BatchResource> addNote({
    required String uid,
    required String batchId,
    required String subjectId,
    required String title,
    required String note,
  }) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty || cleanNote.runes.length > maxNoteChars) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'note',
      );
    }
    final cleanTitle = _titleFor(title, '');
    final resource = BatchResource(
      id: newEntityId('res'),
      batchId: batchId,
      subjectId: subjectId,
      kind: ResourceKind.note,
      title: cleanTitle,
      uploaderUid: uid,
      createdAt: _clock(),
      note: cleanNote,
    );
    return repository.addResource(uid, batchId, resource);
  }

  String _titleFor(String? title, String fileName) {
    var clean = title?.trim() ?? '';
    if (clean.isEmpty) {
      clean = fileName;
      final dot = clean.lastIndexOf('.');
      if (dot > 0) clean = clean.substring(0, dot);
      clean = clean.trim();
      if (clean.runes.length > maxTitleChars) {
        clean = String.fromCharCodes(clean.runes.take(maxTitleChars));
      }
    }
    if (clean.isEmpty ||
        clean.runes.length > maxTitleChars ||
        clean.runes.any((rune) => rune < 0x20 || rune == 0x7F)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'title',
      );
    }
    return clean;
  }

  Future<void> _discard({
    required String uid,
    required String batchId,
    required BatchResource resource,
  }) async {
    final path = BatchResourcePaths.filePath(resource);
    if (path == null) return;
    try {
      await files.deleteFile(
        uid: uid,
        batchId: batchId,
        relativePath: path,
      );
    } on BatchFailure {
      // An orphan copy is cleaned up by the next prune; the import already
      // failed for a reason the caller can act on.
    }
  }

  static String _mimeFor(String extension) => switch (extension) {
        'pdf' => 'application/pdf',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        _ => 'application/octet-stream',
      };
}

/// Renders page one of a copied PDF into `thumbs/<resourceId>.png`.
class PdfResourceThumbnailer implements ResourceThumbnailer {
  PdfResourceThumbnailer({
    required this.files,
    this.channel = const PdfRenderChannel(),
  });

  final BatchFileStore files;
  final PdfRenderChannel channel;

  @override
  Future<void> generate({
    required String uid,
    required String batchId,
    required String resourceId,
    required String sourcePath,
  }) async {
    PdfRendererHandle? handle;
    try {
      handle = await channel.open(sourcePath);
      if (handle.pages.isEmpty) return;
      final page = handle.pages.first;
      if (page.widthPoints <= 0) return;
      final bytes = await channel.render(
        handle: handle.id,
        pageIndex: 0,
        scale: 120 / page.widthPoints,
        source: const NormalizedRect(0, 0, 1, 1),
      );
      await files.writeBytes(
        uid: uid,
        batchId: batchId,
        relativePath: BatchResourcePaths.thumbnailPath(resourceId),
        bytes: bytes,
      );
    } on Object {
      // A thumbnail is a convenience; the import already succeeded.
    } finally {
      if (handle != null) await channel.close(handle.id);
    }
  }
}
