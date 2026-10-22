/// Data models for the "manhaji" study content tree.
///
/// The original app ships 216 books across 12 Egyptian grade levels
/// (prep1..prep3, prim1..prim6, sec1..sec3) under
/// `assets/manhaji/<grade>/index.json`.
///
/// The index schema recovered from the APK:
/// ```json
/// {
///   "grade": "prep1",
///   "label": "أولى إعدادي",
///   "books": [
///     {
///       "id": "mn_prep1_09c2036cbc",
///       "subject": "اللغة العربية",
///       "variant": "",
///       "lang": "ar",
///       "title": "اللغة العربية",
///       "pages": 136,
///       "lessons": 14,
///       "grade": "prep1",
///       "file": "mn_prep1_09c2036cbc.json.gz",
///       "fp": "65f0d3c2283083ee"
///     }
///   ]
/// }
/// ```
///
/// Each book's packed payload starts with the magic `ZKB1\x00`, followed by
/// a 16-char content fingerprint and an opaque key block. The decoded
/// content behind it is JSON shaped like:
/// ```json
/// {
///   "fp": "<the same 16-char fingerprint>",
///   "l": {
///     "<lesson number as string>": [
///       { "f": "<figure file>", "nr": "<narrative text>",
///         "p": <page>, "lb": ["<label1>", "<label2>"] }
///     ]
///   }
/// }
/// ```
/// `f` is the asset file name under `assets/manhaji/<grade>/figs/`;
/// `nr` is the inline narrative; `p` is the 1-based page; `lb` is an
/// optional list of anachdit labels shown next to the narrative.
library;

/// A single grade level (e.g. "أولى ثانوي").
class Grade {
  const Grade({required this.id, required this.label, required this.books});

  /// Machine id, e.g. `sec2`.
  final String id;

  /// Arabic display label, e.g. `تانية ثانوي`.
  final String label;

  final List<Book> books;

  factory Grade.fromJson(Map<String, dynamic> json) {
    final rawBooks = (json['books'] as List?) ?? const [];
    return Grade(
      id: json['grade'] as String? ?? '',
      label: json['label'] as String? ?? '',
      books: rawBooks
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'grade': id,
    'label': label,
    'books': books.map((b) => b.toJson()).toList(),
  };
}

/// A textbook within a grade.
class Book {
  const Book({
    required this.id,
    required this.subject,
    required this.variant,
    required this.lang,
    required this.title,
    required this.pages,
    required this.lessons,
    required this.grade,
    required this.file,
    required this.fingerprint,
    this.content,
  });

  final String id;

  /// Subject name in Arabic, e.g. `الرياضيات`.
  final String subject;

  /// Optional variant qualifier (some books ship several editions).
  final String variant;

  /// BCP-47-ish language tag of the book body, e.g. `ar`.
  final String lang;

  final String title;
  final int pages;

  /// Number of lessons contained in the book.
  final int lessons;

  final String grade;

  /// File name (relative to the grade folder) of the packed payload.
  final String file;

  /// Content fingerprint used for cache validation.
  final String fingerprint;

  /// Decoded payload, once loaded.
  final BookContent? content;

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    variant: json['variant'] as String? ?? '',
    lang: json['lang'] as String? ?? 'ar',
    title: json['title'] as String? ?? '',
    pages: (json['pages'] as num?)?.toInt() ?? 0,
    lessons: (json['lessons'] as num?)?.toInt() ?? 0,
    grade: json['grade'] as String? ?? '',
    file: json['file'] as String? ?? '',
    fingerprint: json['fp'] as String? ?? '',
    content: json['content'] == null
        ? null
        : BookContent.fromJson(json['content'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'variant': variant,
    'lang': lang,
    'title': title,
    'pages': pages,
    'lessons': lessons,
    'grade': grade,
    'file': file,
    'fp': fingerprint,
    if (content != null) 'content': content!.toJson(),
  };

  /// Stable cache key for the packed payload.
  String get cacheKey => 'manhaji/$grade/$file';

  @override
  String toString() => 'Book($id, $title)';
}

/// The decoded content of a single book.
class BookContent {
  const BookContent({required this.fingerprint, required this.figures});

  final String fingerprint;

  /// Maps the stringified lesson number to the figures it contains.
  final Map<String, List<Figure>> figures;

  factory BookContent.fromJson(Map<String, dynamic> json) {
    final raw = (json['l'] as Map<String, dynamic>?) ?? const {};
    final parsed = <String, List<Figure>>{};
    for (final entry in raw.entries) {
      final items = (entry.value as List?) ?? const [];
      parsed[entry.key.toString()] = items
          .map((e) => Figure.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }
    return BookContent(
      fingerprint: json['fp'] as String? ?? '',
      figures: parsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'fp': fingerprint,
    'l': figures.map((k, v) => MapEntry(k, v.map((f) => f.toJson()).toList())),
  };

  /// The lessons of this book, ordered by their number.
  List<Lesson> get lessons {
    final keys =
        figures.keys.map((k) => int.tryParse(k)).whereType<int>().toList()
          ..sort();
    return keys
        .map((n) => Lesson(number: n, figures: figures['$n'] ?? const []))
        .toList(growable: false);
  }
}

/// A lesson inside a book.
class Lesson {
  const Lesson({
    required this.number,
    this.title = '',
    this.figures = const [],
  });

  /// 1-based lesson number.
  final int number;

  /// Optional lesson title (not always present in the shipped payloads).
  final String title;

  /// The ordered figures of this lesson.
  final List<Figure> figures;

  /// The narrative text of every figure, joined for reading or searching.
  String get narrative =>
      figures.map((f) => f.narrative).where((t) => t.isNotEmpty).join('\n');

  bool get isEmpty => figures.isEmpty;

  @override
  String toString() => 'Lesson($number, ${figures.length} figures)';
}

/// A single figure embedded in a lesson.
class Figure {
  const Figure({
    required this.assetPath,
    required this.narrative,
    this.page,
    this.labels = const [],
  });

  /// Asset file name under `assets/manhaji/<grade>/figs/`, e.g.
  /// `mn_prim1_2f1ac2d801_p007_1.webp`.
  final String assetPath;

  /// Inline narrative text shown beneath the figure.
  final String narrative;

  /// 1-based page number of this figure within the book.
  final int? page;

  /// Optional anachdit labels accompanying the figure.
  final List<String> labels;

  factory Figure.fromJson(Map<String, dynamic> json) {
    return Figure(
      assetPath: json['f'] as String? ?? '',
      narrative: json['nr'] as String? ?? '',
      page: (json['p'] as num?)?.toInt(),
      labels: ((json['lb'] as List?) ?? const []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (assetPath.isNotEmpty) 'f': assetPath,
    if (narrative.isNotEmpty) 'nr': narrative,
    if (page != null) 'p': page,
    if (labels.isNotEmpty) 'lb': labels,
  };

  @override
  String toString() => 'Figure($assetPath, p$page)';
}
