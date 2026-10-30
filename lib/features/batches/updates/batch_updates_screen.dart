/// The updates timeline for one batch.
///
/// Every post is stored on this device. The screen says so instead of implying
/// that other members were notified.
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
import '../widgets/batch_notice.dart';
import 'update_access.dart';

class BatchUpdatesScreen extends ConsumerWidget {
  const BatchUpdatesScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final updates = ref.watch(batchUpdatesProvider(batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final snapshot = detail.valueOrNull;
    final canPost = snapshot != null && canPostUpdates(snapshot, uid);

    return Scaffold(
      appBar: AppBar(title: const TrText('المستجدات')),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(ZakerRoutes.batchUpdateNew(batchId)),
              icon: const Icon(Icons.campaign_outlined),
              label: const TrText('مستجد جديد'),
            )
          : null,
      body: updates.when(
        loading: () => const Center(
          child: LoadingBox(label: 'بنقرا المستجدات…'),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.sync_problem_rounded,
          title: 'مقدرناش نقرا المستجدات',
          message: error is BatchFailure
              ? batchErrorText(error)
              : 'حصل خطأ مش معروف. جرّب تفتح الصفحة تاني.',
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(batchUpdatesProvider(batchId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const TrText('جرّب تاني'),
          ),
        ),
        data: (items) => _list(context, items, uid, canPost),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<BatchUpdate> items,
    String uid,
    bool canPost,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        96,
      ),
      children: [
        const BatchNotice(
          icon: Icons.phonelink_lock_rounded,
          text: 'المستجدات بتتحفظ على الجهاز وبتظهر لكل حساب يفتح الدفعة من '
              'الجهاز ده. إشعار لباقي الأعضاء محتاج سيرفر.',
        ),
        const SizedBox(height: ZakerSpacing.md),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.campaign_outlined,
            title: 'مفيش مستجدات لسه',
            message: canPost
                ? 'اكتب أول مستجد للدفعة. هيتحفظ على الجهاز وتشوفه انت '
                    'واللي بيفتح الدفعة من الجهاز ده.'
                : 'صاحب الدفعة لسه ماضافش مستجدات. لما يضيفها هتشوفها هنا.',
            action: canPost
                ? FilledButton.icon(
                    onPressed: () =>
                        context.push(ZakerRoutes.batchUpdateNew(batchId)),
                    icon: const Icon(Icons.campaign_outlined),
                    label: const TrText('اكتب مستجد'),
                  )
                : null,
          )
        else
          for (final update in items)
            _UpdateCard(
              update: update,
              read: update.isReadBy(uid),
              onTap: () => context.push(
                ZakerRoutes.batchUpdate(batchId, update.id),
              ),
            ),
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    required this.read,
    required this.onTap,
  });

  final BatchUpdate update;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      updateKindLabel(update.kind),
      if (update.authorName.trim().isNotEmpty) update.authorName,
      formatBatchDate(update.createdAt),
      if (read) 'مقروء' else 'جديد',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: ListTile(
        onTap: onTap,
        isThreeLine: update.body.trim().isNotEmpty,
        leading: CircleAvatar(
          backgroundColor: read
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          child: Icon(
            update.pinned
                ? Icons.push_pin_rounded
                : read
                    ? Icons.mark_email_read_outlined
                    : Icons.campaign_outlined,
            size: 20,
            color: read
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
        ),
        title: TrText(
          update.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: read ? FontWeight.w600 : FontWeight.w800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.body.trim().isNotEmpty) ...[
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                update.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              meta.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_left_rounded),
      ),
    );
  }
}
