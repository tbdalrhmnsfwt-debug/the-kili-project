# «المكتبة الدراسية» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the second tab to «المكتبة الدراسية» and add a grade → subject → book hierarchy over the bundled `assets/manhaji` library, without breaking any legacy route.

**Architecture:** A new hub screen replaces the tab body and the `/courses` route. Two new pushed routes (`/library/:gradeId`, `/library/:gradeId/:subject`) drill into a grade's subjects and a subject's books. Subjects and counts are derived from each grade's own `index.json`; the existing `BookLessonsScreen` and reader remain the terminal step. An empty official-book catalog is loaded and rendered as a pending state, never as fabricated links.

**Tech Stack:** Flutter, Riverpod, go_router, Dart 3.5, the bundled `assets/manhaji` indexes.

**Spec:** `docs/superpowers/specs/2026-10-24-study-library-design.md`

## Global Constraints

- No deployment, no push, no commit unless the user explicitly asks.
- Do not change deployment configs or the bundled `assets/manhaji` payloads.
- Keep every existing route working: `/courses`, `/grade/:gradeId`, `/lesson/:gradeId/:bookId`, `/subjects`, `/subjects/:gradeId/:subjectId`.
- Do not invent subjects, official book links or PDF metadata. The official catalog ships with `"books": []`.
- Arabic RTL UI; reuse `ZakerColors`, `ZakerSpacing`, `ZakerRadius`, `TrText`, `SectionHeader`, `StatChip`, `ProgressBar`, `EmptyState`, `LoadingBox`.
- Local analysis command: `work/dartsdk/dart-sdk/bin/dart analyze lib test`. The vendored Flutter tool cannot run on this device; do not claim `flutter test` passed locally.

## Review Focus

1. A grade whose `index.json` is missing or invalid must surface the provider's `EmptyState`, never crash inside the hierarchy.
2. Arabic subject names containing spaces or a slash must survive the route (`Uri.encodeComponent` on build, go_router decoding on read).
3. An empty official catalog must render the pending card, never a fake link or a blank section.
4. A book with `lessons == 0` must yield progress `0` and never divide by zero.
5. The longer tab label must not overflow the floating bottom bar; allow two lines.

---

### Task 1: Study-library data helpers

**Files:**
- Create: `lib/core/study_library.dart`
- Modify: `lib/features/courses/course_list_screen.dart` (remove the local `kGradeLabels` map; import it from `core/study_library.dart`)
- Test: `test/study_library_test.dart`

**Interfaces:**
- Consumes: `Grade`, `Book` from `lib/models/manhaji.dart`.
- Produces:
  - `const Map<String, String> kGradeLabels`
  - `enum StudyStage { primary, preparatory, secondary }` with `final String label` and `static StudyStage? of(String gradeId)`
  - `class StudySubjectSummary { final String name; final int books; final int lessons; final int readLessons; final IconData icon; final Color color; double get progress; int get percent; }`
  - `List<StudySubjectSummary> studySubjects(Grade grade, Set<String> readLessons)`
  - `int studyLessonCount(Grade grade)`
  - `int studyReadCount(Grade grade, Set<String> readLessons)`
  - `double studyProgress(Grade grade, Set<String> readLessons)`
  - `List<Grade> studyGradesInStage(List<Grade> grades, StudyStage stage)`
  - `({IconData icon, Color color}) studySubjectVisual(String name)`

- [ ] **Step 1: Write the failing tests**

Create `test/study_library_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/study_library.dart';
import '../lib/models/manhaji.dart';

Book _book({
  required String id,
  required String subject,
  int lessons = 1,
}) => Book(
  id: id,
  subject: subject,
  variant: '',
  lang: 'ar',
  title: subject,
  pages: 10,
  lessons: lessons,
  grade: 'prep1',
  file: '$id.json.gz',
  fingerprint: 'fp',
);

void main() {
  test('groups books by subject, preserving index order', () {
    final grade = Grade(
      id: 'prep1',
      label: 'أولى إعدادي',
      books: [
        _book(id: 'a', subject: 'الرياضيات', lessons: 2),
        _book(id: 'b', subject: 'اللغة العربية', lessons: 3),
        _book(id: 'c', subject: 'الرياضيات', lessons: 1),
      ],
    );

    final subjects = studySubjects(grade, {'prep1/a/1', 'prep1/c/1'});

    expect(subjects.map((s) => s.name), ['الرياضيات', 'اللغة العربية']);
    expect(subjects[0].books, 2);
    expect(subjects[0].lessons, 3);
    expect(subjects[0].readLessons, 2);
    expect(subjects[0].progress, closeTo(2 / 3, 1e-9));
    expect(subjects[1].readLessons, 0);
  });

  test('empty grades are zero-safe', () {
    const grade = Grade(id: 'prep1', label: 'أولى إعدادي', books: []);

    expect(studySubjects(grade, {}), isEmpty);
    expect(studyLessonCount(grade), 0);
    expect(studyReadCount(grade, {}), 0);
    expect(studyProgress(grade, {}), 0);
  });

  test('maps grade ids to stages and rejects unknown ids', () {
    expect(StudyStage.of('prim1'), StudyStage.primary);
    expect(StudyStage.of('prep2'), StudyStage.preparatory);
    expect(StudyStage.of('sec3'), StudyStage.secondary);
    expect(StudyStage.of('nursery'), isNull);
  });

  test('round-trips Arabic subject names through a route segment', () {
    const subject = 'اللغة العربية / 1';
    expect(Uri.decodeComponent(Uri.encodeComponent(subject)), subject);
  });

  test('falls back to a generic visual for unknown subjects', () {
    expect(studySubjectVisual('مادة جديدة').icon, Icons.auto_stories_rounded);
  });
}
```

- [ ] **Step 2: Verify the tests cannot compile yet**

Run: `work/dartsdk/dart-sdk/bin/dart analyze test/study_library_test.dart`
Expected: errors for undefined `studySubjects`, `StudyStage`, `studyLessonCount`, `studyReadCount`, `studyProgress`, `studySubjectVisual`.

- [ ] **Step 3: Implement the helpers**

Create `lib/core/study_library.dart` with the exact signatures above.

Implementation notes:
- `kGradeLabels` is moved verbatim from `course_list_screen.dart` (same 12 entries and order).
- `StudyStage.of` dispatches on the `prim` / `prep` / `sec` prefix and returns `null` otherwise.
- `studySubjects` iterates `grade.books` into a `Map<String, _SubjectAccumulator>` so insertion order matches `index.json`; then maps to `StudySubjectSummary`. For each book, count `book.lessons` and count a read lesson when `readLessons.contains('${grade.id}/${book.id}/$lesson')` for `lesson` in `1..book.lessons`.
- `studyLessonCount` sums `book.lessons`; `studyReadCount` uses the same key; `studyProgress` returns `0` when the lesson count is `0`.
- `studyGradesInStage` filters by `StudyStage.of(grade.id) == stage`, preserving input order.
- `studySubjectVisual` uses a `switch` over the known Arabic subject names with the palette from `curriculum.dart` (teal, blue, indigo, amber, orange, green, emerald, cyan, rose, brown, slate) and returns `(icon: Icons.auto_stories_rounded, color: Color(0xFF0F766E))` for anything else.

- [ ] **Step 4: Update `CourseListScreen` to use the moved map**

In `lib/features/courses/course_list_screen.dart`, delete the local `kGradeLabels` declaration and add:

```dart
import '../../core/study_library.dart';
```

- [ ] **Step 5: Verify analysis**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test`
Expected: `No issues found!`

---

### Task 2: Shared book widgets

**Files:**
- Create: `lib/features/library/library_widgets.dart`
- Modify: `lib/features/courses/course_list_screen.dart`

**Interfaces:**
- Consumes: `Book`, `kGradeLabels`.
- Produces:
  - `class BookTile extends StatelessWidget` with `const BookTile({super.key, required Book book, VoidCallback? onTap})`
  - `class BookSearchDelegate extends SearchDelegate<Book?>` with `BookSearchDelegate(this.grades)` and the existing search behavior over titles, subjects and variants.

- [ ] **Step 1: Create the shared widgets file**

Move `BookTile` (currently in `course_list_screen.dart:296-366`) and `_BookSearchDelegate` (currently `:369-462`) into `lib/features/library/library_widgets.dart`. Rename `_BookSearchDelegate` to `BookSearchDelegate` and make it public. Keep the UI and the `searchFieldLabel: 'ابحث عن كتاب…'` identical. Import `core/study_library.dart` for `kGradeLabels`, plus `models/manhaji.dart`, `core/theme.dart`, `widgets/common.dart`, `widgets/tr_text.dart`.

- [ ] **Step 2: Update `CourseListScreen`**

Remove the moved classes from `course_list_screen.dart`; import `../library/library_widgets.dart`; change `_BookSearchDelegate(grades)` to `BookSearchDelegate(grades)`. Do not change its behavior or routes.

- [ ] **Step 3: Verify analysis**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test`
Expected: `No issues found!`

---

### Task 3: Official-book catalog (empty by default)

**Files:**
- Create: `lib/models/official_book.dart`
- Create: `assets/data/official_books.json`
- Modify: `lib/core/asset_service.dart` (import + `loadOfficialBooks`)
- Modify: `lib/providers/app_providers.dart` (import + `officialBooksProvider`)
- Test: `test/official_books_test.dart`

**Interfaces:**
- Consumes: `AssetService._bundle`.
- Produces:
  - `class OfficialBook { final String id; final String grade; final String subject; final String title; final String url; final String source; factory OfficialBook.fromJson(Map<String, dynamic> json); Map<String, dynamic> toJson(); bool matches(String gradeId, String subject); }`
  - `class OfficialBookCatalog { final int version; final String updated; final List<OfficialBook> books; factory OfficialBookCatalog.fromJson(Map<String, dynamic> json); List<OfficialBook> forGradeSubject(String gradeId, String subject); bool get isEmpty; }`
  - `Future<OfficialBookCatalog> AssetService.loadOfficialBooks()`
  - `final officialBooksProvider = FutureProvider<OfficialBookCatalog>(...)`

- [ ] **Step 1: Write the failing tests**

Create `test/official_books_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/official_book.dart';

void main() {
  test('an empty catalog has no books', () {
    final catalog = OfficialBookCatalog.fromJson({
      'version': 1,
      'updated': '',
      'books': <dynamic>[],
    });

    expect(catalog.isEmpty, isTrue);
    expect(catalog.forGradeSubject('sec1', 'الرياضيات'), isEmpty);
  });

  test('filters official books by grade and subject', () {
    final catalog = OfficialBookCatalog.fromJson({
      'version': 1,
      'updated': '2026-10-24',
      'books': [
        {
          'id': 'math-sec1',
          'grade': 'sec1',
          'subject': 'الرياضيات',
          'title': 'الرياضيات — أولى ثانوي',
          'url': 'https://example.invalid/math-sec1.pdf',
          'source': 'official',
        },
        {
          'id': 'arabic-sec1',
          'grade': 'sec1',
          'subject': 'اللغة العربية',
          'title': 'اللغة العربية — أولى ثانوي',
          'url': 'https://example.invalid/arabic-sec1.pdf',
          'source': 'official',
        },
      ],
    });

    final matches = catalog.forGradeSubject('sec1', 'الرياضيات');
    expect(matches, hasLength(1));
    expect(matches.single.id, 'math-sec1');
    expect(catalog.forGradeSubject('sec2', 'الرياضيات'), isEmpty);
    expect(catalog.forGradeSubject('sec1', 'العلوم'), isEmpty);
  });
}
```

- [ ] **Step 2: Verify the tests cannot compile yet**

Run: `work/dartsdk/dart-sdk/bin/dart analyze test/official_books_test.dart`
Expected: errors for the missing `official_book.dart` / classes.

- [ ] **Step 3: Implement the model, asset, loader and provider**

Create `lib/models/official_book.dart` with the exact fields/signatures above. `fromJson` tolerates missing keys with `as String? ?? ''`; `books` defaults to `const []`. `forGradeSubject` returns books where `matches(gradeId, subject)` is true.

Create `assets/data/official_books.json`:

```json
{
  "version": 1,
  "updated": "",
  "books": []
}
```

In `lib/core/asset_service.dart`, import `../models/official_book.dart` and add:

```dart
Future<OfficialBookCatalog> loadOfficialBooks() async {
  final raw = await _bundle.loadString('assets/data/official_books.json');
  return OfficialBookCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
```

In `lib/providers/app_providers.dart`, import `../models/official_book.dart` and add:

```dart
final officialBooksProvider = FutureProvider<OfficialBookCatalog>((ref) async {
  return ref.watch(assetServiceProvider).loadOfficialBooks();
});
```

`assets/data/` is already listed in `pubspec.yaml`, so no pubspec change is needed.

- [ ] **Step 4: Verify analysis**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test`
Expected: `No issues found!`

---

### Task 4: Study Library hub and shell wiring

**Files:**
- Create: `lib/features/library/study_library_screen.dart`
- Modify: `lib/features/home/shell_screen.dart`
- Modify: `lib/core/router.dart`
- Modify: `lib/features/home/home_screen.dart`

**Interfaces:**
- Consumes: `gradesProvider`, `readLessonsProvider`, `studySubjects`, `studySubjects` counts, `studyGradesInStage`, `BookSearchDelegate`, `shellMenuLeading`.
- Produces:
  - `class StudyLibraryScreen extends ConsumerWidget` with `const StudyLibraryScreen({super.key})`
  - `ZakerRoutes.library = '/library'`
  - `ZakerRoutes.libraryPath(String gradeId) => '/library/<gradeId>'`
  - `ZakerRoutes.librarySubjectPath(String gradeId, String subject) => '/library/<gradeId>/<encoded subject>'`

- [ ] **Step 1: Create the hub screen**

Create `lib/features/library/study_library_screen.dart`:

- `Scaffold` with `AppBar(leading: shellMenuLeading(context), title: const TrText('المكتبة الدراسية'))` and a search action that calls `showSearch<Book?>(context: context, delegate: BookSearchDelegate(grades))`, then pushes `ZakerRoutes.lessonPath(book)`.
- Body: `gradesAsync.when(loading: LoadingBox(label: 'بنجهز المكتبة…'), error: EmptyState(...), data: ...)`.
- Data layout: a `ListView` with a teal gradient hero (`_LibraryHero`) showing the title, the subtitle `كل كتب المنهج في مكان واحد`, and glass stats for grade count, book count and lesson count.
- Then one `_StageSection` per `StudyStage.values` where `studyGradesInStage(grades, stage)` is non-empty: `SectionHeader(title: stage.label, icon: ...)` plus a 2-column `Wrap`/`GridView` of `_GradeCard`.
- `_GradeCard` shows the grade label, `studySubjects(grade, read).length` subjects, `grade.books.length` books, `studyLessonCount(grade)` lessons, a `ProgressBar(value: studyProgress(grade, read))`, and pushes `ZakerRoutes.libraryPath(grade.id)` on tap.
- Read progress comes from `ref.watch(readLessonsProvider)`.
- Counts are computed from the loaded `Grade` objects; never hardcode per-grade counts.

- [ ] **Step 2: Make the hub the tab and the `/courses` destination**

In `lib/features/home/shell_screen.dart`:
- Change the second `_Tab` label from `'مكتبتي'` to `'المكتبة الدراسية'`.
- Replace `1 => const CourseListScreen()` with `1 => const StudyLibraryScreen()`.
- Import `../library/study_library_screen.dart`; remove the now-unused `../courses/course_list_screen.dart` import if nothing else uses it.
- In `_NavItem`, change the label `maxLines: 1` to `maxLines: 2`, add `textAlign: TextAlign.center`, and set `fontSize: 9.5` so the longer label fits.

In `lib/core/router.dart`:
- Import `../features/library/study_library_screen.dart`.
- Change the `/courses` builder child from `CourseListScreen()` to `StudyLibraryScreen()`.
- Add the route constants/helpers from the Interfaces block. Add the two `/library` routes in Task 5 and Task 6.
- Leave `/grade/:gradeId` pointing at `CourseListScreen` unchanged.

- [ ] **Step 3: Update home entry-point labels**

In `lib/features/home/home_screen.dart`:
- Change the action card title `'موادك الدراسية'` to `'المكتبة الدراسية'` and its subtitle to `'كل الكتب والمناهج'` (same `/courses` tap).
- Change the `_LibrarySection` action label `'كل المواد'` to `'كل المكتبة'`.
- Change both `'تصفح المواد'` buttons to `'افتح المكتبة'`.
- Leave the `'منهج الثانوي'` tile and the `'موادك'` section title unchanged.

- [ ] **Step 4: Verify analysis**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test`
Expected: `No issues found!`

---

### Task 5: Grade screen (subjects)

**Files:**
- Create: `lib/features/library/study_grade_screen.dart`
- Modify: `lib/core/router.dart`
- Modify: `lib/features/library/study_library_screen.dart` (the grade card already pushes `libraryPath`)

**Interfaces:**
- Consumes: `gradeProvider(gradeId)`, `readLessonsProvider`, `studySubjects`, `kGradeLabels`, `ZakerRoutes.subjects`, `ZakerRoutes.librarySubjectPath`.
- Produces: `class StudyGradeScreen extends ConsumerWidget` with `const StudyGradeScreen({super.key, required String gradeId})`.

- [ ] **Step 1: Create the grade screen**

Create `lib/features/library/study_grade_screen.dart`:

- `Scaffold` with `AppBar(title: TrText(kGradeLabels[gradeId] ?? gradeId))`.
- Body: `gradeAsync.when(...)`.
- Data layout: `ListView` with:
  - `_GradeHeader`: stage label (`StudyStage.of(gradeId)?.label`), grade label, `StatChip`s for subjects/books/lessons, and a `ProgressBar` from `studyProgress(grade, read)`.
  - If `StudyStage.of(gradeId) == StudyStage.secondary`, a `_SecondaryHubCard` that pushes `'${ZakerRoutes.subjects}?grade=${Uri.encodeQueryComponent(gradeId)}'` and reads `منهج الثانوي` / `الشعب والمسارات والمواد التفصيلية`.
  - `SectionHeader(title: 'المواد', icon: Icons.auto_stories_rounded)`.
  - A 2-column grid of `_SubjectCard`s using `studySubjects(grade, read)`.
- `_SubjectCard` shows the subject icon/colour from `studySubjectVisual`, the name, `'${subject.books} كتاب · ${subject.lessons} درس'`, a `ProgressBar(value: subject.progress)` and the percent. On tap: `context.push(ZakerRoutes.librarySubjectPath(gradeId, subject.name))`.
- If `studySubjects` is empty, show `EmptyState(icon: Icons.menu_book_outlined, title: 'مفيش مواد في الصف ده', message: 'الكتب لسه بتتضاف للصف ده.')`.

- [ ] **Step 2: Add the route**

In `lib/core/router.dart`, add:

```dart
GoRoute(
  path: '${ZakerRoutes.library}/:gradeId',
  builder: (context, state) => StudyGradeScreen(
    gradeId: state.pathParameters['gradeId'] ?? 'sec1',
  ),
),
```

with the import for `study_grade_screen.dart`.

- [ ] **Step 3: Verify analysis**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test`
Expected: `No issues found!`

---

### Task 6: Subject screen (books + official pending state)

**Files:**
- Create: `lib/features/library/study_subject_screen.dart`
- Modify: `lib/core/router.dart`

**Interfaces:**
- Consumes: `gradeProvider(gradeId)`, `officialBooksProvider`, `readLessonsProvider`, `BookTile`, `ZakerRoutes.lessonPath`, `OfficialBookCatalog`.
- Produces: `class StudySubjectScreen extends ConsumerWidget` with `const StudySubjectScreen({super.key, required String gradeId, required String subject})`.

- [ ] **Step 1: Create the subject screen**

Create `lib/features/library/study_subject_screen.dart`:

- `Scaffold` with `AppBar(title: TrText(subject))`.
- Body: `gradeAsync.when(...)`.
- Filter the grade's books with `book.subject == subject` (exact match; the subject name comes from the same `Book.subject` values).
- Data layout: `ListView` with:
  - `_SubjectHeader`: `studySubjectVisual(subject)`, the subject name, `${books.length} كتاب`, the total lessons, and a `ProgressBar` computed from the filtered books and `readLessonsProvider` using the `'${gradeId}/${book.id}/$lesson'` key.
  - `SectionHeader(title: 'الكتب الرسمية', icon: Icons.verified_outlined)` followed by `officialAsync.when(...)`:
    - `data`: `catalog.forGradeSubject(gradeId, subject)`.
      - If empty: `_OfficialPendingCard` with the icon `Icons.hourglass_empty_rounded`, title `'البيانات الرسمية قيد الإضافة'`, message `'روابط الكتب الرسمية لسه بتتضاف. الكتب المتاحة فوق من مكتبة المنهج المرفقة.'` — no URL, no fake link.
      - If non-empty: a `ListTile` per book with the title, `source` subtitle, a launch icon, and `onTap` that calls `launchUrl(Uri.parse(book.url), mode: LaunchMode.externalApplication)`; on failure show a `SnackBar` with `'مش قادرين نفتح الرابط على الجهاز ده.'`.
    - `loading`: `LoadingBox()`.
    - `error`: the pending card (the catalog is optional and must never block the bundled books).
  - `SectionHeader(title: 'الكتب المتاحة', icon: Icons.menu_book_rounded)`.
  - If `books` is empty: `EmptyState(icon: Icons.menu_book_outlined, title: 'مفيش كتاب للمادة دي', message: 'جرّب مادة تانية من نفس الصف.')`.
  - Otherwise a `BookTile` per book; `onTap` pushes `ZakerRoutes.lessonPath(book)`.

- [ ] **Step 2: Add the route**

In `lib/core/router.dart`, add:

```dart
GoRoute(
  path: '${ZakerRoutes.library}/:gradeId/:subject',
  builder: (context, state) => StudySubjectScreen(
    gradeId: state.pathParameters['gradeId'] ?? 'sec1',
    subject: state.pathParameters['subject'] ?? '',
  ),
),
```

with the import for `study_subject_screen.dart`. go_router decodes the path parameter; do not call `Uri.decodeComponent` again.

- [ ] **Step 3: Verify analysis**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test`
Expected: `No issues found!`

---

### Task 7: Format, full check and handoff summary

**Files:**
- No new files.
- Modified files are those listed in Tasks 1–6.

- [ ] **Step 1: Format the changed Dart files**

Run:

```bash
work/dartsdk/dart-sdk/bin/dart format \
  lib/core/study_library.dart \
  lib/models/official_book.dart \
  lib/features/library \
  lib/features/courses/course_list_screen.dart \
  lib/features/home/shell_screen.dart \
  lib/features/home/home_screen.dart \
  lib/core/asset_service.dart \
  lib/core/router.dart \
  lib/providers/app_providers.dart \
  test/study_library_test.dart \
  test/official_books_test.dart
```

Expected: `Formatted ...` with no errors.

- [ ] **Step 2: Analyze the whole library and tests**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 3: Verify the legacy routes are still declared**

Run:

```bash
grep -n "ZakerRoutes.courses\|ZakerRoutes.grade\|ZakerRoutes.lesson\|ZakerRoutes.subjects\|ZakerRoutes.library" lib/core/router.dart
```

Expected: all of `/courses`, `/grade`, `/lesson`, `/subjects`, `/library` are present, and `/grade` still builds `CourseListScreen`.

- [ ] **Step 4: Report in Arabic**

Report, without claiming 100% completion if the catalog is empty:

1. Modified and newly created files.
2. Features successfully integrated.
3. Analysis status, plus the explicit note that Flutter tests were not run on this device (x86-64 tool) and run in CI.
4. Official book links/data still pending; `assets/data/official_books.json` contains `"books": []` and the UI shows the pending state.
