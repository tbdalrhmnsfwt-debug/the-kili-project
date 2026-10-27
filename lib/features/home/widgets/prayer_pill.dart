import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/hijri_date.dart';
import '../../../core/prayer_formats.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';
import '../../prayer/location_flow.dart';
import '../../prayer/prayer_models.dart';
import '../../prayer/prayer_onboarding.dart';
import '../../prayer/prayer_providers.dart';

/// The live prayer pill: watches the clock, the location and the Hijri day.
///
/// Keeps the hero's old first-frame behaviour — ask for a location once, then
/// refresh it on resume — because the pill is now where the location lives.
class PrayerPill extends ConsumerStatefulWidget {
  const PrayerPill({super.key});

  @override
  ConsumerState<PrayerPill> createState() => _PrayerPillState();
}

class _PrayerPillState extends ConsumerState<PrayerPill>
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
    return PrayerPillView(
      day: ref.watch(prayerDayProvider),
      location: ref.watch(prayerLocationProvider),
      hijri: ref.watch(prayerHijriProvider),
      onTap: () => context.push(ZakerRoutes.islamicHub),
    );
  }
}

/// The one-row prayer card: next prayer, its time, the day, and a countdown.
///
/// A 64 dp **minimum**, not a fixed height: at 2.0x text the row grows instead
/// of clipping.
class PrayerPillView extends StatelessWidget {
  const PrayerPillView({
    super.key,
    required this.day,
    required this.location,
    required this.hijri,
    required this.onTap,
  });

  final PrayerDay? day;
  final PrayerLocation? location;
  final HijriDate hijri;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = featureAccentsOf(theme);
    final radius = BorderRadius.circular(ZakerRadius.cardValue);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('home-prayer-pill'),
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cardSurfaceOf(theme),
            borderRadius: radius,
            border: Border.all(color: ZakerColors.border),
            boxShadow: ZakerShadows.card,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ZakerSpacing.md,
                vertical: ZakerSpacing.sm,
              ),
              child: day == null
                  ? _NoLocationRow(theme: theme, accent: accents.prayer)
                  : _DayRow(
                      theme: theme,
                      accent: accents.prayer,
                      day: day!,
                      location: location,
                      hijri: hijri,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.theme,
    required this.accent,
    required this.day,
    required this.location,
    required this.hijri,
  });

  final ThemeData theme;
  final Color accent;
  final PrayerDay day;
  final PrayerLocation? location;
  final HijriDate hijri;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final meta = TextStyle(fontSize: 11, color: muted);
    // The watched location wins; the snapshot carries its own as a fallback.
    final place = location?.displayName ?? day.location.displayName;

    return Row(
      children: [
        _PrayerTile(theme: theme, accent: accent),
        const SizedBox(width: ZakerSpacing.sm),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: TrText(
                      day.next.name.invocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (day.next.tomorrow) ...[
                    const SizedBox(width: ZakerSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(ZakerRadius.pill),
                      ),
                      child: TrText(
                        'غدًا',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cardAccentOf(accent, theme),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(formatClockTime(day.next.time), style: meta),
              const SizedBox(height: 1),
              Row(
                children: [
                  Flexible(
                    child: TrText(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text('·', style: meta),
                  ),
                  Flexible(
                    child: TrText(
                      hijri.formatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: ZakerSpacing.sm),
        // The countdown is a fixed-width badge: clamping its scale keeps the
        // eight digits from pushing the row past a 320 dp screen at 2.0x.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TrText('بعد', style: TextStyle(fontSize: 10, color: muted)),
              Text(
                formatCountdown(day.remaining),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: cardAccentOf(accent, theme),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZakerSpacing.xs),
        HugeIcon(
          key: const Key('home-prayer-chevron'),
          icon: HugeIcons.strokeRoundedArrowLeft01,
          size: 18,
          color: muted,
        ),
      ],
    );
  }
}

class _NoLocationRow extends StatelessWidget {
  const _NoLocationRow({required this.theme, required this.accent});

  final ThemeData theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PrayerTile(theme: theme, accent: accent),
        const SizedBox(width: ZakerSpacing.sm),
        const Expanded(
          child: TrText(
            'حدد موقعك لمعرفة مواقيت الصلاة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        HugeIcon(
          key: const Key('home-prayer-chevron'),
          icon: HugeIcons.strokeRoundedArrowLeft01,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// The moon tile that anchors the pill.
class _PrayerTile extends StatelessWidget {
  const _PrayerTile({required this.theme, required this.accent});

  final ThemeData theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.14),
          cardSurfaceOf(theme),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMoon02,
          size: 20,
          color: cardAccentOf(accent, theme),
        ),
      ),
    );
  }
}
