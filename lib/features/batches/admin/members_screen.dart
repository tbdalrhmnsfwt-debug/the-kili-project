/// Members of a local batch, with remote management shown as blocked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/theme.dart';
import '../../../models/batch.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import '../widgets/batch_notice.dart';

class BatchMembersScreen extends ConsumerWidget {
  const BatchMembersScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const TrText('الأعضاء')),
      body: detail.when(
        loading: () => const Center(child: LoadingBox(label: 'بنقرا الأعضاء…')),
        error: (error, _) => _MembersError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        ),
        data: (snapshot) {
          if (!canViewBatchAdmin(snapshot, uid)) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'الأعضاء لصاحب الدفعة أو المسؤول بس',
              message: 'قائمة الأعضاء الكاملة جزء من الإدارة.',
            );
          }
          return _MembersBody(snapshot: snapshot);
        },
      ),
    );
  }
}

class _MembersBody extends StatelessWidget {
  const _MembersBody({required this.snapshot});

  final BatchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = snapshot.members
        .where((member) => member.role == BatchRole.pending)
        .length;
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        if (pending > 0) ...[
          BatchNotice(
            icon: Icons.pending_actions_outlined,
            text: 'فيه ${arabicDigits(pending)} عضوية مستنية. الموافقة '
                'بين الأجهزة محتاجة سيرفر؛ الحالة محفوظة هنا للمستقبل.',
          ),
          const SizedBox(height: ZakerSpacing.md),
        ],
        if (pending == 0) ...[
          const BatchNotice(
            icon: Icons.phonelink_lock_rounded,
            text: 'مفيش أعضاء من أجهزة تانية. الأعضاء هنا هم الحسابات '
                'المسجلة على الجهاز ده بس.',
          ),
          const SizedBox(height: ZakerSpacing.md),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < snapshot.members.length; index++) ...[
                _MemberRow(
                  member: snapshot.members[index],
                  ownerUid: snapshot.batch.ownerUid,
                ),
                if (index != snapshot.members.length - 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: ZakerRadius.card,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                'الدعوة والكتم والإزالة محتاجين سيرفر',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: ZakerSpacing.xs),
              TrText(
                'على الجهاز ده الكود بيضيف عضوية محلية، لكنه مش بيوصل '
                'لأجهزة تانية. عشان كده مفيش أزرار دعوة أو كتم أو إزالة '
                'وهمية في الشاشة دي.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.ownerUid});

  final Membership member;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = member.uid == ownerUid;
    final name =
        member.displayName.isEmpty ? 'حساب على الجهاز' : member.displayName;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(
          isOwner ? Icons.workspace_premium_outlined : Icons.person_outline,
          size: 18,
          color: theme.colorScheme.primary,
        ),
      ),
      title: TrText(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: TrText(
        roleLabel(member.role),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: member.role == BatchRole.pending
          ? Icon(
              Icons.hourglass_top_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}

String roleLabel(BatchRole role) => switch (role) {
      BatchRole.owner => 'صاحب الدفعة',
      BatchRole.admin => 'مسؤول',
      BatchRole.member => 'عضو',
      BatchRole.pending => 'مستني موافقة',
      BatchRole.muted => 'مكتّم',
      BatchRole.removed => 'متشال',
    };

class _MembersError extends StatelessWidget {
  const _MembersError({this.failure, required this.onRetry});

  final BatchFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
              failure == null
                  ? 'مش قادرين نقرا الأعضاء.'
                  : batchErrorText(failure!),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZakerSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const TrText('حاول تاني'),
            ),
          ],
        ),
      ),
    );
  }
}
