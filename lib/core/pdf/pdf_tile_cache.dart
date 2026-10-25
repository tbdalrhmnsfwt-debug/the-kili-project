/// A bounded LRU cache for rendered page tiles.
///
/// Tiles are keyed by page, scale bucket and a quantized source rectangle, so
/// scrolling by a fraction of a percent still hits the tile already rendered.
/// The cache is Flutter-free so it can be verified on plain Dart.
library;

import 'dart:collection';
import 'dart:typed_data';

import 'pdf_page_geometry.dart';

/// Identifies one rendered tile.
class PdfTileKey {
  const PdfTileKey({
    required this.pageIndex,
    required this.scaleBucket,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
  });

  /// Quantizes [source] so a sub-thousandth change reuses the tile.
  factory PdfTileKey.fromSource({
    required int pageIndex,
    required double scale,
    required NormalizedRect source,
  }) {
    int quantize(double value) => (value * 1000).round().clamp(0, 1000);
    return PdfTileKey(
      pageIndex: pageIndex,
      scaleBucket: (scale * 100).round(),
      x0: quantize(source.left),
      y0: quantize(source.top),
      x1: quantize(source.right),
      y1: quantize(source.bottom),
    );
  }

  final int pageIndex;
  final int scaleBucket;

  /// Normalized edges, quantized to 0..1000.
  final int x0;
  final int y0;
  final int x1;
  final int y1;

  @override
  bool operator ==(Object other) {
    return other is PdfTileKey &&
        other.pageIndex == pageIndex &&
        other.scaleBucket == scaleBucket &&
        other.x0 == x0 &&
        other.y0 == y0 &&
        other.x1 == x1 &&
        other.y1 == y1;
  }

  @override
  int get hashCode => Object.hash(pageIndex, scaleBucket, x0, y0, x1, y1);

  @override
  String toString() => 'PdfTileKey($pageIndex, $scaleBucket, $x0,$y0,$x1,$y1)';
}

/// Keeps the most recently used tiles under a byte budget.
class PdfTileCache {
  PdfTileCache({this.maxBytes = 96 * 1024 * 1024});

  final int maxBytes;

  /// Insertion order is recency order: the first key is the oldest.
  final LinkedHashMap<PdfTileKey, Uint8List> _tiles =
      LinkedHashMap<PdfTileKey, Uint8List>();
  int _bytes = 0;

  /// Total bytes currently held.
  int get bytes => _bytes;

  /// Number of tiles currently held.
  int get length => _tiles.length;

  /// Returns [key]'s bytes and marks it most recently used.
  Uint8List? get(PdfTileKey key) {
    final value = _tiles.remove(key);
    if (value == null) return null;
    _tiles[key] = value;
    return value;
  }

  /// Stores [bytes], evicting the oldest tiles over budget.
  void put(PdfTileKey key, Uint8List bytes) {
    final previous = _tiles.remove(key);
    if (previous != null) _bytes -= previous.lengthInBytes;
    _tiles[key] = bytes;
    _bytes += bytes.lengthInBytes;
    // Keep the newest tile even when it alone exceeds the budget.
    while (_bytes > maxBytes && _tiles.length > 1) {
      final oldest = _tiles.keys.first;
      final removed = _tiles.remove(oldest);
      _bytes -= removed!.lengthInBytes;
    }
  }

  /// Drops every tile.
  void clear() {
    _tiles.clear();
    _bytes = 0;
  }
}
