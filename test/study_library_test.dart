import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/study_library.dart';
import '../lib/models/manhaji.dart';
import '../lib/models/official_book.dart';

Book _book({required String id, required String subject, int lessons = 1}) =>
    Book(
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

  test('merges official language variants into the bundled subject', () {
    final grade = Grade(
      id: 'sec1',
      label: 'أولى ثانوي',
      books: [
        _book(id: 'math', subject: 'الرياضيات', lessons: 4),
        _book(id: 'arabic', subject: 'اللغة العربية', lessons: 5),
      ],
    );
    final catalog = OfficialBookCatalog.fromJson({
      'version': 2,
      'books': [
        {
          'id': 'math-ar',
          'grade': 'sec1',
          'subject': 'الرياضيات باللغة العربية',
          'title_ar': 'الرياضيات',
          'url': 'https://example.invalid/math-ar.pdf',
        },
        {
          'id': 'math-en',
          'grade': 'sec1',
          'subject': 'الرياضيات باللغة الإنجليزية',
          'title_ar': 'Mathematics',
          'url': 'https://example.invalid/math-en.pdf',
        },
        {
          'id': 'math-story',
          'grade': 'sec1',
          'subject': 'الرياضيات-القصة',
          'title_ar': 'قصة الرياضيات',
          'kind': 'story',
          'url': 'https://example.invalid/math-story.pdf',
        },
        {
          'id': 'math-assessment',
          'grade': 'sec1',
          'subject': 'الرياضيات باللغة العربية',
          'title_ar': 'تقييم الرياضيات',
          'kind': 'assessment',
          'url': 'https://example.invalid/math-assessment.pdf',
        },
        {
          'id': 'arabic-ar',
          'grade': 'sec1',
          'subject': 'اللغة العربية',
          'title_ar': 'اللغة العربية',
          'url': 'https://example.invalid/arabic.pdf',
        },
        {
          'id': 'programming',
          'grade': 'sec1',
          'subject': 'البرمجة والذكاء الاصطناعي باللغة العربية',
          'title_ar': 'البرمجة',
          'url': 'https://example.invalid/programming.pdf',
        },
        {
          'id': 'notice',
          'grade': 'sec1',
          'subject': 'الكتب الرسمية',
          'title_ar': 'بيان',
          'kind': 'notice',
          'status': 'not_published',
        },
      ],
    });

    final subjects = studySubjects(grade, const {}, officialCatalog: catalog);

    expect(subjects.map((s) => s.name), [
      'الرياضيات',
      'اللغة العربية',
      'البرمجة والذكاء الاصطناعي',
    ]);
    final math = subjects[0];
    expect(math.books, 1);
    expect(math.lessons, 4);
    expect(math.officialBooks, 3);
    expect(math.officialAssessments, 1);
    expect(math.officialSources, 4);
    expect(subjects[1].officialBooks, 1);
    final programming = subjects[2];
    expect(programming.isOfficialOnly, isTrue);
    expect(programming.books, 0);
    expect(programming.officialBooks, 1);
    expect(subjects.where((s) => s.name == 'الكتب الرسمية'), isEmpty);
  });

  test('official-only subjects never replace bundled counts', () {
    final grade = Grade(
      id: 'sec1',
      label: 'أولى ثانوي',
      books: [_book(id: 'chemistry', subject: 'الكيمياء', lessons: 6)],
    );
    final catalog = OfficialBookCatalog.fromJson({
      'version': 2,
      'books': [
        {
          'id': 'chem',
          'grade': 'sec1',
          'subject': 'الكيمياء باللغة العربية',
          'title_ar': 'الكيمياء',
          'url': 'https://example.invalid/chem.pdf',
        },
      ],
    });

    final chemistry = studySubjects(
      grade,
      const {},
      officialCatalog: catalog,
    ).single;

    expect(chemistry.name, 'الكيمياء');
    expect(chemistry.books, 1);
    expect(chemistry.lessons, 6);
    expect(chemistry.officialBooks, 1);
    expect(chemistry.isOfficialOnly, isFalse);
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
