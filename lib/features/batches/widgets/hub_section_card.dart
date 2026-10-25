/// One section row on the batch hub.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

class HubSectionCard extends StatelessWidget {
  const HubSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.countLabel,
    this.badge,
    this.unavailable = false,
    this.onTap,
  });

  final IconData icon;
  final String title;

  /// The latest item, or the honest empty-state line.
  final String subtitle;

  /// A compact count, for example `2 مادة · 5 ملف`.
  final String countLabel;
  final int? badge;
  final bool unavailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        unavailable ? theme.colorScheme.error : theme.colorScheme.primary;
    final content = Padding(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(ZakerRadius.sm),
            ),
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TrText(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (badge != null && badge! > 0) ...[
                      const SizedBox(width: ZakerSpacing.xs),
                      _Badge(count: badge!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                TrText(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: unavailable
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                TrText(
                  countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: ZakerSpacing.xs),
            Icon(
              Icons.chevron_left_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: unavailable
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
