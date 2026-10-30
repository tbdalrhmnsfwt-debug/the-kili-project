/// Playback state, resume position and progress for one audio resource.
///
/// It owns no audio engine of its own: every command goes through
/// [AudioPlayerBindings], and every event comes back from the platform. When
/// the native player cannot open the file the controller reports a real
/// failure instead of pretending to play.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_player_channel.dart';
import 'playback_position_store.dart';

class AudioPlaybackController extends ChangeNotifier {
  AudioPlaybackController({
    required this.bindings,
    required this.positions,
    required this.uid,
    required this.batchId,
    required this.resourceId,
    required this.path,
    int? knownDurationMs,
    DateTime Function()? clock,
  })  : _durationMs = knownDurationMs ?? 0,
        _clock = clock ?? DateTime.now;

  final AudioPlayerBindings bindings;
  final PlaybackPositionStore positions;
  final String uid;
  final String batchId;
  final String resourceId;
  final String path;
  final DateTime Function() _clock;

  static const int saveEveryMs = 5000;

  /// A saved position closer than this to the end restarts from zero.
  static const int endToleranceMs = 1500;

  AudioPlayerState _state = AudioPlayerState.idle;
  int _positionMs = 0;
  int _durationMs;
  String? _errorCode;
  bool _initialized = false;
  bool _restoreDone = false;
  bool _disposed = false;
  DateTime? _lastSavedAt;
  StreamSubscription<AudioPlaybackEvent>? _subscription;

  AudioPlayerState get state => _state;
  int get positionMs => _positionMs;
  int get durationMs => _durationMs;
  String? get errorCode => _errorCode;
  bool get isPlaying => _state == AudioPlayerState.playing;
  bool get isPreparing => _state == AudioPlayerState.preparing;

  /// The player is usable only after [initialize] has opened the file: before
  /// that the native player is still preparing and a play command would be
  /// refused with `notReady`.
  bool get isReady =>
      _durationMs > 0 &&
      _state != AudioPlayerState.idle &&
      _state != AudioPlayerState.failed;
  bool get hasError => _state == AudioPlayerState.failed;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    _subscription = bindings.events.listen(_onEvent, onError: (Object error) {
      _fail(error is AudioPlayerException ? error.code : 'unavailable');
    });
    try {
      final duration = await bindings.open(path);
      if (_disposed) return;
      if (duration != null && duration > 0) {
        _durationMs = duration;
      }
      if (_durationMs <= 0) {
        // The open reply carries the duration, and no event supplied one
        // while we waited: the file is not playable here, and sitting in
        // "preparing" forever hides that from the student.
        _fail('no_duration');
        return;
      }
      _state = AudioPlayerState.preparing;
      notifyListeners();
      await _applySavedPosition();
    } on AudioPlayerException catch (error) {
      _fail(error.code);
    }
  }

  Future<void> toggle() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (_disposed || hasError) return;
    try {
      await bindings.play();
      _state = AudioPlayerState.playing;
      _errorCode = null;
      notifyListeners();
    } on AudioPlayerException catch (error) {
      _fail(error.code);
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    try {
      await bindings.pause();
      _state = AudioPlayerState.paused;
      notifyListeners();
      await saveNow();
    } on AudioPlayerException catch (error) {
      _fail(error.code);
    }
  }

  Future<void> seekTo(int positionMs) async {
    if (_disposed || hasError) return;
    final target = _durationMs > 0
        ? positionMs.clamp(0, _durationMs).toInt()
        : positionMs.clamp(0, PlaybackPositionStore.maxPositionMs).toInt();
    try {
      await bindings.seek(target);
      _positionMs = target;
      notifyListeners();
      await saveNow();
    } on AudioPlayerException catch (error) {
      _fail(error.code);
    }
  }

  /// Writes the current position. Called every few seconds, on pause, on a
  /// seek, when the app leaves the foreground and on close.
  Future<void> saveNow() async {
    if (_durationMs <= 0) return;
    if (_positionMs >= _durationMs - endToleranceMs) {
      // Finished (or effectively finished): start over next time.
      await positions.remove(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
      );
      return;
    }
    await positions.save(
      uid: uid,
      batchId: batchId,
      resourceId: resourceId,
      positionMs: _positionMs,
      durationMs: _durationMs,
    );
    _lastSavedAt = _clock();
  }

  void _onEvent(AudioPlaybackEvent event) {
    if (_disposed) return;
    if (event.durationMs != null && event.durationMs! > 0) {
      _durationMs = event.durationMs!;
    }
    if (event.positionMs != null && event.positionMs! >= 0) {
      _positionMs = _durationMs > 0
          ? event.positionMs!.clamp(0, _durationMs).toInt()
          : event.positionMs!;
    }
    // Restore the remembered position exactly once, as soon as a real
    // duration is known. Never re-apply it on a user pause or seek.
    if (!_restoreDone && _durationMs > 0) {
      unawaited(_applySavedPosition());
    }
    switch (event.state) {
      case AudioPlayerState.preparing:
        _state = AudioPlayerState.preparing;
        notifyListeners();
      case AudioPlayerState.playing:
        _state = AudioPlayerState.playing;
        notifyListeners();
        _saveIfDue();
      case AudioPlayerState.paused:
        _state = AudioPlayerState.paused;
        notifyListeners();
        unawaited(saveNow());
      case AudioPlayerState.completed:
        _state = AudioPlayerState.completed;
        _positionMs = 0;
        notifyListeners();
        unawaited(
          positions.remove(
            uid: uid,
            batchId: batchId,
            resourceId: resourceId,
          ),
        );
      case AudioPlayerState.failed:
        _fail(event.errorCode ?? 'failed');
      case AudioPlayerState.idle:
        _state = AudioPlayerState.idle;
        notifyListeners();
    }
  }

  Future<void> _applySavedPosition() async {
    if (_restoreDone || _durationMs <= 0) return;
    _restoreDone = true;
    final saved = positions.positionFor(
      uid: uid,
      batchId: batchId,
      resourceId: resourceId,
    );
    if (saved == null || saved >= _durationMs - endToleranceMs) return;
    try {
      await bindings.seek(saved);
      if (_disposed) return;
      _positionMs = saved;
      notifyListeners();
    } on AudioPlayerException {
      // A failed seek must not stop the file from playing from the start.
    }
  }

  void _saveIfDue() {
    final now = _clock();
    final last = _lastSavedAt;
    if (last != null && now.difference(last).inMilliseconds < saveEveryMs) {
      return;
    }
    unawaited(saveNow());
  }

  void _fail(String code) {
    if (_disposed) return;
    _state = AudioPlayerState.failed;
    _errorCode = code;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close());
    super.dispose();
  }

  /// Saves the position and releases the native player. Retrying must await
  /// this before opening the file again, otherwise the release races the new
  /// `open` and tears down the player it just created.
  Future<void> close() => _closeFuture ??= _shutdown();

  Future<void>? _closeFuture;

  Future<void> _shutdown() async {
    await saveNow();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await bindings.close();
    } on AudioPlayerException {
      // Closing a player that never opened has nothing to report.
    }
  }
}
