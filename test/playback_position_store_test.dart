import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/chat_seen_store.dart';
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

void main() {
  late _MemoryStore memory;
  late PlaybackPositionStore positions;

  setUp(() {
    memory = _MemoryStore();
    positions = PlaybackPositionStore(memory);
  });

  test('stores, reads and removes a clamped position', () async {
    await positions.save(
      uid: 'user-1',
      batchId: 'batch-1',
      resourceId: 'audio-1',
      positionMs: 1200,
      durationMs: 4000,
    );
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      1200,
    );

    await positions.save(
      uid: 'user-1',
      batchId: 'batch-1',
      resourceId: 'audio-1',
      positionMs: 99999,
      durationMs: 4000,
    );
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      4000,
    );

    await positions.remove(
      uid: 'user-1',
      batchId: 'batch-1',
      resourceId: 'audio-1',
    );
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      isNull,
    );
  });

  test('does not store a position without a real duration', () async {
    await positions.save(
      uid: 'user-1',
      batchId: 'batch-1',
      resourceId: 'audio-1',
      positionMs: 1200,
      durationMs: 0,
    );
    expect(memory.values, isEmpty);
  });

  test('a zero position clears the entry', () async {
    await positions.save(
      uid: 'user-1',
      batchId: 'batch-1',
      resourceId: 'audio-1',
      positionMs: 1200,
      durationMs: 4000,
    );
    await positions.save(
      uid: 'user-1',
      batchId: 'batch-1',
      resourceId: 'audio-1',
      positionMs: 0,
      durationMs: 4000,
    );
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      isNull,
    );
  });

  test('keeps accounts and batches isolated', () async {
    await positions.save(
      uid: 'user-1',
      batchId: 'batch-1',
      resourceId: 'audio-1',
      positionMs: 1000,
      durationMs: 4000,
    );
    await positions.save(
      uid: 'user-1',
      batchId: 'batch-2',
      resourceId: 'audio-1',
      positionMs: 2000,
      durationMs: 4000,
    );

    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      1000,
    );
    expect(
      positions.positionFor(
        uid: 'user-2',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      isNull,
    );

    await positions.clearBatch(uid: 'user-1', batchId: 'batch-1');
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      isNull,
    );
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-2',
        resourceId: 'audio-1',
      ),
      2000,
    );
  });

  test('evicts the oldest entries beyond the cap', () async {
    var tick = 0;
    final capped = PlaybackPositionStore(
      memory,
      maxEntries: 2,
      clock: () => DateTime.utc(2026, 10, 25, 8).add(
        Duration(minutes: tick++),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await capped.save(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-$i',
        positionMs: 1000,
        durationMs: 4000,
      );
    }

    expect(
      capped.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-0',
      ),
      isNull,
    );
    expect(
      capped.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-2',
      ),
      1000,
    );
  });

  test('ignores corrupt JSON and malformed entries', () async {
    memory.values['batches.playback.v1.user-1'] = '{oops';
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      isNull,
    );

    memory.values['batches.playback.v1.user-1'] = jsonEncode({
      'entries': {
        'batch-1/audio-1': {'ms': '1200', 'at': '2026-10-25T08:00:00Z'},
        'batch-1/audio-2': {'ms': 1200, 'at': 42},
        'batch-1/audio-3': {'ms': -5, 'at': '2026-10-25T08:00:00Z'},
        'batch-1/audio-4': {'ms': 1200, 'at': '2026-10-25T08:00:00Z'},
      },
    });
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-1',
      ),
      isNull,
    );
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-2',
      ),
      isNull,
    );
    expect(
      positions.positionFor(
        uid: 'user-1',
        batchId: 'batch-1',
        resourceId: 'audio-4',
      ),
      1200,
    );
  });

  test('rejects invalid ids instead of writing them', () async {
    expect(
      () => positions.save(
        uid: 'user-1',
        batchId: '../escape',
        resourceId: 'audio-1',
        positionMs: 1000,
        durationMs: 4000,
      ),
      throwsA(isA<BatchFailure>()),
    );
    expect(memory.values, isEmpty);
  });

  group('ChatSeenStore', () {
    late ChatSeenStore seen;

    setUp(() {
      seen = ChatSeenStore(memory);
    });

    test('remembers a timestamp per batch and account', () async {
      final at = DateTime.utc(2026, 10, 25, 9);
      await seen.markSeen(uid: 'user-1', batchId: 'batch-1', at: at);

      expect(
        seen.seenAt(uid: 'user-1', batchId: 'batch-1')?.toUtc(),
        at,
      );
      expect(seen.seenAt(uid: 'user-1', batchId: 'batch-2'), isNull);
      expect(seen.seenAt(uid: 'user-2', batchId: 'batch-1'), isNull);
    });

    test('a corrupt marker reads as null and is replaced on the next visit',
        () async {
      memory.values['batches.chatSeen.v1.user-1'] = 'not json';
      expect(seen.seenAt(uid: 'user-1', batchId: 'batch-1'), isNull);

      final at = DateTime.utc(2026, 10, 25, 10);
      await seen.markSeen(uid: 'user-1', batchId: 'batch-1', at: at);
      expect(seen.seenAt(uid: 'user-1', batchId: 'batch-1')?.toUtc(), at);
    });
  });
}
