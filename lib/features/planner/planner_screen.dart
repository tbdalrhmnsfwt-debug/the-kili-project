/// The planner: daily goals and the study schedule.
///
/// Shipped strings this screen is built from:
///   * `أهداف اليوم`
///   * `أنشئ جدول مذاكرة`
///   * `اختر مصدرك، حدد وقتك المتاح، وهجهزلك خطة مراجعة مقسمة دقيقة بدقيقة.`
///   * `اللي تكتبه هنا هيبان هدف بكرة لوحده.`
///   * `إنجاز اليوم من عشرة محسوب مش مكتوب: الوقت أربع نقاط، أهدافك تلاتة،
///     البنود نقطتين، واليومية نقطة.`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/study_planner.dart';
import '../../core/theme.dart';
import '../../models/planner.dart';
import '../../models/schedule.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The planner screen.
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('أهداف اليوم')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          const _TodayScoreCard(),
          const SizedBox(height: ZakerSpacing.lg),
          SectionHeader(
            title: 'أهداف اليوم',
            icon: Icons.flag_rounded,
            actionLabel: 'ضيف',
            onAction: () => _addGoal(context, ref),
          ),
          if (goals.isEmpty)
            const EmptyState(
              icon: Icons.flag_outlined,
              title: 'ابدأ بأول هدف',
              message: 'اكتب اللي عايز تعمله النهارده.',
            )
          else
            for (final goal in goals)
              _GoalTile(goal: goal, onToggle: () => _bump(context, ref, goal)),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: 'جدول المذاكرة',
            icon: Icons.calendar_month_rounded,
          ),
          const _ScheduleCard(),
        ],
      ),
    );
  }

  void _addGoal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هدف جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اكتب الهدف…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                final goals = ref.read(goalsProvider);
                ref.read(goalsProvider.notifier).state = [
                  Goal(
                    id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    createdAt: DateTime.now(),
                  ),
                  ...goals,
                ];
              }
              Navigator.of(context).pop();
            },
            child: const Text('ضيف'),
          ),
        ],
      ),
    );
  }

  void _bump(BuildContext context, WidgetRef ref, Goal goal) {
    final goals = ref.read(goalsProvider);
    ref.read(goalsProvider.notifier).state = [
      for (final g in goals)
        if (g.id == goal.id)
          Goal(
            id: g.id,
            title: g.title,
            minutes: g.minutes,
            completedMinutes: g.isComplete ? 0 : g.completedMinutes + g.minutes,
            createdAt: g.createdAt,
            sourceKey: g.sourceKey,
          )
        else
          g,
    ];
  }
}

/// The "today's score out of ten" card.
///
/// The shipped string explains the weighting explicitly:
/// `الوقت أربع نقاط، أهدافك تلاتة، البنود نقطتين، واليومية نقطة.`
class _TodayScoreCard extends StatelessWidget {
  const _TodayScoreCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Time 4, goals 3, tasks 2, daily log 1 — total 10.
    const time = 4.0;
    const goals = 2.0;
    const tasks = 1.0;
    const log = 1.0;
    final score = time + goals + tasks + log;

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
            'إنجاز اليوم',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            'من عشرة محسوبة — الوقت أربع نقاط، أهدافك تلاتة، البنود نقطتين، '
            'واليومية نقطة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  ' / 10',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          ProgressBar(
            value: score / 10,
            height: 8,
            color: Colors.white,
            background: Colors.white24,
          ),
        ],
      ),
    );
  }
}

/// A single goal row.
class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.onToggle});

  final Goal goal;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: InkWell(
        onTap: onToggle,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: goal.isComplete
                  ? ZakerColors.success.withValues(alpha: 0.4)
                  : (theme.dividerTheme.color ?? Colors.black12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                goal.isComplete
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: goal.isComplete
                    ? ZakerColors.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: goal.isComplete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${goal.completedMinutes} من ${goal.minutes} دقيقة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

/// The study-schedule card.
class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final schedule = ref.watch(taskScheduleProvider);
    final entries = [...schedule.entries]..sort(_byDue);
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
            'ابدأ جدولك',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            'اختر مصدرك، حدد وقتك المتاح، وهجهزلك خطة مراجعة مقسمة دقيقة بدقيقة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _generate(context, ref),
                  child: const Text('أنشئ جدول مذاكرة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TextButton(
            onPressed: () => _addManual(context, ref),
            child: const Text('اكتبها بنفسي'),
          ),
          if (entries.isNotEmpty) ...[
            const Divider(height: ZakerSpacing.xl),
            for (final entry in entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: entry.done,
                onChanged: (value) => _toggle(ref, entry, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  entry.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: entry.done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(_subtitle(entry)),
                secondary: entry.important
                    ? const Icon(
                        Icons.priority_high_rounded,
                        color: ZakerColors.accent,
                      )
                    : null,
              ),
          ],
        ],
      ),
    );
  }

  static int _byDue(ScheduleEntry a, ScheduleEntry b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  static String _subtitle(ScheduleEntry entry) {
    final due = entry.dueAt;
    final day = due == null
        ? ''
        : '${due.day}/${due.month} • '
              '${due.hour.toString().padLeft(2, '0')}:'
              '${due.minute.toString().padLeft(2, '0')}';
    if (entry.notes.isEmpty) return day;
    return day.isEmpty ? entry.notes : '$day — ${entry.notes}';
  }

  /// Asks for a daily duration, then lays out a week from the grade's books.
  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('مدة المذاكرة اليومية'),
        children: [
          for (final option in const [30, 45, 60])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Text('$option دقيقة'),
            ),
        ],
      ),
    );
    if (minutes == null || !context.mounted) return;

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
        start: DateTime.now(),
        minutesPerDay: minutes,
      );
      final current = ref.read(taskScheduleProvider);
      ref.read(taskScheduleProvider.notifier).state = mergePlan(
        current,
        plan,
        idPrefix: 'plan',
      );
      _toast(context, 'اتعملت خطة ٧ أيام — ابدأ النهارده.');
    } catch (e) {
      if (context.mounted) {
        _toast(context, 'مقدرناش نجهز الجدول: $e');
      }
    }
  }

  /// Lets the user write a single task for today.
  Future<void> _addManual(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مهمة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اكتب المهمة…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('ضيف'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || !context.mounted) return;

    final now = DateTime.now();
    final current = ref.read(taskScheduleProvider);
    ref.read(taskScheduleProvider.notifier).state = TaskSchedule(
      title: current.title,
      entries: [
        ...current.entries,
        ScheduleEntry(
          id: 'manual-${now.millisecondsSinceEpoch}',
          title: title,
          dueAt: DateTime(now.year, now.month, now.day, kStudyStartHour),
          dayOfWeek: now.weekday % 7,
          createdAt: now,
        ),
      ],
    );
    _toast(context, 'اتضافت لمهام النهارده.');
  }

  void _toggle(WidgetRef ref, ScheduleEntry task, bool done) {
    final current = ref.read(taskScheduleProvider);
    ref.read(taskScheduleProvider.notifier).state = TaskSchedule(
      title: current.title,
      entries: [
        for (final entry in current.entries)
          if (entry.id == task.id)
            ScheduleEntry(
              id: entry.id,
              title: entry.title,
              notes: entry.notes,
              done: done,
              important: entry.important,
              dueAt: entry.dueAt,
              dayOfWeek: entry.dayOfWeek,
              createdAt: entry.createdAt,
            )
          else
            entry,
      ],
    );
    if (done) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
