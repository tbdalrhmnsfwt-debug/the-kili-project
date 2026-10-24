import 'package:flutter_test/flutter_test.dart';

import '../lib/core/book_sectioning.dart';
import '../lib/models/extraction.dart';
import '../lib/models/official_book.dart';

ExtractedPage _page(int number, String text, {bool fromOcr = false}) =>
    ExtractedPage(pageNumber: number, text: text, fromOcr: fromOcr);

void main() {
  group('findHeading', () {
    test('recognises printed unit/lesson headings', () {
      expect(findHeading('الوحدة الأولى\nمقدمة'), 'الوحدة الأولى');
      expect(findHeading('الدرس 3: المتجهات'), 'الدرس 3: المتجهات');
      expect(findHeading('الفصل ٢\nالكيمياء'), 'الفصل ٢');
      expect(findHeading('الباب IV'), 'الباب IV');
      expect(findHeading('المحور 1'), 'المحور 1');
    });

    test('ignores ordinary paragraphs and very long lines', () {
      expect(findHeading('هذا شرح عادي للدرس بدون عنوان مطبوع'), isNull);
      expect(findHeading(''), isNull);
      expect(findHeading('الدرس 1 ${'طويل ' * 40}'), isNull);
    });
  });

  group('buildSections', () {
    test('groups pages between real printed headings', () {
      final pages = [
        _page(1, 'غلاف الكتاب'),
        _page(2, 'الدرس 1: الأعداد\nمقدمة الدرس'),
        _page(3, 'شرح الأعداد'),
        _page(4, 'الدرس 2: الجبر\nمقدمة الجبر'),
        _page(5, 'شرح الجبر'),
      ];
      final sections = buildSections(pages, []);
      expect(sections, hasLength(2));
      expect(sections.first.title, 'الدرس 1: الأعداد');
      expect(sections.first.startPage, 2);
      expect(sections.first.endPage, 3);
      expect(sections.first.isFallback, isFalse);
      expect(sections.last.title, 'الدرس 2: الجبر');
      expect(sections.last.startPage, 4);
      expect(sections.last.endPage, 5);
      expect(sections.last.text, contains('شرح الجبر'));
      expect(sections.first.id, 's1');
      expect(sections.last.id, 's2');
    });

    test('a repeated running header is only used once', () {
      final pages = [
        _page(1, 'الوحدة 1\nمقدمة'),
        _page(2, 'الوحدة 1\nمحتوى'),
        _page(3, 'الوحدة 1\nمحتوى إضافي'),
      ];
      final sections = buildSections(pages, []);
      expect(sections, hasLength(1));
      expect(sections.single.startPage, 1);
      expect(sections.single.endPage, 3);
    });

    test('a heading with no body folds into the next section', () {
      final pages = [
        _page(1, 'الدرس 1\nمقدمة'),
        _page(2, 'الدرس 2\nتمارين'),
        _page(3, 'حل التمارين'),
      ];
      final sections = buildSections(pages, []);
      expect(sections, hasLength(1));
      expect(sections.single.startPage, 2);
      expect(sections.single.title, 'الدرس 2');
    });

    test('falls back to labelled page ranges with a warning', () {
      final pages = [
        for (var i = 1; i <= 20; i++) _page(i, 'نص عادي صفحة $i'),
      ];
      final warnings = <String>[];
      final sections = buildSections(pages, warnings);

      expect(sections, hasLength(3));
      expect(sections.every((section) => section.isFallback), isTrue);
      expect(sections.first.title, 'الصفحات 1–8');
      expect(sections[1].title, 'الصفحات 9–16');
      expect(sections.last.title, 'الصفحات 17–20');
    });

    test('skips empty pages and reports when there is nothing to organise',
        () {
      final warnings = <String>[];
      final sections = buildSections([
        _page(1, '   '),
        _page(2, ''),
      ], warnings);

      expect(sections, isEmpty);
      expect(warnings, contains(contains('مفيش صفحات')));
    });

    test('marks a section that contains OCR pages', () {
      final pages = [
        _page(1, 'الدرس 1\nمقدمة'),
        _page(2, 'نص من OCR', fromOcr: true),
      ];
      final sections = buildSections(pages, []);
      expect(sections.single.fromOcr, isTrue);
      expect(sections.single.pageCount, 2);
    });
  });

  group('cleanPageText', () {
    test('removes control characters and collapses blank lines', () {
      expect(
        cleanPageText('  سطر\u0000 واحد  \n\n\n\nسطر ثاني  '),
        'سطر واحد\n\nسطر ثاني',
      );
      expect(cleanPageText('نص\t\nتاني'), 'نص\nتاني');
    });
  });

  group('ExtractedBook.search', () {
    test('returns snippets with page numbers', () {
      final book = ExtractedBook(
        bookId: 'b',
        sha256: 's',
        extractedAt: DateTime(2026),
        pages: [
          _page(1, 'هذا نص عن المتجهات في الرياضيات'),
          _page(2, 'نص آخر'),
        ],
        sections: const [],
        textPageCount: 2,
        ocrPageCount: 0,
        warnings: const [],
        status: BookExtractionStatus.ready,
      );

      final hits = book.search('المتجهات');
      expect(hits, hasLength(1));
      expect(hits.single.pageNumber, 1);
      expect(hits.single.snippet, contains('المتجهات'));
    });

    test('normalises Arabic diacritics and alef forms', () {
      final book = ExtractedBook(
        bookId: 'b',
        sha256: 's',
        extractedAt: DateTime(2026),
        pages: [_page(1, 'إِنَّ الْحَمْدَ لِلَّهِ')],
        sections: const [],
        textPageCount: 1,
        ocrPageCount: 0,
        warnings: const [],
        status: BookExtractionStatus.ready,
      );
      expect(book.search('الحمد'), isNotEmpty);
      expect(book.search('   '), isEmpty);
    });
  });
}
