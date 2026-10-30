/// The home screen.
///
/// The compact order from the approved mockup: the navy top strip with the
/// app name, the navy-slate hero with the live prayer badge, [WelcomeSearch]
/// and the glass stat chips, the three side-by-side action cards, the six
/// core-feature cards, the countdown and daily-advice banners, the all-tools
/// grid, and the developer credit at the bottom.
///
/// The hero, action cards, feature cards and tools all share the
/// [HomePalette] navy-glass treatment: deep navy slate anchored by champagne
/// gold, with emerald teal, amber and coral carrying the data and actions.
///
/// The data is the app's own: the display name comes from
/// [authUserProvider], the streak/minutes from [studyStatsProvider], the
/// pending reminders from [taskScheduleProvider], and the shelves from
/// [gradesProvider].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadDecoration, ShadIconButton;

import '../../core/brand/rafiq_brand.dart';
import '../../core/brand/rafiq_mark.dart';
import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/schedule.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../../widgets/zaker_visuals.dart';
import '../focus/focus_screen.dart';
import 'shell_screen.dart';
import 'widgets/core_features_grid.dart';
import 'widgets/home_style.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/prayer_pill.dart';
import 'widgets/stats_strip.dart';
import 'widgets/welcome_search.dart';

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
    final stats = ref.watch(studyStatsProvider);
    final user = ref.watch(authUserProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final schedule = ref.watch(taskScheduleProvider);
    final pending = schedule.forDay().where((e) => !e.done).toList();
    final nextDeadline = _nextDeadline(schedule.entries);
    final openDrawer = shellDrawerOpener(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              HomeTopBar(
                showBadge: notificationsOn && pending.isNotEmpty,
                onMenu: openDrawer,
                onNotifications: () => _showNotifications(context),
                onSettings: () => context.push(ZakerRoutes.settings),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // Refresh what this screen actually shows. Grades are no
                    // longer on the home, but the bag still reads them, so
                    // they are refreshed in the background for that screen.
                    ref.invalidate(taskScheduleProvider);
                    ref.invalidate(studyStatsProvider);
                    ref.invalidate(gradesProvider);
                    try {
                      await ref.read(gradesProvider.future);
                    } catch (_) {
                      // The home shows no grades, so a failed background
                      // refresh must not escape the indicator as an unhandled
                      // error. The bag reports its own load failure.
                    }
                  },
                  child: ListView(
                    key: const Key('home-body'),
                    padding: EdgeInsets.zero,
                    children: [
                      _HomeHeader(
                        name: user?.displayName ?? 'ضيف',
                        streakDays: stats.streakDays,
                        minutesToday: stats.minutesToday,
                        pendingCount: pending.length,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _OrganicActionCards(),
                            const SizedBox(height: 22),
                            const _SectionTitle(
                              title: 'ميزاتك الأساسية',
                              icon: HugeIcons.strokeRoundedGrid02,
                            ),
                            const SizedBox(height: ZakerSpacing.md),
                            const CoreFeaturesGrid(),
                            const SizedBox(height: 22),
                            _BannerRow(
                              nextDeadline: nextDeadline,
                              onCountdown: () =>
                                  context.push(ZakerRoutes.tasks),
                            ),
                            const SizedBox(height: 22),
                            const _AllToolsSection(),
                            const SizedBox(height: ZakerSpacing.xl),
                            const _HomeFooter(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The nearest task still ahead of us, or the most recent overdue one.
  static ScheduleEntry? _nextDeadline(List<ScheduleEntry> entries) {
    final now = DateTime.now();
    final dated = entries
        .where((e) => !e.done && e.dueAt != null)
        .toList(growable: false)
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

// -------------------------------------------------------------------- header

/// The navy welcome panel directly under the fixed top strip.
///
/// The fixed top strip owns the menu, notifications and settings. This panel
/// carries the compact prayer badge and continues the same navy field into the
/// greeting and the AI search, then softly rounds back into the off-white body.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.name,
    required this.streakDays,
    required this.minutesToday,
    required this.pendingCount,
  });

  final String name;
  final int streakDays;
  final int minutesToday;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-header'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: HomePalette.headerGradient,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: HomePalette.midnight.withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Three soft colour fields keep the navy from reading as a flat bar:
          // champagne warms the top, emerald lifts the stats, coral grounds
          // the lower edge.
          const Positioned.fill(child: HomeHeaderAtmosphere()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The live badge sits just under the app bar so the app name
                // can stay the top strip's clear, permanent title.
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PrayerPill(compact: true),
                ),
                const SizedBox(height: 6),
                WelcomeSearch(name: name),
                const SizedBox(height: 14),
                HomeStatsStrip(
                  streakDays: streakDays,
                  minutesToday: minutesToday,
                  pendingCount: pendingCount,
                ),
              ],
            ),
          ),
          // A hairline of champagne closes the hero into the page.
          PositionedDirectional(
            bottom: 0,
            start: 28,
            end: 28,
            child: IgnorePointer(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HomePalette.champagne.withValues(alpha: 0),
                      HomePalette.champagne.withValues(alpha: 0.45),
                      HomePalette.champagne.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ organic cards

/// The three primary actions, always side by side in their own glass fields.
///
/// The row is deliberately not a responsive stack: the brief asks for one
/// horizontal three-column band, so each child gets an [Expanded] share and
/// the card contents shrink/ellipsize instead of dropping to a column.
class _OrganicActionCards extends StatelessWidget {
  const _OrganicActionCards();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _OrganicActionCard(
              cardKey: const Key('home-card-assistant'),
              icon: HugeIcons.strokeRoundedAiSparkles,
              accent: HomePalette.champagne,
              accentSoft: HomePalette.champagneLight,
              gradient: HomePalette.assistantGradient,
              title: 'المساعد الذكي',
              subtitle: 'اسأل عن أي حاجة',
              onTap: () => context.push(ZakerRoutes.chat),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OrganicActionCard(
              cardKey: const Key('home-card-bag'),
              icon: HugeIcons.strokeRoundedShoppingBag01,
              accent: HomePalette.emerald,
              accentSoft: HomePalette.emeraldLight,
              gradient: HomePalette.bagGradient,
              title: 'ملفاتي بالمادة',
              subtitle: 'شنطة كل مادة',
              onTap: () => context.push(ZakerRoutes.bag),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OrganicActionCard(
              cardKey: const Key('home-card-tasks'),
              icon: HugeIcons.strokeRoundedCheckList,
              accent: HomePalette.coral,
              accentSoft: HomePalette.coralLight,
              gradient: HomePalette.tasksGradient,
              title: 'مهامي',
              subtitle: 'رتب مهام يومك',
              onTap: () => context.push(ZakerRoutes.tasks),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tall glass card: a tinted badge, a two-line title block and a solid
/// circular arrow that anchors the bottom edge.
class _OrganicActionCard extends StatelessWidget {
  const _OrganicActionCard({
    required this.cardKey,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key cardKey;
  final List<List<dynamic>> icon;
  final Color accent;
  final Color accentSoft;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tight = MediaQuery.sizeOf(context).width < 380;
    final badgeSize = tight ? 36.0 : 40.0;
    final arrowSize = tight ? 28.0 : 30.0;

    return _Pressable3D(
      accent: accent,
      depth: 4,
      radius: 26,
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        key: cardKey,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsetsDirectional.fromSTEB(
          tight ? 8 : 10,
          12,
          tight ? 8 : 10,
          10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topEnd,
            end: AlignmentDirectional.bottomStart,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Two soft accent orbs keep the card organic without adding an
            // illustration or another tap target.
            PositionedDirectional(
              top: -24,
              end: -18,
              child: IgnorePointer(
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 8,
              start: -22,
              child: IgnorePointer(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // The glass sheen: a narrow white wash along the top edge.
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              height: 48,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      size: tight ? 19 : 21,
                      color: accentSoft,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: TrText(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HomePalette.textPrimary,
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: TrText(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentSoft,
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: arrowSize,
                  height: arrowSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [accentSoft, accent],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      size: tight ? 14 : 15,
                      color: HomePalette.midnight,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    const accent = HomePalette.amber;
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
      accent: accent,
      depth: 4,
      radius: 20,
      onTap: onTap,
      semanticLabel: 'العد التنازلي',
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topEnd,
            end: AlignmentDirectional.bottomStart,
            colors: HomePalette.countdownGradient,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedHourglass,
                  size: 26,
                  color: accent,
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
                      color: HomePalette.textPrimary,
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
                      color: HomePalette.textSecondary,
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
                      color: HomePalette.champagne,
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TrText(
                    unitText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: HomePalette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(width: 8),
              // The whole banner is already one labelled button; this is a
              // visual affordance for the same tap, not a second unnamed one.
              ExcludeSemantics(
                child: ShadIconButton(
                  width: 38,
                  height: 38,
                  padding: EdgeInsets.zero,
                  backgroundColor: accent.withValues(alpha: 0.16),
                  hoverBackgroundColor: accent.withValues(alpha: 0.24),
                  decoration: const ShadDecoration(shape: BoxShape.circle),
                  onPressed: onTap,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    size: 18,
                    color: accent,
                  ),
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
    const accent = HomePalette.emerald;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final tip = _tips[dayOfYear % _tips.length];

    return _Pressable3D(
      accent: accent,
      depth: 4,
      radius: 20,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const FocusScreen())),
      semanticLabel: 'نصيحة النهاردة',
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topEnd,
            end: AlignmentDirectional.bottomStart,
            colors: HomePalette.adviceGradient,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.24)),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedIdea01,
                  size: 23,
                  color: HomePalette.emeraldLight,
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
                      color: HomePalette.emeraldLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  TrText(
                    tip,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: HomePalette.textSecondary,
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

// ------------------------------------------------------------------ all tools

/// The full feature grid, preserving every entry the app exposes.
class _AllToolsSection extends StatelessWidget {
  const _AllToolsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('home-tools-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'قسم الأدوات',
          icon: HugeIcons.strokeRoundedDashboardSquare01,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TrText(
            'المكتبة الدراسية وكل أدوات رفيق الطالب على بُعد ضغطة واحدة.',
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
            // The cell must hold the glyph, both text blocks at their own
            // scale, and the padding; a flat 168 clips the text at 2.0x.
            final scaler = MediaQuery.textScalerOf(context);
            final text = Theme.of(context).textTheme;
            double block(TextStyle? style, double size, double height) =>
                2 *
                scaler.scale(style?.fontSize ?? size) *
                (style?.height ?? height);
            final needed = ZakerSpacing.md * 2 +
                38 + // glyph
                ZakerSpacing.sm +
                2 +
                block(text.titleSmall, 14, 1.43) +
                block(text.bodySmall, 12, 1.33) +
                // Line boxes round up to whole pixels; the slack keeps the
                // cell from overflowing its own text by a fraction.
                ZakerSpacing.xs;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: ZakerSpacing.md,
                crossAxisSpacing: ZakerSpacing.md,
                // A floor keeps the icon, title and subtitle together instead
                // of stretching into tall squares on wide screens, and the
                // scaled height lets the text grow with the user's setting.
                mainAxisExtent: needed < 168 ? 168 : needed,
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
    const colors = HomePalette.toolAccents;
    final tiles =
        <({String title, IconData icon, String? subtitle, VoidCallback onTap})>[
      (
        title: 'المكتبة الدراسية',
        icon: Icons.library_books_rounded,
        subtitle: 'كل الكتب والمناهج',
        onTap: () => context.push(ZakerRoutes.courses),
      ),
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

    Widget glassTile({
      required String title,
      required String? subtitle,
      required IconData icon,
      required Color accent,
      Widget? art,
      required VoidCallback onTap,
    }) {
      return FeatureTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        art: art,
        color: accent,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: HomePalette.tintedCardGradient(accent),
        ),
        borderColor: accent.withValues(alpha: 0.26),
        titleColor: HomePalette.textPrimary,
        subtitleColor: HomePalette.textSecondary,
        iconOnDark: true,
        onTap: onTap,
      );
    }

    return [
      glassTile(
        title: 'معلم AI',
        subtitle: 'اسأل واشرح',
        icon: Icons.auto_awesome_rounded,
        art: const AuroraAssistantMark(size: 38, radius: ZakerRadius.sm),
        accent: colors[0],
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      for (var i = 0; i < tiles.length; i++)
        glassTile(
          title: tiles[i].title,
          subtitle: tiles[i].subtitle,
          icon: tiles[i].icon,
          accent: colors[(i + 1) % colors.length],
          onTap: tiles[i].onTap,
        ),
    ];
  }
}

/// A section header with a Hugeicons glyph, matching the mockup.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 17,
          decoration: BoxDecoration(
            color: ZakerColors.gold,
            borderRadius: BorderRadius.circular(ZakerRadius.pill),
          ),
        ),
        const SizedBox(width: 7),
        HugeIcon(icon: icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        // Flexible so an Arabic title at 2.0x wraps instead of overflowing
        // the row.
        Flexible(
          child: TrText(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// The developer credit that closes the home scroll.
class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    return HomeGlassPanel(
      key: const Key('home-footer'),
      accent: HomePalette.champagne,
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: HomePalette.champagne.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: HomePalette.champagne.withValues(alpha: 0.30),
                  ),
                ),
                child: const Center(child: RafiqMark(size: 20)),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              // Flexible so the name wraps instead of overflowing the footer
              // row at 2.0x text on a 320 dp screen.
              Flexible(
                child: TrText(
                  RafiqBrand.appName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: HomePalette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  HomePalette.champagne.withValues(alpha: 0),
                  HomePalette.champagne.withValues(alpha: 0.42),
                  HomePalette.champagne.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const TrText(
            'من تطوير',
            style: TextStyle(
              color: HomePalette.textFaint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          const TrText(
            RafiqBrand.developer,
            key: Key('home-footer-copyright'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HomePalette.champagne,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    final tasks =
        ref.watch(taskScheduleProvider).forDay().where((e) => !e.done).toList();

    return SafeArea(
      // A short phone or 2.0x text can push the sheet past the screen; scroll
      // instead of overflowing so the two actions stay reachable.
      child: SingleChildScrollView(
        key: const Key('notifications-sheet-scroll'),
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
