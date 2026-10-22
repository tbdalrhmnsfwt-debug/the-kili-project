/// The home screen: a greeting, the user's study stats and a grid of the
/// app's features.
///
/// Feature names come from the shipped Arabic UI strings (see
/// `assets/data/i18n/en.json` for the English renderings).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../focus/focus_screen.dart';

/// The home screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(gradesProvider);
    final stats = ref.watch(studyStatsProvider);
    final notificationsOn = ref.watch(notificationsEnabledProvider);
    final pending = ref
        .watch(taskScheduleProvider)
        .forDay()
        .where((e) => !e.done)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(gradesProvider),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('ذاكرلي'),
              actions: [
                IconButton(
                  tooltip: 'المنبهات',
                  icon: Badge(
                    isLabelVisible: notificationsOn && pending.isNotEmpty,
                    label: Text('${pending.length}'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: ZakerRadius.sheet,
                    ),
                    builder: (_) => const _NotificationsSheet(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push(ZakerRoutes.settings),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  ZakerSpacing.sm,
                  ZakerSpacing.lg,
                  0,
                ),
                child: _GreetingCard(
                  streakDays: stats.streakDays,
                  minutesToday: stats.minutesToday,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  ZakerSpacing.xl,
                  ZakerSpacing.lg,
                  0,
                ),
                child: SectionHeader(
                  title: 'أدواتك',
                  icon: Icons.grid_view_rounded,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: ZakerSpacing.md,
                  crossAxisSpacing: ZakerSpacing.md,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildListDelegate(_featureTiles(context)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  ZakerSpacing.xl,
                  ZakerSpacing.lg,
                  ZakerSpacing.sm,
                ),
                child: SectionHeader(
                  title: 'مكتبتي',
                  icon: Icons.folder_rounded,
                  actionLabel: 'الكل',
                  onAction: () => context.push(ZakerRoutes.courses),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  0,
                  ZakerSpacing.lg,
                  ZakerSpacing.xxl,
                ),
                child: grades.when(
                  loading: () => const LoadingBox(),
                  error: (e, _) => EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'مقدرناش نحمّل المواد',
                    message: '$e',
                  ),
                  data: (list) => _RecentBooks(grades: list),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _featureTiles(BuildContext context) {
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

/// The greeting / streak card at the top of the home screen.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.streakDays, required this.minutesToday});

  final int streakDays;
  final int minutesToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, ZakerColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مساء الخير 👋',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            minutesToday == 0
                ? 'ابدأ أول جلسة النهارده وخلي سلسلتك تكبر.'
                : 'كمّلت $minutesToday دقيقة مذاكرة النهارده — كمّل!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              _pill(
                context,
                '🔥 $streakDays يوم',
                Icons.local_fire_department_rounded,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              _pill(context, '⭐ $minutesToday دقيقة', Icons.schedule_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZakerSpacing.md,
        vertical: ZakerSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: ZakerSpacing.xs),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The reminders sheet opened from the bell in the app bar.
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
            Text(
              'المنبهات',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZakerSpacing.xs),
            Text(
              enabled
                  ? 'دي المهام اللي مستنياك النهارده.'
                  : 'التنبيهات متوقفة — تقدر تفتحها من هنا.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تذكير المذاكرة'),
              value: enabled,
              onChanged: (value) =>
                  ref.read(notificationsEnabledProvider.notifier).state = value,
            ),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: ZakerSpacing.md),
                child: Text('مفيش مهام مجدولة النهارده — يومك فاضي.'),
              )
            else
              for (final task in tasks.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    task.important
                        ? Icons.priority_high_rounded
                        : Icons.schedule_rounded,
                    color: task.important
                        ? ZakerColors.accent
                        : theme.colorScheme.primary,
                  ),
                  title: Text(task.title),
                  subtitle: task.dueAt == null
                      ? null
                      : Text(
                          '${task.dueAt!.hour.toString().padLeft(2, '0')}:'
                          '${task.dueAt!.minute.toString().padLeft(2, '0')}',
                        ),
                ),
            const SizedBox(height: ZakerSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(ZakerRoutes.planner);
                },
                icon: const Icon(Icons.flag_rounded),
                label: const Text('افتح أهداف اليوم'),
              ),
            ),
          ],
        ),
      ),
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
          child: const Text('تصفح المواد'),
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
                  Text(
                    book.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
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
