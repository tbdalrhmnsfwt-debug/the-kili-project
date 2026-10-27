import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';
import '../bag_preview_provider.dart';

/// A wrapping row of «شنطتي» folder chips.
///
/// Shared by the home preview (with [maxFolders]) and the bag screen (all of
/// them). The chip is the seam Phase 3 keeps: only the data behind the folders
/// changes when the real bag arrives.
class BagFolderStrip extends StatelessWidget {
  const BagFolderStrip({super.key, required this.folders, this.maxFolders});

  final List<BagFolderPreview> folders;

  /// How many folders to draw; every folder when null.
  final int? maxFolders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = maxFolders == null
        ? folders
        : folders.take(maxFolders!).toList(growable: false);
    if (shown.isEmpty) {
      return TrText(
        'لسه مفيش مواد في الشنطة',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: ZakerSpacing.sm,
      runSpacing: ZakerSpacing.sm,
      children: [
        for (final folder in shown) _FolderChip(folder: folder),
      ],
    );
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({required this.folder});

  final BagFolderPreview folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(folder.colorValue);
    return Container(
      key: Key('bag-folder-${folder.id}'),
      padding: const EdgeInsets.all(ZakerSpacing.sm),
      decoration: BoxDecoration(
        color: cardSurfaceOf(theme),
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        border: Border.all(color: ZakerColors.border),
        boxShadow: ZakerShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: TrText(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < folder.pocketCounts.length; i++)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: i == folder.pocketCounts.length - 1
                        ? 0
                        : ZakerSpacing.xs,
                  ),
                  child: Container(
                    key: Key('bag-dot-${folder.id}-$i'),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: folder.pocketCounts[i] > 0
                          ? accent
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
