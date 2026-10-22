/// Builds exam questions from the bundled textbook content.
///
/// The original app generates question banks per lesson, either on-device or
/// through the AI service. Until the model is wired up, the replica derives
/// cloze (fill-in-the-blank) questions directly from the narratives that ship
/// with each readable book. The result is genuine, book-specific practice
/// with no network round-trip.
library;

import '../models/exam.dart';
import '../models/manhaji.dart';

/// A candidate sentence with the word that will be blanked out.
class _ClozeCandidate {
  const _ClozeCandidate({
    required this.prompt,
    required this.answer,
    required this.lessonNumber,
  });

  final String prompt;
  final String answer;
  final int lessonNumber;
}

/// Words that make poor answers because they carry little meaning.
const _stopwords = <String>{
  // Arabic
  'من', 'في', 'على', 'إلى', 'الى', 'عن', 'أن', 'ان', 'إن', 'كان', 'كانت',
  'هذا', 'هذه', 'ذلك', 'تلك', 'التي', 'الذي', 'الذين', 'مع', 'أو', 'او',
  'ثم', 'قد', 'لا', 'ما', 'هو', 'هي', 'هم', 'كل', 'بعض', 'بين', 'بعد',
  'قبل', 'حتى', 'لكن', 'كما', 'عند', 'منذ', 'نحو', 'حول', 'خلال', 'دون',
  'غير', 'سوف', 'سو', 'ليس', 'ليست', 'فيه', 'فيها', 'منه', 'منها', 'عليه',
  'عليها', 'له', 'لها', 'لهم', 'كذلك', 'أيضا', 'أيضًا', 'ايضا', 'حيث',
  // French
  'les', 'des', 'une', 'aux', 'dans', 'pour', 'avec', 'que', 'qui', 'par',
  'sur', 'est', 'sont', 'pas', 'plus', 'comme', 'leur', 'leurs', 'cette',
  'ces', 'son', 'sa', 'ses', 'il', 'elle', 'ils', 'elles', 'nous', 'vous',
  // German
  'der', 'die', 'das', 'und', 'ist', 'sind', 'mit', 'von', 'den', 'dem',
  'ein', 'eine', 'nicht', 'auf', 'für', 'fur', 'auch', 'werden', 'wird',
  // English
  'the', 'and', 'that', 'with', 'this', 'these', 'those', 'from', 'have',
  'has', 'are', 'was', 'were', 'for', 'not', 'but', 'they', 'their',
};

// Arabic letters only — the broad ؀-ۿ range also contains the
// Arabic comma, semicolon and question mark, which must not become part of
// an answer. Trailing diacritics and tatweel are folded into the match so a
// blank leaves no stray marks behind.
const _letters = r'A-Za-zÀ-ÿء-يٱ-ۓۺ-ۼ';
final _wordPattern = RegExp(
  '[$_letters][$_letters\\u064B-\\u0652\\u0670\\u0640]*',
);
final _diacritics = RegExp(r'[ً-ْٰـ]');
final _sentenceBreaks = RegExp(r'[.!؟?؛\n\r]+');

/// Generates up to [maxQuestions] cloze questions from [lessons] of [book].
///
/// Returns an empty list when the content has no usable sentences.
List<ExamQuestion> generateClozeQuestions({
  required Book book,
  required List<Lesson> lessons,
  int maxQuestions = 8,
}) {
  final candidates = <_ClozeCandidate>[];
  final vocabulary = <String>{};

  for (final lesson in lessons) {
    for (final figure in lesson.figures) {
      for (final sentence in _sentences(figure.narrative)) {
        final tokens = _wordPattern.allMatches(sentence).toList();
        if (tokens.length < 6) continue;

        _Word? best;
        for (final match in tokens) {
          final word = match.group(0)!;
          final clean = _normalise(word);
          if (clean.length < 4 || _stopwords.contains(clean)) continue;
          vocabulary.add(word);
          if (best == null || clean.length > best.clean.length) {
            best = _Word(word, clean, match.start, match.end);
          }
        }
        if (best == null) continue;

        // Leave the sentence alone when the answer word occurs more than once:
        // the blank would otherwise be given away.
        final occurrences = RegExp(
          RegExp.escape(best.word),
        ).allMatches(sentence).length;
        if (occurrences != 1) continue;

        final prompt = sentence.replaceRange(best.start, best.end, '____');
        candidates.add(
          _ClozeCandidate(
            prompt: prompt,
            answer: best.word,
            lessonNumber: lesson.number,
          ),
        );
      }
    }
  }

  if (candidates.length < 4) return const [];

  final answers = <String>{for (final c in candidates) c.answer}.toList();
  final questions = <ExamQuestion>[];
  final usedPrompts = <String>{};

  for (var i = 0; i < candidates.length && questions.length < maxQuestions; i++) {
    final candidate = candidates[i];
    if (!usedPrompts.add(candidate.prompt)) continue;

    final distractors = <String>[];
    for (var step = 1; step <= answers.length && distractors.length < 3; step++) {
      final word = answers[(i + step) % answers.length];
      if (word == candidate.answer) continue;
      if (distractors.contains(word)) continue;
      distractors.add(word);
    }
    if (distractors.length < 3) continue;

    final options = [candidate.answer, ...distractors]..sort();
    questions.add(
      ExamQuestion(
        id: 'cloze-${book.id}-$i',
        prompt: candidate.prompt,
        answerKind: AnswerKind.multipleChoice,
        options: options,
        correctIndex: options.indexOf(candidate.answer),
        explanation:
            'الكلمة الناقصة: ${candidate.answer} — '
            'من «${book.title}»، الدرس ${candidate.lessonNumber}',
        lessonNumber: candidate.lessonNumber,
        source: 'local',
      ),
    );
  }

  return questions;
}

/// A short built-in bank used when no bundled book can be read.
List<ExamQuestion> demoExamQuestions() => const [
  ExamQuestion(
    id: 'q1',
    prompt: 'ناتج 12 × 8 يساوي كام؟',
    answerKind: AnswerKind.multipleChoice,
    options: ['96', '88', '104', '92'],
    correctIndex: 0,
    explanation: '12 × 8 = 96',
  ),
  ExamQuestion(
    id: 'q2',
    prompt: 'المستقيمان المتوازيان لا يتقاطعان أبدًا.',
    answerKind: AnswerKind.multipleChoice,
    options: ['صح', 'خطأ'],
    correctIndex: 0,
  ),
  ExamQuestion(
    id: 'q3',
    prompt: 'أكمّل: مجموع زوايا المثلث يساوي ... درجة',
    answerKind: AnswerKind.multipleChoice,
    options: ['90', '180', '270', '360'],
    correctIndex: 1,
  ),
];

/// A candidate word and where it sits in its sentence.
class _Word {
  const _Word(this.word, this.clean, this.start, this.end);

  final String word;
  final String clean;
  final int start;
  final int end;
}

Iterable<String> _sentences(String text) => text
    .split(_sentenceBreaks)
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty);

String _normalise(String word) =>
    word.replaceAll(_diacritics, '').toLowerCase();
