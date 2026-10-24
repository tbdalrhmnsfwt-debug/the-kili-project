/// Runs the Flutter-free half of the official-library verification on a plain
/// Dart VM.
///
/// `flutter test` needs the Flutter SDK; this script is the fallback that can
/// run anywhere `dart` runs. It exercises the same URL policy, storage layout,
/// catalog invariants, sectioning, spaced-repetition and planner rules as the
/// tests in `test/`.
///
///     dart tool/verify_official_logic.dart
library;

import 'dart:convert';
import 'dart:io';

import '../lib/core/answer_grading.dart';
import '../lib/core/book_sectioning.dart';
import '../lib/core/book_storage.dart';
import '../lib/core/key_value_store.dart';
import '../lib/core/official_library_store.dart';
import '../lib/core/official_study_plan.dart';
import '../lib/core/vocabulary.dart';
import '../lib/models/exam.dart';
import '../lib/models/extraction.dart';
import '../lib/models/focus.dart';
import '../lib/models/official_book.dart';
import '../lib/models/recall.dart';

var _checks = 0;
final _failures = <String>[];

void check(bool condition, String description) {
  _checks++;
  if (!condition) _failures.add(description);
}

void checkEqual(Object? actual, Object? expected, String description) {
  check(
    actual == expected,
    '$description (expected: $expected, actual: $actual)',
  );
}

void checkThrows(void Function() body, BookFailureKind kind, String what) {
  _checks++;
  try {
    body();
    _failures.add('$what: expected ${kind.name}, nothing was thrown');
  } on BookOperationException catch (error) {
    if (error.kind != kind) {
      _failures.add('$what: expected ${kind.name}, got ${error.kind.name}');
    }
  } catch (error) {
    _failures.add('$what: expected ${kind.name}, got $error');
  }
}

OfficialBook book({
  String id = 'book-1',
  EducationSystem system = EducationSystem.generalSecondary,
  BaccalaureatePathway track = BaccalaureatePathway.none,
  String grade = 'sec1',
  String language = 'ar',
  BookTerm term = BookTerm.first,
  String subjectId = 'math',
  OfficialBookStatus status = OfficialBookStatus.available,
  String downloadUrl =
      'https://elearnningcontent.blob.core.windows.net/books/book-1.pdf',
}) => OfficialBook(
  id: id,
  grade: grade,
  subject: 'الرياضيات',
  subjectId: subjectId,
  titleAr: 'الرياضيات',
  system: system,
  track: track,
  term: term,
  language: language,
  downloadUrl: downloadUrl,
  status: status,
  officialSourceUrl: 'https://ellibrary.moe.gov.eg/Books-sec/',
  sourcePage: 'https://ellibrary.moe.gov.eg/Books-sec/',
);

ExtractedSection section(int number) => ExtractedSection(
  id: 's$number',
  title: 'الدرس $number',
  startPage: number * 2,
  endPage: number * 2 + 1,
  text: 'نص $number',
);

ExtractedPage page(int number, String text, {bool ocr = false}) =>
    ExtractedPage(pageNumber: number, text: text, fromOcr: ocr);

RecallCard card({int reviews = 0, int correct = 0}) => RecallCard(
  id: 'c1',
  kind: CardKind.multipleChoice,
  front: const CardFace(text: '٢ + ٣'),
  back: const CardFace(text: '٥'),
  lessonId: 'l1',
  reviews: reviews,
  correctReviews: correct,
  sourcePage: 12,
  sourceSectionId: 's1',
  sourceBookTitle: 'الرياضيات',
);

void verifyUrlPolicy() {
  const policy = OfficialBookUrlPolicy();
  policy.requireDownloadUrl(
    'https://elearnningcontent.blob.core.windows.net/x.pdf',
  );
  policy.requireDownloadUrl(
    'https://egyptianbaccalaureate.blob.core.windows.net/x.pdf',
  );
  checkThrows(
    () => policy.requireDownloadUrl(
      'http://elearnningcontent.blob.core.windows.net/x.pdf',
    ),
    BookFailureKind.invalidUrl,
    'http URL',
  );
  for (final url in [
    'https://example.com/x.pdf',
    'https://moe.gov.eg.evil.example/x.pdf',
    'https://evil.example/elearnningcontent.blob.core.windows.net/x.pdf',
  ]) {
    checkThrows(
      () => policy.requireDownloadUrl(url),
      BookFailureKind.blockedHost,
      'foreign host $url',
    );
  }
  checkThrows(
    () => policy.requireDownloadUrl(
      'https://user:pass@elearnningcontent.blob.core.windows.net/x.pdf',
    ),
    BookFailureKind.invalidUrl,
    'credentials in URL',
  );
  checkThrows(
    () => policy.requireFinalUrl(Uri.parse('https://evil.example/x.pdf')),
    BookFailureKind.blockedHost,
    'redirect off the allowlist',
  );
}

void verifyStorage() {
  final root = Directory.systemTemp.createTempSync('thakir-verify-');
  try {
    final layout = BookStorageLayout(root);
    final bac = book(
      system: EducationSystem.egyptianBaccalaureate,
      track: BaccalaureatePathway.medicineLifeSciences,
      grade: 'sec2',
      language: 'en',
      subjectId: 'biology',
    );
    checkEqual(
      layout.relativeBookDirectory(bac).split(Platform.pathSeparator).join('/'),
      '2026-2027/egyptian_baccalaureate/sec2/medicine_life_sciences/'
      'biology/en/term1/book-1',
      'official storage hierarchy',
    );
    check(
      layout.relativeBookDirectory(book()).contains('no-stream'),
      'general secondary has no stream segment',
    );
    checkEqual(
      layout.finalFile(book()).path,
      layout.finalFile(book()).path,
      'the same row maps to one shared file',
    );
    final paths = {
      layout.finalFile(book()).path,
      layout.finalFile(book(grade: 'sec2')).path,
      layout.finalFile(book(language: 'fr')).path,
      layout.finalFile(book(term: BookTerm.second)).path,
      layout.finalFile(book(subjectId: 'physics')).path,
    };
    checkEqual(paths.length, 5, 'different metadata never collides');
    checkEqual(
      BookStorageLayout.safeSegment('الرياضيات'),
      BookStorageLayout.safeSegment('الرياضيات'),
      'Arabic fallback segment is deterministic',
    );
    check(
      BookStorageLayout.safeSegment('الرياضيات') !=
          BookStorageLayout.safeSegment('الفيزياء'),
      'different Arabic names get different fallbacks',
    );
    check(
      layout.extractionFile(book(), 'a' * 64).path !=
          layout.extractionFile(book(), 'b' * 64).path,
      'extraction files are versioned by SHA',
    );
  } finally {
    root.deleteSync(recursive: true);
  }
}

void verifySectioning() {
  checkEqual(findHeading('الوحدة الأولى\nمقدمة'), 'الوحدة الأولى', 'unit heading');
  checkEqual(findHeading('الدرس 3: المتجهات'), 'الدرس 3: المتجهات', 'lesson heading');
  checkEqual(findHeading('نص عادي بدون عنوان'), null, 'ordinary text has no heading');

  final pages = [
    page(1, 'غلاف'),
    page(2, 'الدرس 1\nمقدمة'),
    page(3, 'شرح'),
    page(4, 'الدرس 2\nتمارين'),
    page(5, 'حل', ocr: true),
  ];
  final sections = buildSections(pages, []);
  checkEqual(sections.length, 2, 'two printed lessons');
  checkEqual(sections.first.title, 'الدرس 1', 'first title');
  checkEqual(sections.first.startPage, 2, 'first start page');
  checkEqual(sections.first.endPage, 3, 'first end page');
  checkEqual(sections.last.title, 'الدرس 2', 'second title');
  check(sections.last.fromOcr, 'section keeps its OCR flag');

  final fallbackPages = [
    for (var i = 1; i <= 20; i++) page(i, 'نص $i'),
  ];
  final fallback = buildSections(fallbackPages, []);
  checkEqual(fallback.length, 3, 'fallback chunks of eight pages');
  check(fallback.every((s) => s.isFallback), 'fallback is labelled');
  checkEqual(fallback.first.title, 'الصفحات 1–8', 'fallback title');
  checkEqual(fallback.last.title, 'الصفحات 17–20', 'last fallback title');

  final emptyWarnings = <String>[];
  check(
    buildSections([page(1, ' ')], emptyWarnings).isEmpty,
    'pages with no text produce no sections',
  );
  check(
    emptyWarnings.any((w) => w.contains('مفيش صفحات')),
    'empty book explains why there are no sections',
  );

  final extracted = ExtractedBook(
    bookId: 'b',
    sha256: 's',
    extractedAt: DateTime(2026),
    pages: [page(1, 'إِنَّ الْحَمْدَ لِلَّهِ'), page(2, 'المتجهات')],
    sections: const [],
    textPageCount: 2,
    ocrPageCount: 0,
    warnings: const [],
    status: BookExtractionStatus.ready,
  );
  checkEqual(extracted.search('الحمد').single.pageNumber, 1, 'diacritic search');
  checkEqual(extracted.search('المتجهات').single.pageNumber, 2, 'plain search');
  check(extracted.search('   ').isEmpty, 'blank search has no hits');
}

void verifyRecall() {
  final now = DateTime(2026, 10, 24, 18);
  checkEqual(
    card().graded(ReviewGrade.knew, now: now).dueAt,
    DateTime(2026, 10, 25, 18),
    'first success returns tomorrow',
  );
  checkEqual(
    card(reviews: 1, correct: 1).graded(ReviewGrade.knew, now: now).dueAt,
    DateTime(2026, 10, 27, 18),
    'second success returns after three days',
  );
  checkEqual(
    card(reviews: 4, correct: 4).graded(ReviewGrade.knew, now: now).dueAt,
    DateTime(2026, 11, 23, 18),
    'fifth success returns after thirty days',
  );
  checkEqual(
    card(reviews: 2, correct: 2).graded(ReviewGrade.difficult, now: now).dueAt,
    DateTime(2026, 10, 25, 18),
    'difficult returns tomorrow',
  );
  final again = card(reviews: 5, correct: 5)
      .graded(ReviewGrade.again, now: now);
  checkEqual(again.dueAt, DateTime(2026, 10, 24, 18, 10), 'again returns soon');
  checkEqual(again.correctReviews, 0, 'again resets the streak');
  checkEqual(again.sourcePage, 12, 'grading keeps page provenance');
  checkEqual(
    RecallCard.fromJson(again.toJson()).correctReviews,
    0,
    'graded state survives JSON',
  );
  final due = ReviewQueue(
    cards: [
      RecallCard(
        id: 'a',
        kind: CardKind.swipe,
        front: const CardFace(text: 'a'),
        lessonId: 'l',
        dueAt: DateTime(2026, 10, 23),
      ),
      RecallCard(
        id: 'b',
        kind: CardKind.swipe,
        front: const CardFace(text: 'b'),
        lessonId: 'l',
        dueAt: DateTime(2026, 10, 25),
      ),
    ],
  ).due(now);
  checkEqual(due.length, 1, 'only due cards are shown');
  checkEqual(due.single.id, 'a', 'oldest due card first');
}

void verifyPlanner() {
  final request = OfficialStudyPlanRequest(
    book: book(id: 'math-sec1'),
    sections: [section(1), section(2)],
    startDate: DateTime(2026, 10, 24),
    targetDate: DateTime(2026, 11, 24),
    dailyMinutes: 60,
  );
  final plan = OfficialStudyPlanBuilder.build(request);
  checkEqual(plan.sections, 2, 'plan sees two lessons');
  checkEqual(plan.studyDays, 1, 'two lessons fit one day');
  checkEqual(plan.tasks.length, 8, 'four tasks per lesson');
  checkEqual(
    plan.tasks.first.id,
    'official:math-sec1:s1:study',
    'deterministic task id',
  );
  checkEqual(
    plan.tasks.first.dueAt,
    DateTime(2026, 10, 24, 21),
    'study due that evening',
  );
  checkEqual(
    plan.tasks.first.sourcePage,
    2,
    'plan task links to the lesson page',
  );
  final byId = {for (final task in plan.tasks) task.id: task};
  checkEqual(
    byId['official:math-sec1:s1:review1']!.dueAt,
    DateTime(2026, 10, 25, 19, 30),
    'review one day later',
  );
  checkEqual(
    byId['official:math-sec1:s1:review3']!.dueAt,
    DateTime(2026, 10, 27, 19, 30),
    'review three days later',
  );
  checkEqual(
    byId['official:math-sec1:s1:quiz']!.dueAt,
    DateTime(2026, 10, 31, 19),
    'quiz a week later',
  );
  final rebuilt = OfficialStudyPlanBuilder.build(request);
  checkEqual(
    rebuilt.tasks.map((t) => t.id).join(','),
    plan.tasks.map((t) => t.id).join(','),
    'rebuilding produces the same plan',
  );

  final five = OfficialStudyPlanBuilder.build(
    OfficialStudyPlanRequest(
      book: book(id: 'math-sec1'),
      sections: [for (var i = 1; i <= 5; i++) section(i)],
      startDate: DateTime(2026, 10, 24),
      targetDate: DateTime(2026, 10, 26),
      dailyMinutes: 30,
      includeReviews: false,
      includeQuiz: false,
    ),
  );
  checkEqual(five.studyDays, 3, 'five lessons over three days');
  checkEqual(
    (five.tasks.map((t) => t.dueAt!.day).toSet().toList()..sort()).join(','),
    '24,25,26',
    'plan uses every available day',
  );

  final empty = OfficialStudyPlanBuilder.build(
    OfficialStudyPlanRequest(
      book: book(),
      sections: const [],
      startDate: DateTime(2026, 10, 24),
      targetDate: DateTime(2026, 11, 24),
    ),
  );
  check(empty.tasks.isEmpty, 'no lessons means no tasks');

  final merged = OfficialStudyPlanBuilder.merge(
    [
      StudyTask(
        id: 'official:math-sec1:s1:study',
        title: 'قديم',
        dueAt: DateTime(2026, 10, 20),
      ),
      StudyTask(
        id: 'official:math-sec1:s1:review1',
        title: 'خلص',
        done: true,
      ),
    ],
    plan.tasks,
  );
  check(merged.any((t) => t.title == 'خلص' && t.done), 'completed work kept');
  check(
    merged.firstWhere((t) => t.id == 'official:math-sec1:s1:study').title !=
        'قديم',
    'open work refreshed',
  );
  checkEqual(merged.length, plan.tasks.length, 'merge does not duplicate');

  final now = DateTime(2026, 10, 24, 12);
  final moved = OfficialStudyPlanBuilder.rescheduleOverdue(
    [
      StudyTask(
        id: 'late',
        title: 'متأخر',
        dueAt: DateTime(2026, 10, 23, 21),
        startAt: DateTime(2026, 10, 23, 16),
      ),
      StudyTask(
        id: 'done',
        title: 'خلص',
        done: true,
        dueAt: DateTime(2026, 10, 20, 21),
      ),
    ],
    now: now,
  );
  final movedById = {for (final task in moved) task.id: task};
  checkEqual(
    movedById['late']!.dueAt,
    DateTime(2026, 10, 25, 21),
    'overdue task moves forward',
  );
  checkEqual(
    movedById['late']!.startAt,
    DateTime(2026, 10, 25, 16),
    'its start time moves with it',
  );
  checkEqual(
    movedById['done']!.dueAt,
    DateTime(2026, 10, 20, 21),
    'completed tasks are not moved',
  );
}

void verifyCatalog() {
  final file = File('assets/data/official_books.json');
  check(file.existsSync(), 'catalog file exists');
  if (!file.existsSync()) return;
  final catalog = OfficialBookCatalog.fromJson(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
  checkEqual(catalog.schoolYear, '2026-2027', 'catalog school year');
  check(catalog.version >= 2, 'catalog version is current');
  check(catalog.books.length >= 338, 'catalog has all rows');
  check(catalog.sources.isNotEmpty, 'catalog names its sources');

  final ids = <String>{};
  const policy = OfficialBookUrlPolicy();
  var published = 0;
  var bac = 0;
  for (final row in catalog.books) {
    ids.add(row.id);
    check(row.titleAr.isNotEmpty, '${row.id} has an Arabic title');
    check(row.subject.isNotEmpty, '${row.id} has a subject');
    check(
      row.schoolYear == '2026-2027',
      '${row.id} carries the right school year',
    );
    check(
      kOfficialSourceHosts.contains(Uri.parse(row.sourcePage).host),
      '${row.id} source page is an official host',
    );
    if (row.system == EducationSystem.egyptianBaccalaureate) bac++;
    if (row.system == EducationSystem.generalSecondary) {
      check(row.track == BaccalaureatePathway.none, '${row.id} has no stream');
    }
    if (row.status == OfficialBookStatus.available) {
      published++;
      policy.requireDownloadUrl(row.downloadUrl);
    } else {
      check(!row.hasDownload, '${row.id} is not offered for download');
      if (row.status == OfficialBookStatus.notPublished) {
        check(row.downloadUrl.isEmpty, '${row.id} has no invented URL');
      }
    }
  }
  checkEqual(ids.length, catalog.books.length, 'catalog ids are unique');
  check(published > 300, 'most rows are published');
  check(bac > 0, 'Baccalaureate is represented separately');

  final general = catalog.forSystem(EducationSystem.generalSecondary);
  final baccalaureate = catalog.forSystem(
    EducationSystem.egyptianBaccalaureate,
  );
  check(general.isNotEmpty, 'General Secondary filter works');
  check(baccalaureate.isNotEmpty, 'Baccalaureate filter works');
  check(
    general.every((b) => b.system == EducationSystem.generalSecondary),
    'General Secondary filter never returns Baccalaureate rows',
  );
  check(
    baccalaureate.every((b) => b.system == EducationSystem.egyptianBaccalaureate),
    'Baccalaureate filter never returns General Secondary rows',
  );
  final medicine = catalog.forSystem(
    EducationSystem.egyptianBaccalaureate,
    grade: 'sec2',
    pathway: BaccalaureatePathway.medicineLifeSciences,
  );
  check(medicine.isNotEmpty, 'Medicine pathway has books');
  check(
    medicine.every(
      (b) =>
          b.track == BaccalaureatePathway.medicineLifeSciences ||
          b.track == BaccalaureatePathway.none,
    ),
    'pathway filter includes shared core subjects only',
  );

  final unpublished = OfficialBook.fromJson({
    'id': 'future',
    'grade': 'sec3',
    'subject': 'جديد',
    'title_ar': 'جديد',
  });
  checkEqual(
    unpublished.status,
    OfficialBookStatus.notPublished,
    'a row without a URL is not published',
  );
  check(!unpublished.hasDownload, 'unpublished rows cannot download');
  checkEqual(
    unpublished.initialState().downloadStatus,
    BookDownloadStatus.notPublished,
    'local state reflects publication',
  );
}

void verifyAnswerGrading() {
  ExamQuestion question(String model) => ExamQuestion(
    id: 'q1',
    prompt: 'اشرح المتجه',
    answerKind: AnswerKind.freeText,
    modelAnswer: model,
  );
  final model = 'المتجه كمية لها مقدار واتجاه';
  check(
    gradeShortAnswer('المتجه كمية لها مقدار واتجاه', question(model)),
    'exact model answer passes',
  );
  check(
    gradeShortAnswer(
      'المتجه له مقدار واتجاه ويستخدم في الفيزياء',
      question(model),
    ),
    'paraphrase with keyword overlap passes',
  );
  check(
    !gradeShortAnswer('الماء يغلي عند مئة درجة', question(model)),
    'unrelated answer fails',
  );
  check(!gradeShortAnswer('   ', question('')), 'empty answer fails');
  check(
    !gradeShortAnswer('قصير', question('')),
    'empty model requires a substantive answer',
  );
  check(
    gradeShortAnswer(
      'الكمية لها مقدار واتجاه',
      question('الْكَمِّيَّة لَهَا مِقْدَار وَاتِّجَاه'),
    ),
    'diacritics are ignored',
  );
  check(
    !gradeShortAnswer(
      'المتجه',
      question('المتجه كمية رياضية لها مقدار واتجاه ويمثل بسهم'),
    ),
    'one-word fragment of a long answer is not correct',
  );

  ExamQuestion choice(int? index, {List<String> options = const ['أ', 'ب']}) =>
      ExamQuestion(
        id: 'q2',
        prompt: 'اختر',
        answerKind: AnswerKind.multipleChoice,
        options: options,
        correctIndex: index,
      );
  check(hasValidChoiceAnswer(choice(0)), 'valid choice index passes');
  check(!hasValidChoiceAnswer(choice(null)), 'missing choice index fails');
  check(!hasValidChoiceAnswer(choice(3)), 'out-of-range choice index fails');
  check(isChoiceAnswerCorrect(choice(1), 1), 'correct option is graded right');
  check(!isChoiceAnswerCorrect(choice(1), 0), 'wrong option is graded wrong');
  check(
    !isChoiceAnswerCorrect(choice(9), 0),
    'malformed index never marks an option correct',
  );
}

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

Future<void> verifyLibraryStore() async {
  final memory = _MemoryStore();
  final store = OfficialLibraryStore(memory);

  var load = store.load();
  check(load.state.isEmpty, 'an empty store loads empty');
  check(!load.corrupt, 'an empty store is not corrupt');
  check(!load.recoveredFromBackup, 'an empty store has no backup recovery');

  const row = BookLocalState(
    bookId: 'g10-math',
    downloadStatus: BookDownloadStatus.downloaded,
    extractionStatus: BookExtractionStatus.ready,
    filePath: '/books/g10-math.pdf',
    fileSize: 1024,
    sha256: 'abc123',
    extractedPath: '/books/g10-math.json',
    pageCount: 120,
    sectionCount: 8,
  );
  await store.save(
    const OfficialLibraryState(
      books: {'g10-math': row},
      queue: [],
      catalogVersion: 2,
    ),
  );
  load = store.load();
  check(!load.corrupt, 'a saved state loads without corruption');
  checkEqual(load.state.books.length, 1, 'a saved row round-trips');
  checkEqual(
    load.state.books['g10-math']?.filePath,
    '/books/g10-math.pdf',
    'the file path round-trips',
  );
  checkEqual(
    load.state.books['g10-math']?.sha256,
    'abc123',
    'the SHA-256 round-trips',
  );
  checkEqual(load.state.catalogVersion, 2, 'the catalog version round-trips');

  // Saving again moves the previous primary to the backup.
  await store.save(
    const OfficialLibraryState(
      books: {
        'g10-math': BookLocalState(
          bookId: 'g10-math',
          downloadStatus: BookDownloadStatus.needsUpdate,
          filePath: '/books/g10-math.pdf',
        ),
      },
      queue: ['g10-math'],
    ),
  );
  check(
    memory.values[kOfficialLibraryBackupKey] != null,
    'a second save writes a backup',
  );
  checkEqual(
    store.load().state.queue.join(','),
    'g10-math',
    'the queue round-trips',
  );

  // Corrupt the primary: the backup must be used instead.
  memory.values[kOfficialLibraryKey] = '{not json';
  load = store.load();
  check(load.recoveredFromBackup, 'a corrupt primary falls back to the backup');
  check(load.corrupt == false, 'backup recovery is not reported as corruption');
  checkEqual(
    load.state.books['g10-math']?.downloadStatus,
    BookDownloadStatus.downloaded,
    'the backup keeps the last good download state',
  );
  check(
    memory.values[kOfficialLibraryCorruptKey] == '{not json',
    'the corrupt payload is retained for diagnostics',
  );

  // Corrupt everything: never throw, never lose the downloaded file path.
  final broken = _MemoryStore();
  broken.values[kOfficialLibraryKey] = '[[[';
  broken.values[kOfficialLibraryBackupKey] = 'oops';
  final brokenLoad = OfficialLibraryStore(broken).load();
  check(brokenLoad.corrupt, 'two corrupt payloads report corruption');
  check(brokenLoad.state.isEmpty, 'corruption yields an empty safe state');
  check(
    broken.values[kOfficialLibraryCorruptKey] == '[[[',
    'the latest corrupt payload is kept when there is no backup',
  );

  // Unversioned payload: a list of rows and a `pending` queue.
  final legacy = _MemoryStore();
  legacy.values[kOfficialLibraryKey] = jsonEncode({
    'pending': ['b1'],
    'books': [
      {
        'book_id': 'b1',
        'download_status': 'downloaded',
        'file_path': '/b1.pdf',
      },
    ],
  });
  final legacyLoad = OfficialLibraryStore(legacy).load();
  checkEqual(legacyLoad.migratedFrom, 0, 'an unversioned payload is migrated');
  checkEqual(
    legacyLoad.state.schemaVersion,
    kOfficialLibrarySchemaVersion,
    'migration stamps the current schema',
  );
  checkEqual(
    legacyLoad.state.queue.join(','),
    'b1',
    'the legacy pending queue is read',
  );
  checkEqual(legacyLoad.state.books.length, 1, 'legacy list rows are read');

  // A crash during download/extraction returns the row to a resumable state.
  final crashed = _MemoryStore();
  crashed.values[kOfficialLibraryKey] = jsonEncode({
    'schema_version': kOfficialLibrarySchemaVersion,
    'queue': <String>[],
    'books': {
      'down': {
        'book_id': 'down',
        'download_status': 'downloading',
        'extraction_status': 'extracting',
      },
    },
  });
  final recovered = OfficialLibraryStore(crashed).load().state;
  checkEqual(
    recovered.books['down']?.downloadStatus,
    BookDownloadStatus.queued,
    'an interrupted download is queued again',
  );
  checkEqual(
    recovered.books['down']?.extractionStatus,
    BookExtractionStatus.notStarted,
    'an interrupted extraction can restart',
  );
  check(
    recovered.queue.contains('down'),
    'the interrupted download is back in the queue',
  );

  // Export omits device paths; import merges without deleting local files.
  final exported = store.export();
  checkEqual(
    exported['kind'],
    'thakir_official_library',
    'exports carry a recognisable kind',
  );
  final exportedBooks = exported['books'] as Map<String, dynamic>;
  check(
    (exportedBooks['g10-math'] as Map<String, dynamic>)['file_path'] == '',
    'exports omit local file paths',
  );

  final target = _MemoryStore();
  final targetStore = OfficialLibraryStore(target);
  await targetStore.save(
    const OfficialLibraryState(
      books: {
        'g10-math': BookLocalState(
          bookId: 'g10-math',
          downloadStatus: BookDownloadStatus.downloaded,
          filePath: '/local.pdf',
          sha256: 'different',
        ),
      },
    ),
  );
  final conflict = await targetStore.importJson(
    jsonEncode({
      'kind': 'thakir_official_library',
      'books': {
        'g10-math': {
          'book_id': 'g10-math',
          'download_status': 'downloaded',
          'file_path': '/other.pdf',
          'sha256': 'other-hash',
        },
      },
    }),
  );
  checkEqual(
    conflict.conflicts,
    1,
    'a different downloaded hash is reported as a conflict',
  );
  checkEqual(
    targetStore.load().state.books['g10-math']?.filePath,
    '/local.pdf',
    'import never replaces a local verified file',
  );

  final badJson = await targetStore.importJson('not json');
  check(!badJson.ok, 'invalid JSON is rejected');
  final wrongKind = await targetStore.importJson('{"kind":"other","books":{}}');
  check(!wrongKind.ok, 'an unknown export kind is rejected');
  final malformed = await targetStore.importJson(
    '{"kind":"thakir_official_library","books":[]}',
  );
  check(!malformed.ok, 'an export without a book map is rejected');

  final fresh = _MemoryStore();
  final freshStore = OfficialLibraryStore(fresh);
  final imported = await freshStore.importJson(jsonEncode(exported));
  check(imported.ok, 'a valid export imports cleanly');
  checkEqual(imported.imported, 1, 'the exported row is imported');
  checkEqual(
    freshStore.load().state.books['g10-math']?.filePath,
    '',
    'an imported row does not invent a local file path',
  );
}

void verifyVocabulary() {
  const translations = {
    'vector': 'متجه',
    'magnitude': 'مقدار',
    'direction': 'اتجاه',
    'mass': 'كتلة',
  };
  final pages = [
    const VocabularyPage(
      pageNumber: 4,
      text: 'A vector has magnitude and direction. The vector is drawn '
          'as an arrow. Mass is not a vector.',
    ),
    const VocabularyPage(
      pageNumber: 9,
      text: 'Direction matters, and the vector stays the same.',
    ),
  ];

  final items = extractVocabulary(pages: pages, translations: translations);
  check(items.isNotEmpty, 'vocabulary finds dictionary words');
  check(
    items.every((item) => translations.containsKey(item.term)),
    'every term comes from the dictionary',
  );
  check(
    items.every((item) => item.translation.trim().isNotEmpty),
    'every item has a real translation',
  );
  checkEqual(items.first.term, 'vector', 'most frequent word ranks first');
  checkEqual(items.first.occurrences, 4, 'occurrences are counted');
  checkEqual(items.first.page, 4, 'first page is recorded');
  check(
    items.first.context.toLowerCase().contains('vector'),
    'context contains the word',
  );
  final vector = items.firstWhere((item) => item.term == 'vector');
  check(vector.page == 4, 'repeated word keeps its first page');
  check(
    !items.any((item) => item.term == 'and'),
    'stop words are skipped',
  );
  check(
    !items.any((item) => item.term == 'arrow'),
    'words the dictionary lacks are skipped',
  );
  check(
    extractVocabulary(pages: const [], translations: translations).isEmpty,
    'no pages yields no vocabulary',
  );
  check(
    extractVocabulary(pages: pages, translations: const {}).isEmpty,
    'no dictionary yields no vocabulary',
  );
  check(
    extractVocabulary(pages: pages, translations: translations, limit: 0).isEmpty,
    'a zero limit yields no vocabulary',
  );
  checkEqual(
    extractVocabulary(pages: pages, translations: translations, limit: 2).length,
    2,
    'the limit is respected',
  );

  final upper = extractVocabulary(
    pages: const [
      VocabularyPage(pageNumber: 1, text: 'VECTOR Vector vector.'),
    ],
    translations: translations,
  );
  checkEqual(upper.single.term, 'vector', 'matching is case-insensitive');
  checkEqual(upper.single.occurrences, 3, 'case variants are counted together');

  final apostrophe = extractVocabulary(
    pages: const [
      VocabularyPage(pageNumber: 2, text: "Newton's law explains motion."),
    ],
    translations: const {"newton's": 'نيوتن', 'motion': 'حركة'},
  );
  check(
    apostrophe.any((item) => item.term == "newton's"),
    'apostrophes stay part of the word',
  );

  final arabic = extractVocabulary(
    pages: const [
      VocabularyPage(pageNumber: 3, text: 'المتجه كمية لها مقدار واتجاه.'),
    ],
    translations: translations,
  );
  check(arabic.isEmpty, 'Arabic-only text produces no Latin vocabulary');
}

Future<void> main() async {
  verifyUrlPolicy();
  verifyStorage();
  verifySectioning();
  verifyRecall();
  verifyPlanner();
  verifyAnswerGrading();
  verifyVocabulary();
  await verifyLibraryStore();
  verifyCatalog();

  if (_failures.isEmpty) {
    stdout.writeln('OK — $_checks checks passed.');
    return;
  }
  stderr.writeln('${_failures.length} of $_checks checks failed:');
  for (final failure in _failures) {
    stderr.writeln('  - $failure');
  }
  exitCode = 1;
}
