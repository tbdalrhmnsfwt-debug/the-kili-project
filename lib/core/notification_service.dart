/// Study reminders delivered by the operating system.
///
/// The original app schedules its reminders with `flutter_local_notifications`
/// and the `AlarmManager` receivers that package registers. This service keeps
/// the same contract: one repeating daily reminder, scheduled even when the
/// app is closed, and cancelled as soon as the user turns reminders off.
///
/// Every platform call is wrapped: when the plugin is unavailable (widget
/// tests, a stripped build, a denied permission) the app keeps working and the
/// callers simply receive `false`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Wrapper around the platform notification scheduler.
class NotificationService {
  NotificationService._();

  /// The single service instance used by the app.
  static final NotificationService instance = NotificationService._();

  /// The id of the repeating study reminder.
  static const int dailyReminderId = 1001;

  static const String _channelId = 'zaker_study_reminders';
  static const String _channelName = 'تذكير المذاكرة';
  static const String _channelDescription =
      'منبه يومي بيشجعك تبدأ جلسة مذاكرة قصيرة.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Prepares the plugin once per process.
  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    try {
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      debugPrint('notifications: initialization failed ($e)');
    }
  }

  /// Asks for the runtime notification permission (Android 13+, iOS).
  ///
  /// Returns `true` when notifications may be posted. On platforms that do not
  /// ask at runtime this returns `true` unless the call itself failed.
  Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return true;
    } catch (e) {
      debugPrint('notifications: permission request failed ($e)');
      return false;
    }
  }

  /// Schedules (or replaces) the daily reminder at [hour]:[minute] local time.
  ///
  /// The reminder repeats every day at the same wall-clock time. Returns
  /// whether the reminder could be scheduled.
  Future<bool> scheduleDaily({required int hour, required int minute}) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;
    await init();
    if (!_initialized) return false;
    if (!await requestPermission()) return false;

    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    try {
      await _plugin.cancel(dailyReminderId);
      await _plugin.zonedSchedule(
        dailyReminderId,
        'وقت المذاكرة 📚',
        'يلا نبدأ جلسة تركيز قصيرة — افتح ذاكرلي وكمّل هدف النهارده.',
        // `tz.local` defaults to UTC; converting the local DateTime keeps its
        // absolute instant, so the notification fires at the device's own
        // [hour]:[minute] without needing a timezone database.
        tz.TZDateTime.from(next, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      debugPrint('notifications: could not schedule the reminder ($e)');
      return false;
    }
  }

  /// Removes the repeating reminder.
  Future<void> cancelDaily() async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancel(dailyReminderId);
    } catch (e) {
      debugPrint('notifications: could not cancel the reminder ($e)');
    }
  }

  /// The reminders currently scheduled with the system, if the platform
  /// exposes them. Used by the settings sheet to show the real state.
  Future<bool> isDailyScheduled() async {
    await init();
    if (!_initialized) return false;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.any((p) => p.id == dailyReminderId);
    } catch (e) {
      debugPrint('notifications: could not read pending requests ($e)');
      return false;
    }
  }
}
