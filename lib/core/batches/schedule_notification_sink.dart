/// The platform implementation of the timetable reminder sink.
library;

import '../notification_service.dart';
import 'schedule_reminder_service.dart';

/// Routes reminder scheduling through [NotificationService], keeping every
/// platform call behind the service's already-safe wrappers.
class NotificationServiceScheduleSink implements ScheduleReminderSink {
  NotificationServiceScheduleSink(this._notifications);

  final NotificationService _notifications;

  @override
  Future<void> ensureChannel() => _notifications.ensureBatchScheduleChannel();

  @override
  Future<bool> requestPermission() => _notifications.requestPermission();

  @override
  Future<Set<int>> pendingIds() async {
    final ids = await _notifications.pendingNotificationIds();
    return ids.toSet();
  }

  @override
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) {
    return _notifications.scheduleBatchReminder(
      id: id,
      title: title,
      body: body,
      when: when,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _notifications.cancelNotification(id);
}
