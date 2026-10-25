/// Thumbnails for the library grid.
///
/// A thumbnail is page 1 rendered at roughly 120 px wide. It is best effort:
/// a document without one shows a generic glyph, so every failure here is
/// swallowed rather than surfaced as an import error.
library;

import 'pdf_library_controller.dart';
import 'pdf_library_store.dart';
import 'pdf_page_geometry.dart';
import 'pdf_render_channel.dart';

/// Builds the default thumbnailer for [channel] and [store].
PdfThumbnailer pdfThumbnailer(PdfRenderChannel channel, PdfLibraryStore store) {
  return (baseFile, thumbFile) async {
    PdfRendererHandle? handle;
    try {
      handle = await channel.open(baseFile.path);
      if (handle.pages.isEmpty) return;
      final page = handle.pages.first;
      if (page.widthPoints <= 0) return;
      final bytes = await channel.render(
        handle: handle.id,
        pageIndex: 0,
        scale: 120 / page.widthPoints,
        source: const NormalizedRect(0, 0, 1, 1),
      );
      final name = thumbFile.uri.pathSegments.last;
      final id = name.endsWith('.png')
          ? name.substring(0, name.length - 4)
          : name;
      await store.writeThumbnail(id, bytes);
    } on Object {
      // Missing thumbnails fall back to a glyph in the grid.
    } finally {
      if (handle != null) await channel.close(handle.id);
    }
  };
}
