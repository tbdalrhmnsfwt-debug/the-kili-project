/// Dart side of `zaker/audio_player` and `zaker/audio_events`.
///
/// The channel is deliberately narrow and fully replaceable: tests inject a
/// fake [AudioPlayerBindings], so no MediaPlayer runs inside a widget test.
library;

import 'dart:async';

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

/// Fans the one native event stream out to every client.
///
/// `EventChannel.receiveBroadcastStream` installs the channel's single
/// message handler on each call, so a second subscriber silently takes every
/// event from the first. The native side already tags each payload with its
/// `clientId`; this keeps one subscription and hands each client only its own.
class AudioEventHub {
  /// A hub over [open], for tests that need an event source of their own.
  AudioEventHub(this._open);

  AudioEventHub._forChannel(EventChannel events)
      : _open = events.receiveBroadcastStream;

  /// The hub for [events]'s channel. Two channels with one name share the
  /// single native sink that name addresses.
  factory AudioEventHub.forChannel(EventChannel events) => _hubs.putIfAbsent(
        events.name,
        () => AudioEventHub._forChannel(events),
      );

  static final Map<String, AudioEventHub> _hubs = {};

  final Stream<dynamic> Function() _open;

  StreamSubscription<dynamic>? _subscription;
  final Map<String, Set<StreamController<AudioPlaybackEvent>>> _clients = {};

  /// The events addressed to [clientId].
  Stream<AudioPlaybackEvent> eventsFor(String clientId) {
    late StreamController<AudioPlaybackEvent> controller;
    controller = StreamController<AudioPlaybackEvent>.broadcast(
      onListen: () {
        // `listen` opens the native stream at most once, and only while some
        // client is listening: an idle app holds no event channel.
        _subscription ??= _open().listen(_dispatch);
        _clients.putIfAbsent(clientId, () => {}).add(controller);
      },
      onCancel: () {
        final listeners = _clients[clientId];
        listeners?.remove(controller);
        if (listeners != null && listeners.isEmpty) _clients.remove(clientId);
        if (_clients.isEmpty) {
          _subscription?.cancel();
          _subscription = null;
        }
      },
    );
    return controller.stream;
  }

  void _dispatch(Object? raw) {
    if (raw is! Map) return;
    final listeners = _clients[raw['clientId']];
    if (listeners == null) return;
    final event = AudioPlaybackEvent.fromMap(raw);
    for (final controller in listeners.toList()) {
      if (!controller.isClosed) controller.add(event);
    }
  }
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
  Stream<AudioPlaybackEvent> get events =>
      AudioEventHub.forChannel(_events).eventsFor(clientId);

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
