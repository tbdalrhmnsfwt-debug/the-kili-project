import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_repository.dart';
import 'package:zaker_ai/core/batches/schedule_reminder_service.dart';
import 'package:zaker_ai/models/batch_schedule.dart';

class _FakeRepository implements BatchRepository {
  _FakeRepository(this.drafts);

  List<TimetableDraft> drafts;

  @override
  Future<List<TimetableDraft>> loadSchedules(
    String uid,
    String batchId,
  ) async =>
      [...drafts];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Scheduled {
  _Scheduled({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String payload;
}

class _FakeSink implements ScheduleReminderSink {
  _FakeSink({
    this.permission = true,
    Set<int>? pending,
  }) : pendingIds_ = {...?pending};

  final bool permission;
  final Set<int> pendingIds_;
  final List<_Scheduled> scheduled = [];
  final List<int> cancelled = [];
  bool channelReady = false;

  @override
  Future<void> ensureChannel() async {
    channelReady = true;
  }

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<Set<int>> pendingIds() async => {...pendingIds_};

  @override
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduled.add(
      _Scheduled(
          id: id, title: title, body: body, when: when, payload: payload),
    );
    pendingIds_.add(id);
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pendingIds_.remove(id);
  }
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  final now = DateTime(2026, 10, 24, 7);
  final marker = deviceTimeZoneMarker(now);

  TimetableEntry entry({
    String id = 'slot-1',
    int dayOfWeek = DateTime.saturday,
    int startMinutes = 8 * 60,
    int endMinutes = 9 * 60,
    String title = 'رياضيات',
    TimetableRecurrence recurrence = TimetableRecurrence.weekly,
    DateTime? anchor,
    String? timeZoneId,
    bool reminderEnabled = true,
  }) {
    return TimetableEntry(
      id: id,
      dayOfWeek: dayOfWeek,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      title: title,
      recurrence: recurrence,
      weekAnchorDate: anchor,
      timeZoneId: timeZoneId ?? marker,
      reminderEnabled: reminderEnabled,
    );
  }

  TimetableDraft draft({
    String id = 'schedule-1',
    TimetableDraftStatus status = TimetableDraftStatus.published,
    List<TimetableEntry>? entries,
  }) {
    return TimetableDraft(
      id: id,
      batchId: batchId,
      sourceImageFileName: 'schedules/$id.png',
      createdAt: now,
      updatedAt: now,
      status: status,
      entries: entries ?? [entry()],
    );
  }

  ({ScheduleReminderService service, _FakeSink sink}) build(
    List<TimetableDraft> drafts, {
    bool permission = true,
    Set<int>? pending,
  }) {
    final sink = _FakeSink(permission: permission, pending: pending);
    final service = ScheduleReminderService(
      repository: _FakeRepository(drafts),
      notifications: sink,
    );
    return (service: service, sink: sink);
  }

  test('a weekly class reserves the next four reminders ten minutes early',
      () async {
    final built = build([draft()]);
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.scheduled, 4);
    expect(result.skipped, 0);
    expect(built.sink.channelReady, isTrue);
    expect(built.sink.scheduled, hasLength(4));
    expect(
      [for (final item in built.sink.scheduled) item.when],
      [
        DateTime(2026, 10, 24, 7, 50),
        DateTime(2026, 10, 31, 7, 50),
        DateTime(2026, 11, 7, 7, 50),
        DateTime(2026, 11, 14, 7, 50),
      ],
    );
    expect(
      [for (final item in built.sink.scheduled) item.id],
      [9000, 9001, 9002, 9003],
    );

    final payload =
        jsonDecode(built.sink.scheduled.first.payload) as Map<String, dynamic>;
    expect(payload['type'], 'batch_schedule');
    expect(payload['batchId'], batchId);
    expect(payload['draftId'], 'schedule-1');
    expect(payload['entryId'], 'slot-1');
  });

  test('the notification never carries the class title or a private path',
      () async {
    final built = build([draft()]);
    await built.service.sync(uid: uid, batchId: batchId, now: now);

    for (final item in built.sink.scheduled) {
      expect(item.title, 'تذكير حصة');
      expect(item.body, isNot(contains('رياضيات')));
      expect(item.body, isNot(contains('schedules/')));
      expect(item.payload, isNot(contains('رياضيات')));
      expect(item.payload, isNot(contains('schedules/')));
    }
  });

  test('a reminder today that already passed moves a week, not a day',
      () async {
    final later = DateTime(2026, 10, 24, 9);
    final built = build([draft()]);
    await built.service.sync(uid: uid, batchId: batchId, now: later);

    expect(
      built.sink.scheduled.first.when,
      DateTime(2026, 10, 31, 7, 50),
    );
  });

  test('a row without a saved timezone basis is skipped, not guessed',
      () async {
    final built = build([
      draft(entries: [entry(timeZoneId: '')]),
    ]);
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.scheduled, 0);
    expect(result.skipped, 1);
    expect(result.timeZoneMismatch, 0);
    expect(built.sink.scheduled, isEmpty);
    expect(built.sink.channelReady, isFalse);
  });

  test('a changed device timezone cancels stale reminders and asks for review',
      () async {
    final built = build(
      [
        draft(entries: [entry(timeZoneId: 'device:Old:120')])
      ],
      pending: {1001, 9100},
    );
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.timeZoneMismatch, 1);
    expect(result.scheduled, 0);
    expect(result.skipped, 1);
    expect(built.sink.cancelled, [9100]);
    expect(built.sink.pendingIds_, {1001});
    expect(built.sink.scheduled, isEmpty);
  });

  test('turning a reminder off removes its queued notifications', () async {
    final built = build(
      [
        draft(entries: [entry(reminderEnabled: false)])
      ],
      pending: {9000, 9001},
    );
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.cancelled, 2);
    expect(result.scheduled, 0);
    expect(built.sink.cancelled, [9000, 9001]);
    expect(built.sink.scheduled, isEmpty);
  });

  test('drafts never schedule, even when a row asks for a reminder', () async {
    final built = build([
      draft(status: TimetableDraftStatus.draft),
    ]);
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.scheduled, 0);
    expect(result.skipped, 0);
    expect(built.sink.scheduled, isEmpty);
  });

  test('a one-off class in the past is not moved to a made-up date', () async {
    final built = build([
      draft(
        entries: [
          entry(
            recurrence: TimetableRecurrence.none,
            anchor: DateTime(2026, 10, 20),
          ),
        ],
      ),
    ]);
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.scheduled, 0);
    expect(result.skipped, 1);
    expect(built.sink.scheduled, isEmpty);
  });

  test('a future one-off class schedules exactly once', () async {
    final built = build([
      draft(
        entries: [
          entry(
            recurrence: TimetableRecurrence.none,
            anchor: DateTime(2026, 10, 27),
          ),
        ],
      ),
    ]);
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.scheduled, 1);
    expect(built.sink.scheduled.single.when, DateTime(2026, 10, 27, 7, 50));
  });

  test('an unfinished row is skipped without a reminder', () async {
    final built = build([
      draft(entries: [entry(endMinutes: 8 * 60)]),
    ]);
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.scheduled, 0);
    expect(result.skipped, 1);
    expect(built.sink.scheduled, isEmpty);
  });

  test('refused notifications schedule nothing and report it honestly',
      () async {
    final built = build(
      [draft()],
      permission: false,
      pending: {9000},
    );
    final result =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(result.permissionDenied, isTrue);
    expect(result.cancelled, 1);
    expect(result.scheduled, 0);
    expect(built.sink.channelReady, isFalse);
    expect(built.sink.scheduled, isEmpty);
  });

  test('a resync replaces the whole window instead of stacking alarms',
      () async {
    final built = build([draft()], pending: {9000, 9001, 9002, 9003});
    await built.service.sync(uid: uid, batchId: batchId, now: now);
    final second =
        await built.service.sync(uid: uid, batchId: batchId, now: now);

    expect(second.cancelled, 4);
    expect(second.scheduled, 4);
    expect(
      built.sink.cancelled,
      [9000, 9001, 9002, 9003, 9000, 9001, 9002, 9003],
    );
    expect(built.sink.scheduled, hasLength(8));
    expect(
      [for (final item in built.sink.scheduled.skip(4)) item.id],
      [9000, 9001, 9002, 9003],
    );
  });
}
