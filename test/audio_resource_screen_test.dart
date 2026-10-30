import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/audio_player_channel.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/playback_position_store.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/subjects/audio_resource_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

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
  static const int? durationMs = 5000;
  final StreamController<AudioPlaybackEvent> controller =
      StreamController<AudioPlaybackEvent>.broadcast();
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Stream<AudioPlaybackEvent> get events => controller.stream;

  @override
  Future<int?> open(String path) async => durationMs;

  @override
  Future<void> play() async {
    playCalls++;
    controller.add(
      AudioPlaybackEvent(
        state: AudioPlayerState.playing,
        positionMs: 0,
        durationMs: durationMs,
      ),
    );
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> seek(int positionMs) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() async {
    await controller.close();
  }
}

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-1';
  const resourceId = 'audio-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  BatchSnapshot snapshot() {
    return BatchSnapshot(
      batch: Batch(
        id: batchId,
        name: 'دفعة تالتة ثانوي',
        ownerUid: uid,
        createdAt: fixed,
        lastActivityAt: fixed,
        settings: const BatchSettings(),
        subjects: [
          BatchSubject(
            id: 'subject-1',
            name: 'رياضيات',
            order: 0,
            createdAt: fixed,
          ),
        ],
        codeState: InviteCodeState(code: '12345678', createdAt: fixed),
      ),
      members: [
        Membership(
          batchId: batchId,
          uid: uid,
          displayName: 'طالب',
          role: BatchRole.owner,
          joinedAt: fixed,
        ),
      ],
      resources: [
        BatchResource(
          id: resourceId,
          batchId: batchId,
          subjectId: 'subject-1',
          kind: ResourceKind.audio,
          title: 'شرح الدرس',
          fileName: 'lesson.m4a',
          sizeBytes: 2048,
          durationMs: 5000,
          uploaderUid: uid,
          createdAt: fixed,
        ),
      ],
    );
  }

  Widget app(_FakeBindings bindings) {
    return ProviderScope(
      overrides: [
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
        batchDetailProvider.overrideWith((ref, id) async => snapshot()),
        batchFileStoreProvider.overrideWithValue(
          BatchFileStore(root: Directory.systemTemp),
        ),
        resourceMissingProvider.overrideWith((ref, args) async => false),
        audioPlayerBindingsProvider.overrideWith((ref, clientId) => bindings),
        playbackPositionStoreProvider.overrideWithValue(
          PlaybackPositionStore(_MemoryStore()),
        ),
      ],
      child: MaterialApp(
        theme: ZakerTheme.light(),
        home: const AudioResourceScreen(
          batchId: batchId,
          resourceId: resourceId,
        ),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets(
      'opens the real local player and shows the honest blocked '
      'transcription note', (tester) async {
    final bindings = _FakeBindings();
    await tester.pumpWidget(app(bindings));
    // Bounded pumps: the loading skeletons and the progress indicator repeat
    // forever, so pumpAndSettle would never return. The screen never closes
    // the fake binding's controller while it is mounted, so no teardown close.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('شرح الدرس'), findsWidgets);
    expect(find.text('رياضيات · 0:05 · ٢ كيلوبايت'), findsOneWidget);
    expect(find.textContaining('التفريغ الآلي مش متاح'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(bindings.playCalls, 1);
  });
}
