/// Extraction artifacts kept free of Flutter so they can be parsed, searched
/// and tested on a plain Dart VM.
///
/// `core/book_extraction.dart` builds these from a real PDF and re-exports
/// them; anything that only needs to read a finished extraction can import
/// this file directly.
library;

import 'dart:math' as math;

import 'official_book.dart';

/// One PDF page after extraction.
class ExtractedPage {
  const ExtractedPage({
    required this.pageNumber,
    required this.text,
    this.fromOcr = false,
  });

  /// 1-based page number as the reader displays it.
  final int pageNumber;
  final String text;
  final bool fromOcr;

  int get characterCount => text.length;

  Map<String, dynamic> toJson() => {
    'page': pageNumber,
    'text': text,
    if (fromOcr) 'ocr': true,
  };

  factory ExtractedPage.fromJson(Map<String, dynamic> json) => ExtractedPage(
    pageNumber: (json['page'] as num?)?.toInt() ?? 0,
    text: json['text'] as String? ?? '',
    fromOcr: json['ocr'] == true,
  );
}

/// A chapter/unit/lesson, or a fallback page range.
class ExtractedSection {
  const ExtractedSection({
    required this.id,
    required this.title,
    required this.startPage,
    required this.endPage,
    required this.text,
    this.isFallback = false,
    this.fromOcr = false,
  });

  final String id;
  final String title;
  final int startPage;
  final int endPage;
  final String text;

  /// True when no heading was found and this is a page range, not a real
  /// chapter the Ministry printed.
  final bool isFallback;

  /// Whether any page in this section came from OCR.
  final bool fromOcr;

  int get pageCount => endPage - startPage + 1;
  int get characterCount => text.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start_page': startPage,
    'end_page': endPage,
    'text': text,
    if (isFallback) 'fallback': true,
    if (fromOcr) 'ocr': true,
  };

  factory ExtractedSection.fromJson(Map<String, dynamic> json) =>
      ExtractedSection(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        startPage: (json['start_page'] as num?)?.toInt() ?? 0,
        endPage: (json['end_page'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
        isFallback: json['fallback'] == true,
        fromOcr: json['ocr'] == true,
      );
}

/// The complete extraction artifact for one verified PDF.
class ExtractedBook {
  const ExtractedBook({
    required this.bookId,
    required this.sha256,
    required this.extractedAt,
    required this.pages,
    required this.sections,
    required this.textPageCount,
    required this.ocrPageCount,
    required this.warnings,
    required this.status,
    this.catalogSnapshot = const {},
    this.pageCount = 0,
    this.fromCache = false,
  });

  final String bookId;
  final String sha256;
  final DateTime extractedAt;
  final List<ExtractedPage> pages;
  final List<ExtractedSection> sections;

  final int textPageCount;
  final int ocrPageCount;
  final List<String> warnings;
  final BookExtractionStatus status;

  /// The catalog row at extraction time, so a later metadata change can
  /// invalidate explanations that quoted the old edition.
  final Map<String, dynamic> catalogSnapshot;

  final int pageCount;
  final bool fromCache;

  bool get isReady => status == BookExtractionStatus.ready;

  ExtractedBook copyWith({bool? fromCache}) => ExtractedBook(
    bookId: bookId,
    sha256: sha256,
    extractedAt: extractedAt,
    pages: pages,
    sections: sections,
    textPageCount: textPageCount,
    ocrPageCount: ocrPageCount,
    warnings: warnings,
    status: status,
    catalogSnapshot: catalogSnapshot,
    pageCount: pageCount,
    fromCache: fromCache ?? this.fromCache,
  );

  ExtractedSection? sectionById(String id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  /// Full-text search with the page of each hit.
  List<SearchHit> search(String query, {int limit = 40}) {
    final normalized = normalizeArabic(query).toLowerCase();
    if (normalized.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (final page in pages) {
      if (page.text.isEmpty) continue;
      final haystack = normalizeArabic(page.text).toLowerCase();
      if (!haystack.contains(normalized)) continue;
      final index = haystack.indexOf(normalized);
      final start = math.max(0, index - 60);
      final end = math.min(page.text.length, index + query.length + 80);
      hits.add(
        SearchHit(
          pageNumber: page.pageNumber,
          snippet: page.text.substring(start, end).trim(),
        ),
      );
      if (hits.length >= limit) break;
    }
    return hits;
  }

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'book_id': bookId,
    'sha256': sha256,
    'extracted_at': extractedAt.toIso8601String(),
    'page_count': pageCount,
    'text_page_count': textPageCount,
    'ocr_pages': ocrPageCount,
    'status': status.wire,
    'warnings': warnings,
    'catalog': catalogSnapshot,
    'sections': sections.map((section) => section.toJson()).toList(),
    'pages': pages.map((page) => page.toJson()).toList(),
  };

  factory ExtractedBook.fromJson(Map<String, dynamic> json) => ExtractedBook(
    bookId: json['book_id'] as String? ?? '',
    sha256: json['sha256'] as String? ?? '',
    extractedAt:
        DateTime.tryParse(json['extracted_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    pages: ((json['pages'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ExtractedPage.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false),
    sections: ((json['sections'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ExtractedSection.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false),
    textPageCount: (json['text_page_count'] as num?)?.toInt() ?? 0,
    ocrPageCount: (json['ocr_pages'] as num?)?.toInt() ?? 0,
    warnings: ((json['warnings'] as List?) ?? const [])
        .map((e) => '$e')
        .toList(growable: false),
    status: BookExtractionStatus.fromWire(json['status']),
    catalogSnapshot:
        (json['catalog'] as Map?)?.cast<String, dynamic>() ?? const {},
    pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
  );
}

/// A search result that names the page it came from.
class SearchHit {
  const SearchHit({required this.pageNumber, required this.snippet});

  final int pageNumber;
  final String snippet;
}
