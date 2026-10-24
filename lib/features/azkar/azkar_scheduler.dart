/// Schedules the salat reminders, morning/evening azkar and Friday Kahf
/// reminder with the operating system.
///
/// The approach mirrors the adhan scheduler: a rolling window of exact alarms,
/// a fallback to inexact alarms when Android refuses them, a boot receiver
/// already declared by the app, and a rebuild on start, resume, midnight and
/// any settings/location change.
library;

import 'dart:async';
import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_service.dart';
import '../../core/prayer_methods.dart';
import '../prayer/prayer_providers.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';

/// How many days of morning/evening azkar and Kahf reminders are kept.
const int kAzkarHorizonDays = 8;

/// How many days of salat reminders are kept.  Three days at a 15-minute
/// interval is already a large number of alarms, so this window is shorter
/// than the adhan window.
const int kSalatHorizonDays = 3;

/// The scheduler used by the lifecycle host and the settings screen.
final azkarSchedulerProvider = Provider<AzkarScheduler>((ref) {
  return AzkarScheduler(ref);
});

/// What one scheduling pass did.
@immutable
class AzkarScheduleResult {
  const AzkarScheduleResult({
    this.enabled = true,
    this.hadLocation = true,
    this.notificationsAllowed = true,
    this.exact = true,
    this.salat = 0,
    this.azkar = 0,
    this.kahf = 0,
    this.failed = 0,
  });

  /// False when every feature switch is off (everything was cancelled).
  final bool enabled;

  /// False when a location-based reminder was enabled but no location exists.
  final bool hadLocation;

  /// False when Android blocks notifications for the app.
  final bool notificationsAllowed;

  /// False when at least one alarm had to be scheduled inexactly.
  final bool exact;

  final int salat;
  final int azkar;
  final int kahf;
  final int failed;

  int get total => salat + azkar + kahf;
}

class AzkarScheduler {
  AzkarScheduler(this._ref);

  final Ref _ref;

  /// Serialises passes so quick setting changes cannot interleave.
  Future<void> _chain = Future<void>.value();

  /// Cancels and rebuilds all azkar, salat and Kahf schedules.
  Future<AzkarScheduleResult> syncNow() {
    final completer = Completer<AzkarScheduleResult>();
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

  Future<AzkarScheduleResult> _sync() async {
    final settings = _ref.read(azkarSettingsProvider);
    final location = _ref.read(prayerLocationProvider);
    final prayerSettings = _ref.read(prayerSettingsProvider);

    await NotificationService.instance.cancelAzkarNotifications();

    if (!settings.isAnyEnabled) {
      return const AzkarScheduleResult(enabled: false);
    }
    if (!await NotificationService.instance.areNotificationsEnabled()) {
      return const AzkarScheduleResult(notificationsAllowed: false);
    }

    await NotificationService.instance.ensureAzkarChannels();
    await NotificationService.instance.ensureSalatChannels();

    final now = DateTime.now();
    var useExact = await NotificationService.instance
        .canScheduleExactNotifications();
    var salat = 0;
    var azkar = 0;
    var kahf = 0;
    var failed = 0;

    void count(AdhanScheduleOutcome outcome, void Function() onScheduled) {
      switch (outcome) {
        case AdhanScheduleOutcome.exact:
          onScheduled();
        case AdhanScheduleOutcome.inexact:
          onScheduled();
          useExact = false;
        case AdhanScheduleOutcome.failed:
          failed++;
      }
    }

    // Only the morning/evening anchors and the Fajr-to-Isha salat window need
    // computed prayer times.  Daytime, all-day and custom salat windows can be
    // scheduled even before the user picks a location.
    final needsPrayerTimes =
        settings.morningEnabled ||
        settings.eveningEnabled ||
        (settings.salatEnabled &&
            settings.salatWindow == SalatWindow.fajrToIsha);
    final hasLocation = location != null;

    for (var dayOffset = 0; dayOffset < kAzkarHorizonDays; dayOffset++) {
      // Calendar-field construction keeps local midnight correct across
      // daylight-saving changes.
      final date = DateTime(now.year, now.month, now.day + dayOffset);
      PrayerTimes? times;
      if (location != null && needsPrayerTimes) {
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
          debugPrint('azkar: could not compute $date ($error)');
        }
      }

      // Morning and evening azkar.
      if (times != null) {
        for (final period in AzkarPeriod.values) {
          final enabled = period == AzkarPeriod.morning
              ? settings.morningEnabled
              : settings.eveningEnabled;
          if (!enabled) continue;
          final offset = period == AzkarPeriod.morning
              ? settings.morningOffsetMinutes
              : settings.eveningOffsetMinutes;
          final anchor = period == AzkarPeriod.morning
              ? times.fajr.toLocal()
              : times.asr.toLocal();
          final when = anchor.add(Duration(minutes: offset));
          if (!when.isAfter(now.add(const Duration(seconds: 5)))) continue;

          final id = NotificationService.azkarNotificationId(
            dayOffset,
            period.index,
          );
          final outcome = await NotificationService.instance
              .scheduleAzkarReminder(
                id: id,
                title: period.title,
                body: 'وقت ${period.label} — افتح واقرأ وعدّ.',
                when: when,
                preferExact: useExact,
                payload: jsonEncode(<String, Object?>{
                  'type': 'azkar',
                  'period': period.wireName,
                  'id': id,
                  'time': when.toIso8601String(),
                }),
              );
          count(outcome, () => azkar++);
        }
      }

      // Salat reminders.
      if (settings.salatEnabled && dayOffset < kSalatHorizonDays) {
        final phrases = settings.selectedPhrases;
        final window = _salatWindow(settings, times);
        if (phrases.isNotEmpty && window != null) {
          final dayStart = DateTime(date.year, date.month, date.day);
          var slot = 0;
          var minute = window.start;
          while (minute < window.end && slot < 200) {
            final when = dayStart.add(Duration(minutes: minute));
            if (when.isAfter(now.add(const Duration(seconds: 5)))) {
              final phrase = phrases[slot % phrases.length];
              final id = NotificationService.salatNotificationId(
                dayOffset,
                slot,
              );
              final outcome = await NotificationService.instance
                  .scheduleSalatReminder(
                    id: id,
                    title: 'الصلاة على النبي ﷺ',
                    body: phrase.text,
                    when: when,
                    phrase: phrase,
                    sound: settings.soundFor(phrase.id),
                    vibration: settings.salatVibration,
                    preferExact: useExact,
                    payload: jsonEncode(<String, Object?>{
                      'type': 'salat',
                      'phrase': phrase.id,
                      'id': id,
                      'time': when.toIso8601String(),
                    }),
                  );
              count(outcome, () => salat++);
            }
            slot++;
            minute += settings.salatIntervalMinutes;
          }
        }
      }

      // Friday Surat Al-Kahf.
      if (settings.kahfEnabled && date.weekday == DateTime.friday) {
        final when = DateTime(
          date.year,
          date.month,
          date.day,
          settings.kahfHour,
          settings.kahfMinute,
        );
        if (when.isAfter(now.add(const Duration(seconds: 5)))) {
          final id = NotificationService.kahfNotificationId(dayOffset);
          final outcome = await NotificationService.instance
              .scheduleKahfReminder(
                id: id,
                title: 'سورة الكهف',
                body: 'النهارده الجمعة — ما تنساش تقرا سورة الكهف.',
                when: when,
                preferExact: useExact,
                payload: jsonEncode(<String, Object?>{
                  'type': 'kahf',
                  'id': id,
                  'time': when.toIso8601String(),
                }),
              );
          count(outcome, () => kahf++);
        }
      }
    }

    debugPrint(
      'azkar: scheduled $salat salat, $azkar azkar and $kahf kahf reminders '
      '($failed failed, ${useExact ? 'exact' : 'inexact'})',
    );
    return AzkarScheduleResult(
      hadLocation: !needsPrayerTimes || hasLocation,
      exact: useExact,
      salat: salat,
      azkar: azkar,
      kahf: kahf,
      failed: failed,
    );
  }

  /// The start/end minute range for salat reminders on one day.
  ///
  /// The end is exclusive.  A custom range whose end is not after its start
  /// wraps past midnight (equal values mean a 24-hour window).
  ({int start, int end})? _salatWindow(
    AzkarSettings settings,
    PrayerTimes? times,
  ) {
    switch (settings.salatWindow) {
      case SalatWindow.daytime:
        return (start: 8 * 60, end: 20 * 60);
      case SalatWindow.allDay:
        return (start: 0, end: 24 * 60);
      case SalatWindow.fajrToIsha:
        if (times == null) return null;
        final fajr = times.fajr.toLocal();
        final isha = times.isha.toLocal();
        final start = fajr.hour * 60 + fajr.minute;
        final end = isha.hour * 60 + isha.minute;
        if (end <= start) return null;
        return (start: start, end: end);
      case SalatWindow.custom:
        final start = settings.salatStartMinutes;
        var end = settings.salatEndMinutes;
        if (end <= start) end += 24 * 60;
        return (start: start, end: end);
    }
  }
}
