/// Layout maths for the tiled reader.
///
/// Everything here works in normalized page coordinates (0..1, origin at the
/// top-left of the unrotated page), so zoom, scrolling, rotation and screen
/// size never change the annotations' stored coordinates.
library;

/// A rectangle in normalized page coordinates.
class NormalizedRect {
  const NormalizedRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  /// The same rectangle pulled inside the page, never negative-sized.
  NormalizedRect clampToPage() {
    final l = left.clamp(0.0, 1.0).toDouble();
    final t = top.clamp(0.0, 1.0).toDouble();
    final r = right.clamp(0.0, 1.0).toDouble();
    final b = bottom.clamp(0.0, 1.0).toDouble();
    return NormalizedRect(
      l,
      t,
      (r - l).clamp(0.0, 1.0).toDouble(),
      (b - t).clamp(0.0, 1.0).toDouble(),
    );
  }
}

/// One page's size and the maths that maps it onto the viewport.
class PdfPageGeometry {
  const PdfPageGeometry({
    required this.widthPoints,
    required this.heightPoints,
  });

  /// Page width in PDF points (72 per inch).
  final double widthPoints;

  /// Page height in PDF points.
  final double heightPoints;

  /// Scale at which the page exactly fills [viewportWidth].
  double fitScale(double viewportWidth) => viewportWidth / widthPoints;

  /// Page width on screen at [zoom] (1.0 = fit-width).
  double displayWidth({required double fitScale, required double zoom}) =>
      widthPoints * fitScale * zoom;

  /// Page height on screen at [zoom] (1.0 = fit-width).
  double displayHeight({required double fitScale, required double zoom}) =>
      heightPoints * fitScale * zoom;

  /// The part of the unrotated page a viewport sees.
  ///
  /// [scrollX]/[scrollY] are page-local offsets (the scroll offset minus the
  /// page's leading edge). [margin] adds prefetch on every visible side; the
  /// result never leaves the page.
  NormalizedRect visibleSource({
    required double scrollX,
    required double scrollY,
    required double viewportWidth,
    required double viewportHeight,
    required double fitScale,
    required double zoom,
    double margin = 0.15,
  }) {
    final width = displayWidth(fitScale: fitScale, zoom: zoom);
    final height = displayHeight(fitScale: fitScale, zoom: zoom);
    final visibleWidth = (viewportWidth / width).clamp(0.0, 1.0).toDouble();
    final visibleHeight = (viewportHeight / height).clamp(0.0, 1.0).toDouble();
    final maxLeft = (1 - visibleWidth).clamp(0.0, 1.0).toDouble();
    final maxTop = (1 - visibleHeight).clamp(0.0, 1.0).toDouble();
    final startLeft = (scrollX / width).clamp(0.0, maxLeft).toDouble();
    final startTop = (scrollY / height).clamp(0.0, maxTop).toDouble();
    final left = (startLeft - margin).clamp(0.0, 1.0).toDouble();
    final top = (startTop - margin).clamp(0.0, 1.0).toDouble();
    final right = (startLeft + visibleWidth + margin)
        .clamp(0.0, 1.0)
        .toDouble();
    final bottom = (startTop + visibleHeight + margin)
        .clamp(0.0, 1.0)
        .toDouble();
    return NormalizedRect(
      left,
      top,
      (right - left).clamp(0.0, 1.0).toDouble(),
      (bottom - top).clamp(0.0, 1.0).toDouble(),
    );
  }

  /// Maps a rectangle in rotated display space back to the unrotated page.
  ///
  /// [quarterTurns] counts clockwise quarter turns applied for display.
  static NormalizedRect unrotateSource(
    NormalizedRect displayRect,
    int quarterTurns,
  ) {
    final turns = ((quarterTurns % 4) + 4) % 4;
    final l = displayRect.left;
    final t = displayRect.top;
    final w = displayRect.width;
    final h = displayRect.height;
    return switch (turns) {
      1 => NormalizedRect(t, 1 - l - w, h, w),
      2 => NormalizedRect(1 - l - w, 1 - t - h, w, h),
      3 => NormalizedRect(1 - t - h, l, h, w),
      _ => displayRect,
    };
  }
}
