/// Dart side of `zaker/audio_player` and `zaker/audio_events`.
///
/// The channel is deliberately narrow and fully replaceable: tests inject a
/// fake [AudioPlayerBindings], so no MediaPlayer runs inside a widget test.
library;

import 'package:flutter/services.dart';

/// The states the native player reports.
enum AudioPlayerState { idle, preparing, playing, paused, completed, failed }

class AudioPlaybackEvent {
  const AudioPlaybackEvent({
    required this.state,
    this.positionMs,
    this.durationMs,
    this.errorCode,
  });

  final AudioPlayerState state;
  final int? positionMs;
  final int? durationMs;
  final String? errorCode;

  factory AudioPlaybackEvent.fromMap(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final state = switch (map['state'] as String?) {
      'preparing' => AudioPlayerState.preparing,
      'playing' => AudioPlayerState.playing,
      'paused' => AudioPlayerState.paused,
      'completed' => AudioPlayerState.completed,
      'failed' => AudioPlayerState.failed,
      _ => AudioPlayerState.idle,
    };
    return AudioPlaybackEvent(
      state: state,
      positionMs: (map['positionMs'] as num?)?.toInt(),
      durationMs: (map['durationMs'] as num?)?.toInt(),
      errorCode: map['error'] as String?,
    );
  }
}

/// A typed failure from the native player.
class AudioPlayerException implements Exception {
  const AudioPlayerException(this.code);

  final String code;

  @override
  String toString() => 'AudioPlayerException($code)';
}

/// The player surface the controller depends on.
abstract interface class AudioPlayerBindings {
  /// Opens a private file path and returns its duration when already known.
  Future<int?> open(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(int positionMs);
  Future<void> stop();
  Future<void> close();
  Stream<AudioPlaybackEvent> get events;
}

class AudioPlayerChannel implements AudioPlayerBindings {
  AudioPlayerChannel({
    required this.clientId,
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? const MethodChannel(methodName),
        _events = events ?? const EventChannel(eventName);

  static const String methodName = 'zaker/audio_player';
  static const String eventName = 'zaker/audio_events';

  /// This player's identity on the native side, so two screens can hold two
  /// files at once and closing one releases only its own player.
  final String clientId;

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Stream<AudioPlaybackEvent> get events => _events
      .receiveBroadcastStream()
      // One native event sink serves every client; keep this client's own.
      .where((raw) => raw is Map && raw['clientId'] == clientId)
      .map(AudioPlaybackEvent.fromMap);

  @override
  Future<int?> open(String path) =>
      _call<int?>('open', {'clientId': clientId, 'path': path});

  @override
  Future<void> play() => _call<void>('play', {'clientId': clientId});

  @override
  Future<void> pause() => _call<void>('pause', {'clientId': clientId});

  @override
  Future<void> seek(int positionMs) =>
      _call<void>('seek', {'clientId': clientId, 'positionMs': positionMs});

  @override
  Future<void> stop() => _call<void>('stop', {'clientId': clientId});

  @override
  Future<void> close() => _call<void>('dispose', {'clientId': clientId});

  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw AudioPlayerException(error.code);
    } on MissingPluginException {
      throw const AudioPlayerException('unavailable');
    }
  }
}
