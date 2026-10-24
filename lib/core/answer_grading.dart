/// Free-text answer grading, kept free of Flutter so it can be unit tested.
library;

import '../models/exam.dart';
import '../models/official_book.dart';

/// Whether a choice question carries an answer that exists in its options.
///
/// Generated or imported banks can be malformed; an out-of-range index must
/// never be shown as a correct answer or crash the quiz screen.
bool hasValidChoiceAnswer(ExamQuestion question) {
  final index = question.correctIndex;
  return index != null && index >= 0 && index < question.options.length;
}

/// Whether tapping [selected] is correct for a choice question.
bool isChoiceAnswerCorrect(ExamQuestion question, int selected) =>
    hasValidChoiceAnswer(question) && question.correctIndex == selected;

/// Grades a free-text answer by overlap with the quoted model answer.
///
/// Very short answers cannot pass, and a near-empty model answer requires a
/// non-empty answer rather than pretending to grade it. This is deliberately
/// conservative: it is only used where the model answer is shown to the
/// student afterwards, so a false "correct" is worse than asking them to
/// compare their wording.
bool gradeShortAnswer(String given, ExamQuestion question) {
  final answer = normalizeArabic(given).trim();
  if (answer.isEmpty) return false;
  final model = normalizeArabic(question.modelAnswer).trim();
  if (model.isEmpty) return answer.length >= 8;
  final words = model
      .split(RegExp(r'\s+'))
      .where((word) => word.length >= 3)
      .toSet()
      .toList();
  if (words.isEmpty) return answer.length >= 8;
  final matched = words.where(answer.contains).length;
  final ratio = matched / words.length;
  // Containment only counts in the direction where the student wrote the full
  // model answer or more. The reverse ("the model contains the student's
  // single word") would mark a one-word fragment of a long answer correct.
  return ratio >= 0.4 || answer.contains(model);
}
