/// The home screen.
///
/// Layout follows the approved mockup: a teal gradient hero with the
/// greeting, search and live study stats; the three 3D action cards; the
/// countdown and daily-advice banners; the six-tool daily grid (including the
/// calculator and the إعراب guide); the subject cards for the selected grade;
/// and — below them — the complete feature grid so every screen stays one tap
/// away.
///
/// The data is the app's own: the display name comes from
/// [authUserProvider], the streak/minutes from [studyStatsProvider], the
/// pending reminders from [taskScheduleProvider], and the subjects from
/// [gradesProvider].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadDecoration, ShadIconButton, ShadInput;

import '../../core/appearance.dart';
import '../../core/curriculum.dart';
import '../../core/hijri_date.dart';
import '../../core/prayer_formats.dart';
import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../models/schedule.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../../widgets/zaker_visuals.dart';
import '../focus/focus_screen.dart';
import '../prayer/location_flow.dart';
import '../prayer/prayer_models.dart';
import '../prayer/prayer_onboarding.dart';
import '../prayer/prayer_providers.dart';
import 'shell_screen.dart';

/// Accent colours for the tinted cards in the mockup.
class _Accents {
  const _Accents._();

  static const Color purple = Color(0xFF7C3AED);
  static const Color teal = ZakerColors.primary;
  static const Color blue = Color(0xFF2563EB);
  static const Color amber = Color(0xFFD97706);
  static const Color rose = Color(0xFFE11D48);
  static const Color sky = Color(0xFF0284C7);
  static const Color green = Color(0xFF059669);
}

const List<Color> _subjectAccents = [
  _Accents.blue,
  _Accents.amber,
  _Accents.purple,
  _Accents.green,
  _Accents.rose,
  _Accents.sky,
  _Accents.teal,
];

/// A pastel wash of [accent] that still works on the dark theme.
Color _wash(BuildContext context, Color accent) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return Color.alphaBlend(
    accent.withValues(alpha: isDark ? 0.16 : 0.07),
    theme.scaffoldBackgroundColor,
  );
}

Color _hairline(BuildContext context, Color accent) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return accent.withValues(alpha: isDark ? 0.32 : 0.20);
}

Color _depth(BuildContext context, Color accent) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Color.alphaBlend(
    Colors.black.withValues(alpha: isDark ? 0.36 : 0.20),
    accent,
  );
}

/// The home screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(gradesProvider);
    final stats = ref.watch(studyStatsProvider);
    final user = ref.watch(authUserProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final gradeId = ref.watch(selectedGradeProvider);
    final schedule = ref.watch(taskScheduleProvider);
    final pending = schedule.forDay().where((e) => !e.done).toList();
    final nextDeadline = _nextDeadline(schedule.entries);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gradesProvider);
          await ref.read(gradesProvider.future);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
              children: [
                _HeroBanner(
                  name: user?.displayName ?? 'ضيف',
                  showBadge: notificationsOn && pending.isNotEmpty,
                  streakDays: stats.streakDays,
                  minutesToday: stats.minutesToday,
                  pendingCount: pending.length,
                  onNotifications: () => _showNotifications(context),
                  onSettings: () => context.push(ZakerRoutes.settings),
                ),
                const SizedBox(height: 20),
                _ActionCards(streakDays: stats.streakDays),
                const SizedBox(height: 12),
                const _IslamicHubCard(),
                const SizedBox(height: 22),
                _BannerRow(
                  nextDeadline: nextDeadline,
                  onCountdown: () => context.push(ZakerRoutes.tasks),
                ),
                const SizedBox(height: 26),
                const _DailyTools(),
                const SizedBox(height: 26),
                _LibrarySection(grades: grades, gradeId: gradeId),
                const SizedBox(height: 26),
                const _AllToolsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The nearest task still ahead of us, or the most recent overdue one.
  static ScheduleEntry? _nextDeadline(List<ScheduleEntry> entries) {
    final now = DateTime.now();
    final dated =
        entries.where((e) => !e.done && e.dueAt != null).toList(growable: false)
          ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    if (dated.isEmpty) return null;
    for (final entry in dated) {
      if (!entry.dueAt!.isBefore(now)) return entry;
    }
    return dated.last;
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (_) => const _NotificationsSheet(),
    );
  }
}

// ---------------------------------------------------------------- hero banner

/// The greeting banner: greeting, name, actions, search, the live next-prayer
/// countdown and the three Islamic quick actions.
class _HeroBanner extends ConsumerStatefulWidget {
  const _HeroBanner({
    required this.name,
    required this.showBadge,
    required this.streakDays,
    required this.minutesToday,
    required this.pendingCount,
    required this.onNotifications,
    required this.onSettings,
  });

  final String name;
  final bool showBadge;
  final int streakDays;
  final int minutesToday;
  final int pendingCount;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  ConsumerState<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<_HeroBanner>
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
    final theme = Theme.of(context);
    final palette = ZakerTheme.paletteFor(
      ref.watch(appearanceProvider).themeStyle,
    );
    final location = ref.watch(prayerLocationProvider);
    final day = ref.watch(prayerDayProvider);
    final hijri = ref.watch(prayerHijriProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final openDrawer = shellDrawerOpener(context);
    final radius = BorderRadius.circular(28);
    const softWhite = Color(0xFFEDF1F8);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: palette.heroGradient,
          stops: const [0, 0.58, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: palette.heroGradient.first.withValues(alpha: 0.34),
            blurRadius: 32,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(ZakerRoutes.prayer),
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -40,
                child: _Bubble(size: 200, opacity: 0.08),
              ),
              Positioned(
                bottom: -90,
                left: -50,
                child: _Bubble(size: 220, opacity: 0.05),
              ),
              Positioned(
                top: 24,
                left: 92,
                child: _Bubble(size: 56, opacity: 0.06),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: TrText(
                                  '$greeting يا ${widget.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: softWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              TrText(
                                'عايز تعمل إيه النهاردة؟',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (openDrawer != null) ...[
                          _HeroButton(
                            icon: HugeIcons.strokeRoundedMenu01,
                            onTap: openDrawer,
                            tooltip: 'القائمة',
                          ),
                          const SizedBox(width: 6),
                        ],
                        _HeroButton(
                          icon: HugeIcons.strokeRoundedDashboardSquare01,
                          onTap: () => context.push(ZakerRoutes.appearance),
                          tooltip: 'تغيير الشكل',
                        ),
                        const SizedBox(width: 6),
                        _HeroButton(
                          icon: HugeIcons.strokeRoundedNotification01,
                          showDot: widget.showBadge,
                          onTap: widget.onNotifications,
                          tooltip: 'التنبيهات',
                        ),
                        if (openDrawer == null) ...[
                          const SizedBox(width: 6),
                          _HeroButton(
                            icon: HugeIcons.strokeRoundedSettings01,
                            onTap: widget.onSettings,
                            tooltip: 'الإعدادات',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _SearchBox(),
                    const SizedBox(height: 14),
                    if (location == null)
                      _HeroPrayerSetup(
                        onDevice: () => startLocationFlow(context, ref),
                        onCity: () => chooseCity(context, ref),
                      )
                    else if (day == null)
                      const _HeroPrayerLoading()
                    else
                      _HeroPrayerBlock(
                        day: day,
                        hijri: hijri,
                        onLocation: () => showLocationPickerSheet(context, ref),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroQuickAction(
                            icon: HugeIcons.strokeRoundedVolumeHigh,
                            label: 'الأذان',
                            onTap: () =>
                                context.push(ZakerRoutes.prayerNotifications),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HeroQuickAction(
                            icon: HugeIcons.strokeRoundedKaaba01,
                            label: 'القبلة',
                            onTap: () => context.push(ZakerRoutes.qibla),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HeroQuickAction(
                            icon: HugeIcons.strokeRoundedSunrise,
                            label: 'الأذكار',
                            onTap: () => context.push(ZakerRoutes.azkar),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              value: '${widget.streakDays}',
                              label: 'يوم متواصل',
                            ),
                          ),
                          const _HeroDivider(),
                          Expanded(
                            child: _HeroStat(
                              value: '${widget.minutesToday}',
                              label: 'دقيقة النهاردة',
                            ),
                          ),
                          const _HeroDivider(),
                          Expanded(
                            child: _HeroStat(
                              value: '${widget.pendingCount}',
                              label: 'مهمة مستنية',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next prayer, its live HH:MM:SS countdown and the day's progress.
class _HeroPrayerBlock extends StatelessWidget {
  const _HeroPrayerBlock({
    required this.day,
    required this.hijri,
    required this.onLocation,
  });

  final PrayerDay day;
  final HijriDate hijri;
  final VoidCallback onLocation;

  static const Color _meta = Color(0xFFD9F5F2);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: _HeroPill(
                icon: HugeIcons.strokeRoundedLocation01,
                label: day.location.displayName,
                onTap: onLocation,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: _HeroPill(
                icon: HugeIcons.strokeRoundedCalendar03,
                label: hijri.formatted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const TrText(
              'الصلاة القادمة',
              style: TextStyle(
                color: _meta,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (day.next.tomorrow) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const TrText(
                  'غدًا',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const Spacer(),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 17,
              color: _meta,
            ),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Row(
            key: ValueKey('${day.next.name.name}-${day.next.tomorrow}'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TrText(
                  day.next.name.invocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatClockTime(day.next.time),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const TrText(
              'متبقي',
              style: TextStyle(
                color: _meta,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              formatCountdown(day.remaining),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: day.progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Text(
              formatShortClockTime(day.previousTime),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: _meta,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Text(
              formatShortClockTime(day.next.time),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: _meta,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label, this.onTap});

  final dynamic icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: TrText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: 'تغيير الموقع',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// The no-location state inside the hero: two ways to set a location.
class _HeroPrayerSetup extends StatelessWidget {
  const _HeroPrayerSetup({required this.onDevice, required this.onCity});

  final VoidCallback onDevice;
  final VoidCallback onCity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedMosqueLocation,
                size: 19,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Expanded(
                child: TrText(
                  'حدّد موقعك تشوف مواقيت الصلاة والعدّاد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onDevice,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ZakerColors.primaryDark,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(
                      fontFamily: ZakerTheme.fontUi,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const TrText('موقعي الحالي'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCity,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(
                      fontFamily: ZakerTheme.fontUi,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const TrText('اختار مدينة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPrayerLoading extends StatelessWidget {
  const _HeroPrayerLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          ZakerSkeleton(width: 16, height: 16, radius: 8),
          SizedBox(width: 10),
          TrText(
            'بنحسب مواقيت النهاردة…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the three hero shortcuts. An item with no route is rendered
/// disabled instead of pushing a dead path.
class _HeroQuickAction extends StatelessWidget {
  const _HeroQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final dynamic icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.black.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(icon: icon, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: TrText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
        border: Border.all(color: Colors.white.withValues(alpha: opacity / 2)),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        TrText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.16),
    );
  }
}

/// A translucent circular action in the banner.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
    this.tooltip,
  });

  final List<List<dynamic>> icon;
  final VoidCallback onTap;
  final bool showDot;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = ShadIconButton(
      width: 42,
      height: 42,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.white.withValues(alpha: 0.18),
      hoverBackgroundColor: Colors.white.withValues(alpha: 0.30),
      pressedBackgroundColor: Colors.white.withValues(alpha: 0.34),
      decoration: const ShadDecoration(shape: BoxShape.circle),
      onPressed: onTap,
      icon: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            HugeIcon(icon: icon, size: 22, color: Colors.white),
            if (showDot)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBBF24),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The mockup's translucent search pill. Submitting opens the AI chat with
/// the typed question, which is the app's free-text entry point.
class _SearchBox extends StatefulWidget {
  const _SearchBox();

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    context.push('${ZakerRoutes.chat}?q=${Uri.encodeQueryComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 20,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ShadInput(
              controller: _controller,
              decoration: ShadDecoration.none,
              padding: const EdgeInsets.symmetric(vertical: 13),
              cursorColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: ZakerTheme.fontUi,
                fontSize: 14,
              ),
              placeholder: const TrText(
                'اسأل معلم AI عن أي حاجة…',
                style: TextStyle(
                  color: Color(0xFFE3F4F2),
                  fontFamily: ZakerTheme.fontUi,
                  fontSize: 14,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- action cards

/// The three primary actions, rendered as raised 3D cards.
class _ActionCards extends StatelessWidget {
  const _ActionCards({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _ActionCard(
        aurora: true,
        accent: _Accents.purple,
        title: 'المساعد الذكي',
        subtitle: 'أسأل عن أي حاجة',
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      _ActionCard(
        icon: HugeIcons.strokeRoundedBookOpen01,
        accent: _Accents.teal,
        title: 'المكتبة الدراسية',
        subtitle: 'كل الكتب والمناهج',
        onTap: () => context.push(ZakerRoutes.courses),
      ),
      _ActionCard(
        icon: HugeIcons.strokeRoundedTaskDone01,
        accent: _Accents.blue,
        title: 'مهامي',
        subtitle: streakDays == 0
            ? 'رتب مهام يومك'
            : 'مذاكرة $streakDays يوم متواصل',
        onTap: () => context.push(ZakerRoutes.tasks),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) SizedBox(width: compact ? 8 : 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.aurora = false,
  });

  final List<List<dynamic>>? icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The assistant card uses the animated aurora mark instead of a glyph.
  final bool aurora;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 620;
    final surface = theme.cardTheme.color ?? theme.colorScheme.surface;

    return _Pressable3D(
      accent: accent,
      depth: 6,
      radius: 22,
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: isDark ? 0.30 : 0.16),
                surface,
              ),
              Color.alphaBlend(
                accent.withValues(alpha: isDark ? 0.12 : 0.04),
                surface,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _hairline(context, accent)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 3.5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(ZakerRadius.pill),
              ),
            ),
            SizedBox(height: compact ? 9 : 11),
            if (aurora)
              AuroraAssistantMark(
                size: compact ? 46 : 54,
                radius: compact ? 15 : 18,
              )
            else
              ZakerGlassIcon(
                icon: icon!,
                accent: accent,
                size: compact ? 46 : 54,
                iconSize: compact ? 24 : 28,
                radius: compact ? 15 : 18,
              ),
            SizedBox(height: compact ? 10 : 12),
            TrText(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: compact ? 12 : 15,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              TrText(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: compact ? 8 : 14),
            Container(
              width: compact ? 30 : 36,
              height: compact ? 30 : 36,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                size: compact ? 15 : 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- islamic hub card

/// The single home entry to the Islamics hub.
class _IslamicHubCard extends StatelessWidget {
  const _IslamicHubCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent =
        theme.extension<ZakerFeatureAccents>()?.islamic ??
        theme.colorScheme.primary;
    final surface = theme.cardTheme.color ?? theme.colorScheme.surface;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(ZakerRoutes.islamicHub),
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: ZakerSpacing.md,
            vertical: ZakerSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Color.alphaBlend(
                  accent.withValues(alpha: isDark ? 0.22 : 0.10),
                  surface,
                ),
                surface,
              ],
            ),
            borderRadius: BorderRadius.circular(ZakerRadius.lg),
            border: Border.all(color: _hairline(context, accent)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      accent.withValues(alpha: isDark ? 0.30 : 0.18),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(ZakerRadius.md),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMosque01,
                    size: 22,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TrText(
                      'الإسلاميات',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      'المواقيت · الأذان · القبلة · الأذكار · الحفظ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, height: 1.4, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ZakerRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TrText(
                      'افتح',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_left_rounded, size: 16, color: accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- countdown & advice

/// The amber countdown and the green daily-advice banner.
class _BannerRow extends StatelessWidget {
  const _BannerRow({required this.nextDeadline, required this.onCountdown});

  final ScheduleEntry? nextDeadline;
  final VoidCallback onCountdown;

  @override
  Widget build(BuildContext context) {
    final countdown = _CountdownBanner(
      nextDeadline: nextDeadline,
      onTap: onCountdown,
    );
    final advice = const _AdviceBanner();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 780) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: countdown),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: advice),
              ],
            ),
          );
        }
        return Column(
          children: [countdown, const SizedBox(height: 12), advice],
        );
      },
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.nextDeadline, required this.onTap});

  final ScheduleEntry? nextDeadline;
  final VoidCallback onTap;

  static const List<String> _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = nextDeadline;
    final due = entry?.dueAt;

    var daysText = '';
    var unitText = '';
    if (due != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      final diff = dueDay.difference(today).inDays;
      if (diff > 1) {
        daysText = '$diff';
        unitText = 'يوم فاضل';
      } else if (diff == 1) {
        daysText = '1';
        unitText = 'بكرة';
      } else if (diff == 0) {
        daysText = '0';
        unitText = 'النهارده';
      } else {
        daysText = '${-diff}';
        unitText = 'يوم فات';
      }
    }

    final dateLabel = due == null
        ? null
        : '${due.day} ${_months[due.month - 1]} · '
              '${due.hour.toString().padLeft(2, '0')}:'
              '${due.minute.toString().padLeft(2, '0')}';

    return _Pressable3D(
      accent: _Accents.amber,
      depth: 4,
      radius: 20,
      onTap: onTap,
      semanticLabel: 'العد التنازلي',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _wash(context, _Accents.amber),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hairline(context, _Accents.amber)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _Accents.amber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedHourglass,
                  size: 26,
                  color: _Accents.amber,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TrText(
                    entry == null
                        ? 'أضف عد تنازلي لامتحاناتك'
                        : 'العد التنازلي',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  TrText(
                    entry == null
                        ? 'حدد موعد مهمة وإحنا نحسب الأيام الباقية.'
                        : '${entry.title}${dateLabel == null ? '' : ' · $dateLabel'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (entry != null) ...[
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    daysText,
                    style: const TextStyle(
                      color: _Accents.amber,
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TrText(
                    unitText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(width: 8),
              ShadIconButton(
                width: 38,
                height: 38,
                padding: EdgeInsets.zero,
                backgroundColor: _Accents.amber.withValues(alpha: 0.16),
                hoverBackgroundColor: _Accents.amber.withValues(alpha: 0.24),
                decoration: const ShadDecoration(shape: BoxShape.circle),
                onPressed: onTap,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 18,
                  color: _Accents.amber,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A rotating, date-stable tip for the day.
class _AdviceBanner extends StatelessWidget {
  const _AdviceBanner();

  static const List<String> _tips = [
    'ذاكر 25 دقيقة وخد راحة 5 دقايق — طريقة بومودورو بتخلي تركيزك أعلى.',
    'راجع الدرس قبل ما تنام بعشر دقايق، الذاكرة بتثبت أكتر.',
    'قسّم المنهج لأجزاء صغيرة، وابدأ بأصعب جزء وإنت فايق.',
    'لخّص كل درس في 5 نقاط بكلامك إنت، مش بالنقل من الكتاب.',
    'حل امتحان قديم قبل الامتحان بأسبوع — ده أفضل تدريب.',
    'اشرب مية ونام 7 ساعات؛ المخ محتاجهم للمذاكرة.',
    'سيب الموبايل في أوضة تانية وإنت بتذاكر — الإشعارات بتكسر التركيز.',
    'علّم حد غيرك درس إنت فهمته؛ الشرح بيثبّت المعلومة.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final tip = _tips[dayOfYear % _tips.length];

    return _Pressable3D(
      accent: _Accents.green,
      depth: 4,
      radius: 20,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const FocusScreen())),
      semanticLabel: 'نصيحة النهاردة',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _wash(context, _Accents.green),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hairline(context, _Accents.green)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _Accents.green.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedIdea01,
                  size: 23,
                  color: _Accents.green,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TrText(
                    'نصيحة النهاردة',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _Accents.green,
                    ),
                  ),
                  const SizedBox(height: 3),
                  TrText(
                    tip,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- daily tools

/// The six daily-tool tiles from the mockup.
class _DailyTools extends StatelessWidget {
  const _DailyTools();

  @override
  Widget build(BuildContext context) {
    final tools =
        <
          ({
            List<List<dynamic>> icon,
            String label,
            Color accent,
            VoidCallback onTap,
          })
        >[
          (
            icon: HugeIcons.strokeRoundedCalculator01,
            label: 'الآلة الحاسبة',
            accent: _Accents.blue,
            onTap: () => context.push(ZakerRoutes.calculator),
          ),
          (
            icon: HugeIcons.strokeRoundedPen01,
            label: 'الإعراب',
            accent: _Accents.amber,
            onTap: () => context.push(ZakerRoutes.irab),
          ),
          (
            icon: HugeIcons.strokeRoundedCalendar03,
            label: 'خطة المذاكرة',
            accent: _Accents.green,
            onTap: () => context.push(ZakerRoutes.planner),
          ),
          (
            icon: HugeIcons.strokeRoundedTimer01,
            label: 'إدارة الوقت',
            accent: _Accents.purple,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FocusScreen()),
            ),
          ),
          (
            icon: HugeIcons.strokeRoundedAnalytics01,
            label: 'متابعة التقدم',
            accent: _Accents.rose,
            onTap: () => context.push(ZakerRoutes.weekly),
          ),
          (
            icon: HugeIcons.strokeRoundedTarget01,
            label: 'مراجعات',
            accent: _Accents.sky,
            onTap: () => context.push(ZakerRoutes.recall),
          ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'أدواتك اليومية',
          icon: HugeIcons.strokeRoundedWrench01,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 720 ? 6 : 3;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tool in tools)
                  SizedBox(
                    width: tileWidth,
                    child: _ToolTile(
                      icon: tool.icon,
                      label: tool.label,
                      accent: tool.accent,
                      onTap: tool.onTap,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Pressable3D(
      accent: accent,
      depth: 4,
      radius: 18,
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 104,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(
          color: _wash(context, accent),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _hairline(context, accent)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ZakerGlassIcon(
              icon: icon,
              accent: accent,
              size: 36,
              iconSize: 21,
              radius: 11,
            ),
            const SizedBox(height: 8),
            TrText(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- subjects

/// The selected grade's subjects as tappable cards.
class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.grades, required this.gradeId});

  final AsyncValue<List<Grade>> grades;
  final String gradeId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        grades.when(
          loading: () => const _SectionTitle(
            title: 'موادك',
            icon: HugeIcons.strokeRoundedBookOpen01,
          ),
          error: (_, __) => const _SectionTitle(
            title: 'موادك',
            icon: HugeIcons.strokeRoundedBookOpen01,
          ),
          data: (list) {
            final label = list
                .where((g) => g.id == gradeId)
                .map((g) => g.label)
                .firstOrNull;
            return _SectionTitle(
              title: 'موادك',
              icon: HugeIcons.strokeRoundedBookOpen01,
              badge: label,
              actionLabel: 'كل المكتبة',
              onAction: () => context.push(ZakerRoutes.courses),
            );
          },
        ),
        const SizedBox(height: 12),
        grades.when(
          loading: () => const LoadingBox(),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'مقدرناش نحمّل المواد',
            message: '$e',
          ),
          data: (list) => _SubjectGrid(grades: list, gradeId: gradeId),
        ),
      ],
    );
  }
}

class _SubjectGrid extends StatelessWidget {
  const _SubjectGrid({required this.grades, required this.gradeId});

  final List<Grade> grades;
  final String gradeId;

  @override
  Widget build(BuildContext context) {
    if (grades.isEmpty) {
      return EmptyState(
        icon: Icons.library_books_outlined,
        title: 'مكتبتك فاضية',
        message: 'افتح أي مادة وابدأ المذاكرة.',
        action: FilledButton(
          onPressed: () => context.push(ZakerRoutes.courses),
          child: const TrText('افتح المكتبة'),
        ),
      );
    }

    final grade = grades.firstWhere(
      (g) => g.id == gradeId,
      orElse: () => grades.first,
    );

    // Several variants can ship for one subject; the card represents the
    // subject and opens the first book, while the count hints at the rest.
    final subjects = <String, List<Book>>{};
    for (final book in grade.books) {
      subjects.putIfAbsent(book.subject, () => <Book>[]).add(book);
    }

    if (subjects.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'مفيش مواد في الصف ده',
        message: 'جرّب صف دراسي تاني من «كل المواد».',
        action: FilledButton(
          onPressed: () => context.push(ZakerRoutes.courses),
          child: const TrText('افتح المكتبة'),
        ),
      );
    }

    final entries = subjects.entries.toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 138,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final accent = _subjectAccents[index % _subjectAccents.length];
            return _SubjectCard(
              subject: entry.key,
              books: entry.value,
              accent: accent,
              onTap: () =>
                  context.push(_subjectRoute(grade, entry.value.first)),
            );
          },
        );
      },
    );
  }
}

/// Routes a subject card of a secondary grade to the curriculum screen; other
/// grades keep opening the first book directly.
String _subjectRoute(Grade grade, Book book) {
  final curriculum = curriculumForGrade(grade.id);
  if (curriculum != null) {
    for (final subject in curriculum.subjects) {
      if (!subject.assetSubjects.contains(book.subject)) continue;
      final trackId = subject.tracks.isEmpty ? null : subject.tracks.first;
      return ZakerRoutes.subjectPath(grade.id, subject.id, track: trackId);
    }
  }
  return ZakerRoutes.lessonPath(book);
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.books,
    required this.accent,
    required this.onTap,
  });

  final String subject;
  final List<Book> books;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessons = books.fold<int>(0, (sum, book) => sum + book.lessons);

    return _Pressable3D(
      accent: accent,
      depth: 5,
      radius: 18,
      onTap: onTap,
      semanticLabel: subject,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _hairline(context, accent)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedBookOpen01,
                      size: 20,
                      color: accent,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    size: 15,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TrText(
                subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TrText(
              books.length > 1
                  ? '$lessons درس · ${books.length} كتب'
                  : '$lessons درس',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ all tools

/// The full feature grid, preserving every entry the app exposes.
class _AllToolsSection extends StatelessWidget {
  const _AllToolsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'كل الأدوات',
          icon: HugeIcons.strokeRoundedDashboardSquare01,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TrText(
            'كل حاجة في رفيق الطالب على بُعد ضغطة واحدة.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 4
                : constraints.maxWidth >= 620
                ? 3
                : 2;
            final tiles = _tiles(context);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: ZakerSpacing.md,
                crossAxisSpacing: ZakerSpacing.md,
                // A fixed tile height keeps the icon, title and subtitle
                // together instead of stretching into tall squares on wide
                // screens.
                mainAxisExtent: 168,
              ),
              itemCount: tiles.length,
              itemBuilder: (_, index) => tiles[index],
            );
          },
        ),
      ],
    );
  }

  List<Widget> _tiles(BuildContext context) {
    final tiles =
        <({String title, IconData icon, String? subtitle, VoidCallback onTap})>[
          (
            title: 'امتحان',
            icon: Icons.fact_check_rounded,
            subtitle: 'اختبار بالدرجات',
            onTap: () => context.push(ZakerRoutes.exams),
          ),
          (
            title: 'منهج الثانوي',
            icon: Icons.school_rounded,
            subtitle: 'مواد ومسارات',
            onTap: () => context.push(ZakerRoutes.subjects),
          ),
          (
            title: ZakerStrings.s_9cfe0, // بنك الأسئلة
            icon: Icons.quiz_rounded,
            subtitle: ZakerStrings.s_d6b7e, // بنك الأسئلة اللي في مكتبتك
            onTap: () => context.push(ZakerRoutes.questionBank),
          ),
          (
            title: 'تركيز',
            icon: Icons.timer_rounded,
            subtitle: 'جلسات مذاكرة',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FocusScreen()),
            ),
          ),
          (
            title: 'القرآن الكريم',
            icon: Icons.menu_book_rounded,
            subtitle: 'أذكار وتلاوة',
            onTap: () => context.push(ZakerRoutes.quran),
          ),
          (
            title: 'فهرس المصطلحات',
            icon: Icons.menu_book_outlined,
            subtitle: 'معاني الكلمات',
            onTap: () => context.push(ZakerRoutes.glossary),
          ),
          (
            title: 'أدوات الـPDF',
            icon: Icons.picture_as_pdf_rounded,
            subtitle: 'ادمج وحول واطبع',
            onTap: () => context.push(ZakerRoutes.pdfTools),
          ),
          (
            title: 'المسح الضوئي',
            icon: Icons.document_scanner_rounded,
            subtitle: 'صوّر الواجب',
            onTap: () => context.push(ZakerRoutes.scan),
          ),
          (
            title: 'الآلة الحاسبة',
            icon: Icons.calculate_rounded,
            subtitle: 'علمية متقدمة',
            onTap: () => context.push(ZakerRoutes.calculator),
          ),
          (
            title: 'دليل الإعراب',
            icon: Icons.spellcheck_rounded,
            subtitle: 'قواعد وأمثلة',
            onTap: () => context.push(ZakerRoutes.irab),
          ),
          (
            title: 'استرجاع نشط',
            icon: Icons.style_rounded,
            subtitle: 'كارت المراجعة',
            onTap: () => context.push(ZakerRoutes.recall),
          ),
          (
            title: 'الخريطة الذهنية',
            icon: Icons.account_tree_rounded,
            subtitle: 'ارسم أفكارك',
            onTap: () => context.push(ZakerRoutes.mindMap),
          ),
          (
            title: 'المهام',
            icon: Icons.checklist_rounded,
            subtitle: 'واجباتك وتذكيراتك',
            onTap: () => context.push(ZakerRoutes.tasks),
          ),
          (
            title: 'أهداف اليوم',
            icon: Icons.flag_rounded,
            subtitle: 'خطتك النهارده',
            onTap: () => context.push(ZakerRoutes.planner),
          ),
          (
            title: 'إنجازاتي',
            icon: Icons.workspace_premium_rounded,
            subtitle: 'الشارات والدعوة',
            onTap: () => context.push(ZakerRoutes.achievements),
          ),
          (
            title: 'المتصدرين',
            icon: Icons.emoji_events_rounded,
            subtitle: 'نقاطك وسلسلتك',
            onTap: () => context.push(ZakerRoutes.leaderboard),
          ),
          (
            title: 'دفتر أخطائي',
            icon: Icons.error_outline_rounded,
            subtitle: 'غلطاتك ترجعلك',
            onTap: () => context.push(ZakerRoutes.mistakes),
          ),
          (
            title: ZakerStrings.s_7859a, // ترجمة
            icon: Icons.translate_rounded,
            subtitle: 'ترجمة نصوص ومحاضرات',
            onTap: () => context.push(ZakerRoutes.translate),
          ),
          (
            title: ZakerStrings.s_35563, // كلماتي
            icon: Icons.translate_rounded,
            subtitle: 'قاموس الكلمات',
            onTap: () => context.push(ZakerRoutes.words),
          ),
          (
            title: ZakerStrings.s_5588a, // ملاحظاتي
            icon: Icons.edit_note_rounded,
            subtitle: 'دفتر ملاحظاتك',
            onTap: () => context.push(ZakerRoutes.notebooks),
          ),
          (
            title: ZakerStrings.s_a03b0, // الحديقة
            icon: Icons.grain_rounded,
            subtitle: 'بتنمو بالأيام',
            onTap: () => context.push(ZakerRoutes.garden),
          ),
          (
            title: ZakerStrings.s_feeca, // تحديات
            icon: Icons.bolt_rounded,
            subtitle: ZakerStrings.s_1da21, // تحدي مع صحابك
            onTap: () => context.push(ZakerRoutes.challenges),
          ),
          (
            title: ZakerStrings.s_03af3, // نقاط ضعفي
            icon: Icons.trending_down_rounded,
            subtitle: 'راجع نقاط ضعفي',
            onTap: () => context.push(ZakerRoutes.weakness),
          ),
          (
            title: ZakerStrings.s_97497, // ألعاب المذاكرة
            icon: Icons.sports_esports_rounded,
            subtitle: ZakerStrings.s_928ae, // مذاكرة على شكل لعبة…
            onTap: () => context.push(ZakerRoutes.games),
          ),
          (
            title: ZakerStrings.s_f30a0, // سبورة
            icon: Icons.draw_rounded,
            subtitle: ZakerStrings.s_ddb1c, // اشرح الدرس على السبورة
            onTap: () => context.push(ZakerRoutes.whiteboard),
          ),
          (
            title: ZakerStrings.s_02316, // تقدمي الأسبوعي
            icon: Icons.insights_rounded,
            subtitle: ZakerStrings.s_a3f5a, // ملخص أسبوعك…
            onTap: () => context.push(ZakerRoutes.weekly),
          ),
        ];

    return [
      FeatureTile(
        title: 'معلم AI',
        subtitle: 'اسأل واشرح',
        icon: Icons.auto_awesome_rounded,
        art: const AuroraAssistantMark(size: 38, radius: ZakerRadius.sm),
        color: _subjectAccents[0],
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      for (var i = 0; i < tiles.length; i++)
        FeatureTile(
          title: tiles[i].title,
          subtitle: tiles[i].subtitle,
          icon: tiles[i].icon,
          color: _subjectAccents[(i + 1) % _subjectAccents.length],
          onTap: tiles[i].onTap,
        ),
    ];
  }
}

/// A section header with a Hugeicons glyph, matching the mockup.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    this.badge,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<List<dynamic>> icon;
  final String? badge;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        HugeIcon(icon: icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        TrText(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TrText(
                badge!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: TrText(actionLabel!)),
      ],
    );
  }
}

// --------------------------------------------------------------- notifications

/// The reminders sheet opened from the bell in the banner.
class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(notificationsEnabledProvider);
    final tasks = ref
        .watch(taskScheduleProvider)
        .forDay()
        .where((e) => !e.done)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          0,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              'المنبهات',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              enabled
                  ? 'دي المهام اللي مستنياك النهارده.'
                  : 'التنبيهات متوقفة — تقدر تفتحها من هنا.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const TrText('تذكير المذاكرة'),
              value: enabled,
              onChanged: (value) =>
                  ref.read(notificationsEnabledProvider.notifier).state = value,
            ),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ZakerSpacing.md),
                child: TrText('مفيش مهام مجدولة النهارده — يومك فاضي.'),
              )
            else
              for (final task in tasks.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(ZakerRoutes.tasks);
                  },
                  leading: Icon(
                    task.important
                        ? Icons.priority_high_rounded
                        : Icons.schedule_rounded,
                    color: task.important
                        ? ZakerColors.accent
                        : theme.colorScheme.primary,
                  ),
                  title: TrText(task.title),
                  subtitle: task.dueAt == null
                      ? null
                      : TrText(
                          '${task.dueAt!.hour.toString().padLeft(2, '0')}:'
                          '${task.dueAt!.minute.toString().padLeft(2, '0')}',
                        ),
                ),
            const SizedBox(height: ZakerSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(ZakerRoutes.tasks);
                },
                icon: const Icon(Icons.checklist_rounded),
                label: const TrText('كل المهام'),
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(ZakerRoutes.planner);
                },
                icon: const Icon(Icons.flag_rounded),
                label: const TrText('افتح أهداف اليوم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 3D shell

/// A raised card with a solid coloured edge, a press-down animation and a
/// hover lift on desktop. The depth is painted under the card rather than as
/// a shadow, which is what gives the mockup its 3D toy-like edge.
class _Pressable3D extends StatefulWidget {
  const _Pressable3D({
    required this.child,
    required this.accent,
    required this.onTap,
    required this.radius,
    this.depth = 6,
    this.semanticLabel,
  });

  final Widget child;
  final Color accent;
  final VoidCallback onTap;
  final double radius;
  final double depth;
  final String? semanticLabel;

  @override
  State<_Pressable3D> createState() => _Pressable3DState();
}

class _Pressable3DState extends State<_Pressable3D> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final depth = widget.depth;
    final offset = _pressed ? depth * 0.72 : 0.0;
    final lift = _hovered && !_pressed ? -1.5 : 0.0;
    final radius = BorderRadius.circular(widget.radius);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                top: depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _depth(context, widget.accent),
                    borderRadius: radius,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                transform: Matrix4.diagonal3Values(
                  _pressed ? 0.97 : 1.0,
                  _pressed ? 0.97 : 1.0,
                  1,
                )..setTranslationRaw(0.0, offset + lift, 0.0),
                child: Container(
                  margin: EdgeInsets.only(bottom: depth),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
