/// Pure-Dart organisation of extracted PDF pages into lessons.
///
/// Kept out of `book_extraction.dart` so the sectioning rules can be tested
/// without Flutter, a PDF engine or a device. It never invents a lesson title:
/// it only uses a heading the book actually prints, or a labelled page range.
library;

import 'dart:math' as math;

import '../models/extraction.dart';
import '../models/official_book.dart';

/// A numeral or a written Arabic ordinal ("الأولى", "الثاني", …).
const String _number =
    r'(?:\d+|[٠-٩]+|[IVXLCivxlc]+|الأول|الأولى|الثاني|الثانية|الثالث|'
    r'الثالثة|الرابع|الرابعة|الخامس|الخامسة|السادس|السادسة|السابع|'
    r'السابعة|الثامن|الثامنة|التاسع|التاسعة|العاشر|العاشرة|'
    r'الحادي|الحادية|الثانى|الثانية)';

final List<RegExp> _headingPatterns = [
  RegExp('^(الوحدة|وحدة|الوحد\\S*)\\s*$_number'),
  RegExp('^(الفصل|فصل)\\s*$_number'),
  RegExp('^(الدرس|درس)\\s*$_number'),
  RegExp('^(الباب|باب)\\s*$_number'),
  RegExp('^(المحور|محور)\\s*$_number'),
  RegExp('^(الموضوع|موضوع)\\s*$_number'),
];

/// Normalises whitespace and control characters from one PDF page.
String cleanPageText(String value) => value
    .replaceAll('\u0000', '')
    .replaceAll(RegExp(r'[ \t]+\n'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Returns the first printed unit/lesson heading in [text], if any.
String? findHeading(String text) {
  if (text.isEmpty) return null;
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .take(12);
  for (final line in lines) {
    if (line.length > 90) continue;
    for (final pattern in _headingPatterns) {
      if (pattern.hasMatch(line)) return line;
    }
  }
  return null;
}

/// Groups [pages] under the headings they print, or into labelled page ranges.
///
/// Headings too close together are treated as recurring page headers rather
/// than new chapters. Only the first heading on a page counts.
List<ExtractedSection> buildSections(
  List<ExtractedPage> pages,
  List<String> warnings,
) {
  final headings = <({int index, String title})>[];
  String? previous;
  for (final page in pages) {
    final heading = findHeading(page.text);
    if (heading == null) continue;
    if (previous != null &&
        normalizeArabic(previous) == normalizeArabic(heading)) {
      continue;
    }
    previous = heading;
    headings.add((index: page.pageNumber - 1, title: heading));
  }

  final sections = <ExtractedSection>[];
  var sectionCount = 0;

  void addSection(int start, int end, String title, bool fallback) {
    if (start < 0 || end < start || start >= pages.length) return;
    final slice = pages.sublist(start, math.min(end + 1, pages.length));
    final text = slice
        .map((page) => page.text)
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    if (text.trim().isEmpty) return;
    sectionCount++;
    sections.add(
      ExtractedSection(
        id: 's$sectionCount',
        title: title,
        startPage: slice.first.pageNumber,
        endPage: slice.last.pageNumber,
        text: text,
        isFallback: fallback,
        fromOcr: slice.any((page) => page.fromOcr),
      ),
    );
  }

  // Headings too close together are usually recurring page headers, not
  // chapters. Keep one per page at most and require at least two pages of
  // material unless it is the last heading.
  if (headings.length >= 2) {
    for (var i = 0; i < headings.length; i++) {
      final start = headings[i].index;
      final end = i + 1 < headings.length
          ? headings[i + 1].index - 1
          : pages.length - 1;
      if (end <= start && i + 1 < headings.length) {
        // A heading with no body: fold it into the next section.
        continue;
      }
      addSection(start, end, headings[i].title, false);
    }
  }

  if (sections.isEmpty) {
    const chunk = 8;
    for (var start = 0; start < pages.length; start += chunk) {
      final end = math.min(start + chunk - 1, pages.length - 1);
      addSection(
        start,
        end,
        'الصفحات ${pages[start].pageNumber}–${pages[end].pageNumber}',
        true,
      );
    }
    if (sections.isEmpty) {
      warnings.add('مفيش صفحات فيها نص نقدر نرتّبها في دروس.');
    }
  }
  return sections;
}
