import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/audio_player_channel.dart';

void main() {
  group('AudioEventHub', () {
    test('opens the native stream once and fans it out per client', () async {
      final source = StreamController<Object?>.broadcast();
      var opens = 0;
      final hub = AudioEventHub(() {
        opens += 1;
        return source.stream;
      });
      final bag = <AudioPlaybackEvent>[];
      final resource = <AudioPlaybackEvent>[];
      final bagSub = hub.eventsFor('bag').listen(bag.add);
      final resourceSub = hub.eventsFor('resource').listen(resource.add);
      addTearDown(() async {
        await bagSub.cancel();
        await resourceSub.cancel();
        await source.close();
      });

      source.add({'clientId': 'bag', 'state': 'playing', 'positionMs': 10});
      source.add({'clientId': 'resource', 'state': 'paused', 'positionMs': 20});
      await Future<void>.delayed(Duration.zero);

      expect(opens, 1, reason: 'a second listen would take the first one');
      expect(bag.single.state, AudioPlayerState.playing);
      expect(bag.single.positionMs, 10);
      expect(resource.single.state, AudioPlayerState.paused);
      expect(resource.single.positionMs, 20);
    });

    test('drops payloads that belong to no client', () async {
      final source = StreamController<Object?>.broadcast();
      final hub = AudioEventHub(() => source.stream);
      final bag = <AudioPlaybackEvent>[];
      final sub = hub.eventsFor('bag').listen(bag.add);
      addTearDown(() async {
        await sub.cancel();
        await source.close();
      });

      source.add({'clientId': 'someone-else', 'state': 'playing'});
      source.add('not a map');
      source.add({'clientId': 'bag', 'state': 'completed'});
      await Future<void>.delayed(Duration.zero);

      expect(bag.single.state, AudioPlayerState.completed);
    });

    test('closes the native stream with its last client', () async {
      final source = StreamController<Object?>.broadcast();
      var opens = 0;
      final hub = AudioEventHub(() {
        opens += 1;
        return source.stream;
      });

      final first = hub.eventsFor('bag').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await first.cancel();
      await Future<void>.delayed(Duration.zero);

      final second = hub.eventsFor('bag').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(opens, 2, reason: 'a new screen must open a fresh subscription');

      await second.cancel();
      await source.close();
    });
  });
}
