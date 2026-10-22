/// Exam / question-bank models.
///
/// The app generates exams and question banks per book and per subject, and
/// can also let the on-device LLM (llama.cpp via `llm_llamacpp`) produce
/// questions from a lesson. The recovered UI strings show the flow:
/// `# بنك أسئلة — {0}`, `# امتحان: {0}`, `# بين السطور — {0}`,
/// `# زتونة: {0}` and `# شيت المراجعة: {0}`.
library;

import 'dart:convert';

import 'manhaji.dart';

/// How an answer is graded.
enum AnswerKind {
  /// Multiple choice with a single correct option.
  multipleChoice,

  /// Free-text answer judged by the AI / keyword matching.
  freeText,
}

/// A single exam question.
class ExamQuestion {
  const ExamQuestion({
    required this.id,
    required this.prompt,
    required this.answerKind,
    this.options = const [],
    this.correctIndex,
    this.explanation = '',
    this.lessonNumber,
    this.source = 'local',
  });

  final String id;
  final String prompt;
  final AnswerKind answerKind;

  /// Option texts for multiple-choice questions.
  final List<String> options;

  /// Index into [options] of the correct answer.
  final int? correctIndex;

  final String explanation;

  /// Lesson this question was derived from, when known.
  final int? lessonNumber;

  /// `local` for bundled banks, `ai` for model-generated.
  final String source;

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final kind = switch (json['kind'] as String? ??
        json['type'] as String? ??
        '') {
      'freeText' || 'free_text' || 'text' => AnswerKind.freeText,
      _ => AnswerKind.multipleChoice,
    };
    return ExamQuestion(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? json['q'] as String? ?? '',
      answerKind: kind,
      options: (json['options'] as List?)?.cast<String>() ?? const [],
      correctIndex:
          (json['correctIndex'] as num?)?.toInt() ??
          (json['correct'] as num?)?.toInt(),
      explanation: json['explanation'] as String? ?? '',
      lessonNumber: (json['lesson'] as num?)?.toInt(),
      source: json['source'] as String? ?? 'local',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'kind': answerKind.name,
    if (options.isNotEmpty) 'options': options,
    if (correctIndex != null) 'correctIndex': correctIndex,
    if (explanation.isNotEmpty) 'explanation': explanation,
    if (lessonNumber != null) 'lesson': lessonNumber,
    'source': source,
  };

  /// Builds a question from a lesson figure's narrative text.
  factory ExamQuestion.fromFigure(Figure figure, {required int index}) {
    return ExamQuestion(
      id: 'f$index',
      prompt: figure.narrative,
      answerKind: AnswerKind.freeText,
      source: 'local',
    );
  }
}

/// The result of grading a single answer.
class AnswerResult {
  const AnswerResult({
    required this.questionId,
    required this.isCorrect,
    this.givenAnswer = '',
    this.correctAnswer = '',
    this.feedback = '',
  });

  final String questionId;
  final bool isCorrect;
  final String givenAnswer;
  final String correctAnswer;
  final String feedback;

  factory AnswerResult.fromJson(Map<String, dynamic> json) => AnswerResult(
    questionId: json['questionId'] as String? ?? '',
    isCorrect: json['isCorrect'] as bool? ?? false,
    givenAnswer: json['given'] as String? ?? '',
    correctAnswer: json['correct'] as String? ?? '',
    feedback: json['feedback'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'isCorrect': isCorrect,
    'given': givenAnswer,
    'correct': correctAnswer,
    if (feedback.isNotEmpty) 'feedback': feedback,
  };
}

/// An exam session: a set of questions plus the collected answers.
class ExamSession {
  ExamSession({
    required this.id,
    required this.title,
    required this.questions,
    this.bookId,
    this.subject,
    this.startedAt,
  });

  final String id;
  final String title;
  final List<ExamQuestion> questions;
  final String? bookId;
  final String? subject;
  final DateTime? startedAt;

  final Map<String, AnswerResult> answers = {};

  int get answeredCount => answers.length;
  int get total => questions.length;
  bool get isComplete => answeredCount >= total;
  double get progress => total == 0 ? 0 : answeredCount / total;

  int get correctCount => answers.values.where((a) => a.isCorrect).length;

  /// Percentage score in the range 0..100.
  double get score => total == 0 ? 0 : (correctCount / total) * 100;

  void record(AnswerResult result) => answers[result.questionId] = result;

  /// Serialises the session for persistence / sharing.
  String encode() => jsonEncode({
    'id': id,
    'title': title,
    'bookId': bookId,
    'subject': subject,
    'startedAt': startedAt?.toIso8601String(),
    'questions': questions.map((q) => q.toJson()).toList(),
    'answers': answers.values.map((a) => a.toJson()).toList(),
  });

  /// Restores a session previously produced by [encode].
  static ExamSession decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final session = ExamSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      bookId: json['bookId'] as String?,
      subject: json['subject'] as String?,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'] as String),
      questions: ((json['questions'] as List?) ?? const [])
          .map((e) => ExamQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    for (final a in (json['answers'] as List?) ?? const []) {
      session.record(AnswerResult.fromJson(a as Map<String, dynamic>));
    }
    return session;
  }
}

/// A saved question bank, e.g. "بنك أسئلة — الرياضيات".
class QuestionBank {
  const QuestionBank({
    required this.id,
    required this.title,
    required this.questions,
    this.subject,
    this.bookId,
  });

  final String id;
  final String title;
  final List<ExamQuestion> questions;
  final String? subject;
  final String? bookId;

  int get length => questions.length;

  factory QuestionBank.fromJson(Map<String, dynamic> json) => QuestionBank(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subject: json['subject'] as String?,
    bookId: json['bookId'] as String?,
    questions: ((json['questions'] as List?) ?? const [])
        .map((e) => ExamQuestion.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (subject != null) 'subject': subject,
    if (bookId != null) 'bookId': bookId,
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}
