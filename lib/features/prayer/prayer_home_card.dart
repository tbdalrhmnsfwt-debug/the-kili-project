/// The prayer-times block on the home screen.
///
/// It shows the next prayer with a live (seconds included) countdown, the
/// Hijri date, and one compact card per prayer whose state (passed / next /
/// upcoming) updates on its own.  The same widgets are reused by the full
/// prayer screen for its header card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/hijri_date.dart';
import '../../core/prayer_formats.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'location_flow.dart';
import 'prayer_models.dart';
import 'prayer_onboarding.dart';
import 'prayer_providers.dart';

/// Home-screen entry point for prayer times.
class PrayerHomeSection extends ConsumerStatefulWidget {
  const PrayerHomeSection({super.key});

  @override
  ConsumerState<PrayerHomeSection> createState() => _PrayerHomeSectionState();
}

class _PrayerHomeSectionState extends ConsumerState<PrayerHomeSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(prayerSettingsProvider).onboarded) {
        maybeShowPrayerOnboarding(context, ref);
      } else {
        refreshLocationIfMoved(ref);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      refreshLocationIfMoved(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(prayerLocationProvider);
    final day = ref.watch(prayerDayProvider);
    final hijri = ref.watch(prayerHijriProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(onAction: () => context.push(ZakerRoutes.prayer)),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: location == null
              ? _SetupCard(
                  key: const ValueKey('prayer-setup'),
                  onDevice: () => startLocationFlow(context, ref),
                  onCity: () => chooseCity(context, ref),
                )
              : day == null
              ? const _LoadingCard(key: ValueKey('prayer-loading'))
              : Column(
                  key: const ValueKey('prayer-ready'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NextPrayerCard(
                      day: day,
                      hijri: hijri,
                      onTap: () => context.push(ZakerRoutes.prayer),
                      onLocation: () => showLocationPickerSheet(context, ref),
                    ),
                    const SizedBox(height: 10),
                    _PrayerStrip(
                      day: day,
                      onTap: () => context.push(ZakerRoutes.prayer),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedMosqueLocation,
          size: 20,
          color: ZakerColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TrText(
            'مواقيت الصلاة',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const TrText(
            'عرض الكل',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- setup

class _SetupCard extends StatelessWidget {
  const _SetupCard({super.key, required this.onDevice, required this.onCity});

  final VoidCallback onDevice;
  final VoidCallback onCity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.cardTheme.color,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.38 : 0.22,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.16 : 0.08,
            ),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [ZakerColors.primary, ZakerColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: ZakerColors.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedMosqueLocation,
                      size: 23,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        'فعّل مواقيت الصلاة',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      TrText(
                        'حدد موقعك مرة واحدة، وهنحسب الخمس صلوات '
                        'على جهازك من غير إنترنت.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.55,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDevice,
                    icon: const Icon(Icons.near_me_rounded, size: 17),
                    label: const TrText(
                      'حدد موقعي',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCity,
                    icon: const Icon(Icons.location_city_rounded, size: 17),
                    label: const TrText(
                      'اختار مدينتي',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            TrText(
              'بنحسب مواقيت اليوم…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- hero

/// The next-prayer card.  Public so the full screen can show the same header.
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({
    super.key,
    required this.day,
    required this.hijri,
    this.onTap,
    this.onLocation,
    this.showMeta = true,
  });

  final PrayerDay day;
  final HijriDate hijri;
  final VoidCallback? onTap;
  final VoidCallback? onLocation;

  /// Whether to show the location and Hijri pills inside the card. The full
  /// screen has its own date header, so it hides them here.
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B5F59).withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF0B5F59),
                  Color(0xFF0F766E),
                  Color(0xFF0D9488),
                ],
                stops: [0, 0.55, 1],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned(
                    top: -58,
                    left: -34,
                    child: _Bubble(size: 150, opacity: 0.08),
                  ),
                  Positioned(
                    bottom: -70,
                    right: -30,
                    child: _Bubble(size: 170, opacity: 0.06),
                  ),
                  Positioned(
                    top: 18,
                    right: 74,
                    child: _Bubble(size: 44, opacity: 0.06),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showMeta) ...[
                          Row(
                            children: [
                              Flexible(
                                child: _Pill(
                                  icon: HugeIcons.strokeRoundedLocation01,
                                  label: day.location.displayName,
                                  onTap: onLocation,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: _Pill(
                                  icon: HugeIcons.strokeRoundedCalendar03,
                                  label: hijri.formatted,
                                  alignment: AlignmentDirectional.centerEnd,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            TrText(
                              'الصلاة القادمة',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                            if (day.next.tomorrow) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const TrText(
                                  'غدًا',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: Row(
                            key: ValueKey(
                              '${day.next.name.name}-${day.next.tomorrow}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TrText(
                                  day.next.name.invocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatClockTime(day.next.time),
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Countdown(duration: day.remaining),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: day.progress,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              formatShortClockTime(day.previousTime),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              formatShortClockTime(day.next.time),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _Countdown extends StatelessWidget {
  const _Countdown({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final parts = countdownParts(duration);
    return Row(
      children: [
        Expanded(
          child: _CountBlock(
            value: parts.hours,
            label: 'ساعة',
            semanticsLabel: '${parts.hours} ساعة',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _CountBlock(
            value: parts.minutes,
            label: 'دقيقة',
            semanticsLabel: '${parts.minutes} دقيقة',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _CountBlock(
            value: parts.seconds,
            label: 'ثانية',
            semanticsLabel: '${parts.seconds} ثانية',
          ),
        ),
      ],
    );
  }
}

class _CountBlock extends StatelessWidget {
  const _CountBlock({
    required this.value,
    required this.label,
    required this.semanticsLabel,
  });

  final int value;
  final String label;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 1),
            TrText(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- strip

class _PrayerStrip extends StatelessWidget {
  const _PrayerStrip({required this.day, required this.onTap});

  final PrayerDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < day.prayers.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _PrayerMiniCard(
              prayer: day.prayers[i],
              phase: day.phaseFor(i),
              highlighted: day.isNext(day.prayers[i].name),
              onTap: onTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _PrayerMiniCard extends StatelessWidget {
  const _PrayerMiniCard({
    required this.prayer,
    required this.phase,
    required this.highlighted,
    required this.onTap,
  });

  final PrayerMoment prayer;
  final PrayerPhase phase;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNext = phase == PrayerPhase.next;
    final isPassed = phase == PrayerPhase.passed;
    final cardColor =
        theme.cardTheme.color ??
        (isDark ? const Color(0xFF1E293B) : Colors.white);

    final Color nameColor;
    final Color timeColor;
    if (isNext) {
      nameColor = Colors.white;
      timeColor = Colors.white.withValues(alpha: 0.95);
    } else if (isPassed) {
      nameColor = theme.colorScheme.onSurface.withValues(
        alpha: isDark ? 0.42 : 0.48,
      );
      timeColor = theme.colorScheme.onSurface.withValues(
        alpha: isDark ? 0.36 : 0.40,
      );
    } else {
      nameColor = theme.colorScheme.onSurface.withValues(alpha: 0.82);
      timeColor = theme.colorScheme.onSurface;
    }

    return Semantics(
      button: true,
      label: '${prayer.name.invocation} ${formatClockTime(prayer.time)}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isNext ? null : cardColor,
          gradient: isNext
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [ZakerColors.primary, ZakerColors.primaryDark],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNext
                ? Colors.transparent
                : theme.dividerTheme.color ?? Colors.black12,
          ),
          boxShadow: isNext
              ? [
                  BoxShadow(
                    color: ZakerColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 15,
                    child: Center(
                      child: isNext
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const TrText(
                                'التالي',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                ),
                              ),
                            )
                          : isPassed
                          ? Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.45),
                            )
                          : Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  TrText(
                    prayer.name.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatShortClockTime(prayer.time),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    style: TextStyle(
                      color: timeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

// ------------------------------------------------------------------ helpers

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    this.onTap,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: TrText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return Align(alignment: alignment, child: child);
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A single prayer row used by the full screen.
class PrayerDetailTile extends StatelessWidget {
  const PrayerDetailTile({
    super.key,
    required this.prayer,
    required this.phase,
    this.countdown,
  });

  final PrayerMoment prayer;
  final PrayerPhase phase;

  /// Shown under the next prayer only.
  final String? countdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNext = phase == PrayerPhase.next;
    final isPassed = phase == PrayerPhase.passed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNext
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.08)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNext
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: isNext
                  ? const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [ZakerColors.primary, ZakerColors.primaryLight],
                    )
                  : null,
              color: isNext
                  ? null
                  : theme.colorScheme.primary.withValues(
                      alpha: isPassed ? 0.06 : 0.10,
                    ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isPassed
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.55,
                      ),
                    )
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedMosqueLocation,
                      size: 18,
                      color: isNext ? Colors.white : theme.colorScheme.primary,
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: TrText(
                        prayer.name.invocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isPassed
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                )
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (prayer.tomorrow) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: TrText(
                          'غدًا',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isNext && countdown != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TrText(
                        'باقي ',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        countdown!,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ] else if (isPassed) ...[
                  const SizedBox(height: 2),
                  TrText(
                    'خلص وقتها',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatClockTime(prayer.time),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: isNext
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(
                      alpha: isPassed ? 0.42 : 0.88,
                    ),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
