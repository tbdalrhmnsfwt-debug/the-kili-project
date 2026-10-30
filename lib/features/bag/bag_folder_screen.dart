import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization.dart';
import '../../core/my_bag/my_bag_models.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/my_bag_providers.dart';
import '../../providers/pdf_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../pdf/widgets/pdf_document_card.dart';
import 'bag_visuals.dart';
import 'widgets/bag_pocket_tile.dart';

/// One bag folder: its header, its four pockets and what was added lately.
class BagFolderScreen extends ConsumerWidget {
  const BagFolderScreen({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bag = ref.watch(myBagControllerProvider);
    final folder = bag.folderById(folderId);
    if (folder == null) {
      return Scaffold(
        key: const Key('bag-pocket-missing'),
        appBar: AppBar(title: const TrText('المجلد مش موجود')),
        body: EmptyState(
          icon: Icons.folder_off_outlined,
          title: 'المجلد مش موجود',
          message: 'يمكن اتحذف من الشنطة.',
          action: FilledButton(
            onPressed: () => context.go(ZakerRoutes.bag),
            child: const TrText('ارجع للشنطة'),
          ),
        ),
      );
    }

    final totals = bag.totalsFor(folderId);
    final media = bag.mediaOf(folderId);
    final accent = Color(folder.colorValue);
    final previews = _previews(context, ref, folder, media);
    final recent = media.recent(4);

    return Scaffold(
      key: const Key('bag-folder-screen'),
      appBar: AppBar(title: TrText(folder.name)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Container(
                key: const Key('bag-folder-hero'),
                padding: const EdgeInsets.all(ZakerSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ZakerRadius.cardValue),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.3)!,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HugeIcon(
                          icon: bagIcon(folder.iconName),
                          size: 28,
                          color: Colors.white,
                        ),
                        const SizedBox(width: ZakerSpacing.sm),
                        Expanded(
                          child: TrText(
                            folder.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.md),
                    Wrap(
                      spacing: ZakerSpacing.sm,
                      runSpacing: ZakerSpacing.xs,
                      children: [
                        _HeroChip(value: totals.pdfs, label: 'ملف PDF'),
                        _HeroChip(value: totals.voice, label: 'تسجيل'),
                        _HeroChip(value: totals.boards, label: 'صورة بورد'),
                        _HeroChip(value: totals.links, label: 'رابط'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: ZakerSpacing.md,
                crossAxisSpacing: ZakerSpacing.md,
                mainAxisExtent: 96,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final kind = BagPocketKind.values[index];
                return BagPocketTile(
                  key: Key('bag-pocket-${kind.name}'),
                  kind: kind,
                  count: totals.asList[index],
                  preview: previews[kind]!,
                  onTap: () => context.push(
                    ZakerRoutes.bagPocketPath(folderId, kind.name),
                  ),
                );
              }, childCount: BagPocketKind.values.length),
            ),
          ),
          if (recent.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                ZakerSpacing.xl,
                ZakerSpacing.lg,
                ZakerSpacing.xl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  key: const Key('bag-recent'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'آخر ما أضفت',
                      icon: Icons.history,
                    ),
                    for (final item in recent) _RecentRow(item: item),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<BagPocketKind, String> _previews(
    BuildContext context,
    WidgetRef ref,
    MyBagFolder folder,
    MyBagFolderMedia media,
  ) {
    String pdfPreview() {
      if (folder.pdfIds.isEmpty) return 'مفيش ملفات';
      final entries = ref.watch(pdfLibraryControllerProvider).entries;
      for (final id in folder.pdfIds) {
        for (final entry in entries) {
          if (entry.id == id) return entry.displayName;
        }
      }
      return 'مفيش ملفات';
    }

    String voicePreview() {
      if (media.voice.isEmpty) return 'مفيش تسجيلات';
      var latest = media.voice.first;
      for (final clip in media.voice) {
        if (clip.createdAtMs > latest.createdAtMs) latest = clip;
      }
      return latest.title;
    }

    String boardPreview() {
      if (media.boards.isEmpty) return 'مفيش صور';
      return context.trf('{0} صورة', [media.boards.length]);
    }

    String linkPreview() {
      if (media.links.isEmpty) return 'مفيش روابط';
      var latest = media.links.first;
      for (final link in media.links) {
        if (link.createdAtMs > latest.createdAtMs) latest = link;
      }
      return bagLinkHost(latest.url);
    }

    return {
      BagPocketKind.pdfs: pdfPreview(),
      BagPocketKind.voice: voicePreview(),
      BagPocketKind.boards: boardPreview(),
      BagPocketKind.links: linkPreview(),
    };
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: ZakerSpacing.xs),
          TrText(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});

  final MyBagRecentItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        item.title.isEmpty ? BagPocketTile.labelOf(item.kind) : item.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Row(
        children: [
          HugeIcon(
            icon: BagPocketTile.iconOf(item.kind),
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Text(
            formatPdfDate(
              DateTime.fromMillisecondsSinceEpoch(item.createdAtMs),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
