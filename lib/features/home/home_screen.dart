/// The home screen.
///
/// The compact order from the approved mockup: the top bar, the welcome strip
/// with [WelcomeSearch], the stat chips, the live prayer pill, the bag
/// preview, the three 3D action cards, the countdown and daily-advice
/// banners, the six-tool daily grid, the library shortcut and — last — the
/// complete feature grid so every screen stays one tap away.
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
import 'widgets/home_bag_preview.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/library_shortcut.dart';
import 'widgets/prayer_pill.dart';
import 'widgets/stats_strip.dart';
import 'widgets/welcome_search.dart';

/// The all-tools grid's accent cycle, drawn from the active appearance.
List<Color> _allToolsAccents(ZakerFeatureAccents accents) => [
      accents.assistant,
      accents.study,
      accents.tasks,
      accents.islamic,
      accents.qibla,
      accents.azkar,
      accents.hifz,
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
                    ref.invalidate(gradesProvider);
                    await ref.read(gradesProvider.future);
                  },
                  child: ListView(
                    key: const Key('home-body'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      WelcomeSearch(name: user?.displayName ?? 'ضيف'),
                      const SizedBox(height: ZakerSpacing.md),
                      HomeStatsStrip(
                        streakDays: stats.streakDays,
                        minutesToday: stats.minutesToday,
                        pendingCount: pending.length,
                      ),
                      const SizedBox(height: ZakerSpacing.md),
                      const PrayerPill(),
                      const SizedBox(height: ZakerSpacing.lg),
                      const HomeBagPreview(),
                      const SizedBox(height: ZakerSpacing.lg),
                      _ActionCards(streakDays: stats.streakDays),
                      const SizedBox(height: ZakerSpacing.md),
                      _BannerRow(
                        nextDeadline: nextDeadline,
                        onCountdown: () => context.push(ZakerRoutes.tasks),
                      ),
                      const SizedBox(height: 22),
                      const _DailyTools(),
                      const SizedBox(height: 22),
                      const LibraryShortcut(),
                      const SizedBox(height: 22),
                      const _AllToolsSection(),
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

// --------------------------------------------------------------- action cards

/// The three primary actions, rendered as raised 3D cards.
class _ActionCards extends StatelessWidget {
  const _ActionCards({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final accents = featureAccentsOf(Theme.of(context));
    final cards = <Widget>[
      _ActionCard(
        aurora: true,
        accent: accents.assistant,
        title: 'المساعد الذكي',
        subtitle: 'أسأل عن أي حاجة',
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      _ActionCard(
        icon: HugeIcons.strokeRoundedBookOpen01,
        accent: accents.study,
        title: 'المكتبة الدراسية',
        subtitle: 'كل الكتب والمناهج',
        onTap: () => context.push(ZakerRoutes.courses),
      ),
      _ActionCard(
        icon: HugeIcons.strokeRoundedTaskDone01,
        accent: accents.tasks,
        title: 'مهامي',
        subtitle:
            streakDays == 0 ? 'رتب مهام يومك' : 'مذاكرة $streakDays يوم متواصل',
        onTap: () => context.push(ZakerRoutes.tasks),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below 620 dp, or once the text is large, three side-by-side cards
        // squeeze their titles to nothing; stack them instead.
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 620 || scale > 1.3) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                SizedBox(width: double.infinity, child: cards[i]),
                if (i != cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 12),
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
    final accents = featureAccentsOf(theme);
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
      accent: accents.islamic,
      depth: 4,
      radius: 20,
      onTap: onTap,
      semanticLabel: 'العد التنازلي',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _wash(context, accents.islamic),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hairline(context, accents.islamic)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accents.islamic.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedHourglass,
                  size: 26,
                  color: accents.islamic,
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
                    style: TextStyle(
                      color: cardAccentOf(accents.islamic, theme),
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
                backgroundColor: accents.islamic.withValues(alpha: 0.16),
                hoverBackgroundColor: accents.islamic.withValues(alpha: 0.24),
                decoration: const ShadDecoration(shape: BoxShape.circle),
                onPressed: onTap,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 18,
                  color: accents.islamic,
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
    final accents = featureAccentsOf(theme);
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final tip = _tips[dayOfYear % _tips.length];

    return _Pressable3D(
      accent: accents.tasks,
      depth: 4,
      radius: 20,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const FocusScreen())),
      semanticLabel: 'نصيحة النهاردة',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _wash(context, accents.tasks),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hairline(context, accents.tasks)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accents.tasks.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedIdea01,
                  size: 23,
                  color: accents.tasks,
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
                      color: cardAccentOf(accents.tasks, theme),
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
    final accents = featureAccentsOf(Theme.of(context));
    final tools = <({
      List<List<dynamic>> icon,
      String label,
      Color accent,
      VoidCallback onTap,
    })>[
      (
        icon: HugeIcons.strokeRoundedCalculator01,
        label: 'الآلة الحاسبة',
        accent: accents.study,
        onTap: () => context.push(ZakerRoutes.calculator),
      ),
      (
        icon: HugeIcons.strokeRoundedPen01,
        label: 'الإعراب',
        accent: accents.azkar,
        onTap: () => context.push(ZakerRoutes.irab),
      ),
      (
        icon: HugeIcons.strokeRoundedCalendar03,
        label: 'خطة المذاكرة',
        accent: accents.tasks,
        onTap: () => context.push(ZakerRoutes.planner),
      ),
      (
        icon: HugeIcons.strokeRoundedTimer01,
        label: 'إدارة الوقت',
        accent: accents.qibla,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FocusScreen()),
            ),
      ),
      (
        icon: HugeIcons.strokeRoundedAnalytics01,
        label: 'متابعة التقدم',
        accent: accents.islamic,
        onTap: () => context.push(ZakerRoutes.weekly),
      ),
      (
        icon: HugeIcons.strokeRoundedTarget01,
        label: 'مراجعات',
        accent: accents.hifz,
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
    final colors = _allToolsAccents(featureAccentsOf(Theme.of(context)));
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
        color: colors[0],
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      for (var i = 0; i < tiles.length; i++)
        FeatureTile(
          title: tiles[i].title,
          subtitle: tiles[i].subtitle,
          icon: tiles[i].icon,
          color: colors[(i + 1) % colors.length],
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
        HugeIcon(icon: icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        TrText(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
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
    final tasks =
        ref.watch(taskScheduleProvider).forDay().where((e) => !e.done).toList();

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
