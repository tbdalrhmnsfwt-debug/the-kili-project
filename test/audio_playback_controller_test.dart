import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/audio_playback_controller.dart';
import 'package:zaker_ai/core/batches/audio_player_channel.dart';
import 'package:zaker_ai/core/batches/playback_position_store.dart';
import 'package:zaker_ai/core/key_value_store.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FakeBindings implements AudioPlayerBindings {
  _FakeBindings({this.durationMs});

  final int? durationMs;
  final StreamController<AudioPlaybackEvent> controller =
      StreamController<AudioPlaybackEvent>.broadcast();
  final List<int> seeks = [];
  int openCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int closeCalls = 0;

  @override
  Stream<AudioPlaybackEvent> get events => controller.stream;

  @override
  Future<int?> open(String path) async {
    openCalls++;
    return durationMs;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> seek(int positionMs) async {
    seeks.add(positionMs);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() async {
    closeCalls++;
    await controller.close();
  }
}

void main() {
  const uid = 'user-1';
  const batchId = 'batch-1';
  const resourceId = 'audio-1';

  late _MemoryStore memory;
  late PlaybackPositionStore positions;

  setUp(() {
    memory = _MemoryStore();
    positions = PlaybackPositionStore(memory);
  });

  AudioPlaybackController build(
    _FakeBindings bindings, {
    int? knownDurationMs,
  }) {
    return AudioPlaybackController(
      bindings: bindings,
      positions: positions,
      uid: uid,
      batchId: batchId,
      resourceId: resourceId,
      path: '/private/audio.m4a',
      knownDurationMs: knownDurationMs,
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('restores a saved position once a real duration is known', () async {
    await positions.save(
      uid: uid,
      batchId: batchId,
      resourceId: resourceId,
      positionMs: 4000,
      durationMs: 10000,
    );
    final bindings = _FakeBindings(durationMs: 10000);
    final player = build(bindings);
    addTearDown(player.dispose);

    await player.initialize();
    await settle();

    expect(bindings.openCalls, 1);
    expect(bindings.seeks, [4000]);
    expect(player.positionMs, 4000);
    expect(player.durationMs, 10000);
    expect(player.isReady, isTrue);
  });

  test('does not re-apply the old position after a user seek and pause',
      () async {
    await positions.save(
      uid: uid,
      batchId: batchId,
      resourceId: resourceId,
      positionMs: 4000,
      durationMs: 10000,
    );
    final bindings = _FakeBindings(durationMs: 10000);
    final player = build(bindings);
    addTearDown(player.dispose);
    await player.initialize();
    await settle();

    await player.seekTo(6000);
    bindings.controller.add(
      const AudioPlaybackEvent(
        state: AudioPlayerState.paused,
        positionMs: 6000,
        durationMs: 10000,
      ),
    );
    await settle();

    expect(bindings.seeks, [4000, 6000]);
    expect(player.positionMs, 6000);
    expect(
      positions.positionFor(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
      ),
      6000,
    );
  });

  test('clamps seeks to the duration and forgets a finished position',
      () async {
    final bindings = _FakeBindings(durationMs: 10000);
    final player = build(bindings);
    addTearDown(player.dispose);
    await player.initialize();
    await settle();

    await player.seekTo(99999);
    expect(bindings.seeks.last, 10000);

    await player.seekTo(9500);
    expect(bindings.seeks.last, 9500);
    expect(
      positions.positionFor(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
      ),
      isNull,
    );
  });

  test('an unknown duration is never saved and is not ready', () async {
    final bindings = _FakeBindings();
    final player = build(bindings);
    addTearDown(player.dispose);
    await player.initialize();
    await settle();

    expect(player.durationMs, 0);
    expect(player.isReady, isFalse);
    await player.seekTo(4000);
    await player.saveNow();
    expect(memory.values, isEmpty);
  });

  test('reports a native failure instead of pretending to play', () async {
    final bindings = _FakeBindings();
    final player = build(bindings);
    addTearDown(player.dispose);
    await player.initialize();
    bindings.controller.add(
      const AudioPlaybackEvent(
        state: AudioPlayerState.failed,
        errorCode: 'missingFile',
      ),
    );
    await settle();

    expect(player.hasError, isTrue);
    expect(player.errorCode, 'missingFile');
    await player.play();
    expect(bindings.playCalls, 0);
  });

  test('saves on close and releases the native player', () async {
    final bindings = _FakeBindings(durationMs: 10000);
    final player = build(bindings);
    await player.initialize();
    await player.seekTo(3000);

    player.dispose();
    await settle();

    expect(bindings.closeCalls, 1);
    expect(
      positions.positionFor(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
      ),
      3000,
    );
  });
}
