import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';
import '../../bag/bag_preview_provider.dart';
import '../../bag/widgets/bag_folder_strip.dart';

/// The home's «شنطتي» card: a header, the open button and at most six folders.
///
/// The folders come from [bagFolderPreviewProvider], the same seam the bag
/// screen reads, so Phase 3 fills both with one provider change.
class HomeBagPreview extends ConsumerWidget {
  const HomeBagPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('home-bag-preview'),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: cardSurfaceOf(theme),
        borderRadius: ZakerRadius.card,
        border: Border.all(color: ZakerColors.border),
        boxShadow: ZakerShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A Wrap, not a Row: the button sits beside the title when it fits
          // and drops to its own line at 2.0x text instead of overflowing.
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _BagIdentity(theme: theme),
              FilledButton.tonal(
                key: const Key('home-bag-open'),
                onPressed: () => context.push(ZakerRoutes.bag),
                child: const TrText('افتح الشنطة'),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          BagFolderStrip(
            folders: ref.watch(bagFolderPreviewProvider),
            maxFolders: 6,
          ),
        ],
      ),
    );
  }
}

class _BagIdentity extends StatelessWidget {
  const _BagIdentity({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ZakerColors.backpack,
                Color.lerp(ZakerColors.backpack, Colors.black, 0.3)!,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedBackpack01,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: ZakerSpacing.md),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                'شنطتي',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              TrText(
                'كل موادك في شنطة واحدة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
