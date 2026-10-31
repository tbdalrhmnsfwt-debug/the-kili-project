/// One page of the reader: the page box plus whatever tile arrived for it.
///
/// The page is laid out in unrotated page space and rotated for display, so
/// the tile's normalized [source] always maps straight onto the box.
/// Annotations use the same normalized coordinates, which is what lets a
/// highlight stay on its sentence through zoom, rotation and a new device.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/pdf/pdf_annotations.dart';
import '../../../core/pdf/pdf_page_geometry.dart';

/// A single page at [zoom], with night mode, rotation, search hits and the
/// studio's annotations.
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
    this.annotations = const [],
    this.onLongPress,
    this.onAnnotationTap,
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

  /// Studio annotations that belong to this page.
  final List<PdfAnnotation> annotations;

  /// Emits a zero-sized rect at the long-pressed point, already unrotated.
  final ValueChanged<NormalizedRect>? onLongPress;

  /// Opens the editor for a tapped annotation.
  final ValueChanged<PdfAnnotation>? onAnnotationTap;

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
          for (final annotation in annotations)
            _positionedAnnotation(annotation, pageWidth, pageHeight),
        ],
      ),
    );

    final box = SizedBox(
      width: swapped ? pageHeight : pageWidth,
      height: swapped ? pageWidth : pageHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: Colors.black12)),
          boxShadow: [
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

    final onLongPress = this.onLongPress;
    if (onLongPress == null) return box;
    final boxWidth = swapped ? pageHeight : pageWidth;
    final boxHeight = swapped ? pageWidth : pageHeight;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        if (boxWidth <= 0 || boxHeight <= 0) return;
        final point = NormalizedRect(
          (details.localPosition.dx / boxWidth).clamp(0.0, 1.0).toDouble(),
          (details.localPosition.dy / boxHeight).clamp(0.0, 1.0).toDouble(),
          0,
          0,
        );
        onLongPress(PdfPageGeometry.unrotateSource(point, turns));
      },
      child: box,
    );
  }

  Widget _positionedAnnotation(
    PdfAnnotation annotation,
    double pageWidth,
    double pageHeight,
  ) {
    final rect = annotation.rect.clampToPage();
    final left = rect.left * pageWidth;
    final top = rect.top * pageHeight;
    final width = math.max(rect.width * pageWidth, 1.0);
    final height = math.max(rect.height * pageHeight, 1.0);
    final color = Color(annotation.effectiveColor | 0xFF000000);

    switch (annotation.kind) {
      case PdfAnnotationKind.highlight:
        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: annotation.opacity.clamp(0.1, 1) * 0.55,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      case PdfAnnotationKind.underline:
        return Positioned(
          left: left,
          top: top + height - math.max(1.5, pageHeight * 0.004),
          width: width,
          height: math.max(1.5, pageHeight * 0.004),
          child: IgnorePointer(child: ColoredBox(color: color)),
        );
      case PdfAnnotationKind.strike:
        return Positioned(
          left: left,
          top: top + height / 2,
          width: width,
          height: math.max(1.2, pageHeight * 0.003),
          child: IgnorePointer(
            child: ColoredBox(
              color: color.withValues(alpha: annotation.opacity),
            ),
          ),
        );
      case PdfAnnotationKind.ink:
        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _InkPainter(
                color.withValues(alpha: annotation.opacity),
              ),
            ),
          ),
        );
      case PdfAnnotationKind.note:
        return _card(
          annotation,
          left,
          top,
          width,
          height,
          background: const Color(0xFFFFF6D8),
          border: const Color(0xFFE2B93B),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.sticky_note_2_rounded,
                size: 12,
                color: Color(0xFF8A6500),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  annotation.text.isEmpty ? 'ملاحظة' : annotation.text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B2C00),
                  ),
                ),
              ),
            ],
          ),
        );
      case PdfAnnotationKind.text:
        return _card(
          annotation,
          left,
          top,
          width,
          height,
          background: Colors.white.withValues(alpha: 0.92),
          border: const Color(0xFFCBD5E1),
          child: Text(
            annotation.text,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 9,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Color(annotation.effectiveColor | 0xFF000000),
            ),
          ),
        );
      case PdfAnnotationKind.image:
        return _imageAnnotation(annotation, left, top, width, height);
      case PdfAnnotationKind.stamp:
        return _card(
          annotation,
          left,
          top,
          width,
          height,
          background: color.withValues(alpha: 0.12),
          border: color,
          child: Center(
            child: Text(
              annotation.text.isEmpty ? 'تم' : annotation.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        );
      case PdfAnnotationKind.arrow:
        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: CustomPaint(painter: _ArrowPainter(color)),
          ),
        );
      case PdfAnnotationKind.audio:
      case PdfAnnotationKind.video:
        return _card(
          annotation,
          left,
          top,
          width,
          height,
          background: Colors.white,
          border: color,
          child: _MediaCardBody(annotation: annotation, accent: color),
        );
    }
  }

  Widget _card(
    PdfAnnotation annotation,
    double left,
    double top,
    double width,
    double height, {
    required Color background,
    required Color border,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap:
            onAnnotationTap == null ? null : () => onAnnotationTap!(annotation),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: border, width: 0.9),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageAnnotation(
    PdfAnnotation annotation,
    double left,
    double top,
    double width,
    double height,
  ) {
    final path = annotation.mediaPath;
    Widget child;
    if (path == null || !File(path).existsSync()) {
      child = const ColoredBox(
        color: Color(0xFFF1ECFF),
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 16,
            color: Color(0xFF7C5CFF),
          ),
        ),
      );
    } else {
      child = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: Color(0xFFF1ECFF),
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 16,
              color: Color(0xFF7C5CFF),
            ),
          ),
        ),
      );
    }
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap:
            onAnnotationTap == null ? null : () => onAnnotationTap!(annotation),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: child,
        ),
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

/// The audio/video card drawn on the page: play control, title and metadata.
class _MediaCardBody extends StatelessWidget {
  const _MediaCardBody({required this.annotation, required this.accent});

  final PdfAnnotation annotation;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isAudio = annotation.kind == PdfAnnotationKind.audio;
    final title = annotation.mediaName.trim().isEmpty
        ? (isAudio ? 'شرح صوتي' : 'شرح بالفيديو')
        : annotation.mediaName;
    final meta = [
      if (annotation.durationMs > 0) _duration(annotation.durationMs),
      if (annotation.mediaBytes > 0) _size(annotation.mediaBytes),
    ].join(' • ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 96;
        return Row(
          children: [
            Container(
              width: constraints.maxHeight.clamp(18.0, 34.0),
              height: constraints.maxHeight.clamp(18.0, 34.0),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                isAudio ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                size: 14,
                color: accent,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF102344),
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 7,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _duration(int milliseconds) {
  final total = (milliseconds / 1000).round();
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String _size(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

class _InkPainter extends CustomPainter {
  const _InkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, size.height * 0.08)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    const steps = 14;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = size.width * t;
      final y = size.height * (0.62 - 0.28 * (i.isOdd ? 1 : 0) - 0.08 * t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_InkPainter oldDelegate) => oldDelegate.color != color;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, size.height * 0.05)
      ..strokeCap = StrokeCap.round;
    final start = Offset(size.width * 0.1, size.height * 0.9);
    final end = Offset(size.width * 0.9, size.height * 0.1);
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const length = 12.0;
    canvas.drawLine(
      end,
      end +
          Offset(
            math.cos(angle + math.pi * 0.82) * length,
            math.sin(angle + math.pi * 0.82) * length,
          ),
      paint,
    );
    canvas.drawLine(
      end,
      end +
          Offset(
            math.cos(angle - math.pi * 0.82) * length,
            math.sin(angle - math.pi * 0.82) * length,
          ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}
