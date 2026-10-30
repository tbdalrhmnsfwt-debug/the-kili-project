/// Schedules the adhan notifications with the operating system.
///
/// A rolling window of [kAdhanHorizonDays] days is kept scheduled, so the
/// phone keeps receiving the adhan even if the app is not opened for a few
/// days.  The window is rebuilt:
///   * on every app start and resume,
///   * at every local midnight while the app is open,
///   * after a location, calculation or notification-settings change.
///
/// The times themselves are still computed on-device by `adhan_dart`; nothing
/// here needs a network connection.
library;

import 'dart:async';
import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adhan_voices.dart';
import '../../core/notification_service.dart';
import '../../core/prayer_methods.dart';
import '../../core/prayer_status_bar.dart';
import 'adhan_providers.dart';
import 'prayer_models.dart';
import 'prayer_providers.dart';
import 'prayer_status_schedule.dart';

/// How many days ahead the scheduler keeps alarms.  Eight days covers a week
/// away from the app plus one day of overlap.
const int kAdhanHorizonDays = 8;

/// The scheduler used by the UI and the lifecycle host.
final prayerAdhanSchedulerProvider = Provider<PrayerAdhanScheduler>((ref) {
  return PrayerAdhanScheduler(ref);
});

/// What one scheduling pass did, used for the in-app confirmation.
@immutable
class AdhanScheduleResult {
  const AdhanScheduleResult({
    this.enabled = true,
    this.hadLocation = true,
    this.notificationsAllowed = true,
    this.exact = true,
    this.scheduled = 0,
    this.reminders = 0,
    this.failed = 0,
  });

  /// False when the master switch is off (everything was cancelled).
  final bool enabled;

  /// False when no location has been chosen yet.
  final bool hadLocation;

  /// False when Android blocks notifications for the app.
  final bool notificationsAllowed;

  /// False when at least one alarm had to be scheduled inexactly.
  final bool exact;

  final int scheduled;
  final int reminders;
  final int failed;

  int get total => scheduled + reminders;
}

class PrayerAdhanScheduler {
  PrayerAdhanScheduler(this._ref);

  final Ref _ref;

  /// Serialises passes so two quick setting changes cannot interleave their
  /// cancel/schedule calls.
  Future<void> _chain = Future<void>.value();

  /// Cancels and rebuilds the whole rolling window.
  Future<AdhanScheduleResult> syncNow() {
    final completer = Completer<AdhanScheduleResult>();
    _chain = _chain.then((_) async {
      try {
        final result = await _sync();
        if (!completer.isCompleted) completer.complete(result);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    return completer.future;
  }

  Future<AdhanScheduleResult> _sync() async {
    final settings = _ref.read(adhanSettingsProvider);
    final location = _ref.read(prayerLocationProvider);
    final prayerSettings = _ref.read(prayerSettingsProvider);

    await NotificationService.instance.cancelPrayerNotifications();

    final notificationsAllowed =
        await NotificationService.instance.areNotificationsEnabled();
    final showStatusBar = shouldShowPrayerStatusBar(
      adhanEnabled: settings.enabled,
      statusBarEnabled: settings.statusBarEnabled,
      hasLocation: location != null,
      notificationsAllowed: notificationsAllowed,
    );
    if (!showStatusBar) {
      await PrayerStatusBar.instance.cancel();
    }

    if (!settings.enabled) {
      return const AdhanScheduleResult(enabled: false);
    }
    if (location == null) {
      return const AdhanScheduleResult(hadLocation: false);
    }
    if (!notificationsAllowed) {
      return const AdhanScheduleResult(notificationsAllowed: false);
    }

    await NotificationService.instance.ensureAdhanChannels();

    final now = DateTime.now();
    var useExact =
        await NotificationService.instance.canScheduleExactNotifications();
    var scheduled = 0;
    var reminders = 0;
    var failed = 0;
    // The successfully computed days feed the status bar's boundary list.
    final days = <PrayerTimes>[];

    for (var dayOffset = 0; dayOffset < kAdhanHorizonDays; dayOffset++) {
      // Constructing from the calendar fields (instead of adding 24h) keeps
      // local midnight correct across daylight-saving changes.
      final date = DateTime(now.year, now.month, now.day + dayOffset);
      final PrayerTimes times;
      try {
        times = PrayerTimes(
          date: date,
          coordinates: Coordinates(location.latitude, location.longitude),
          calculationParameters: prayerParameters(
            methodId: prayerSettings.methodId,
            madhabId: prayerSettings.madhabId,
          ),
        );
      } catch (error) {
        debugPrint('adhan: could not compute $date ($error)');
        continue;
      }

      days.add(times);

      for (final prayer in PrayerName.values) {
        if (!settings.isPrayerEnabled(prayer)) continue;
        final prayerTime = _timeFor(times, prayer).toLocal();
        final voice = adhanVoiceById(settings.voiceIdFor(prayer));

        if (prayerTime.isAfter(now.add(const Duration(seconds: 5)))) {
          final id = NotificationService.adhanNotificationId(
            dayOffset,
            prayer.index,
            voiceSlot: NotificationService.adhanVoiceSlot(voice.id),
          );
          final outcome =
              await NotificationService.instance.schedulePrayerAdhan(
            id: id,
            title: 'حان وقت ${prayer.invocation}',
            body: _adhanBody(prayer),
            when: prayerTime,
            voice: voice,
            preferExact: useExact,
            payload: _adhanPayload(
              id: id,
              prayer: prayer,
              when: prayerTime,
              location: location,
              voice: voice,
            ),
          );
          switch (outcome) {
            case AdhanScheduleOutcome.exact:
              scheduled++;
            case AdhanScheduleOutcome.inexact:
              scheduled++;
              useExact = false;
            case AdhanScheduleOutcome.failed:
              failed++;
          }
        }

        if (settings.remindersEnabled) {
          final remindAt = prayerTime.subtract(
            Duration(minutes: settings.reminderMinutes),
          );
          if (remindAt.isAfter(now.add(const Duration(seconds: 5)))) {
            final outcome =
                await NotificationService.instance.schedulePrayerReminder(
              id: NotificationService.prayerReminderNotificationId(
                dayOffset,
                prayer.index,
              ),
              title: 'قبل ${prayer.invocation}',
              body: 'فاضل ${settings.reminderMinutes} دقيقة على '
                  '${prayer.invocation}. استعد للصلاة.',
              when: remindAt,
              preferExact: useExact,
            );
            switch (outcome) {
              case AdhanScheduleOutcome.exact:
                reminders++;
              case AdhanScheduleOutcome.inexact:
                reminders++;
                useExact = false;
              case AdhanScheduleOutcome.failed:
                failed++;
            }
          }
        }
      }
    }

    if (showStatusBar) {
      final boundaries = buildPrayerStatusBoundaries(days: days, now: now);
      if (boundaries.isEmpty) {
        await PrayerStatusBar.instance.cancel();
      } else {
        await PrayerStatusBar.instance.sync(
          city: location.displayName,
          boundaries: boundaries,
        );
      }
    }

    debugPrint(
      'adhan: scheduled $scheduled adhans and $reminders reminders '
      '($failed failed, ${useExact ? 'exact' : 'inexact'})',
    );
    return AdhanScheduleResult(
      exact: useExact,
      scheduled: scheduled,
      reminders: reminders,
      failed: failed,
    );
  }

  DateTime _timeFor(PrayerTimes times, PrayerName prayer) {
    return switch (prayer) {
      PrayerName.fajr => times.fajr,
      PrayerName.dhuhr => times.dhuhr,
      PrayerName.asr => times.asr,
      PrayerName.maghrib => times.maghrib,
      PrayerName.isha => times.isha,
    };
  }

  String _adhanBody(PrayerName prayer) {
    if (prayer == PrayerName.fajr) {
      return 'حان الآن وقت صلاة الفجر. الصلاة خير من النوم.';
    }
    return 'حان الآن وقت ${prayer.invocation}. تقبل الله.';
  }

  /// The JSON payload travels with the notification, so the full-screen
  /// player knows which prayer, recording, time and city to show even after
  /// the app process was killed.
  String _adhanPayload({
    required int id,
    required PrayerName prayer,
    required DateTime when,
    required PrayerLocation location,
    required AdhanVoice voice,
  }) {
    return jsonEncode(<String, Object?>{
      'type': 'adhan',
      'id': id,
      'prayer': prayer.name,
      'voice': voice.id,
      'time': when.toIso8601String(),
      'city': location.displayName,
    });
  }
}
