/// Shared visual pieces for the azkar feature.
///
/// The look stays inside the app's Cairo / Hugeicons / teal system, but the
/// azkar screens add their own quiet arch-and-star motif.  The motif is drawn
/// with paths, so it works in light and dark mode and at any size without
/// image assets.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';

/// A rounded surface used by the azkar cards and settings groups.
class AzkarSurface extends StatelessWidget {
  const AzkarSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZakerSpacing.lg),
    this.color,
    this.gradient,
    this.borderColor,
    this.onTap,
    this.radius = 22,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border =
        borderColor ??
        (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.07));
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border),
    );
    final content = Padding(padding: padding, child: child);
    return Material(
      color: gradient == null
          ? (color ?? (isDark ? const Color(0xFF1E293B) : Colors.white))
          : Colors.transparent,
      shape: shape,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: gradient == null ? null : Border.all(color: border),
        ),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: content,
              ),
      ),
    );
  }
}

/// The wide opening card used by the home, tasbih and salat screens.
class AzkarHero extends StatelessWidget {
  const AzkarHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 18),
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? ZakerColors.primaryLight : ZakerColors.primary;
    final ink = isDark ? Colors.white : theme.colorScheme.onSurface;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : theme.colorScheme.onSurfaceVariant;
    final gradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: isDark
          ? const <Color>[Color(0xFF123B37), Color(0xFF0F2029)]
          : const <Color>[Color(0xFFE2F5EF), Color(0xFFF8FAFC)],
    );

    return AzkarSurface(
      gradient: gradient,
      borderColor: primary.withValues(alpha: isDark ? 0.28 : 0.16),
      padding: EdgeInsets.zero,
      radius: 26,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: AzkarPatternPainter(
                  color: primary,
                  accent: ZakerColors.accent,
                  isDark: isDark,
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Eyebrow(text: eyebrow, color: primary),
                          const SizedBox(height: 10),
                          TrText(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 25,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TrText(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 12,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: isDark ? 0.22 : 0.11),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primary.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(icon: icon, size: 26, color: primary),
                      ),
                    ),
                  ],
                ),
                if (footer != null) ...[const SizedBox(height: 16), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: TrText(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            height: 1.4,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// A small section heading with an icon and an optional trailing action.
class AzkarSectionHeader extends StatelessWidget {
  const AzkarSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final List<List<dynamic>> icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 18, color: primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TrText(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// An explicit, clearly labelled placeholder when the bundled JSON cannot be
/// read.  It never falls back to invented azkar text.
class AzkarPlaceholder extends StatelessWidget {
  const AzkarPlaceholder({super.key, this.detail, this.compact = false});

  final String? detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    return AzkarSurface(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
      borderColor: ZakerColors.accent.withValues(alpha: 0.38),
      padding: EdgeInsets.all(compact ? 16 : 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ZakerColors.accent.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              color: ZakerColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          TrText(
            'بيانات الأذكار غير متوفرة',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          TrText(
            'التطبيق محتاج ملف assets/data/azkar.json عشان يعرض أذكار الصباح والمساء. '
            'مفيش نص بديل مكتوب من عندنا.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: muted,
              fontSize: 11,
              height: 1.6,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: primary.withValues(alpha: 0.76),
                fontSize: 9,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A slim status pill (e.g. «العداد محفوظ»).
class AzkarPill extends StatelessWidget {
  const AzkarPill({
    super.key,
    required this.label,
    required this.icon,
    this.color,
  });

  final String label;
  final List<List<dynamic>> icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(color: tint.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 13, color: tint),
          const SizedBox(width: 5),
          Flexible(
            child: TrText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ornamental progress dial used by the tasbih and salat counters.
class AzkarProgressDial extends StatelessWidget {
  const AzkarProgressDial({
    super.key,
    required this.progress,
    required this.child,
    this.size = 272,
    this.color,
    this.background,
  });

  /// 0–1.
  final double progress;
  final Widget child;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = color ?? theme.colorScheme.primary;
    final track =
        background ??
        (isDark
            ? Colors.white.withValues(alpha: 0.09)
            : Colors.black.withValues(alpha: 0.06));
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _DialPainter(
              progress: value,
              color: primary,
              track: track,
              accent: isDark ? const Color(0xFFFBD38D) : ZakerColors.accent,
              isDark: isDark,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(size * 0.15),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.accent,
    required this.isDark,
  });

  final double progress;
  final Color color;
  final Color track;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 13;
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    // Faint halo.
    canvas.drawCircle(
      center,
      radius + 10,
      Paint()..color = color.withValues(alpha: isDark ? 0.07 : 0.05),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    if (progress > 0) {
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }

    // Tick marks just outside the ring.
    final tickPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.24 : 0.18)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 48; i++) {
      final angle = (math.pi * 2 / 48) * i - math.pi / 2;
      final long = i % 4 == 0;
      final inner = radius + 17;
      final outer = inner + (long ? 7 : 3.5);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }

    // A small eight-point star at the top, echoing the app's arch motif.
    final star = Path();
    const points = 8;
    const outerRadius = 7.0;
    const innerRadius = 3.0;
    final starCenter = Offset(center.dx, 7);
    for (var i = 0; i < points * 2; i++) {
      final radiusAt = i.isEven ? outerRadius : innerRadius;
      final angle = (math.pi / points) * i - math.pi / 2;
      final point =
          starCenter + Offset(math.cos(angle), math.sin(angle)) * radiusAt;
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = accent.withValues(alpha: 0.92));
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.track != track ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark;
  }
}

/// The arch, stars and concentric rings behind the hero cards.
class AzkarPatternPainter extends CustomPainter {
  const AzkarPatternPainter({
    required this.color,
    required this.accent,
    required this.isDark,
  });

  final Color color;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final halo = Paint()
      ..color = color.withValues(alpha: isDark ? 0.08 : 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(w * 0.91, h * 0.18), w * 0.11 * i, halo);
    }

    // A tall arch on the left, like a quiet mihrab outline.
    final arch = Path()
      ..moveTo(w * 0.08, h)
      ..lineTo(w * 0.08, h * 0.40)
      ..quadraticBezierTo(w * 0.08, h * 0.22, w * 0.20, h * 0.22)
      ..quadraticBezierTo(w * 0.32, h * 0.22, w * 0.32, h * 0.40)
      ..lineTo(w * 0.32, h);
    canvas.drawPath(
      arch,
      Paint()
        ..color = color.withValues(alpha: isDark ? 0.16 : 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Small stars scattered in the free area.
    final starPaint = Paint()..color = accent.withValues(alpha: 0.28);
    for (final spot in <Offset>[
      Offset(w * 0.69, h * 0.20),
      Offset(w * 0.80, h * 0.62),
      Offset(w * 0.60, h * 0.78),
    ]) {
      canvas.drawPath(_star(spot, 4.5), starPaint);
    }

    final dot = Paint()..color = color.withValues(alpha: 0.22);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(w * (0.54 + i * 0.075), h * 0.48), 1.2, dot);
    }
  }

  Path _star(Offset center, double outer) {
    final path = Path();
    const points = 8;
    final inner = outer * 0.42;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = (math.pi / points) * i - math.pi / 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant AzkarPatternPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark;
  }
}
