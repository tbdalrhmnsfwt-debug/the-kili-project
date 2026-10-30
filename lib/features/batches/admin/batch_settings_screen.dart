/// Owner-only batch policies and local storage maintenance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../models/batch.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_notice.dart';
import '../widgets/storage_usage_line.dart';

class BatchSettingsScreen extends ConsumerWidget {
  const BatchSettingsScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const TrText('إعدادات الدفعة')),
      body: detail.when(
        loading: () =>
            const Center(child: LoadingBox(label: 'بنفتح الإعدادات…')),
        error: (error, _) => _SettingsError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        ),
        data: (snapshot) {
          if (!isBatchOwner(snapshot, uid)) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'الإعدادات لصاحب الدفعة بس',
              message: 'المسؤول يقدر يرفع وينشر ويدير المحتوى، لكن تغيير '
                  'سياسات الدفعة وكودها وحدها من حق صاحب الدفعة.',
            );
          }
          return _SettingsForm(
            batchId: batchId,
            settings: snapshot.batch.settings,
          );
        },
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.batchId, required this.settings});

  final String batchId;
  final BatchSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late bool _uploadsAdminOnly = widget.settings.uploadsAdminOnly;
  late bool _requireApproval = widget.settings.requireApproval;
  late bool _allowMemberReminders = widget.settings.allowMemberReminders;
  bool _saving = false;

  bool get _dirty =>
      _uploadsAdminOnly != widget.settings.uploadsAdminOnly ||
      _requireApproval != widget.settings.requireApproval ||
      _allowMemberReminders != widget.settings.allowMemberReminders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        const BatchNotice(
          icon: Icons.phone_android_rounded,
          text: 'الإعدادات بتتحفظ على الجهاز ده وبتطبق على العضويات المحلية.',
        ),
        const SizedBox(height: ZakerSpacing.md),
        Material(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
              ),
              borderRadius: ZakerRadius.card,
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _uploadsAdminOnly,
                  onChanged: (value) =>
                      setState(() => _uploadsAdminOnly = value),
                  title: const TrText('الرفع للمسؤول بس'),
                  subtitle: const TrText(
                    'لما يتقفل، الأعضاء النشطين يقدروا يرفعوا ملفاتهم.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _requireApproval,
                  onChanged: (value) =>
                      setState(() => _requireApproval = value),
                  title: const TrText('الانضمام محتاج موافقة'),
                  subtitle: const TrText(
                    'القرار بيتحفظ للمستقبل. الموافقة الفعلية بين الأجهزة '
                    'محتاجة سيرفر، فمفيش موافقة وهمية دلوقتي.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _allowMemberReminders,
                  onChanged: (value) =>
                      setState(() => _allowMemberReminders = value),
                  title: const TrText('تذكيرات المواعيد للأعضاء'),
                  subtitle: const TrText(
                    'التذكيرات بتتجدول على الجهاز ده بس، ومش بتوصل لأجهزة '
                    'الأعضاء التانيين.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        FilledButton.icon(
          onPressed: _saving || !_dirty ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: TrText(_saving ? 'بنحفظ…' : 'احفظ الإعدادات'),
        ),
        const SizedBox(height: ZakerSpacing.md),
        TextButton(
          onPressed: _dirty
              ? () => setState(() {
                    _uploadsAdminOnly = widget.settings.uploadsAdminOnly;
                    _requireApproval = widget.settings.requireApproval;
                    _allowMemberReminders =
                        widget.settings.allowMemberReminders;
                  })
              : null,
          child: const TrText('رجّع التغييرات'),
        ),
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(title: 'المساحة على الجهاز'),
        const SizedBox(height: ZakerSpacing.sm),
        StorageUsageLine(batchId: widget.batchId),
        const SizedBox(height: ZakerSpacing.sm),
        const TrText(
          'تنضيف الكاش بيشيل النصوص المستخرجة والصور المصغّرة بس. الملفات '
          'الأصلية والملاحظات ما بتتلمسش.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        OutlinedButton.icon(
          onPressed: _prune,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const TrText('نضّف الكاش'),
        ),
        const SizedBox(height: ZakerSpacing.lg),
      ],
    );
  }

  Future<void> _save() async {
    if (_uploadsAdminOnly && !widget.settings.uploadsAdminOnly) {
      final confirmed = await _confirmDisableUploads();
      if (!confirmed || !mounted) return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(batchControllerProvider).updateSettings(
            widget.batchId,
            widget.settings.copyWith(
              uploadsAdminOnly: _uploadsAdminOnly,
              requireApproval: _requireApproval,
              allowMemberReminders: _allowMemberReminders,
            ),
          );
      messenger.showSnackBar(
        const SnackBar(content: TrText('الإعدادات اتحفظت.')),
      );
      if (mounted) setState(() => _saving = false);
    } on BatchFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _prune() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(batchControllerProvider).pruneCaches(widget.batchId);
    messenger.showSnackBar(
      const SnackBar(
          content: TrText('الكاش اتنضّف. الملفات الأصلية زي ما هي.')),
    );
  }

  Future<bool> _confirmDisableUploads() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('تقفل الرفع للأعضاء؟'),
        content: const TrText(
          'الأعضاء النشطين مش هيقدروا يرفعوا ملفات جديدة. الملفات الموجودة '
          'بتفضل زي ما هي.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('اقفل الرفع'),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({this.failure, required this.onRetry});

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
                  ? 'مش قادرين نفتح الإعدادات.'
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
