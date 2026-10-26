/// One honest line about where a batch's content lives.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// A tinted notice used above a local-only collection.
class BatchNotice extends StatelessWidget {
  const BatchNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(ZakerRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
