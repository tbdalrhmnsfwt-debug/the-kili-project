/// The prayer boundaries the system prayer bar re-targets at.
///
/// Pure data and pure functions: no plugin, no clock, no storage. The scheduler
/// builds the list once per pass and hands it to `PrayerStatusBar`; the native
/// bridge only stores it and re-posts the notification at each boundary.
library;

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';

import 'prayer_models.dart';

/// How much lead time a boundary needs before the bar may target it. A target
/// this close would be a countdown to the past by the time the OS renders it.
const Duration kPrayerStatusLead = Duration(seconds: 5);

/// One prayer instant the bar can count down to.
@immutable
class PrayerStatusBoundary {
  const PrayerStatusBoundary({
    required this.at,
    required this.name,
    required this.hour,
    required this.minute,
  });

  /// The absolute instant (local zone); the native side uses its epoch.
  final DateTime at;

  /// The Arabic prayer label, e.g. «العصر».
  final String name;

  /// The local 24-hour clock fields, formatted by the native side so a
  /// timezone change does not need a second prayer calculation.
  final int hour;
  final int minute;

  Map<String, Object?> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'name': name,
        'hour': hour,
        'minute': minute,
      };
}

/// Every prayer in [days] that is still ahead of [now], sorted ascending.
///
/// Boundaries inside [lead] are dropped: by the time the notification is
/// rendered they would already be in the past.
List<PrayerStatusBoundary> buildPrayerStatusBoundaries({
  required Iterable<PrayerTimes> days,
  required DateTime now,
  Duration lead = kPrayerStatusLead,
}) {
  final cutoff = now.add(lead);
  final boundaries = <PrayerStatusBoundary>[];
  for (final times in days) {
    final moments = <PrayerName, DateTime>{
      PrayerName.fajr: times.fajr,
      PrayerName.dhuhr: times.dhuhr,
      PrayerName.asr: times.asr,
      PrayerName.maghrib: times.maghrib,
      PrayerName.isha: times.isha,
    };
    for (final entry in moments.entries) {
      final local = entry.value.toLocal();
      if (!local.isAfter(cutoff)) continue;
      boundaries.add(
        PrayerStatusBoundary(
          at: local,
          name: entry.key.label,
          hour: local.hour,
          minute: local.minute,
        ),
      );
    }
  }
  boundaries.sort((a, b) => a.at.compareTo(b.at));
  return List<PrayerStatusBoundary>.unmodifiable(boundaries);
}

/// Whether the ongoing bar should be shown at all.
bool shouldShowPrayerStatusBar({
  required bool adhanEnabled,
  required bool statusBarEnabled,
  required bool hasLocation,
  required bool notificationsAllowed,
}) =>
    adhanEnabled && statusBarEnabled && hasLocation && notificationsAllowed;
