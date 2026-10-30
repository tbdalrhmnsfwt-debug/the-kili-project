/// On-device text extraction and search for the native reader.
///
/// Syncfusion reads the document from bytes and extracts in Dart; nothing
/// leaves the device, and no extracted text is logged. The document is opened
/// per operation and disposed in `finally`, so no file handle outlives a call.
///
/// Search runs in a worker isolate when the map was built from a file: the
/// extractor walks every page, which is exactly the work that must not block
/// the UI isolate.
library;

import 'dart:io';
import 'dart:isolate';
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
    : _file = null,
      _password = password;

  /// Reads the page text straight from [file].
  ///
  /// Nothing is copied into the Dart heap: Syncfusion opens the path itself,
  /// so a 200 MB document costs the extractor's buffer, not another full copy.
  PdfTextMap.fromFile(File file, {required this.pageCount, String? password})
    : _file = file,
      _bytes = null,
      _password = password;

  final Uint8List? _bytes;
  final File? _file;
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

  /// Finds [query] on every page.
  ///
  /// An empty query and an unreadable document return no matches; whether the
  /// document carries any text at all is the caller's question, and asking it
  /// here would extract every page twice.
  Future<List<PdfTextMatch>> search(String query) async {
    final needle = query.trim();
    if (needle.isEmpty) return const [];
    final file = _file;
    if (file != null) {
      final path = file.path;
      final password = _password;
      final count = pageCount;
      try {
        return await Isolate.run(
          () => _searchInWorker(path, password, needle, count),
        );
      } on Object {
        // An extractor that cannot run off the root isolate falls back to
        // running here; reporting "no matches" would be a lie.
      }
    }
    final bytes = await _readBytes();
    if (bytes == null) return const [];
    return _extractBytes(bytes, _password, needle, pageCount);
  }

  /// Entry point of the worker isolate: reads the file there, extracts there.
  static List<PdfTextMatch> _searchInWorker(
    String path,
    String? password,
    String needle,
    int pageCount,
  ) {
    try {
      final bytes = File(path).readAsBytesSync();
      return _extractBytes(bytes, password, needle, pageCount);
    } on Object {
      return const [];
    }
  }

  static List<PdfTextMatch> _extractBytes(
    Uint8List bytes,
    String? password,
    String needle,
    int pageCount,
  ) {
    return PdfTextMap.fromBytes(
      bytes,
      password: password,
      pageCount: pageCount,
    )._searchSync(needle);
  }

  /// The synchronous search body, shared by the worker and the fallback.
  List<PdfTextMatch> _searchSync(String needle) {
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
      }
    } on Object {
      // Keep the matches found before the failure.
    } finally {
      document.dispose();
    }
    return matches;
  }

  /// The document's bytes, read on demand so opening the sheet costs nothing.
  Future<Uint8List?> _readBytes() async {
    final cached = _bytes;
    if (cached != null) return cached;
    try {
      return await _file?.readAsBytes();
    } on FileSystemException {
      return null;
    }
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
      final file = _file;
      if (file != null) {
        return sf.PdfDocument(
          inputBytes: file.readAsBytesSync(),
          password: _password,
        );
      }
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
