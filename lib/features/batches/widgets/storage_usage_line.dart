/// Batch storage usage as a one-line, passive note.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/batch_providers.dart';
import '../../../widgets/tr_text.dart';
import 'batch_labels.dart';

class StorageUsageLine extends ConsumerWidget {
  const StorageUsageLine({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final used = ref.watch(batchStorageProvider(batchId));
    final theme = Theme.of(context);
    return used.when(
      data: (bytes) => Row(
        children: [
          Icon(
            Icons.sd_storage_outlined,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TrText(
              'المساحة المستخدمة على الجهاز: ${formatBytes(bytes)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(height: ZakerSpacing.sm),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
