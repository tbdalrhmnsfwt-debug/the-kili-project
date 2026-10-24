import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/study_library.dart';
import '../lib/models/manhaji.dart';

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
