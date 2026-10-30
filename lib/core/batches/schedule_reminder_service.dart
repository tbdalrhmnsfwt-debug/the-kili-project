/// Weekly and one-off timetable reminders on this device.
///
/// A row may only produce a reminder when it carries an explicit time basis:
/// a nonzero start, a weekly rule (or a week anchor for a one-off row), and a
/// timezone marker recorded when the user turned the reminder on. The marker
/// is the device's own zone at that moment; when the device zone changes the
/// service cancels the stale schedules and reports the mismatch instead of
/// silently moving a class to the new local time.
///
/// The system scheduler itself is behind [ScheduleReminderSink], so the
/// planning logic and its privacy rules are testable without a platform
/// channel.
library;

import 'dart:convert';

import '../../models/batch_schedule.dart';
import 'batch_repository.dart';

/// How early a class reminder fires.
const int scheduleReminderLeadMinutes = 10;

/// How many weekly occurrences are reserved in the system queue. Reopening
/// the schedules screen renews the window.
const int scheduleReminderHorizon = 4;

/// First notification id reserved for timetable reminders.
const int kScheduleReminderIdBase = 9000;

/// One past the last reserved id.
const int kScheduleReminderIdLimit = 9900;

/// Whether [id] belongs to a timetable reminder.
bool isScheduleReminderId(int id) =>
    id >= kScheduleReminderIdBase && id < kScheduleReminderIdLimit;

/// A stable marker for the device's current clock, stored on a row when its
/// reminder is enabled. It is deliberately not a guessed regional zone.
String deviceTimeZoneMarker(DateTime now) {
  final name = now.timeZoneName.trim();
  final safeName = name.isEmpty ? 'local' : name;
  final offset = now.timeZoneOffset.inMinutes;
  return 'device:$safeName:$offset';
}

/// The reminder instants for one row, or an empty list when the row has no
/// usable basis. Times are local `DateTime`s, so the platform scheduler keeps
/// the correct absolute instant.
List<DateTime> plannedReminderTimes(TimetableEntry entry, DateTime now) {
  if (!entry.hasTimeBasis || entry.startMinutes < 0) return const [];
  if (entry.startMinutes >= 24 * 60) return const [];
  if (entry.endMinutes <= entry.startMinutes) return const [];
  if (entry.title.trim().isEmpty) return const [];
  if (entry.dayOfWeek < DateTime.monday || entry.dayOfWeek > DateTime.sunday) {
    return const [];
  }

  DateTime reminderOn(DateTime day) {
    return DateTime(day.year, day.month, day.day).add(
      Duration(minutes: entry.startMinutes - scheduleReminderLeadMinutes),
    );
  }

  if (entry.recurrence == TimetableRecurrence.weekly) {
    var day = DateTime(now.year, now.month, now.day);
    var guard = 0;
    while (day.weekday != entry.dayOfWeek && guard < 7) {
      day = DateTime(day.year, day.month, day.day + 1);
      guard++;
    }
    // Calendar arithmetic, not `Duration(days: 7)`: a weekly class keeps the
    // same wall-clock time even when the device crosses a DST boundary.
    DateTime onDay(int offsetDays) {
      return DateTime(day.year, day.month, day.day + offsetDays).add(
        Duration(minutes: entry.startMinutes - scheduleReminderLeadMinutes),
      );
    }

    final firstOffset = onDay(0).isAfter(now) ? 0 : 7;
    return [
      for (var i = 0; i < scheduleReminderHorizon; i++)
        onDay(firstOffset + i * 7),
    ];
  }

  final anchor = entry.weekAnchorDate;
  if (anchor == null) return const [];
  final when = reminderOn(anchor);
  if (!when.isAfter(now)) return const [];
  return [when];
}

/// The platform operations the reminder service needs.
abstract class ScheduleReminderSink {
  Future<void> ensureChannel();
  Future<bool> requestPermission();
  Future<Set<int>> pendingIds();
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  });
  Future<void> cancel(int id);
}

/// What one [ScheduleReminderService.sync] pass did.
class ScheduleReminderSyncResult {
  const ScheduleReminderSyncResult({
    this.scheduled = 0,
    this.cancelled = 0,
    this.skipped = 0,
    this.timeZoneMismatch = 0,
    this.permissionDenied = false,
  });

  final int scheduled;
  final int cancelled;
  final int skipped;

  /// Rows whose stored device marker no longer matches this device.
  final int timeZoneMismatch;
  final bool permissionDenied;
}

/// Rebuilds the device's timetable reminder queue from published rows.
class ScheduleReminderService {
  ScheduleReminderService({
    required BatchRepository repository,
    required ScheduleReminderSink notifications,
  })  : _repository = repository,
        _notifications = notifications;

  final BatchRepository _repository;
  final ScheduleReminderSink _notifications;
  int _nextId = kScheduleReminderIdBase;

  /// Cancels every timetable reminder this app scheduled and, when the
  /// published rows still have a usable basis, schedules the next window.
  ///
  /// [drafts] lets a caller pass the list it already loaded; otherwise the
  /// repository's access-checked read is used.
  Future<ScheduleReminderSyncResult> sync({
    required String uid,
    required String batchId,
    List<TimetableDraft>? drafts,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final all = drafts ?? await _repository.loadSchedules(uid, batchId);

    final wanted = <({String draftId, TimetableEntry entry})>[];
    for (final draft in all) {
      if (draft.status != TimetableDraftStatus.published) continue;
      for (final entry in draft.entries) {
        if (entry.reminderEnabled) {
          wanted.add((draftId: draft.id, entry: entry));
        }
      }
    }

    var cancelled = 0;
    final pending = await _notifications.pendingIds();
    for (final id in pending) {
      if (!isScheduleReminderId(id)) continue;
      await _notifications.cancel(id);
      cancelled++;
    }

    if (wanted.isEmpty) {
      return ScheduleReminderSyncResult(cancelled: cancelled);
    }

    final marker = deviceTimeZoneMarker(at);
    final planned =
        <({String draftId, TimetableEntry entry, List<DateTime> times})>[];
    var skipped = 0;
    var mismatch = 0;
    for (final item in wanted) {
      final basis = item.entry.timeZoneId;
      if (basis == null || basis.isEmpty) {
        skipped++;
        continue;
      }
      if (basis != marker) {
        skipped++;
        mismatch++;
        continue;
      }
      final times = plannedReminderTimes(item.entry, at);
      if (times.isEmpty) {
        skipped++;
        continue;
      }
      planned.add((
        draftId: item.draftId,
        entry: item.entry,
        times: times,
      ));
    }

    if (planned.isEmpty) {
      return ScheduleReminderSyncResult(
        cancelled: cancelled,
        skipped: skipped,
        timeZoneMismatch: mismatch,
      );
    }

    final allowed = await _notifications.requestPermission();
    if (!allowed) {
      return ScheduleReminderSyncResult(
        cancelled: cancelled,
        skipped: skipped,
        timeZoneMismatch: mismatch,
        permissionDenied: true,
      );
    }

    await _notifications.ensureChannel();
    _nextId = kScheduleReminderIdBase;
    var scheduled = 0;
    for (final item in planned) {
      for (final when in item.times) {
        if (_nextId >= kScheduleReminderIdLimit) break;
        final id = _nextId++;
        final ok = await _notifications.schedule(
          id: id,
          title: 'تذكير حصة',
          // The lock screen stays free of class titles, teacher names and
          // any file name; the batch and row ids live only in the payload.
          body: 'فاضل ١٠ دقايق على حصة في جدول الدفعة.',
          when: when,
          payload: jsonEncode(<String, Object?>{
            'type': 'batch_schedule',
            'batchId': batchId,
            'draftId': item.draftId,
            'entryId': item.entry.id,
          }),
        );
        if (ok) scheduled++;
      }
    }

    return ScheduleReminderSyncResult(
      scheduled: scheduled,
      cancelled: cancelled,
      skipped: skipped,
      timeZoneMismatch: mismatch,
    );
  }
}
