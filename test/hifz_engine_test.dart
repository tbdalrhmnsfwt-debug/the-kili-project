import 'package:flutter_test/flutter_test.dart';

import '../lib/features/hifz/hifz_engine.dart';
import '../lib/features/hifz/hifz_models.dart';

void main() {
  group('hifzSplitWords', () {
    test('splits an ayah into whitespace-separated words', () {
      expect(
        hifzSplitWords('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'),
        ['بِسْمِ', 'اللَّهِ', 'الرَّحْمَٰنِ', 'الرَّحِيمِ'],
      );
    });

    test('collapses repeated whitespace and trims', () {
      expect(hifzSplitWords('  إِنَّا   أَعْطَيْنَاكَ  '), [
        'إِنَّا',
        'أَعْطَيْنَاكَ',
      ]);
    });
  });

  group('hifzHiddenIndexes', () {
    test('none hides nothing', () {
      expect(
        hifzHiddenIndexes(
          wordCount: 6,
          mode: HifzHideMode.none,
          seed: 7,
        ),
        isEmpty,
      );
    });

    test('wholeAyah hides every word', () {
      expect(
        hifzHiddenIndexes(
          wordCount: 4,
          mode: HifzHideMode.wholeAyah,
          seed: 7,
        ),
        {0, 1, 2, 3},
      );
    });

    test('lastWords hides the final third, at least one word', () {
      expect(
        hifzHiddenIndexes(
          wordCount: 9,
          mode: HifzHideMode.lastWords,
          seed: 7,
        ),
        {6, 7, 8},
      );
      expect(
        hifzHiddenIndexes(
          wordCount: 2,
          mode: HifzHideMode.lastWords,
          seed: 7,
        ),
        {1},
      );
    });

    test('alternateWords hides every second word', () {
      expect(
        hifzHiddenIndexes(
          wordCount: 5,
          mode: HifzHideMode.alternateWords,
          seed: 7,
        ),
        {1, 3},
      );
    });

    test('randomWords is deterministic for a seed and hides some words', () {
      final first = hifzHiddenIndexes(
        wordCount: 12,
        mode: HifzHideMode.randomWords,
        seed: 42,
      );
      final again = hifzHiddenIndexes(
        wordCount: 12,
        mode: HifzHideMode.randomWords,
        seed: 42,
      );
      expect(first, again);
      expect(first, isNotEmpty);
      expect(first.length, lessThan(12));
      expect(first.every((i) => i >= 0 && i < 12), isTrue);
    });

    test('empty ayahs hide nothing', () {
      for (final mode in HifzHideMode.values) {
        expect(hifzHiddenIndexes(wordCount: 0, mode: mode, seed: 1), isEmpty);
      }
    });
  });

  group('hifzAyahMask', () {
    test('exposes the words with their hidden flags', () {
      final mask = hifzAyahMask(
        'قُلْ هُوَ اللَّهُ أَحَدٌ',
        mode: HifzHideMode.lastWords,
        seed: 3,
      );
      expect(mask.words.length, 4);
      expect(mask.hidden, {3});
      expect(mask.isFullyHidden, isFalse);
      expect(mask.visibleCount, 3);
    });

    test('a fully hidden ayah reports itself as such', () {
      final mask = hifzAyahMask(
        'قُلْ هُوَ اللَّهُ أَحَدٌ',
        mode: HifzHideMode.wholeAyah,
        seed: 3,
      );
      expect(mask.isFullyHidden, isTrue);
      expect(mask.visibleCount, 0);
    });
  });
}
