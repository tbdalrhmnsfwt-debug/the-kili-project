/// Optional links to the official editions of a textbook.
///
/// `assets/data/official_books.json` ships empty until the official links are
/// collected. The model is deliberately independent of the bundled lesson
/// payloads: a catalog entry only points at an external source.
library;

/// One official book link.
class OfficialBook {
  const OfficialBook({
    required this.id,
    required this.grade,
    required this.subject,
    required this.title,
    required this.url,
    this.source = '',
  });

  final String id;
  final String grade;
  final String subject;
  final String title;
  final String url;

  /// Where the link comes from, e.g. `official` or a publisher name.
  final String source;

  factory OfficialBook.fromJson(Map<String, dynamic> json) => OfficialBook(
    id: json['id'] as String? ?? '',
    grade: json['grade'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    source: json['source'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'grade': grade,
    'subject': subject,
    'title': title,
    'url': url,
    'source': source,
  };

  /// Whether this entry belongs on the [gradeId] / [subject] screen.
  bool matches(String gradeId, String subject) =>
      grade == gradeId && this.subject == subject;
}

/// The whole official-book catalog.
class OfficialBookCatalog {
  const OfficialBookCatalog({
    this.version = 1,
    this.updated = '',
    this.books = const <OfficialBook>[],
  });

  final int version;
  final String updated;
  final List<OfficialBook> books;

  bool get isEmpty => books.isEmpty;

  factory OfficialBookCatalog.fromJson(Map<String, dynamic> json) {
    final raw = (json['books'] as List?) ?? const [];
    return OfficialBookCatalog(
      version: (json['version'] as num?)?.toInt() ?? 1,
      updated: json['updated'] as String? ?? '',
      books: raw
          .whereType<Map<String, dynamic>>()
          .map(OfficialBook.fromJson)
          .toList(growable: false),
    );
  }

  /// The official entries for one grade's subject.
  List<OfficialBook> forGradeSubject(String gradeId, String subject) {
    return books
        .where((book) => book.matches(gradeId, subject))
        .toList(growable: false);
  }
}
