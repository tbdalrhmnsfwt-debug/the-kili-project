/// Builds real study-plan tasks from extracted official lessons.
///
/// The plan is deterministic: the same book, sections and dates always produce
/// the same task ids, so regenerating after adding lessons updates the plan
/// instead of duplicating it. Completed tasks are never rewritten, and
/// [rescheduleOverdue] only moves unfinished work.
library;

import 'dart:math' as math;

import '../models/extraction.dart';
import '../models/focus.dart';
import '../models/official_book.dart';

/// Inputs for an official-book study plan.
class OfficialStudyPlanRequest {
  const OfficialStudyPlanRequest({
    required this.book,
    required this.sections,
    required this.startDate,
    required this.targetDate,
    this.dailyMinutes = 45,
    this.includeReviews = true,
    this.includeQuiz = true,
  });

  final OfficialBook book;
  final List<ExtractedSection> sections;
  final DateTime startDate;
  final DateTime targetDate;

  /// Study time available on each planned day.
  final int dailyMinutes;

  final bool includeReviews;
  final bool includeQuiz;
}

/// A generated plan and the facts the UI reports about it.
class OfficialStudyPlan {
  const OfficialStudyPlan({
    required this.tasks,
    required this.studyDays,
    required this.sections,
    required this.dailyMinutes,
  });

  final List<StudyTask> tasks;
  final int studyDays;
  final int sections;
  final int dailyMinutes;

  int get weeklyMinutes => dailyMinutes * 7;

  String get summary =>
      '$sections درس على $studyDays يوم · $dailyMinutes دقيقة/يوم · '
      '${tasks.where((task) => task.isReview).length} جلسة مراجعة';
}

/// A deterministic planner for official lessons.
class OfficialStudyPlanBuilder {
  const OfficialStudyPlanBuilder._();

  static OfficialStudyPlan build(OfficialStudyPlanRequest request) {
    final start = _day(request.startDate);
    var target = _day(request.targetDate);
    if (target.isBefore(start)) target = start;
    final availableDays = math.max(1, target.difference(start).inDays + 1);
    final sections = request.sections
        .where((section) => section.title.trim().isNotEmpty)
        .toList(growable: false);

    if (sections.isEmpty) {
      return OfficialStudyPlan(
        tasks: const [],
        studyDays: 0,
        sections: 0,
        dailyMinutes: request.dailyMinutes,
      );
    }

    final daily = request.dailyMinutes.clamp(15, 480);
    // One focused 25-minute block per sitting; never more than the day allows.
    final perDay = math.max(1, math.min(sections.length, daily ~/ 25));
    final neededDays = (sections.length / perDay).ceil();
    final studyDays = math.min(availableDays, neededDays);
    final minutesPerSession = math.max(15, math.min(90, daily ~/ perDay));
    final tasks = <StudyTask>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final dayIndex = math.min(studyDays - 1, i ~/ perDay);
      final withinDay = i % perDay;
      final day = start.add(Duration(days: dayIndex));
      final startAt = DateTime(
        day.year,
        day.month,
        day.day,
        16,
        0,
      ).add(Duration(minutes: withinDay * minutesPerSession));
      final dueAt = DateTime(day.year, day.month, day.day, 21);
      final pageLabel = section.startPage == section.endPage
          ? 'صفحة ${section.startPage}'
          : 'صفحات ${section.startPage}–${section.endPage}';

      tasks.add(
        StudyTask(
          id: _id(request.book.id, section.id, 'study'),
          title: 'مذاكرة: ${section.title}',
          notes:
              'المصدر: «${request.book.titleAr}» — $pageLabel. '
              'جلسة مقترحة $minutesPerSession دقيقة. '
              'الشرح والملخص والكروت كلها مربوطة بالصفحات دي.',
          subject: request.book.subject,
          startAt: startAt,
          dueAt: dueAt,
          important: i == 0,
          createdAt: DateTime.now(),
          sourceBookId: request.book.id,
          sourceBookTitle: request.book.titleAr,
          sourceSectionId: section.id,
          sourceSectionTitle: section.title,
          sourcePage: section.startPage,
        ),
      );

      if (request.includeReviews) {
        for (final offset in const [1, 3]) {
          final reviewDay = day.add(Duration(days: offset));
          tasks.add(
            StudyTask(
              id: _id(request.book.id, section.id, 'review$offset'),
              title: 'مراجعة: ${section.title}',
              notes:
                  'مراجعة متباعدة بعد $offset يوم من المذاكرة. '
                  'المصدر: «${request.book.titleAr}» — $pageLabel.',
              subject: request.book.subject,
              startAt: DateTime(
                reviewDay.year,
                reviewDay.month,
                reviewDay.day,
                18,
                30,
              ),
              dueAt: DateTime(
                reviewDay.year,
                reviewDay.month,
                reviewDay.day,
                19,
                30,
              ),
              isReview: true,
              createdAt: DateTime.now(),
              sourceBookId: request.book.id,
              sourceBookTitle: request.book.titleAr,
              sourceSectionId: section.id,
              sourceSectionTitle: section.title,
              sourcePage: section.startPage,
            ),
          );
        }
      }

      if (request.includeQuiz) {
        final quizDay = day.add(const Duration(days: 7));
        tasks.add(
          StudyTask(
            id: _id(request.book.id, section.id, 'quiz'),
            title: 'اختبار قصير: ${section.title}',
            notes:
                'اختبار من أسئلة الكتاب نفسه بعد أسبوع. '
                'المصدر: «${request.book.titleAr}» — $pageLabel.',
            subject: request.book.subject,
            startAt: DateTime(
              quizDay.year,
              quizDay.month,
              quizDay.day,
              18,
            ),
            dueAt: DateTime(
              quizDay.year,
              quizDay.month,
              quizDay.day,
              19,
            ),
            createdAt: DateTime.now(),
            sourceBookId: request.book.id,
            sourceBookTitle: request.book.titleAr,
            sourceSectionId: section.id,
            sourceSectionTitle: section.title,
            sourcePage: section.startPage,
          ),
        );
      }
    }

    return OfficialStudyPlan(
      tasks: tasks,
      studyDays: studyDays,
      sections: sections.length,
      dailyMinutes: daily,
    );
  }

  /// Adds or refreshes [generated] tasks without touching completed work.
  ///
  /// Existing task ids are updated in place when they are still open, so a
  /// regenerated plan reflects the new dates. Completed tasks keep exactly
  /// what the student finished.
  static List<StudyTask> merge(
    List<StudyTask> existing,
    List<StudyTask> generated,
  ) {
    final result = List<StudyTask>.of(existing);
    final positions = <String, int>{
      for (var i = 0; i < result.length; i++) result[i].id: i,
    };
    for (final task in generated) {
      if (task.id.isEmpty) continue;
      final index = positions[task.id];
      if (index == null) {
        positions[task.id] = result.length;
        result.add(task);
      } else if (!result[index].done) {
        result[index] = task;
      }
    }
    return result;
  }

  /// Moves unfinished overdue tasks forward without touching completed work.
  ///
  /// [days] is the first free day; successive overdue tasks get successive
  /// days so the catch-up does not pile everything on one date.
  static List<StudyTask> rescheduleOverdue(
    List<StudyTask> tasks, {
    DateTime? now,
    int days = 1,
  }) {
    final reference = now ?? DateTime.now();
    final today = _day(reference);
    final overdue = tasks
        .where(
          (task) =>
              !task.done &&
              task.dueAt != null &&
              task.dueAt!.isBefore(reference),
        )
        .toList();
    if (overdue.isEmpty) return List<StudyTask>.of(tasks);

    overdue.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final moved = <String, StudyTask>{};
    for (var i = 0; i < overdue.length; i++) {
      final task = overdue[i];
      final dueDay = today.add(Duration(days: days + i));
      final originalTime = task.dueAt!;
      final due = DateTime(
        dueDay.year,
        dueDay.month,
        dueDay.day,
        originalTime.hour,
        originalTime.minute,
      );
      moved[task.id] = task.copyWith(
        dueAt: due,
        startAt: task.startAt == null
            ? null
            : due.subtract(
                Duration(
                  hours: task.dueAt!.difference(task.startAt!).inHours.abs(),
                ),
              ),
      );
    }
    return [
      for (final task in tasks) moved[task.id] ?? task,
    ];
  }

  static String _id(String bookId, String sectionId, String suffix) =>
      'official:$bookId:$sectionId:$suffix';

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
