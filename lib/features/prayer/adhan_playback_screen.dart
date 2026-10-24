/// The full-screen adhan.
///
/// Android launches this screen from the adhan notification while the phone
/// is locked (`fullScreenIntent`), and tapping an adhan notification opens it
/// at any other time.  The recording itself is played by a native foreground
/// service, so it keeps going while this screen is in front or the app is in
/// the background; the screen's controls stop it, mute it, snooze it, or mark
/// the prayer as prayed.
///
/// The mosque scene is drawn in code with per-prayer palettes: Fajr is
/// blue-violet, Dhuhr a bright sky, Asr golden, Maghrib orange and Isha deep
/// night.  Motion — drifting clouds, twinkling stars, the halo behind the
/// clock — is disabled when the system asks for reduced motion.  The scene is
/// wrapped in a [RepaintBoundary] and painted on its own layer, so the live
/// clock does not repaint it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adhan_platform.dart';
import '../../core/adhan_voices.dart';
import '../../core/hijri_date.dart';
import '../../core/notification_service.dart';
import '../../core/prayer_formats.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'adhan_providers.dart';
import 'prayer_log.dart';
import 'prayer_models.dart';

class AdhanPlaybackScreen extends ConsumerStatefulWidget {
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
  ConsumerState<AdhanPlaybackScreen> createState() =>
      _AdhanPlaybackScreenState();
}

class _AdhanPlaybackScreenState extends ConsumerState<AdhanPlaybackScreen> {
  bool? _playing;
  bool _muted = false;
  bool _stopping = false;
  bool _busy = false;
  late DateTime _now;
  Timer? _clock;

  PrayerName get _prayer => PrayerName.values.firstWhere(
    (prayer) => prayer.name == widget.prayerName,
    orElse: () => PrayerName.dhuhr,
  );

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    // Leaving the screen — by the stop button, the back gesture or the close
    // button — always ends the foreground playback.
    unawaited(AdhanPlatform.stopPlayback());
    super.dispose();
  }

  String get _voiceId {
    final explicit = widget.voiceId;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return ref.read(adhanSettingsProvider).voiceIdFor(_prayer);
  }

  Future<void> _start() async {
    final voice = adhanVoiceById(_voiceId);
    final settings = ref.read(adhanSettingsProvider);
    final started = await AdhanPlatform.startPlayback(
      resource: voice.resource,
      assetPath: voice.assetPath,
      title: _prayer.invocation,
      notificationId: widget.notificationId,
      fadeIn: _prayer == PrayerName.fajr,
      silenceOnHardware: settings.silenceOnHardware,
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
    setState(() {
      _playing = started;
      _muted = false;
    });
  }

  /// Ends the foreground sound but keeps the screen open.
  Future<void> _silence() async {
    if (_stopping || _busy) return;
    setState(() => _busy = true);
    await AdhanPlatform.stopPlayback();
    final notificationId = widget.notificationId;
    if (notificationId != null) {
      await NotificationService.instance.cancelNotification(notificationId);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _muted = true;
      _playing = false;
    });
  }

  /// Restarts the sound after the user muted it.
  Future<void> _unmute() async {
    if (_stopping || _busy) return;
    setState(() {
      _busy = true;
      _muted = false;
    });
    await _start();
    if (mounted) setState(() => _busy = false);
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

  Future<void> _markPrayed() async {
    if (_stopping) return;
    HapticFeedback.mediumImpact();
    final today = DateTime.now();
    final log = ref.read(prayerLogProvider);
    if (!log.isMarked(today, _prayer)) {
      ref.read(prayerLogProvider.notifier).toggle(today, _prayer);
    }
    await _stop();
  }

  Future<void> _snooze() async {
    if (_stopping || _busy) return;
    setState(() => _busy = true);
    final voice = adhanVoiceById(_voiceId);
    await NotificationService.instance.scheduleAdhanSnooze(
      prayerName: _prayer.name,
      voiceId: voice.id,
      city: widget.city,
    );
    await AdhanPlatform.stopPlayback();
    final notificationId = widget.notificationId;
    if (notificationId != null) {
      await NotificationService.instance.cancelNotification(notificationId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: TrText('هنذكّرك تاني بعد ١٠ دقائق.'),
          duration: Duration(seconds: 3),
        ),
      );
    if (mounted) Navigator.of(context).maybePop();
  }

  /// A gentle fade-in when the screen appears; instant under reduced motion.
  Widget _fade(BuildContext context, Widget child) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _AdhanPalette.of(
      _prayer,
      dark: theme.brightness == Brightness.dark,
    );
    final hijri = HijriDate.fromGregorian(_now);
    final prayerTime = widget.time?.toLocal();
    final clock = _clockText(_now);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: palette.sky,
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: IgnorePointer(
              child: _AdhanScene(
                palette: palette,
                reducedMotion: MediaQuery.of(context).disableAnimations,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 16),
                    ),
                    child: _fade(
                      context,
                      IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _TopBar(
                              city: widget.city,
                              palette: palette,
                              onClose: _stopping ? null : _stop,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: _CenterBlock(
                                palette: palette,
                                clock: clock,
                                prayer: _prayer,
                                prayerTime: prayerTime,
                                hijri: hijri,
                                reducedMotion: MediaQuery.of(context)
                                    .disableAnimations,
                              ),
                            ),
                            _Controls(
                              palette: palette,
                              muted: _muted,
                              busy: _busy || _stopping,
                              playing: _playing,
                              onMute: _muted ? _unmute : _silence,
                              onPrayed: _markPrayed,
                              onSnooze: _snooze,
                              onSettings: () =>
                                  context.push(ZakerRoutes.prayerNotifications),
                              onQibla: () => context.push(ZakerRoutes.qibla),
                              onQuran: () => context.push(ZakerRoutes.quran),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// «6:04:09 م» — the live clock, tabular so the digits do not jump.
String _clockText(DateTime now) {
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  final second = now.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second ${now.hour < 12 ? 'ص' : 'م'}';
}

/// One prayer's colours in light or dark mode.
class _AdhanPalette {
  const _AdhanPalette({
    required this.sky,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.silhouette,
    required this.window,
    required this.horizon,
    required this.stars,
    required this.chipFill,
    required this.chipBorder,
  });

  final List<Color> sky;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color silhouette;
  final Color window;
  final Color horizon;
  final bool stars;
  final Color chipFill;
  final Color chipBorder;

  static _AdhanPalette of(PrayerName prayer, {required bool dark}) {
    if (dark) {
      return switch (prayer) {
        PrayerName.fajr => const _AdhanPalette(
          sky: [Color(0xFF171338), Color(0xFF2E1F63), Color(0xFF0B1026)],
          ink: Colors.white,
          muted: Color(0xFFCBC4E8),
          accent: Color(0xFFC4B5FD),
          silhouette: Color(0xFF080A18),
          window: Color(0xFFB4A6F5),
          horizon: Color(0x33FFFFFF),
          stars: true,
          chipFill: Color(0x26FFFFFF),
          chipBorder: Color(0x33FFFFFF),
        ),
        PrayerName.dhuhr => const _AdhanPalette(
          sky: [Color(0xFF0A3A52), Color(0xFF0E7490), Color(0xFF06202E)],
          ink: Colors.white,
          muted: Color(0xFFBFE6F2),
          accent: Color(0xFF9FE0F5),
          silhouette: Color(0xFF03141C),
          window: Color(0xFFBDEBFA),
          horizon: Color(0x33FFFFFF),
          stars: false,
          chipFill: Color(0x26FFFFFF),
          chipBorder: Color(0x33FFFFFF),
        ),
        PrayerName.asr => const _AdhanPalette(
          sky: [Color(0xFF3B2506), Color(0xFF8A4B0F), Color(0xFF231405)],
          ink: Colors.white,
          muted: Color(0xFFF5DFC2),
          accent: Color(0xFFFCD34D),
          silhouette: Color(0xFF160C02),
          window: Color(0xFFFBD38D),
          horizon: Color(0x33FFFFFF),
          stars: false,
          chipFill: Color(0x26FFFFFF),
          chipBorder: Color(0x33FFFFFF),
        ),
        PrayerName.maghrib => const _AdhanPalette(
          sky: [Color(0xFF431407), Color(0xFFC2410C), Color(0xFF2A0A12)],
          ink: Colors.white,
          muted: Color(0xFFFBD5C5),
          accent: Color(0xFFFFC48A),
          silhouette: Color(0xFF1A0507),
          window: Color(0xFFFCA97A),
          horizon: Color(0x33FFFFFF),
          stars: true,
          chipFill: Color(0x26FFFFFF),
          chipBorder: Color(0x33FFFFFF),
        ),
        PrayerName.isha => const _AdhanPalette(
          sky: [Color(0xFF020617), Color(0xFF111C3A), Color(0xFF0B1026)],
          ink: Colors.white,
          muted: Color(0xFFC7D2FE),
          accent: Color(0xFF93C5FD),
          silhouette: Color(0xFF01030B),
          window: Color(0xFF93C5FD),
          horizon: Color(0x33FFFFFF),
          stars: true,
          chipFill: Color(0x26FFFFFF),
          chipBorder: Color(0x33FFFFFF),
        ),
      };
    }

    return switch (prayer) {
      PrayerName.fajr => const _AdhanPalette(
        sky: [Color(0xFFF2F0FF), Color(0xFFE4E0FA), Color(0xFFFAF9FF)],
        ink: Color(0xFF1E1B4B),
        muted: Color(0xFF4338CA),
        accent: Color(0xFF5B21B6),
        silhouette: Color(0xFF4C3F8F),
        window: Color(0xFF6D28D9),
        horizon: Color(0x334C1D95),
        stars: false,
        chipFill: Color(0xCCFFFFFF),
        chipBorder: Color(0x335B21B6),
      ),
      PrayerName.dhuhr => const _AdhanPalette(
        sky: [Color(0xFFEFF9FF), Color(0xFFD8EEFB), Color(0xFFF9FDFF)],
        ink: Color(0xFF082F49),
        muted: Color(0xFF075985),
        accent: Color(0xFF0369A1),
        silhouette: Color(0xFF2B6C88),
        window: Color(0xFF0284C7),
        horizon: Color(0x330C4A6E),
        stars: false,
        chipFill: Color(0xCCFFFFFF),
        chipBorder: Color(0x330369A1),
      ),
      PrayerName.asr => const _AdhanPalette(
        sky: [Color(0xFFFFF9E8), Color(0xFFFCEBCB), Color(0xFFFFFDF6)],
        ink: Color(0xFF422006),
        muted: Color(0xFF92400E),
        accent: Color(0xFFB45309),
        silhouette: Color(0xFF8A6420),
        window: Color(0xFFB45309),
        horizon: Color(0x3385420E),
        stars: false,
        chipFill: Color(0xCCFFFFFF),
        chipBorder: Color(0x33B45309),
      ),
      PrayerName.maghrib => const _AdhanPalette(
        sky: [Color(0xFFFFF4EA), Color(0xFFFDDCC4), Color(0xFFFFFBF7)],
        ink: Color(0xFF431407),
        muted: Color(0xFF9A3412),
        accent: Color(0xFFC2410C),
        silhouette: Color(0xFF8C3B1D),
        window: Color(0xFFEA580C),
        horizon: Color(0x339A3412),
        stars: false,
        chipFill: Color(0xCCFFFFFF),
        chipBorder: Color(0x33C2410C),
      ),
      PrayerName.isha => const _AdhanPalette(
        sky: [Color(0xFFF4F7FF), Color(0xFFE1E8FA), Color(0xFFFBFBFF)],
        ink: Color(0xFF0F172A),
        muted: Color(0xFF1E3A8A),
        accent: Color(0xFF1D4ED8),
        silhouette: Color(0xFF33477A),
        window: Color(0xFF2563EB),
        horizon: Color(0x331E3A8A),
        stars: false,
        chipFill: Color(0xCCFFFFFF),
        chipBorder: Color(0x331D4ED8),
      ),
    };
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.city,
    required this.palette,
    required this.onClose,
  });

  final String city;
  final _AdhanPalette palette;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassButton(
          icon: Icons.close_rounded,
          tooltip: 'إغلاق',
          palette: palette,
          onTap: onClose,
        ),
        const Spacer(),
        if (city.isNotEmpty)
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.chipFill,
                borderRadius: BorderRadius.circular(ZakerRadius.pill),
                border: Border.all(color: palette.chipBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedMapPin,
                    size: 15,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: TrText(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CenterBlock extends StatelessWidget {
  const _CenterBlock({
    required this.palette,
    required this.clock,
    required this.prayer,
    required this.prayerTime,
    required this.hijri,
    required this.reducedMotion,
  });

  final _AdhanPalette palette;
  final String clock;
  final PrayerName prayer;
  final DateTime? prayerTime;
  final HijriDate hijri;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrText(
          'حان الآن وقت',
          style: TextStyle(
            color: palette.ink.withValues(alpha: 0.86),
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        TrText(
          prayer.invocation,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.ink,
            fontWeight: FontWeight.w900,
            fontSize: 38,
            height: 1.2,
          ),
        ),
        if (prayerTime != null) ...[
          const SizedBox(height: 2),
          Text(
            formatClockTime(prayerTime!),
            style: TextStyle(
              color: palette.muted,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _PulseHalo(
          color: palette.accent,
          reducedMotion: reducedMotion,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: palette.chipFill,
              borderRadius: BorderRadius.circular(ZakerRadius.xl),
              border: Border.all(color: palette.chipBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clock,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                TrText(
                  hijri.withWeekday,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The softly pulsing ring behind the clock, disabled under reduced motion.
class _PulseHalo extends StatefulWidget {
  const _PulseHalo({
    required this.color,
    required this.reducedMotion,
    required this.child,
  });

  final Color color;
  final bool reducedMotion;
  final Widget child;

  @override
  State<_PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<_PulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reducedMotion) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion) {
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
    final child = widget.child;
    if (widget.reducedMotion) return child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 250 + 22 * t,
              height: 112 + 16 * t,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZakerRadius.xl + 20),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.14 + 0.10 * t),
                    blurRadius: 34 + 18 * t,
                    spreadRadius: 4 + 8 * t,
                  ),
                ],
              ),
            ),
            child!,
          ],
        );
      },
      child: child,
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.palette,
    required this.muted,
    required this.busy,
    required this.playing,
    required this.onMute,
    required this.onPrayed,
    required this.onSnooze,
    required this.onSettings,
    required this.onQibla,
    required this.onQuran,
  });

  final _AdhanPalette palette;
  final bool muted;
  final bool busy;
  final bool? playing;
  final VoidCallback onMute;
  final VoidCallback onPrayed;
  final VoidCallback onSnooze;
  final VoidCallback onSettings;
  final VoidCallback onQibla;
  final VoidCallback onQuran;

  @override
  Widget build(BuildContext context) {
    final failed = playing == false && !muted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TrText(
              'مش قادرين نشغّل الصوت — اتأكد إن صوت الوسائط مفتوح.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, fontSize: 12, height: 1.5),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _PrimaryButton(
                label: 'صلّيت الآن',
                icon: HugeIcons.strokeRoundedTaskDone01,
                palette: palette,
                filled: true,
                onTap: busy ? null : onPrayed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PrimaryButton(
                label: 'ذكّرني بعد ١٠ دقائق',
                icon: HugeIcons.strokeRoundedAlarmClock,
                palette: palette,
                filled: false,
                onTap: busy ? null : onSnooze,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ToolButton(
              icon: muted
                  ? HugeIcons.strokeRoundedVolumeMute01
                  : HugeIcons.strokeRoundedVolumeHigh,
              label: muted ? 'تشغيل الصوت' : 'كتم',
              palette: palette,
              highlighted: muted,
              onTap: busy ? null : onMute,
            ),
            const SizedBox(width: 8),
            _ToolButton(
              icon: HugeIcons.strokeRoundedSettings02,
              label: 'الإعدادات',
              palette: palette,
              onTap: onSettings,
            ),
            const SizedBox(width: 8),
            _ToolButton(
              icon: HugeIcons.strokeRoundedKaaba01,
              label: 'القبلة',
              palette: palette,
              onTap: onQibla,
            ),
            const SizedBox(width: 8),
            _ToolButton(
              icon: HugeIcons.strokeRoundedBookOpen01,
              label: 'القرآن',
              palette: palette,
              onTap: onQuran,
            ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.palette,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final dynamic icon;
  final _AdhanPalette palette;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = filled ? palette.sky.last : palette.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: filled ? palette.ink : palette.chipFill,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ZakerRadius.md),
              border: Border.all(
                color: filled ? Colors.transparent : palette.chipBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: icon,
                  size: 19,
                  color: enabled
                      ? foreground
                      : foreground.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: TrText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled
                          ? foreground
                          : foreground.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
    this.highlighted = false,
  });

  final dynamic icon;
  final String label;
  final _AdhanPalette palette;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: highlighted
              ? palette.accent.withValues(alpha: 0.28)
              : palette.chipFill,
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(ZakerRadius.md),
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ZakerRadius.md),
                border: Border.all(
                  color: highlighted ? palette.accent : palette.chipBorder,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: icon,
                    size: 20,
                    color: highlighted ? palette.accent : palette.ink,
                  ),
                  const SizedBox(height: 4),
                  TrText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final _AdhanPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: palette.chipFill,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.chipBorder),
            ),
            child: Icon(icon, size: 22, color: palette.ink),
          ),
        ),
      ),
    );
  }
}

/// The mosque scene: sky, drifting clouds, twinkling stars, crescent, dome,
/// minarets and lit arches.  Repaints only while motion is allowed.
class _AdhanScene extends StatefulWidget {
  const _AdhanScene({required this.palette, required this.reducedMotion});

  final _AdhanPalette palette;
  final bool reducedMotion;

  @override
  State<_AdhanScene> createState() => _AdhanSceneState();
}

class _AdhanSceneState extends State<_AdhanScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reducedMotion) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _AdhanScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion) {
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
    final painter = _MosquePainter(
      palette: widget.palette,
      progress: widget.reducedMotion ? 0 : null,
    );
    if (widget.reducedMotion) {
      return CustomPaint(painter: painter);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _MosquePainter(
          palette: widget.palette,
          progress: _controller.value,
        ),
      ),
    );
  }
}

class _MosquePainter extends CustomPainter {
  const _MosquePainter({required this.palette, this.progress});

  final _AdhanPalette palette;

  /// 0–1 over twelve seconds; `null` paints a still frame.
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseline = h * 0.985;
    final t = progress ?? 0;

    // Clouds drift slowly behind the mosque.
    _clouds(canvas, w, h, t);

    // Stars twinkle at different phases.
    if (palette.stars) {
      final random = math.Random(7);
      final paint = Paint();
      for (var index = 0; index < 46; index++) {
        final x = random.nextDouble() * w;
        final y = random.nextDouble() * h * 0.52;
        final radius = 0.5 + random.nextDouble() * 1.2;
        final phase = random.nextDouble() * math.pi * 2;
        final twinkle = progress == null
            ? 0.28
            : 0.18 + 0.22 * (0.5 + 0.5 * math.sin(t * math.pi * 2 + phase));
        paint.color = Colors.white.withValues(alpha: twinkle);
        canvas.drawCircle(Offset(x, y), radius, paint);
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
      Paint()
        ..color = palette.accent.withValues(alpha: palette.stars ? 0.9 : 0.5),
    );

    // Soft glow behind the dome.
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.80),
      w * 0.30,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );

    final body = Paint()..color = palette.silhouette;
    final lit = Paint()..color = palette.window;

    canvas.drawRect(
      Rect.fromLTRB(0, baseline, w, h),
      Paint()..color = palette.silhouette.withValues(alpha: 0.55),
    );
    canvas.drawLine(
      Offset(0, baseline),
      Offset(w, baseline),
      Paint()
        ..color = palette.horizon
        ..strokeWidth = 1.2,
    );

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

    canvas.drawRect(
      Rect.fromLTRB(w * 0.27, h * 0.78, w * 0.73, baseline),
      body,
    );
    canvas.drawRect(
      Rect.fromLTRB(w * 0.20, h * 0.84, w * 0.80, baseline),
      body,
    );

    final dome = Rect.fromLTRB(w * 0.30, h * 0.66, w * 0.70, h * 0.80);
    canvas.drawArc(dome, math.pi, math.pi, true, body);
    canvas.drawRect(
      Rect.fromLTRB(w * 0.30, h * 0.78, w * 0.70, h * 0.80),
      body,
    );

    final finial = Paint()
      ..color = palette.accent.withValues(alpha: palette.stars ? 0.8 : 0.5)
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
      Paint()
        ..color = palette.accent.withValues(alpha: palette.stars ? 0.85 : 0.55),
    );

    for (final centerX in [w * 0.385, w * 0.5, w * 0.615]) {
      _arch(canvas, lit, centerX, h * 0.82, w * 0.062, h * 0.075);
    }
    _arch(canvas, lit, w * 0.5, h * 0.895, w * 0.085, h * 0.075);

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
        Paint()
          ..color = palette.accent.withValues(
            alpha: palette.stars ? 0.65 : 0.38,
          ),
      );
    }
  }

  void _clouds(Canvas canvas, double w, double h, double t) {
    final paint = Paint()
      ..color = palette.ink.withValues(alpha: palette.stars ? 0.055 : 0.10);
    for (var index = 0; index < 3; index++) {
      final speed = 0.5 + index * 0.35;
      final baseX = ((t * speed + index * 0.37) % 1.3) - 0.15;
      final x = baseX * w;
      final y = h * (0.16 + index * 0.07);
      final scale = w * (0.16 + index * 0.05);
      canvas.drawOval(Rect.fromLTWH(x, y, scale, scale * 0.23), paint);
      canvas.drawOval(
        Rect.fromLTWH(
          x + scale * 0.28,
          y - scale * 0.06,
          scale * 0.6,
          scale * 0.2,
        ),
        paint,
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
    return oldDelegate.palette != palette || oldDelegate.progress != progress;
  }
}
