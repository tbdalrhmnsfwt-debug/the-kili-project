/// The ongoing system notification that counts down to the next prayer.
///
/// Android renders the countdown with its own chronometer, so the process may
/// be dead; this wrapper only hands the boundary list to the native bridge and
/// routes a tap back into the app. Every call is guarded: on a platform
/// without the bridge (tests, desktop) it silently reports failure.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../features/prayer/prayer_status_schedule.dart';

class PrayerStatusBar {
  PrayerStatusBar._();

  /// The single bridge instance used by the app.
  static final PrayerStatusBar instance = PrayerStatusBar._();

  static const String channelName = 'zaker/prayer_status';
  static const MethodChannel _channel = MethodChannel(channelName);

  /// Called when the user taps the bar; the route comes from the native side.
  void Function(String route)? onOpenRoute;

  bool _attached = false;

  /// Registers the native-to-Dart callback. Safe to call more than once.
  void attach() {
    if (_attached) return;
    _attached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openRoute') return null;
      final route = call.arguments;
      if (route is String) onOpenRoute?.call(route);
      return null;
    });
  }

  /// Stores [boundaries] natively, posts the bar and re-arms every alarm.
  ///
  /// Returns `false` when the platform has no bridge or rejected the payload.
  Future<bool> sync({
    required String city,
    required List<PrayerStatusBoundary> boundaries,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('sync', <String, Object?>{
        'enabled': true,
        'city': city,
        'boundaries': [for (final boundary in boundaries) boundary.toJson()],
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('prayer_status: sync failed (${error.code})');
      return false;
    }
  }

  /// Hides the bar and cancels every boundary alarm.
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // No bridge on this platform.
    } on PlatformException catch (error) {
      debugPrint('prayer_status: cancel failed (${error.code})');
    }
  }

  /// The route the app was launched with, consumed once.
  Future<String?> takeLaunchRoute() async {
    try {
      return await _channel.invokeMethod<String>('takeLaunchRoute');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
