import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/audio_player_channel.dart';
import 'package:zaker_ai/core/batches/audio_recorder_channel.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';
import 'package:zaker_ai/core/my_bag/my_bag_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_pocket_screen.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';
import 'package:zaker_ai/providers/my_bag_providers.dart';

import 'support/my_bag_fixtures.dart';

class _FakeRecorder implements AudioRecorderBindings {
  _FakeRecorder({
    this.permitted = true,
    this.free = 100 * 1024 * 1024,
    required this.resultPath,
  });

  final bool permitted;
  final int free;
  final String resultPath;
  final StreamController<RecorderTick> _ticks =
      StreamController<RecorderTick>.broadcast();
  int startCalls = 0;
  bool cancelled = false;

  @override
  Stream<RecorderTick> get ticks => _ticks.stream;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async => permitted;

  @override
  Future<int> freeBytes() async => free;

  @override
  Future<void> start(String tempPath) async => startCalls++;

  @override
  Future<RecordedClip> stop() async =>
      RecordedClip(path: resultPath, durationMs: 1200, sizeBytes: 3);

  @override
  Future<void> cancel() async => cancelled = true;

  void tick(int amplitude, [int elapsedMs = 200]) =>
      _ticks.add(RecorderTick(elapsedMs: elapsedMs, amplitude: amplitude));
}

class _FakePlayer implements AudioPlayerBindings {
  final StreamController<AudioPlaybackEvent> _events =
      StreamController<AudioPlaybackEvent>.broadcast();
  int openCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Stream<AudioPlaybackEvent> get events => _events.stream;

  @override
  Future<int?> open(String path) async {
    openCalls++;
    return 1200;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _events.add(
      const AudioPlaybackEvent(
        state: AudioPlayerState.playing,
        positionMs: 0,
        durationMs: 1200,
      ),
    );
  }

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(int positionMs) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() async {}
}

void main() {
  late Directory root;
  late MyBagStore store;
  late String clipPath;
  const folderId = 'subject:sec1:الرياضيات';
  final folder = MyBagFolder.subject(
    gradeId: 'sec1',
    subjectKey: 'الرياضيات',
    name: 'الرياضيات',
    colorValue: 0xFF2F5EA8,
    createdAt: DateTime.utc(2026, 10, 1),
  );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_bag_voice_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
    clipPath = '${root.path}/recorded.m4a';
    File(clipPath).writeAsBytesSync(const [1, 2, 3]);
    await store.saveIndex(MyBagIndex().upsert(folder));
  });

  tearDown(() => root.deleteSync(recursive: true));

  Widget app(_FakeRecorder recorder, _FakePlayer player) => ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          myBagStoreProvider.overrideWithValue(store),
          bagSeedSubjectsProvider.overrideWithValue(const []),
          bagSubjectProgressProvider.overrideWithValue(const {}),
          audioRecorderBindingsProvider.overrideWithValue(recorder),
          audioPlayerBindingsProvider.overrideWithValue(player),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          home: const BagPocketScreen(
            folderId: folderId,
            kind: BagPocketKind.voice,
          ),
        ),
      );

  testWidgets('a recording is saved with a downsampled waveform', (
    tester,
  ) async {
    final recorder = _FakeRecorder(resultPath: clipPath);
    await tester.pumpWidget(app(recorder, _FakePlayer()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-pocket-add')));
    // The recording stage runs a 200 ms elapsed timer, so this route can
    // never settle: pump its entrance by hand instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('bag-voice-recorder-sheet')), findsOneWidget);
    expect(recorder.startCalls, 1);

    for (var i = 0; i < 5; i++) {
      recorder.tick(1000 + i * 500, 200 * (i + 1));
    }
    await tester.pump();

    await tester.tap(find.byKey(const Key('bag-recorder-stop')));
    await tester.pump();

    // The pocket copies real bytes on the real event loop, then deletes the
    // recorder's temporary file; both must finish before the assertions.
    for (var i = 0; i < 50; i++) {
      if (store.loadMedia(folderId).voice.isNotEmpty &&
          !File(clipPath).existsSync()) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final media = store.loadMedia(folderId);
    expect(media.voice, hasLength(1));
    final clip = media.voice.single;
    expect(clip.durationMs, 1200);
    expect(clip.waveform, isNotEmpty);
    expect(clip.waveform.length, lessThanOrEqualTo(96));
    expect(store.voiceFile(folderId, clip.fileName).existsSync(), isTrue);
    expect(File(clipPath).existsSync(), isFalse);
    expect(find.byKey(Key('bag-voice-${clip.id}')), findsOneWidget);
  });

  testWidgets('leaving while recording discards it, as the hint says', (
    tester,
  ) async {
    final recorder = _FakeRecorder(resultPath: clipPath);
    await tester.pumpWidget(app(recorder, _FakePlayer()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-pocket-add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('الحد الأقصى ١٥ دقيقة. لو سبت الشاشة، التسجيل هيتلغي.'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(recorder.cancelled, isTrue);
    expect(find.byKey(const Key('bag-voice-recorder-sheet')), findsNothing);
    expect(store.loadMedia(folderId).voice, isEmpty);
  });

  testWidgets('a denied microphone explains and offers settings', (
    tester,
  ) async {
    final recorder = _FakeRecorder(permitted: false, resultPath: clipPath);
    await tester.pumpWidget(app(recorder, _FakePlayer()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-pocket-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bag-recorder-denied')), findsOneWidget);
    expect(find.byKey(const Key('bag-recorder-settings')), findsOneWidget);
    expect(recorder.startCalls, 0);
  });

  testWidgets('a nearly full device refuses to start', (tester) async {
    final recorder = _FakeRecorder(free: 1024, resultPath: clipPath);
    await tester.pumpWidget(app(recorder, _FakePlayer()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-pocket-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bag-recorder-low-storage')), findsOneWidget);
    expect(recorder.startCalls, 0);
  });

  testWidgets('one player opens, plays and pauses', (tester) async {
    final player = _FakePlayer();
    const clip = MyBagVoiceClip(
      id: 'v1',
      fileName: 'v1.m4a',
      title: 'شرح',
      durationMs: 1200,
      sizeBytes: 3,
      createdAtMs: 1,
      waveform: [20, 80, 50],
    );
    // Real file I/O inside a testWidgets body never completes under the fake
    // async zone; seed the clip on the real event loop instead.
    await tester.runAsync(() async {
      await store.saveMedia(
        folderId,
        const MyBagFolderMedia(voice: [clip]),
      );
      await store.writeVoiceClip(folderId, clip.fileName, const [1, 2, 3]);
    });

    await tester.pumpWidget(app(_FakeRecorder(resultPath: clipPath), player));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-voice-play-v1')));
    await tester.pumpAndSettle();
    expect(player.openCalls, 1);
    expect(player.playCalls, 1);

    await tester.tap(find.byKey(const Key('bag-voice-play-v1')));
    await tester.pumpAndSettle();
    expect(player.pauseCalls, 1);
  });

  testWidgets('a vanished recording is shown, not crashed', (tester) async {
    const clip = MyBagVoiceClip(
      id: 'v2',
      fileName: 'v2.m4a',
      title: 'قديم',
      durationMs: 500,
      sizeBytes: 3,
      createdAtMs: 2,
      waveform: [10],
    );
    await tester.runAsync(
      () => store.saveMedia(folderId, const MyBagFolderMedia(voice: [clip])),
    );

    await tester.pumpWidget(
      app(_FakeRecorder(resultPath: clipPath), _FakePlayer()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bag-voice-missing-v2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bag-voice-play-v2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
