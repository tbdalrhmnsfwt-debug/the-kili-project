/// The weekly report: the numbers for the week, the subject breakdown and
/// the plan for next week.
///
/// Shipped strings this screen is built from:
///   * `تقدمي الأسبوعي`
///   * `أسبوعك بالأرقام`
///   * `ملخص أسبوعك: ذاكرت قد إيه، وفين قوي وفين محتاج شغل.`
///   * `وقت المذاكرة مش بتكتبه — بيتقرا من جلسات التركيز اللي عملتها فعلا،
///      ومعاه مقارنة امبارح ومتوسط أسبوعك.`
///   * `متوسط أسبوعك {0} دقيقة`
///   * `سلسلتك نار! 🔥 أسبوع كامل من غير ما تفوت يوم.`
///   * `اعمل خطة الأسبوع الجاي`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/study_planner.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/weekly.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The weekday names, in the order the app shows them.
const List<String> _arabicWeekdays = [
  'السبت', // السبت
  'الأحد', // الأحد
  'الإثنين', // الإثنين
  'الثلاثاء', // الثلاثاء
  'الأربعاء', // الأربعاء
  'الخميس', // الخميس
  'الجمعة', // الجمعة
];

/// The weekly report screen.
class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key, this.weekStart});

  /// The first day of the week to show; defaults to the current week.
  final DateTime? weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(weeklyReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TrText(ZakerStrings.s_02316), // تقدمي الأسبوعي
        actions: [
          IconButton(
            tooltip: 'شارك تقريرك',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _share(context, report),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _WeekBanner(report: report),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_6a13c, // أسبوعك بالأرقام
            icon: Icons.insights_rounded,
          ),
          _NumbersGrid(report: report),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_d02d7, // نشاطك الأسبوع ده
            icon: Icons.bar_chart_rounded,
          ),
          _WeekChart(report: report),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_a42d6, // جدول الأسبوع بموادك
            icon: Icons.pie_chart_rounded,
          ),
          _SubjectBreakdown(report: report),
          const SizedBox(height: ZakerSpacing.lg),
          const _NextWeekCard(),
        ],
      ),
    );
  }

  /// Shares the week's headline numbers, falling back to the clipboard.
  Future<void> _share(BuildContext context, WeeklyReport report) async {
    final text =
        'تقريري الأسبوعي في ذاكرلي:\n'
        '${report.totalMinutes} دقيقة مذاكرة • '
        '${report.totalPoints} نقطة • '
        '${report.activeDayCount} يوم نشاط.\n'
        'سلسلتي ${report.streak} يوم 🔥';
    try {
      await Share.share(text);
    } catch (_) {
      if (!context.mounted) return;
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('اتنسخ ملخص أسبوعك — الصقه في أي مكان.')),
      );
    }
  }
}

/// The banner at the top: the streak and the summary line.
class _WeekBanner extends StatelessWidget {
  const _WeekBanner({required this.report});

  final WeeklyReport report;

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
          TrText(
            ZakerStrings.s_a3f5a, // ملخص أسبوعك…
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '${report.totalMinutes}',
                label: ZakerStrings.s_128c6, // الوقت
                icon: Icons.schedule_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${report.totalPoints}',
                label: ZakerStrings.s_0_1_b7157, // {0} نقطة • الأسبوع ده {1}
                icon: Icons.star_rounded,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          if (report.isPerfectWeek)
            TrText(
              ZakerStrings.s_6adc7, // سلسلتك نار! 🔥
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

/// The "your week in numbers" grid.
class _NumbersGrid extends StatelessWidget {
  const _NumbersGrid({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatChip(
                value: '${report.activeDayCount}',
                label: ZakerStrings.s_c91e0, // الأسبوع ده
                icon: Icons.event_available_rounded,
              ),
            ),
            const SizedBox(width: ZakerSpacing.sm),
            Expanded(
              child: StatChip(
                value: report.averageMinutes.toStringAsFixed(0),
                label: ZakerStrings.s_0_c7b5c, // متوسط أسبوعك {0} دقيقة
                icon: Icons.timelapse_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.sm),
        Row(
          children: [
            Expanded(
              child: StatChip(
                value: '${report.totalAnswers}',
                label: ZakerStrings.s_0120a, // أسئلة التحدي
                icon: Icons.quiz_rounded,
              ),
            ),
            const SizedBox(width: ZakerSpacing.sm),
            Expanded(
              child: StatChip(
                value: '${(report.accuracy * 100).round()}%',
                label: ZakerStrings.s_8d420, // محتاج شغل
                icon: Icons.track_changes_rounded,
                color: ZakerColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        TrText(
          ZakerStrings.s_abcda, // وقت المذاكرة مش بتكتبه…
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// The per-day bar chart.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = report.days;
    final max = days.isEmpty
        ? 1
        : days.fold<int>(
            1,
            (m, d) => d.focusMinutes > m ? d.focusMinutes : m,
          );

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++) ...[
            Expanded(
              child: _DayBar(
                name: _arabicWeekdays[i],
                minutes: i < days.length ? days[i].focusMinutes : 0,
                max: max,
                isToday: _isToday(days, i),
              ),
            ),
            if (i < 6) const SizedBox(width: ZakerSpacing.xs),
          ],
        ],
      ),
    );
  }

  bool _isToday(List<WeekDay> days, int index) {
    if (index >= days.length) return false;
    final now = DateTime.now();
    final d = days[index].date;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

/// One bar in the day chart.
class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.name,
    required this.minutes,
    required this.max,
    required this.isToday,
  });

  final String name;
  final int minutes;
  final int max;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = max <= 0 ? 0.0 : minutes / max;

    return Column(
      children: [
        TrText(
          '$minutes',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: ZakerSpacing.xs),
        Container(
          height: 80,
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: ratio.clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(ZakerRadius.sm),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZakerSpacing.xs),
        TrText(
          name,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}

/// The subject breakdown list.
class _SubjectBreakdown extends StatelessWidget {
  const _SubjectBreakdown({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (report.subjects.isEmpty) {
      return EmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: ZakerStrings.s_c1a24, // أسبوعك فاضي
        message: ZakerStrings.s_3124a, // كل جداولك في مكان واحد…
      );
    }

    final total = report.totalMinutes;
    return Column(
      children: [
        for (final s in report.subjects) ...[
          Container(
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
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TrText(
                        s.subject,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TrText(
                      '${s.focusMinutes} ${ZakerStrings.s_128c6}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.sm),
                ProgressBar(
                  value: total <= 0 ? 0 : s.focusMinutes / total,
                  height: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
        ],
      ],
    );
  }
}

/// The card that offers to plan the next week.
class _NextWeekCard extends ConsumerWidget {
  const _NextWeekCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            ZakerStrings.s_b2921, // تقريري الأسبوعي — خطة الأسبوع الجاي
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            ZakerStrings.s_2c465, // خطة المذاكرة الأسبوعية
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          FilledButton(
            onPressed: () => _planNextWeek(context, ref),
            child: const TrText(ZakerStrings.s_2c4ed), // اعمل خطة الأسبوع الجاي
          ),
        ],
      ),
    );
  }

  /// Adds seven study blocks starting next Saturday to the task schedule.
  Future<void> _planNextWeek(BuildContext context, WidgetRef ref) async {
    try {
      final grades = await ref.read(gradesProvider.future);
      if (!context.mounted) return;
      if (grades.isEmpty) {
        _toast(context, 'مفيش كتب متاحة دلوقتي.');
        return;
      }
      final gradeId = ref.read(selectedGradeProvider);
      final grade = grades.firstWhere(
        (g) => g.id == gradeId,
        orElse: () => grades.first,
      );
      if (grade.books.isEmpty) {
        _toast(context, 'مفيش كتب متاحة للصف ده.');
        return;
      }

      final plan = buildWeekSchedule(
        books: grade.books,
        start: nextWeekStart(),
        idPrefix: 'week-plan',
      );
      final current = ref.read(taskScheduleProvider);
      ref.read(taskScheduleProvider.notifier).state = mergePlan(
        current,
        plan,
        idPrefix: 'week-plan',
      );
      _toast(context, 'اتعملت خطة الأسبوع الجاي — ٧ أيام.');
    } catch (e) {
      _toast(context, 'مقدرناش نجهز الخطة: $e');
    }
  }

  void _toast(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }
}
