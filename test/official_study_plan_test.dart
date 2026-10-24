import 'package:flutter_test/flutter_test.dart';

import '../lib/core/official_study_plan.dart';
import '../lib/models/extraction.dart';
import '../lib/models/focus.dart';
import '../lib/models/official_book.dart';

OfficialBook _book() => const OfficialBook(
  id: 'math-sec1-term1',
  grade: 'sec1',
  subject: 'الرياضيات',
  subjectId: 'math',
  titleAr: 'الرياضيات — الصف الأول الثانوي',
  system: EducationSystem.generalSecondary,
  downloadUrl: 'https://elearnningcontent.blob.core.windows.net/x.pdf',
  status: OfficialBookStatus.available,
);

ExtractedSection _section(int number) => ExtractedSection(
  id: 's$number',
  title: 'الدرس $number',
  startPage: number * 2,
  endPage: number * 2 + 1,
  text: 'نص الدرس $number',
);

void main() {
  group('OfficialStudyPlanBuilder.build', () {
    test('returns an empty plan when there are no usable sections', () {
      final plan = OfficialStudyPlanBuilder.build(
        OfficialStudyPlanRequest(
          book: _book(),
          sections: const [
            ExtractedSection(
              id: 's1',
              title: '   ',
              startPage: 1,
              endPage: 1,
              text: 'x',
            ),
          ],
          startDate: DateTime(2026, 10, 24),
          targetDate: DateTime(2026, 11, 24),
        ),
      );

      expect(plan.tasks, isEmpty);
      expect(plan.sections, 0);
      expect(plan.studyDays, 0);
    });

    test('uses real section titles, pages and deterministic ids', () {
      final plan = OfficialStudyPlanBuilder.build(
        OfficialStudyPlanRequest(
          book: _book(),
          sections: [_section(1), _section(2)],
          startDate: DateTime(2026, 10, 24),
          targetDate: DateTime(2026, 11, 24),
          dailyMinutes: 60,
        ),
      );

      expect(plan.sections, 2);
      expect(plan.studyDays, 1);
      final study = plan.tasks.where((task) => !task.isReview).toList();
      expect(study, hasLength(2));
      expect(study.first.id, 'official:math-sec1-term1:s1:study');
      expect(study.first.title, contains('الدرس 1'));
      expect(study.first.sourceBookId, 'math-sec1-term1');
      expect(study.first.sourceSectionId, 's1');
      expect(study.first.sourcePage, 2);
      expect(study.first.dueAt, DateTime(2026, 10, 24, 21));
      expect(study.first.startAt, DateTime(2026, 10, 24, 16));
      expect(study.last.startAt, DateTime(2026, 10, 24, 16, 30));
    });

    test('adds spaced reviews at +1 and +3 days and a quiz at +7', () {
      final plan = OfficialStudyPlanBuilder.build(
        OfficialStudyPlanRequest(
          book: _book(),
          sections: [_section(1)],
          startDate: DateTime(2026, 10, 24),
          targetDate: DateTime(2026, 11, 24),
          dailyMinutes: 45,
        ),
      );

      final byId = {for (final task in plan.tasks) task.id: task};
      expect(byId, hasLength(4));
      expect(
        byId['official:math-sec1-term1:s1:review1']!.dueAt,
        DateTime(2026, 10, 25, 19, 30),
      );
      expect(
        byId['official:math-sec1-term1:s1:review3']!.dueAt,
        DateTime(2026, 10, 27, 19, 30),
      );
      expect(
        byId['official:math-sec1-term1:s1:quiz']!.dueAt,
        DateTime(2026, 10, 31, 19),
      );
      expect(byId.values.where((task) => task.isReview), hasLength(2));
    });

    test('can omit reviews and quizzes', () {
      final plan = OfficialStudyPlanBuilder.build(
        OfficialStudyPlanRequest(
          book: _book(),
          sections: [_section(1)],
          startDate: DateTime(2026, 10, 24),
          targetDate: DateTime(2026, 11, 24),
          includeReviews: false,
          includeQuiz: false,
        ),
      );
      expect(plan.tasks, hasLength(1));
      expect(plan.tasks.single.isReview, isFalse);
    });

    test('spreads lessons over the available days when time is short', () {
      final sections = [for (var i = 1; i <= 5; i++) _section(i)];
      final plan = OfficialStudyPlanBuilder.build(
        OfficialStudyPlanRequest(
          book: _book(),
          sections: sections,
          startDate: DateTime(2026, 10, 24),
          targetDate: DateTime(2026, 10, 26),
          dailyMinutes: 30,
          includeReviews: false,
          includeQuiz: false,
        ),
      );

      expect(plan.studyDays, 3);
      final days = plan.tasks.map((task) => task.dueAt!.day).toSet();
      expect(days, {24, 25, 26});
    });

    test('a target before the start still produces one study day', () {
      final plan = OfficialStudyPlanBuilder.build(
        OfficialStudyPlanRequest(
          book: _book(),
          sections: [_section(1)],
          startDate: DateTime(2026, 10, 24),
          targetDate: DateTime(2026, 10, 20),
        ),
      );
      expect(plan.studyDays, 1);
      expect(plan.tasks, isNotEmpty);
    });

    test('clamps daily minutes to a sane range', () {
      final plan = OfficialStudyPlanBuilder.build(
        OfficialStudyPlanRequest(
          book: _book(),
          sections: [_section(1)],
          startDate: DateTime(2026, 10, 24),
          targetDate: DateTime(2026, 11, 24),
          dailyMinutes: 1,
        ),
      );
      expect(plan.dailyMinutes, 15);
      expect(plan.weeklyMinutes, 105);
    });
  });

  group('OfficialStudyPlanBuilder.merge', () {
    test('preserves completed tasks and refreshes open ones', () {
      final old = StudyTask(
        id: 'official:book:s1:study',
        title: 'قديم',
        dueAt: DateTime(2026, 10, 20),
      );
      final done = StudyTask(
        id: 'official:book:s1:review1',
        title: 'خلص',
        done: true,
        dueAt: DateTime(2026, 10, 21),
      );
      final fresh = [
        StudyTask(
          id: 'official:book:s1:study',
          title: 'جديد',
          dueAt: DateTime(2026, 11, 1),
        ),
        StudyTask(
          id: 'official:book:s1:review1',
          title: 'جديد',
          dueAt: DateTime(2026, 11, 2),
        ),
        StudyTask(id: 'official:book:s1:quiz', title: 'اختبار'),
      ];

      final merged = OfficialStudyPlanBuilder.merge([old, done], fresh);
      expect(merged, hasLength(3));
      expect(merged.first.title, 'جديد');
      expect(merged.first.dueAt, DateTime(2026, 11, 1));
      expect(merged[1].title, 'خلص');
      expect(merged[1].done, isTrue);
      expect(merged[2].id, 'official:book:s1:quiz');
    });

    test('does not add duplicate ids on repeated merges', () {
      final generated = [
        StudyTask(id: 'a', title: 'a'),
        StudyTask(id: 'b', title: 'b'),
      ];
      final once = OfficialStudyPlanBuilder.merge([], generated);
      final twice = OfficialStudyPlanBuilder.merge(once, generated);
      expect(twice, hasLength(2));
    });
  });

  group('OfficialStudyPlanBuilder.rescheduleOverdue', () {
    test('moves only unfinished overdue tasks to successive days', () {
      final now = DateTime(2026, 10, 24, 12);
      final tasks = [
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
        StudyTask(id: 'future', title: 'بكرة', dueAt: DateTime(2026, 10, 30)),
      ];

      final moved = OfficialStudyPlanBuilder.rescheduleOverdue(
        tasks,
        now: now,
      );
      final byId = {for (final task in moved) task.id: task};
      expect(byId['late']!.dueAt, DateTime(2026, 10, 25, 21));
      expect(byId['late']!.startAt, DateTime(2026, 10, 25, 16));
      expect(byId['done']!.dueAt, DateTime(2026, 10, 20, 21));
      expect(byId['future']!.dueAt, DateTime(2026, 10, 30));
    });

    test('returns the same tasks when nothing is overdue', () {
      final tasks = [
        StudyTask(id: 'a', title: 'a', dueAt: DateTime(2026, 11, 1)),
      ];
      final result = OfficialStudyPlanBuilder.rescheduleOverdue(
        tasks,
        now: DateTime(2026, 10, 24),
      );
      expect(result.single.dueAt, DateTime(2026, 11, 1));
    });
  });
}
