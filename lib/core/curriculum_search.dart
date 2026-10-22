/// Offline answers grounded in the textbooks that ship with the app.
///
/// The assistant is only as useful as the content it can reach offline. This
/// index reads the plaintext `figs/<book id>.json` payloads (74 books at the
/// time of writing) and indexes their figure labels and narration sentences.
/// When the cloud model is unreachable, [CurriculumSearch.answer] finds the
/// passages that share words with the question and returns them with the book
/// and grade they came from, instead of an empty canned reply.
library;

import 'asset_service.dart';

/// One searchable passage: a narration sentence or a figure's label list.
class _Passage {
  const _Passage({
    required this.bookTitle,
    required this.subject,
    required this.gradeLabel,
    required this.lesson,
    required this.page,
    required this.text,
  });

  final String bookTitle;
  final String subject;
  final String gradeLabel;
  final int lesson;
  final int? page;
  final String text;
}

/// Searches the readable bundled books for passages relevant to a question.
class CurriculumSearch {
  CurriculumSearch(this._assets);

  final AssetService _assets;

  List<_Passage>? _passages;

  /// Builds the index once and reuses it for the life of the service.
  Future<List<_Passage>> _ensureIndex() async {
    final cached = _passages;
    if (cached != null) return cached;

    final out = <_Passage>[];
    for (final grade in await _assets.loadAllGrades()) {
      for (final book in grade.books) {
        final json = await _assets.loadPlaintext(book);
        if (json == null) continue;
        final lessons = json['l'];
        if (lessons is! Map) continue;
        lessons.forEach((lessonKey, entries) {
          if (entries is! List) return;
          final lesson = int.tryParse('$lessonKey') ?? 0;
          for (final raw in entries) {
            if (raw is! Map) continue;
            final page = raw['p'];
            final pageNumber = page is num ? page.toInt() : null;

            final narration = raw['nr'];
            if (narration is String && narration.trim().isNotEmpty) {
              out.add(
                _Passage(
                  bookTitle: book.title,
                  subject: book.subject,
                  gradeLabel: grade.label,
                  lesson: lesson + 1,
                  page: pageNumber,
                  text: narration.trim(),
                ),
              );
            }

            final labels = raw['lb'];
            if (labels is List && labels.isNotEmpty) {
              final text = labels
                  .whereType<String>()
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .join(' · ');
              if (text.isNotEmpty) {
                out.add(
                  _Passage(
                    bookTitle: book.title,
                    subject: book.subject,
                    gradeLabel: grade.label,
                    lesson: lesson + 1,
                    page: pageNumber,
                    text: text,
                  ),
                );
              }
            }
          }
        });
      }
    }
    _passages = out;
    return out;
  }

  /// Returns a short, source-attributed answer for [question], or `null` when
  /// no bundled passage is relevant enough.
  Future<String?> answer(String question, {String? subject}) async {
    final indexed = await _ensureIndex();
    if (indexed.isEmpty) return null;

    final terms = _tokens(question);
    if (terms.isEmpty) return null;

    final scored = <({_Passage passage, int score})>[];
    for (final passage in indexed) {
      final haystack = _normalize(passage.text);
      var score = 0;
      for (final term in terms) {
        if (haystack.contains(term)) score++;
      }
      if (score == 0) continue;
      // Prefer the subject the user is already working in.
      if (subject != null &&
          _normalize(passage.subject).contains(_normalize(subject))) {
        score += 2;
      }
      scored.add((passage: passage, score: score));
    }
    if (scored.isEmpty) return null;

    scored.sort((a, b) => b.score.compareTo(a.score));
    // Require more than a single accidental word match.
    final best = scored.first.score;
    final threshold = best >= 3 ? 2 : 1;
    final picked = scored
        .where((e) => e.score >= threshold)
        .take(3)
        .toList(growable: false);
    if (picked.isEmpty) return null;

    final buffer = StringBuffer(
      'دي أقرب حاجة لقيتها في كتبك على الجهاز:\n',
    );
    for (final entry in picked) {
      final p = entry.passage;
      buffer
        ..write('\n• ${p.text}\n')
        ..write(
          '  — ${p.bookTitle} (${p.gradeLabel})'
          '${p.page == null ? '' : '، ص ${p.page}'}\n',
        );
    }
    buffer.write('\nافتح الدرس نفسه لو عايز الشرح كامل.');
    return buffer.toString();
  }

  static final RegExp _splitter = RegExp(r'[^A-Za-z0-9؀-ۿ]+');
  static final RegExp _diacritics = RegExp(
    '[ً-ْٰـ]',
    unicode: true,
  );

  static List<String> _tokens(String text) {
    return _normalize(text)
        .split(_splitter)
        .map((t) => t.trim())
        .where((t) => t.length >= 3)
        .where((t) => !_stopWords.contains(t))
        .toSet()
        .take(12)
        .toList(growable: false);
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(_diacritics, '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  /// Words that carry no retrieval signal in Arabic or English.
  static const Set<String> _stopWords = {
    'the', 'and', 'for', 'what', 'with', 'this', 'that', 'from', 'are',
    'was', 'were', 'have', 'has', 'how', 'why', 'when', 'where', 'which',
    'into', 'about', 'على', 'عن', 'في', 'من', 'الى', 'إلى', 'اللي', 'التي',
    'الذي', 'هذا', 'هذه', 'ذلك', 'كل', 'مع', 'هو', 'هي', 'ما', 'ماذا',
    'ايه', 'إيه', 'ازاي', 'إزاي', 'هل', 'يعني', 'وضح', 'اشرح', 'اشرحلي',
  };
}
