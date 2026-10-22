/// The "mistakes notebook" (`دفتر أخطائي`) model.
///
/// The shipped string states the schedule precisely:
/// `أي سؤال بتغلط فيه — في بنك الأسئلة أو الامتحانات أو التحدي — بيتسجل
/// هنا لوحده، وبيرجعلك بعد يوم وبعدين 3 أيام لحد ما تجاوبه صح 3 مرات
/// فيخرج متقن.`
library;

import 'dart:convert';

/// A question the user got wrong, tracked until it is mastered.
class MistakeEntry {
  const MistakeEntry({
    required this.id,
    required this.prompt,
    required this.bookId,
    this.lessonNumber,
    this.options = const [],
    this.correctIndex,
    this.correctAnswer = '',
    this.timesWrong = 1,
    this.timesCorrect = 0,
    this.confident = false,
    this.createdAt,
    this.dueAt,
    this.mastered = false,
  });

  final String id;
  final String prompt;
  final String bookId;
  final int? lessonNumber;
  final List<String> options;

  /// Index into [options] of the correct answer.
  final int? correctIndex;

  final String correctAnswer;

  /// How many times the user got this wrong.
  final int timesWrong;

  /// How many times the user has since got it right.
  final int timesCorrect;

  /// True when the user marked themselves "sure" and still got it wrong.
  ///
  /// The shipped string calls this the most dangerous bucket:
  /// `«متأكد وغلط» أخطر خانة — بترجعلك أول حاجة تاني يوم.`
  final bool confident;

  final DateTime? createdAt;

  /// When this entry should come back.
  final DateTime? dueAt;

  /// True once the user has answered correctly three times.
  final bool mastered;

  /// Whether the entry is due for review.
  bool isDue([DateTime? now]) {
    final reference = now ?? DateTime.now();
    if (mastered) return false;
    if (dueAt == null) return true;
    return !dueAt!.isAfter(reference);
  }

  /// Records another wrong answer and reschedules the review.
  ///
  /// A "confident wrong" comes back the very next day.
  MistakeEntry failed({bool wasConfident = false, DateTime? now}) {
    final reference = now ?? DateTime.now();
    return MistakeEntry(
      id: id,
      prompt: prompt,
      bookId: bookId,
      lessonNumber: lessonNumber,
      options: options,
      correctIndex: correctIndex,
      correctAnswer: correctAnswer,
      timesWrong: timesWrong + 1,
      timesCorrect: 0,
      confident: wasConfident,
      createdAt: createdAt,
      dueAt: reference.add(const Duration(days: 1)),
      mastered: false,
    );
  }

  /// Records a correct answer and advances the review ladder.
  ///
  /// The ladder is 1 day, then 3 days, then 7; three consecutive successes
  /// master the entry and remove it from the notebook.
  MistakeEntry passed({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final correct = timesCorrect + 1;
    const ladder = [1, 3, 7];
    final days = ladder[(correct - 1).clamp(0, ladder.length - 1)];
    return MistakeEntry(
      id: id,
      prompt: prompt,
      bookId: bookId,
      lessonNumber: lessonNumber,
      options: options,
      correctIndex: correctIndex,
      correctAnswer: correctAnswer,
      timesWrong: timesWrong,
      timesCorrect: correct,
      confident: confident,
      createdAt: createdAt,
      dueAt: reference.add(Duration(days: days)),
      mastered: correct >= 3,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        'bookId': bookId,
        if (lessonNumber != null) 'lesson': lessonNumber,
        if (options.isNotEmpty) 'options': options,
        if (correctIndex != null) 'correctIndex': correctIndex,
        if (correctAnswer.isNotEmpty) 'correctAnswer': correctAnswer,
        'timesWrong': timesWrong,
        'timesCorrect': timesCorrect,
        'confident': confident,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
        'mastered': mastered,
      };

  factory MistakeEntry.fromJson(Map<String, dynamic> json) => MistakeEntry(
        id: json['id'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        bookId: json['bookId'] as String? ?? '',
        lessonNumber: (json['lesson'] as num?)?.toInt(),
        options: (json['options'] as List?)?.cast<String>() ?? const [],
        correctIndex: (json['correctIndex'] as num?)?.toInt(),
        correctAnswer: json['correctAnswer'] as String? ?? '',
        timesWrong: (json['timesWrong'] as num?)?.toInt() ?? 1,
        timesCorrect: (json['timesCorrect'] as num?)?.toInt() ?? 0,
        confident: json['confident'] as bool? ?? false,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        dueAt: json['dueAt'] == null
            ? null
            : DateTime.tryParse(json['dueAt'] as String),
        mastered: json['mastered'] as bool? ?? false,
      );
}

/// The mistakes notebook.
class MistakeNotebook {
  const MistakeNotebook({List<MistakeEntry>? entries})
    : entries = entries ?? const <MistakeEntry>[];

  final List<MistakeEntry> entries;

  int get total => entries.length;

  /// Entries still waiting to be mastered.
  int get open => entries.where((e) => !e.mastered).length;

  /// Entries the user was "sure" about and still got wrong.
  int get confidentCount => entries.where((e) => e.confident && !e.mastered).length;

  /// The entries due for review, most confident-wrong first.
  List<MistakeEntry> due([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final list = entries.where((e) => e.isDue(reference)).toList()
      ..sort((a, b) {
        if (a.confident != b.confident) return a.confident ? -1 : 1;
        final ad = a.dueAt, bd = b.dueAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    return list;
  }
}

/// Encodes a notebook for persistence.
String encodeMistakeNotebook(MistakeNotebook notebook) =>
    jsonEncode({'entries': notebook.entries.map((e) => e.toJson()).toList()});

/// Decodes a notebook persisted by [encodeMistakeNotebook].
MistakeNotebook decodeMistakeNotebook(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return MistakeNotebook(
    entries: ((json['entries'] as List?) ?? const [])
        .map((e) => MistakeEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
