/// Location helpers for the prayer feature.
///
/// Every platform call is wrapped: a missing geocoder, a revoked permission or
/// a device without GPS must never stop the app or block the prayer screen.
library;

import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/egypt_cities.dart';
import 'prayer_models.dart';

/// Builds a [PrayerLocation] from a GPS fix, reverse-geocoding its city name.
Future<PrayerLocation> locationFromPosition(Position position) async {
  final labels = await _labelsFor(position.latitude, position.longitude);
  return PrayerLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    city: labels.city,
    region: labels.region,
    fromGps: true,
  );
}

/// Builds a [PrayerLocation] from a city in the bundled list.
PrayerLocation locationFromCity(EgyptCity city) {
  return PrayerLocation(
    latitude: city.latitude,
    longitude: city.longitude,
    city: city.name,
    region: city.governorate,
  );
}

/// Resolves a human-readable city/governorate pair.
///
/// Uses the platform geocoder first.  If it is unavailable, the nearest city
/// from the bundled Egyptian list is used; failing that, the caller falls back
/// to the coordinates (the [PrayerLocation] keeps them either way).
Future<({String city, String region})> _labelsFor(
  double latitude,
  double longitude,
) async {
  try {
    final geocoding = Geocoding();
    final marks = await geocoding
        .placemarkFromCoordinates(
          latitude,
          longitude,
          locale: const Locale('ar', 'EG'),
        )
        .timeout(const Duration(seconds: 8));
    if (marks.isNotEmpty) {
      final mark = marks.first;
      final city =
          _clean(mark.locality) ??
          _clean(mark.subAdministrativeArea) ??
          _clean(mark.administrativeArea) ??
          _clean(mark.name);
      var region =
          _clean(mark.administrativeArea) ?? _clean(mark.country) ?? '';
      if (region == city) region = '';
      if (city != null) return (city: city, region: region);
    }
  } catch (error) {
    debugPrint('prayer: reverse geocoding unavailable ($error)');
  }

  final nearest = nearestEgyptCity(latitude, longitude);
  if (nearest != null) {
    return (city: nearest.name, region: nearest.governorate);
  }
  // No city name: the model falls back to displaying the coordinates.
  return (city: '', region: '');
}

String? _clean(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
