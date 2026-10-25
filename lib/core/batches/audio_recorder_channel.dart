/// Dart side of `zaker/audio_recorder` and `zaker/recorder_events`.
///
/// Recording only ever targets a caller-supplied temporary path. The chat
/// layer copies the finished file into the batch's private voice directory.
library;

import 'package:flutter/services.dart';

class RecorderTick {
  const RecorderTick({
    required this.elapsedMs,
    required this.amplitude,
    this.maxReached = false,
  });

  final int elapsedMs;
  final int amplitude;

  /// True when the platform stopped at the 15-minute cap on its own.
  final bool maxReached;

  factory RecorderTick.fromMap(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return RecorderTick(
      elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
      amplitude: (map['amplitude'] as num?)?.toInt() ?? 0,
      maxReached: map['maxReached'] == true,
    );
  }
}

class RecordedClip {
  const RecordedClip({
    required this.path,
    required this.durationMs,
    required this.sizeBytes,
  });

  final String path;
  final int durationMs;
  final int sizeBytes;
}

/// A typed recorder failure, including a denied microphone permission.
class AudioRecorderException implements Exception {
  const AudioRecorderException(this.code);

  final String code;

  bool get isPermissionDenied => code == 'permissionDenied';

  @override
  String toString() => 'AudioRecorderException($code)';
}

abstract interface class AudioRecorderBindings {
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Free bytes on the volume that will hold the recording, or 0 when the
  /// platform cannot tell.
  Future<int> freeBytes();

  /// Starts recording into [tempPath]. A bare file name is resolved by the
  /// platform inside this app's private cache directory.
  Future<void> start(String tempPath);
  Future<RecordedClip> stop();
  Future<void> cancel();
  Stream<RecorderTick> get ticks;
}

class AudioRecorderChannel implements AudioRecorderBindings {
  AudioRecorderChannel({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? const MethodChannel(methodName),
        _events = events ?? const EventChannel(eventName);

  static const String methodName = 'zaker/audio_recorder';
  static const String eventName = 'zaker/recorder_events';

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Stream<RecorderTick> get ticks =>
      _events.receiveBroadcastStream().map(RecorderTick.fromMap);

  @override
  Future<bool> hasPermission() async =>
      await _call<bool>('hasPermission') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _call<bool>('requestPermission') ?? false;

  @override
  Future<int> freeBytes() async => await _call<int>('freeBytes') ?? 0;

  @override
  Future<void> start(String tempPath) =>
      _call<void>('start', {'path': tempPath});

  @override
  Future<RecordedClip> stop() async {
    final result = await _call<Map<Object?, Object?>>('stop');
    if (result == null) {
      throw const AudioRecorderException('recordFailed');
    }
    final map = Map<String, dynamic>.from(result);
    return RecordedClip(
      path: map['path'] as String? ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> cancel() => _call<void>('cancel');

  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw AudioRecorderException(error.code);
    } on MissingPluginException {
      throw const AudioRecorderException('unavailable');
    }
  }
}
