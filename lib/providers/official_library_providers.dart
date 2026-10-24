/// Riverpod controller for the official library: verified downloads,
/// per-device state, extraction and update checks.
///
/// The controller is the only place that mutates [BookLocalState]; the UI
/// reads [OfficialLibraryViewState.stateOf] so every badge (downloaded,
/// extracting, needs review) is derived from real files and real requests.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/book_download_service.dart';
import '../core/book_extraction.dart';
import '../core/book_storage.dart';
import '../core/official_library_store.dart';
import '../models/dictionary.dart';
import '../models/official_book.dart';
import 'app_providers.dart';

/// English→Arabic glosses from the dictionary bundled with the app.
///
/// Only single-word entries are indexed because the vocabulary extractor works
/// token by token; a lesson never gets a translation the dictionary lacks.
final officialGlossaryProvider = FutureProvider<Map<String, String>>((ref) async {
  final DictionaryEntry dictionary = await ref
      .watch(assetServiceProvider)
      .loadDictionary();
  final glossary = <String, String>{};
  for (final entry in dictionary.entries) {
    final english = entry.english.trim().toLowerCase();
    final arabic = entry.arabic.trim();
    if (english.isEmpty || arabic.isEmpty || english.contains(' ')) continue;
    glossary.putIfAbsent(english, () => arabic);
  }
  return Map.unmodifiable(glossary);
});

/// The directory that holds official PDFs and extraction artifacts.
final officialLibraryRootProvider = FutureProvider<Directory>((ref) async {
  final base = await getApplicationDocumentsDirectory();
  return Directory(p.join(base.path, 'official_library'));
});

/// At most two concurrent downloads, as the brief requires.
const int kMaxConcurrentBookDownloads = 2;

/// Weekly automatic re-check of downloaded official files.
const Duration kBookUpdateCheckInterval = Duration(days: 7);

/// Immutable UI-facing library state.
class OfficialLibraryViewState {
  const OfficialLibraryViewState({
    required this.persisted,
    this.progress = const {},
    this.extractionProgress = const {},
    this.extracting = const {},
    this.notice = '',
    this.corrupt = false,
    this.recoveredFromBackup = false,
    this.checkingUpdates = false,
  });

  final OfficialLibraryState persisted;

  /// Live byte counts, kept in memory; the persisted row holds the status.
  final Map<String, DownloadProgress> progress;

  /// 0..1 while text extraction runs.
  final Map<String, double> extractionProgress;

  /// Book ids with an extraction running right now.
  final Set<String> extracting;

  final String notice;
  final bool corrupt;
  final bool recoveredFromBackup;
  final bool checkingUpdates;

  BookLocalState stateOf(OfficialBook book) =>
      persisted.books[book.id] ?? book.initialState();

  bool isDownloaded(OfficialBook book) =>
      stateOf(book).downloadStatus == BookDownloadStatus.downloaded;

  bool isReady(OfficialBook book) {
    final row = stateOf(book);
    return row.downloadStatus == BookDownloadStatus.downloaded &&
        (row.extractionStatus == BookExtractionStatus.ready ||
            row.extractionStatus == BookExtractionStatus.needsReview);
  }

  int get downloadedCount => persisted.books.values
      .where((row) => row.downloadStatus == BookDownloadStatus.downloaded)
      .length;

  int get readyCount => persisted.books.values
      .where(
        (row) =>
            row.extractionStatus == BookExtractionStatus.ready ||
            row.extractionStatus == BookExtractionStatus.needsReview,
      )
      .length;

  OfficialLibraryViewState copyWith({
    OfficialLibraryState? persisted,
    Map<String, DownloadProgress>? progress,
    Map<String, double>? extractionProgress,
    Set<String>? extracting,
    String? notice,
    bool? corrupt,
    bool? recoveredFromBackup,
    bool? checkingUpdates,
    bool clearNotice = false,
  }) => OfficialLibraryViewState(
    persisted: persisted ?? this.persisted,
    progress: progress ?? this.progress,
    extractionProgress: extractionProgress ?? this.extractionProgress,
    extracting: extracting ?? this.extracting,
    notice: clearNotice ? '' : notice ?? this.notice,
    corrupt: corrupt ?? this.corrupt,
    recoveredFromBackup: recoveredFromBackup ?? this.recoveredFromBackup,
    checkingUpdates: checkingUpdates ?? this.checkingUpdates,
  );
}

/// Owns the official-library pipeline.
class OfficialLibraryController
    extends AsyncNotifier<OfficialLibraryViewState> {
  late OfficialLibraryStore _stateStore;
  late BookDownloadService _downloader;
  late BookExtractor _extractor;
  late BookStorageLayout _layout;
  late OfficialBookCatalog _catalog;
  late OfficialLibraryViewState _view;

  final Map<String, CancelToken> _cancels = {};
  final Set<String> _activeDownloads = {};
  final Map<String, ExtractedBook> _extractedCache = {};
  bool _disposed = false;
  bool _pumping = false;

  @override
  Future<OfficialLibraryViewState> build() async {
    ref.onDispose(() {
      _disposed = true;
      for (final token in _cancels.values) {
        token.cancel('controller disposed');
      }
      _cancels.clear();
    });

    final catalog = await ref.watch(officialBooksProvider.future);
    final root = await ref.watch(officialLibraryRootProvider.future);
    final local = ref.watch(localStoreProvider);
    _catalog = catalog;
    _layout = BookStorageLayout(root);
    _stateStore = OfficialLibraryStore(local);

    final load = _stateStore.load();
    final reconciled = _reconcile(load.state);
    _view = OfficialLibraryViewState(
      persisted: reconciled,
      corrupt: load.corrupt,
      recoveredFromBackup: load.recoveredFromBackup,
      notice: load.message,
    );

    _downloader = BookDownloadService(layout: _layout);
    _extractor = BookExtractor(layout: _layout);
    if (load.corrupt) {
      // Preserve the recovered view immediately so a second crash does not
      // leave the corrupt value in place.
      unawaited(_stateStore.save(reconciled));
    }

    // Resume queued work and perform the weekly HEAD checks without blocking
    // the first frame.
    Future<void>.microtask(() async {
      if (_disposed) return;
      _pump();
      await _checkStaleUpdates();
    });
    return _view;
  }

  OfficialBookCatalog get catalog => _catalog;

  OfficialBook? bookById(String id) {
    for (final book in _catalog.books) {
      if (book.id == id) return book;
    }
    return null;
  }

  BookLocalState stateOf(OfficialBook book) => _view.stateOf(book);

  /// Loads a previously extracted book from disk, or from the memory cache.
  Future<ExtractedBook?> extractedFor(OfficialBook book) async {
    final cached = _extractedCache[book.id];
    if (cached != null) return cached;
    final row = stateOf(book);
    if (row.sha256.isEmpty) return null;
    final extracted = await _extractor.load(book, sha256: row.sha256);
    if (extracted != null) _extractedCache[book.id] = extracted;
    return extracted;
  }

  /// Queues a book for download and returns immediately.
  Future<void> requestDownload(OfficialBook book) async {
    final row = stateOf(book);
    if (row.downloadStatus.isBusy) return;
    if (!book.hasDownload) {
      await _updateRow(
        row.copyWith(
          downloadStatus: book.status == OfficialBookStatus.notPublished
              ? BookDownloadStatus.notPublished
              : BookDownloadStatus.manualReview,
          error: book.statusExplanation,
          updatedAt: DateTime.now(),
        ),
        notice: book.statusExplanation,
      );
      return;
    }
    if (row.downloadStatus == BookDownloadStatus.downloaded &&
        row.filePath.isNotEmpty &&
        File(row.filePath).existsSync()) {
      _setNotice('الكتاب منزّل على الجهاز بالفعل.');
      return;
    }

    // Identical official URL: share the verified file instead of downloading
    // and storing the same bytes twice.
    final canonical = _canonicalForUrl(book, row);
    if (canonical != null) {
      final canonicalRow = _view.persisted.books[canonical]!;
      await _updateRow(
        row.copyWith(
          downloadStatus: BookDownloadStatus.downloaded,
          extractionStatus: canonicalRow.extractionStatus,
          filePath: canonicalRow.filePath,
          fileSize: canonicalRow.fileSize,
          sha256: canonicalRow.sha256,
          downloadedAt: canonicalRow.downloadedAt,
          extractedPath: canonicalRow.extractedPath,
          extractedAt: canonicalRow.extractedAt,
          pageCount: canonicalRow.pageCount,
          sectionCount: canonicalRow.sectionCount,
          ocrPages: canonicalRow.ocrPages,
          warnings: canonicalRow.warnings,
          duplicateOf: canonical,
          downloadedMetadataVersion: book.metadataVersion,
          error: '',
          progress: 0,
          updatedAt: DateTime.now(),
        ),
        notice:
            'الكتاب ده نفس ملف كتاب تاني، فاتحفظ على الجهاز مرة واحدة '
            'والتقدم مشترك.',
      );
      return;
    }

    final queue = List<String>.from(_view.persisted.queue);
    if (!queue.contains(book.id)) queue.add(book.id);
    await _commit(
      _view.persisted.copyWith(
        queue: queue,
        books: {
          ..._view.persisted.books,
          book.id: row.copyWith(
            downloadStatus: BookDownloadStatus.queued,
            error: '',
            progress: 0,
            updatedAt: DateTime.now(),
          ),
        },
        updatedAt: DateTime.now(),
      ),
      notice: 'الكتاب اتضاف لقائمة التنزيل.',
    );
    unawaited(_pump());
  }

  /// Cancels a running download or removes a queued one.
  Future<void> cancelDownload(OfficialBook book) async {
    _cancels[book.id]?.cancel('ألغى الطالب التنزيل');
    final queue = _view.persisted.queue.where((id) => id != book.id).toList();
    final row = stateOf(book);
    if (row.downloadStatus.isBusy) {
      await _commit(
        _view.persisted.copyWith(
          queue: queue,
          books: {
            ..._view.persisted.books,
            book.id: row.copyWith(
              downloadStatus: BookDownloadStatus.cancelled,
              error: 'اتلغى التنزيل. الملف الجزئي محفوظ ويمكن نكمّل بعدين.',
              progress: 0,
              updatedAt: DateTime.now(),
            ),
          },
          updatedAt: DateTime.now(),
        ),
        notice: 'اتلغى تنزيل «${book.titleAr}».',
      );
    } else if (queue.length != _view.persisted.queue.length) {
      await _commit(
        _view.persisted.copyWith(queue: queue, updatedAt: DateTime.now()),
      );
    }
    _setDownloadProgress(book.id, null);
  }

  /// Asks the server whether the official file changed.
  Future<BookUpdateCheck?> checkForUpdate(OfficialBook book) async {
    final row = stateOf(book);
    if (row.downloadStatus != BookDownloadStatus.downloaded &&
        row.downloadStatus != BookDownloadStatus.needsUpdate) {
      return null;
    }
    _view = _view.copyWith(checkingUpdates: true);
    _emit();
    final check = await _downloader.checkForUpdate(book, row);
    final next = check.error.isNotEmpty
        ? row.copyWith(
            lastCheckedAt: check.checkedAt,
            error: check.error,
            updatedAt: DateTime.now(),
          )
        : row.copyWith(
            lastCheckedAt: check.checkedAt,
            etag: check.etag.isNotEmpty ? check.etag : row.etag,
            lastModified:
                check.lastModified.isNotEmpty ? check.lastModified : row.lastModified,
            downloadStatus: check.changed
                ? BookDownloadStatus.needsUpdate
                : BookDownloadStatus.downloaded,
            error: check.changed
                ? 'فيه نسخة أحدث من الكتاب على السيرفر الرسمي. '
                      'التنزيل هيكمل من غير ما يمسح النسخة الحالية.'
                : '',
            updatedAt: DateTime.now(),
          );
    await _commit(
      _view.persisted.copyWith(
        books: {..._view.persisted.books, book.id: next},
        updatedAt: DateTime.now(),
      ),
      notice: check.error.isNotEmpty
          ? check.error
          : check.changed
          ? 'فيه تحديث رسمي لكتاب «${book.titleAr}».'
          : 'النسخة الموجودة على الجهاز محدّثة.',
    );
    _view = _view.copyWith(checkingUpdates: false);
    _emit();
    return check;
  }

  /// Extracts text and sections. Safe to call again; cached artifacts load
  /// instantly and a partial checkpoint resumes.
  Future<void> extractBook(
    OfficialBook book, {
    bool? allowOcr,
    bool force = false,
  }) async {
    final row = stateOf(book);
    if (row.extractionStatus == BookExtractionStatus.extracting ||
        row.extractionStatus == BookExtractionStatus.organizing) {
      return;
    }
    if (row.downloadStatus != BookDownloadStatus.downloaded ||
        row.filePath.isEmpty ||
        !File(row.filePath).existsSync()) {
      await _updateRow(
        row.copyWith(
          extractionStatus: BookExtractionStatus.failed,
          error: 'لازم تنزّل الكتاب الأول قبل ما نستخرج الدروس.',
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }

    var sha = row.sha256;
    if (sha.isEmpty) {
      try {
        sha = await _hashFile(File(row.filePath));
      } catch (_) {
        await _updateRow(
          row.copyWith(
            extractionStatus: BookExtractionStatus.failed,
            error: 'مقدرناش نتحقق من الملف قبل الاستخراج. نزّله تاني.',
            updatedAt: DateTime.now(),
          ),
        );
        return;
      }
    }

    final ocrDefault = ref.read(officialOcrEnabledProvider);
    final useOcr = allowOcr ?? ocrDefault;
    await _updateRow(
      row.copyWith(
        sha256: sha,
        extractionStatus: BookExtractionStatus.extracting,
        error: '',
        extractedPath: '',
        updatedAt: DateTime.now(),
      ),
      notice: 'بيستخرج نص «${book.titleAr}»…',
    );
    _view = _view.copyWith(
      extracting: {..._view.extracting, book.id},
      extractionProgress: {..._view.extractionProgress, book.id: 0},
    );
    _emit();

    try {
      final result = await _extractor.extract(
        book,
        sha256: sha,
        pdf: File(row.filePath),
        allowOcr: useOcr,
        force: force,
        isCancelled: () => _disposed,
        onProgress: (progress) {
          final total = progress.total <= 0 ? 1 : progress.total;
          final fraction = (progress.done / total).clamp(0.0, 1.0);
          _view = _view.copyWith(
            extractionProgress: {
              ..._view.extractionProgress,
              book.id: fraction,
            },
          );
          _emit();
        },
      );
      final extracted = result.book;
      _extractedCache[book.id] = extracted;
      await _updateRow(
        stateOf(book).copyWith(
          extractionStatus: extracted.status,
          extractedPath: _layout.extractionFile(book, sha).path,
          extractedAt: extracted.extractedAt,
          pageCount: extracted.pageCount,
          sectionCount: extracted.sections.length,
          ocrPages: extracted.ocrPageCount,
          warnings: extracted.warnings,
          error: '',
          updatedAt: DateTime.now(),
        ),
        notice: extracted.status == BookExtractionStatus.ready
            ? 'الكتاب جاهز للمذاكرة: ${extracted.sections.length} درس/قسم '
                  'من ${extracted.pageCount} صفحة.'
            : 'الاستخراج خلص بس محتاج مراجعة: '
                  '${extracted.warnings.isEmpty ? 'نص قليل' : extracted.warnings.first}',
      );
    } on BookOperationException catch (error) {
      final cancelled = error.kind == BookFailureKind.cancelled;
      await _updateRow(
        stateOf(book).copyWith(
          extractionStatus: cancelled
              ? BookExtractionStatus.notStarted
              : BookExtractionStatus.failed,
          error: error.message,
          updatedAt: DateTime.now(),
        ),
        notice: error.message,
      );
    } catch (error) {
      await _updateRow(
        stateOf(book).copyWith(
          extractionStatus: BookExtractionStatus.failed,
          error: 'الاستخراج فشل: $error',
          updatedAt: DateTime.now(),
        ),
        notice: 'الاستخراج فشل. جرّب تاني أو نزّل الكتاب من جديد.',
      );
    } finally {
      final extracting = Set<String>.from(_view.extracting)..remove(book.id);
      final progress = Map<String, double>.from(_view.extractionProgress)
        ..remove(book.id);
      _view = _view.copyWith(
        extracting: extracting,
        extractionProgress: progress,
      );
      _emit();
    }
  }

  /// Re-checks that every recorded file still exists and keeps the library
  /// honest after an OS cleanup.
  Future<void> refreshFromDisk() async {
    final reconciled = _reconcile(_view.persisted);
    await _commit(reconciled, notice: 'اتعمل فحص لملفات الكتب على الجهاز.');
  }

  Map<String, dynamic> exportLibrary() => _stateStore.export();

  Future<OfficialLibraryImport> importLibrary(String raw) async {
    final result = await _stateStore.importJson(raw);
    if (result.ok) {
      final reloaded = _stateStore.load().state;
      _view = _view.copyWith(persisted: _reconcile(reloaded));
      _emit();
    }
    return result;
  }

  void clearNotice() {
    if (_view.notice.isEmpty) return;
    _view = _view.copyWith(clearNotice: true);
    _emit();
  }

  // ---------------------------------------------------------------- internals

  String? _canonicalForUrl(OfficialBook book, BookLocalState row) {
    if (book.downloadUrl.isEmpty) return null;
    for (final entry in _view.persisted.books.entries) {
      if (entry.key == book.id) continue;
      if (entry.value.downloadStatus != BookDownloadStatus.downloaded) {
        continue;
      }
      if (entry.value.filePath.isEmpty) continue;
      final other = bookById(entry.key);
      if (other == null || other.downloadUrl != book.downloadUrl) continue;
      if (File(entry.value.filePath).existsSync()) return entry.key;
    }
    if (row.duplicateOf.isNotEmpty &&
        _view.persisted.books[row.duplicateOf]?.filePath.isNotEmpty == true) {
      return row.duplicateOf;
    }
    return null;
  }

  Future<void> _pump() async {
    if (_pumping || _disposed) return;
    _pumping = true;
    try {
      while (_activeDownloads.length < kMaxConcurrentBookDownloads) {
        final id = _nextQueued();
        if (id == null) break;
        final book = bookById(id);
        if (book == null) break;
        _activeDownloads.add(id);
        unawaited(_runDownload(book));
      }
    } finally {
      _pumping = false;
    }
  }

  String? _nextQueued() {
    for (final id in _view.persisted.queue) {
      if (_activeDownloads.contains(id)) continue;
      final row = _view.persisted.books[id];
      if (row == null) continue;
      if (row.downloadStatus == BookDownloadStatus.downloaded) continue;
      if (bookById(id) == null) continue;
      return id;
    }
    return null;
  }

  Future<void> _runDownload(OfficialBook book) async {
    final id = book.id;
    final token = CancelToken();
    _cancels[id] = token;
    final before = stateOf(book);
    await _updateRow(
      before.copyWith(
        downloadStatus: BookDownloadStatus.downloading,
        error: '',
        progress: 0,
        updatedAt: DateTime.now(),
      ),
    );

    try {
      final outcome = await _downloader.download(
        book,
        cancelToken: token,
        onProgress: (progress) => _setDownloadProgress(id, progress),
      );
      var row = stateOf(book).copyWith(
        downloadStatus: BookDownloadStatus.downloaded,
        filePath: outcome.filePath,
        fileSize: outcome.fileSize,
        sha256: outcome.sha256,
        downloadedAt: outcome.downloadedAt,
        etag: outcome.etag.isNotEmpty ? outcome.etag : stateOf(book).etag,
        lastModified: outcome.lastModified.isNotEmpty
            ? outcome.lastModified
            : stateOf(book).lastModified,
        lastCheckedAt: DateTime.now(),
        pageCount: outcome.pageCount,
        downloadedMetadataVersion: book.metadataVersion,
        progress: 1,
        error: '',
        extractionStatus: stateOf(book).extractionStatus ==
                BookExtractionStatus.ready
            ? BookExtractionStatus.ready
            : BookExtractionStatus.notStarted,
        updatedAt: DateTime.now(),
      );

      final duplicateId = _duplicateSha(id, outcome.sha256);
      if (duplicateId != null) {
        final canonicalRow = _view.persisted.books[duplicateId]!;
        // The new copy is byte-identical to the canonical file. Removing the
        // redundant copy is the only deletion the pipeline performs; the
        // canonical verified file stays untouched.
        try {
          final duplicateFile = File(outcome.filePath);
          if (await duplicateFile.exists() &&
              duplicateFile.path != canonicalRow.filePath) {
            await duplicateFile.delete();
          }
        } catch (_) {
          // If deletion fails the file is still valid; pointing at the
          // canonical copy keeps deduplication correct.
        }
        row = row.copyWith(
          filePath: canonicalRow.filePath,
          fileSize: canonicalRow.fileSize,
          duplicateOf: duplicateId,
          extractionStatus: canonicalRow.extractionStatus,
          extractedPath: canonicalRow.extractedPath,
          extractedAt: canonicalRow.extractedAt,
          sectionCount: canonicalRow.sectionCount,
          ocrPages: canonicalRow.ocrPages,
          warnings: canonicalRow.warnings,
        );
      }

      final queue = _view.persisted.queue.where((value) => value != id).toList();
      await _commit(
        _view.persisted.copyWith(
          queue: queue,
          books: {..._view.persisted.books, id: row},
          updatedAt: DateTime.now(),
        ),
        notice: duplicateId != null
            ? 'الملف مطابق لكتاب تاني بالفعل على الجهاز، فمااتخزنش مرتين.'
            : 'تم تنزيل «${book.titleAr}» والتحقق منه.',
      );
    } on BookOperationException catch (error) {
      final cancelled = error.kind == BookFailureKind.cancelled;
      final queue = cancelled
          ? _view.persisted.queue.where((value) => value != id).toList()
          : _view.persisted.queue.where((value) => value != id).toList();
      await _commit(
        _view.persisted.copyWith(
          queue: queue,
          books: {
            ..._view.persisted.books,
            id: stateOf(book).copyWith(
              downloadStatus: cancelled
                  ? BookDownloadStatus.cancelled
                  : BookDownloadStatus.failed,
              error: error.message,
              progress: 0,
              attempts: stateOf(book).attempts + 1,
              updatedAt: DateTime.now(),
            ),
          },
          updatedAt: DateTime.now(),
        ),
        notice: error.message,
      );
    } catch (error) {
      await _commit(
        _view.persisted.copyWith(
          queue: _view.persisted.queue.where((value) => value != id).toList(),
          books: {
            ..._view.persisted.books,
            id: stateOf(book).copyWith(
              downloadStatus: BookDownloadStatus.failed,
              error: 'التنزيل فشل: $error',
              progress: 0,
              attempts: stateOf(book).attempts + 1,
              updatedAt: DateTime.now(),
            ),
          },
          updatedAt: DateTime.now(),
        ),
        notice: 'التنزيل فشل. جرّب تاني.',
      );
    } finally {
      _cancels.remove(id);
      _activeDownloads.remove(id);
      _setDownloadProgress(id, null);
      if (!_disposed) unawaited(_pump());
    }

    final after = stateOf(book);
    if (after.downloadStatus == BookDownloadStatus.downloaded) {
      final extracted = await _extractor.load(book, sha256: after.sha256);
      if (extracted == null) {
        await extractBook(book);
      }
    }
  }

  String? _duplicateSha(String id, String sha) {
    if (sha.isEmpty) return null;
    for (final entry in _view.persisted.books.entries) {
      if (entry.key == id) continue;
      final row = entry.value;
      if (row.sha256 != sha) continue;
      if (row.filePath.isEmpty || !File(row.filePath).existsSync()) continue;
      return entry.key;
    }
    return null;
  }

  Future<void> _checkStaleUpdates() async {
    final now = DateTime.now();
    final stale = <OfficialBook>[];
    for (final book in _catalog.books) {
      final row = stateOf(book);
      if (row.downloadStatus != BookDownloadStatus.downloaded) continue;
      final checked = row.lastCheckedAt;
      if (checked != null && now.difference(checked) < kBookUpdateCheckInterval) {
        continue;
      }
      stale.add(book);
      if (stale.length >= 3) break;
    }
    for (final book in stale) {
      if (_disposed) return;
      await checkForUpdate(book);
    }
  }

  OfficialLibraryState _reconcile(OfficialLibraryState state) {
    final books = <String, BookLocalState>{};
    final queue = List<String>.from(state.queue);
    for (final entry in state.books.entries) {
      var row = entry.value;
      if (row.filePath.isNotEmpty) {
        final file = File(row.filePath);
        if (!file.existsSync()) {
          row = row.copyWith(
            downloadStatus: BookDownloadStatus.failed,
            error:
                'الملف مش موجود على الجهاز (يمكن النظام مسحه). '
                'البيانات محفوظة وتقدر تنزّله تاني.',
            updatedAt: DateTime.now(),
          );
        } else {
          final size = file.lengthSync();
          if (row.fileSize > 0 && size != row.fileSize) {
            row = row.copyWith(
              downloadStatus: BookDownloadStatus.failed,
              error:
                  'حجم الملف اتغيّر على الجهاز، فالملف ممكن يكون تلف. '
                  'نزّله تاني من المصدر الرسمي.',
              updatedAt: DateTime.now(),
            );
          }
        }
      }
      if (row.extractedPath.isNotEmpty && !File(row.extractedPath).existsSync()) {
        row = row.copyWith(
          extractionStatus: BookExtractionStatus.notStarted,
          extractedPath: '',
          error: '',
          updatedAt: DateTime.now(),
        );
      }
      if (row.downloadStatus == BookDownloadStatus.downloaded &&
          row.filePath.isEmpty) {
        row = row.copyWith(
          downloadStatus: BookDownloadStatus.notDownloaded,
          updatedAt: DateTime.now(),
        );
      }
      books[entry.key] = row;
    }
    queue.removeWhere(
      (id) =>
          !books.containsKey(id) ||
          books[id]!.downloadStatus == BookDownloadStatus.downloaded,
    );
    return state.copyWith(books: books, queue: queue, updatedAt: DateTime.now());
  }

  Future<String> _hashFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  void _setDownloadProgress(String id, DownloadProgress? progress) {
    if (_disposed) return;
    final map = Map<String, DownloadProgress>.from(_view.progress);
    if (progress == null) {
      map.remove(id);
    } else {
      map[id] = progress;
    }
    _view = _view.copyWith(progress: map);
    _emit();
  }

  void _setNotice(String notice) {
    _view = _view.copyWith(notice: notice);
    _emit();
  }

  Future<void> _updateRow(
    BookLocalState row, {
    String? notice,
  }) => _commit(
    _view.persisted.copyWith(
      books: {..._view.persisted.books, row.bookId: row},
      updatedAt: DateTime.now(),
    ),
    notice: notice,
  );

  Future<void> _commit(
    OfficialLibraryState next, {
    String? notice,
    bool clearNotice = false,
  }) async {
    _view = _view.copyWith(
      persisted: next,
      notice: notice,
      clearNotice: clearNotice,
    );
    _emit();
    await _stateStore.save(next);
  }

  void _emit() {
    if (_disposed) return;
    state = AsyncData(_view);
  }
}

/// The official library controller.
final officialLibraryControllerProvider =
    AsyncNotifierProvider<OfficialLibraryController, OfficialLibraryViewState>(
      OfficialLibraryController.new,
    );

/// The extracted artifact for one book, or `null` before extraction finishes.
///
/// Watching the controller keeps this in sync when extraction completes, but
/// the read only happens once the recorded status says an artifact exists, so
/// download progress updates do not keep reloading the JSON.
final officialExtractedProvider =
    FutureProvider.autoDispose.family<ExtractedBook?, String>((ref, bookId) async {
      final library = ref.watch(officialLibraryControllerProvider);
      final view = library.valueOrNull;
      if (view == null) return null;
      final controller = ref.read(officialLibraryControllerProvider.notifier);
      final book = controller.bookById(bookId);
      if (book == null) return null;
      final row = controller.stateOf(book);
      if (row.extractionStatus != BookExtractionStatus.ready &&
          row.extractionStatus != BookExtractionStatus.needsReview) {
        return null;
      }
      return controller.extractedFor(book);
    });

/// A convenience encoder for the exported JSON payload.
String encodeOfficialLibraryExport(Map<String, dynamic> value) =>
    const JsonEncoder.withIndent('  ').convert(value);
