/// Data model for the prayer feature: the saved location, the user's
/// calculation settings, and one day of prayer times with its live state.
library;

import 'package:adhan_dart/adhan_dart.dart';

/// A location used for prayer calculations.
///
/// [city] and [region] are display labels only; the coordinates are what the
/// astronomical calculation uses.  A GPS location keeps [fromGps] so the app
/// can refresh it when the user travels more than 10 km.
class PrayerLocation {
  const PrayerLocation({
    required this.latitude,
    required this.longitude,
    this.city = '',
    this.region = '',
    this.fromGps = false,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String region;
  final bool fromGps;

  /// The city name if known, otherwise the coordinates (the documented
  /// fallback when reverse geocoding is unavailable).
  String get displayName {
    final name = city.trim();
    return name.isEmpty ? coordinatesText : name;
  }

  /// The governorate for a chosen city, or the coordinates for a manual
  /// location.  The sheet shows this under [displayName].
  String get subtitle {
    final area = region.trim();
    final name = city.trim();
    if (name.isEmpty) return '';
    if (area.isNotEmpty && area != name) return area;
    return coordinatesText;
  }

  /// «30.0444، 31.2357».
  String get coordinatesText =>
      '${latitude.toStringAsFixed(4)}، ${longitude.toStringAsFixed(4)}';

  /// «من GPS» / «مختار يدويًا».
  String get sourceLabel => fromGps ? 'من GPS' : 'مختار يدويًا';

  PrayerLocation copyWith({
    double? latitude,
    double? longitude,
    String? city,
    String? region,
    bool? fromGps,
  }) {
    return PrayerLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      region: region ?? this.region,
      fromGps: fromGps ?? this.fromGps,
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'city': city,
    'region': region,
    'gps': fromGps,
  };

  /// Reads a stored location; returns `null` for missing or malformed data.
  static PrayerLocation? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = json['lat'];
    final lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    final latitude = lat.toDouble();
    final longitude = lng.toDouble();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return PrayerLocation(
      latitude: latitude,
      longitude: longitude,
      city: json['city'] is String ? json['city'] as String : '',
      region: json['region'] is String ? json['region'] as String : '',
      fromGps: json['gps'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerLocation &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.city == city &&
      other.region == region &&
      other.fromGps == fromGps;

  @override
  int get hashCode => Object.hash(latitude, longitude, city, region, fromGps);

  @override
  String toString() => '$displayName ($coordinatesText)';
}

/// The five obligatory prayers, in order.
enum PrayerName { fajr, dhuhr, asr, maghrib, isha }

extension PrayerNameInfo on PrayerName {
  /// «الفجر» — the short label used on cards.
  String get label => switch (this) {
    PrayerName.fajr => 'الفجر',
    PrayerName.dhuhr => 'الظهر',
    PrayerName.asr => 'العصر',
    PrayerName.maghrib => 'المغرب',
    PrayerName.isha => 'العشاء',
  };

  /// «صلاة الفجر» — the longer label used in the list.
  String get invocation => switch (this) {
    PrayerName.fajr => 'صلاة الفجر',
    PrayerName.dhuhr => 'صلاة الظهر',
    PrayerName.asr => 'صلاة العصر',
    PrayerName.maghrib => 'صلاة المغرب',
    PrayerName.isha => 'صلاة العشاء',
  };
}

/// Where a prayer sits relative to the current moment.
enum PrayerPhase { passed, next, upcoming }

/// One prayer on one day.
class PrayerMoment {
  const PrayerMoment({
    required this.name,
    required this.time,
    this.tomorrow = false,
  });

  final PrayerName name;
  final DateTime time;

  /// True only for tomorrow's Fajr, shown after Isha.
  final bool tomorrow;
}

/// The state of one day's five prayers at a given moment.
class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.now,
    required this.prayers,
    required this.next,
    required this.previousTime,
    required this.location,
  });

  /// The calendar day the times belong to (local midnight).
  final DateTime date;

  /// The moment this snapshot was built for.
  final DateTime now;

  /// Fajr … Isha, always five entries.
  final List<PrayerMoment> prayers;

  /// The upcoming prayer. After Isha this is tomorrow's Fajr.
  final PrayerMoment next;

  /// The prayer before [next]; used for the progress bar. Before Fajr this is
  /// yesterday's Isha.
  final DateTime previousTime;

  final PrayerLocation location;

  /// Builds today's state from an `adhan_dart` result.
  ///
  /// `adhan_dart` returns UTC `DateTime`s; every time is converted to the
  /// device's local zone so the cards and the countdown agree with the clock.
  factory PrayerDay.fromTimes({
    required PrayerTimes times,
    required PrayerLocation location,
    required DateTime now,
  }) {
    final prayers = <PrayerMoment>[
      PrayerMoment(name: PrayerName.fajr, time: times.fajr.toLocal()),
      PrayerMoment(name: PrayerName.dhuhr, time: times.dhuhr.toLocal()),
      PrayerMoment(name: PrayerName.asr, time: times.asr.toLocal()),
      PrayerMoment(name: PrayerName.maghrib, time: times.maghrib.toLocal()),
      PrayerMoment(name: PrayerName.isha, time: times.isha.toLocal()),
    ];

    final nextIndex = prayers.indexWhere((prayer) => prayer.time.isAfter(now));
    final PrayerMoment next;
    final DateTime previousTime;
    if (nextIndex == -1) {
      // Everything today has passed: the next prayer is tomorrow's Fajr.
      next = PrayerMoment(
        name: PrayerName.fajr,
        time: times.fajrAfter.toLocal(),
        tomorrow: true,
      );
      previousTime = times.isha.toLocal();
    } else {
      next = prayers[nextIndex];
      previousTime = nextIndex == 0
          ? times.ishaBefore.toLocal()
          : prayers[nextIndex - 1].time;
    }

    return PrayerDay(
      date: times.date,
      now: now,
      prayers: List<PrayerMoment>.unmodifiable(prayers),
      next: next,
      previousTime: previousTime,
      location: location,
    );
  }

  /// The time left until [next].
  Duration get remaining {
    final value = next.time.difference(now);
    return value.isNegative ? Duration.zero : value;
  }

  /// How far we are between the previous prayer and the next one (0–1).
  double get progress {
    final total = next.time.difference(previousTime).inMilliseconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(previousTime).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  /// The state of [prayers]`[index]` at [now].
  PrayerPhase phaseFor(int index) {
    if (index < 0 || index >= prayers.length) return PrayerPhase.upcoming;
    final prayer = prayers[index];
    if (!next.tomorrow && prayer.name == next.name) return PrayerPhase.next;
    return prayer.time.isAfter(now) ? PrayerPhase.upcoming : PrayerPhase.passed;
  }

  /// Whether [prayer] is the next one (and therefore gets the highlighted
  /// time in the strip).
  bool isNext(PrayerName name) => !next.tomorrow && next.name == name;
}

/// The user's persisted calculation choices.
class PrayerSettings {
  const PrayerSettings({
    this.methodId = 'egyptian',
    this.madhabId = 'shafi',
    this.onboarded = false,
  });

  /// One of the ids in `kPrayerMethods`.
  final String methodId;

  /// `shafi` or `hanafi`.
  final String madhabId;

  /// Whether the first-run explanation has been shown.
  final bool onboarded;

  PrayerSettings copyWith({
    String? methodId,
    String? madhabId,
    bool? onboarded,
  }) {
    return PrayerSettings(
      methodId: methodId ?? this.methodId,
      madhabId: madhabId ?? this.madhabId,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrayerSettings &&
      other.methodId == methodId &&
      other.madhabId == madhabId &&
      other.onboarded == onboarded;

  @override
  int get hashCode => Object.hash(methodId, madhabId, onboarded);
}
