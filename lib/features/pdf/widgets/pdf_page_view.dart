/// One page of the reader: the page box plus whatever tile arrived for it.
///
/// The page is laid out in unrotated page space and rotated for display, so
/// the tile's normalized [source] always maps straight onto the box.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/pdf/pdf_page_geometry.dart';

/// A single page at [zoom], with optional night mode and rotation.
class PdfPageView extends StatelessWidget {
  const PdfPageView({
    super.key,
    required this.geometry,
    required this.fitScale,
    required this.zoom,
    this.quarterTurns = 0,
    this.nightMode = false,
    this.tile,
    this.source,
    this.highlights = const [],
  });

  final PdfPageGeometry geometry;
  final double fitScale;
  final double zoom;
  final int quarterTurns;
  final bool nightMode;

  /// PNG bytes for [source], or null while the first tile is rendering.
  final Uint8List? tile;

  /// The normalized page rect [tile] covers.
  final NormalizedRect? source;

  /// Search hits painted over the page, in unrotated page coordinates.
  final List<NormalizedRect> highlights;

  @override
  Widget build(BuildContext context) {
    final pageWidth = geometry.displayWidth(fitScale: fitScale, zoom: zoom);
    final pageHeight = geometry.displayHeight(fitScale: fitScale, zoom: zoom);
    final turns = ((quarterTurns % 4) + 4) % 4;
    final swapped = turns.isOdd;

    final content = SizedBox(
      width: pageWidth,
      height: pageHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),
          if (tile != null && source != null)
            Positioned(
              left: source!.left * pageWidth,
              top: source!.top * pageHeight,
              width: source!.width * pageWidth,
              height: source!.height * pageHeight,
              child: nightMode ? _night(_tileImage(tile!)) : _tileImage(tile!),
            ),
          for (final rect in highlights)
            Positioned(
              left: rect.left * pageWidth,
              top: rect.top * pageHeight,
              width: rect.width * pageWidth,
              height: rect.height * pageHeight,
              child: const IgnorePointer(
                child: ColoredBox(color: Color(0x66FFC107)),
              ),
            ),
        ],
      ),
    );

    return SizedBox(
      width: swapped ? pageHeight : pageWidth,
      height: swapped ? pageWidth : pageHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: turns == 0
            ? content
            : RotatedBox(quarterTurns: turns, child: content),
      ),
    );
  }

  Widget _tileImage(Uint8List bytes) {
    return Image.memory(
      bytes,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Colors.white),
    );
  }

  Widget _night(Widget child) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.55, 0, 0, 0, 18, //
        0, 0.52, 0, 0, 8, //
        0, 0, 0.45, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
      child: child,
    );
  }
}
