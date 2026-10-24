/// Word-level masking for the hifz session. Pure Dart so it can be tested
/// without rendering.
library;

import 'dart:math';

import 'hifz_models.dart';

/// Splits an ayah into words on whitespace, dropping empty pieces.
List<String> hifzSplitWords(String ayah) => ayah
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList(growable: false);

/// The indexes hidden for [mode] out of [wordCount] words.
///
/// [seed] makes [HifzHideMode.randomWords] stable for one ayah, so rebuilding
/// a widget never reshuffles what the student is reciting.
Set<int> hifzHiddenIndexes({
  required int wordCount,
  required HifzHideMode mode,
  required int seed,
}) {
  if (wordCount <= 0) return const <int>{};

  switch (mode) {
    case HifzHideMode.none:
      return const <int>{};
    case HifzHideMode.wholeAyah:
      return {for (var i = 0; i < wordCount; i++) i};
    case HifzHideMode.lastWords:
      final hidden = max(1, wordCount ~/ 3);
      return {for (var i = wordCount - hidden; i < wordCount; i++) i};
    case HifzHideMode.alternateWords:
      return {for (var i = 1; i < wordCount; i += 2) i};
    case HifzHideMode.randomWords:
      final random = Random(seed);
      final hidden = <int>{
        for (var i = 0; i < wordCount; i++)
          if (random.nextDouble() < 0.4) i,
      };
      if (hidden.isEmpty) hidden.add(0);
      if (hidden.length == wordCount && wordCount > 1) hidden.remove(0);
      return hidden;
  }
}

/// One ayah prepared for recitation: its words and which ones are hidden.
class HifzAyahMask {
  const HifzAyahMask({required this.words, required this.hidden});

  final List<String> words;
  final Set<int> hidden;

  bool get isFullyHidden => words.isNotEmpty && hidden.length == words.length;

  int get visibleCount => words.length - hidden.length;
}

/// Builds the mask for [ayah]. [seed] should be stable per ayah (its number).
HifzAyahMask hifzAyahMask(
  String ayah, {
  required HifzHideMode mode,
  required int seed,
}) {
  final words = hifzSplitWords(ayah);
  return HifzAyahMask(
    words: words,
    hidden: hifzHiddenIndexes(wordCount: words.length, mode: mode, seed: seed),
  );
}
