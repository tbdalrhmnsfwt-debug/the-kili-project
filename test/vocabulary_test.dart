import 'package:flutter_test/flutter_test.dart';

import '../lib/core/vocabulary.dart';

void main() {
  const translations = {
    'vector': 'متجه',
    'magnitude': 'مقدار',
    'direction': 'اتجاه',
    'mass': 'كتلة',
  };

  const pages = [
    VocabularyPage(
      pageNumber: 4,
      text: 'A vector has magnitude and direction. The vector is drawn '
          'as an arrow. Mass is not a vector.',
    ),
    VocabularyPage(
      pageNumber: 9,
      text: 'Direction matters, and the vector stays the same.',
    ),
  ];

  test('only returns words the dictionary can gloss', () {
    final items = extractVocabulary(pages: pages, translations: translations);
    expect(items, isNotEmpty);
    expect(items.every((item) => translations.containsKey(item.term)), isTrue);
    expect(items.every((item) => item.translation.trim().isNotEmpty), isTrue);
  });

  test('ranks by frequency and keeps the first page', () {
    final items = extractVocabulary(pages: pages, translations: translations);
    expect(items.first.term, 'vector');
    expect(items.first.occurrences, 4);
    expect(items.first.page, 4);
  });

  test('keeps a context window around the word', () {
    final items = extractVocabulary(pages: pages, translations: translations);
    expect(items.first.context.toLowerCase(), contains('vector'));
    expect(items.first.context.length, lessThanOrEqualTo(181));
  });

  test('skips stop words and words missing from the dictionary', () {
    final items = extractVocabulary(pages: pages, translations: translations);
    expect(items.any((item) => item.term == 'and'), isFalse);
    expect(items.any((item) => item.term == 'arrow'), isFalse);
  });

  test('handles empty inputs and limits', () {
    expect(extractVocabulary(pages: const [], translations: translations), isEmpty);
    expect(extractVocabulary(pages: pages, translations: const {}), isEmpty);
    expect(
      extractVocabulary(pages: pages, translations: translations, limit: 0),
      isEmpty,
    );
    expect(
      extractVocabulary(pages: pages, translations: translations, limit: 2).length,
      2,
    );
  });

  test('matches case-insensitively and counts variants together', () {
    final items = extractVocabulary(
      pages: const [
        VocabularyPage(pageNumber: 1, text: 'VECTOR Vector vector.'),
      ],
      translations: translations,
    );
    expect(items.single.term, 'vector');
    expect(items.single.occurrences, 3);
  });

  test('keeps apostrophes inside a word', () {
    final items = extractVocabulary(
      pages: const [
        VocabularyPage(pageNumber: 2, text: "Newton's law explains motion."),
      ],
      translations: const {"newton's": 'نيوتن', 'motion': 'حركة'},
    );
    expect(items.map((item) => item.term), contains("newton's"));
  });

  test('Arabic-only text never produces Latin vocabulary', () {
    final items = extractVocabulary(
      pages: const [
        VocabularyPage(pageNumber: 3, text: 'المتجه كمية لها مقدار واتجاه.'),
      ],
      translations: translations,
    );
    expect(items, isEmpty);
  });
}
