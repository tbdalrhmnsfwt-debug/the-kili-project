import 'package:flutter_test/flutter_test.dart';

import '../lib/models/official_book.dart';

void main() {
  test('an empty catalog has no books', () {
    final catalog = OfficialBookCatalog.fromJson({
      'version': 1,
      'updated': '',
      'books': <dynamic>[],
    });

    expect(catalog.isEmpty, isTrue);
    expect(catalog.forGradeSubject('sec1', 'الرياضيات'), isEmpty);
  });

  test('filters official books by grade and subject', () {
    final catalog = OfficialBookCatalog.fromJson({
      'version': 1,
      'updated': '2026-10-24',
      'books': [
        {
          'id': 'math-sec1',
          'grade': 'sec1',
          'subject': 'الرياضيات',
          'title': 'الرياضيات — أولى ثانوي',
          'url': 'https://example.invalid/math-sec1.pdf',
          'source': 'official',
        },
        {
          'id': 'arabic-sec1',
          'grade': 'sec1',
          'subject': 'اللغة العربية',
          'title': 'اللغة العربية — أولى ثانوي',
          'url': 'https://example.invalid/arabic-sec1.pdf',
          'source': 'official',
        },
      ],
    });

    final matches = catalog.forGradeSubject('sec1', 'الرياضيات');
    expect(matches, hasLength(1));
    expect(matches.single.id, 'math-sec1');
    expect(catalog.forGradeSubject('sec2', 'الرياضيات'), isEmpty);
    expect(catalog.forGradeSubject('sec1', 'العلوم'), isEmpty);
  });
}
