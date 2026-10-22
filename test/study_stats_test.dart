import 'package:flutter_test/flutter_test.dart';

import '../lib/models/study_stats.dart';

void main() {
  test('adds minutes to the day they were studied', () {
    final day = DateTime(2026, 10, 20, 18);
    final stats = const StudyStats()
        .recordMinutes(25, now: day)
        .recordMinutes(10, now: day);

    expect(stats.minutesOn(day), 35);
    expect(stats.totalMinutes, 35);
    expect(stats.recordMinutes(0, now: day).totalMinutes, 35);
  });

  test('counts consecutive days and stops at a gap', () {
    final today = DateTime(2026, 10, 22);
    var stats = const StudyStats();
    for (var i = 0; i < 4; i++) {
      stats = stats.recordMinutes(
        10,
        now: today.subtract(Duration(days: i)),
      );
    }

    expect(stats.streakAsOf(today), 4);

    // A day with no minutes breaks the run.
    final broken = stats.recordMinutes(
      10,
      now: today.subtract(const Duration(days: 6)),
    );
    expect(broken.streakAsOf(today), 4);
    expect(broken.streakAsOf(today.add(const Duration(days: 1))), 4);
    expect(broken.streakAsOf(today.add(const Duration(days: 2))), 0);
  });

  test('survives a JSON round trip', () {
    final day = DateTime(2026, 10, 20);
    final stats = const StudyStats().recordMinutes(42, now: day);
    final decoded = decodeStudyStats(encodeStudyStats(stats));

    expect(decoded.minutesOn(day), 42);
    expect(decoded.dailyMinutes, stats.dailyMinutes);
  });
}
