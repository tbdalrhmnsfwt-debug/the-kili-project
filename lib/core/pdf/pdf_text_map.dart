/// On-device text extraction and search for the native reader.
///
/// Syncfusion opens the bytes in memory; nothing leaves the device, and no
/// extracted text is logged. The document is opened per operation and disposed
/// in `finally`, so no file handle outlives a call.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'pdf_page_geometry.dart';

/// One word on a page, in normalized page coordinates.
class PdfTextWord {
  const PdfTextWord({required this.text, required this.bounds});

  final String text;
  final NormalizedRect bounds;
}

/// One extracted line, in normalized page coordinates.
class PdfTextLine {
  const PdfTextLine({
    required this.text,
    required this.bounds,
    required this.words,
  });

  final String text;
  final NormalizedRect bounds;
  final List<PdfTextWord> words;
}

/// One search hit.
class PdfTextMatch {
  const PdfTextMatch({
    required this.pageIndex,
    required this.bounds,
    required this.snippet,
  });

  final int pageIndex;
  final NormalizedRect bounds;
  final String snippet;
}

/// Text access for one open document.
class PdfTextMap {
  PdfTextMap.fromBytes(this._bytes, {String? password, required this.pageCount})
    : _password = password;

  final Uint8List _bytes;
  final String? _password;
  final int pageCount;

  final Map<int, List<PdfTextLine>> _lineCache = {};
  bool? _hasText;

  /// Extracts (and caches) the lines of one page.
  Future<List<PdfTextLine>> linesOnPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= pageCount) return const [];
    final cached = _lineCache[pageIndex];
    if (cached != null) return cached;
    final document = _open();
    if (document == null) return const [];
    try {
      final extractor = sf.PdfTextExtractor(document);
      final lines = extractor.extractTextLines(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      final pageSize = _displaySize(document.pages[pageIndex]);
      final mapped = [for (final line in lines) _line(line, pageSize)];
      _lineCache[pageIndex] = mapped;
      return mapped;
    } on Object {
      return const [];
    } finally {
      document.dispose();
    }
  }

  /// Finds [query] on every page. An empty query, a document without text and
  /// an unreadable document all return no matches.
  Future<List<PdfTextMatch>> search(String query) async {
    final needle = query.trim();
    if (needle.isEmpty) return const [];
    if (!await hasAnyText()) return const [];
    final document = _open();
    if (document == null) return const [];
    final matches = <PdfTextMatch>[];
    try {
      final extractor = sf.PdfTextExtractor(document);
      for (var page = 0; page < pageCount; page++) {
        final pageSize = _displaySize(document.pages[page]);
        final lines = _linesFor(extractor, page, pageSize);
        for (final item in extractor.findText(
          [needle],
          startPageIndex: page,
          endPageIndex: page,
        )) {
          final bounds = _normalize(item.bounds, pageSize);
          matches.add(
            PdfTextMatch(
              pageIndex: page,
              bounds: bounds,
              snippet: _snippet(lines, bounds, needle),
            ),
          );
        }
        // Let the UI breathe between pages.
        await Future<void>.delayed(Duration.zero);
      }
    } on Object {
      // Keep the matches found before the failure.
    } finally {
      document.dispose();
    }
    return matches;
  }

  /// Whether any page carries extractable text.
  Future<bool> hasAnyText() async {
    final cached = _hasText;
    if (cached != null) return cached;
    if (pageCount <= 0) return _hasText = false;
    final document = _open();
    if (document == null) return _hasText = false;
    try {
      final extractor = sf.PdfTextExtractor(document);
      for (var page = 0; page < pageCount; page++) {
        final lines = extractor.extractTextLines(
          startPageIndex: page,
          endPageIndex: page,
        );
        if (lines.any((line) => line.text.trim().isNotEmpty)) {
          return _hasText = true;
        }
        await Future<void>.delayed(Duration.zero);
      }
      return _hasText = false;
    } on Object {
      return _hasText = false;
    } finally {
      document.dispose();
    }
  }

  List<PdfTextLine> _linesFor(
    sf.PdfTextExtractor extractor,
    int page,
    Size pageSize,
  ) {
    final cached = _lineCache[page];
    if (cached != null) return cached;
    final lines = extractor.extractTextLines(
      startPageIndex: page,
      endPageIndex: page,
    );
    final mapped = [for (final line in lines) _line(line, pageSize)];
    _lineCache[page] = mapped;
    return mapped;
  }

  sf.PdfDocument? _open() {
    try {
      return sf.PdfDocument(inputBytes: _bytes, password: _password);
    } on Object {
      return null;
    }
  }

  /// The page as the reader shows it: rotated pages swap width and height.
  Size _displaySize(sf.PdfPage page) {
    final size = page.size;
    return switch (page.rotation) {
      sf.PdfPageRotateAngle.rotateAngle90 ||
      sf.PdfPageRotateAngle.rotateAngle270 => Size(size.height, size.width),
      _ => size,
    };
  }

  PdfTextLine _line(sf.TextLine line, Size pageSize) {
    return PdfTextLine(
      text: line.text,
      bounds: _normalize(line.bounds, pageSize),
      words: [
        for (final word in line.wordCollection)
          PdfTextWord(
            text: word.text,
            bounds: _normalize(word.bounds, pageSize),
          ),
      ],
    );
  }

  NormalizedRect _normalize(Rect bounds, Size pageSize) {
    if (pageSize.width <= 0 || pageSize.height <= 0) {
      return const NormalizedRect(0, 0, 0, 0);
    }
    final left = (bounds.left / pageSize.width).clamp(0.0, 1.0).toDouble();
    final top = (bounds.top / pageSize.height).clamp(0.0, 1.0).toDouble();
    final right = (bounds.right / pageSize.width).clamp(0.0, 1.0).toDouble();
    final bottom = (bounds.bottom / pageSize.height).clamp(0.0, 1.0).toDouble();
    return NormalizedRect(
      left,
      top,
      math.max(0, right - left),
      math.max(0, bottom - top),
    );
  }

  String _snippet(
    List<PdfTextLine> lines,
    NormalizedRect bounds,
    String fallback,
  ) {
    final centerX = bounds.left + bounds.width / 2;
    final centerY = bounds.top + bounds.height / 2;
    for (final line in lines) {
      final lineBounds = line.bounds;
      if (centerX >= lineBounds.left &&
          centerX <= lineBounds.right &&
          centerY >= lineBounds.top &&
          centerY <= lineBounds.bottom) {
        final text = line.text.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return fallback;
  }
}
