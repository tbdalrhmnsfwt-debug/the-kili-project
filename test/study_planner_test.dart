import 'package:flutter_test/flutter_test.dart';

import '../lib/core/study_planner.dart';
import '../lib/models/manhaji.dart';
import '../lib/models/schedule.dart';

Book _book(String subject) => Book(
  id: 'book-$subject',
  subject: subject,
  variant: '',
  lang: 'ar',
  title: subject,
  pages: 10,
  lessons: 2,
  grade: 'sec1',
  file: '$subject.json.gz',
  fingerprint: 'fp',
);

void main() {
  test('builds one block per day, rotating the subjects', () {
    final start = DateTime(2026, 10, 24);
    final plan = buildWeekSchedule(
      books: [_book('الرياضيات'), _book('العلوم')],
      start: start,
      minutesPerDay: 45,
    );

    expect(plan, hasLength(7));
    expect(plan.map((e) => e.id).toSet(), hasLength(7));
    expect(plan[0].title, 'مذاكرة الرياضيات');
    expect(plan[1].title, 'مذاكرة العلوم');
    expect(plan[2].title, 'مذاكرة الرياضيات');
    expect(plan.first.dueAt!.hour, kStudyStartHour);
    expect(plan.first.notes, contains('45'));
  });

  test('regenerating a plan replaces the previous one', () {
    final day = DateTime(2026, 10, 24);
    final first = buildWeekSchedule(
      books: [_book('الرياضيات')],
      start: day,
    );
    final older = TaskSchedule(
      title: 'قائمة المهام',
      entries: [
        ...first,
        ScheduleEntry(id: 'manual-1', title: 'مهمة'),
      ],
    );

    final second = buildWeekSchedule(
      books: [_book('العلوم')],
      start: day,
    );
    final merged = mergePlan(older, second, idPrefix: 'plan');

    expect(merged.entries, hasLength(8));
    expect(
      merged.entries.where((e) => e.id.startsWith('plan-')),
      hasLength(7),
    );
    expect(merged.entries.any((e) => e.title == 'مهمة'), isTrue);
    expect(merged.entries.any((e) => e.title == 'مذاكرة العلوم'), isTrue);
  });

  test('next week starts on a Saturday', () {
    final monday = DateTime(2026, 10, 19);
    final start = nextWeekStart(monday);

    expect(start.weekday, DateTime.saturday);
    expect(start.isAfter(monday), isTrue);
  });
}
