/// Turns one batch PDF into a page-numbered [SourceDocument].
///
/// The file never leaves the device: Syncfusion reads the text layer, pages
/// without one are rasterised for Tesseract (`ara+eng`), and the result is
/// cached at `text/<sha16>.json` under the batch's private directory. A page
/// whose text cannot be recovered stays empty and is reported in [warnings];
/// nothing is invented. Encrypted files are refused with a blocked message.
library;

import 'dart:convert';
import 'dart:io';

import '../../models/batch_resource.dart';
import '../../models/study_source.dart';
import '../book_extraction.dart';
import '../book_sectioning.dart';
import 'batch_failure.dart';
import 'batch_file_store.dart';
import 'batch_ids.dart';
import 'batch_resource_paths.dart';

class StudySourceExtractor {
  StudySourceExtractor({
    required this.files,
    PdfPageSourceFactory? openPdf,
    PageOcrEngine? ocr,
    Future<bool> Function(File file)? isEncrypted,
    this.maxOcrPages = 50,
    this.maxPages = 500,
    this.maxBytes = 100 * 1024 * 1024,
    DateTime Function()? clock,
  })  : openPdf = openPdf ?? SyncfusionPageSource.open,
        ocr = ocr ?? const TesseractPageOcr(),
        isEncrypted = isEncrypted ?? _looksEncrypted,
        _clock = clock ?? DateTime.now;

  final BatchFileStore files;
  final PdfPageSourceFactory openPdf;
  final PageOcrEngine ocr;
  final Future<bool> Function(File file) isEncrypted;

  /// A scanned 500-page book must not spend hours in OCR on a phone. Pages
  /// over this cap stay textless and the result carries a warning.
  final int maxOcrPages;

  final int maxPages;
  final int maxBytes;

  final DateTime Function() _clock;

  /// The default OCR language for batch documents: Arabic and English are the
  /// only Tesseract data files bundled with the app.
  static const String ocrLanguage = 'ara+eng';

  StudyJob? _lastJob;

  /// The most recent job, completed or not. Screens read it for the final
  /// state after [extract] returns.
  StudyJob? get lastJob => _lastJob;

  bool get isBusy => _lastJob?.isActive ?? false;

  /// The cached document for [resource], or null when it is absent, belongs
  /// to another resource or does not match the file's SHA-256.
  Future<SourceDocument?> cached({
    required String uid,
    required BatchResource resource,
  }) =>
      _loadCached(uid: uid, resource: resource);

  /// Extracts [resource], or returns its cached document when the SHA matches.
  ///
  /// Refuses a second start while one job is active, including a duplicate
  /// start for the same resource.
  Future<SourceDocument> extract({
    required String uid,
    required BatchResource resource,
    bool force = false,
    bool Function()? isCancelled,
    void Function(StudyJob job)? onProgress,
  }) async {
    if (isBusy) {
      throw const BatchFailure(
        BatchFailureCode.conflict,
        detail: 'study extraction already running',
      );
    }
    var job = StudyJob(
      id: newEntityId('study'),
      resourceId: resource.id,
      state: StudyJobState.queued,
      startedAt: _clock(),
      message: 'مستنيين نبدأ قراءة الملف…',
    );
    job = _emit(job, onProgress);

    try {
      if (!force) {
        final cached = await _loadCached(uid: uid, resource: resource);
        if (cached != null) {
          job = _emit(
            _finish(job, StudyJobState.completed, 'النص محفوظ من قبل.'),
            onProgress,
          );
          return cached;
        }
      }

      final relativePath = BatchResourcePaths.filePath(resource);
      if (relativePath == null) {
        throw const BatchFailure(
          BatchFailureCode.missingFile,
          detail: 'no pdf path',
        );
      }
      final pdf = files.fileInBatch(uid, resource.batchId, relativePath);
      if (!await pdf.exists()) {
        throw const BatchFailure(BatchFailureCode.missingFile);
      }
      if (await pdf.length() > maxBytes) {
        throw const BatchFailure(BatchFailureCode.fileTooLarge);
      }
      if (await isEncrypted(pdf)) {
        throw const BatchFailure(BatchFailureCode.encryptedSource);
      }

      job = _emit(
        job.copyWith(
          state: StudyJobState.processing,
          message: 'بنقرا نص الملف…',
        ),
        onProgress,
      );

      final PdfPageSource source;
      try {
        source = await openPdf(pdf);
      } catch (error) {
        throw BatchFailure(
          BatchFailureCode.extractionFailed,
          detail: 'open failed: ${_shortError(error)}',
        );
      }
      final total = source.pageCount;
      if (total > maxPages) {
        source.close();
        throw const BatchFailure(BatchFailureCode.tooManyPages);
      }

      final pages = <SourcePage>[];
      final warnings = <String>[];
      var ocrPages = 0;
      var ocrSkipped = 0;
      try {
        for (var index = 0; index < total; index++) {
          if (isCancelled?.call() ?? false) {
            throw const BatchFailure(BatchFailureCode.cancelled);
          }
          var text = cleanPageText(await source.readPage(index));
          var fromOcr = false;
          if (text.length < SourceDocument.minimumPageText) {
            if (ocrPages < maxOcrPages) {
              ocrPages++;
              try {
                final recognised = cleanPageText(
                  await ocr.recognizePage(pdf, index, ocrLanguage),
                );
                if (recognised.length > text.length) {
                  text = recognised;
                  fromOcr = recognised.length >= SourceDocument.minimumPageText;
                }
              } catch (_) {
                if (!warnings.any((warning) => warning.contains('OCR'))) {
                  warnings.add(
                    'تعذّر تشغيل OCR على بعض الصفحات المصوّرة، '
                    'فالنص المستخرج ناقص.',
                  );
                }
              }
            } else {
              ocrSkipped++;
            }
          }
          pages.add(
            SourcePage(
              pageNumber: index + 1,
              text: text,
              fromOcr: fromOcr,
            ),
          );
          job = _emit(
            job.copyWith(done: index + 1, total: total),
            onProgress,
          );
        }
      } finally {
        source.close();
      }

      if (ocrSkipped > 0) {
        warnings.add(
          'اتخطينا OCR لـ $ocrSkipped صفحة بعد حد $maxOcrPages صفحة. '
          'الصفحات المصوّرة دي ممكن تكون من غير نص.',
        );
      }
      if (pages.every((page) => page.text.trim().isEmpty)) {
        warnings.add(
          'مفيش نص مقروء في الملف. ممكن يكون نسخة مصوّرة محتاجة OCR '
          'أو الملف تالف.',
        );
      }

      if (isCancelled?.call() ?? false) {
        throw const BatchFailure(BatchFailureCode.cancelled);
      }

      final document = SourceDocument(
        resourceId: resource.id,
        batchId: resource.batchId,
        title: resource.title,
        sha256: resource.sha256,
        pages: List.unmodifiable(pages),
        warnings: List.unmodifiable(warnings),
        extractedAt: _clock(),
        pageCount: total,
        ocrPageCount: ocrPages,
      );
      await _saveCache(uid: uid, document: document);

      job = _emit(
        _finish(job, StudyJobState.completed, 'خلصنا استخراج النص.'),
        onProgress,
      );
      return document;
    } on BatchFailure catch (failure) {
      job = _emit(
        _finish(
          job,
          failure.code == BatchFailureCode.cancelled
              ? StudyJobState.cancelled
              : StudyJobState.failed,
          failure.code == BatchFailureCode.cancelled
              ? 'اتوقف الاستخراج.'
              : 'الاستخراج وقف. جرّب تاني.',
        ),
        onProgress,
      );
      rethrow;
    } on Object {
      job = _emit(
        _finish(
          job,
          StudyJobState.failed,
          'الاستخراج وقف. جرّب تاني.',
        ),
        onProgress,
      );
      throw const BatchFailure(
        BatchFailureCode.extractionFailed,
        detail: 'study extraction failed',
      );
    }
  }

  /// Publishes [job] as the current one and to the caller.
  ///
  /// The field must move with every transition: [isBusy] and [lastJob] read
  /// it, and a stale queued job would block the next extraction forever.
  StudyJob _emit(StudyJob job, void Function(StudyJob job)? onProgress) {
    _lastJob = job;
    onProgress?.call(job);
    return job;
  }

  StudyJob _finish(StudyJob job, StudyJobState state, String message) =>
      job.copyWith(state: state, message: message, finishedAt: _clock());

  Future<SourceDocument?> _loadCached({
    required String uid,
    required BatchResource resource,
  }) async {
    if (resource.sha256.isEmpty) return null;
    final relativePath = BatchResourcePaths.textCachePath(resource.sha256);
    final bytes = await files.readBytes(
      uid: uid,
      batchId: resource.batchId,
      relativePath: relativePath,
    );
    if (bytes == null) return null;
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map) return null;
      final document = SourceDocument.fromJson(
        json.cast<String, dynamic>(),
      );
      if (document.resourceId != resource.id) return null;
      if (document.sha256 != resource.sha256) return null;
      if (document.pages.isEmpty) return null;
      return document.copyWith(fromCache: true);
    } catch (_) {
      // A corrupt cache is re-extracted rather than trusted.
      return null;
    }
  }

  Future<void> _saveCache({
    required String uid,
    required SourceDocument document,
  }) async {
    if (document.sha256.isEmpty) return;
    try {
      await files.writeBytes(
        uid: uid,
        batchId: document.batchId,
        relativePath: BatchResourcePaths.textCachePath(document.sha256),
        bytes: utf8.encode(jsonEncode(document.toJson())),
      );
    } on BatchFailure {
      // Re-extracting next time is cheap compared to losing the result.
    }
  }

  /// Detects `/Encrypt` in the PDF trailer, which every encrypted file carries
  /// and no plain one does. Reading the last block avoids loading a 100 MB
  /// file twice just to answer this question.
  static Future<bool> _looksEncrypted(File file) async {
    const window = 8192;
    try {
      final length = await file.length();
      if (length == 0) return false;
      final start = length > window ? length - window : 0;
      final handle = await file.open();
      try {
        await handle.setPosition(start);
        final bytes = await handle.read(length - start);
        return _containsAscii(bytes, '/Encrypt');
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      return false;
    }
  }

  static bool _containsAscii(List<int> bytes, String needle) {
    final pattern = ascii.encode(needle);
    outer:
    for (var index = 0; index <= bytes.length - pattern.length; index++) {
      for (var offset = 0; offset < pattern.length; offset++) {
        if (bytes[index + offset] != pattern[offset]) continue outer;
      }
      return true;
    }
    return false;
  }

  static String _shortError(Object error) {
    final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }
}
