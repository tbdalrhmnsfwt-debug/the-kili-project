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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/weekly.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

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
      appBar: AppBar(title: const Text(ZakerStrings.s_02316)), // تقدمي الأسبوعي
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
          Text(
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
            Text(
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
        Text(
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
        Text(
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
        Text(
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
                      child: Text(
                        s.subject,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
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
class _NextWeekCard extends StatelessWidget {
  const _NextWeekCard();

  @override
  Widget build(BuildContext context) {
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
          Text(
            ZakerStrings.s_b2921, // تقريري الأسبوعي — خطة الأسبوع الجاي
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            ZakerStrings.s_2c465, // خطة المذاكرة الأسبوعية
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          FilledButton(
            onPressed: () {},
            child: const Text(ZakerStrings.s_2c4ed), // اعمل خطة الأسبوع الجاي
          ),
        ],
      ),
    );
  }
}
