import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the home needs to know about one «شنطتي» folder.
///
/// Deliberately smaller than Phase 3's `MyBagFolder`: the home draws a name, a
/// colour and four counts, and nothing else. Phase 3 replaces the provider's
/// body with a watch on the bag controller; no widget changes with it.
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

/// Folder previews for the home and the bag screen; empty until Phase 3.
final bagFolderPreviewProvider = Provider.autoDispose<List<BagFolderPreview>>(
  (ref) => const [],
);
