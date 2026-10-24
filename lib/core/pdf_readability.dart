/// Readability probes for downloaded PDFs.
///
/// The downloader uses a probe before moving a `.part` file into place. The
/// probe opens the real document; a byte signature alone is not enough to
/// prove the file is readable.
library;

import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'book_storage.dart';

/// Facts discovered by opening a PDF.
class PdfReadability {
  const PdfReadability({
    required this.pageCount,
    this.textPageCount = 0,
    this.sampleText = '',
    this.encrypted = false,
  });

  final int pageCount;

  /// How many of the first few sampled pages yielded text.
  final int textPageCount;
  final String sampleText;
  final bool encrypted;

  bool get hasTextLayer => textPageCount > 0;
}

/// Opens a PDF and reports whether it is readable.
abstract interface class PdfReadabilityProbe {
  Future<PdfReadability> probe(File file);
}

/// A probe backed by Syncfusion's PDF parser.
class SyncfusionPdfReadabilityProbe implements PdfReadabilityProbe {
  const SyncfusionPdfReadabilityProbe({this.sampledPages = 3});

  final int sampledPages;

  @override
  Future<PdfReadability> probe(File file) async {
    if (!await file.exists()) {
      throw const BookOperationException(
        BookFailureKind.unreadable,
        'ملف الكتاب مش موجود بعد التنزيل. جرّب تنزّله تاني.',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length < 5) {
      throw const BookOperationException(
        BookFailureKind.signature,
        'الملف صغير جدًا ومش PDF صالح.',
      );
    }
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      if (pageCount <= 0) {
        throw const BookOperationException(
          BookFailureKind.unreadable,
          'الملف اتفتح لكن مفيش فيه صفحات.',
        );
      }
      final sample = StringBuffer();
      var textPages = 0;
      final limit = sampledPages > pageCount ? pageCount : sampledPages;
      for (var index = 0; index < limit; index++) {
        try {
          final text = PdfTextExtractor(
            document,
          ).extractText(startPageIndex: index, endPageIndex: index).trim();
          if (text.isNotEmpty) {
            textPages++;
            if (sample.length < 2400) sample.writeln(text);
          }
        } catch (_) {
          // A page that cannot be text-extracted may still be a scanned page;
          // the document itself remains readable.
        }
      }
      return PdfReadability(
        pageCount: pageCount,
        textPageCount: textPages,
        sampleText: sample.toString().trim(),
      );
    } on BookOperationException {
      rethrow;
    } catch (error) {
      throw BookOperationException(
        BookFailureKind.unreadable,
        'الملف مش PDF مقروء أو محمي بكلمة سر. جرّب من مصدر رسمي تاني.',
        cause: error,
      );
    } finally {
      document?.dispose();
    }
  }
}
