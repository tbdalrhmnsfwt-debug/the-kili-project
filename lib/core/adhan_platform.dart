/// Small platform bridge for the adhan settings screen.
///
/// * Battery-optimisation state and the system exemption prompt.
/// * The app-settings screen (for notifications disabled outside the app).
/// * In-app preview of a bundled raw sound, so a voice can be heard without
///   posting a notification.
///
/// Every call is guarded: on a platform without the channel (tests, desktop)
/// the methods return `false` instead of throwing.
library;

import 'package:flutter/services.dart';

class AdhanPlatform {
  const AdhanPlatform._();

  static const MethodChannel _channel = MethodChannel('zaker/adhan');

  /// Whether Android is allowed to put the app to sleep. `null` when the
  /// platform could not be asked.
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
    } catch (_) {
      return null;
    }
  }

  /// Opens the system dialog that excludes the app from battery optimisation.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestIgnoreBatteryOptimizations',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the app's system settings page (used when notifications are
  /// blocked and the runtime prompt no longer appears).
  static Future<bool> openAppSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Plays `res/raw/<resourceName>` in process (used by the voice picker).
  static Future<bool> playPreview(String resourceName) async {
    try {
      return await _channel.invokeMethod<bool>('playPreview', {
            'name': resourceName,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Stops the preview player, if one is running.
  static Future<void> stopPreview() async {
    try {
      await _channel.invokeMethod<void>('stopPreview');
    } catch (_) {
      // Nothing to stop.
    }
  }
}
