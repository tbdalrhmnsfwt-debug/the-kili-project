/// The globe card for the Qibla screen.
///
/// Draws an orthographic projection of the Earth with the great-circle route
/// from the user's location to the Kaaba, a light graticule, and both markers.
/// Everything is painted with [CustomPainter]; there is no map package, tile
/// server or network call involved.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/qibla_constants.dart';

/// A small, self-contained globe showing the route to Makkah.
class QiblaGlobe extends StatelessWidget {
  const QiblaGlobe({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 1.18,
      child: CustomPaint(
        painter: _QiblaGlobePainter(
          latitude: latitude,
          longitude: longitude,
          ocean: isDark ? const Color(0xFF0C302D) : const Color(0xFFDDF1EC),
          oceanDeep: isDark ? const Color(0xFF041B19) : const Color(0xFFB7DFD6),
          oceanLight: isDark
              ? const Color(0xFF15514B)
              : const Color(0xFFF4FBF8),
          grid: (isDark ? Colors.white : theme.colorScheme.primary).withValues(
            alpha: isDark ? 0.11 : 0.16,
          ),
          rim: theme.colorScheme.primary.withValues(alpha: isDark ? 0.5 : 0.3),
          route: theme.colorScheme.secondary,
          user: theme.colorScheme.primary,
          kaaba: theme.colorScheme.secondary,
          labelBackground: (theme.cardTheme.color ?? theme.colorScheme.surface)
              .withValues(alpha: 0.92),
          labelInk: theme.colorScheme.onSurface,
          shadow: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
        ),
      ),
    );
  }
}

class _QiblaGlobePainter extends CustomPainter {
  const _QiblaGlobePainter({
    required this.latitude,
    required this.longitude,
    required this.ocean,
    required this.oceanDeep,
    required this.oceanLight,
    required this.grid,
    required this.rim,
    required this.route,
    required this.user,
    required this.kaaba,
    required this.labelBackground,
    required this.labelInk,
    required this.shadow,
  });

  final double latitude;
  final double longitude;
  final Color ocean;
  final Color oceanDeep;
  final Color oceanLight;
  final Color grid;
  final Color rim;
  final Color route;
  final Color user;
  final Color kaaba;
  final Color labelBackground;
  final Color labelInk;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) * 0.40;
    final sphere = Rect.fromCircle(center: center, radius: radius);

    final from = _Vec.fromLatLon(latitude, longitude);
    final to = _Vec.fromLatLon(kKaabaLatitude, kKaabaLongitude);
    final dot = from.dot(to).clamp(-1.0, 1.0);
    final omega = math.acos(dot);
    final mid = from.add(to);
    // When the two points are (nearly) antipodal the midpoint is undefined;
    // centring on the user keeps the globe stable in that rare case.
    final view = mid.length < 1e-6 ? from : mid.normalized();

    var east = const _Vec(0, 0, 1).cross(view);
    if (east.length < 1e-6) {
      east = const _Vec(0, 1, 0).cross(view);
    }
    east = east.normalized();
    final north = view.cross(east).normalized();

    // Soft shadow under the sphere gives the card depth.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.98),
        width: radius * 1.5,
        height: radius * 0.24,
      ),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Halo around the globe.
    canvas.drawCircle(
      center,
      radius * 1.04,
      Paint()
        ..color = rim.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    final shader = RadialGradient(
      center: const Alignment(-0.38, -0.48),
      radius: 1.12,
      colors: [oceanLight, ocean, oceanDeep],
      stops: const [0, 0.52, 1],
    ).createShader(sphere);
    canvas.drawCircle(center, radius, Paint()..shader = shader);

    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    _drawGraticule(canvas, center, radius, east, north, view);
    _drawRoute(canvas, center, radius, east, north, view, from, to, omega);
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = rim,
    );

    final userPoint = _project(from, center, radius, east, north, view);
    final kaabaPoint = _project(to, center, radius, east, north, view);

    _drawUserMarker(canvas, userPoint);
    _drawKaabaMarker(canvas, kaabaPoint);

    // Labels are offset in opposite directions so they stay readable even
    // when the two locations are close together (Egypt and Makkah are only
    // about 10–15° apart on the globe).
    _drawLabel(canvas, size, userPoint, 'موقعك', dx: -12, above: false);
    _drawLabel(canvas, size, kaabaPoint, 'الكعبة', dx: 12, above: true);
  }

  void _drawGraticule(
    Canvas canvas,
    Offset center,
    double radius,
    _Vec east,
    _Vec north,
    _Vec view,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = grid;

    void polyline(List<_Vec> points) {
      _Projected? previous;
      for (final point in points) {
        final projected = _projectOrNull(
          point,
          center,
          radius,
          east,
          north,
          view,
        );
        if (projected == null || previous == null) {
          previous = projected;
          continue;
        }
        canvas.drawLine(previous.offset, projected.offset, paint);
        previous = projected;
      }
    }

    // Parallels.
    for (var lat = -75; lat <= 75; lat += 15) {
      polyline([
        for (var lon = -180; lon <= 180; lon += 6)
          _Vec.fromLatLon(lat.toDouble(), lon.toDouble()),
      ]);
    }

    // Meridians.
    for (var lon = -180; lon < 180; lon += 15) {
      polyline([
        for (var lat = -90; lat <= 90; lat += 6)
          _Vec.fromLatLon(lat.toDouble(), lon.toDouble()),
      ]);
    }

    // A slightly stronger equator.
    final equator = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = grid.withValues(alpha: math.min(1.0, grid.a * 1.6));
    _Projected? previous;
    for (var lon = -180; lon <= 180; lon += 6) {
      final projected = _projectOrNull(
        _Vec.fromLatLon(0, lon.toDouble()),
        center,
        radius,
        east,
        north,
        view,
      );
      if (projected != null && previous != null) {
        canvas.drawLine(previous.offset, projected.offset, equator);
      }
      previous = projected;
    }
  }

  void _drawRoute(
    Canvas canvas,
    Offset center,
    double radius,
    _Vec east,
    _Vec north,
    _Vec view,
    _Vec from,
    _Vec to,
    double omega,
  ) {
    final points = <Offset>[];
    final sinOmega = math.sin(omega);
    for (var index = 0; index <= kQiblaPathSamples; index++) {
      final t = index / kQiblaPathSamples;
      final _Vec point;
      if (omega.abs() < 1e-6 || sinOmega.abs() < 1e-9) {
        point = from;
      } else {
        point = from
            .scale(math.sin((1 - t) * omega) / sinOmega)
            .add(to.scale(math.sin(t * omega) / sinOmega))
            .normalized();
      }
      final projected = _project(point, center, radius, east, north, view);
      points.add(projected.offset);
    }

    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = route.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = route,
    );

    // Small waypoints make the arc read as a route rather than a diagram.
    final dot = Paint()..color = route.withValues(alpha: 0.75);
    for (var index = 8; index < points.length - 8; index += 10) {
      canvas.drawCircle(points[index], 1.4, dot);
    }
  }

  void _drawUserMarker(Canvas canvas, _Projected point) {
    canvas.drawCircle(
      point.offset,
      10,
      Paint()..color = user.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      point.offset,
      7.4,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(point.offset, 5.2, Paint()..color = user);
  }

  void _drawKaabaMarker(Canvas canvas, _Projected point) {
    canvas.drawCircle(
      point.offset,
      12,
      Paint()..color = kaaba.withValues(alpha: 0.20),
    );
    canvas.drawCircle(point.offset, 8.6, Paint()..color = kaaba);
    final cube = RRect.fromRectAndRadius(
      Rect.fromCenter(center: point.offset, width: 7.4, height: 7.4),
      const Radius.circular(1.4),
    );
    canvas.drawRRect(cube, Paint()..color = const Color(0xFF1F2937));
    // The golden band of the Kaaba's kiswa.
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(point.offset.dx, point.offset.dy - 1.4),
        width: 7.4,
        height: 1.5,
      ),
      Paint()..color = const Color(0xFFFDE68A),
    );
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    _Projected anchor,
    String text, {
    required double dx,
    required bool above,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: labelInk,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: math.max(40, size.width * 0.38));

    final maxX = math.max(2.0, size.width - painter.width - 9);
    var x = above
        ? anchor.offset.dx + dx
        : anchor.offset.dx - painter.width + dx;
    x = x.clamp(4.0, maxX).toDouble();
    var y = above
        ? anchor.offset.dy - painter.height - 12
        : anchor.offset.dy + 12;
    y = y
        .clamp(4.0, math.max(4.0, size.height - painter.height - 8))
        .toDouble();

    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 7, y - 3.5, painter.width + 14, painter.height + 7),
      const Radius.circular(7),
    );
    canvas.drawRRect(background, Paint()..color = labelBackground);
    canvas.drawRRect(
      background,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = grid,
    );
    painter.paint(canvas, Offset(x, y));
  }

  _Projected _project(
    _Vec point,
    Offset center,
    double radius,
    _Vec east,
    _Vec north,
    _Vec view,
  ) {
    final visible = point.dot(view);
    // Points behind the sphere are still projected; the caller clips them
    // away when drawing.  Markers always face the viewer.
    return _Projected(
      offset: Offset(
        center.dx + point.dot(east) * radius,
        center.dy - point.dot(north) * radius,
      ),
      visible: visible,
    );
  }

  _Projected? _projectOrNull(
    _Vec point,
    Offset center,
    double radius,
    _Vec east,
    _Vec north,
    _Vec view,
  ) {
    final projected = _project(point, center, radius, east, north, view);
    return projected.visible > 0.001 ? projected : null;
  }

  @override
  bool shouldRepaint(covariant _QiblaGlobePainter oldDelegate) {
    return oldDelegate.latitude != latitude ||
        oldDelegate.longitude != longitude ||
        oldDelegate.ocean != ocean ||
        oldDelegate.oceanDeep != oceanDeep ||
        oldDelegate.oceanLight != oceanLight ||
        oldDelegate.grid != grid ||
        oldDelegate.rim != rim ||
        oldDelegate.route != route ||
        oldDelegate.user != user ||
        oldDelegate.kaaba != kaaba ||
        oldDelegate.labelBackground != labelBackground ||
        oldDelegate.labelInk != labelInk ||
        oldDelegate.shadow != shadow;
  }
}

class _Projected {
  const _Projected({required this.offset, required this.visible});

  final Offset offset;
  final double visible;
}

/// A tiny immutable 3-vector used for the spherical geometry.
class _Vec {
  const _Vec(this.x, this.y, this.z);

  factory _Vec.fromLatLon(double latitude, double longitude) {
    final phi = latitude * math.pi / 180;
    final lambda = longitude * math.pi / 180;
    final cosPhi = math.cos(phi);
    return _Vec(
      cosPhi * math.cos(lambda),
      cosPhi * math.sin(lambda),
      math.sin(phi),
    );
  }

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vec add(_Vec other) => _Vec(x + other.x, y + other.y, z + other.z);

  _Vec scale(double factor) => _Vec(x * factor, y * factor, z * factor);

  double dot(_Vec other) => x * other.x + y * other.y + z * other.z;

  _Vec cross(_Vec other) => _Vec(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  _Vec normalized() {
    final magnitude = length;
    if (magnitude < 1e-12) return const _Vec(1, 0, 0);
    return _Vec(x / magnitude, y / magnitude, z / magnitude);
  }
}
