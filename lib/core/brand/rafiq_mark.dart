import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The Rafiq mark: a four-point star above an open book.
///
/// Drawn rather than shipped as an asset, so it stays crisp from the 22 pt
/// navigation badge to the 180 pt splash and takes its colour from the caller.
class RafiqMark extends StatelessWidget {
  const RafiqMark({super.key, this.size = 96, this.color = ZakerColors.gold});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RafiqMarkPainter(color)),
    );
  }
}

class _RafiqMarkPainter extends CustomPainter {
  const _RafiqMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;

    _paintStar(canvas, size, side);
    _paintBook(canvas, size, side);
  }

  void _paintStar(Canvas canvas, Size size, double side) {
    final center = Offset(size.width / 2, side * 0.20);
    final radius = side * 0.17;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? radius : radius * 0.36;
      final angle = -math.pi / 2 + i * math.pi / 4;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintBook(Canvas canvas, Size size, double side) {
    final spineX = size.width / 2;
    final outer = side * 0.14;
    final spineTop = side * 0.56;
    final spineBottom = side * 0.80;
    final outerTop = side * 0.50;
    final outerBottom = side * 0.74;
    final curve = side * 0.20;

    final book = Path()
      ..moveTo(spineX, spineTop)
      ..quadraticBezierTo(
          spineX - curve, outerTop - side * 0.04, outer, outerTop)
      ..lineTo(outer, outerBottom)
      ..quadraticBezierTo(
          spineX - curve, spineBottom - side * 0.02, spineX, spineBottom)
      ..moveTo(spineX, spineTop)
      ..quadraticBezierTo(
          spineX + curve, outerTop - side * 0.04, side - outer, outerTop)
      ..lineTo(side - outer, outerBottom)
      ..quadraticBezierTo(
          spineX + curve, spineBottom - side * 0.02, spineX, spineBottom)
      ..moveTo(spineX, spineTop)
      ..lineTo(spineX, spineBottom);

    canvas.drawPath(
      book,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, side * 0.045)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RafiqMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
