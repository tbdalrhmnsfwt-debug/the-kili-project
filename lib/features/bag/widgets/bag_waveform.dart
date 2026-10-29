/// A saved waveform strip with a playhead.
///
/// The samples are already on a 0..100 scale (`downsampleWaveform`), so this
/// widget paints and never scales: passing a new list paints a new strip.
library;

import 'package:flutter/material.dart';

import '../../../core/localization.dart';

/// Where a tap at [dx] falls on the clip, with the bar order mirrored in RTL.
double waveformSeekFraction({
  required double dx,
  required double width,
  required bool rtl,
}) {
  if (width <= 0) return 0;
  final fromLeft = dx / width;
  final fraction = rtl ? 1 - fromLeft : fromLeft;
  return fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0;
}

/// The playhead's x, measured from the left edge, for [progress] on [width].
///
/// In RTL the bars run right-to-left, so the playhead starts at the right
/// edge and moves left as the clip plays.
double waveformPlayheadX({
  required double width,
  required double progress,
  required bool rtl,
}) {
  final value = rtl ? 1 - progress : progress;
  return value * width;
}

/// Whether a bar centered at [center] sits behind the playhead.
bool waveformBarIsPlayed({
  required double center,
  required double playheadX,
  required bool rtl,
}) =>
    rtl ? center >= playheadX : center <= playheadX;

class BagWaveform extends StatelessWidget {
  const BagWaveform({
    super.key,
    required this.samples,
    required this.progress,
    this.onSeek,
    this.height = 36,
  });

  /// Bar heights on a 0..100 scale, oldest bar first.
  final List<int> samples;

  /// Playhead as a fraction of the clip, clamped to 0..1.
  final double progress;

  /// Called with a 0..1 fraction when the student taps the strip.
  final ValueChanged<double>? onSeek;

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final played = theme.colorScheme.primary;
    final idle = theme.colorScheme.primary.withValues(alpha: 0.28);
    final value = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      label: context.tr('شريط الصوت'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onSeek == null
                ? null
                : (details) => onSeek!(
                      waveformSeekFraction(
                        dx: details.localPosition.dx,
                        width: width,
                        rtl: rtl,
                      ),
                    ),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: CustomPaint(
                painter: _WaveformPainter(
                  samples: samples,
                  progress: value,
                  played: played,
                  idle: idle,
                  rtl: rtl,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.played,
    required this.idle,
    required this.rtl,
  });

  final List<int> samples;
  final double progress;
  final Color played;
  final Color idle;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height / 2 - 1, size.width, 2),
        Paint()..color = idle,
      );
      return;
    }

    const gap = 2.0;
    final slot = size.width / samples.length;
    final barWidth = (slot - gap).clamp(1.0, 6.0);
    final playhead = waveformPlayheadX(
      width: size.width,
      progress: progress,
      rtl: rtl,
    );
    final face = Paint()..style = PaintingStyle.fill;
    final radius = Radius.circular(barWidth / 2);

    for (var index = 0; index < samples.length; index++) {
      final fraction = (samples[index] / 100).clamp(0.0, 1.0);
      final barHeight = (size.height * fraction).clamp(2.0, size.height);
      final center = slot * index + slot / 2;
      final left =
          rtl ? size.width - center - barWidth / 2 : center - barWidth / 2;
      final top = (size.height - barHeight) / 2;
      face.color = waveformBarIsPlayed(
        center: center,
        playheadX: playhead,
        rtl: rtl,
      )
          ? played
          : idle;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, barHeight),
          radius,
        ),
        face,
      );
    }

    canvas.drawLine(
      Offset(playhead, 0),
      Offset(playhead, size.height),
      Paint()
        ..color = played
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.progress != progress ||
      oldDelegate.played != played ||
      oldDelegate.idle != idle ||
      oldDelegate.rtl != rtl;
}
