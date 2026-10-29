import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/my_bag/my_bag_models.dart';
import '../../providers/my_bag_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'pockets/pdf_pocket_body.dart';
import 'widgets/bag_pocket_tile.dart';

/// One pocket of one folder. Tasks 6–9 replace each branch of [_body].
class BagPocketScreen extends ConsumerWidget {
  const BagPocketScreen({
    super.key,
    required this.folderId,
    required this.kind,
  });

  final String folderId;
  final BagPocketKind kind;

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
        ),
      );
    }

    // The PDFs pocket owns its own app bar and scrolling body.
    if (kind == BagPocketKind.pdfs) {
      return PdfPocketBody(folderId: folderId);
    }

    return Scaffold(
      key: Key('bag-pocket-screen-${kind.name}'),
      appBar: AppBar(title: TrText(BagPocketTile.labelOf(kind))),
      body: SafeArea(child: _body(context, ref)),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) => switch (kind) {
        BagPocketKind.pdfs => PdfPocketBody(folderId: folderId),
        BagPocketKind.voice => _PocketPlaceholder(kind: kind),
        BagPocketKind.boards => _PocketPlaceholder(kind: kind),
        BagPocketKind.links => _PocketPlaceholder(kind: kind),
      };
}

/// A pocket that holds nothing yet.
class _PocketPlaceholder extends StatelessWidget {
  const _PocketPlaceholder({required this.kind});

  final BagPocketKind kind;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.inbox_outlined,
      title: BagPocketTile.labelOf(kind),
      message: 'لسه مفيش حاجة هنا',
    );
  }
}
