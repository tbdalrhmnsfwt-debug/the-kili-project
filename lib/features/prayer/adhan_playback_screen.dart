/// The full-screen adhan.
///
/// Android launches this screen from the adhan notification while the phone
/// is locked (`fullScreenIntent`), and tapping an adhan notification opens it
/// at any other time.  The recording itself is played by a native foreground
/// service, so it keeps going when the screen is off or the app goes to the
/// background; [stop] ends both the sound and the service.
///
/// The mosque scene is drawn in code (no image assets), following the app's
/// Cairo/Hugeicons/RTL theme in both light and dark mode.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/adhan_voices.dart';
import '../../core/notification_service.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'prayer_models.dart';

class AdhanPlaybackScreen extends StatefulWidget {
  const AdhanPlaybackScreen({
    super.key,
    required this.prayerName,
    this.time,
    this.city = '',
    this.voiceId,
    this.notificationId,
  });

  /// The `PrayerName.name` of the prayer being called, e.g. `fajr`.
  final String prayerName;

  /// When the prayer starts, shown under the name.
  final DateTime? time;

  /// The saved city (or coordinates) shown at the top.
  final String city;

  /// The recording to play.
  final String? voiceId;

  /// The notification to cancel once this screen owns the audio.
  final int? notificationId;

  @override
  State<AdhanPlaybackScreen> createState() => _AdhanPlaybackScreenState();
}

class _AdhanPlaybackScreenState extends State<AdhanPlaybackScreen> {
  bool? _playing;
  bool _stopping = false;

  PrayerName get _prayer => PrayerName.values.firstWhere(
    (prayer) => prayer.name == widget.prayerName,
    orElse: () => PrayerName.dhuhr,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  @override
  void dispose() {
    // Leaving the screen — by the stop button, the back gesture or the close
    // button — always ends the foreground playback.
    unawaited(AdhanPlatform.stopPlayback());
    super.dispose();
  }

  Future<void> _start() async {
    final voice = adhanVoiceById(widget.voiceId);
    final started = await AdhanPlatform.startPlayback(
      resource: voice.resource,
      assetPath: voice.assetPath,
      title: _prayer.invocation,
      notificationId: widget.notificationId,
    );
    final notificationId = widget.notificationId;
    if (started && notificationId != null) {
      // The foreground player owns the audio now; drop the notification so
      // its own channel sound cannot overlap it.
      unawaited(
        NotificationService.instance.cancelNotification(notificationId),
      );
    }
    if (!mounted) return;
    setState(() => _playing = started);
  }

  Future<void> _stop() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    await AdhanPlatform.stopPlayback();
    final notificationId = widget.notificationId;
    if (notificationId != null) {
      await NotificationService.instance.cancelNotification(notificationId);
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  String get _timeText {
    final time = widget.time?.toLocal();
    if (time == null) return '';
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'ص' : 'م'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = isDark ? Colors.white : theme.colorScheme.onSurface;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : theme.colorScheme.onSurfaceVariant;
    final accent = isDark
        ? const Color(0xFFFBD38D)
        : theme.colorScheme.tertiary;
    final background = isDark
        ? const <Color>[Color(0xFF041E1C), Color(0xFF0B3A35), Color(0xFF031514)]
        : const <Color>[
            Color(0xFFFDF7E9),
            Color(0xFFE4F4ED),
            Color(0xFFF6FBF8),
          ];
    final mosque = isDark
        ? const Color(0xFF021413).withValues(alpha: 0.88)
        : theme.colorScheme.primary.withValues(alpha: 0.16);
    final windows = isDark
        ? accent.withValues(alpha: 0.55)
        : theme.colorScheme.primary.withValues(alpha: 0.30);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: background,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MosquePainter(
                  silhouette: mosque,
                  window: windows,
                  accent: accent,
                  stars: isDark,
                  horizon: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : theme.colorScheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.city.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ink.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedMapPin,
                                  size: 15,
                                  color: accent,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: TrText(
                                    widget.city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: ink.withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: _stopping ? null : _stop,
                        icon: Icon(
                          Icons.close_rounded,
                          color: ink.withValues(alpha: 0.75),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  TrText(
                    'حان الآن وقت',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TrText(
                    _prayer.invocation,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      height: 1.15,
                    ),
                  ),
                  if (_timeText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _timeText,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: ink.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w700,
                        fontSize: 27,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _PlayingStatus(
                    playing: _playing,
                    ink: ink,
                    muted: muted,
                    accent: accent,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _stopping ? null : _stop,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedStopCircle,
                        size: 23,
                        color: Colors.white,
                      ),
                      label: const TrText('إيقاف الأذان'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ZakerColors.danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet status line: animated bars while the adhan plays, a warning when
/// the platform could not start the player.
class _PlayingStatus extends StatelessWidget {
  const _PlayingStatus({
    required this.playing,
    required this.ink,
    required this.muted,
    required this.accent,
  });

  final bool? playing;
  final Color ink;
  final Color muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = playing == false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed)
          Icon(Icons.volume_off_rounded, size: 17, color: muted)
        else
          _SoundBars(color: accent),
        const SizedBox(width: 8),
        Flexible(
          child: TrText(
            failed
                ? 'مش قادرين نشغّل الصوت — اتأكد إن صوت الوسائط مفتوح.'
                : 'الصوت شغال',
            style: theme.textTheme.bodySmall?.copyWith(
              color: failed ? muted : ink.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoundBars extends StatefulWidget {
  const _SoundBars({required this.color});

  final Color color;

  @override
  State<_SoundBars> createState() => _SoundBarsState();
}

class _SoundBarsState extends State<_SoundBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < 4; index++)
                _bar(
                  index,
                  (math.sin((_controller.value + index * 0.22) * math.pi * 2) +
                          1) /
                      2,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(int index, double phase) {
    // A little variety between the four bars.
    final height = 4 + 11 * phase * (0.55 + (index % 2) * 0.35);
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// The mosque scene: a crescent and stars in the sky, a central dome with two
/// minarets, and three lit arches.  Drawn entirely with paths so the same
/// illustration works in light and dark mode at any screen size.
class _MosquePainter extends CustomPainter {
  const _MosquePainter({
    required this.silhouette,
    required this.window,
    required this.accent,
    required this.stars,
    required this.horizon,
  });

  final Color silhouette;
  final Color window;
  final Color accent;
  final bool stars;
  final Color horizon;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseline = h * 0.985;
    final random = math.Random(7);

    // Sky.
    if (stars) {
      final sky = Paint()..color = Colors.white;
      for (var index = 0; index < 46; index++) {
        final x = random.nextDouble() * w;
        final y = random.nextDouble() * h * 0.52;
        final radius = 0.5 + random.nextDouble() * 1.2;
        sky.color = Colors.white.withValues(
          alpha: 0.14 + random.nextDouble() * 0.36,
        );
        canvas.drawCircle(Offset(x, y), radius, sky);
      }
    }

    // Crescent.
    final crescent = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.14, h * 0.13), radius: 21))
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.14 + 9, h * 0.13 - 5), radius: 19),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      crescent,
      Paint()..color = accent.withValues(alpha: stars ? 0.92 : 0.55),
    );

    // Soft glow behind the dome.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.80),
      w * 0.30,
      Paint()
        ..color = accent.withValues(alpha: stars ? 0.10 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );

    final body = Paint()..color = silhouette;
    final lit = Paint()..color = window;

    // Ground.
    canvas.drawRect(
      Rect.fromLTRB(0, baseline, w, h),
      Paint()..color = silhouette.withValues(alpha: 0.55),
    );
    canvas.drawLine(
      Offset(0, baseline),
      Offset(w, baseline),
      Paint()
        ..color = horizon
        ..strokeWidth = 1.2,
    );

    // Minarets.
    _minaret(canvas, body, lit, w * 0.155, w * 0.048, h * 0.62, baseline);
    _minaret(
      canvas,
      body,
      lit,
      w * 0.845 - w * 0.048,
      w * 0.048,
      h * 0.62,
      baseline,
    );

    // Main hall.
    final hall = Rect.fromLTRB(w * 0.27, h * 0.78, w * 0.73, baseline);
    canvas.drawRect(hall, body);

    // Side wings.
    final wing = Rect.fromLTRB(w * 0.20, h * 0.84, w * 0.80, baseline);
    canvas.drawRect(wing, body);

    // Central dome.
    final dome = Rect.fromLTRB(w * 0.30, h * 0.66, w * 0.70, h * 0.80);
    canvas.drawArc(dome, math.pi, math.pi, true, body);
    // Drum under the dome.
    canvas.drawRect(
      Rect.fromLTRB(w * 0.30, h * 0.78, w * 0.70, h * 0.80),
      body,
    );
    // Finial.
    final finial = Paint()
      ..color = accent.withValues(alpha: stars ? 0.8 : 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.66),
      Offset(w * 0.5, h * 0.62),
      finial,
    );
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.615),
      3,
      Paint()..color = accent.withValues(alpha: stars ? 0.85 : 0.55),
    );

    // Three lit arches on the hall.
    for (final centerX in [w * 0.385, w * 0.5, w * 0.615]) {
      _arch(canvas, lit, centerX, h * 0.82, w * 0.062, h * 0.075);
    }

    // Door.
    _arch(canvas, lit, w * 0.5, h * 0.895, w * 0.085, h * 0.075);

    // Balcony lines on the minarets.
    for (final x in [w * 0.155, w * 0.845 - w * 0.048]) {
      canvas.drawRect(
        Rect.fromLTRB(
          x - w * 0.008,
          h * 0.69,
          x + w * 0.048 + w * 0.008,
          h * 0.697,
        ),
        body,
      );
      canvas.drawCircle(
        Offset(x + w * 0.024, h * 0.62),
        w * 0.011,
        Paint()..color = accent.withValues(alpha: stars ? 0.65 : 0.38),
      );
    }
  }

  void _minaret(
    Canvas canvas,
    Paint body,
    Paint lit,
    double left,
    double width,
    double top,
    double baseline,
  ) {
    canvas.drawRect(Rect.fromLTRB(left, top, left + width, baseline), body);
    // Dome cap.
    canvas.drawArc(
      Rect.fromLTRB(
        left - width * 0.18,
        top - width * 0.9,
        left + width * 1.18,
        top + width * 0.2,
      ),
      math.pi,
      math.pi,
      true,
      body,
    );
    // A thin lit slit.
    canvas.drawRect(
      Rect.fromLTRB(
        left + width * 0.38,
        top + width * 0.9,
        left + width * 0.62,
        top + width * 2.3,
      ),
      lit,
    );
  }

  void _arch(
    Canvas canvas,
    Paint paint,
    double centerX,
    double baseY,
    double width,
    double height,
  ) {
    final path = Path()
      ..moveTo(centerX - width / 2, baseY)
      ..lineTo(centerX - width / 2, baseY - height * 0.55)
      ..quadraticBezierTo(
        centerX - width / 2,
        baseY - height,
        centerX,
        baseY - height,
      )
      ..quadraticBezierTo(
        centerX + width / 2,
        baseY - height,
        centerX + width / 2,
        baseY - height * 0.55,
      )
      ..lineTo(centerX + width / 2, baseY)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MosquePainter oldDelegate) {
    return oldDelegate.silhouette != silhouette ||
        oldDelegate.window != window ||
        oldDelegate.accent != accent ||
        oldDelegate.stars != stars ||
        oldDelegate.horizon != horizon;
  }
}
