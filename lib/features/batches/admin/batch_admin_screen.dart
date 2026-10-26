/// Local administration: joins, members, code, policies, content, storage,
/// the audit trail and deletion.
///
/// Approvals and remote member management are shown as blocked, never faked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_code_service.dart';
import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/batches/hub_summary.dart';
import '../../../core/router.dart';
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
import '../widgets/storage_usage_line.dart';

class BatchAdminScreen extends ConsumerWidget {
  const BatchAdminScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const TrText('إدارة الدفعة'),
        actions: [
          IconButton(
            tooltip: 'إعدادات الدفعة',
            onPressed: () =>
                context.push(ZakerRoutes.batchAdminSettings(batchId)),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: LoadingBox(label: 'بنفتح الإدارة…')),
        error: (error, _) => _AdminError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        ),
        data: (snapshot) {
          if (!canViewBatchAdmin(snapshot, uid)) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'الإدارة مش متاحة للحساب ده',
              message: 'إدارة الدفعة متاحة لصاحب الدفعة أو المسؤول فقط.',
            );
          }
          return _AdminBody(batchId: batchId, snapshot: snapshot, uid: uid);
        },
      ),
    );
  }
}

class _AdminBody extends ConsumerWidget {
  const _AdminBody({
    required this.batchId,
    required this.snapshot,
    required this.uid,
  });

  final String batchId;
  final BatchSnapshot snapshot;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owner = isBatchOwner(snapshot, uid);
    final hub = ref.watch(batchHubDataProvider(batchId));
    final audit = ref.watch(batchAuditProvider(batchId));

    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        const BatchNotice(
          icon: Icons.phone_android_rounded,
          text: 'الإدارة هنا محلية: بتشتغل على دفعة الجهاز ده بس، ومفيش '
              'أعضاء تانيين بيتأثروا.',
        ),
        const SizedBox(height: ZakerSpacing.md),
        _AdminCard(
          icon: Icons.how_to_reg_outlined,
          title: 'طلبات الانضمام',
          subtitle: 'مفيش طلبات على الجهاز',
          onTap: () => context.push(ZakerRoutes.batchAdminRequests(batchId)),
          child: const TrText(
            'الموافقة والرفض بين الأجهزة محتاجين سيرفر، فمفيش أزرار موافقة '
            'وهمية هنا.',
            style: TextStyle(height: 1.5),
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        _AdminCard(
          icon: Icons.groups_2_outlined,
          title: 'الأعضاء',
          subtitle: '${arabicDigits(snapshot.members.length)} على الجهاز',
          onTap: () => context.push(ZakerRoutes.batchAdminMembers(batchId)),
          child: const TrText(
            'الدعوة والكتم والإزالة بين الأجهزة محتاجة سيرفر. العضويات '
            'المحلية بتتدار من الكود على الجهاز ده.',
            style: TextStyle(height: 1.5),
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        _InviteCodeCard(
          batchId: batchId,
          codeState: snapshot.batch.codeState,
          owner: owner,
        ),
        const SizedBox(height: ZakerSpacing.md),
        _AdminCard(
          icon: Icons.tune_rounded,
          title: 'الإعدادات والسياسات',
          subtitle: owner ? 'الرفع والانضمام والتذكيرات' : 'لصاحب الدفعة بس',
          onTap: owner
              ? () => context.push(ZakerRoutes.batchAdminSettings(batchId))
              : null,
          child: _PolicySummary(settings: snapshot.batch.settings),
        ),
        const SizedBox(height: ZakerSpacing.md),
        _ContentCard(
          batchId: batchId,
          subjectCount: snapshot.batch.subjects.length,
          hub: hub,
        ),
        const SizedBox(height: ZakerSpacing.md),
        _AdminCard(
          icon: Icons.sd_storage_outlined,
          title: 'المساحة على الجهاز',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StorageUsageLine(batchId: batchId),
              const SizedBox(height: ZakerSpacing.sm),
              const TrText(
                'تنضيف الكاش بيشيل النصوص المستخرجة والصور المصغّرة بس. '
                'ملفاتك الأصلية ما بتتلمسش.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: ZakerSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _pruneCaches(context, ref),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const TrText('نضّف الكاش'),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        _AuditCard(batchId: batchId, audit: audit),
        if (owner) ...[
          const SizedBox(height: ZakerSpacing.md),
          _DeleteCard(batchId: batchId, name: snapshot.batch.name),
        ],
        const SizedBox(height: ZakerSpacing.lg),
        TrText(
          'كل الأوامر دي بتتعاد مراجعتها في المستودع قبل ما تتنفذ.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
      ],
    );
  }

  Future<void> _pruneCaches(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(batchControllerProvider).pruneCaches(batchId);
    messenger.showSnackBar(
      const SnackBar(
          content: TrText('الكاش اتنضّف. الملفات الأصلية زي ما هي.')),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.child,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: ZakerRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: ZakerSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null)
                          TrText(
                            subtitle!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_left_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (child != null) ...[
                const SizedBox(height: ZakerSpacing.md),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySummary extends StatelessWidget {
  const _PolicySummary({required this.settings});

  final BatchSettings settings;

  @override
  Widget build(BuildContext context) {
    final upload = settings.uploadsAdminOnly
        ? 'الرفع للمسؤول بس'
        : 'كل الأعضاء النشطين يرفعوا';
    final join = settings.requireApproval
        ? 'الانضمام محتاج موافقة'
        : 'الانضمام مفتوح بالكود';
    return TrText(
      '$upload · $join',
      style: const TextStyle(height: 1.5),
    );
  }
}

class _InviteCodeCard extends ConsumerWidget {
  const _InviteCodeCard({
    required this.batchId,
    required this.codeState,
    required this.owner,
  });

  final String batchId;
  final InviteCodeState codeState;
  final bool owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _AdminCard(
      icon: Icons.key_rounded,
      title: 'كود الدعوة',
      subtitle: owner ? null : 'الكود لصاحب الدفعة بس',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (codeState.isActive)
            SelectableText(
              BatchCodeService.format(codeState.code),
              textDirection: TextDirection.ltr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else
            const TrText('مفيش كود فعّال.'),
          const SizedBox(height: ZakerSpacing.sm),
          const TrText(
            'الكود بيلاقي الدفعة على الجهاز ده بس. هو دعوة مش تسجيل دخول.',
            style: TextStyle(height: 1.5),
          ),
          if (owner) ...[
            const SizedBox(height: ZakerSpacing.sm),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _rotate(context, ref),
                  icon: const Icon(Icons.autorenew_rounded),
                  label: const TrText('كود جديد'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      codeState.isActive ? () => _revoke(context, ref) : null,
                  icon: const Icon(Icons.key_off_rounded),
                  label: const TrText('وقف الكود'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rotate(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'توليد كود جديد؟',
      message: 'الكود القديم هيتوقف، والكود الجديد ينفع على الجهاز ده بس.',
      confirmLabel: 'ولّد كود',
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(batchControllerProvider).rotateCode(batchId);
      messenger.showSnackBar(
        const SnackBar(content: TrText('اتولّد كود جديد.')),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'إيقاف كود الدعوة؟',
      message: 'الكود الحالي مش هيلاقي الدفعة بعد الإيقاف. تقدر تولّد كود '
          'جديد في أي وقت.',
      confirmLabel: 'وقف الكود',
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(batchControllerProvider).revokeCode(batchId);
      messenger.showSnackBar(
        const SnackBar(content: TrText('الكود اتوقف.')),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.batchId,
    required this.subjectCount,
    required this.hub,
  });

  final String batchId;
  final int subjectCount;
  final AsyncValue<BatchHubData> hub;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      icon: Icons.fact_check_outlined,
      title: 'مراجعة المحتوى',
      subtitle: 'اللي على الجهاز دلوقتي',
      child: hub.when(
        loading: () => const SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const TrText('مش قادرين نقرا محتوى الدفعة دلوقتي.'),
        data: (data) {
          final drafts = data.exams.where((exam) => !exam.isPublished).length;
          return Column(
            children: [
              _reviewRow(
                context,
                icon: Icons.menu_book_outlined,
                label: 'المواد',
                count: arabicDigits(subjectCount),
                onTap: () => context.push(ZakerRoutes.batchSubjects(batchId)),
              ),
              _reviewRow(
                context,
                icon: Icons.schedule_rounded,
                label: 'سطور المواعيد المنشورة',
                count: arabicDigits(data.scheduleEntryCount),
                onTap: () => context.push(ZakerRoutes.batchSchedules(batchId)),
              ),
              _reviewRow(
                context,
                icon: Icons.campaign_outlined,
                label: 'المستجدات',
                count: arabicDigits(data.updates.length),
                onTap: () => context.push(ZakerRoutes.batchUpdates(batchId)),
              ),
              _reviewRow(
                context,
                icon: Icons.quiz_outlined,
                label: 'الامتحانات',
                count: '${arabicDigits(data.exams.length)}'
                    '${drafts == 0 ? '' : ' (${arabicDigits(drafts)} مسودة)'}',
                onTap: () => context.push(ZakerRoutes.batchExams(batchId)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _reviewRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String count,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, size: 18, color: theme.colorScheme.primary),
      title: TrText(label, style: theme.textTheme.bodyMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrText(
            count,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.batchId, required this.audit});

  final String batchId;
  final AsyncValue<List<AuditEntry>> audit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AdminCard(
      icon: Icons.receipt_long_outlined,
      title: 'السجل المحلي',
      subtitle: 'آخر الأوامر على الجهاز',
      child: audit.when(
        loading: () => const SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, _) => TrText(
          error is BatchFailure
              ? batchErrorText(error)
              : 'مش قادرين نقرا السجل دلوقتي.',
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const TrText('مفيش أوامر مسجلة لسه.');
          }
          final shown = entries.take(12).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in shown) ...[
                _AuditRow(entry: entry),
                if (entry != shown.last)
                  Divider(
                    height: ZakerSpacing.md,
                    color: theme.dividerTheme.color,
                  ),
              ],
              if (entries.length > shown.length) ...[
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  'وباقي ${arabicDigits(entries.length - shown.length)} أمر '
                  'أقدم في السجل.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                'السجل محلي ومش مقاوم للتلاعب. مش بيحفظ نص رسالة ولا إجابة '
                'امتحان.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = entry.at.toLocal();
    final clock = formatScheduleTime(at.hour * 60 + at.minute);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(width: ZakerSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                auditActionLabel(entry.action),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TrText(
                '${at.day}/${at.month}/${at.year} · $clock',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeleteCard extends ConsumerWidget {
  const _DeleteCard({required this.batchId, required this.name});

  final String batchId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _AdminCard(
      icon: Icons.delete_forever_outlined,
      title: 'حذف الدفعة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrText(
            'الحذف بيشيل كل حاجة من الجهاز: الملفات والرسايل والمواعيد '
            'والمستجدات والامتحانات والمحاولات. مفيش نسخة على سيرفر.',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const TrText('احذف الدفعة'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('حذف الدفعة؟'),
        content: TrText(
          'هتتشال «$name» وكل ملفاتها ورسايلها ومواعيدها وامتحاناتها من '
          'الجهاز. الخطوة دي مش بترجع.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('احذف الدفعة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(batchControllerProvider).deleteBatch(batchId);
      router.go(ZakerRoutes.batches);
      messenger.showSnackBar(
        const SnackBar(content: TrText('الدفعة اتحذفت من الجهاز.')),
      );
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    }
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: TrText(title),
      content: TrText(message, style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: TrText(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

class _AdminError extends StatelessWidget {
  const _AdminError({this.failure, required this.onRetry});

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
                  ? 'مش قادرين نفتح الإدارة.'
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
