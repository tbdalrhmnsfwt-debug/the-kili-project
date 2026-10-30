/// One update, with its local read state and the owner's edit controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../models/batch_update.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../providers/update_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import 'update_access.dart';

class UpdateDetailScreen extends ConsumerStatefulWidget {
  const UpdateDetailScreen({
    super.key,
    required this.batchId,
    required this.updateId,
  });

  final String batchId;
  final String updateId;

  @override
  ConsumerState<UpdateDetailScreen> createState() => _UpdateDetailScreenState();
}

class _UpdateDetailScreenState extends ConsumerState<UpdateDetailScreen> {
  /// The read mark is sent once per visit; the repository ignores repeats.
  bool _markSent = false;

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(batchUpdatesProvider(widget.batchId));
    final detail = ref.watch(batchDetailProvider(widget.batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final snapshot = detail.valueOrNull;
    final canManage = snapshot != null && canManageUpdates(snapshot, uid);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('تفاصيل المستجد'),
        actions: [
          if (canManage && updates.valueOrNull != null)
            ..._actions(context, updates.valueOrNull!),
        ],
      ),
      body: updates.when(
        loading: () => const Center(
          child: LoadingBox(label: 'بنقرا المستجد…'),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.sync_problem_rounded,
          title: 'مقدرناش نقرا المستجد',
          message: error is BatchFailure
              ? batchErrorText(error)
              : 'حصل خطأ مش معروف. جرّب تفتح الصفحة تاني.',
          action: FilledButton.icon(
            onPressed: () =>
                ref.invalidate(batchUpdatesProvider(widget.batchId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const TrText('جرّب تاني'),
          ),
        ),
        data: (items) {
          BatchUpdate? update;
          for (final item in items) {
            if (item.id == widget.updateId) update = item;
          }
          if (update == null) {
            return EmptyState(
              icon: Icons.campaign_outlined,
              title: 'المستجد مش موجود',
              message: 'يمكن اتحذف من جهاز تاني، أو الرابط مش صح.',
              action: TextButton(
                onPressed: () => context.pop(),
                child: const TrText('رجوع'),
              ),
            );
          }
          _markReadOnce(update, uid);
          return _body(context, update);
        },
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    List<BatchUpdate> items,
  ) {
    BatchUpdate? update;
    for (final item in items) {
      if (item.id == widget.updateId) update = item;
    }
    if (update == null) return const [];
    return [
      IconButton(
        tooltip: 'تعديل المستجد',
        onPressed: () => _openEditor(context, update!),
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: 'حذف المستجد',
        onPressed: () => _delete(context, update!),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    ];
  }

  Widget _body(BuildContext context, BatchUpdate update) {
    final theme = Theme.of(context);
    final meta = [
      updateKindLabel(update.kind),
      if (update.authorName.trim().isNotEmpty) update.authorName,
      formatBatchDate(update.createdAt),
      if (update.editedAt != null)
        'آخر تعديل ${formatBatchDate(update.editedAt!)}',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        TrText(
          update.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ZakerSpacing.xs),
        TrText(
          meta.join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (update.pinned) ...[
          const SizedBox(height: ZakerSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.push_pin_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: ZakerSpacing.xs),
              const TrText('مثبّت'),
            ],
          ),
        ],
        const Divider(height: ZakerSpacing.xl),
        if (update.body.trim().isEmpty)
          TrText(
            'المستجد ده فيه عنوان بس.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          TrText(
            update.body,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
      ],
    );
  }

  void _markReadOnce(BatchUpdate update, String uid) {
    if (_markSent || uid.isEmpty || update.isReadBy(uid)) return;
    _markSent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
    });
  }

  Future<void> _markRead() async {
    if (!mounted) return;
    try {
      await ref
          .read(batchUpdatesControllerProvider)
          .markRead(widget.batchId, widget.updateId);
    } on Object {
      // Read state is a convenience; the post stays readable without it.
    }
  }

  void _openEditor(BuildContext context, BatchUpdate update) {
    context.push(
      ZakerRoutes.batchUpdateEdit(widget.batchId, update.id),
      extra: update,
    );
  }

  Future<void> _delete(BuildContext context, BatchUpdate update) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('حذف المستجد؟'),
        content: const TrText(
          'المستجد هيتشال من الجهاز. مفيش نسخة على سيرفر.',
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
    try {
      await ref
          .read(batchUpdatesControllerProvider)
          .delete(widget.batchId, update.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: TrText('المستجد اتحذف.')));
      Navigator.of(context).pop();
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      _snack(batchErrorText(failure));
    } on Object {
      if (!mounted) return;
      _snack('الحذف ما تمّش. جرّب تاني.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: TrText(message)));
  }
}
