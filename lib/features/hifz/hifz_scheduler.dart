/// Keeps the next hifz review reminder in step with the saved parts.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_service.dart';
import 'hifz_models.dart';
import 'hifz_providers.dart';

final hifzSchedulerProvider = Provider<HifzScheduler>(
  (ref) => HifzScheduler(ref),
);

/// Schedules one notification for the next review date (or cancels it when
/// reminders are off or nothing is scheduled).
class HifzScheduler {
  HifzScheduler(this._ref);

  final Ref _ref;
  Future<void> _chain = Future<void>.value();

  /// Serialises passes so two quick state changes cannot interleave cancels
  /// and schedules.
  Future<void> syncNow() {
    final next = _chain.then((_) => _sync());
    _chain = next.catchError((Object _) {});
    return next;
  }

  Future<void> _sync() async {
    final state = _ref.read(hifzProvider);
    final service = NotificationService.instance;
    await service.cancelHifzNotifications();
    if (!state.remindersEnabled || state.parts.isEmpty) return;
    if (!await service.areNotificationsEnabled()) return;

    final now = DateTime.now();
    final when = hifzReminderTime(
      dueDates: state.parts
          .map((part) => part.nextReviewAt)
          .whereType<DateTime>(),
      hour: state.reminderHour,
      minute: state.reminderMinute,
      now: now,
    );
    if (when == null) return;

    await service.ensureHifzChannels();
    final exact = await service.canScheduleExactNotifications();
    final due = state.dueCount(now);
    await service.scheduleHifzReminder(
      id: NotificationService.hifzNotificationId(0),
      title: 'مراجعة الحفظ',
      body: due > 0
          ? 'عندك $due أجزاء مستنية المراجعة النهارده.'
          : 'موعد مراجعة الجزء اللي حفظته.',
      when: when,
      preferExact: exact,
      payload: jsonEncode(<String, Object?>{'type': 'hifz'}),
    );
  }
}
