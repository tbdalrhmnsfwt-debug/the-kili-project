import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/hijri_date.dart';
import '../../../core/localization.dart';
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
  const PrayerPill({super.key, this.compact = false});

  /// When true the pill is the tiny badge that lives inside the navy header.
  final bool compact;

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
      compact: widget.compact,
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
    this.compact = false,
  });

  final PrayerDay? day;
  final PrayerLocation? location;
  final HijriDate hijri;
  final VoidCallback onTap;

  /// True for the single-line badge in the navy header.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactPrayerBadge(day: day, onTap: onTap);
    }
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

/// The single-line prayer badge embedded in the navy header.
///
/// It is deliberately height-capped and wrapped in a [FittedBox]: however long
/// the location or large the reader's text setting, the badge shrinks to fit
/// its strip instead of pushing the header taller.
class _CompactPrayerBadge extends StatelessWidget {
  const _CompactPrayerBadge({required this.day, required this.onTap});

  final PrayerDay? day;
  final VoidCallback onTap;

  static const TextStyle _nameStyle = TextStyle(
    color: Colors.white,
    fontSize: 10.5,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle _metaStyle = TextStyle(
    color: Color(0xCCFFFFFF),
    fontSize: 9.5,
    height: 1.15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle _countdownStyle = TextStyle(
    color: ZakerColors.goldLight,
    fontSize: 10,
    height: 1.15,
    fontWeight: FontWeight.w800,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final hasDay = day != null;
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    String tr(String value) => l10n?.t(value) ?? value;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: hasDay
          ? [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedMoon02,
                size: 13,
                color: ZakerColors.goldLight,
              ),
              const SizedBox(width: 5),
              TrText(day!.next.name.invocation, style: _nameStyle),
              const SizedBox(width: 4),
              const Text('•', style: _metaStyle),
              const SizedBox(width: 4),
              const TrText('بعد', style: _metaStyle),
              const SizedBox(width: 3),
              Text(
                formatCountdown(day!.remaining),
                textDirection: TextDirection.ltr,
                style: _countdownStyle,
              ),
            ]
          : [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedLocation01,
                size: 13,
                color: ZakerColors.goldLight,
              ),
              const SizedBox(width: 5),
              const TrText('حدد موقعك لمواقيت الصلاة', style: _metaStyle),
            ],
    );

    return Semantics(
      button: true,
      label: hasDay
          ? '${tr(day!.next.name.invocation)}، ${tr('بعد')} '
              '${formatCountdown(day!.remaining)}'
          : tr('حدد موقعك لمواقيت الصلاة'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-prayer-pill'),
          borderRadius: BorderRadius.circular(ZakerRadius.pill),
          onTap: onTap,
          child: SizedBox(
            // The pill stays visually 30 dp tall, but its tap target uses the
            // whole content height of the compact top strip.
            height: 40,
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Container(
                key: const Key('home-prayer-badge'),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(ZakerRadius.pill),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.center,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: row,
                    ),
                  ),
                ),
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

    final tile = _PrayerTile(theme: theme, accent: accent);
    final chevron = HugeIcon(
      key: const Key('home-prayer-chevron'),
      icon: HugeIcons.strokeRoundedArrowLeft01,
      size: 18,
      color: muted,
    );
    final countdown = Column(
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
    );

    final details = Column(
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
    );

    // The countdown is eight fixed-width digits. At large text they no longer
    // fit beside the details on a narrow screen, so the countdown gets its own
    // line at full scale instead of being clamped below the user's setting.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (!largeText) {
      return Row(
        children: [
          tile,
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(child: details),
          const SizedBox(width: ZakerSpacing.sm),
          countdown,
          const SizedBox(width: ZakerSpacing.xs),
          chevron,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            tile,
            const SizedBox(width: ZakerSpacing.sm),
            Expanded(child: details),
            const SizedBox(width: ZakerSpacing.xs),
            chevron,
          ],
        ),
        const SizedBox(height: ZakerSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: countdown,
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
