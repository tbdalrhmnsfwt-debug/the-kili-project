/// The tasks / assignments screen.
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
///
/// A task can carry notes, an important flag and a due date/time. When a due
/// time is set the OS notification is scheduled for it, so the reminder still
/// fires while the app is closed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_service.dart';
import '../../core/theme.dart';
import '../../models/schedule.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The sections the task list can be narrowed to.
enum _TaskFilter { all, today, upcoming, done }

/// The tasks screen.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(taskScheduleProvider);
    final now = DateTime.now();
    final entries = [...schedule.entries]..sort(_byDue);
    final important = entries.where((e) => e.important && !e.done).toList();
    final visible = _filtered(entries, now);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('المهام'),
        actions: [
          IconButton(
            tooltip: 'أجّل المهام المتأخرة يوم',
            onPressed: _rescheduleOverdue,
            icon: const Icon(Icons.update_rounded),
          ),
          IconButton(
            tooltip: 'مهمة جديدة',
            onPressed: _add,
            icon: const Icon(Icons.add_task_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _ProgressCard(entries: schedule.forDay(now)),
          const SizedBox(height: ZakerSpacing.md),
          _FilterBar(
            selected: _filter,
            onSelected: (value) => setState(() => _filter = value),
          ),
          if (important.isNotEmpty && _filter != _TaskFilter.done) ...[
            const SizedBox(height: ZakerSpacing.lg),
            const SectionHeader(
              title: '⭐ الحاجات المهمة — دوس تروحلها',
              icon: Icons.star_rounded,
            ),
            for (final e in important)
              _TaskTile(
                entry: e,
                onToggle: () => _toggle(e),
                onEdit: () => _edit(e),
                onDelete: () => _delete(e),
                onRemind: () => _remind(e),
              ),
          ],
          const SizedBox(height: ZakerSpacing.lg),
          SectionHeader(
            title: 'قائمة المهام',
            icon: Icons.checklist_rounded,
            actionLabel: 'مهمة جديدة',
            onAction: _add,
          ),
          if (visible.isEmpty)
            EmptyState(
              icon: Icons.checklist_outlined,
              title: _emptyTitle,
              message: _emptyMessage,
              action: FilledButton(
                onPressed: _add,
                child: const TrText('ضيف مهمة…'),
              ),
            )
          else
            for (final e in visible)
              _TaskTile(
                entry: e,
                onToggle: () => _toggle(e),
                onEdit: () => _edit(e),
                onDelete: () => _delete(e),
                onRemind: () => _remind(e),
              ),
        ],
      ),
    );
  }

  String get _emptyTitle => switch (_filter) {
    _TaskFilter.today => 'مفيش مهام النهارده',
    _TaskFilter.upcoming => 'مفيش مهام جاية',
    _TaskFilter.done => 'مفيش مهام خلصانة',
    _TaskFilter.all => 'مفيش مهام لسه',
  };

  String get _emptyMessage => switch (_filter) {
    _TaskFilter.today =>
      'مفيش مهام من عندك النهارده — دوس «مهمة» وضيف اللي في دماغك.',
    _TaskFilter.upcoming => 'ضيف مهمة بموعد جاي وهتلاقيها هنا.',
    _TaskFilter.done => 'أول ما تخلص مهمة هتتسجل في القسم ده.',
    _TaskFilter.all =>
      'مفيش مهام من عندك النهارده — دوس «مهمة» وضيف اللي في دماغك.',
  };

  List<ScheduleEntry> _filtered(List<ScheduleEntry> entries, DateTime now) {
    return switch (_filter) {
      _TaskFilter.all => entries,
      _TaskFilter.today => entries
          .where((e) => !e.done && (e.dueAt == null || e.isDueOn(now)))
          .toList(),
      _TaskFilter.upcoming => entries
          .where(
            (e) =>
                !e.done &&
                e.dueAt != null &&
                !e.isDueOn(now) &&
                e.dueAt!.isAfter(now),
          )
          .toList(),
      _TaskFilter.done => entries.where((e) => e.done).toList(),
    };
  }

  /// Pending tasks first, then by due time (undated last), then newest.
  static int _byDue(ScheduleEntry a, ScheduleEntry b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final aDue = a.dueAt;
    final bDue = b.dueAt;
    if (aDue == null && bDue == null) {
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    }
    if (aDue == null) return 1;
    if (bDue == null) return -1;
    return aDue.compareTo(bDue);
  }

  Future<void> _add() => _edit(null);

  /// Moves unfinished overdue tasks one day forward. Completed tasks keep
  /// their original dates and their tick.
  void _rescheduleOverdue() {
    final schedule = ref.read(taskScheduleProvider);
    final now = DateTime.now();
    final overdue = schedule.entries
        .where((entry) => entry.isOverdue(now))
        .toList();
    if (overdue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TrText('مفيش مهام متأخرة دلوقتي.')),
      );
      return;
    }
    var next = schedule;
    for (final entry in overdue) {
      next = next.replace(
        entry.copyWith(dueAt: entry.dueAt!.add(const Duration(days: 1))),
      );
    }
    ref.read(taskScheduleProvider.notifier).state = next;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TrText(
          '${overdue.length} مهمة اتأجلت يوم. المهام المكتملة ماتغيّرتش.',
        ),
      ),
    );
  }

  /// Opens the editor for a new task or an existing [entry].
  Future<void> _edit(ScheduleEntry? entry) async {
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (context) => _TaskEditor(entry: entry),
    );
    if (draft == null || !mounted) return;

    final schedule = ref.read(taskScheduleProvider);
    final updated = entry == null
        ? ScheduleEntry(
            id: 'task-${DateTime.now().microsecondsSinceEpoch}',
            title: draft.title,
            notes: draft.notes,
            important: draft.important,
            dueAt: draft.dueAt,
            createdAt: DateTime.now(),
          )
        : entry.copyWith(
            title: draft.title,
            notes: draft.notes,
            important: draft.important,
            dueAt: draft.dueAt,
            clearDueAt: draft.dueAt == null,
          );
    ref.read(taskScheduleProvider.notifier).state = schedule.upsert(updated);

    await _syncReminder(updated);
  }

  /// Toggles completion and drops the reminder once the task is done.
  Future<void> _toggle(ScheduleEntry entry) async {
    final schedule = ref.read(taskScheduleProvider);
    final updated = entry.copyWith(done: !entry.done);
    ref.read(taskScheduleProvider.notifier).state = schedule.replace(updated);

    if (updated.done) {
      await NotificationService.instance.cancelTaskReminder(updated.id);
    } else {
      await _syncReminder(updated);
    }
  }

  Future<void> _delete(ScheduleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('تمسح المهمة؟'),
        content: TrText('«${entry.title}» هتتشال من قايمة المهام.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const TrText('امسح'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final schedule = ref.read(taskScheduleProvider);
    ref.read(taskScheduleProvider.notifier).state = schedule.remove(entry.id);
    await NotificationService.instance.cancelTaskReminder(entry.id);
  }

  /// Schedules (or re-schedules) the task reminder at its due time.
  Future<void> _remind(ScheduleEntry entry) async {
    final due = entry.dueAt;
    if (due == null) {
      await _edit(entry);
      return;
    }
    final ok = await _syncReminder(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TrText(
          ok
              ? 'اتظبط تذكير «${entry.title}» على ${_formatDue(due, english: _isEnglish(context))}.'
              : 'مقدرناش نجدول التذكير — راجع إذن الإشعارات.',
        ),
      ),
    );
  }

  /// Keeps the OS reminder in sync with [entry]'s due time.
  Future<bool> _syncReminder(ScheduleEntry entry) async {
    final due = entry.dueAt;
    if (due == null || entry.done || !due.isAfter(DateTime.now())) {
      await NotificationService.instance.cancelTaskReminder(entry.id);
      return false;
    }
    return NotificationService.instance.scheduleTaskReminder(
      taskId: entry.id,
      title: entry.title,
      when: due,
      notes: entry.notes,
    );
  }
}

/// The progress card at the top.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.entries});

  final List<ScheduleEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = entries.length;
    final done = entries.where((e) => e.done).length;
    final progress = total == 0 ? 0.0 : done / total;

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
            'مهام اليوم: $done من $total خلصت.',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          ProgressBar(value: progress, height: 8),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '$done',
                label: 'خلصت',
                icon: Icons.check_circle_outline_rounded,
                color: ZakerColors.success,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${total - done}',
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

/// The all / today / upcoming / done filter row.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final _TaskFilter selected;
  final ValueChanged<_TaskFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _TaskFilter.all: 'الكل',
      _TaskFilter.today: 'النهارده',
      _TaskFilter.upcoming: 'جاية',
      _TaskFilter.done: 'خلصت',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            ChoiceChip(
              selected: selected == entry.key,
              onSelected: (_) => onSelected(entry.key),
              label: TrText(entry.value),
            ),
            const SizedBox(width: ZakerSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// A single task row with edit, delete and reminder actions.
class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.entry,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onRemind,
  });

  final ScheduleEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = entry.isOverdue();
    final due = entry.dueAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onEdit,
          borderRadius: ZakerRadius.card,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.md,
              ZakerSpacing.sm,
              ZakerSpacing.xs,
              ZakerSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: ZakerRadius.card,
              border: Border.all(
                color: overdue
                    ? ZakerColors.danger.withValues(alpha: 0.5)
                    : theme.dividerTheme.color ?? Colors.black12,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: entry.done ? 'ارجعها' : 'خلصتها',
                  onPressed: onToggle,
                  icon: Icon(
                    entry.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: entry.done
                        ? ZakerColors.success
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: entry.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (entry.notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        TrText(
                          entry.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (due != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              overdue
                                  ? Icons.notification_important_rounded
                                  : Icons.schedule_rounded,
                              size: 14,
                              color: overdue
                                  ? ZakerColors.danger
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: TrText(
                                _formatDue(due, english: _isEnglish(context)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: overdue
                                      ? readableTextColor(
                                          ZakerColors.danger,
                                          theme.colorScheme.surface,
                                        )
                                      : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (entry.important)
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: ZakerColors.accent,
                  ),
                PopupMenuButton<String>(
                  tooltip: 'خيارات',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'remind') {
                      onRemind();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: TrText('تعديل'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remind',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.alarm_add_rounded),
                        title: TrText('تذكير'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: TrText('حذف'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The values returned by [_TaskEditor].
class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.notes,
    required this.important,
    required this.dueAt,
  });

  final String title;
  final String notes;
  final bool important;
  final DateTime? dueAt;
}

/// The add / edit task dialog.
class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.entry});

  final ScheduleEntry? entry;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.entry?.title ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.entry?.notes ?? '');
  late bool _important = widget.entry?.important ?? false;
  late DateTime? _dueAt = widget.entry?.dueAt;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: TrText(widget.entry == null ? 'مهمة جديدة' : 'تعديل المهمة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'ضيف مهمة…'),
            ),
            const SizedBox(height: ZakerSpacing.md),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'تفاصيل (اختياري)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: const TrText('الموعد'),
              subtitle: TrText(
                _dueAt == null
                    ? 'من غير موعد'
                    : _formatDue(_dueAt!, english: _isEnglish(context)),
              ),
              trailing: _dueAt == null
                  ? const Icon(Icons.chevron_left_rounded)
                  : IconButton(
                      tooltip: 'شيل الموعد',
                      onPressed: () => setState(() => _dueAt = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
              onTap: _pickDue,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.star_outline_rounded),
              title: const TrText('مهمة مهمة'),
              subtitle: TrText(
                'بتظهر في قسم الحاجات المهمة فوق.',
                style: theme.textTheme.bodySmall,
              ),
              value: _important,
              onChanged: (value) => setState(() => _important = value),
            ),
            if (_dueAt != null)
              TrText(
                'هنبعتلك تذكير على الموبايل في المعاد ده.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed: _save,
          child: TrText(widget.entry == null ? 'ضيف' : 'احفظ'),
        ),
      ],
    );
  }

  /// Lets the user pick a date, then a time on that date.
  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final picked = time ?? TimeOfDay.fromDateTime(initial);
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(
      _TaskDraft(
        title: title,
        notes: _notes.text.trim(),
        important: _important,
        dueAt: _dueAt,
      ),
    );
  }
}

/// Whether the app is currently rendering the English interface.
bool _isEnglish(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en';

/// Formats a due time relative to today.
String _formatDue(DateTime due, {bool english = false}) {
  final now = DateTime.now();
  final day = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = day.difference(today).inDays;
  final time =
      '${due.hour.toString().padLeft(2, '0')}:'
      '${due.minute.toString().padLeft(2, '0')}';

  if (english) {
    return switch (difference) {
      0 => 'Today $time',
      1 => 'Tomorrow $time',
      -1 => 'Yesterday $time',
      _ =>
        '${_weekdaysEn[due.weekday % 7]} ${due.day} '
            '${_monthsEn[due.month - 1]} — $time',
    };
  }

  return switch (difference) {
    0 => 'النهارده $time',
    1 => 'بكرة $time',
    -1 => 'امبارح $time',
    _ => '${_weekdays[due.weekday % 7]} ${due.day} ${_months[due.month - 1]} — $time',
  };
}

const _weekdays = <String>[
  'الأحد',
  'الاتنين',
  'التلات',
  'الأربع',
  'الخميس',
  'الجمعة',
  'السبت',
];

const _months = <String>[
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

const _weekdaysEn = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const _monthsEn = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
