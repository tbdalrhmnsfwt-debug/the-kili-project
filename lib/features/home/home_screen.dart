/// The home screen.
///
/// Layout follows the design mockup: a teal greeting banner with a search
/// field, the three primary actions, the exam-countdown prompt and the
/// daily-tools grid. The data behind it is the app's own: the display name
/// comes from [authUserProvider], the streak/minutes from
/// [studyStatsProvider], the pending reminders from [taskScheduleProvider]
/// and the library strip from [gradesProvider].
///
/// The full feature grid that used to fill the home screen is kept below the
/// mockup's sections under "كل الأدوات", so every screen stays reachable.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadDecoration, ShadIconButton, ShadInput;

import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../focus/focus_screen.dart';

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

/// The home screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(gradesProvider);
    final stats = ref.watch(studyStatsProvider);
    final user = ref.watch(authUserProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final pending = ref
        .watch(taskScheduleProvider)
        .forDay()
        .where((e) => !e.done)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(gradesProvider),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _HeroBanner(
                  name: user?.displayName ?? 'ضيف',
                  showBadge: notificationsOn && pending.isNotEmpty,
                  onNotifications: () => _showNotifications(context),
                  onSettings: () => context.push(ZakerRoutes.settings),
                ),
                const SizedBox(height: 20),
                _ActionCards(streakDays: stats.streakDays),
                const SizedBox(height: 20),
                const _CountdownBanner(),
                const SizedBox(height: 28),
                const _DailyTools(),
                const SizedBox(height: 28),
                _LibrarySection(grades: grades),
                const SizedBox(height: 28),
                const _AllToolsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (_) => const _NotificationsSheet(),
    );
  }
}

// ---------------------------------------------------------------- hero banner

/// The greeting banner: greeting, name, banner actions and the search field.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.name,
    required this.showBadge,
    required this.onNotifications,
    required this.onSettings,
  });

  final String name;
  final bool showBadge;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : 'مساء الخير';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [ZakerColors.primary, ZakerColors.primaryLight],
        ),
        boxShadow: [
          BoxShadow(
            color: ZakerColors.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -56,
            right: -32,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
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
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: TrText(
                              '$greeting يا $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFCCFBF1),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TrText(
                            'عايز تعمل إيه النهاردة؟',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HeroButton(
                      icon: HugeIcons.strokeRoundedNotification01,
                      showDot: showBadge,
                      onTap: onNotifications,
                    ),
                    const SizedBox(width: 8),
                    _HeroButton(
                      icon: HugeIcons.strokeRoundedSettings01,
                      onTap: onSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SearchBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A translucent circular action in the banner.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final List<List<dynamic>> icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return ShadIconButton(
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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 20,
            color: Color(0xFFCCFBF1),
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
                fontFamily: ZakerTheme.fontBody,
                fontSize: 14,
              ),
              placeholder: const TrText(
                'اكتب... عني، امتحان، بكرة',
                style: TextStyle(
                  color: Color(0xFFB7E9E3),
                  fontFamily: ZakerTheme.fontBody,
                  fontSize: 14,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- action cards

/// The three primary actions.
class _ActionCards extends StatelessWidget {
  const _ActionCards({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _ActionCard(
        icon: HugeIcons.strokeRoundedRobot01,
        accent: _Accents.purple,
        title: 'المساعد الذكي',
        subtitle: 'أسأل عن أي حاجة',
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      _ActionCard(
        icon: HugeIcons.strokeRoundedFolder01,
        accent: _Accents.teal,
        title: 'ملفاتي بالمادة',
        subtitle: 'مراجعة، ملخصات وتعاريف',
        onTap: () => context.push(ZakerRoutes.courses),
      ),
      _ActionCard(
        icon: HugeIcons.strokeRoundedTaskDone01,
        accent: _Accents.blue,
        title: 'مهامي',
        subtitle: streakDays == 0
            ? 'رتب مهام يومك وحقق أهدافك'
            : 'مذاكرة $streakDays يوم على التوالي',
        onTap: () => context.push(ZakerRoutes.tasks),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
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
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _wash(context, accent),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _hairline(context, accent)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(icon: icon, size: 28, color: accent),
                ),
              ),
              const SizedBox(height: 12),
              TrText(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              TrText(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ShadIconButton(
                width: 44,
                height: 44,
                padding: EdgeInsets.zero,
                backgroundColor: accent,
                hoverBackgroundColor: accent.withValues(alpha: 0.85),
                pressedBackgroundColor: accent.withValues(alpha: 0.75),
                decoration: const ShadDecoration(shape: BoxShape.circle),
                onPressed: onTap,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ countdown prompt

/// The amber "add an exam countdown" banner.
class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(ZakerRoutes.exams),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _wash(context, _Accents.amber),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hairline(context, _Accents.amber)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _Accents.amber.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
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
                  children: [
                    TrText(
                      'أضف عد تنازلي لامتحاناتك',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    TrText(
                      'سنذكرك بالأيام المتبقية حتى لا يضيع وقتك',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ShadIconButton(
                width: 40,
                height: 40,
                padding: EdgeInsets.zero,
                backgroundColor: _Accents.amber.withValues(alpha: 0.16),
                hoverBackgroundColor: _Accents.amber.withValues(alpha: 0.24),
                decoration: const ShadDecoration(shape: BoxShape.circle),
                onPressed: () => context.push(ZakerRoutes.exams),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 18,
                  color: _Accents.amber,
                ),
              ),
            ],
          ),
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
            onTap: () => _comingSoon(context),
          ),
          (
            icon: HugeIcons.strokeRoundedPen01,
            label: 'الإعراب',
            accent: _Accents.amber,
            onTap: () => _comingSoon(context),
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
            const spacing = 12.0;
            final columns = constraints.maxWidth >= 720 ? 6 : 2;
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

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: TrText('الأداة دي هتتضاف قريب إن شاء الله.')),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: _wash(context, accent),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _hairline(context, accent)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: icon, size: 24, color: accent),
              const SizedBox(height: 10),
              TrText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- library

/// The "مكتبتي" strip of recently available books.
class _LibrarySection extends StatelessWidget {
  const _LibrarySection({required this.grades});

  final AsyncValue<List<Grade>> grades;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'مكتبتي',
          icon: HugeIcons.strokeRoundedBookOpen01,
          actionLabel: 'الكل',
          onAction: () => context.push(ZakerRoutes.courses),
        ),
        const SizedBox(height: 12),
        grades.when(
          loading: () => const LoadingBox(),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'مقدرناش نحمّل المواد',
            message: '$e',
          ),
          data: (list) => _RecentBooks(grades: list),
        ),
      ],
    );
  }
}

/// A horizontal list of recently-opened books.
class _RecentBooks extends StatelessWidget {
  const _RecentBooks({required this.grades});

  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books = <Book>[];
    for (final g in grades) {
      books.addAll(g.books);
    }
    if (books.isEmpty) {
      return EmptyState(
        icon: Icons.library_books_outlined,
        title: 'مكتبتك فاضية',
        message: 'افتح أي مادة وابدأ المذاكرة.',
        action: FilledButton(
          onPressed: () => context.push(ZakerRoutes.courses),
          child: const TrText('تصفح المواد'),
        ),
      );
    }
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length > 8 ? 8 : books.length,
        separatorBuilder: (_, __) => const SizedBox(width: ZakerSpacing.md),
        itemBuilder: (context, index) {
          final book = books[index];
          return InkWell(
            borderRadius: ZakerRadius.card,
            onTap: () => context.push('/${book.grade}/${book.id}'),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(ZakerSpacing.md),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: ZakerRadius.card,
                border: Border.all(
                  color: theme.dividerTheme.color ?? Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TrText(
                    book.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TrText(
                    '${book.lessons} درس',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ all tools

/// The full feature grid, preserving every entry the old home screen exposed.
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
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisCount: columns,
              mainAxisSpacing: ZakerSpacing.md,
              crossAxisSpacing: ZakerSpacing.md,
              childAspectRatio: 1.05,
              children: _tiles(context),
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
            title: 'معلم AI',
            icon: Icons.smart_toy_rounded,
            subtitle: 'اسأل واشرح',
            onTap: () => context.push(ZakerRoutes.chat),
          ),
          (
            title: 'امتحان',
            icon: Icons.fact_check_rounded,
            subtitle: 'اختبار بالدرجات',
            onTap: () => context.push(ZakerRoutes.exams),
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
      for (final t in tiles)
        FeatureTile(
          title: t.title,
          subtitle: t.subtitle,
          icon: t.icon,
          onTap: t.onTap,
        ),
    ];
  }
}

/// A section header with a Hugeicons glyph, matching the mockup.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<List<dynamic>> icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        HugeIcon(icon: icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: TrText(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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
