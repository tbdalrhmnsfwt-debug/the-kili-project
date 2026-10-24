/// The shared premium visuals: the animated aurora assistant mark, the
/// rounded glass icon tile used by feature cards, a shimmering skeleton and
/// the press-scale wrapper.
///
/// Everything here is drawn in code, clipped to the same radii as the cards,
/// and respects the system's reduced-motion setting. Painters are kept inside
/// a [RepaintBoundary] so a moving gradient never repaints its neighbours.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/theme.dart';

/// The original voice of the assistant: violet, blue, teal and pink silk
/// waves with a four-point sparkle.
///
/// The loop is ten seconds. Under reduce-motion it paints one still frame,
/// and the [AnimationController]'s ticker is muted automatically whenever the
/// widget is off-screen.
class AuroraAssistantMark extends StatefulWidget {
  const AuroraAssistantMark({
    super.key,
    this.size = 54,
    this.radius = 18,
    this.semanticLabel = 'شعار المساعد الذكي',
  });

  final double size;
  final double radius;
  final String semanticLabel;

  @override
  State<AuroraAssistantMark> createState() => _AuroraAssistantMarkState();
}

class _AuroraAssistantMarkState extends State<AuroraAssistantMark>
    with SingleTickerProviderStateMixin {
  static const Duration _loop = Duration(seconds: 10);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _loop,
  );

  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.of(context).disableAnimations;
    if (_reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: Size.square(widget.size),
                painter: _AuroraPainter(
                  progress: _reduced ? 0 : _controller.value,
                  radius: widget.radius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({required this.progress, required this.radius});

  final double progress;
  final double radius;

  static const List<Color> _palette = [
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFF0D9488),
    Color(0xFFDB2777),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final short = size.shortestSide;
    final phase = progress * math.pi * 2;

    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: _palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    // Three silk bands drifting at different speeds.
    _band(canvas, size, phase * 1.0, 0.60, const Color(0x3DFFFFFF), 0.11);
    _band(
      canvas,
      size,
      phase * 1.35 + 1.7,
      0.76,
      const Color(0x33FDE68A),
      0.09,
    );
    _band(canvas, size, phase * 0.8 + 3.4, 0.88, const Color(0x2EFFFFFF), 0.07);

    // A soft diagonal sheen.
    final sheen = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final sheenX = -short * 0.8 + (progress * short * 1.6);
    canvas.save();
    canvas.translate(sheenX, 0);
    canvas.transform(Matrix4.skewX(-0.35).storage);
    canvas.drawRect(Rect.fromLTWH(0, -short, short * 0.34, short * 3), sheen);
    canvas.restore();

    // Ambient glow behind the sparkle, drawn as cheap translucent rings.
    final center = Offset(size.width / 2, size.height / 2);
    final glow = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(center, short * 0.36, glow);
    canvas.drawCircle(
      center,
      short * 0.27,
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    _sparkle(canvas, center, short * 0.23, 1);
    _sparkle(
      canvas,
      Offset(size.width * 0.80, size.height * 0.22),
      short * 0.085,
      0.72,
    );

    canvas.restore();

    canvas.drawRRect(
      rrect.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.30),
    );
  }

  void _band(
    Canvas canvas,
    Size size,
    double phase,
    double yBase,
    Color color,
    double amplitude,
  ) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h * (yBase + math.sin(phase) * amplitude))
      ..cubicTo(
        w * 0.28,
        h * (yBase - amplitude * 1.6 + math.cos(phase) * amplitude),
        w * 0.56,
        h * (yBase + amplitude * 1.8 + math.sin(phase + 1.2) * amplitude),
        w,
        h * (yBase + math.cos(phase + 0.6) * amplitude),
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// A four-point sparkle made of four concave curves.
  void _sparkle(Canvas canvas, Offset center, double radius, double alpha) {
    final inner = radius * 0.13;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + inner,
        center.dy - inner,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + inner,
        center.dy + inner,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - inner,
        center.dy + inner,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - inner,
        center.dy - inner,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.radius != radius;
  }
}

/// A rounded glass tile for one feature icon: tinted gradient, inner
/// highlight, hairline border and two layers of shadow.
class ZakerGlassIcon extends StatelessWidget {
  const ZakerGlassIcon({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 46,
    this.iconSize = 23,
    this.radius = ZakerRadius.md,
  });

  final dynamic icon;
  final Color accent;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.brightness == Brightness.dark
        ? Color.lerp(accent, Colors.white, 0.32)!
        : accent;
    return _GlassTile(
      accent: tint,
      size: size,
      radius: radius,
      child: HugeIcon(icon: icon, size: iconSize, color: tint),
    );
  }
}

/// The same glass tile for Material [IconData] glyphs, so the older feature
/// grids match the newer cards.
class ZakerGlassGlyph extends StatelessWidget {
  const ZakerGlassGlyph({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 46,
    this.iconSize = 23,
    this.radius = ZakerRadius.md,
  });

  final IconData icon;
  final Color accent;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.brightness == Brightness.dark
        ? Color.lerp(accent, Colors.white, 0.32)!
        : accent;
    return _GlassTile(
      accent: tint,
      size: size,
      radius: radius,
      child: Icon(icon, size: iconSize, color: tint),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({
    required this.accent,
    required this.size,
    required this.radius,
    required this.child,
  });

  final Color accent;
  final double size;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.cardTheme.color ?? theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.34 : 0.22),
              surface,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.14 : 0.07),
              surface,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.28 : 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 1,
            right: 1,
            top: 1,
            height: size * 0.46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.18 : 0.46),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius - 1),
                ),
              ),
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

/// A shimmering placeholder block. Used instead of a spinner while a screen
/// loads. Under reduce-motion it stays at a single opacity.
class ZakerSkeleton extends StatefulWidget {
  const ZakerSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = ZakerRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<ZakerSkeleton> createState() => _ZakerSkeletonState();
}

class _ZakerSkeletonState extends State<ZakerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.of(context).disableAnimations;
    if (_reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget block(double t) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10 + 0.10 * t),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }

    if (_reduced) return block(0.5);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          block(Curves.easeInOut.transform(_controller.value)),
    );
  }
}

/// Scales its child to 0.97 while a pointer is down. It does not handle the
/// tap itself, so the wrapped [InkWell] keeps its ripple and its callback.
class ZakerPressScale extends StatefulWidget {
  const ZakerPressScale({super.key, required this.child});

  final Widget child;

  @override
  State<ZakerPressScale> createState() => _ZakerPressScaleState();
}

class _ZakerPressScaleState extends State<ZakerPressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final scale = _pressed && !reduce ? 0.97 : 1.0;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: scale,
        duration: Duration(milliseconds: reduce ? 0 : 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
