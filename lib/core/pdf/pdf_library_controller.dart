/// Owns «ملفاتي»: importing, renaming, favouriting and pruning.
///
/// Every mutation goes through [PdfLibraryRepository] so the catalog on disk
/// always matches the state the UI is showing. The controller never touches a
/// file the user did not hand it: imports are copies, and `remove` only
/// deletes those copies.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pdf_document.dart';
import 'pdf_library_index.dart';
import 'pdf_library_repository.dart';
import 'pdf_library_store.dart';
import 'pdf_render_channel.dart';

/// One file offered to the importer.
class PdfImportSource {
  const PdfImportSource({
    required this.name,
    required this.sizeBytes,
    required this.openRead,
  });

  /// The name the file had where the user picked it.
  final String name;

  /// Bytes the picker reported; zero when unknown.
  final int sizeBytes;

  /// Opens a fresh stream of the file's bytes.
  final Stream<List<int>> Function() openRead;
}

/// What probing an imported file found out.
class PdfProbeResult {
  const PdfProbeResult({this.pageCount, this.encrypted = false});

  /// Null when the file is encrypted or could not be read.
  final int? pageCount;

  /// Whether the file needs a password.
  final bool encrypted;
}

/// Reads basic facts about a freshly copied file.
typedef PdfProbe = Future<PdfProbeResult> Function(File file);

/// Writes a thumbnail for [baseFile] into [thumbFile].
typedef PdfThumbnailer = Future<void> Function(File baseFile, File thumbFile);

/// The outcome of one import pass.
class PdfImportResult {
  const PdfImportResult({required this.imported, required this.failures});

  final List<PdfDocumentEntry> imported;
  final List<PdfImportFailure> failures;
}

/// The library's single source of truth.
class PdfLibraryController extends StateNotifier<PdfLibraryIndex> {
  PdfLibraryController({
    required PdfLibraryStore store,
    required PdfLibraryRepository repository,
    required PdfProbe probe,
    required PdfThumbnailer thumbnailer,
    String Function()? newId,
  }) : _store = store,
       _repository = repository,
       _probe = probe,
       _thumbnailer = thumbnailer,
       _newId = newId ?? _defaultId,
       super(repository.load());

  final PdfLibraryStore _store;
  final PdfLibraryRepository _repository;
  final PdfProbe _probe;
  final PdfThumbnailer _thumbnailer;
  final String Function() _newId;
  bool _busy = false;

  /// Whether an import pass is running.
  bool get isBusy => _busy;

  /// Imports [sources] one at a time.
  Future<PdfImportResult> import(List<PdfImportSource> sources) async {
    if (_busy) {
      return const PdfImportResult(imported: [], failures: []);
    }
    _busy = true;
    final imported = <PdfDocumentEntry>[];
    final failures = <PdfImportFailure>[];
    try {
      for (final source in sources) {
        final id = _newId();
        try {
          final sizeBytes = await _store.copyIn(source.openRead(), id);
          final baseFile = _store.baseFile(id);
          final probe = await _safeProbe(baseFile);
          String? thumbnail;
          if (!probe.encrypted) {
            final thumbFile = _store.thumbFile(id);
            try {
              await _thumbnailer(baseFile, thumbFile);
              if (thumbFile.existsSync()) thumbnail = _baseName(thumbFile);
            } on Object {
              // A missing thumbnail is not an import failure.
            }
          }
          final entry = PdfDocumentEntry(
            id: id,
            displayName: _displayName(source.name),
            baseFileName: _baseName(baseFile),
            originalName: source.name,
            sizeBytes: sizeBytes,
            pageCount: probe.pageCount,
            addedAt: DateTime.now(),
            thumbnailFileName: thumbnail,
            source: PdfDocumentSource.imported,
            encryption: probe.encrypted
                ? PdfEncryptionState.yes
                : probe.pageCount != null
                ? PdfEncryptionState.no
                : PdfEncryptionState.unknown,
          );
          await _commit(state.upsert(entry));
          imported.add(entry);
        } on PdfImportException catch (error) {
          failures.add(error.failure);
        }
      }
    } finally {
      _busy = false;
    }
    return PdfImportResult(imported: imported, failures: failures);
  }

  /// Changes only the catalog name; the file keeps its original.
  Future<void> rename(String id, String name) async {
    final entry = _entry(id);
    if (entry == null) return;
    await _commit(state.upsert(entry.copyWith(displayName: name)));
  }

  /// Deletes the app's copy and drops the entry.
  Future<void> remove(String id) async {
    await _store.deleteEntry(id);
    await _commit(state.remove(id));
  }

  Future<void> setFavorite(String id, bool value) async {
    final entry = _entry(id);
    if (entry == null) return;
    await _commit(state.upsert(entry.copyWith(favorite: value)));
  }

  /// Records that the document was opened, optionally at [page].
  Future<void> markOpened(String id, {int? page}) async {
    final entry = _entry(id);
    if (entry == null) return;
    await _commit(
      state.upsert(
        entry.copyWith(
          lastOpenedAt: DateTime.now(),
          lastPage: page == null || page < 1 ? entry.lastPage : page,
        ),
      ),
    );
  }

  /// Drops entries whose file is missing and persists the result.
  Future<void> refresh() async {
    final pruned = state.pruneMissing(
      (entry) => _store.baseFile(entry.id).existsSync(),
    );
    if (pruned.entries.length != state.entries.length) {
      await _commit(pruned);
    }
  }

  /// Reloads the catalog from disk, then drops entries whose file is gone.
  Future<void> reindex() async {
    state = _repository.load();
    await refresh();
  }

  PdfDocumentEntry? _entry(String id) {
    for (final entry in state.entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<PdfProbeResult> _safeProbe(File file) async {
    try {
      return await _probe(file);
    } on PdfRenderException catch (error) {
      return PdfProbeResult(
        encrypted: error.failure == PdfRenderFailure.passwordRequired,
      );
    } on Object {
      // The reader surfaces the real error; the entry still gets imported.
      return const PdfProbeResult();
    }
  }

  Future<void> _commit(PdfLibraryIndex index) async {
    state = index;
    await _repository.save(index);
  }

  static String _baseName(File file) => file.uri.pathSegments.last;

  /// The name shown in the catalog: the source name without a `.pdf` suffix.
  static String _displayName(String sourceName) {
    final trimmed = sourceName.trim();
    if (trimmed.toLowerCase().endsWith('.pdf') && trimmed.length > 4) {
      return trimmed.substring(0, trimmed.length - 4).trim();
    }
    return trimmed;
  }

  static String _defaultId() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final noise = Random.secure().nextInt(1 << 20).toRadixString(16);
    return '$stamp-$noise';
  }
}
