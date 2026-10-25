/// Pure numerical graph sampling and analysis.
///
/// The UI receives plain [GraphPoint] lists, so this file has no Flutter
/// dependency and can be tested on a normal Dart VM. Discontinuities end the
/// current polyline instead of drawing a false vertical line through an
/// asymptote.
library;

import 'dart:math' as math;

import 'ast.dart';
import 'calculator_error.dart';
import 'evaluator.dart';
import 'math_value.dart';
import 'parser.dart';

class GraphPoint {
  const GraphPoint(this.x, this.y);

  final double x;
  final double y;

  bool get isFinite => x.isFinite && y.isFinite;
}

class GraphSample {
  const GraphSample({
    required this.segments,
    required this.discontinuities,
  });

  final List<List<GraphPoint>> segments;
  final int discontinuities;

  bool get isEmpty => segments.every((segment) => segment.isEmpty);
}

class GraphSegment {
  const GraphSegment(this.start, this.end);

  final GraphPoint start;
  final GraphPoint end;
}

class GraphExtremum {
  const GraphExtremum(this.point, {required this.isMinimum, required this.approximate});

  final GraphPoint point;
  final bool isMinimum;
  final bool approximate;
}

class TangentLine {
  const TangentLine({
    required this.point,
    required this.slope,
    required this.intercept,
  });

  final GraphPoint point;
  final double slope;
  final double intercept;

  double valueAt(double x) => slope * x + intercept;
}

class _CompiledFunction {
  _CompiledFunction(
    String source, {
    required this.variable,
    required this.angleUnit,
    this.allowComplex = false,
  }) : expression = parseExpression(source),
       context = EvalContext(angleUnit: angleUnit, allowComplex: allowComplex);

  final Expr expression;
  final String variable;
  final AngleUnit angleUnit;
  final bool allowComplex;
  final EvalContext context;

  double call(double x) {
    context.variables[variable] = EvalValue.real(x);
    try {
      final value = Evaluator(context).evaluate(expression);
      if (!value.isReal || !value.realPart.isFinite) return double.nan;
      return value.realPart;
    } on CalcError {
      return double.nan;
    }
  }
}

GraphSample sampleCartesian(
  String source, {
  required double minX,
  required double maxX,
  int samples = 1400,
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  if (!(maxX > minX)) {
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'نطاق x غير صالح.',
    );
  }
  final count = samples.clamp(2, 8000);
  final function = _CompiledFunction(source, variable: 'x', angleUnit: angleUnit);
  final segments = <List<GraphPoint>>[];
  var current = <GraphPoint>[];
  var discontinuities = 0;
  double? previousY;
  for (var i = 0; i < count; i++) {
    final x = minX + (maxX - minX) * i / (count - 1);
    final y = function(x);
    if (!y.isFinite || y.abs() > 1e9) {
      if (current.length > 1) segments.add(current);
      current = <GraphPoint>[];
      previousY = null;
      discontinuities++;
      continue;
    }
    if (previousY != null &&
        (y - previousY).abs() > 1e5 &&
        math.min(y.abs(), previousY.abs()) > 1e2) {
      segments.add(current);
      current = <GraphPoint>[];
      discontinuities++;
    }
    current.add(GraphPoint(x, y));
    previousY = y;
  }
  if (current.length > 1) segments.add(current);
  return GraphSample(segments: segments, discontinuities: discontinuities);
}

GraphSample samplePolar(
  String source, {
  required double minAngle,
  required double maxAngle,
  int samples = 1800,
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  final count = samples.clamp(2, 8000);
  final function = _CompiledFunction(
    source,
    variable: 'θ',
    angleUnit: angleUnit,
  );
  final segments = <List<GraphPoint>>[];
  var current = <GraphPoint>[];
  var discontinuities = 0;
  for (var i = 0; i < count; i++) {
    final theta = minAngle + (maxAngle - minAngle) * i / (count - 1);
    final radius = function(theta);
    if (!radius.isFinite || radius.abs() > 1e9) {
      if (current.length > 1) segments.add(current);
      current = <GraphPoint>[];
      discontinuities++;
      continue;
    }
    final radians = _toRadians(theta, angleUnit);
    current.add(GraphPoint(radius * math.cos(radians), radius * math.sin(radians)));
  }
  if (current.length > 1) segments.add(current);
  return GraphSample(segments: segments, discontinuities: discontinuities);
}

GraphSample sampleParametric(
  String xSource,
  String ySource, {
  required double minT,
  required double maxT,
  int samples = 1600,
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  final count = samples.clamp(2, 8000);
  final xFunction = _CompiledFunction(xSource, variable: 't', angleUnit: angleUnit);
  final yFunction = _CompiledFunction(ySource, variable: 't', angleUnit: angleUnit);
  final segments = <List<GraphPoint>>[];
  var current = <GraphPoint>[];
  var discontinuities = 0;
  for (var i = 0; i < count; i++) {
    final t = minT + (maxT - minT) * i / (count - 1);
    final x = xFunction(t);
    final y = yFunction(t);
    if (!x.isFinite ||
        !y.isFinite ||
        x.abs() > 1e9 ||
        y.abs() > 1e9) {
      if (current.length > 1) segments.add(current);
      current = <GraphPoint>[];
      discontinuities++;
      continue;
    }
    current.add(GraphPoint(x, y));
  }
  if (current.length > 1) segments.add(current);
  return GraphSample(segments: segments, discontinuities: discontinuities);
}

/// Marching-squares sampling for `f(x, y) = 0`.
List<GraphSegment> sampleImplicit(
  String source, {
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  int resolution = 70,
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  if (!(maxX > minX) || !(maxY > minY)) {
    throw const CalcError(CalcErrorKind.argument, detail: 'نطاق الرسم غير صالح.');
  }
  final expression = parseExpression(source);
  final context = EvalContext(angleUnit: angleUnit);
  final cells = resolution.clamp(16, 160);
  double valueAt(double x, double y) {
    context.variables['x'] = EvalValue.real(x);
    context.variables['y'] = EvalValue.real(y);
    try {
      final value = Evaluator(context).evaluate(expression);
      return value.isReal ? value.realPart : double.nan;
    } on CalcError {
      return double.nan;
    }
  }

  final grid = List<List<double>>.generate(
    cells + 1,
    (i) => List<double>.generate(
      cells + 1,
      (j) => valueAt(
        minX + (maxX - minX) * i / cells,
        minY + (maxY - minY) * j / cells,
      ),
    ),
  );
  final segments = <GraphSegment>[];
  for (var i = 0; i < cells; i++) {
    for (var j = 0; j < cells; j++) {
      final x0 = minX + (maxX - minX) * i / cells;
      final x1 = minX + (maxX - minX) * (i + 1) / cells;
      final y0 = minY + (maxY - minY) * j / cells;
      final y1 = minY + (maxY - minY) * (j + 1) / cells;
      final v00 = grid[i][j];
      final v10 = grid[i + 1][j];
      final v11 = grid[i + 1][j + 1];
      final v01 = grid[i][j + 1];
      if (!v00.isFinite || !v10.isFinite || !v11.isFinite || !v01.isFinite) {
        continue;
      }
      final crossings = <GraphPoint>[];
      void edge(GraphPoint a, GraphPoint b, double va, double vb) {
        if (va == 0 && vb == 0) return;
        if ((va <= 0 && vb > 0) || (va >= 0 && vb < 0) || va == 0 || vb == 0) {
          final denominator = va - vb;
          if (denominator.abs() < 1e-30) return;
          final t = (va / denominator).clamp(0.0, 1.0);
          crossings.add(GraphPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
        }
      }

      edge(GraphPoint(x0, y0), GraphPoint(x1, y0), v00, v10);
      edge(GraphPoint(x1, y0), GraphPoint(x1, y1), v10, v11);
      edge(GraphPoint(x1, y1), GraphPoint(x0, y1), v11, v01);
      edge(GraphPoint(x0, y1), GraphPoint(x0, y0), v01, v00);
      if (crossings.length == 2) {
        segments.add(GraphSegment(crossings[0], crossings[1]));
      } else if (crossings.length == 4) {
        final center = valueAt((x0 + x1) / 2, (y0 + y1) / 2);
        if (center.isFinite && center >= 0) {
          segments.add(GraphSegment(crossings[0], crossings[1]));
          segments.add(GraphSegment(crossings[2], crossings[3]));
        } else {
          segments.add(GraphSegment(crossings[1], crossings[2]));
          segments.add(GraphSegment(crossings[3], crossings[0]));
        }
      }
    }
  }
  return segments;
}

List<double> findRoots(
  String source, {
  required double minX,
  required double maxX,
  int samples = 1000,
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  final function = _CompiledFunction(source, variable: 'x', angleUnit: angleUnit);
  final count = samples.clamp(50, 8000);
  final roots = <double>[];
  final tolerance = (maxX - minX) * 1e-7;
  double? previousX;
  double? previousY;
  for (var i = 0; i < count; i++) {
    final x = minX + (maxX - minX) * i / (count - 1);
    final y = function(x);
    if (!y.isFinite) {
      previousX = null;
      previousY = null;
      continue;
    }
    if (y == 0) {
      _addRoot(roots, x, tolerance);
    }
    if (previousY != null && previousX != null) {
      if ((previousY <= 0 && y > 0) || (previousY >= 0 && y < 0)) {
        final root = _bisect(function, previousX, x);
        if (root != null) _addRoot(roots, root, tolerance);
      }
    }
    previousX = x;
    previousY = y;
  }
  return roots;
}

void _addRoot(List<double> roots, double candidate, double tolerance) {
  if (roots.any((root) => (root - candidate).abs() <= tolerance)) return;
  roots.add(candidate);
}

double? _bisect(
  double Function(double) function,
  double left,
  double right,
) {
  var a = left;
  var b = right;
  var fa = function(a);
  var fb = function(b);
  if (!fa.isFinite || !fb.isFinite) return null;
  if (fa == 0) return a;
  if (fb == 0) return b;
  if (fa.sign == fb.sign) return null;
  for (var i = 0; i < 100; i++) {
    final middle = (a + b) / 2;
    final fm = function(middle);
    if (!fm.isFinite) return null;
    if (fm == 0 || (b - a).abs() < 1e-13 * math.max(1, middle.abs())) {
      return middle;
    }
    if (fa.sign != fm.sign) {
      b = middle;
      fb = fm;
    } else {
      a = middle;
      fa = fm;
    }
  }
  final result = (a + b) / 2;
  final residual = function(result);
  // Reject a sign change caused by a vertical asymptote.
  if (!residual.isFinite || residual.abs() > 1e-3 * math.max(1, result.abs())) {
    return null;
  }
  return result;
}

List<GraphExtremum> findExtrema(
  String source, {
  required double minX,
  required double maxX,
  int samples = 600,
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  final function = _CompiledFunction(source, variable: 'x', angleUnit: angleUnit);
  final count = samples.clamp(50, 4000);
  final extrema = <GraphExtremum>[];
  final tolerance = (maxX - minX) * 1e-5;
  double derivative(double x) {
    final h = math.max(1e-6, x.abs() * 1e-6);
    final left = function(x - h);
    final right = function(x + h);
    if (!left.isFinite || !right.isFinite) return double.nan;
    return (right - left) / (2 * h);
  }

  double? previousX;
  double? previousDerivative;
  for (var i = 0; i < count; i++) {
    final x = minX + (maxX - minX) * i / (count - 1);
    final d = derivative(x);
    if (!d.isFinite) {
      previousX = null;
      previousDerivative = null;
      continue;
    }
    if (previousDerivative != null && previousX != null) {
      if ((previousDerivative < 0 && d > 0) ||
          (previousDerivative > 0 && d < 0)) {
        final isMinimum = previousDerivative < 0;
        final candidate = _goldenSection(
          function,
          previousX,
          x,
          minimize: isMinimum,
        );
        if (candidate != null &&
            !extrema.any((item) => (item.point.x - candidate).abs() < tolerance)) {
          final y = function(candidate);
          if (y.isFinite) {
            extrema.add(
              GraphExtremum(
                GraphPoint(candidate, y),
                isMinimum: isMinimum,
                approximate: true,
              ),
            );
          }
        }
      }
    }
    previousX = x;
    previousDerivative = d;
  }
  return extrema;
}

double? _goldenSection(
  double Function(double) function,
  double left,
  double right, {
  required bool minimize,
}) {
  const ratio = 0.6180339887498949;
  var a = left;
  var b = right;
  var c = b - ratio * (b - a);
  var d = a + ratio * (b - a);
  var fc = function(c);
  var fd = function(d);
  if (!fc.isFinite || !fd.isFinite) return null;
  for (var i = 0; i < 100; i++) {
    final chooseLeft = minimize ? fc < fd : fc > fd;
    if (chooseLeft) {
      b = d;
      d = c;
      fd = fc;
      c = b - ratio * (b - a);
      fc = function(c);
    } else {
      a = c;
      c = d;
      fc = fd;
      d = a + ratio * (b - a);
      fd = function(d);
    }
    if (!fc.isFinite || !fd.isFinite) return null;
  }
  return (a + b) / 2;
}

List<GraphPoint> findIntersections(
  String first,
  String second, {
  required double minX,
  required double maxX,
  int samples = 1200,
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  final f = _CompiledFunction(first, variable: 'x', angleUnit: angleUnit);
  final g = _CompiledFunction(second, variable: 'x', angleUnit: angleUnit);
  double difference(double x) => f(x) - g(x);
  final count = samples.clamp(50, 8000);
  final points = <GraphPoint>[];
  final tolerance = (maxX - minX) * 1e-6;
  double? previousX;
  double? previousY;
  for (var i = 0; i < count; i++) {
    final x = minX + (maxX - minX) * i / (count - 1);
    final y = difference(x);
    if (!y.isFinite) {
      previousX = null;
      previousY = null;
      continue;
    }
    if (previousY != null && previousX != null) {
      if ((previousY <= 0 && y > 0) || (previousY >= 0 && y < 0)) {
        final root = _bisect(difference, previousX, x);
        if (root != null &&
            !points.any((point) => (point.x - root).abs() < tolerance)) {
          final fy = f(root);
          if (fy.isFinite) points.add(GraphPoint(root, fy));
        }
      }
    }
    previousX = x;
    previousY = y;
  }
  return points;
}

TangentLine tangentAt(
  String source,
  double x, {
  AngleUnit angleUnit = AngleUnit.degrees,
}) {
  final function = _CompiledFunction(source, variable: 'x', angleUnit: angleUnit);
  final h = math.max(1e-6, x.abs() * 1e-6);
  final slope = (function(x + h) - function(x - h)) / (2 * h);
  final y = function(x);
  if (!slope.isFinite || !y.isFinite) {
    throw const CalcError(
      CalcErrorKind.math,
      detail: 'المماس غير معرّف عند النقطة دي.',
    );
  }
  return TangentLine(
    point: GraphPoint(x, y),
    slope: slope,
    intercept: y - slope * x,
  );
}

double _toRadians(double value, AngleUnit unit) => switch (unit) {
  AngleUnit.degrees => value * math.pi / 180,
  AngleUnit.radians => value,
  AngleUnit.gradians => value * math.pi / 200,
};
