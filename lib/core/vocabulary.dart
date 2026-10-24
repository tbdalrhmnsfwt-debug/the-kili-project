/// Extracts study vocabulary from an official passage and glosses it with the
/// app's bundled English→Arabic dictionary.
///
/// Everything here is extractive: a word only appears with a translation that
/// already exists in the dictionary, and every item carries the page it was
/// first seen on. No translation is guessed or machine-invented.
library;

/// One page of source text.
class VocabularyPage {
  const VocabularyPage({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

/// A word quoted from the book, its dictionary gloss and its page.
class VocabularyItem {
  const VocabularyItem({
    required this.term,
    required this.translation,
    required this.page,
    required this.context,
    required this.occurrences,
  });

  final String term;
  final String translation;
  final int page;

  /// The sentence the word was found in, for revision in context.
  final String context;

  final int occurrences;
}

/// Common English words that are not worth a vocabulary card.
const Set<String> _stopWords = {
  'about', 'after', 'again', 'against', 'also', 'among', 'another', 'because',
  'been', 'before', 'being', 'between', 'both', 'could', 'does', 'doing',
  'down', 'during', 'each', 'from', 'further', 'have', 'having', 'here',
  'into', 'itself', 'just', 'more', 'most', 'much', 'must', 'only', 'other',
  'over', 'same', 'should', 'some', 'such', 'than', 'that', 'their', 'them',
  'then', 'there', 'these', 'they', 'this', 'those', 'through', 'under',
  'until', 'very', 'were', 'what', 'when', 'where', 'which', 'while',
  'with', 'would', 'your', 'yours', 'however', 'therefore', 'thus',
  'using', 'used', 'use', 'can', 'may', 'might', 'shall',
};

/// Picks up to [limit] useful words that the dictionary can actually gloss.
List<VocabularyItem> extractVocabulary({
  required List<VocabularyPage> pages,
  required Map<String, String> translations,
  int limit = 12,
}) {
  if (pages.isEmpty || translations.isEmpty || limit <= 0) return const [];

  final counts = <String, int>{};
  final firstPage = <String, int>{};
  final contexts = <String, String>{};

  for (final page in pages) {
    final matches = RegExp(r"[A-Za-z][A-Za-z'-]{3,}").allMatches(page.text);
    for (final match in matches) {
      final word = match.group(0)?.toLowerCase();
      if (word == null || _stopWords.contains(word)) continue;
      final translation = translations[word];
      if (translation == null || translation.trim().isEmpty) continue;
      counts[word] = (counts[word] ?? 0) + 1;
      firstPage.putIfAbsent(word, () => page.pageNumber);
      contexts.putIfAbsent(word, () => _context(page.text, match.start));
    }
  }

  final ranked = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      if (byCount != 0) return byCount;
      return a.compareTo(b);
    });

  return [
    for (final word in ranked.take(limit))
      VocabularyItem(
        term: word,
        translation: translations[word]!,
        page: firstPage[word]!,
        context: contexts[word]!,
        occurrences: counts[word]!,
      ),
  ];
}

/// A short window around [index] inside [text], on sentence boundaries when
/// possible, so the student can revise the word in context.
String _context(String text, int index) {
  const window = 120;
  var start = index - window;
  var end = index + window;
  if (start < 0) start = 0;
  if (end > text.length) end = text.length;
  var snippet = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (start > 0) {
    final boundary = snippet.indexOf(RegExp(r'[.!?]\s'));
    if (boundary >= 0) snippet = snippet.substring(boundary + 1).trim();
  }
  if (end < text.length) {
    final boundary = snippet.lastIndexOf(RegExp(r'[.!?]\s'));
    if (boundary > 20) snippet = snippet.substring(0, boundary + 1).trim();
  }
  if (snippet.length > 180) snippet = '${snippet.substring(0, 180)}…';
  return snippet;
}
