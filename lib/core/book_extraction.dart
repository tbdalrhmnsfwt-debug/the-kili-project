/// Turns a downloaded official PDF into a searchable, page-numbered lesson
/// library.
///
/// Every paragraph the study tools show is traceable to a PDF page. The
/// extractor never invents a section title: when the book has no recognisable
/// unit/lesson headings it falls back to clearly-labelled page ranges and
/// reports `needsReview`, so the UI can say the outline is a fallback.
///
/// Extraction is idempotent (keyed by the verified SHA-256) and resumable
/// (a checkpoint is written every few pages). OCR is used only for pages with
/// no text layer, and only for Arabic/English books, because those are the
/// only Tesseract data files bundled with the app.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/extraction.dart';
import '../models/official_book.dart';
import 'book_sectioning.dart';
import 'book_storage.dart';

export '../models/extraction.dart';

/// The stage reported to the UI while extraction runs.
enum ExtractionStage { reading, ocr, organizing, saving }

class ExtractionProgress {
  const ExtractionProgress(this.stage, this.done, this.total);

  final ExtractionStage stage;
  final int done;
  final int total;
}

/// Opens a PDF and reads one page at a time.
abstract interface class PdfPageSource {
  int get pageCount;
  Future<String> readPage(int pageIndex);
  void close();
}

typedef PdfPageSourceFactory = Future<PdfPageSource> Function(File file);

/// Reads pages with Syncfusion's pure-Dart parser.
class SyncfusionPageSource implements PdfPageSource {
  SyncfusionPageSource._(this._document, this._extractor, this.pageCount);

  static Future<PdfPageSource> open(File file) async {
    if (!await file.exists()) {
      throw const BookOperationException(
        BookFailureKind.storage,
        'ملف الكتاب مش موجود. نزّل الكتاب تاني قبل الاستخراج.',
      );
    }
    final bytes = await file.readAsBytes();
    try {
      final document = PdfDocument(inputBytes: bytes);
      final count = document.pages.count;
      if (count <= 0) {
        document.dispose();
        throw const BookOperationException(
          BookFailureKind.unreadable,
          'الملف مفتوح لكن مفيش فيه صفحات.',
        );
      }
      return SyncfusionPageSource._(
        document,
        PdfTextExtractor(document),
        count,
      );
    } on BookOperationException {
      rethrow;
    } catch (error) {
      throw BookOperationException(
        BookFailureKind.unreadable,
        'مقدرناش نفتح الكتاب. الملف ممكن يكون تالف أو محمي بكلمة سر.',
        cause: error,
      );
    }
  }

  final PdfDocument _document;
  final PdfTextExtractor _extractor;

  @override
  final int pageCount;

  @override
  Future<String> readPage(int pageIndex) async {
    try {
      return _extractor
          .extractText(startPageIndex: pageIndex, endPageIndex: pageIndex)
          .trim();
    } catch (_) {
      // A single malformed page must not fail the whole book; it is reported
      // as an empty page and the caller may OCR it.
      return '';
    }
  }

  @override
  void close() => _document.dispose();
}

/// OCR for one PDF page. Implemented by the app with Tesseract; tests inject
/// a fake.
abstract interface class PageOcrEngine {
  /// Returns `null` when this book language has no bundled OCR data.
  String? languageTag(String bookLanguage);

  Future<String> recognizePage(
    File pdf,
    int pageIndex,
    String tesseractLanguage,
  );
}

/// Default OCR: rasterise one page with `printing`, then run Tesseract.
///
/// Only `ara` and `eng` Tesseract data are bundled, so other languages return
/// `null` and the extraction reports a warning instead of guessing.
class TesseractPageOcr implements PageOcrEngine {
  const TesseractPageOcr({this.dpi = 200});

  final double dpi;

  @override
  String? languageTag(String bookLanguage) {
    return switch (bookLanguage) {
      'ar' => 'ara',
      'en' => 'eng',
      _ => null,
    };
  }

  @override
  Future<String> recognizePage(
    File pdf,
    int pageIndex,
    String tesseractLanguage,
  ) async {
    final bytes = await pdf.readAsBytes();
    final rasters = await Printing.raster(
      bytes,
      pages: [pageIndex],
      dpi: dpi,
    ).toList();
    if (rasters.isEmpty) return '';
    final png = await rasters.first.toPng();
    final directory = await Directory.systemTemp.createTemp('thakir_ocr_');
    final image = File(p.join(directory.path, 'page_$pageIndex.png'));
    try {
      await image.writeAsBytes(png, flush: true);
      return await FlutterTesseractOcr.extractText(
        image.path,
        language: tesseractLanguage,
        args: {'preserve_interword_spaces': '1'},
      );
    } finally {
      try {
        await image.delete();
        await directory.delete(recursive: true);
      } catch (_) {
        // Cache cleanup is best-effort.
      }
    }
  }
}

/// The result of an extraction call.
class BookExtractionResult {
  const BookExtractionResult({required this.book, required this.fromCache});

  final ExtractedBook book;
  final bool fromCache;
}

/// Extracts a downloaded PDF into page-numbered sections.
class BookExtractor {
  BookExtractor({
    required this.layout,
    PdfPageSourceFactory? openPdf,
    PageOcrEngine? ocr,
    this.maxOcrPages = 300,
    this.checkpointEvery = 10,
  }) : openPdf = openPdf ?? SyncfusionPageSource.open,
       ocr = ocr ?? const TesseractPageOcr();

  final BookStorageLayout layout;
  final PdfPageSourceFactory openPdf;
  final PageOcrEngine ocr;

  /// A safety cap: a 400-page scanned book must not quietly spend hours in
  /// OCR on a phone. Pages over the cap are counted, warned about and the
  /// result is marked [BookExtractionStatus.needsReview], never silently
  /// presented as a complete searchable book.
  final int maxOcrPages;

  final int checkpointEvery;

  static const int _minimumPageText = 24;

  /// Loads an existing extraction without touching the PDF.
  Future<ExtractedBook?> load(
    OfficialBook book, {
    required String sha256,
  }) async {
    final file = layout.extractionFile(book, sha256);
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return null;
      final extracted = ExtractedBook.fromJson(json.cast<String, dynamic>());
      if (extracted.bookId != book.id) return null;
      if (extracted.sha256.isNotEmpty && extracted.sha256 != sha256) {
        return null;
      }
      return extracted.copyWith(fromCache: true);
    } catch (_) {
      return null;
    }
  }

  /// Extracts (or resumes) [book].
  Future<BookExtractionResult> extract(
    OfficialBook book, {
    required String sha256,
    required File pdf,
    bool allowOcr = true,
    bool force = false,
    bool Function()? isCancelled,
    void Function(ExtractionProgress progress)? onProgress,
  }) async {
    if (!force) {
      final cached = await load(book, sha256: sha256);
      if (cached != null) {
        return BookExtractionResult(book: cached, fromCache: true);
      }
    }

    final warnings = <String>[];
    final pages = <ExtractedPage>[];

    // Resume the checkpoint if it belongs to the same SHA.
    final partialFile = layout.partialExtractionFile(book, sha256);
    if (partialFile.existsSync()) {
      try {
        final json = jsonDecode(await partialFile.readAsString());
        if (json is Map &&
            json['sha256'] == sha256 &&
            json['book_id'] == book.id &&
            json['pages'] is List) {
          for (final value in json['pages'] as List) {
            if (value is! Map) continue;
            pages.add(
              ExtractedPage.fromJson(value.cast<String, dynamic>()),
            );
          }
          if (pages.isNotEmpty) {
            warnings.add(
              'تم استكمال الاستخراج من آخر نقطة محفوظة '
              '(${pages.length} صفحة).',
            );
          }
        }
      } catch (_) {
        // A corrupt checkpoint is discarded by starting over.
        pages.clear();
      }
    }

    final source = await openPdf(pdf);
    final total = source.pageCount;
    var ocrPages = 0;
    var ocrSkipped = 0;
    var ocrCapped = false;
    final ocrLanguage = ocr.languageTag(book.language);
    final canOcr = allowOcr && ocrLanguage != null;
    if (allowOcr && ocrLanguage == null) {
      warnings.add(
        'الكتاب بلغة (${book.languageLabel}) ومفيش بيانات OCR مناسبة '
        'مضمّنة للتطبيق، فالصفحات المصوّرة هتفضل من غير نص.',
      );
    }

    try {
      for (var index = pages.length; index < total; index++) {
        if (isCancelled?.call() ?? false) {
          await _writeCheckpoint(partialFile, book, sha256, pages, total);
          throw const BookOperationException(
            BookFailureKind.cancelled,
            'اتوقف الاستخراج. يمكن تكملة من نفس الصفحة بعدين.',
          );
        }

        var text = cleanPageText(await source.readPage(index));
        var fromOcr = false;
        if (text.length < _minimumPageText &&
            canOcr &&
            ocrPages < maxOcrPages) {
          onProgress?.call(
            ExtractionProgress(ExtractionStage.ocr, index + 1, total),
          );
          try {
            final recognised = cleanPageText(
              await ocr.recognizePage(pdf, index, ocrLanguage),
            );
            if (recognised.length > text.length) {
              text = recognised;
              fromOcr = recognised.length >= _minimumPageText;
            }
            ocrPages++;
          } catch (error) {
            if (error is BookOperationException &&
                error.kind == BookFailureKind.cancelled) {
              rethrow;
            }
            if (!warnings.any((w) => w.contains('OCR'))) {
              warnings.add(
                'تعذّر تشغيل OCR على بعض الصفحات المصوّرة '
                '(${_shortError(error)}). النص المستخرج ناقص.',
              );
            }
          }
        } else if (text.length < _minimumPageText && canOcr) {
          // The OCR budget is spent; this page stays unsearchable.
          ocrSkipped++;
        }

        pages.add(
          ExtractedPage(
            pageNumber: index + 1,
            text: text,
            fromOcr: fromOcr,
          ),
        );
        onProgress?.call(
          ExtractionProgress(ExtractionStage.reading, index + 1, total),
        );

        if ((index + 1) % checkpointEvery == 0) {
          await _writeCheckpoint(partialFile, book, sha256, pages, total);
        }
      }

      if (ocrSkipped > 0) {
        ocrCapped = true;
        warnings.add(
          'اتخطينا OCR لـ $ocrSkipped صفحة بعد حد $maxOcrPages صفحة. '
          'الصفحات المصوّرة دي ممكن تكون من غير نص.',
        );
      }
    } finally {
      source.close();
    }

    if (isCancelled?.call() ?? false) {
      await _writeCheckpoint(partialFile, book, sha256, pages, total);
      throw const BookOperationException(
        BookFailureKind.cancelled,
        'اتوقف الاستخراج. يمكن تكملة من نفس الصفحة بعدين.',
      );
    }

    onProgress?.call(ExtractionProgress(ExtractionStage.organizing, total, total));
    final sections = buildSections(pages, warnings);

    final textPageCount = pages
        .where((page) => !page.fromOcr && page.text.length >= _minimumPageText)
        .length;
    final usablePages = pages
        .where((page) => page.text.length >= _minimumPageText)
        .length;

    var status = BookExtractionStatus.ready;
    if (total == 0 || usablePages == 0) {
      status = BookExtractionStatus.needsReview;
      warnings.add(
        'مفيش نص مقروء في الكتاب. ممكن الكتاب نسخة مصوّرة محتاجة OCR '
        'أو الملف تالف.',
      );
    } else if (usablePages / total < 0.3) {
      status = BookExtractionStatus.needsReview;
      warnings.add(
        'أقل من ثلث الصفحات فيه نص مقروء. راجع الصفحات المصوّرة قبل '
        'الاعتماد على الفلاش كاردز أو الاختبارات.',
      );
    } else if (ocrCapped) {
      status = BookExtractionStatus.needsReview;
      warnings.add(
        'الاستخراج وقف عند حد OCR قبل آخر الصفحات، فمش كل الكتاب قابل '
        'للبحث. راجع الصفحات الأخيرة أو كمّل الاستخراج.',
      );
    }
    if (sections.every((section) => section.isFallback)) {
      warnings.add(
        'معرفناش نلاقي عناوين وحدات أو دروس واضحة، فاتقسّم الكتاب '
        'لمجموعات صفحات. تقدر تفتح أي صفحة وتشوف مصدرها.',
      );
    }

    onProgress?.call(ExtractionProgress(ExtractionStage.saving, total, total));
    final result = ExtractedBook(
      bookId: book.id,
      sha256: sha256,
      extractedAt: DateTime.now(),
      pages: List.unmodifiable(pages),
      sections: List.unmodifiable(sections),
      textPageCount: textPageCount,
      ocrPageCount: ocrPages,
      warnings: List.unmodifiable(warnings),
      status: status,
      catalogSnapshot: book.toJson(),
      pageCount: total,
    );

    await _writeArtifact(book, result);
    try {
      if (await partialFile.exists()) await partialFile.delete();
    } catch (_) {
      // The final artifact is authoritative.
    }
    return BookExtractionResult(book: result, fromCache: false);
  }

  Future<void> _writeArtifact(OfficialBook book, ExtractedBook result) async {
    final target = layout.extractionFile(book, result.sha256);
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(result.toJson()), flush: true);
    await temp.rename(target.path);

    final manifest = {
      'book_id': book.id,
      'sha256': result.sha256,
      'extracted_at': result.extractedAt.toIso8601String(),
      'page_count': result.pageCount,
      'text_page_count': result.textPageCount,
      'ocr_pages': result.ocrPageCount,
      'section_count': result.sections.length,
      'status': result.status.wire,
      'file': target.path,
      'warnings': result.warnings,
      'catalog_metadata_version': book.metadataVersion,
    };
    final manifestFile = layout.extractedManifestFile(book);
    await manifestFile.parent.create(recursive: true);
    final manifestTemp = File('${manifestFile.path}.tmp');
    await manifestTemp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );
    await manifestTemp.rename(manifestFile.path);
  }

  Future<void> _writeCheckpoint(
    File file,
    OfficialBook book,
    String sha256,
    List<ExtractedPage> pages,
    int total,
  ) async {
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode({
          'schema': 1,
          'book_id': book.id,
          'sha256': sha256,
          'page_count': total,
          'next_page': pages.length + 1,
          'pages': pages.map((page) => page.toJson()).toList(),
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } catch (_) {
      // Losing a checkpoint only costs re-reading pages; it must not abort.
    }
  }

  static String _shortError(Object error) {
    final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }
}

/// A warning for a book that has no text and no usable OCR.
class ExtractionFailure implements Exception {
  const ExtractionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
