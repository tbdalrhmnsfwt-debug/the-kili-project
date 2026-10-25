/// The success screen after a batch is created: code, copy and honest share.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/batches/batch_code_service.dart';
import '../../core/batches/batch_failure.dart';
import '../../core/batches/batch_store.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/batch.dart';
import '../../providers/batch_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'batch_error_text.dart';

class BatchCreatedScreen extends ConsumerWidget {
  const BatchCreatedScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    return Scaffold(
      appBar: AppBar(title: const TrText('الدفعة اتعملت')),
      body: detail.when(
        loading: () => const Center(child: LoadingBox(label: 'بنفتح الدفعة…')),
        error: (error, _) => _CreatedError(
          failure: error is BatchFailure ? error : null,
          onRetry: () => ref.invalidate(batchDetailProvider(batchId)),
        ),
        data: (snapshot) => _CreatedBody(snapshot: snapshot),
      ),
    );
  }
}

class _CreatedBody extends StatelessWidget {
  const _CreatedBody({required this.snapshot});

  final BatchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = snapshot.batch;
    final code = batch.codeState;
    final grouped = BatchCodeService.format(code.code);
    final creator = _memberName(snapshot, batch.ownerUid);

    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        const SizedBox(height: ZakerSpacing.md),
        Icon(
          Icons.check_circle_rounded,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: ZakerSpacing.md),
        TrText(
          batch.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (creator.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            'صاحب الدفعة: $creator',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: ZakerSpacing.xl),
        if (code.isActive) ...[
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: ZakerRadius.card,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                const TrText(
                  'كود الدخول',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: ZakerSpacing.sm),
                SelectableText(
                  grouped,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copy(context, code.code),
                        icon: const Icon(Icons.copy_rounded),
                        label: const TrText('انسخ'),
                      ),
                    ),
                    const SizedBox(width: ZakerSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _share(context, batch, grouped),
                        icon: const Icon(Icons.share_rounded),
                        label: const TrText('شارك'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: ZakerRadius.card,
            ),
            child: const TrText(
              'الكود مش فعال. تقدر تولّد كود جديد من إدارة الدفعة.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: ZakerSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border:
                Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: ZakerSpacing.sm),
                  const Expanded(
                    child: TrText(
                      'الكود ده طريقة دعوة مش تسجيل دخول. على الجهاز ده '
                      'بيلاقي الدفعة ويوريك إنك عضو فيها. جهاز تاني مش هيعرف '
                      'يستخدمه لحد ما يبقى فيه سيرفر.',
                      style: TextStyle(height: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.sm),
              const TrText(
                'الدفعة وكل ملفاتها محفوظة على الجهاز ده لوحده.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZakerSpacing.xl),
        FilledButton.icon(
          onPressed: () => context.go(ZakerRoutes.batches),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const TrText('رجوع للدفعات'),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(
      const SnackBar(content: TrText('الكود اتنسخ.')),
    );
  }

  Future<void> _share(
    BuildContext context,
    Batch batch,
    String grouped,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = 'كود الدعوة لدفعة «${batch.name}»: $grouped\n\n'
        'الكود ده دعوة مش تسجيل دخول. النسخة المحلية بتعرف تلاقي الدفعة '
        'على الجهاز اللي اتعملت عليه بس؛ الانضمام من جهاز تاني محتاج سيرفر.';
    try {
      await Share.share(text);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: TrText('المشاركة ما ظبطتش على الجهاز ده.')),
      );
    }
  }

  static String _memberName(BatchSnapshot snapshot, String uid) {
    for (final member in snapshot.members) {
      if (member.uid == uid) return member.displayName;
    }
    return '';
  }
}

class _CreatedError extends StatelessWidget {
  const _CreatedError({this.failure, required this.onRetry});

  final BatchFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message =
        failure == null ? 'مش قادرين نفتح الدفعة.' : batchErrorText(failure!);
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
