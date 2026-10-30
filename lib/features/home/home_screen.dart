/// The home screen.
///
/// The approved light-theme order: the app bar with notifications and
/// settings, the welcome progress card, the search field, the live prayer
/// badge and stat chips, the three quick actions, the six core-feature cards,
/// the countdown and daily-advice banners, the all-tools shelf, and the
/// developer credit at the bottom.
///
/// Every surface shares the light dashboard language in [HomeLight]: a soft
/// blue-grey page, white or pastel 24 dp cards, navy ink and a soft shadow.
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

import '../../core/brand/rafiq_brand.dart';
import '../../core/brand/rafiq_mark.dart';
import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/schedule.dart';
import '../../providers/app_providers.dart';
import '../../widgets/tr_text.dart';
import '../dashboard/widgets/feature_card_widget.dart';
import '../dashboard/widgets/header_widget.dart';
import '../focus/focus_screen.dart';
import 'shell_screen.dart';
import 'widgets/core_features_grid.dart';
import 'widgets/home_light_style.dart';
import 'widgets/prayer_pill.dart';
import 'widgets/stats_strip.dart';
import 'widgets/welcome_search.dart';

/// The home screen.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Anchors the "المزيد من الأدوات" card to the all-tools shelf.
  final GlobalKey _toolsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(studyStatsProvider);
    final user = ref.watch(authUserProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final schedule = ref.watch(taskScheduleProvider);
    final pending = schedule.forDay().where((e) => !e.done).toList();
    final nextDeadline = _nextDeadline(schedule.entries);
    final openDrawer = shellDrawerOpener(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HomeLight.page, HomeLight.pageAlt],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              children: [
                DashboardTopBar(
                  showBadge: notificationsOn && pending.isNotEmpty,
                  onMenu: openDrawer,
                  onNotifications: () => _showNotifications(context),
                  onSettings: () => context.push(ZakerRoutes.settings),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: HomeLight.blue,
                    backgroundColor: Colors.white,
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
                        // refresh must not escape the indicator as an
                        // unhandled error. The bag reports its own failure.
                      }
                    },
                    // A non-lazy scroll view keeps the all-tools section built,
                    // so the "المزيد من الأدوات" card can always scroll to it.
                    child: SingleChildScrollView(
                      key: const Key('home-body'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: _HomeHeader(
                              name: user?.displayName ?? 'طالب',
                              progress:
                                  (stats.minutesToday / 60).clamp(0.0, 1.0),
                              streakDays: stats.streakDays,
                              minutesToday: stats.minutesToday,
                              pendingCount: pending.length,
                            ),
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
                                const SizedBox(height: 14),
                                CoreFeaturesGrid(onMoreTools: _scrollToTools),
                                const SizedBox(height: 22),
                                _BannerRow(
                                  nextDeadline: nextDeadline,
                                  onCountdown: () =>
                                      context.push(ZakerRoutes.tasks),
                                ),
                                const SizedBox(height: 22),
                                _AllToolsSection(key: _toolsKey),
                                const SizedBox(height: ZakerSpacing.xl),
                                const _HomeFooter(),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  void _scrollToTools() {
    final target = _toolsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      alignment: 0.04,
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

/// The welcome card, search, live prayer badge and stat chips.
///
/// The card itself is [WelcomeProgressCard]; the search and the stat strip
/// stay outside it so the greeting remains the page's single focal point.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.name,
    required this.progress,
    required this.streakDays,
    required this.minutesToday,
    required this.pendingCount,
  });

  final String name;
  final double progress;
  final int streakDays;
  final int minutesToday;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WelcomeProgressCard(
          name: name,
          progress: progress,
          footer: const Align(
            alignment: AlignmentDirectional.centerStart,
            child: PrayerPill(compact: true),
          ),
        ),
        const SizedBox(height: 12),
        const WelcomeSearch(),
        const SizedBox(height: 12),
        HomeStatsStrip(
          streakDays: streakDays,
          minutesToday: minutesToday,
          pendingCount: pendingCount,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ quick actions

/// The three primary actions, always side by side in their own pastel fields.
///
/// The row is deliberately not a responsive stack: the brief asks for one
/// horizontal three-column band, so each child gets an [Expanded] share and
/// the contents shrink instead of dropping to a column.
class _OrganicActionCards extends StatelessWidget {
  const _OrganicActionCards();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickActionCard(
              cardKey: const Key('home-card-assistant'),
              icon: HugeIcons.strokeRoundedAiSparkles,
              accent: HomeLight.purple,
              gradient: HomeLight.assistantGradient,
              title: 'المساعد الذكي',
              subtitle: 'اسأل عن أي حاجة',
              onTap: () => context.push(ZakerRoutes.chat),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              cardKey: const Key('home-card-bag'),
              icon: HugeIcons.strokeRoundedShoppingBag01,
              accent: HomeLight.mint,
              gradient: HomeLight.bagGradient,
              title: 'ملفاتي بالمادة',
              subtitle: 'شنطة كل مادة',
              onTap: () => context.push(ZakerRoutes.bag),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionCard(
              cardKey: const Key('home-card-tasks'),
              icon: HugeIcons.strokeRoundedCheckList,
              accent: HomeLight.orange,
              gradient: HomeLight.tasksGradient,
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

/// One compact light card: white icon circle, centred labels and a coloured
/// arrow button. The labels shrink rather than overflow at large text scales.
class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.cardKey,
    required this.icon,
    required this.accent,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key cardKey;
  final List<List<dynamic>> icon;
  final Color accent;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tight = MediaQuery.sizeOf(context).width < 380;
    final badgeSize = tight ? 32.0 : 36.0;
    final arrowSize = tight ? 26.0 : 28.0;

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeLight.cardRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            key: cardKey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(HomeLight.cardRadius),
              boxShadow: HomeLight.shadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      size: tight ? 17 : 19,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TrText(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomeLight.ink,
                      fontSize: 12.5,
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
                    style: const TextStyle(
                      color: HomeLight.mutedStrong,
                      fontSize: 9.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: arrowSize,
                  height: arrowSize,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      size: tight ? 13 : 14,
                      color: Colors.white,
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
    const accent = HomeLight.orange;
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

    return Semantics(
      button: true,
      label: 'العد التنازلي',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeLight.cardRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: HomeLight.cardDecoration(
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: HomeLight.countdownGradient,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.16),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: HomeLight.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      TrText(
                        entry == null
                            ? 'حدد موعد مهمة وإحنا نحسب الأيام الباقية.'
                            : '${entry.title}${dateLabel == null ? '' : ' · $dateLabel'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: HomeLight.mutedStrong,
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
                          color: HomeLight.orangeDeep,
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TrText(
                        unitText,
                        style: const TextStyle(
                          color: HomeLight.mutedStrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  // The whole banner is already one labelled button; this is a
                  // visual affordance for the same tap, not a second target.
                  ExcludeSemantics(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.26),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    const accent = HomeLight.mint;
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final tip = _tips[dayOfYear % _tips.length];

    return Semantics(
      button: true,
      label: 'نصيحة النهاردة',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomeLight.cardRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FocusScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: HomeLight.cardDecoration(
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: HomeLight.adviceGradient,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedIdea01,
                      size: 23,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TrText(
                        'نصيحة النهاردة',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: HomeLight.mintDeep,
                        ),
                      ),
                      const SizedBox(height: 3),
                      TrText(
                        tip,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: HomeLight.mutedStrong,
                        ),
                      ),
                    ],
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

// ------------------------------------------------------------------ all tools

/// The full feature grid, preserving every entry the app exposes.
class _AllToolsSection extends StatelessWidget {
  const _AllToolsSection({super.key});

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
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: TrText(
            'المكتبة الدراسية وكل أدوات رفيق الطالب على بُعد ضغطة واحدة.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: HomeLight.mutedStrong,
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
            const spacing = 16.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final extent = featureCardExtent(
              tileWidth,
              textScale: scale,
              dense: true,
            );
            final tiles = _tiles(context);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                mainAxisExtent: extent,
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

    Widget toolTile({
      required int index,
      required String title,
      required String? subtitle,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return FeatureCard(
        key: Key('home-tool-$index'),
        title: title,
        subtitle: subtitle,
        icon: icon,
        dense: true,
        palette:
            FeatureCardPalette.cycle[index % FeatureCardPalette.cycle.length],
        onTap: onTap,
      );
    }

    return [
      toolTile(
        index: 0,
        title: 'معلم AI',
        subtitle: 'اسأل واشرح',
        icon: Icons.auto_awesome_rounded,
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      for (var i = 0; i < tiles.length; i++)
        toolTile(
          index: i + 1,
          title: tiles[i].title,
          subtitle: tiles[i].subtitle,
          icon: tiles[i].icon,
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
    return Row(
      children: [
        Container(
          width: 3,
          height: 17,
          decoration: BoxDecoration(
            color: HomeLight.blue,
            borderRadius: BorderRadius.circular(ZakerRadius.pill),
          ),
        ),
        const SizedBox(width: 7),
        HugeIcon(icon: icon, size: 20, color: HomeLight.blue),
        const SizedBox(width: 8),
        // Flexible so an Arabic title at 2.0x wraps instead of overflowing
        // the row.
        Flexible(
          child: TrText(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: HomeLight.ink,
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
    return Container(
      key: const Key('home-footer'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: HomeLight.cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: HomeLight.deepBlueGradient.last,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(child: RafiqMark(size: 20)),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              // Flexible so the name wraps instead of overflowing the footer
              // row at 2.0x text on a 320 dp screen.
              const Flexible(
                child: TrText(
                  RafiqBrand.appName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HomeLight.ink,
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
            color: HomeLight.border,
          ),
          const SizedBox(height: 12),
          const TrText(
            'من تطوير',
            style: TextStyle(
              color: HomeLight.muted,
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
              color: HomeLight.blue,
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
