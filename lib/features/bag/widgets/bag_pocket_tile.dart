import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/my_bag/my_bag_models.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// One of a folder's four pockets: label, count and a one-line preview.
class BagPocketTile extends StatelessWidget {
  const BagPocketTile({
    super.key,
    required this.kind,
    required this.count,
    required this.preview,
    required this.onTap,
  });

  final BagPocketKind kind;
  final int count;
  final String preview;
  final VoidCallback onTap;

  /// The icon the pocket is drawn with.
  static List<List<dynamic>> iconOf(BagPocketKind kind) => switch (kind) {
        BagPocketKind.pdfs => HugeIcons.strokeRoundedPdf01,
        BagPocketKind.voice => HugeIcons.strokeRoundedMic01,
        BagPocketKind.boards => HugeIcons.strokeRoundedImage01,
        BagPocketKind.links => HugeIcons.strokeRoundedLink01,
      };

  /// The Arabic label of the pocket, also its translation key.
  static String labelOf(BagPocketKind kind) => switch (kind) {
        BagPocketKind.pdfs => 'ملفات PDF',
        BagPocketKind.voice => 'تسجيلات صوتية',
        BagPocketKind.boards => 'صور بورد',
        BagPocketKind.links => 'روابط',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HugeIcon(icon: iconOf(kind), size: 20, color: accent),
                  const Spacer(),
                  Text(
                    '$count',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                labelOf(kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              TrText(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
