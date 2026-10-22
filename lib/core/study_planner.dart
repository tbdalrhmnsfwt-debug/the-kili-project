/// Builds study schedules from the bundled books.
///
/// Both the planner and the weekly report offer a one-tap "make me a plan"
/// action. They share this generator so a generated week always has the same
/// shape: one focused block per day, rotating through the grade's subjects.
library;

import '../models/manhaji.dart';
import '../models/schedule.dart';

/// A sensible default start time for the daily block.
const int kStudyStartHour = 17;

/// Builds seven daily study blocks starting on [start].
///
/// [books] supplies the subjects; duplicates are collapsed so the week
/// rotates instead of repeating one subject. The entries carry
/// `id = <idPrefix>-<yyyy-MM-dd>`, which lets a caller regenerate a plan
/// without duplicating the previous one.
List<ScheduleEntry> buildWeekSchedule({
  required List<Book> books,
  required DateTime start,
  int minutesPerDay = 45,
  String idPrefix = 'plan',
}) {
  final subjects = books
      .map((b) => b.subject.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();
  if (subjects.isEmpty) subjects.add('مراجعة');

  final now = DateTime.now();
  final first = DateTime(start.year, start.month, start.day);
  return [
    for (var i = 0; i < 7; i++)
      ScheduleEntry(
        id: '$idPrefix-${_dayKey(first.add(Duration(days: i)))}',
        title: 'مذاكرة ${subjects[i % subjects.length]}',
        notes: 'خطة مذاكرة — $minutesPerDay دقيقة',
        dueAt: DateTime(
          first.year,
          first.month,
          first.day + i,
          kStudyStartHour,
        ),
        dayOfWeek: first.add(Duration(days: i)).weekday % 7,
        createdAt: now,
      ),
  ];
}

/// The first day of next week (the coming Saturday).
DateTime nextWeekStart([DateTime? now]) {
  final reference = now ?? DateTime.now();
  final daysUntilSaturday = (DateTime.saturday - reference.weekday) % 7;
  final start = reference.add(
    Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday),
  );
  return DateTime(start.year, start.month, start.day);
}

/// Adds [fresh] to [schedule], replacing any earlier entries with the same
/// [idPrefix].
TaskSchedule mergePlan(
  TaskSchedule schedule,
  List<ScheduleEntry> fresh, {
  required String idPrefix,
}) {
  final kept = schedule.entries
      .where((e) => !e.id.startsWith('$idPrefix-'))
      .toList();
  return TaskSchedule(title: schedule.title, entries: [...kept, ...fresh]);
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
