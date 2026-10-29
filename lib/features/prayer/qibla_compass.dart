/// The drawn compass at the centre of the Qibla screen.
///
/// The bezel, cardinal rose and needle are all original vector drawings (no
/// image assets).  The rose rotates against the device heading so its
/// directions stay geographically true, while the needle points at the Qibla.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';

/// A compass that points from the device heading to [qiblaBearing].
///
/// [heading] is the continuous display heading; the screen accumulates it so
/// crossing 0°/360° does not make the rose spin the long way around.  Pass
/// `null` for a device without a magnetometer: the rose stays north-up and
/// the needle shows the Qibla bearing as a static arrow.
class QiblaCompassDial extends StatelessWidget {
  const QiblaCompassDial({
    super.key,
    required this.qiblaBearing,
    required this.heading,
    required this.aligned,
  });

  final double qiblaBearing;
  final double? heading;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final primary = theme.colorScheme.primary;
    final accent = theme.colorScheme.secondary;
    final needleColor = aligned ? ZakerColors.success : primary;
    // The disc under the kaaba is primary-filled, which is gold in two of the
    // four palettes: white on gold is 2.10:1 and 1.74:1 there, while onPrimary
    // is 9.36:1 and 9.57:1. The aligned disc stays green with white on it.
    final discInk = aligned ? Colors.white : theme.colorScheme.onPrimary;
    final isStatic = heading == null;
    final displayHeading = heading ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 320.0;
        final side = math.min(availableWidth, availableHeight);
        return RepaintBoundary(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  width: side * 0.9,
                  height: side * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: isDark ? 0.05 : 0.035),
                    boxShadow: aligned
                        ? [
                            BoxShadow(
                              color: ZakerColors.success.withValues(alpha: 0.3),
                              blurRadius: 26,
                              spreadRadius: 1,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: primary.withValues(
                                alpha: isDark ? 0.10 : 0.07,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BezelPainter(
                      ink: ink,
                      muted: muted,
                      primary: primary,
                      aligned: aligned,
                      staticMode: isStatic,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedRotation(
                    turns: -displayHeading / 360,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: CustomPaint(
                      painter: _RosePainter(
                        ink: ink,
                        muted: muted,
                        primary: primary,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedRotation(
                    turns: (qiblaBearing - displayHeading) / 360,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: CustomPaint(
                      painter: _NeedlePainter(
                        color: needleColor,
                        tail: muted,
                        accent: accent,
                        aligned: aligned,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: side * 0.135,
                  height: side * 0.135,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: aligned
                          ? const [ZakerColors.success, Color(0xFF15803D)]
                          // Darkening within the hue, not toward the navy, so
                          // one ink stays legible on both ends of the disc.
                          : [primary, Color.lerp(primary, Colors.black, 0.28)!],
                    ),
                    border: Border.all(
                      color: discInk.withValues(alpha: 0.85),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedKaaba01,
                      size: side * 0.072,
                      color: discInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The static bezel: rings, the alignment arc and the "top of the phone"
/// index.  It never rotates, so the arc always frames the screen's top.
class _BezelPainter extends CustomPainter {
  const _BezelPainter({
    required this.ink,
    required this.muted,
    required this.primary,
    required this.aligned,
    required this.staticMode,
  });

  final Color ink;
  final Color muted;
  final Color primary;
  final bool aligned;
  final bool staticMode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;

    canvas.drawCircle(
      center,
      radius * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = muted.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      center,
      radius * 0.70,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = muted.withValues(alpha: 0.12),
    );

    if (!staticMode) {
      final arcRadius = radius * 0.94;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        -math.pi / 2 - 0.10,
        0.20,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = (aligned ? ZakerColors.success : primary).withValues(
            alpha: aligned ? 0.95 : 0.45,
          ),
      );
    }

    // Index at the top of the phone: the direction the device is pointing.
    final index = Path()
      ..moveTo(center.dx, center.dy - radius + radius * 0.055)
      ..lineTo(center.dx - radius * 0.045, center.dy - radius)
      ..lineTo(center.dx + radius * 0.045, center.dy - radius)
      ..close();
    canvas.drawPath(index, Paint()..color = primary.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant _BezelPainter oldDelegate) {
    return oldDelegate.ink != ink ||
        oldDelegate.muted != muted ||
        oldDelegate.primary != primary ||
        oldDelegate.aligned != aligned ||
        oldDelegate.staticMode != staticMode;
  }
}

/// The rotating rose: ticks and Arabic cardinal labels.
class _RosePainter extends CustomPainter {
  const _RosePainter({
    required this.ink,
    required this.muted,
    required this.primary,
  });

  final Color ink;
  final Color muted;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;

    for (var index = 0; index < 72; index++) {
      final degrees = index * 5.0;
      final angle = degrees * math.pi / 180;
      final major = index % 18 == 0;
      final medium = index % 6 == 0;
      final inner = major ? 0.80 : (medium ? 0.845 : 0.875);
      final outer = 0.92;
      final start = center + _polar(radius * inner, angle);
      final end = center + _polar(radius * outer, angle);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = major ? 2.0 : (medium ? 1.4 : 0.9)
          ..strokeCap = StrokeCap.round
          ..color = major
              ? primary.withValues(alpha: 0.85)
              : muted.withValues(alpha: medium ? 0.55 : 0.3),
      );
    }

    const cardinals = <int, String>{
      0: 'شمال',
      90: 'شرق',
      180: 'جنوب',
      270: 'غرب',
    };
    for (final entry in cardinals.entries) {
      final angle = entry.key * math.pi / 180;
      final isNorth = entry.key == 0;
      final painter = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: radius * 0.085,
            fontWeight: FontWeight.w800,
            color: isNorth ? primary : ink.withValues(alpha: 0.62),
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout();
      final anchor = center + _polar(radius * 0.72, angle);
      painter.paint(
        canvas,
        Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RosePainter oldDelegate) {
    return oldDelegate.ink != ink ||
        oldDelegate.muted != muted ||
        oldDelegate.primary != primary;
  }
}

/// The Qibla needle: a tapered pointer with a small Kaaba at its tip.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter({
    required this.color,
    required this.tail,
    required this.accent,
    required this.aligned,
  });

  final Color color;
  final Color tail;
  final Color accent;
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final tip = center + Offset(0, -radius * 0.65);

    final pointer = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(center.dx - radius * 0.072, center.dy)
      ..lineTo(center.dx + radius * 0.072, center.dy)
      ..close();

    // Soft glow, then the pointer body and a crisp outline.
    canvas.drawPath(
      pointer,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      pointer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            Color.lerp(color, Colors.black, aligned ? 0.05 : 0.22) ?? color,
          ],
        ).createShader(Rect.fromPoints(tip, Offset(center.dx, center.dy))),
    );
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.75),
    );

    // Tail.
    final tailPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx - radius * 0.048, center.dy + radius * 0.26)
      ..lineTo(center.dx + radius * 0.048, center.dy + radius * 0.26)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = tail.withValues(alpha: 0.28));

    // Kaaba at the tip: a golden dot with a tiny cube and its kiswa band.
    canvas.drawCircle(
      tip,
      radius * 0.055,
      Paint()..color = accent.withValues(alpha: 0.22),
    );
    canvas.drawCircle(tip, radius * 0.038, Paint()..color = accent);
    final cube = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: tip,
        width: radius * 0.034,
        height: radius * 0.034,
      ),
      Radius.circular(radius * 0.006),
    );
    canvas.drawRRect(cube, Paint()..color = const Color(0xFF1F2937));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(tip.dx, tip.dy - radius * 0.007),
        width: radius * 0.034,
        height: radius * 0.007,
      ),
      Paint()..color = const Color(0xFFFDE68A),
    );
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.tail != tail ||
        oldDelegate.accent != accent ||
        oldDelegate.aligned != aligned;
  }
}

Offset _polar(double radius, double angleFromNorth) {
  return Offset(
    math.sin(angleFromNorth) * radius,
    -math.cos(angleFromNorth) * radius,
  );
}
