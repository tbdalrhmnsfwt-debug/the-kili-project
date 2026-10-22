/// Builders for the documents the PDF tools screen exports.
///
/// Every document is generated on-device: question sheets come from the same
/// cloze generator the quizzes use, and the formatted book is the bundled
/// lesson narratives laid out for reading. The compression helper rasterises
/// a picked PDF at a lower resolution and rebuilds it, which is the only way
/// to shrink a document without its original source assets.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/exam.dart';
import '../models/manhaji.dart';

/// The theme is loaded once; the PDF fonts are large and parsing is not free.
Future<pw.ThemeData>? _themeFuture;

/// A theme with the bundled Arabic faces, so the generated PDFs are readable
/// and shape correctly outside the app.
Future<pw.ThemeData> _pdfTheme() => _themeFuture ??= _loadTheme();

Future<pw.ThemeData> _loadTheme() async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/TajawalPdf-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/TajawalPdf-Bold.ttf'),
  );
  return pw.ThemeData.withFont(base: regular, bold: bold);
}

/// Builds a question-bank PDF, with an answer line under each question when
/// [withAnswers] is true.
Future<Uint8List> buildQuestionsPdf({
  required String title,
  required String subtitle,
  required List<ExamQuestion> questions,
  required bool withAnswers,
}) async {
  final theme = await _pdfTheme();
  final doc = pw.Document(title: title, author: 'ذاكرلي', theme: theme);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      maxPages: 300,
      margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
      footer: _footer,
      build: (context) => [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 12),
        for (var i = 0; i < questions.length; i++)
          _questionBlock(questions[i], i, withAnswers),
      ],
    ),
  );

  return doc.save();
}

/// Builds a formatted PDF of a whole book: every lesson and its narrated
/// figures, in reading order.
Future<Uint8List> buildBookPdf({
  required Book book,
  required List<Lesson> lessons,
}) async {
  final theme = await _pdfTheme();
  final doc = pw.Document(title: book.title, author: 'ذاكرلي', theme: theme);
  final meta = [
    if (book.subject.isNotEmpty) book.subject,
    if (book.variant.isNotEmpty) book.variant,
    '${lessons.length} درس',
  ].join(' • ');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      maxPages: 500,
      margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 36),
      footer: _footer,
      build: (context) => [
        pw.Text(
          book.title,
          style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          meta,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 1, color: PdfColors.grey300),
        for (final lesson in lessons) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            lesson.title.isEmpty ? 'الدرس ${lesson.number}' : lesson.title,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          if (lesson.title.isNotEmpty)
            pw.Text(
              'الدرس ${lesson.number}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          pw.SizedBox(height: 6),
          for (final figure in lesson.figures) ...[
            if (figure.narrative.trim().isNotEmpty)
              pw.Text(
                _plain(figure.narrative),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
            if (figure.labels.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  'مصطلحات: ${figure.labels.join(' • ')}',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            if (figure.page != null)
              pw.Text(
                'صفحة ${figure.page}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            pw.SizedBox(height: 7),
          ],
        ],
      ],
    ),
  );

  return doc.save();
}

/// Rasterises [source] at [dpi] and rebuilds it as a new PDF.
///
/// Rasterising flattens selectable text, so this is meant for scanned
/// documents whose images dominate the file size; the caller compares the
/// result with the original and keeps whichever is smaller.
Future<Uint8List> compressPdf(Uint8List source, {double dpi = 96}) async {
  final doc = pw.Document(compress: true);
  await for (final raster in Printing.raster(source, dpi: dpi)) {
    final png = await raster.toPng();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Image(
            pw.MemoryImage(png),
            fit: pw.BoxFit.contain,
          ),
        ),
      ),
    );
  }
  return doc.save();
}

/// One numbered question with its options and, optionally, its answer.
pw.Widget _questionBlock(
  ExamQuestion question,
  int index,
  bool withAnswers,
) {
  const letters = ['أ', 'ب', 'ج', 'د', 'هـ'];
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${index + 1}. ${question.prompt}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            lineSpacing: 3,
          ),
        ),
        if (question.options.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          for (var i = 0; i < question.options.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '${i < letters.length ? letters[i] : '${i + 1}'}) '
                '${question.options[i]}',
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
            ),
        ],
        if (withAnswers) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            'الإجابة: ${_answerOf(question)}',
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
        ],
      ],
    ),
  );
}

/// The correct option text, falling back to the explanation.
String _answerOf(ExamQuestion question) {
  final index = question.correctIndex;
  if (index != null &&
      index >= 0 &&
      index < question.options.length &&
      question.options[index].isNotEmpty) {
    return question.options[index];
  }
  return question.explanation.isEmpty ? '—' : question.explanation;
}

/// Strips the Markdown markers the narratives carry before they reach PDF
/// text, which has no inline formatting.
String _plain(String text) => text
    .replaceAll(RegExp(r'[*_`#>]+'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Shared footer with the app name and the page number.
pw.Widget _footer(pw.Context context) => pw.Align(
  alignment: pw.Alignment.centerLeft,
  child: pw.Text(
    'ذاكرلي • ${context.pageNumber} / ${context.pagesCount}',
    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
  ),
);
