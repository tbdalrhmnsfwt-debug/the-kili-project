# «المكتبة الدراسية» — Design

**Date:** 2026-10-24
**Status:** Approved by the user ("Proceed with the plan")

## Intent

The app's second bottom-navigation tab is currently labelled «مكتبتي» and
renders `CourseListScreen`, a flat screen with grade chips, subject chips and a
book list. The user wants this section renamed to **«المكتبة الدراسية»** and
turned into a real curriculum hierarchy:

**grade → subject → book → lesson**

The existing grade/book/lesson screens and routes must keep working.

## Goals

- Rename the section to «المكتبة الدراسية» everywhere the tab is surfaced.
- Add a grade hub with all 12 Egyptian grades grouped by stage (ابتدائي /
  إعدادي / ثانوي), with real counts from the bundled library.
- Add a subject screen per grade, with subject cards aggregated from the
  grade's own `index.json` books (no invented subjects).
- Add a subject book screen that reuses the existing `BookLessonsScreen` for
  the lesson list and reader.
- Keep the secondary curriculum hub (`/subjects`, tracks/branches) reachable.
- Keep every legacy route working: `/courses`, `/grade/:id`,
  `/lesson/:gradeId/:bookId`, `/subjects/:gradeId/:subjectId`.
- Add an official-books catalog structure that is **empty by default** and
  shows a pending state; never fabricate official URLs.
- Add unit tests for aggregation, stage mapping, route-parameter round-trips
  and catalog parsing.

## Non-goals

- No deployment, no push, no deployment-config changes.
- No invented official book links or PDF metadata.
- No rewrite of `BookLessonsScreen`, `LessonReaderScreen`, `SubjectsScreen`
  or `SubjectScreen`.
- No change to the bundled `assets/manhaji` payloads.
- No new network dependency; `url_launcher` is already present for catalog
  links once real data exists.

## Constraints

- Arabic UI labels, RTL, brand theme (`ZakerColors`, `ZakerSpacing`,
  `ZakerRadius`).
- Do not hallucinate components or styles from a description; reuse the
  existing widgets and visual language (`SectionHeader`, `StatChip`,
  `ProgressBar`, `EmptyState`, `LoadingBox`, gradient hero cards).
- The vendored Flutter tool's Dart is x86-64 and does not run on this device.
  Analysis uses `work/dartsdk/dart-sdk/bin/dart analyze`. Flutter tests are
  written but run in CI (GitHub Actions), not locally.
- No commits unless the user asks; no push.

## Approaches considered

1. **New hierarchical tab, additive routes (chosen).** Replace the tab body
   with a new hub, add `/library/:gradeId` and `/library/:gradeId/:subject`,
   keep `CourseListScreen` and all legacy routes intact. Lowest risk; no
   invented data; the secondary hub stays reachable.
2. Extend `curriculum.dart` to all 12 grades and reuse `SubjectsScreen`
   everywhere. Richer secondary metadata, but requires inventing subject
   definitions for nine non-secondary grades and changes the existing hub.
3. Only rename the tab and add subject cards inline in `CourseListScreen`.
   Fewer files, but not a real navigable hierarchy.

The user approved approach 1.

## Decisions

- **Tab label:** «المكتبة الدراسية» in the sidebar and bottom bar. The bottom
  bar item allows two lines so the label does not truncate.
- **Root route:** `/courses` keeps its path and now builds the new hub inside
  the shell, so every existing push to `/courses` lands on the library.
- **Detail routes:** `/library/:gradeId` (subjects) and
  `/library/:gradeId/:subject` (books). Subject names are URL-encoded.
- **Legacy:** `/grade/:gradeId` still builds `CourseListScreen`; the lesson
  flow is unchanged.
- **Subjects:** derived from `grade.books` by `book.subject`, preserving the
  order in `index.json`. Counts are per book/lesson; progress uses the same
  `gradeId/bookId/lessonNumber` key as the rest of the app.
- **Secondary entry point:** a «منهج الثانوي» card on sec1–sec3 grade screens
  links to the existing `/subjects` hub with the grade preselected.
- **Official catalog:** `assets/data/official_books.json` ships with
  `"books": []`. The subject screen shows «البيانات الرسمية قيد الإضافة»
  when the catalog has no match. Parsing/filtering is implemented and tested
  so real data can be dropped in later without code changes.
- **Visual mapping:** subject icon/colour mapping is presentation-only, based
  on the existing `curriculum.dart` palette, with a generic fallback for
  unknown subjects.

## Left to the builder

- Exact card padding/gradients within the existing theme tokens.
- Whether to show an optional subject count badge on the stage headers.
- The wording of the pending-official card, as long as it does not imply
  links exist.
