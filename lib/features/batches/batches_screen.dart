/// The batches tab: the local workspaces for the current account.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/batches/batch_failure.dart';
import '../../core/batches/batch_repository.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/batch_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../../widgets/zaker_visuals.dart';
import '../home/shell_screen.dart';
import 'batch_error_text.dart';

/// Lists the batches stored under the active uid.
class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(batchListProvider);
    final uid = ref.watch(authUserProvider)?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuLeading(context),
        title: const TrText('الدفعات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.read(batchControllerProvider).refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: batches.when(
        loading: () => const Center(child: LoadingBox(label: 'بنحمّل دفعاتك…')),
        error: (error, _) => _ErrorView(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.read(batchControllerProvider).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_2_outlined,
              title: 'مفيش دفعات على الجهاز',
              message:
                  'الدفعات بتتحفظ على الجهاز ده لوحده. المزايا اللي محتاجة '
                  'سيرفر — زي الانضمام من جهاز تاني وتوصيل الرسائل — '
                  'هتظهر كغير متاحة.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(batchListProvider);
              await ref.read(batchListProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              children: [
                const _LocalOnlyNotice(),
                const SizedBox(height: ZakerSpacing.md),
                for (final summary in items) ...[
                  _BatchCard(summary: summary, uid: uid),
                  const SizedBox(height: ZakerSpacing.md),
                ],
                const SizedBox(height: ZakerSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.failure, required this.onRetry});

  final BatchFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = failure == null
        ? 'حصل خطأ وإحنا بنقرا الدفعات.'
        : batchErrorText(failure!);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: ZakerSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('جرّب تاني'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalOnlyNotice extends StatelessWidget {
  const _LocalOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phonelink_lock_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              'الدفعات على الجهاز ده بس. مفيش مزامنة ولا أعضاء تانيين.',
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

class _BatchCard extends ConsumerWidget {
  const _BatchCard({required this.summary, required this.uid});

  final BatchSummary summary;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = summary.batch;
    if (batch == null) return _UnavailableCard(summary: summary);
    final theme = Theme.of(context);
    final isOwner = batch.ownerUid == uid;
    final code = batch.codeState;

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZakerGlassGlyph(
                icon: Icons.groups_2_outlined,
                accent: theme.colorScheme.primary,
                size: 42,
                iconSize: 22,
                radius: ZakerRadius.sm,
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      batch.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      '${batch.subjects.length} مواد · أنت بس على الجهاز',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.unreadUpdates > 0) ...[
                const SizedBox(width: ZakerSpacing.sm),
                _UnreadBadge(count: summary.unreadUpdates),
              ],
              if (isOwner)
                IconButton(
                  tooltip: 'حذف الدفعة',
                  onPressed: () => _confirmDelete(
                    context,
                    ref,
                    batchId: batch.id,
                    batchName: batch.name,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaChip(
                icon: Icons.calendar_today_rounded,
                label: 'آخر نشاط: ${_formatDate(summary.lastActivityAt)}',
              ),
              if (isOwner && code.isActive)
                _CodeChip(code: code.code)
              else if (isOwner)
                const _MetaChip(
                  icon: Icons.key_off_rounded,
                  label: 'الكود متوقف',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref, {
    required String batchId,
    required String batchName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('حذف الدفعة؟'),
        content: TrText(
          'هيتم مسح «$batchName» وكل ملفاتها من الجهاز. '
          'مفيش نسخة على سيرفر، وأي ملفات شاركتها قبل كده مش هتتسحب.',
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
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(batchControllerProvider).deleteBatch(batchId);
      messenger.showSnackBar(
        const SnackBar(content: TrText('اتمسحت الدفعة من الجهاز.')),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: TrText('الحذف ما تمّش. جرّب تاني.')),
      );
    }
  }
}

class _UnavailableCard extends ConsumerWidget {
  const _UnavailableCard({required this.summary});

  final BatchSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final failure =
        summary.failure ?? const BatchFailure(BatchFailureCode.corruptStore);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_off_outlined,
            color: theme.colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'دفعة مش متاحة',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                TrText(
                  batchErrorText(failure),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'حذف الدفعة',
            onPressed: () => _confirmUnavailableDelete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnavailableDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('حذف الدفعة؟'),
        content: const TrText(
          'هيتم مسح مجلد الدفعة من الجهاز. البيانات التالفة مش هتترجع.',
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
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(batchControllerProvider).deleteBatch(summary.batchId);
      messenger.showSnackBar(
        const SnackBar(content: TrText('اتمسح مجلد الدفعة.')),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TrText(
        '$count جديد',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: TrText(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_rounded, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Flexible(
            child: TrText(
              'كود الدخول: $code',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
