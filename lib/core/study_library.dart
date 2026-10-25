/// Helpers for the «المكتبة الدراسية» hierarchy.
///
/// The library is derived from the same bundled grade indexes the books come
/// from, so the UI never invents a subject or a count. A grade's subjects are
/// the distinct `Book.subject` values in `assets/manhaji/<grade>/index.json`,
/// in their original order.
library;

import 'package:flutter/material.dart';

import '../models/manhaji.dart';
import '../models/official_book.dart';
import 'official_subject_index.dart';

/// Grade labels, in the order the app shows them.
const Map<String, String> kGradeLabels = {
  'prep1': 'أولى إعدادي',
  'prep2': 'تانية إعدادي',
  'prep3': 'تالتة إعدادي',
  'prim1': 'أولى ابتدائي',
  'prim2': 'تانية ابتدائي',
  'prim3': 'تالتة ابتدائي',
  'prim4': 'رابعة ابتدائي',
  'prim5': 'خامسة ابتدائي',
  'prim6': 'سادسة ابتدائي',
  'sec1': 'أولى ثانوي',
  'sec2': 'تانية ثانوي',
  'sec3': 'تالتة ثانوي',
};

/// The three Egyptian education stages, in display order.
enum StudyStage {
  primary('المرحلة الابتدائية'),
  preparatory('المرحلة الإعدادية'),
  secondary('المرحلة الثانوية');

  const StudyStage(this.label);

  /// The Arabic stage name shown above its grade cards.
  final String label;

  /// Resolves a grade id such as `prim3`, `prep2` or `sec1`.
  ///
  /// Returns `null` for an id the library does not recognise, so callers can
  /// ignore unexpected index entries instead of inventing a stage.
  static StudyStage? of(String gradeId) {
    if (gradeId.startsWith('prim')) return StudyStage.primary;
    if (gradeId.startsWith('prep')) return StudyStage.preparatory;
    if (gradeId.startsWith('sec')) return StudyStage.secondary;
    return null;
  }
}

/// A subject aggregated from the books of one grade.
class StudySubjectSummary {
  const StudySubjectSummary({
    required this.name,
    required this.books,
    required this.lessons,
    required this.readLessons,
    required this.icon,
    required this.color,
    this.officialBooks = 0,
    this.officialAssessments = 0,
  });

  /// The official subject name stored on each [Book].
  final String name;

  /// How many bundled books belong to this subject.
  final int books;

  /// How many lessons those bundled books contain.
  final int lessons;

  /// How many of those lessons the student marked as read.
  final int readLessons;

  /// Published official books, stories, workbooks and activities.
  final int officialBooks;

  /// Published official assessment papers.
  final int officialAssessments;

  /// Presentation only: icon and accent used on the subject cards.
  final IconData icon;
  final Color color;

  /// Everything the verified catalog offers for this subject right now.
  int get officialSources => officialBooks + officialAssessments;

  /// Whether the catalog has at least one downloadable official source.
  bool get hasOfficial => officialSources > 0;

  /// True when the subject exists only in the official catalog.
  bool get isOfficialOnly => books == 0 && lessons == 0 && hasOfficial;

  /// Read progress in the range 0..1; zero-safe for empty subjects.
  double get progress => lessons == 0 ? 0 : readLessons / lessons;

  /// [progress] as a rounded percentage.
  int get percent => (progress * 100).round();
}

/// Groups [grade]'s books by their exact subject name.
///
/// The map preserves the order in which subjects first appear in the grade's
/// `index.json`. Progress uses the same `gradeId/bookId/lessonNumber` key as
/// the rest of the app.
///
/// When [officialCatalog] is provided, each subject also receives the real
/// counts from the verified Ministry catalog, and official-only subjects are
/// appended so their books are reachable from the grade screen. Language and
/// component variants (`الرياضيات باللغة الإنجليزية`, `الرياضيات-القصة`) fold
/// onto the bundled subject.
List<StudySubjectSummary> studySubjects(
  Grade grade,
  Set<String> readLessons, {
  OfficialBookCatalog? officialCatalog,
}) {
  final grouped = <String, _SubjectAccumulator>{};
  final order = <String>[];
  for (final book in grade.books) {
    final accumulator = grouped.putIfAbsent(book.subject, () {
      order.add(book.subject);
      return _SubjectAccumulator();
    });
    accumulator.books++;
    accumulator.lessons += book.lessons;
    for (var lesson = 1; lesson <= book.lessons; lesson++) {
      if (readLessons.contains('${grade.id}/${book.id}/$lesson')) {
        accumulator.readLessons++;
      }
    }
  }

  for (final group in officialSubjectGroups(officialCatalog, grade.id)) {
    final bundledName = _bundledNameFor(group.key, grouped.keys);
    final accumulator = bundledName == null
        ? _SubjectAccumulator()
        : grouped[bundledName]!;
    accumulator.officialBooks += group.books;
    accumulator.officialAssessments += group.assessments;
    if (bundledName == null) {
      grouped[group.displayName] = accumulator;
      order.add(group.displayName);
    }
  }

  return [for (final name in order) _summary(name, grouped[name]!)];
}

/// The bundled subject name whose canonical key is [key], if any.
String? _bundledNameFor(String key, Iterable<String> names) {
  for (final name in names) {
    if (officialSubjectKey(name) == key) return name;
  }
  return null;
}

StudySubjectSummary _summary(String name, _SubjectAccumulator accumulator) {
  final visual = studySubjectVisual(name);
  return StudySubjectSummary(
    name: name,
    books: accumulator.books,
    lessons: accumulator.lessons,
    readLessons: accumulator.readLessons,
    icon: visual.icon,
    color: visual.color,
    officialBooks: accumulator.officialBooks,
    officialAssessments: accumulator.officialAssessments,
  );
}

class _SubjectAccumulator {
  int books = 0;
  int lessons = 0;
  int readLessons = 0;
  int officialBooks = 0;
  int officialAssessments = 0;
}

/// The number of lessons across every book in [grade].
int studyLessonCount(Grade grade) =>
    grade.books.fold(0, (sum, book) => sum + book.lessons);

/// The number of [grade]'s lessons marked as read.
int studyReadCount(Grade grade, Set<String> readLessons) {
  var read = 0;
  for (final book in grade.books) {
    for (var lesson = 1; lesson <= book.lessons; lesson++) {
      if (readLessons.contains('${grade.id}/${book.id}/$lesson')) read++;
    }
  }
  return read;
}

/// The fraction of [grade]'s lessons marked as read, or 0 for an empty grade.
double studyProgress(Grade grade, Set<String> readLessons) {
  final total = studyLessonCount(grade);
  if (total == 0) return 0;
  return studyReadCount(grade, readLessons) / total;
}

/// The grades belonging to [stage], preserving the input order.
List<Grade> studyGradesInStage(List<Grade> grades, StudyStage stage) {
  return grades
      .where((grade) => StudyStage.of(grade.id) == stage)
      .toList(growable: false);
}

const _teal = Color(0xFF0F766E);
const _blue = Color(0xFF2563EB);
const _indigo = Color(0xFF4F46E5);
const _violet = Color(0xFF7C3AED);
const _amber = Color(0xFFD97706);
const _orange = Color(0xFFEA580C);
const _green = Color(0xFF15803D);
const _emerald = Color(0xFF059669);
const _cyan = Color(0xFF0891B2);
const _rose = Color(0xFFBE123C);
const _brown = Color(0xFF92400E);
const _slate = Color(0xFF475569);

/// The icon and accent used for a subject card.
///
/// The mapping mirrors the palette in `core/curriculum.dart`; unknown subject
/// names get a neutral book icon so a newly bundled subject still renders.
({IconData icon, Color color}) studySubjectVisual(String name) {
  return switch (name) {
    'اللغة العربية' => (icon: Icons.menu_book_rounded, color: _teal),
    'اللغة الإنجليزية' => (icon: Icons.translate_rounded, color: _blue),
    'اللغة الفرنسية' => (icon: Icons.language_rounded, color: _indigo),
    'اللغة الألمانية' => (icon: Icons.language_rounded, color: _amber),
    'اللغة الإسبانية' => (icon: Icons.language_rounded, color: _rose),
    'اللغة الإيطالية' => (icon: Icons.language_rounded, color: _emerald),
    'اللغة الصينية' => (icon: Icons.language_rounded, color: _rose),
    'الرياضيات' => (icon: Icons.functions_rounded, color: _teal),
    'الرياضيات البحتة' => (icon: Icons.functions_rounded, color: _teal),
    'الرياضيات التطبيقية' => (icon: Icons.calculate_rounded, color: _cyan),
    'الإحصاء' => (icon: Icons.bar_chart_rounded, color: _cyan),
    'العلوم' => (icon: Icons.science_rounded, color: _violet),
    'العلوم المتكاملة' => (icon: Icons.science_rounded, color: _violet),
    'الفيزياء' => (icon: Icons.bolt_rounded, color: _orange),
    'الكيمياء' => (icon: Icons.science_rounded, color: _violet),
    'الأحياء' => (icon: Icons.biotech_rounded, color: _green),
    'التاريخ' => (icon: Icons.history_edu_rounded, color: _brown),
    'الجغرافيا' => (icon: Icons.public_rounded, color: _cyan),
    'الدراسات الاجتماعية' => (icon: Icons.public_rounded, color: _brown),
    'الفلسفة والمنطق' => (icon: Icons.psychology_alt_rounded, color: _indigo),
    'علم النفس' => (icon: Icons.psychology_rounded, color: _violet),
    'علم النفس والاجتماع' => (icon: Icons.psychology_rounded, color: _violet),
    'التربية الدينية الإسلامية' => (icon: Icons.mosque_rounded, color: _green),
    'التربية الوطنية' => (icon: Icons.flag_rounded, color: _green),
    'المواطنة وحقوق الإنسان' => (icon: Icons.gavel_rounded, color: _teal),
    'تكنولوجيا المعلومات' => (icon: Icons.computer_rounded, color: _slate),
    'البرمجة والذكاء الاصطناعي' => (icon: Icons.code_rounded, color: _violet),
    'إدارة الأعمال' => (icon: Icons.business_center_rounded, color: _amber),
    'المحاسبة' => (icon: Icons.account_balance_rounded, color: _emerald),
    'المكتبة ومهارات البحث' => (
      icon: Icons.local_library_rounded,
      color: _blue,
    ),
    'التربية الإعلامية' => (icon: Icons.podcasts_rounded, color: _rose),
    'التربية المسرحية' => (icon: Icons.theater_comedy_rounded, color: _amber),
    'المجالات الزراعية' => (icon: Icons.agriculture_rounded, color: _green),
    'المجالات الصناعية' => (icon: Icons.factory_rounded, color: _slate),
    _ => (icon: Icons.auto_stories_rounded, color: _teal),
  };
}
