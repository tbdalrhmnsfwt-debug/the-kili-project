/// The Qibla screen: a live compass, the bearing from the saved location and
/// an original globe view of the great-circle route to the Kaaba.
///
/// The bearing is calculated by `adhan_dart`'s `Qibla` class; the compass
/// uses the device magnetometer through `flutter_compass`; and both the
/// compass rose and the globe are drawn in code, without image or map
/// dependencies.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/qibla_constants.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'location_flow.dart';
import 'prayer_models.dart';
import 'prayer_providers.dart';
import 'qibla_compass.dart';
import 'qibla_globe.dart';
import 'qibla_providers.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

/// What the sensor is currently doing.
enum _CompassMode { detecting, live, staticMode }

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  StreamSubscription<CompassEvent>? _compassSubscription;
  Timer? _sensorTimeout;
  _CompassMode _mode = _CompassMode.detecting;
  double? _heading;
  double? _accuracy;

  /// Continuous heading used for rotation; it accumulates across 0°/360° so
  /// neither the rose nor the needle spins the long way round.
  double _smoothHeading = 0;
  bool _sensorSeen = false;
  bool _aligned = false;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _listenToCompass();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _sensorTimeout?.cancel();
    super.dispose();
  }

  void _listenToCompass() {
    _compassSubscription?.cancel();
    _sensorTimeout?.cancel();
    _sensorTimeout = Timer(kCompassDetectionTimeout, () {
      if (!mounted) return;
      if (_mode == _CompassMode.detecting) _useStaticMode();
    });

    final events = FlutterCompass.events;
    if (events == null) {
      _useStaticMode();
      return;
    }
    try {
      _compassSubscription = events.listen(
        _onCompassEvent,
        onError: (Object _) => _useStaticMode(),
        cancelOnError: false,
      );
    } catch (error) {
      debugPrint('qibla: could not listen to the compass ($error)');
      _useStaticMode();
    }
  }

  void _onCompassEvent(CompassEvent event) {
    final heading = event.heading;
    if (heading == null || !heading.isFinite || !mounted) return;

    final normalized = _normalizeDegrees(heading);
    final accuracy = event.accuracy;
    final qibla = ref.read(qiblaBearingProvider);
    final aligned =
        qibla != null &&
        shortestAngleDelta(normalized, qibla).abs() <=
            kQiblaAlignmentThresholdDegrees;

    if (aligned && !_wasAligned) {
      unawaited(HapticFeedback.mediumImpact());
    }
    _wasAligned = aligned;

    final delta = _sensorSeen
        ? shortestAngleDelta(_smoothHeading, normalized)
        : shortestAngleDelta(0, normalized);

    setState(() {
      _mode = _CompassMode.live;
      _sensorSeen = true;
      _heading = normalized;
      _accuracy = accuracy;
      _smoothHeading += delta;
      _aligned = aligned;
    });
  }

  void _useStaticMode() {
    if (!mounted) return;
    _sensorTimeout?.cancel();
    setState(() {
      _mode = _CompassMode.staticMode;
      _heading = null;
      _accuracy = null;
      _aligned = false;
      _wasAligned = false;
    });
  }

  void _retryCompass() {
    setState(() {
      _mode = _CompassMode.detecting;
      _heading = null;
      _accuracy = null;
      _sensorSeen = false;
      _aligned = false;
      _wasAligned = false;
    });
    _listenToCompass();
  }

  bool get _lowAccuracy =>
      _mode == _CompassMode.live &&
      _accuracy != null &&
      _accuracy! >= kQiblaLowAccuracyDegrees;

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(prayerLocationProvider);
    final bearing = ref.watch(qiblaBearingProvider);
    final distance = ref.watch(qiblaDistanceProvider);
    final hasLocation = location != null && bearing != null;

    return Scaffold(
      appBar: AppBar(
        title: const TrText('اتجاه القبلة'),
        actions: [
          if (hasLocation)
            IconButton(
              tooltip: 'تغيير الموقع',
              onPressed: () => showLocationPickerSheet(context, ref),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 22),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: !hasLocation
          ? _NoLocationView(
              onDetect: () => unawaited(startLocationFlow(context, ref)),
              onCity: () => unawaited(chooseCity(context, ref)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  children: [
                    _PlaceCard(location: location, bearing: bearing),
                    const SizedBox(height: 12),
                    _CompassCard(
                      bearing: bearing,
                      heading: _mode == _CompassMode.live
                          ? _smoothHeading
                          : null,
                      rawHeading: _heading,
                      aligned: _aligned,
                      mode: _mode,
                      lowAccuracy: _lowAccuracy,
                      onRetry: _retryCompass,
                    ),
                    const SizedBox(height: 12),
                    _GlobeCard(
                      latitude: location.latitude,
                      longitude: location.longitude,
                      distanceKm: distance ?? 0,
                    ),
                    const SizedBox(height: 12),
                    const _NotesCard(),
                  ],
                ),
              ),
            ),
    );
  }
}

// ------------------------------------------------------------ place header

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.location, required this.bearing});

  final PrayerLocation location;
  final double bearing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitle = [
      location.subtitle,
      location.sourceLabel,
    ].where((part) => part.isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.09),
            theme.cardTheme.color ?? theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.30 : 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedKaaba01,
                size: 23,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'موقعك الحالي',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 1),
                TrText(
                  location.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _degreesText(bearing),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              TrText(
                'من الشمال',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ compass card

class _CompassCard extends StatelessWidget {
  const _CompassCard({
    required this.bearing,
    required this.heading,
    required this.rawHeading,
    required this.aligned,
    required this.mode,
    required this.lowAccuracy,
    required this.onRetry,
  });

  final double bearing;
  final double? heading;
  final double? rawHeading;
  final bool aligned;
  final _CompassMode mode;
  final bool lowAccuracy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLive = mode == _CompassMode.live;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: aligned
              ? ZakerColors.success.withValues(alpha: 0.45)
              : theme.dividerTheme.color ?? Colors.black12,
          width: aligned ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (aligned ? ZakerColors.success : theme.colorScheme.primary)
                .withValues(alpha: isDark ? 0.10 : 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCompass,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: TrText(
                  'البوصلة',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(
                mode: mode,
                aligned: aligned,
                lowAccuracy: lowAccuracy,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'بوصلة اتجاه القبلة',
            value: '${_degreesText(bearing)} من الشمال',
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 292),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: QiblaCompassDial(
                    qiblaBearing: _normalizeDegrees(bearing),
                    heading: heading,
                    aligned: aligned,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 26,
            runSpacing: 8,
            children: [
              _Readout(
                label: 'القبلة من الشمال',
                value: _degreesText(bearing),
                color: theme.colorScheme.primary,
                emphasized: true,
              ),
              if (isLive && rawHeading != null)
                _Readout(
                  label: 'اتجاه الموبايل',
                  value: _degreesText(rawHeading!),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _CompassStatus(
              key: ValueKey('${mode.name}-$aligned'),
              mode: mode,
              aligned: aligned,
              onRetry: onRetry,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: lowAccuracy
                ? const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: _CalibrationNotice(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: emphasized ? 31 : 19,
            height: 1.05,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        TrText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.mode,
    required this.aligned,
    required this.lowAccuracy,
  });

  final _CompassMode mode;
  final bool aligned;
  final bool lowAccuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (mode) {
      _CompassMode.detecting => ('بنجهز…', theme.colorScheme.onSurfaceVariant),
      _CompassMode.live when aligned => ('متوافق', ZakerColors.success),
      _CompassMode.live when lowAccuracy => ('معايرة', ZakerColors.accent),
      _CompassMode.live => ('مباشر', theme.colorScheme.primary),
      _CompassMode.staticMode => ('ثابت', theme.colorScheme.onSurfaceVariant),
    };
    // The dot and border keep the brand shade; the label has to clear the pill
    // tint underneath it.
    final ink = cardAccentOnTintOf(color, theme, alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          TrText(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassStatus extends StatelessWidget {
  const _CompassStatus({
    super.key,
    required this.mode,
    required this.aligned,
    required this.onRetry,
  });

  final _CompassMode mode;
  final bool aligned;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    switch (mode) {
      case _CompassMode.detecting:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            TrText(
              'بنجرّب حساس البوصلة…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontSize: 10.5,
              ),
            ),
          ],
        );
      case _CompassMode.live:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              aligned
                  ? Icons.check_circle_rounded
                  : Icons.screen_rotation_alt_rounded,
              size: 16,
              color: aligned
                  ? cardAccentOf(ZakerColors.success, theme)
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: TrText(
                aligned
                    ? 'أنت في اتجاه القبلة — كده تقدر تصلّي.'
                    : 'لف الموبايل ببطء لحد ما تبقى فوقه السهم.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: aligned
                      ? cardAccentOf(ZakerColors.success, theme)
                      : muted,
                  fontWeight: aligned ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );
      case _CompassMode.staticMode:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_off_rounded, size: 16, color: muted),
                const SizedBox(width: 7),
                Flexible(
                  child: TrText(
                    'مفيش حساس بوصلة على الجهاز — السهم ثابت على الزاوية '
                    'من الشمال.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const TrText('جرّب البوصلة تاني'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _CalibrationNotice extends StatelessWidget {
  const _CalibrationNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ZakerColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ZakerColors.accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.screen_rotation_rounded,
            size: 17,
            color: ZakerColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TrText(
              'دقة البوصلة منخفضة — حرّك الموبايل على شكل رقم ٨ كام مرة '
              'عشان تعاير الحساس، وبعدين استنى ثانية.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- globe card

class _GlobeCard extends StatelessWidget {
  const _GlobeCard({
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  final double latitude;
  final double longitude;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedEarth,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TrText(
                      'المسافة والمسار',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TrText(
                      'أقصر خط على سطح الأرض بينك وبين الكعبة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDigits(distanceKm.round()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TrText(
                    'كم للكعبة',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          QiblaGlobe(latitude: latitude, longitude: longitude),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: theme.colorScheme.primary, label: 'موقعك'),
              const SizedBox(width: 18),
              _LegendDot(color: theme.colorScheme.secondary, label: 'الكعبة'),
              const SizedBox(width: 18),
              Icon(
                Icons.route_rounded,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              TrText(
                'أقصر مسار',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        TrText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ notes

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              const TrText(
                'ملاحظات سريعة',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const _NoteLine(
            text:
                'الزاوية بتتحسب من الشمال وباتجاه عقارب الساعة، من موقعك '
                'المحفوظ — سواء جاي من الـ GPS أو مدينة اخترتها.',
          ),
          const _NoteLine(
            text:
                'البوصلة بتقرأ مغناطيسية الموبايل. ابعد عن المعادن '
                'والأجهزة الكهربائية وقت الضبط، ولو الدقة منخفضة حرّك '
                'الموبايل على شكل رقم ٨.',
          ),
          const _NoteLine(
            text:
                'لو الجهاز مافيهوش حساس بوصلة، هتشوف الزاوية بالدرجات وسهم '
                'ثابت من الشمال بدل البوصلة الحية.',
          ),
          const _NoteLine(
            text:
                'الاتجاه ده إرشادي — لو فيه فرق واضح، اتجاه المسجد هو '
                'المرجع.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.text, this.last = false});

  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ empty state

class _NoLocationView extends StatelessWidget {
  const _NoLocationView({required this.onDetect, required this.onCity});

  final VoidCallback onDetect;
  final VoidCallback onCity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [ZakerColors.primary, ZakerColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ZakerColors.primary.withValues(alpha: 0.3),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedKaaba01,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TrText(
                'محتاجين موقعك للقبلة',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 8),
              TrText(
                'اختار موقعك مرة واحدة وهنحسب زاوية القبلة من الشمال، '
                'ونرسملك أقصر مسار للكعبة على الكرة الأرضية. الحساب كله '
                'بيتم على جهازك.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.7,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onDetect,
                  icon: const Icon(Icons.near_me_rounded, size: 19),
                  label: const TrText('حدد موقعي'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCity,
                  icon: const Icon(Icons.location_city_rounded, size: 19),
                  label: const TrText('اختار مدينتي'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- helpers

double _normalizeDegrees(double value) => ((value % 360) + 360) % 360;

String _degreesText(double value) =>
    '${_normalizeDegrees(value).round() % 360}°';

String _formatDigits(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) buffer.write(',');
    buffer.write(text[index]);
  }
  return buffer.toString();
}
