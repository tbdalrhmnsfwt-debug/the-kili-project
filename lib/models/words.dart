/// English vocabulary: word lists and the spaced-repetition schedule.
///
/// The shipped strings describe a two-direction vocabulary trainer:
/// `وكل كلمة عندها **اتجاهين مستقلين**: إنجليزي ← عربي (تعرف)، وعربي ←
/// إنجليزي (إنتاج). مابتتحسبش متقنة غير لما الاتنين يعدوا — لأن اللي تعرف
/// معناها مش بالضرورة تعرف تجيبها.`
///
/// And a Leitner-style ladder driven by how often the word is answered:
/// `الكلمات اللي غلطت فيها هترجع لك بدري، واللي عرفتها فورًا هتغيب أكتر.`
library;

import 'dart:convert';

/// How well the user knows a word: 0 is new, 5 is mastered.
class WordEntry {
  const WordEntry({
    required this.id,
    required this.english,
    required this.arabic,
    this.note = '',
    this.box = 0,
    this.correctStreak = 0,
    this.wrongCount = 0,
    this.addedAt,
    this.lastReviewedAt,
  });

  final String id;

  /// The English form.
  final String english;

  /// The Arabic translation.
  final String arabic;

  /// An optional note attached to the word.
  final String note;

  /// The Leitner box: how far up the ladder the word has climbed.
  final int box;

  /// Consecutive correct answers.
  final int correctStreak;

  /// How many times the user has got this word wrong.
  final int wrongCount;

  final DateTime? addedAt;
  final DateTime? lastReviewedAt;

  /// The highest box a word can reach before it counts as mastered.
  static const int maxBox = 5;

  /// True once the word has climbed to the top of the ladder.
  bool get mastered => box >= maxBox;

  /// How many days until this word comes back.
  ///
  /// The shipped string calls out the ordering explicitly:
  /// `الكلمات اللي غلطت فيها هترجع لك بدري، واللي عرفتها فورًا هتغيب أكتر.`
  int get intervalDays {
    const ladder = [0, 1, 2, 4, 7, 15];
    final index = box < 0 ? 0 : (box > ladder.length - 1 ? ladder.length - 1 : box);
    return ladder[index];
  }

  /// Whether the word is due for review now.
  bool isDue([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final last = lastReviewedAt;
    if (last == null) return true;
    return !last.add(Duration(days: intervalDays)).isAfter(reference);
  }

  /// Records a correct answer and moves the word up the ladder.
  WordEntry correct({DateTime? now}) {
    final reference = now ?? DateTime.now();
    return WordEntry(
      id: id,
      english: english,
      arabic: arabic,
      note: note,
      box: box >= maxBox ? maxBox : box + 1,
      correctStreak: correctStreak + 1,
      wrongCount: wrongCount,
      addedAt: addedAt,
      lastReviewedAt: reference,
    );
  }

  /// Records a wrong answer and drops the word back down the ladder.
  WordEntry wrong({DateTime? now}) {
    final reference = now ?? DateTime.now();
    return WordEntry(
      id: id,
      english: english,
      arabic: arabic,
      note: note,
      box: box <= 0 ? 0 : box - 1,
      correctStreak: 0,
      wrongCount: wrongCount + 1,
      addedAt: addedAt,
      lastReviewedAt: reference,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'english': english,
        'arabic': arabic,
        if (note.isNotEmpty) 'note': note,
        'box': box,
        'correctStreak': correctStreak,
        'wrongCount': wrongCount,
        if (addedAt != null) 'addedAt': addedAt!.toIso8601String(),
        if (lastReviewedAt != null)
          'lastReviewedAt': lastReviewedAt!.toIso8601String(),
      };

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
        id: json['id'] as String? ?? '',
        english: json['english'] as String? ?? '',
        arabic: json['arabic'] as String? ?? '',
        note: json['note'] as String? ?? '',
        box: (json['box'] as num?)?.toInt() ?? 0,
        correctStreak: (json['correctStreak'] as num?)?.toInt() ?? 0,
        wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
        addedAt: json['addedAt'] == null
            ? null
            : DateTime.tryParse(json['addedAt'] as String),
        lastReviewedAt: json['lastReviewedAt'] == null
            ? null
            : DateTime.tryParse(json['lastReviewedAt'] as String),
      );
}

/// A named list of vocabulary.
class WordList {
  const WordList({
    required this.id,
    required this.title,
    List<WordEntry>? entries,
    this.createdAt,
  }) : entries = entries ?? const <WordEntry>[];

  final String id;
  final String title;
  final List<WordEntry> entries;
  final DateTime? createdAt;

  /// The entries due for review.
  List<WordEntry> due([DateTime? now]) =>
      entries.where((e) => e.isDue(now)).toList();

  /// The entries the user has mastered in both directions.
  int get mastered => entries.where((e) => e.mastered).length;

  /// The words the user keeps getting wrong.
  int get struggling => entries.where((e) => e.wrongCount > 0).length;

  /// Progress in the range 0..1.
  double get progress => entries.isEmpty ? 0 : mastered / entries.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  factory WordList.fromJson(Map<String, dynamic> json) => WordList(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        entries: ((json['entries'] as List?) ?? const [])
            .map((e) => WordEntry.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
      );
}

/// Encodes word lists for persistence.
String encodeWordLists(List<WordList> lists) => jsonEncode({
      'lists': lists.map((l) => l.toJson()).toList(),
    });

/// Decodes word lists persisted by [encodeWordLists].
List<WordList> decodeWordLists(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ((json['lists'] as List?) ?? const [])
      .map((e) => WordList.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}
