import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/features/bag/widgets/bag_waveform.dart';

void main() {
  group('waveform geometry follows the text direction', () {
    test('a tap near the start is the start of the clip in both directions',
        () {
      expect(
        waveformSeekFraction(dx: 20, width: 200, rtl: false),
        closeTo(0.1, 1e-9),
      );
      expect(
        waveformSeekFraction(dx: 20, width: 200, rtl: true),
        closeTo(0.9, 1e-9),
      );
    });

    test('a tap clamps outside the strip', () {
      expect(waveformSeekFraction(dx: -5, width: 200, rtl: false), 0);
      expect(waveformSeekFraction(dx: 400, width: 200, rtl: false), 1);
      expect(waveformSeekFraction(dx: 5, width: 0, rtl: false), 0);
    });

    test('the playhead starts at the right edge in RTL', () {
      expect(waveformPlayheadX(width: 200, progress: 0, rtl: true), 200);
      expect(waveformPlayheadX(width: 200, progress: 0.25, rtl: true), 150);
      expect(waveformPlayheadX(width: 200, progress: 0.25, rtl: false), 50);
    });

    test('nothing is played at progress 0, in either direction', () {
      for (final rtl in [false, true]) {
        final playhead = waveformPlayheadX(width: 200, progress: 0, rtl: rtl);
        for (final center in [5.0, 100.0, 195.0]) {
          expect(
            waveformBarIsPlayed(center: center, playheadX: playhead, rtl: rtl),
            isFalse,
            reason: 'rtl=$rtl center=$center',
          );
        }
      }
    });

    test('in RTL the bars right of the playhead are the played ones', () {
      final playhead = waveformPlayheadX(width: 200, progress: 0.5, rtl: true);
      expect(
        waveformBarIsPlayed(center: 150, playheadX: playhead, rtl: true),
        isTrue,
      );
      expect(
        waveformBarIsPlayed(center: 50, playheadX: playhead, rtl: true),
        isFalse,
      );
    });
  });

  testWidgets('tapping the RTL strip reports the fraction from the start', (
    tester,
  ) async {
    double? seeked;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 200,
            child: BagWaveform(
              samples: const [50, 60, 70, 80],
              progress: 0,
              onSeek: (value) => seeked = value,
            ),
          ),
        ),
      ),
    );

    final topLeft = tester.getTopLeft(find.byType(BagWaveform));
    await tester.tapAt(topLeft + const Offset(20, 18));

    expect(seeked, isNotNull);
    expect(seeked!, closeTo(0.9, 0.02));
  });
}
