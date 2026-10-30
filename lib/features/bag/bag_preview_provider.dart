import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/my_bag_providers.dart';

/// What the home needs to know about one «شنطتي» folder.
///
/// Deliberately smaller than Phase 3's `MyBagFolder`: the home draws a name, a
/// colour and four counts, and nothing else. The provider reads the bag
/// controller; no widget changes with it.
class BagFolderPreview {
  const BagFolderPreview({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.pocketCounts,
  }) : assert(pocketCounts.length == 4, 'PDFs, voice, boards, links');

  final String id;
  final String name;
  final int colorValue;
  final List<int> pocketCounts;
}

/// Folder previews for the home and the bag screen, read from the bag index.
final bagFolderPreviewProvider = Provider.autoDispose<List<BagFolderPreview>>((
  ref,
) {
  final bag = ref.watch(myBagControllerProvider);
  return [
    for (final folder in bag.index.folders)
      BagFolderPreview(
        id: folder.id,
        name: folder.name,
        colorValue: folder.colorValue,
        pocketCounts: [
          folder.pdfIds.length,
          bag.mediaOf(folder.id).voice.length,
          bag.mediaOf(folder.id).boards.length,
          bag.mediaOf(folder.id).links.length,
        ],
      ),
  ];
});
