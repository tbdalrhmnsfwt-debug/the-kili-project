/// Descriptive statistics and two-variable regression for STAT mode.
library;

import 'dart:math' as math;

import 'calculator_error.dart';
import 'linear_systems.dart';
import 'number_format.dart';

class StatisticsSummary {
  StatisticsSummary._({
    required this.values,
    required this.sum,
    required this.sumSquares,
    required this.mean,
    required this.median,
    required this.modes,
    required this.minimum,
    required this.maximum,
    required this.range,
    required this.q1,
    required this.q3,
    required this.varianceSample,
    required this.variancePopulation,
    required this.sdSample,
    required this.sdPopulation,
  });

  factory StatisticsSummary.fromValues(List<double> input) {
    if (input.isEmpty) {
      throw const CalcError(
        CalcErrorKind.argument,
        detail: 'أدخل قيمة واحدة على الأقل.',
      );
    }
    if (input.any((value) => value.isNaN || !value.isFinite)) {
      throw const CalcError(CalcErrorKind.math);
    }
    final values = List<double>.of(input);
    final sorted = List<double>.of(values)..sort();
    var sum = 0.0;
    var sumSquares = 0.0;
    for (final value in values) {
      sum += value;
      sumSquares += value * value;
    }
    final mean = sum / values.length;
    var squaredDeviations = 0.0;
    for (final value in values) {
      squaredDeviations += (value - mean) * (value - mean);
    }
    final varianceSample = values.length > 1
        ? squaredDeviations / (values.length - 1)
        : 0.0;
    final variancePopulation = squaredDeviations / values.length;

    // Frequency-aware mode. Every value is reported when all are distinct.
    final frequencies = <double, int>{};
    for (final value in values) {
      frequencies[value] = (frequencies[value] ?? 0) + 1;
    }
    final highest = frequencies.values.fold<int>(0, math.max);
    final modes = <double>[
      for (final entry in frequencies.entries)
        if (entry.value == highest) entry.key,
    ]..sort();
    final allDistinct = frequencies.length == values.length;

    return StatisticsSummary._(
      values: List<double>.unmodifiable(values),
      sum: sum,
      sumSquares: sumSquares,
      mean: mean,
      median: _median(sorted),
      modes: allDistinct ? const <double>[] : List<double>.unmodifiable(modes),
      minimum: sorted.first,
      maximum: sorted.last,
      range: sorted.last - sorted.first,
      q1: _quartile(sorted, 0.25),
      q3: _quartile(sorted, 0.75),
      varianceSample: varianceSample,
      variancePopulation: variancePopulation,
      sdSample: math.sqrt(varianceSample),
      sdPopulation: math.sqrt(variancePopulation),
    );
  }

  final List<double> values;
  final double sum;
  final double sumSquares;
  final double mean;
  final double median;
  final List<double> modes;
  final double minimum;
  final double maximum;
  final double range;
  final double q1;
  final double q3;
  final double varianceSample;
  final double variancePopulation;
  final double sdSample;
  final double sdPopulation;

  int get count => values.length;
  double get iqr => q3 - q1;

  String format() {
    final lines = <String>[
      'n = $count',
      'Σx = ${formatReal(sum)}',
      'Σx² = ${formatReal(sumSquares)}',
      'x̄ = ${formatReal(mean)}',
      'الوسيط = ${formatReal(median)}',
      'Q₁ = ${formatReal(q1)}',
      'Q₃ = ${formatReal(q3)}',
      'المدى = ${formatReal(range)}',
      's = ${formatReal(sdSample)}',
      'σ = ${formatReal(sdPopulation)}',
      's² = ${formatReal(varianceSample)}',
      'σ² = ${formatReal(variancePopulation)}',
      'أصغر = ${formatReal(minimum)}',
      'أكبر = ${formatReal(maximum)}',
      if (modes.isNotEmpty)
        'المنوال = ${modes.map(formatReal).join(', ')}',
    ];
    return lines.join('\n');
  }
}

double _median(List<double> sorted) {
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

double _quartile(List<double> sorted, double fraction) {
  if (sorted.length == 1) return sorted.first;
  final position = (sorted.length - 1) * fraction;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final weight = position - lower;
  return sorted[lower] * (1 - weight) + sorted[upper] * weight;
}

class RegressionResult {
  const RegressionResult({
    required this.kind,
    required this.coefficients,
    required this.correlation,
    required this.rSquared,
    required this.summary,
    this.message,
  });

  final String kind;

  /// Highest-degree coefficient first. Linear: [slope, intercept].
  final List<double> coefficients;
  final double correlation;
  final double rSquared;
  final Map<String, double> summary;
  final String? message;

  String get equation {
    if (kind == 'linear') {
      final slope = formatReal(coefficients[0]);
      final sign = coefficients[1] < 0 ? '−' : '+';
      return 'y = ${slope}x $sign ${formatReal(coefficients[1].abs())}';
    }
    if (kind == 'quadratic') {
      final a = formatReal(coefficients[0]);
      final b = coefficients[1];
      final c = coefficients[2];
      return 'y = ${a}x² ${b < 0 ? '−' : '+'} ${formatReal(b.abs())}x '
          '${c < 0 ? '−' : '+'} ${formatReal(c.abs())}';
    }
    return kind;
  }
}

RegressionResult linearRegression(List<double> xs, List<double> ys) {
  _validatePairs(xs, ys);
  final n = xs.length;
  var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0, sumY2 = 0.0;
  for (var i = 0; i < n; i++) {
    sumX += xs[i];
    sumY += ys[i];
    sumXY += xs[i] * ys[i];
    sumX2 += xs[i] * xs[i];
    sumY2 += ys[i] * ys[i];
  }
  final denominator = n * sumX2 - sumX * sumX;
  if (denominator.abs() < 1e-14) {
    throw const CalcError(
      CalcErrorKind.math,
      detail: 'كل قيم x متساوية — مفيش خط انحدار.',
    );
  }
  final slope = (n * sumXY - sumX * sumY) / denominator;
  final intercept = (sumY - slope * sumX) / n;
  final correlationDenominator = math.sqrt(
    (n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY),
  );
  final correlation = correlationDenominator == 0
      ? 0.0
      : (n * sumXY - sumX * sumY) / correlationDenominator;
  var ssRes = 0.0;
  var ssTot = 0.0;
  final meanY = sumY / n;
  for (var i = 0; i < n; i++) {
    final predicted = slope * xs[i] + intercept;
    ssRes += (ys[i] - predicted) * (ys[i] - predicted);
    ssTot += (ys[i] - meanY) * (ys[i] - meanY);
  }
  return RegressionResult(
    kind: 'linear',
    coefficients: <double>[slope, intercept],
    correlation: correlation.clamp(-1.0, 1.0),
    rSquared: ssTot == 0 ? 1.0 : 1 - ssRes / ssTot,
    summary: <String, double>{
      'n': n.toDouble(),
      'Σx': sumX,
      'Σy': sumY,
      'Σxy': sumXY,
      'Σx²': sumX2,
      'x̄': sumX / n,
      'ȳ': meanY,
    },
  );
}

RegressionResult quadraticRegression(List<double> xs, List<double> ys) {
  _validatePairs(xs, ys);
  final n = xs.length;
  if (n < 3) {
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'الانحدار التربيعي محتاج 3 نقاط على الأقل.',
    );
  }
  var s1 = 0.0, s2 = 0.0, s3 = 0.0, s4 = 0.0;
  var t0 = 0.0, t1 = 0.0, t2 = 0.0;
  for (var i = 0; i < n; i++) {
    final x = xs[i];
    final x2 = x * x;
    s1 += x;
    s2 += x2;
    s3 += x2 * x;
    s4 += x2 * x2;
    t0 += ys[i];
    t1 += x * ys[i];
    t2 += x2 * ys[i];
  }
  final solution = solveLinearSystem(
    <List<double>>[
      <double>[s4, s3, s2],
      <double>[s3, s2, s1],
      <double>[s2, s1, n.toDouble()],
    ],
    <double>[t2, t1, t0],
  );
  if (!solution.hasUniqueSolution) {
    throw const CalcError(
      CalcErrorKind.math,
      detail: 'مفيش انحدار تربيعي وحيد للبيانات دي.',
    );
  }
  final a = solution.values[0];
  final b = solution.values[1];
  final c = solution.values[2];
  // The quadratic model is a·x² + b·x + c; all three are reported below.
  var ssRes = 0.0;
  var ssTot = 0.0;
  final meanY = t0 / n;
  for (var i = 0; i < n; i++) {
    final predicted = a * xs[i] * xs[i] + b * xs[i] + c;
    ssRes += (ys[i] - predicted) * (ys[i] - predicted);
    ssTot += (ys[i] - meanY) * (ys[i] - meanY);
  }
  return RegressionResult(
    kind: 'quadratic',
    coefficients: <double>[a, b, c],
    correlation: 0,
    rSquared: ssTot == 0 ? 1.0 : 1 - ssRes / ssTot,
    summary: <String, double>{
      'n': n.toDouble(),
      'Σx': s1,
      'Σy': t0,
    },
  );
}

void _validatePairs(List<double> xs, List<double> ys) {
  if (xs.isEmpty || xs.length != ys.length) {
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'عدد قيم x لازم يساوي عدد قيم y.',
    );
  }
  if (xs.length < 2) {
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'الانحدار محتاج نقطتين على الأقل.',
    );
  }
  if (xs.any((value) => !value.isFinite) ||
      ys.any((value) => !value.isFinite)) {
    throw const CalcError(CalcErrorKind.math);
  }
}
