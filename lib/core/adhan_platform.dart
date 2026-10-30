/// Small platform bridge for the adhan and prayer screens.
///
/// * Battery-optimisation state and the system exemption prompt.
/// * The app-settings screen (for notifications disabled outside the app).
/// * In-app preview of a bundled raw sound, so a voice can be heard without
///   posting a notification.
/// * Keeping the screen awake for the two screens that need it — aiming the
///   qibla compass and a full-screen adhan — instead of every screen.
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

  /// Whether Android will let this app open a full-screen adhan over the lock
  /// screen. Android 14 can withhold this even with the manifest permission.
  static Future<bool?> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent');
    } catch (_) {
      return null;
    }
  }

  /// Opens the system screen where the full-screen-intent permission is
  /// granted. Returns whether the screen was opened.
  static Future<bool> requestFullScreenIntentPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestFullScreenIntent') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Whether the app may draw the optional floating adhan card over other
  /// apps.
  static Future<bool?> canDrawOverlays() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays');
    } catch (_) {
      return null;
    }
  }

  /// Opens the system "display over other apps" screen.
  static Future<bool> requestOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestOverlayPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Plays `res/raw/<resourceName>` in process (used by the voice picker).
  ///
  /// When the voice is a user-added asset, [assetPath] is passed along and
  /// the native side opens it from the Flutter asset bundle instead.
  static Future<bool> playPreview(
    String resourceName, {
    String? assetPath,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('playPreview', {
            'name': resourceName,
            'asset': assetPath,
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

  /// Keeps the screen awake while [on] is true.
  ///
  /// Only the qibla aim and the full-screen adhan ask for this; every other
  /// screen leaves the display on the system timeout.
  static Future<void> setKeepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {'on': on});
    } catch (_) {
      // Not fatal: the screen simply follows the system timeout.
    }
  }

  /// Starts the foreground adhan player for the full-screen adhan.
  ///
  /// The service plays [resource] from `res/raw`, or [assetPath] from the
  /// Flutter asset bundle for a user-added recording.  It keeps playing while
  /// the app is in the background, with a notification whose action stops it.
  static Future<bool> startPlayback({
    required String resource,
    required String title,
    String? assetPath,
    int? notificationId,
    bool fadeIn = false,
    bool silenceOnHardware = true,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('startAdhanPlayback', {
            'name': resource,
            'asset': assetPath,
            'title': title,
            'notificationId': notificationId,
            'fadeIn': fadeIn,
            'silenceOnHardware': silenceOnHardware,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Stops the foreground adhan player.
  static Future<void> stopPlayback() async {
    try {
      await _channel.invokeMethod<void>('stopAdhanPlayback');
    } catch (_) {
      // Nothing to stop.
    }
  }
}
