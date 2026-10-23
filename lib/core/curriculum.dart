/// The secondary-school curriculum map («قسم المواد الدراسية»).
///
/// The bundled library stores textbooks by their official subject name, while
/// the UI groups them into the subjects students actually pick: a grade-10
/// student sees Physics/Chemistry/Biology (all covered by «العلوم المتكاملة»),
/// a grade-11 student first picks a branch, and a grade-12 student picks a
/// track. The definitions here are the single source of truth for that
/// mapping; [curriculumBooks] turns them into the actual [Book]s.
library;

import 'package:flutter/material.dart';

import '../models/manhaji.dart';

/// A selectable branch or track within a secondary grade.
class CurriculumTrack {
  const CurriculumTrack({
    required this.id,
    required this.label,
    required this.description,
    this.markers = const <String>[],
    this.excludeBaccalaureate = false,
  });

  final String id;
  final String label;
  final String description;

  /// Variant fragments that identify this track's books, e.g.
  /// `الطب وعلوم الحياة`.
  final List<String> markers;

  /// When true, any book with a «البكالوريا» variant is hidden.
  final bool excludeBaccalaureate;

  /// Whether [book] belongs to this track.
  bool accepts(Book book) {
    final variant = book.variant;
    if (!variant.contains('البكالوريا')) return true;
    if (excludeBaccalaureate) return false;
    // «البكالوريا — الجزء الأول» (no track in parentheses) is shared by all
    // Baccalaureate tracks.
    if (!variant.contains('(')) return true;
    if (markers.isEmpty) return true;
    return markers.any(variant.contains);
  }
}

/// A subject as shown in the curriculum UI.
class CurriculumSubject {
  const CurriculumSubject({
    required this.id,
    required this.title,
    required this.assetSubjects,
    required this.icon,
    required this.color,
    this.subtitle = '',
    this.tracks = const <String>[],
    this.note,
  });

  /// Stable id used in routes (`math`, `physics`, …).
  final String id;

  /// The Arabic display name.
  final String title;

  /// Official names in the bundled library (`index.json`).
  final List<String> assetSubjects;

  final IconData icon;
  final Color color;
  final String subtitle;

  /// Track ids this subject belongs to; empty means every track.
  final List<String> tracks;

  /// A short explanation shown above the book list.
  final String? note;

  bool appearsIn(String? trackId) =>
      trackId == null || tracks.isEmpty || tracks.contains(trackId);
}

/// A secondary grade with its tracks and subjects.
class CurriculumGrade {
  const CurriculumGrade({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.tracks,
    required this.subjects,
  });

  final String id;
  final String label;
  final String subtitle;
  final List<CurriculumTrack> tracks;
  final List<CurriculumSubject> subjects;

  /// The track shown initially, or null when the grade has no branches.
  CurriculumTrack? get defaultTrack =>
      tracks.isEmpty ? null : tracks.first;
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

const _arabic = CurriculumSubject(
  id: 'arabic',
  title: 'اللغة العربية',
  assetSubjects: ['اللغة العربية'],
  icon: Icons.menu_book_rounded,
  color: _teal,
  subtitle: 'نصوص، نحو، قصة وقراءة',
);

const _english = CurriculumSubject(
  id: 'english',
  title: 'اللغة الإنجليزية',
  assetSubjects: ['اللغة الإنجليزية'],
  icon: Icons.translate_rounded,
  color: _blue,
  subtitle: 'Reading, Grammar & Writing',
);

const _french = CurriculumSubject(
  id: 'french',
  title: 'اللغة الفرنسية',
  assetSubjects: ['اللغة الفرنسية'],
  icon: Icons.language_rounded,
  color: _indigo,
  subtitle: 'Français — livre, histoire et exercices',
);

const _german = CurriculumSubject(
  id: 'german',
  title: 'اللغة الألمانية',
  assetSubjects: ['اللغة الألمانية'],
  icon: Icons.language_rounded,
  color: _amber,
  subtitle: 'Deutsch',
);

const _spanish = CurriculumSubject(
  id: 'spanish',
  title: 'اللغة الإسبانية',
  assetSubjects: ['اللغة الإسبانية'],
  icon: Icons.language_rounded,
  color: _rose,
  subtitle: 'Español',
);

const _italian = CurriculumSubject(
  id: 'italian',
  title: 'اللغة الإيطالية',
  assetSubjects: ['اللغة الإيطالية'],
  icon: Icons.language_rounded,
  color: _emerald,
  subtitle: 'Italiano',
);

const _chinese = CurriculumSubject(
  id: 'chinese',
  title: 'اللغة الصينية',
  assetSubjects: ['اللغة الصينية'],
  icon: Icons.language_rounded,
  color: _rose,
  subtitle: '中文',
);

const _religion = CurriculumSubject(
  id: 'religion',
  title: 'التربية الدينية',
  assetSubjects: ['التربية الدينية الإسلامية'],
  icon: Icons.mosque_rounded,
  color: _green,
  subtitle: 'التربية الدينية الإسلامية',
);

const _history = CurriculumSubject(
  id: 'history',
  title: 'التاريخ',
  assetSubjects: ['التاريخ'],
  icon: Icons.history_edu_rounded,
  color: _brown,
  subtitle: 'حضارات و أحداث',
);

const _geography = CurriculumSubject(
  id: 'geography',
  title: 'الجغرافيا',
  assetSubjects: ['الجغرافيا'],
  icon: Icons.public_rounded,
  color: _cyan,
  subtitle: 'خرائط ومناخ وسكان',
);

const _philosophy = CurriculumSubject(
  id: 'philosophy',
  title: 'الفلسفة والمنطق',
  assetSubjects: ['الفلسفة والمنطق'],
  icon: Icons.psychology_alt_rounded,
  color: _indigo,
  subtitle: 'تفكير ومنطق',
);

const _it = CurriculumSubject(
  id: 'it',
  title: 'تكنولوجيا المعلومات',
  assetSubjects: ['تكنولوجيا المعلومات'],
  icon: Icons.computer_rounded,
  color: _slate,
  subtitle: 'ICT — عربي و English',
);

const _national = CurriculumSubject(
  id: 'national',
  title: 'التربية الوطنية',
  assetSubjects: ['التربية الوطنية'],
  icon: Icons.flag_rounded,
  color: _green,
  subtitle: 'المواطنة والانتماء',
);

const _math = CurriculumSubject(
  id: 'math',
  title: 'الرياضيات',
  assetSubjects: [
    'الرياضيات',
    'الرياضيات البحتة',
    'الرياضيات التطبيقية',
  ],
  icon: Icons.functions_rounded,
  color: _teal,
  subtitle: 'جبر، هندسة وتفاضل',
);

// ---------------------------------------------------------------- grade 10

/// Physics/Chemistry/Biology are taught together as «العلوم المتكاملة» in
/// the first secondary year, so all three cards read the same bundled book.
const _integratedScience = ['العلوم المتكاملة'];

const _grade10Subjects = <CurriculumSubject>[
  _arabic,
  _english,
  _french,
  _german,
  CurriculumSubject(
    id: 'math',
    title: 'الرياضيات',
    assetSubjects: ['الرياضيات'],
    icon: Icons.functions_rounded,
    color: _teal,
    subtitle: 'جبر وحساب مثلثات',
  ),
  CurriculumSubject(
    id: 'physics',
    title: 'الفيزياء',
    assetSubjects: _integratedScience,
    icon: Icons.bolt_rounded,
    color: _orange,
    subtitle: 'العلوم المتكاملة',
    note: 'في أولى ثانوي بتدرس الفيزياء والكيمياء والأحياء مع بعض في كتاب '
        '«العلوم المتكاملة». الكتب الفيزيائية المنفصلة تحت بتغطي الجزء '
        'الخاص بالفيزياء.',
  ),
  CurriculumSubject(
    id: 'chemistry',
    title: 'الكيمياء',
    assetSubjects: _integratedScience,
    icon: Icons.science_rounded,
    color: _violet,
    subtitle: 'العلوم المتكاملة',
    note: 'جزء الكيمياء موجود جوه كتاب «العلوم المتكاملة».',
  ),
  CurriculumSubject(
    id: 'biology',
    title: 'الأحياء',
    assetSubjects: _integratedScience,
    icon: Icons.biotech_rounded,
    color: _green,
    subtitle: 'العلوم المتكاملة',
    note: 'جزء الأحياء موجود جوه كتاب «العلوم المتكاملة».',
  ),
  _history,
  _geography,
  _philosophy,
  _religion,
  _it,
  _spanish,
  _italian,
];

// ---------------------------------------------------------------- grade 11

const _bacMedical = 'bac-med';
const _bacEngineering = 'bac-eng';
const _bacBusiness = 'bac-biz';
const _bacArts = 'bac-arts';
const _science = 'science';
const _literary = 'literary';

const _grade11Tracks = <CurriculumTrack>[
  CurriculumTrack(
    id: _science,
    label: 'الشعبة العلمية',
    description: 'رياضيات وفيزياء وكيمياء وعلوم',
    excludeBaccalaureate: true,
  ),
  CurriculumTrack(
    id: _literary,
    label: 'الشعبة الأدبية',
    description: 'تاريخ وجغرافيا وعلم نفس',
    excludeBaccalaureate: true,
  ),
  CurriculumTrack(
    id: _bacMedical,
    label: 'بكالوريا — الطب وعلوم الحياة',
    description: 'Math, Physics & Chemistry',
    markers: ['الطب وعلوم الحياة'],
  ),
  CurriculumTrack(
    id: _bacEngineering,
    label: 'بكالوريا — الهندسة وعلوم الحاسب',
    description: 'Math, Physics, Chemistry & AI',
    markers: ['الهندسة وعلوم الحاسب'],
  ),
  CurriculumTrack(
    id: _bacBusiness,
    label: 'بكالوريا — الأعمال',
    description: 'Business & Accounting',
    markers: ['الأعمال'],
  ),
  CurriculumTrack(
    id: _bacArts,
    label: 'بكالوريا — الآداب والفنون',
    description: 'Arts, languages & psychology',
    markers: ['الآداب والفنون'],
  ),
];

// The shared Baccalaureate subjects are visible in every Baccalaureate track.
const _bacTracks = <String>[
  _bacMedical,
  _bacEngineering,
  _bacBusiness,
  _bacArts,
];

const _grade11Subjects = <CurriculumSubject>[
  _arabic,
  _english,
  _french,
  _german,
  _math,
  CurriculumSubject(
    id: 'physics',
    title: 'الفيزياء',
    assetSubjects: ['الفيزياء'],
    icon: Icons.bolt_rounded,
    color: _orange,
    subtitle: 'قوانين وحركة وطاقة',
    tracks: [_science, _bacMedical, _bacEngineering],
  ),
  CurriculumSubject(
    id: 'chemistry',
    title: 'الكيمياء',
    assetSubjects: ['الكيمياء'],
    icon: Icons.science_rounded,
    color: _violet,
    subtitle: 'تفاعلات وعناصر',
    tracks: [_science, _bacMedical, _bacEngineering],
  ),
  CurriculumSubject(
    id: 'biology',
    title: 'الأحياء',
    assetSubjects: ['الأحياء'],
    icon: Icons.biotech_rounded,
    color: _green,
    subtitle: 'خلية وجينات وأجهزة',
    tracks: [_science, _bacMedical],
  ),
  _it,
  CurriculumSubject(
    id: 'history',
    title: 'التاريخ',
    assetSubjects: ['التاريخ'],
    icon: Icons.history_edu_rounded,
    color: _brown,
    subtitle: 'حضارات وأحداث',
    tracks: [_literary, ..._bacTracks],
  ),
  CurriculumSubject(
    id: 'geography',
    title: 'الجغرافيا',
    assetSubjects: ['الجغرافيا'],
    icon: Icons.public_rounded,
    color: _cyan,
    subtitle: 'خرائط ومناخ وسكان',
    tracks: [_literary],
  ),
  CurriculumSubject(
    id: 'psychology',
    title: 'علم النفس والاجتماع',
    assetSubjects: ['علم النفس والاجتماع', 'علم النفس'],
    icon: Icons.psychology_rounded,
    color: _violet,
    subtitle: 'سلوك المجتمع والفرد',
    tracks: [_literary, _bacArts],
  ),
  CurriculumSubject(
    id: 'programming',
    title: 'البرمجة والذكاء الاصطناعي',
    assetSubjects: ['البرمجة والذكاء الاصطناعي'],
    icon: Icons.smart_toy_rounded,
    color: _violet,
    subtitle: 'Programming & AI',
    tracks: [_bacEngineering],
  ),
  CurriculumSubject(
    id: 'business',
    title: 'إدارة الأعمال',
    assetSubjects: ['إدارة الأعمال'],
    icon: Icons.business_center_rounded,
    color: _amber,
    subtitle: 'Business Management',
    tracks: [_bacBusiness],
  ),
  CurriculumSubject(
    id: 'accounting',
    title: 'المحاسبة',
    assetSubjects: ['المحاسبة'],
    icon: Icons.account_balance_rounded,
    color: _emerald,
    subtitle: 'Accounting',
    tracks: [_bacBusiness],
  ),
  CurriculumSubject(
    id: 'citizenship',
    title: 'المواطنة وحقوق الإنسان',
    assetSubjects: ['المواطنة وحقوق الإنسان'],
    icon: Icons.gavel_rounded,
    color: _teal,
    subtitle: 'حقوق وواجبات',
    tracks: [_science, _literary],
  ),
  _religion,
  _spanish,
  _italian,
  _chinese,
];

// ---------------------------------------------------------------- grade 12

const _sciMath = 'sci-math';
const _sciScience = 'sci-science';

const _grade12Tracks = <CurriculumTrack>[
  CurriculumTrack(
    id: _sciMath,
    label: 'علمي رياضة',
    description: 'رياضيات بحتة وتطبيقية وفيزياء',
  ),
  CurriculumTrack(
    id: _sciScience,
    label: 'علمي علوم',
    description: 'أحياء وكيمياء وفيزياء',
  ),
  CurriculumTrack(
    id: _literary,
    label: 'أدبي',
    description: 'تاريخ وجغرافيا وعلم نفس',
  ),
];

const _grade12Subjects = <CurriculumSubject>[
  _arabic,
  _english,
  _french,
  _german,
  CurriculumSubject(
    id: 'pure-math',
    title: 'الرياضيات البحتة',
    assetSubjects: ['الرياضيات البحتة'],
    icon: Icons.functions_rounded,
    color: _teal,
    subtitle: 'Pure Mathematics',
    tracks: [_sciMath, _sciScience],
  ),
  CurriculumSubject(
    id: 'applied-math',
    title: 'الرياضيات التطبيقية',
    assetSubjects: ['الرياضيات التطبيقية'],
    icon: Icons.calculate_rounded,
    color: _cyan,
    subtitle: 'Applied Mathematics',
    tracks: [_sciMath],
  ),
  CurriculumSubject(
    id: 'statistics',
    title: 'الإحصاء',
    assetSubjects: ['الإحصاء'],
    icon: Icons.bar_chart_rounded,
    color: _cyan,
    subtitle: 'Statistics',
    tracks: [_sciMath, _literary],
  ),
  CurriculumSubject(
    id: 'physics',
    title: 'الفيزياء',
    assetSubjects: ['الفيزياء'],
    icon: Icons.bolt_rounded,
    color: _orange,
    subtitle: 'قوانين وحركة وطاقة',
    tracks: [_sciMath, _sciScience],
  ),
  CurriculumSubject(
    id: 'chemistry',
    title: 'الكيمياء',
    assetSubjects: ['الكيمياء'],
    icon: Icons.science_rounded,
    color: _violet,
    subtitle: 'تفاعلات وعناصر',
    tracks: [_sciMath, _sciScience],
  ),
  CurriculumSubject(
    id: 'biology',
    title: 'الأحياء',
    assetSubjects: ['الأحياء'],
    icon: Icons.biotech_rounded,
    color: _green,
    subtitle: 'خلية وجينات وأجهزة',
    tracks: [_sciScience],
  ),
  CurriculumSubject(
    id: 'history',
    title: 'التاريخ',
    assetSubjects: ['التاريخ'],
    icon: Icons.history_edu_rounded,
    color: _brown,
    subtitle: 'حضارات وأحداث',
    tracks: [_literary],
  ),
  CurriculumSubject(
    id: 'geography',
    title: 'الجغرافيا',
    assetSubjects: ['الجغرافيا'],
    icon: Icons.public_rounded,
    color: _cyan,
    subtitle: 'خرائط ومناخ وسكان',
    tracks: [_literary],
  ),
  CurriculumSubject(
    id: 'psychology',
    title: 'علم النفس والاجتماع',
    assetSubjects: ['علم النفس والاجتماع', 'علم النفس'],
    icon: Icons.psychology_rounded,
    color: _violet,
    subtitle: 'سلوك المجتمع والفرد',
    tracks: [_literary],
  ),
  _religion,
  _national,
  _it,
  _spanish,
  _italian,
];

/// The three secondary grades, keyed by their library ids.
const Map<String, CurriculumGrade> curriculumGrades = {
  'sec1': CurriculumGrade(
    id: 'sec1',
    label: 'الصف الأول الثانوي',
    subtitle: 'أساسيات المرحلة الثانوية',
    tracks: <CurriculumTrack>[],
    subjects: _grade10Subjects,
  ),
  'sec2': CurriculumGrade(
    id: 'sec2',
    label: 'الصف الثاني الثانوي',
    subtitle: 'اختر شعبتك أو مسار البكالوريا',
    tracks: _grade11Tracks,
    subjects: _grade11Subjects,
  ),
  'sec3': CurriculumGrade(
    id: 'sec3',
    label: 'الصف الثالث الثانوي',
    subtitle: 'اختر مسارك الدراسي',
    tracks: _grade12Tracks,
    subjects: _grade12Subjects,
  ),
};

/// Returns the curriculum for [gradeId], or null for non-secondary grades.
CurriculumGrade? curriculumForGrade(String? gradeId) =>
    gradeId == null ? null : curriculumGrades[gradeId];

/// Resolves a subject id within a grade.
CurriculumSubject? curriculumSubject(String? gradeId, String? subjectId) {
  final curriculum = curriculumForGrade(gradeId);
  if (curriculum == null || subjectId == null) return null;
  for (final subject in curriculum.subjects) {
    if (subject.id == subjectId) return subject;
  }
  return null;
}

/// Resolves a track id within a grade.
CurriculumTrack? curriculumTrack(String? gradeId, String? trackId) {
  final curriculum = curriculumForGrade(gradeId);
  if (curriculum == null || trackId == null) return null;
  for (final track in curriculum.tracks) {
    if (track.id == trackId) return track;
  }
  return null;
}

/// The subjects shown for [trackId].
List<CurriculumSubject> curriculumSubjects({
  required String gradeId,
  String? trackId,
}) {
  final curriculum = curriculumForGrade(gradeId);
  if (curriculum == null) return const <CurriculumSubject>[];
  return curriculum.subjects
      .where((subject) => subject.appearsIn(trackId))
      .toList(growable: false);
}

/// The actual library books for [subject], within [track] when given.
List<Book> curriculumBooks({
  required Grade grade,
  required CurriculumSubject subject,
  CurriculumTrack? track,
}) {
  return grade.books.where((book) {
    if (!subject.assetSubjects.contains(book.subject)) return false;
    if (track != null && !track.accepts(book)) return false;
    return true;
  }).toList(growable: false);
}

/// The fraction of the grade's lessons belonging to [subject] that the
/// student has marked as read.
double subjectProgress({
  required CurriculumGrade curriculum,
  required CurriculumSubject subject,
  required Grade grade,
  required Set<String> readLessons,
  CurriculumTrack? track,
}) {
  final books = curriculumBooks(grade: grade, subject: subject, track: track);
  var total = 0;
  var read = 0;
  for (final book in books) {
    for (var lesson = 1; lesson <= book.lessons; lesson++) {
      total++;
      if (readLessons.contains('${grade.id}/${book.id}/$lesson')) read++;
    }
  }
  if (total == 0) return 0;
  return read / total;
}

/// The number of lessons in [subject].
int subjectLessonCount({
  required CurriculumSubject subject,
  required Grade grade,
  CurriculumTrack? track,
}) {
  return curriculumBooks(grade: grade, subject: subject, track: track)
      .fold(0, (sum, book) => sum + book.lessons);
}
