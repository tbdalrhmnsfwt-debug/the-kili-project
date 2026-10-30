/// The bag's single audio player.
///
/// Every voice pocket shares one instance, so starting a clip stops whatever
/// was playing before it. The player owns no timers: position and state come
/// from the native player's own event stream.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/audio_player_channel.dart';
import '../../../providers/batch_providers.dart';

class BagAudioPlayer extends ChangeNotifier {
  BagAudioPlayer(AudioPlayerBindings bindings) : _bindings = bindings {
    _subscription = _bindings.events.listen(
      _onEvent,
      onError: (Object _) {
        _isPlaying = false;
        notifyListeners();
      },
    );
  }

  final AudioPlayerBindings _bindings;
  late final StreamSubscription<AudioPlaybackEvent> _subscription;

  String? _clipId;
  bool _isPlaying = false;
  int _positionMs = 0;
  int _durationMs = 0;

  /// The clip this player is holding, or null before the first play.
  String? get clipId => _clipId;

  bool get isPlaying => _isPlaying;

  int get positionMs => _positionMs;

  /// The open clip's duration; the catalog value until the player reports one.
  int get durationMs => _durationMs;

  /// Plays [clipId], pauses it when it is already playing, and stops whatever
  /// other clip was open.
  Future<void> toggle({
    required String clipId,
    required String path,
    required int durationMs,
  }) async {
    if (_clipId == clipId) {
      if (_isPlaying) {
        await _bindings.pause();
        _isPlaying = false;
        notifyListeners();
        return;
      }
      await _bindings.play();
      return;
    }
    await _bindings.stop();
    final opened = await _bindings.open(path) ?? durationMs;
    _clipId = clipId;
    _durationMs = opened;
    _positionMs = 0;
    _isPlaying = false;
    notifyListeners();
    await _bindings.play();
  }

  /// Moves the playhead; values outside the clip are ignored.
  Future<void> seek(int positionMs) async {
    if (positionMs < 0 || positionMs > _durationMs) return;
    _positionMs = positionMs;
    notifyListeners();
    await _bindings.seek(positionMs);
  }

  /// Stops playback and returns the playhead to the start.
  Future<void> stop() async {
    await _bindings.stop();
    _positionMs = 0;
    _isPlaying = false;
    notifyListeners();
  }

  void _onEvent(AudioPlaybackEvent event) {
    if (event.positionMs != null) _positionMs = event.positionMs!;
    if (event.durationMs != null) _durationMs = event.durationMs!;
    _isPlaying = event.state == AudioPlayerState.playing;
    if (event.state == AudioPlayerState.completed) {
      _positionMs = _durationMs;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    // The provider owns the binding and releases the native player when this
    // player is disposed; closing it here would release whatever player the
    // next client had opened.
    super.dispose();
  }
}

/// One player per pocket screen; disposed with it.
final bagAudioPlayerProvider = Provider.autoDispose<BagAudioPlayer>((ref) {
  final player = BagAudioPlayer(ref.watch(audioPlayerBindingsProvider('bag')));
  ref.onDispose(player.dispose);
  return player;
});
