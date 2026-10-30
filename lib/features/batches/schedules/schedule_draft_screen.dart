/// Reviewing one imported timetable: uncertain rows, edits and publishing.
///
/// Nothing here talks to a server. The photo and its rows stay in the batch
/// directory, and publishing only changes the local document.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_ids.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/theme.dart';
import '../../../models/batch_schedule.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../providers/schedule_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import '../widgets/batch_notice.dart';
import 'schedule_access.dart';
import 'schedule_entry_editor.dart';
import 'schedule_support.dart';

class ScheduleDraftScreen extends ConsumerStatefulWidget {
  const ScheduleDraftScreen({
    super.key,
    required this.batchId,
    required this.draftId,
  });

  final String batchId;
  final String draftId;

  @override
  ConsumerState<ScheduleDraftScreen> createState() =>
      _ScheduleDraftScreenState();
}

class _ScheduleDraftScreenState extends ConsumerState<ScheduleDraftScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(batchDetailProvider(widget.batchId));
    final drafts = ref.watch(scheduleDraftsProvider(widget.batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final snapshot = detail.valueOrNull;

    TimetableDraft? draft;
    for (final item in drafts.valueOrNull ?? const <TimetableDraft>[]) {
      if (item.id == widget.draftId) draft = item;
    }
    final canEdit =
        snapshot != null && draft != null && canEditSchedules(snapshot, uid);
    final published = draft?.status == TimetableDraftStatus.published;

    return Scaffold(
      appBar: AppBar(
        title: TrText(published ? 'الجدول المنشور' : 'مراجعة الجدول'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'حذف الجدول',
              onPressed: _busy ? null : () => _confirmDelete(draft!),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _body(detail, drafts, snapshot, draft, canEdit),
      bottomNavigationBar: canEdit && !published ? _publishBar(draft) : null,
    );
  }

  Widget _body(
    AsyncValue<BatchSnapshot> detail,
    AsyncValue<List<TimetableDraft>> drafts,
    BatchSnapshot? snapshot,
    TimetableDraft? draft,
    bool canEdit,
  ) {
    final error = drafts.error ?? detail.error;
    if (error != null) {
      return ScheduleErrorView(
        failure: error is BatchFailure ? error : null,
        onRetry: () {
          ref.invalidate(batchDetailProvider(widget.batchId));
          ref.invalidate(scheduleDraftsProvider(widget.batchId));
        },
      );
    }
    if (detail.isLoading || drafts.isLoading) {
      return const Center(child: LoadingBox(label: 'بنقرا مواعيد الدفعة…'));
    }
    if (snapshot == null || draft == null) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'المسودة مش موجودة',
        message: 'يمكن اتمسحت. ارجع لقائمة المواعيد جرّب تاني.',
      );
    }
    return _review(draft, snapshot, canEdit);
  }

  Widget _review(
    TimetableDraft draft,
    BatchSnapshot snapshot,
    bool canEdit,
  ) {
    final theme = Theme.of(context);
    final entries = [...draft.entries]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final groups = <int, List<TimetableEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.dayOfWeek, () => []).add(entry);
    }
    final published = draft.status == TimetableDraftStatus.published;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        if (published) ...[
          const BatchNotice(
            icon: Icons.check_circle_outline_rounded,
            text: 'الجدول منشور. أي حد يفتح الدفعة على الجهاز ده هيشوفه.',
          ),
          const SizedBox(height: ZakerSpacing.md),
        ],
        if (!canEdit) ...[
          const BatchNotice(
            icon: Icons.visibility_outlined,
            text:
                'انت بتشوف الجدول بس. التعديل والنشر لصاحب الدفعة أو المسؤول.',
          ),
          const SizedBox(height: ZakerSpacing.md),
        ],
        if (draft.warnings.isNotEmpty) ...[
          _WarningsCard(warnings: draft.warnings),
          const SizedBox(height: ZakerSpacing.md),
        ],
        Text(
          '${arabicDigits(entries.length)} حصة · '
          '${published ? 'منشور' : 'مسودة'}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (draft.sourceImageFileName.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            'صورة الجدول الأصلية محفوظة مع المسودة على الجهاز.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: ZakerSpacing.md),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: ZakerSpacing.xl),
            child: Column(
              children: [
                const TrText(
                  'الصورة مفيهاش حصص اتقريت.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: ZakerSpacing.xs),
                TrText(
                  canEdit
                      ? 'تقدر تضيف الحصص بإيدك من تحت.'
                      : 'صاحب الدفعة يقدر يضيفها بإيده.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          for (final day in scheduleWeekOrder)
            if (groups[day] != null) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: ZakerSpacing.sm,
                  bottom: ZakerSpacing.xs,
                ),
                child: TrText(
                  weekdayName(day),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final entry in groups[day]!)
                _EntryTile(
                  entry: entry,
                  subjectName: _subjectName(snapshot, entry.subjectId),
                  onTap:
                      canEdit ? () => _editEntry(draft, snapshot, entry) : null,
                ),
            ],
        if (canEdit) ...[
          const SizedBox(height: ZakerSpacing.md),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _addEntry(draft, snapshot),
            icon: const Icon(Icons.add_rounded),
            label: const TrText('ضيف حصة'),
          ),
        ],
      ],
    );
  }

  Widget _publishBar(TimetableDraft draft) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.sm,
          ZakerSpacing.lg,
          ZakerSpacing.md,
        ),
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _publish(draft),
          icon: const Icon(Icons.publish_rounded),
          label: const TrText('انشر الجدول'),
        ),
      ),
    );
  }

  String? _subjectName(BatchSnapshot snapshot, String? subjectId) {
    if (subjectId == null) return null;
    for (final subject in snapshot.batch.subjects) {
      if (subject.id == subjectId) return subject.name;
    }
    return null;
  }

  Future<void> _editEntry(
    TimetableDraft draft,
    BatchSnapshot snapshot,
    TimetableEntry entry,
  ) async {
    final edited = await showModalBottomSheet<TimetableEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (_) => ScheduleEntryEditor(
        original: entry,
        subjects: snapshot.batch.subjects,
      ),
    );
    if (edited == null || !mounted) return;
    await _saveEntries(
      draft,
      [
        for (final item in draft.entries)
          if (item.id == edited.id) edited else item,
      ],
    );
  }

  Future<void> _addEntry(TimetableDraft draft, BatchSnapshot snapshot) async {
    final fresh = TimetableEntry(
      id: newEntityId('slot'),
      dayOfWeek: DateTime.saturday,
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
      title: '',
      recurrence: TimetableRecurrence.weekly,
    );
    final edited = await showModalBottomSheet<TimetableEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (_) => ScheduleEntryEditor(
        original: fresh,
        subjects: snapshot.batch.subjects,
      ),
    );
    if (edited == null || !mounted) return;
    await _saveEntries(draft, [...draft.entries, edited]);
  }

  Future<void> _saveEntries(
    TimetableDraft draft,
    List<TimetableEntry> entries,
  ) async {
    if (_busy) return;
    final hadReminders = draft.entries.any((item) => item.reminderEnabled);
    final hasReminders = entries.any((item) => item.reminderEnabled);
    setState(() => _busy = true);
    try {
      await ref.read(scheduleControllerProvider).saveDraft(
            widget.batchId,
            draft.copyWith(entries: List.unmodifiable(entries)),
          );
      _snack('اتحفظ الجدول.');
      if (hadReminders || hasReminders) await _syncReminders();
    } on BatchFailure catch (failure) {
      _snack(batchErrorText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish(TimetableDraft draft) async {
    if (_busy) return;
    final hasReminders = draft.entries.any((item) => item.reminderEnabled);
    setState(() => _busy = true);
    try {
      await ref
          .read(scheduleControllerProvider)
          .publish(widget.batchId, draft.id);
      _snack('الجدول اتنشر.');
      if (hasReminders) await _syncReminders();
    } on BatchFailure catch (failure) {
      _snack(
        failure.field == 'entries'
            ? 'فيه حصص لسه ناقصة. كمّل وقت النهاية والعنوان الأول.'
            : batchErrorText(failure),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Rebuilds the device's reminder queue and explains the two honest
  /// failure modes: notifications are off, or the device zone changed.
  Future<void> _syncReminders() async {
    try {
      final result = await ref
          .read(scheduleControllerProvider)
          .syncReminders(widget.batchId);
      if (result.permissionDenied) {
        _snack('الإشعارات مقفولة من إعدادات الجهاز، فالتذكير مش هيوصل.');
      } else if (result.timeZoneMismatch > 0) {
        _snack(
          'توقيت الجهاز اتغيّر. افتح الحصة واحفظها تاني عشان التذكير يرجع.',
        );
      }
    } on Object {
      _snack('التذكير مش اتظبط دلوقتي. جرّب تحفظ تاني.');
    }
  }

  /// Cancelling reminders must never make a successful delete look failed.
  Future<void> _resyncRemindersQuietly() async {
    try {
      await ref.read(scheduleControllerProvider).syncReminders(widget.batchId);
    } on Object {
      // The rows are already gone; the next successful save retries the queue.
    }
  }

  Future<void> _confirmDelete(TimetableDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('حذف الجدول؟'),
        content: const TrText(
          'الحصص وصورة الجدول هيتشالوا من الجهاز. مفيش نسخة على سيرفر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final hadReminders = draft.entries.any((item) => item.reminderEnabled);
    setState(() => _busy = true);
    try {
      await ref
          .read(scheduleControllerProvider)
          .delete(widget.batchId, draft.id);
      if (hadReminders) await _resyncRemindersQuietly();
      if (mounted) Navigator.of(context).pop();
    } on BatchFailure catch (failure) {
      _snack(batchErrorText(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              const TrText(
                'راجع الحاجات دي',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.xs),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(top: ZakerSpacing.xs),
              child: TrText(
                '• $warning',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.subjectName,
    this.onTap,
  });

  final TimetableEntry entry;
  final String? subjectName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uncertain = [
      for (final field in entry.uncertainFields) scheduleFieldLabel(field),
    ];
    final details = [
      if (entry.room.isNotEmpty) 'قاعة ${entry.room}',
      if (entry.teacher.isNotEmpty) entry.teacher,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: ZakerSpacing.xs,
                runSpacing: ZakerSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Tag(
                    text: formatScheduleRange(
                      entry.startMinutes,
                      entry.endMinutes,
                    ),
                    emphasise: true,
                  ),
                  if (entry.endMinutes == entry.startMinutes)
                    _Tag(
                      text: 'وقت النهاية ناقص',
                      colour: theme.colorScheme.error,
                    ),
                  if (entry.confidence > 0 && entry.confidence < 0.6)
                    _Tag(text: 'قراءة مش مؤكدة'),
                  if (entry.reminderEnabled) _Tag(text: 'تذكير قبل الحصة'),
                ],
              ),
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                entry.title.isEmpty ? 'من غير عنوان' : entry.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subjectName != null) ...[
                const SizedBox(height: 2),
                TrText(
                  subjectName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                TrText(
                  details.join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (uncertain.isNotEmpty) ...[
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  'مش متأكدين من: ${uncertain.join('، ')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.colour, this.emphasise = false});

  final String text;
  final Color? colour;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = colour ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZakerSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: emphasise ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: TrText(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
