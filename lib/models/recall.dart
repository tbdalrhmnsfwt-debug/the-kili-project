/// Active-recall, flashcard and spaced-repetition models.
///
/// The shipped strings show the vocabulary this screen uses:
///   * `استرجاع نشط` — Active recall
///   * `القراية بتضحك عليك — الاسترجاع بيكشفك`
///   * `{0} كارت · {1} مستنيين مراجعة`
///   * `{0} كارت — {1}٪ صح`
///   * `{0} أسئلة عن «{1}» فيهم الـ٩ أنواع: اسحب الكارت، وصل، رتب، صنف، واكتشف الغلط.`
library;

import 'dart:convert';

/// The nine card kinds the app advertises.
///
/// The Arabic string enumerates them as: «اسحب الكارت، وصل، رتب، صنف،
/// واكتشف الغلط» — swipe the card, match, order, sort and spot the mistake.
enum CardKind {
  /// «اسحب الكارت» — flip/swipe the card.
  swipe,

  /// «وصل» — match two columns.
  match,

  /// «رتب» — put items in the right order.
  order,

  /// «صنف» — sort items into buckets.
  sort,

  /// «اكتشف الغلط» — spot the mistake.
  spotError,

  /// Standard multiple choice.
  multipleChoice,

  /// True / false.
  trueFalse,

  /// Fill in the blank.
  fillBlank,

  /// Free written answer.
  written,
}

extension CardKindX on CardKind {
  /// The Arabic display name used in the UI.
  String get arabicLabel => switch (this) {
    CardKind.swipe => 'اسحب الكارت',
    CardKind.match => 'وصّل',
    CardKind.order => 'رتّب',
    CardKind.sort => 'صنّف',
    CardKind.spotError => 'اكتشف الغلط',
    CardKind.multipleChoice => 'اختيار من متعدد',
    CardKind.trueFalse => 'صح وخطأ',
    CardKind.fillBlank => 'أكمل الفراغ',
    CardKind.written => 'مقالي',
  };
}

/// One face of a card.
class CardFace {
  const CardFace({required this.text, this.hint = ''});

  final String text;

  /// Optional secondary line (an answer, a translation, a note).
  final String hint;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (hint.isNotEmpty) 'hint': hint,
  };

  factory CardFace.fromJson(Map<String, dynamic> json) => CardFace(
    text: json['text'] as String? ?? '',
    hint: json['hint'] as String? ?? '',
  );
}

/// A single recall card.
class RecallCard {
  const RecallCard({
    required this.id,
    required this.kind,
    required this.front,
    required this.lessonId,
    this.back,
    this.options = const [],
    this.correctIndex,
    this.bookId,
    this.lessonNumber,
    this.createdAt,
    this.reviews = 0,
    this.correctReviews = 0,
    this.dueAt,
  });

  final String id;
  final CardKind kind;

  /// The question side.
  final CardFace front;

  /// The answer side, when the kind has one.
  final CardFace? back;

  /// Lesson this card was generated from.
  final String lessonId;
  final String? bookId;
  final int? lessonNumber;

  /// Options for choice-style cards.
  final List<String> options;

  /// Index into [options] of the correct answer.
  final int? correctIndex;

  final DateTime? createdAt;

  /// How many times the card has been reviewed.
  final int reviews;

  /// How many of those reviews were correct.
  final int correctReviews;

  /// When the card becomes eligible for review again.
  final DateTime? dueAt;

  int get remainingReviews => reviews - correctReviews;

  /// Accuracy in the range 0..1.
  double get accuracy => reviews == 0 ? 0 : correctReviews / reviews;

  /// Whether the card is due for review.
  bool isDue([DateTime? now]) {
    final reference = now ?? DateTime.now();
    if (dueAt == null) return true;
    return !dueAt!.isAfter(reference);
  }

  /// Applies a review outcome and schedules the next one.
  ///
  /// The intervals follow a simple expanding ladder (1, 3, 7, 14, 30 days)
  /// keyed off the number of consecutive successes.
  RecallCard reviewed({required bool wasCorrect, DateTime? now}) {
    final reference = now ?? DateTime.now();
    final streak = wasCorrect ? correctReviews + 1 : 0;
    const ladder = [1, 3, 7, 14, 30];
    final days = ladder[streak.clamp(0, ladder.length - 1)];
    return RecallCard(
      id: id,
      kind: kind,
      front: front,
      back: back,
      lessonId: lessonId,
      options: options,
      correctIndex: correctIndex,
      bookId: bookId,
      lessonNumber: lessonNumber,
      createdAt: createdAt,
      reviews: reviews + 1,
      correctReviews: streak,
      dueAt: reference.add(Duration(days: days)),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'front': front.toJson(),
    if (back != null) 'back': back!.toJson(),
    'lessonId': lessonId,
    if (bookId != null) 'bookId': bookId,
    if (lessonNumber != null) 'lesson': lessonNumber,
    if (options.isNotEmpty) 'options': options,
    if (correctIndex != null) 'correctIndex': correctIndex,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    'reviews': reviews,
    'correctReviews': correctReviews,
    if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
  };

  factory RecallCard.fromJson(Map<String, dynamic> json) => RecallCard(
    id: json['id'] as String? ?? '',
    kind: CardKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => CardKind.swipe,
    ),
    front: CardFace.fromJson(
      (json['front'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    back: json['back'] == null
        ? null
        : CardFace.fromJson((json['back'] as Map).cast<String, dynamic>()),
    lessonId: json['lessonId'] as String? ?? '',
    bookId: json['bookId'] as String?,
    lessonNumber: (json['lesson'] as num?)?.toInt(),
    options: (json['options'] as List?)?.cast<String>() ?? const [],
    correctIndex: (json['correctIndex'] as num?)?.toInt(),
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
    reviews: (json['reviews'] as num?)?.toInt() ?? 0,
    correctReviews: (json['correctReviews'] as num?)?.toInt() ?? 0,
    dueAt: json['dueAt'] == null
        ? null
        : DateTime.tryParse(json['dueAt'] as String),
  );
}

/// The queue of cards waiting for review.
class ReviewQueue {
  ReviewQueue({List<RecallCard>? cards}) : cards = cards ?? <RecallCard>[];

  final List<RecallCard> cards;

  int get total => cards.length;

  /// Cards whose [RecallCard.dueAt] has arrived.
  int dueCount([DateTime? now]) => cards.where((c) => c.isDue(now)).length;

  /// Average accuracy over reviewed cards.
  double get accuracy {
    final reviewed = cards.where((c) => c.reviews > 0).toList();
    if (reviewed.isEmpty) return 0;
    final total = reviewed.fold<int>(0, (s, c) => s + c.correctReviews);
    final attempts = reviewed.fold<int>(0, (s, c) => s + c.reviews);
    return attempts == 0 ? 0 : total / attempts;
  }

  /// The cards ready to be shown, oldest due first.
  List<RecallCard> due([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final list = cards.where((c) => c.isDue(reference)).toList()
      ..sort((a, b) {
        final ad = a.dueAt, bd = b.dueAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    return list;
  }
}

/// Encodes a queue for persistence.
String encodeReviewQueue(ReviewQueue queue) =>
    jsonEncode({'cards': queue.cards.map((c) => c.toJson()).toList()});

/// Decodes a queue persisted by [encodeReviewQueue].
ReviewQueue decodeReviewQueue(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ReviewQueue(
    cards: ((json['cards'] as List?) ?? const [])
        .map((e) => RecallCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
