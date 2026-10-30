/// Join requests are a server feature. This screen says so plainly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_notice.dart';

class BatchJoinRequestsScreen extends ConsumerWidget {
  const BatchJoinRequestsScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const TrText('طلبات الانضمام')),
      body: detail.when(
        loading: () => const Center(child: LoadingBox(label: 'بنقرا الطلبات…')),
        error: (error, _) => Center(
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
                  error is BatchFailure
                      ? batchErrorText(error)
                      : 'مش قادرين نقرا الدفعة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ZakerSpacing.md),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(batchDetailProvider(batchId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const TrText('حاول تاني'),
                ),
              ],
            ),
          ),
        ),
        data: (snapshot) {
          if (!canViewBatchAdmin(snapshot, uid)) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'الطلبات لصاحب الدفعة أو المسؤول بس',
              message: 'إدارة الانضمام جزء من إدارة الدفعة.',
            );
          }
          return const _RequestsBody();
        },
      ),
    );
  }
}

class _RequestsBody extends StatelessWidget {
  const _RequestsBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        const BatchNotice(
          icon: Icons.dns_outlined,
          text: 'طلبات الانضمام من أجهزة تانية محتاجة سيرفر. مفيش طلبات '
              'محلية، فمفيش حاجة نوافق عليها هنا.',
        ),
        const SizedBox(height: ZakerSpacing.xl),
        Icon(
          Icons.how_to_reg_outlined,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: ZakerSpacing.md),
        TrText(
          'مفيش طلبات انضمام',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        TrText(
          'على الجهاز ده الانضمام بيحصل بكود الدعوة مباشرة. الموافقة '
          'والرفض بين الأجهزة محتاجين سيرفر، فالشاشة دي مش بتعرض أزرار '
          'موافقة أو رفض وهمية.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: ZakerSpacing.xl),
        Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                'إيه اللي بيشتغل دلوقتي؟',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: ZakerSpacing.xs),
              TrText(
                'صاحب الدفعة بيولّد كود، وأي حساب على الجهاز ده بيدخل '
                'بالكود كعضوية محلية. الكود مش تسجيل دخول ومش بيشتغل على '
                'جهاز تاني.',
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
