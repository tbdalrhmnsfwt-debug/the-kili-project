import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../lib/core/pdf/pdf_text_map.dart';

/// Two A4 pages reading «chemistry» then «physics».
Future<Uint8List> _twoPageDocument() async {
  final document = sf.PdfDocument();
  final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14);
  for (final word in ['chemistry', 'physics']) {
    final page = document.pages.add();
    page.graphics.drawString(
      word,
      font,
      bounds: const Rect.fromLTWH(40, 40, 220, 40),
    );
  }
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

/// One page with no drawable text.
Future<Uint8List> _blankDocument() async {
  final document = sf.PdfDocument();
  document.pages.add();
  final bytes = Uint8List.fromList(await document.save());
  document.dispose();
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('search finds a word on the page that carries it', () async {
    final map = PdfTextMap.fromBytes(await _twoPageDocument(), pageCount: 2);

    final matches = await map.search('chemistry');

    expect(matches, hasLength(1));
    expect(matches.single.pageIndex, 0);
    expect(matches.single.bounds.left, inInclusiveRange(0.0, 1.0));
    expect(matches.single.bounds.top, inInclusiveRange(0.0, 1.0));
    expect(matches.single.bounds.right, inInclusiveRange(0.0, 1.0));
    expect(matches.single.bounds.bottom, inInclusiveRange(0.0, 1.0));
  });

  test('an empty or missing query returns no matches', () async {
    final map = PdfTextMap.fromBytes(await _twoPageDocument(), pageCount: 2);

    expect(await map.search(''), isEmpty);
    expect(await map.search('   '), isEmpty);
    expect(await map.search('nonexistent'), isEmpty);
  });

  test('a page with drawn text reports lines with normalized bounds', () async {
    final map = PdfTextMap.fromBytes(await _twoPageDocument(), pageCount: 2);

    final lines = await map.linesOnPage(0);

    expect(lines.map((line) => line.text).join(' '), contains('chemistry'));
    expect(lines.first.bounds.left, inInclusiveRange(0.0, 1.0));
    expect(lines.first.bounds.top, inInclusiveRange(0.0, 1.0));
  });

  test('a blank document has no extractable text', () async {
    final map = PdfTextMap.fromBytes(await _blankDocument(), pageCount: 1);

    expect(await map.hasAnyText(), isFalse);
    expect(await map.search('anything'), isEmpty);
  });
}
