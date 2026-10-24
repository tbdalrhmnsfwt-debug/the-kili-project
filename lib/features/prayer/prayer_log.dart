/// The persisted daily prayer log.
///
/// One entry per calendar day holds the prayers the user marked as prayed.
/// A streak counts consecutive days whose five prayers were all marked; today
/// only counts once it is complete, so an unfinished day never breaks the
/// streak the user is still building.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../core/local_store.dart';
import 'prayer_models.dart';

/// Store key for the prayer log.
const String kPrayerLogStoreKey = 'prayer_log';

/// The maximum number of days kept; older entries are dropped on load.
const int kPrayerLogKeepDays = 400;

/// `YYYY-MM-DD` for [date] in local time.
String prayerLogDayKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// The marks for every day, keyed by [prayerLogDayKey].
class PrayerLog {
  const PrayerLog([this._days = const <String, Set<PrayerName>>{}]);

  final Map<String, Set<PrayerName>> _days;

  Set<PrayerName> marksFor(DateTime date) =>
      _days[prayerLogDayKey(date)] ?? const <PrayerName>{};

  bool isMarked(DateTime date, PrayerName prayer) =>
      marksFor(date).contains(prayer);

  bool isComplete(DateTime date) =>
      marksFor(date).length >= PrayerName.values.length;

  int countFor(DateTime date) => marksFor(date).length;

  /// Adds or removes one mark for [prayer] on [date].
  PrayerLog toggled(DateTime date, PrayerName prayer) {
    final key = prayerLogDayKey(date);
    final next = <String, Set<PrayerName>>{
      for (final entry in _days.entries)
        entry.key: Set<PrayerName>.unmodifiable(entry.value),
    };
    final day = Set<PrayerName>.of(next[key] ?? const <PrayerName>{});
    if (!day.remove(prayer)) day.add(prayer);
    if (day.isEmpty) {
      next.remove(key);
    } else {
      next[key] = Set<PrayerName>.unmodifiable(day);
    }
    return PrayerLog(Map<String, Set<PrayerName>>.unmodifiable(next));
  }

  /// Consecutive complete days ending today, or ending yesterday when today
  /// is still incomplete.
  int streak({DateTime? now}) {
    final today = now ?? DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!isComplete(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (isComplete(cursor)) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
    'days': {
      for (final entry in _days.entries)
        entry.key: [
          for (final prayer in PrayerName.values)
            if (entry.value.contains(prayer)) prayer.name,
        ],
    },
  };

  /// Reads a stored log, dropping malformed entries and old days.
  static PrayerLog fromJson(Map<String, dynamic>? json, {DateTime? now}) {
    final raw = json?['days'];
    if (raw is! Map) return const PrayerLog();
    final today = now ?? DateTime.now();
    final oldest = DateTime(
      today.year,
      today.month,
      today.day - kPrayerLogKeepDays,
    );
    final days = <String, Set<PrayerName>>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String || entry.value is! List) continue;
      final date = DateTime.tryParse(key);
      if (date == null || date.isBefore(oldest)) continue;
      final marks = <PrayerName>{};
      for (final value in entry.value as List) {
        for (final prayer in PrayerName.values) {
          if (value == prayer.name) marks.add(prayer);
        }
      }
      if (marks.isNotEmpty) {
        days[key] = Set<PrayerName>.unmodifiable(marks);
      }
    }
    return PrayerLog(Map<String, Set<PrayerName>>.unmodifiable(days));
  }
}

final prayerLogProvider = StateNotifierProvider<PrayerLogController, PrayerLog>(
  (ref) => PrayerLogController(ref.watch(localStoreProvider)),
);

class PrayerLogController extends StateNotifier<PrayerLog> {
  PrayerLogController(this._store)
    : super(PrayerLog.fromJson(_store.getJson(kPrayerLogStoreKey)));

  final LocalStore _store;

  void _commit(PrayerLog next) {
    state = next;
    _store.setJson(kPrayerLogStoreKey, next.toJson());
  }

  /// Marks [prayer] as prayed on [date], or clears the mark.
  void toggle(DateTime date, PrayerName prayer) {
    _commit(state.toggled(date, prayer));
  }
}
