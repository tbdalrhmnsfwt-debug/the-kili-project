/// Maps the verified official catalog onto the study library's subject tree.
///
/// The bundled «المكتبة الدراسية» names subjects in their short Arabic form
/// (`الرياضيات`), while the Ministry catalog prefixes language and component
/// qualifiers (`الرياضيات باللغة الإنجليزية`, `الرياضيات-القصة`). This file
/// owns the one canonical key used to join them, so the grade and subject
/// cards count real catalog rows instead of guessing.
///
/// Deliberately Flutter-free: the mapping can be verified on a plain Dart VM
/// with `tool/verify_official_logic.dart`.
library;

import '../models/official_book.dart';

/// The canonical key that joins a bundled subject to official catalog rows.
///
/// It normalises Arabic diacritics and alef variants, repairs the catalog's
/// common `بالغة` typo, drops language/component qualifiers, and folds a few
/// established label variants onto the name the app already ships.
String officialSubjectKey(String subject) {
  // Strip qualifiers before folding alef variants: `normalizeSubject` looks
  // for `لغة أجنبية` with its original hamza, so folding first would leave a
  // second-language suffix in the key and split the subject in two.
  final key = normalizeSubject(subject.replaceAll('بالغة', 'باللغة'))
      .replaceAll(RegExp('[أإآ]'), 'ا');
  return _subjectAliases[key] ?? key;
}

/// A subject group taken from the official catalog.
class OfficialSubjectGroup {
  const OfficialSubjectGroup({
    required this.key,
    required this.displayName,
    required this.rows,
  });

  /// The canonical key shared with the bundled subject.
  final String key;

  /// The Arabic name to show when the group has no bundled counterpart.
  final String displayName;

  /// Every catalog row in the group, including unpublished ones.
  final List<OfficialBook> rows;

  /// Published, downloadable books, stories, workbooks and activities.
  int get books => rows
      .where(
        (book) =>
            book.hasDownload &&
            book.resourceKind != OfficialResourceKind.assessment,
      )
      .length;

  /// Published, downloadable assessment papers.
  int get assessments => rows
      .where(
        (book) =>
            book.hasDownload &&
            book.resourceKind == OfficialResourceKind.assessment,
      )
      .length;

  /// Everything the student can open right now.
  int get sources => books + assessments;

  /// Rows the Ministry has not published yet or that need manual review.
  int get unavailable => rows.where((book) => !book.hasDownload).length;
}

/// The official counts for one grade.
class OfficialGradeCounts {
  const OfficialGradeCounts({
    this.books = 0,
    this.assessments = 0,
    this.subjects = 0,
  });

  final int books;
  final int assessments;
  final int subjects;

  int get sources => books + assessments;

  bool get isEmpty => sources == 0;
}

/// Groups every published official row for [gradeId] by canonical subject.
///
/// Both the General Secondary and Egyptian Baccalaureate rows are included:
/// a grade card is not system-specific, and each subject screen labels the
/// system on every row. Notice rows carry no PDF and are ignored.
///
/// Groups with nothing available to open are omitted so an official-only
/// subject card never leads to an empty list.
List<OfficialSubjectGroup> officialSubjectGroups(
  OfficialBookCatalog? catalog,
  String gradeId,
) {
  if (catalog == null) return const <OfficialSubjectGroup>[];

  final grouped = <String, List<OfficialBook>>{};
  for (final book in catalog.books) {
    if (book.grade != gradeId || book.isNotice) continue;
    final key = officialSubjectKey(book.subject);
    if (key.isEmpty) continue;
    grouped.putIfAbsent(key, () => <OfficialBook>[]).add(book);
  }

  final groups = <OfficialSubjectGroup>[];
  for (final entry in grouped.entries) {
    final rows = entry.value;
    final published = rows.any((book) => book.hasDownload);
    if (!published) continue;
    groups.add(
      OfficialSubjectGroup(
        key: entry.key,
        displayName: _displayName(entry.key, rows),
        rows: List<OfficialBook>.unmodifiable(rows),
      ),
    );
  }
  groups.sort((a, b) => a.displayName.compareTo(b.displayName));
  return groups;
}

/// Official counts for a grade, for its summary card.
OfficialGradeCounts officialCountsForGrade(
  OfficialBookCatalog? catalog,
  String gradeId,
) {
  var books = 0;
  var assessments = 0;
  final groups = officialSubjectGroups(catalog, gradeId);
  for (final group in groups) {
    books += group.books;
    assessments += group.assessments;
  }
  return OfficialGradeCounts(
    books: books,
    assessments: assessments,
    subjects: groups.length,
  );
}

/// Every official row that belongs to [subject] in [gradeId].
///
/// Works for a bundled subject name (`الرياضيات`) and for an official-only
/// display name. The list is ordered the way the subject screen should show
/// it: downloadable books first, then assessments, then unpublished rows.
List<OfficialBook> officialRowsForSubject(
  OfficialBookCatalog? catalog,
  String gradeId,
  String subject,
) {
  if (catalog == null) return const <OfficialBook>[];
  final key = officialSubjectKey(subject);
  if (key.isEmpty) return const <OfficialBook>[];

  final rows = catalog.books
      .where(
        (book) =>
            book.grade == gradeId &&
            !book.isNotice &&
            officialSubjectKey(book.subject) == key,
      )
      .toList(growable: false);
  final sorted = List<OfficialBook>.from(rows);
  sorted.sort((a, b) {
    if (a.hasDownload != b.hasDownload) return a.hasDownload ? -1 : 1;
    final kind = _kindRank(a.resourceKind).compareTo(_kindRank(b.resourceKind));
    if (kind != 0) return kind;
    final system = a.system.index.compareTo(b.system.index);
    if (system != 0) return system;
    final term = a.term.index.compareTo(b.term.index);
    if (term != 0) return term;
    return a.titleAr.compareTo(b.titleAr);
  });
  return sorted;
}

/// The catalog label shown for a subject the bundled library does not have.
String _displayName(String key, List<OfficialBook> rows) {
  final counts = <String, int>{};
  for (final row in rows) {
    final label = _displayLabel(row.subject);
    if (label.isEmpty || officialSubjectKey(label) != key) continue;
    counts[label] = (counts[label] ?? 0) + 1;
  }
  if (counts.isEmpty) return key;
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final frequency = b.value.compareTo(a.value);
      return frequency != 0 ? frequency : a.key.compareTo(b.key);
    });
  return entries.first.key;
}

/// The catalog subject with component qualifiers removed, keeping its
/// original spelling for display.
String _displayLabel(String subject) =>
    normalizeSubject(subject.replaceAll('بالغة', 'باللغة'));

int _kindRank(OfficialResourceKind kind) => switch (kind) {
  OfficialResourceKind.studentBook => 0,
  OfficialResourceKind.story => 1,
  OfficialResourceKind.workbook => 2,
  OfficialResourceKind.activity => 3,
  OfficialResourceKind.assessment => 4,
  OfficialResourceKind.notice => 5,
  OfficialResourceKind.reference => 6,
};

/// Label variants that the catalog and the bundled index spell differently.
///
/// Each value is already in the bundled library's spelling. Keys are what
/// [officialSubjectKey] produced after normalisation, not raw catalog labels.
const Map<String, String> _subjectAliases = <String, String>{
  'تطبيقات الرياضيات': 'الرياضيات التطبيقية',
  'جغرافيا التنمية': 'الجغرافيا',
  'الجغرافيا السياسية': 'الجغرافيا',
  'تكنولوجيا المعلومات والاتصالات': 'تكنولوجيا المعلومات',
  'االتاريخ الوطنى': 'التاريخ',
};
