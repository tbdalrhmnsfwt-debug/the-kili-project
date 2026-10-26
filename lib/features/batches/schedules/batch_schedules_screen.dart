/// The timetable list: published schedules, drafts and photo import.
///
/// Recognition runs on this device. The sheet is honest about that and never
/// offers a cloud path.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/schedule_ocr_service.dart';
import '../../../core/router.dart';
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
import 'schedule_photo_picker.dart';
import 'schedule_support.dart';

class BatchSchedulesScreen extends ConsumerStatefulWidget {
  const BatchSchedulesScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BatchSchedulesScreen> createState() =>
      _BatchSchedulesScreenState();
}

class _BatchSchedulesScreenState extends ConsumerState<BatchSchedulesScreen> {
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _renewReminders());
  }

  /// Reopening the list renews the rolling reminder window. Failures stay
  /// silent: the list itself already reports read errors, and stale reminders
  /// are safer than a surprise snack about a secondary feature.
  Future<void> _renewReminders() async {
    if (!mounted) return;
    try {
      final drafts =
          await ref.read(scheduleDraftsProvider(widget.batchId).future);
      final hasReminders = drafts.any(
        (draft) =>
            draft.status == TimetableDraftStatus.published &&
            draft.entries.any((entry) => entry.reminderEnabled),
      );
      if (!hasReminders) return;
      await ref.read(scheduleControllerProvider).syncReminders(widget.batchId);
    } on Object {
      // The rows stay readable; the next save retries the queue.
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(batchDetailProvider(widget.batchId));
    final drafts = ref.watch(scheduleDraftsProvider(widget.batchId));
    final importState = ref.watch(
      scheduleImportControllerProvider(widget.batchId),
    );
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final snapshot = detail.valueOrNull;
    final canImport = snapshot != null && canImportSchedules(snapshot, uid);

    return Scaffold(
      appBar: AppBar(title: const TrText('المواعيد')),
      floatingActionButton: canImport && !importState.isWorking
          ? FloatingActionButton.extended(
              onPressed: _picking ? null : _startImport,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const TrText('استورد صورة'),
            )
          : null,
      body: drafts.when(
        loading: () => const Center(
          child: LoadingBox(label: 'بنقرا مواعيد الدفعة…'),
        ),
        error: (error, _) => ScheduleErrorView(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(
            scheduleDraftsProvider(widget.batchId),
          ),
        ),
        data: (items) => _list(items, canImport, importState),
      ),
    );
  }

  Widget _list(
    List<TimetableDraft> items,
    bool canImport,
    ScheduleImportState importState,
  ) {
    final published = [
      for (final draft in items)
        if (draft.status == TimetableDraftStatus.published) draft,
    ];
    final drafts = [
      for (final draft in items)
        if (draft.status != TimetableDraftStatus.published) draft,
    ];
    final working = importState.isWorking;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        96,
      ),
      children: [
        if (working) ...[
          _ImportProgress(
            job: importState.job,
            onCancel: () => ref
                .read(scheduleImportControllerProvider(widget.batchId).notifier)
                .cancel(),
          ),
          const SizedBox(height: ZakerSpacing.md),
        ],
        const BatchNotice(
          icon: Icons.phonelink_lock_rounded,
          text: 'صور الجدول بتتقرا على الجهاز وبتتحفظ في مساحة الدفعة. '
              'مفيش رفع لسيرفر.',
        ),
        const SizedBox(height: ZakerSpacing.md),
        if (items.isEmpty && !working)
          EmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'مفيش مواعيد على الجهاز',
            message: canImport
                ? 'صوّر جدول الحصص أو اختار صورة من المعرض، وراجع الحصص قبل '
                    'ما تنشرها.'
                : 'صاحب الدفعة لسه ماضافش جدول. لما يضيفه هتشوفه هنا.',
            action: canImport
                ? FilledButton.icon(
                    onPressed: _picking ? null : _startImport,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const TrText('استورد صورة الجدول'),
                  )
                : null,
          )
        else ...[
          if (published.isNotEmpty) ...[
            const _SectionHeading('الجدول المنشور'),
            for (final draft in published)
              _ScheduleCard(
                draft: draft,
                onTap: () => _open(draft),
              ),
            const SizedBox(height: ZakerSpacing.md),
          ],
          if (drafts.isNotEmpty) ...[
            _SectionHeading(
              published.isEmpty ? 'جداول محفوظة' : 'مسودات لسه مااتنشرتش',
            ),
            for (final draft in drafts)
              _ScheduleCard(
                draft: draft,
                onTap: () => _open(draft),
              ),
          ],
        ],
      ],
    );
  }

  void _open(TimetableDraft draft) {
    context.push(ZakerRoutes.batchScheduleDraft(widget.batchId, draft.id));
  }

  Future<void> _startImport() async {
    if (_picking) return;
    final state = ref.read(scheduleImportControllerProvider(widget.batchId));
    if (state.isWorking) return;

    final source = await _pickSource();
    if (source == null || !mounted) return;

    String? path;
    setState(() => _picking = true);
    try {
      path = await ref.read(schedulePhotoPickerProvider)(source);
    } on Object {
      if (mounted) _snack('مقدرناش نفتح الكاميرا أو المعرض.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (path == null || !mounted) return;

    final controller = ref.read(
      scheduleImportControllerProvider(widget.batchId).notifier,
    );
    final saved = await controller.importPhoto(path);
    if (!mounted) return;
    if (saved != null) {
      context.push(
        ZakerRoutes.batchScheduleDraft(widget.batchId, saved.id),
      );
      return;
    }
    final failure =
        ref.read(scheduleImportControllerProvider(widget.batchId)).failure;
    _snack(
      failure == null ? 'الحفظ ما تمّش. جرّب تاني.' : batchErrorText(failure),
    );
  }

  Future<SchedulePhotoSource?> _pickSource() {
    return showModalBottomSheet<SchedulePhotoSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const TrText('صوّر الجدول'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(SchedulePhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const TrText('اختار صورة من المعرض'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(SchedulePhotoSource.gallery),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  ZakerSpacing.sm,
                  ZakerSpacing.lg,
                  0,
                ),
                child: TrText(
                  'الصورة بتتقرا على الجهاز. لو مش واضحة، جرّب صورة أقرب '
                  'وأوضح.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: ZakerSpacing.sm,
        bottom: ZakerSpacing.xs,
      ),
      child: TrText(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.draft, required this.onTap});

  final TimetableDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final published = draft.status == TimetableDraftStatus.published;
    final details = [
      '${arabicDigits(draft.entries.length)} حصة',
      if (draft.warnings.isNotEmpty)
        '${arabicDigits(draft.warnings.length)} ملاحظة للمراجعة',
      'آخر تعديل ${formatBatchDate(draft.updatedAt)}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            published
                ? Icons.event_available_rounded
                : Icons.edit_calendar_outlined,
            color: theme.colorScheme.primary,
          ),
        ),
        title: TrText(
          published ? 'جدول منشور' : 'مسودة جدول',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: TrText(
          details.join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: published
            ? const Icon(Icons.check_circle_rounded, size: 18)
            : const Icon(Icons.chevron_left_rounded),
      ),
    );
  }
}

class _ImportProgress extends StatelessWidget {
  const _ImportProgress({required this.job, required this.onCancel});

  final ScheduleOcrJob? job;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: ZakerSpacing.sm),
                Expanded(
                  child: TrText(
                    job?.message ?? 'بنستنى صورة الجدول…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            const LinearProgressIndicator(minHeight: 3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onCancel,
                child: const TrText('إلغاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
