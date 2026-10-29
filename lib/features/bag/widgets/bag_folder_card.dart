import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/my_bag/my_bag_models.dart';
import '../../../core/theme.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../bag_visuals.dart';

/// One folder in the bag grid: name, subject icon, four pocket counts.
class BagFolderCard extends StatelessWidget {
  const BagFolderCard({
    super.key,
    required this.folder,
    required this.totals,
    this.progress,
    required this.onOpen,
    required this.onRename,
    required this.onColor,
    required this.onDelete,
  });

  final MyBagFolder folder;
  final PocketTotals totals;

  /// Lesson progress for a subject folder; absent for a custom folder.
  final double? progress;

  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onColor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(folder.colorValue);
    final accentInk = cardAccentOf(accent, theme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: ZakerRadius.card,
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: ZakerRadius.card,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(ZakerRadius.sm),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: bagIcon(folder.iconName),
                        size: 20,
                        color: accentInk,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    key: Key('bag-folder-menu-${folder.id}'),
                    tooltip: 'خيارات المجلد',
                    iconSize: 20,
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoreVertical,
                      size: 18,
                      color: accentInk,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          onRename();
                        case 'color':
                          onColor();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'rename',
                        child: TrText('إعادة تسمية'),
                      ),
                      PopupMenuItem<String>(
                        value: 'color',
                        child: TrText('تغيير اللون'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: TrText('حذف المجلد'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                folder.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (progress != null && progress! > 0) ...[
                const SizedBox(height: ZakerSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ProgressBar(
                        value: progress!,
                        height: 4,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: ZakerSpacing.sm),
                    Text(
                      '${(progress! * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: ZakerSpacing.sm),
              Wrap(
                spacing: ZakerSpacing.xs,
                runSpacing: ZakerSpacing.xs,
                children: [
                  _PocketChip(
                    icon: HugeIcons.strokeRoundedPdf01,
                    count: totals.pdfs,
                    label: 'ملف PDF',
                    accent: accentInk,
                  ),
                  _PocketChip(
                    icon: HugeIcons.strokeRoundedMic01,
                    count: totals.voice,
                    label: 'تسجيل',
                    accent: accentInk,
                  ),
                  _PocketChip(
                    icon: HugeIcons.strokeRoundedImage01,
                    count: totals.boards,
                    label: 'صورة بورد',
                    accent: accentInk,
                  ),
                  _PocketChip(
                    icon: HugeIcons.strokeRoundedLink01,
                    count: totals.links,
                    label: 'رابط',
                    accent: accentInk,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PocketChip extends StatelessWidget {
  const _PocketChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.accent,
  });

  final List<List<dynamic>> icon;
  final int count;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(ZakerRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 13, color: accent),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
