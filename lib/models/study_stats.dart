/// Daily study statistics.
///
/// The home card derives its streak and "minutes today" from this record, and
/// the garden and weekly report read the same history. Only the per-day
/// minutes are stored; the totals and the streak are computed on read so a
/// day boundary never needs a migration or a rewrite.
library;

import 'dart:convert';

/// Minutes studied per calendar day, keyed `yyyy-MM-dd`.
class StudyStats {
  const StudyStats({this.dailyMinutes = const <String, int>{}});

  final Map<String, int> dailyMinutes;

  /// The storage key for [day] (`yyyy-MM-dd`).
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Minutes recorded on [day].
  int minutesOn(DateTime day) => dailyMinutes[dayKey(day)] ?? 0;

  /// Minutes recorded today.
  int get minutesToday => minutesOn(DateTime.now());

  /// Total minutes ever recorded.
  int get totalMinutes {
    var sum = 0;
    for (final value in dailyMinutes.values) {
      sum += value;
    }
    return sum;
  }

  /// Consecutive days with study time, counting back from today.
  ///
  /// A streak that ended yesterday still counts until the day is over, so the
  /// home card does not drop to zero at midnight before the user studies.
  int get streakDays => streakAsOf();

  /// [streakDays] as it would read on [now].
  int streakAsOf([DateTime? now]) {
    var day = _dateOnly(now ?? DateTime.now());
    if (minutesOn(day) == 0) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (minutesOn(day) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// A copy with [minutes] added to [now]'s day.
  StudyStats recordMinutes(int minutes, {DateTime? now}) {
    if (minutes <= 0) return this;
    final reference = now ?? DateTime.now();
    final next = Map<String, int>.from(dailyMinutes);
    final key = dayKey(reference);
    next[key] = (next[key] ?? 0) + minutes;

    // Keep roughly a year of history so the stored JSON stays small.
    if (next.length > 400) {
      final keys = next.keys.toList()..sort();
      for (final stale in keys.take(next.length - 400)) {
        next.remove(stale);
      }
    }
    return StudyStats(dailyMinutes: next);
  }

  Map<String, dynamic> toJson() => {'days': dailyMinutes};

  factory StudyStats.fromJson(Map<String, dynamic> json) {
    final days = <String, int>{};
    final raw = json['days'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is num) {
          days[entry.key.toString()] = value.toInt();
        }
      }
    }
    return StudyStats(dailyMinutes: days);
  }

  static DateTime _dateOnly(DateTime day) =>
      DateTime(day.year, day.month, day.day);
}

/// Encodes [StudyStats] for persistence.
String encodeStudyStats(StudyStats stats) => jsonEncode(stats.toJson());

/// Decodes statistics persisted by [encodeStudyStats].
StudyStats decodeStudyStats(String raw) =>
    StudyStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
