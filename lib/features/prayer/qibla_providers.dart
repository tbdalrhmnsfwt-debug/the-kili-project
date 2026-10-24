/// Derived values for the Qibla screen.
///
/// The bearing comes from `adhan_dart`'s [Qibla] class, which implements the
/// great-circle initial bearing to the Kaaba.  The distance is a plain
/// haversine over the same two points so the globe card can print kilometres.
library;

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/qibla_constants.dart';
import 'prayer_providers.dart';

/// The Qibla bearing from the saved location, clockwise from true north.
///
/// `null` when no location has been chosen yet or the calculation fails.
final qiblaBearingProvider = Provider.autoDispose<double?>((ref) {
  final location = ref.watch(prayerLocationProvider);
  if (location == null) return null;
  try {
    return Qibla.qibla(Coordinates(location.latitude, location.longitude));
  } catch (error) {
    debugPrint('qibla: could not compute the bearing ($error)');
    return null;
  }
});

/// The great-circle distance from the saved location to the Kaaba, in km.
final qiblaDistanceProvider = Provider.autoDispose<double?>((ref) {
  final location = ref.watch(prayerLocationProvider);
  if (location == null) return null;
  return greatCircleDistanceKm(
    fromLatitude: location.latitude,
    fromLongitude: location.longitude,
    toLatitude: kKaabaLatitude,
    toLongitude: kKaabaLongitude,
  );
});
