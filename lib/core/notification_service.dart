/// Reminders and prayer notifications delivered by the operating system.
///
/// The original app schedules its reminders with `flutter_local_notifications`
/// and the `AlarmManager` receivers that package registers. This service keeps
/// the same contract for study reminders: one repeating daily reminder,
/// scheduled even when the app is closed, and cancelled as soon as the user
/// turns reminders off.  It also schedules the adhan: one notification per
/// prayer per day, each through the notification channel of the chosen
/// recording, plus an optional reminder ahead of the adhan.
///
/// Every platform call is wrapped: when the plugin is unavailable (widget
/// tests, a stripped build, a denied permission) the app keeps working and the
/// callers simply receive `false`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'adhan_voices.dart';

/// How a prayer notification ended up being scheduled.
enum AdhanScheduleOutcome {
  /// Scheduled with `exactAllowWhileIdle`.
  exact,

  /// Scheduled with `inexactAllowWhileIdle`, because Android did not allow an
  /// exact alarm.  It still fires, but the system may delay it.
  inexact,

  /// The platform call failed; nothing was scheduled.
  failed,
}

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

  // ---------------------------------------------------------- adhan channels

  static const String _prayerReminderChannelId = 'zaker_prayer_reminders';
  static const String _prayerReminderChannelName = 'تنبيهات الصلاة';
  static const String _prayerReminderChannelDescription =
      'تنبيه بييجي قبل الأذان بدقايق، بصوت إشعار عادي.';

  static const int _adhanIdBase = 4000;
  static const int _reminderIdBase = 5000;

  /// The id of the immediately-posted test adhan.
  static const int adhanTestId = 3999;

  /// A stable id for one prayer on one of the next days.  Separating the days
  /// lets the app keep a rolling window of exact alarms scheduled.
  static int adhanNotificationId(int dayOffset, int prayerIndex) =>
      _adhanIdBase + dayOffset * 10 + prayerIndex;

  /// A stable id for the reminder that precedes one prayer.
  static int prayerReminderNotificationId(int dayOffset, int prayerIndex) =>
      _reminderIdBase + dayOffset * 10 + prayerIndex;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Creates one channel per bundled voice plus the reminder channel.
  ///
  /// A channel's sound is immutable after creation, so every voice needs its
  /// own channel and choosing a voice means choosing a channel.  Calling this
  /// repeatedly is harmless: Android ignores an identical channel.
  Future<void> ensureAdhanChannels() async {
    await init();
    if (!_initialized) return;
    final android = _android;
    if (android == null) return;
    try {
      await android.createNotificationChannelGroup(
        const AndroidNotificationChannelGroup(
          'zaker_adhan',
          'أذان الصلاة',
          description: 'أصوات الأذان المرفقة مع التطبيق، من غير إنترنت.',
        ),
      );
      for (final voice in kAdhanVoices) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            voice.channelId,
            'أذان — ${voice.title}',
            description: 'صوت الأذان: ${voice.title}',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(voice.resource),
            enableVibration: true,
            showBadge: false,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
      }
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _prayerReminderChannelId,
          _prayerReminderChannelName,
          description: _prayerReminderChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: false,
        ),
      );
    } catch (e) {
      debugPrint('notifications: could not create adhan channels ($e)');
    }
  }

  /// Whether the user allows notifications at all.  This does not prompt.
  Future<bool> areNotificationsEnabled() async {
    await init();
    if (!_initialized) return false;
    try {
      final android = _android;
      if (android == null) return true;
      return await android.areNotificationsEnabled() ?? false;
    } catch (e) {
      debugPrint('notifications: could not read the permission ($e)');
      return false;
    }
  }

  /// Whether Android will accept `exactAllowWhileIdle` alarms.
  Future<bool> canScheduleExactNotifications() async {
    await init();
    if (!_initialized) return false;
    try {
      final android = _android;
      if (android == null) return true;
      return await android.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('notifications: could not read the exact-alarm state ($e)');
      return false;
    }
  }

  /// Opens the system screen where the user can grant exact alarms.
  Future<bool> requestExactAlarmsPermission() async {
    await init();
    if (!_initialized) return false;
    try {
      return await _android?.requestExactAlarmsPermission() ?? false;
    } catch (e) {
      debugPrint('notifications: exact-alarm request failed ($e)');
      return false;
    }
  }

  /// Cancels every adhan and prayer reminder, leaving study/task reminders
  /// untouched.
  Future<void> cancelPrayerNotifications() async {
    await init();
    if (!_initialized) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final id = request.id;
        if (id == adhanTestId ||
            (id >= _adhanIdBase && id < _adhanIdBase + 1000) ||
            (id >= _reminderIdBase && id < _reminderIdBase + 1000)) {
          await _plugin.cancel(id);
        }
      }
    } catch (e) {
      debugPrint('notifications: could not cancel prayer schedules ($e)');
    }
  }

  /// Schedules one adhan notification, falling back to an inexact alarm when
  /// Android refuses the exact one.
  Future<AdhanScheduleOutcome> schedulePrayerAdhan({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required AdhanVoice voice,
    required bool preferExact,
  }) {
    return _schedulePrayer(
      id: id,
      title: title,
      body: body,
      when: when,
      preferExact: preferExact,
      details: _adhanDetails(voice, body),
    );
  }

  /// Schedules the optional "N minutes before" reminder.
  Future<AdhanScheduleOutcome> schedulePrayerReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required bool preferExact,
  }) {
    return _schedulePrayer(
      id: id,
      title: title,
      body: body,
      when: when,
      preferExact: preferExact,
      details: _reminderDetails(body),
    );
  }

  Future<AdhanScheduleOutcome> _schedulePrayer({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required bool preferExact,
    required AndroidNotificationDetails details,
  }) async {
    await init();
    if (!_initialized) return AdhanScheduleOutcome.failed;

    Future<void> schedule(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        NotificationDetails(
          android: details,
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'prayer',
      );
    }

    try {
      await schedule(
        preferExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return preferExact
          ? AdhanScheduleOutcome.exact
          : AdhanScheduleOutcome.inexact;
    } on PlatformException catch (error) {
      if (preferExact && error.code == 'exact_alarms_not_permitted') {
        try {
          await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
          return AdhanScheduleOutcome.inexact;
        } catch (fallbackError) {
          debugPrint('notifications: inexact fallback failed ($fallbackError)');
          return AdhanScheduleOutcome.failed;
        }
      }
      debugPrint(
        'notifications: could not schedule prayer notification ($error)',
      );
      return AdhanScheduleOutcome.failed;
    } catch (e) {
      debugPrint('notifications: could not schedule prayer notification ($e)');
      return AdhanScheduleOutcome.failed;
    }
  }

  /// Posts an adhan right now, with [voice]'s channel, for testing.
  Future<bool> showTestAdhan(
    AdhanVoice voice, {
    String title = 'اختبار الأذان',
    String body = 'كده شكل إشعار الأذان — الصوت شغال من غير إنترنت.',
  }) async {
    await init();
    if (!_initialized) return false;
    try {
      await ensureAdhanChannels();
      await _plugin.show(
        adhanTestId,
        title,
        body,
        NotificationDetails(
          android: _adhanDetails(voice, body),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'prayer',
      );
      return true;
    } catch (e) {
      debugPrint('notifications: could not show the test adhan ($e)');
      return false;
    }
  }

  AndroidNotificationDetails _adhanDetails(AdhanVoice voice, String body) {
    return AndroidNotificationDetails(
      voice.channelId,
      'أذان — ${voice.title}',
      channelDescription: 'صوت الأذان: ${voice.title}',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(voice.resource),
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      channelShowBadge: false,
      styleInformation: BigTextStyleInformation(body),
    );
  }

  AndroidNotificationDetails _reminderDetails(String body) {
    return AndroidNotificationDetails(
      _prayerReminderChannelId,
      _prayerReminderChannelName,
      channelDescription: _prayerReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      channelShowBadge: false,
      styleInformation: BigTextStyleInformation(body),
    );
  }

  /// Called with the notification payload when the user taps a notification.
  ///
  /// The app sets this in `main` to route task reminders to the task list.
  void Function(String? payload)? onTap;

  /// Prepares the plugin once per process.
  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) =>
            onTap?.call(response.payload),
      );
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
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
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
        payload: 'tasks',
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

  /// The first notification id reserved for per-task reminders.
  static const int _taskReminderBaseId = 2000;

  /// The notification id for a task, stable across app launches.
  static int taskReminderId(String taskId) =>
      _taskReminderBaseId + (taskId.hashCode & 0x7fffffff) % 100000;

  /// Schedules a one-shot reminder for a task at [when].
  ///
  /// Returns `false` when the time is in the past, notifications are not
  /// permitted, or the platform scheduler fails — the task itself is always
  /// kept either way.
  Future<bool> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime when,
    String? notes,
  }) async {
    if (!when.isAfter(DateTime.now())) return false;
    await init();
    if (!_initialized) return false;
    if (!await requestPermission()) return false;

    final body = (notes == null || notes.trim().isEmpty)
        ? 'مهمتك مستنياك — افتح ذاكرلي وخلصها.'
        : notes.trim();
    try {
      final id = taskReminderId(taskId);
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        'تذكير: $title',
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'tasks',
      );
      return true;
    } catch (e) {
      debugPrint('notifications: could not schedule the task reminder ($e)');
      return false;
    }
  }

  /// Removes a task's scheduled reminder (if one exists).
  Future<void> cancelTaskReminder(String taskId) async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancel(taskReminderId(taskId));
    } catch (e) {
      debugPrint('notifications: could not cancel the task reminder ($e)');
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
