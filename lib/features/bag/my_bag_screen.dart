import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import '../home/shell_screen.dart';
import 'bag_preview_provider.dart';
import 'widgets/bag_folder_strip.dart';

/// The second tab: a first, honest view of «شنطتي».
///
/// Phase 3 replaces the body with the folder grid, the grade filter and the
/// pocket totals; the folder data arrives through [bagFolderPreviewProvider],
/// so this screen keeps its shape when that happens.
class MyBagScreen extends ConsumerWidget {
  const MyBagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(bagFolderPreviewProvider);
    return Scaffold(
      key: const Key('my-bag-screen'),
      appBar: AppBar(
        // Pushed on top of a shell (a /bag deep link from a card), the screen
        // needs a way back; inside the shell's own tab, the menu is the way out.
        leading: Navigator.of(context).canPop()
            ? const BackButton()
            : shellMenuLeading(context),
        title: const TrText('شنطتي'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          const _BagHero(),
          const SizedBox(height: ZakerSpacing.lg),
          BagFolderStrip(folders: folders),
          const SizedBox(height: ZakerSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              key: const Key('my-bag-library-button'),
              onPressed: () => context.push(ZakerRoutes.courses),
              child: const TrText('المكتبة الدراسية'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BagHero extends StatelessWidget {
  const _BagHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.cardValue),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            ZakerColors.backpack,
            Color.lerp(ZakerColors.backpack, Colors.black, 0.25)!,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedBackpack01,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'شنطتي',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.xs),
                TrText(
                  'كل موادك في شنطة واحدة',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
