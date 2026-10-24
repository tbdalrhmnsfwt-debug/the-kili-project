/// Constants and small geometry helpers shared by the Qibla feature.
///
/// The bearing itself is calculated by `adhan_dart`'s `Qibla` class, which
/// uses these same Kaaba coordinates; they are repeated here for the distance
/// and for the globe drawing, which need the destination as a plain point.
library;

import 'dart:math' as math;

/// The Kaaba, inside the Masjid al-Haram in Makkah.
///
/// Matches `adhan_dart`'s `Qibla.makkah` (21.4225241, 39.8261818) to seven
/// decimal places.
const double kKaabaLatitude = 21.4225241;
const double kKaabaLongitude = 39.8261818;

/// Mean Earth radius used for great-circle distances (IUGG, kilometres).
const double kEarthMeanRadiusKm = 6371.0088;

/// How close the device heading must be to the Qibla to count as aligned.
const double kQiblaAlignmentThresholdDegrees = 5;

/// Accuracy at or worse than this (in degrees, as reported by the
/// magnetometer) shows the "figure 8" calibration notice.
///
/// Android reports 15° (high), 30° (medium) and 45° (low); iOS reports its
/// own `headingAccuracy`, also in degrees.  The comparison is inclusive so
/// Android's medium accuracy also prompts the user to recalibrate — a ±30°
/// heading is not good enough to trust for prayer.
const double kQiblaLowAccuracyDegrees = 30;

/// How long to wait for the first compass event before falling back to the
/// static bearing.  A device without a magnetometer never emits one.
const Duration kCompassDetectionTimeout = Duration(seconds: 4);

/// Number of samples used to draw the great-circle path on the globe.
const int kQiblaPathSamples = 72;

/// Great-circle distance in kilometres between two points.
///
/// Uses the haversine formula, which is numerically stable for the short
/// distances involved here.
double greatCircleDistanceKm({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  final phi1 = fromLatitude * math.pi / 180;
  final phi2 = toLatitude * math.pi / 180;
  final deltaPhi = (toLatitude - fromLatitude) * math.pi / 180;
  final deltaLambda = (toLongitude - fromLongitude) * math.pi / 180;

  final a =
      math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLambda / 2) *
          math.sin(deltaLambda / 2);
  return 2 * kEarthMeanRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// The shortest signed difference from [from] to [to] on a 0–360° circle.
///
/// Used to rotate the needle the short way around instead of spinning across
/// north when the heading crosses 0°/360°.
double shortestAngleDelta(double from, double to) {
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return delta;
}
