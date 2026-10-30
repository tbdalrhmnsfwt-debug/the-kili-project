/// The one-time offer to move guest batches into a newly signed-in account.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/batches/batch_claim_service.dart';
import '../../core/theme.dart';
import '../../models/batch.dart';
import '../../providers/batch_providers.dart';
import '../../widgets/tr_text.dart';

/// Shows the claim sheet when there is something claimable.
///
/// A dismissed sheet is not a decline: only «سيبها على الضيف» remembers the
/// choice. Nothing is uploaded in either case.
Future<void> offerBatchClaimIfNeeded({
  required BuildContext context,
  required WidgetRef ref,
  required String guestUid,
  required String accountUid,
}) async {
  final service = ref.read(batchClaimServiceProvider);
  List<Batch> batches;
  try {
    batches = await service.promptBatches(
      guestUid: guestUid,
      accountUid: accountUid,
    );
  } catch (_) {
    return;
  }
  if (batches.isEmpty || !context.mounted) return;

  final choice = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ClaimSheet(batches: batches),
  );
  if (choice == null || !context.mounted) return;

  final ids = [for (final batch in batches) batch.id];
  if (!choice) {
    await service.decline(
      guestUid: guestUid,
      accountUid: accountUid,
      batchIds: ids,
    );
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  BatchClaimResult result;
  try {
    result = await service.claim(
      guestUid: guestUid,
      accountUid: accountUid,
      batchIds: ids,
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: TrText('نقل الدفعات ما تمّش. جرّب تاني.')),
    );
    return;
  }
  ref.invalidate(batchListProvider);
  ref.invalidate(batchDetailProvider);
  if (!context.mounted) return;
  messenger.showSnackBar(SnackBar(content: TrText(_resultText(result))));
}

String _resultText(BatchClaimResult result) {
  if (result.failedCount == 0) {
    return 'اتنقلت ${result.movedCount} دفعة للحساب.';
  }
  if (result.movedCount == 0) {
    return 'الدفعات ما اتنقلتش. لسه على حساب الضيف.';
  }
  return 'اتنقلت ${result.movedCount} دفعة، و${result.failedCount} ما اتنقلوش. '
      'اللي ما اتنقلش لسه على حساب الضيف.';
}

class _ClaimSheet extends StatelessWidget {
  const _ClaimSheet({required this.batches});

  final List<Batch> batches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.lg,
        ZakerSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + ZakerSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.move_up_rounded,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            'عندك ${batches.length} دفعة على حساب الضيف — تنقلها للحساب ده؟',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          TrText(
            'النقل بيحصل على الجهاز ده بس. مجلدات الدفعات وملفاتها بتتنقل '
            'لحسابك من غير أي رفع لسيرفر، والنقل مش بيرجع تلقائيًا.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.35,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final batch = batches[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.groups_2_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: TrText(batch.name, maxLines: 1),
                  subtitle: TrText(
                    batch.subjects.isEmpty
                        ? 'من غير مواد'
                        : '${batch.subjects.length} مواد',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.move_up_rounded),
            label: const TrText('انقل'),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TrText('سيبها على الضيف'),
          ),
        ],
      ),
    );
  }
}
