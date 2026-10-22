/// The daily task list.
///
/// Shipped strings this screen is built from:
///   * `المهام`
///   * `قائمة المهام`
///   * `مهمة جديدة`
///   * `ضيف مهمة…`
///   * `ابدأ بأول مهمة`
///   * `مفيش مهام لسه`
///   * `مفيش مهام النهارده`
///   * `تذكير المهام`
///   * `تذكير بمهامك في معادها`
///   * `⭐ الحاجات المهمة — دوس تروحلها`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/schedule.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The tasks screen.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(taskScheduleProvider);
    final today = schedule.forDay();
    final important = today.where((e) => e.important && !e.done).toList();

    return Scaffold(
      appBar: AppBar(title: const TrText('المهام')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _ProgressCard(schedule: schedule),
          const SizedBox(height: ZakerSpacing.lg),
          if (important.isNotEmpty) ...[
            const SectionHeader(
              title: '⭐ الحاجات المهمة — دوس تروحلها',
              icon: Icons.star_rounded,
            ),
            for (final e in important)
              _TaskTile(entry: e, onToggle: () => _toggle(context, ref, e)),
            const SizedBox(height: ZakerSpacing.lg),
          ],
          SectionHeader(
            title: 'قائمة المهام',
            icon: Icons.checklist_rounded,
            actionLabel: 'مهمة جديدة',
            onAction: () => _add(context, ref),
          ),
          if (today.isEmpty)
            EmptyState(
              icon: Icons.checklist_outlined,
              title: 'مفيش مهام لسه',
              message: 'مفيش مهام من عندك النهارده — دوس «مهمة» وضيف اللي في دماغك.',
              action: FilledButton(
                onPressed: () => _add(context, ref),
                child: const TrText('ضيف مهمة…'),
              ),
            )
          else
            for (final e in today)
              _TaskTile(entry: e, onToggle: () => _toggle(context, ref, e)),
        ],
      ),
    );
  }

  void _add(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('مهمة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ضيف مهمة…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                final schedule = ref.read(taskScheduleProvider);
                ref.read(taskScheduleProvider.notifier).state = TaskSchedule(
                  title: schedule.title,
                  entries: [
                    ScheduleEntry(
                      id: 'task-${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      createdAt: DateTime.now(),
                    ),
                    ...schedule.entries,
                  ],
                );
              }
              Navigator.of(context).pop();
            },
            child: const TrText('ضيف'),
          ),
        ],
      ),
    );
  }

  void _toggle(BuildContext context, WidgetRef ref, ScheduleEntry entry) {
    final schedule = ref.read(taskScheduleProvider);
    ref.read(taskScheduleProvider.notifier).state = TaskSchedule(
      title: schedule.title,
      entries: [
        for (final e in schedule.entries)
          if (e.id == entry.id)
            ScheduleEntry(
              id: e.id,
              title: e.title,
              notes: e.notes,
              done: !e.done,
              important: e.important,
              dueAt: e.dueAt,
              dayOfWeek: e.dayOfWeek,
              createdAt: e.createdAt,
            )
          else
            e,
      ],
    );
  }
}

/// The progress card at the top.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.schedule});

  final TaskSchedule schedule;

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
          TrText(
            'مهام اليوم: ${schedule.doneCount} من ${schedule.total} خلصت.',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          ProgressBar(value: schedule.progress, height: 8),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '${schedule.doneCount}',
                label: 'خلصت',
                icon: Icons.check_circle_outline_rounded,
                color: ZakerColors.success,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${schedule.total - schedule.doneCount}',
                label: 'فاضلة',
                icon: Icons.pending_actions_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single task row.
class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.entry, required this.onToggle});

  final ScheduleEntry entry;
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
            border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Row(
            children: [
              Icon(
                entry.done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: entry.done
                    ? ZakerColors.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: TrText(
                  entry.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: entry.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (entry.important)
                Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: ZakerColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
