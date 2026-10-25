/// Polynomial roots, synthetic division and polynomial extraction from AST.
///
/// Quadratic and cubic/quartic roots are computed with closed forms / the
/// Durand–Kerner method. Results are always numeric except for the rational
/// roots found exactly by the factorer. The caller decides how many decimals
/// to display.
library;

import 'dart:math' as math;

import 'ast.dart';
import 'calculator_error.dart';
import 'math_value.dart';

class ComplexRoot {
  const ComplexRoot(this.real, this.imaginary, {this.exactReal});

  final double real;
  final double imaginary;
  final Rational? exactReal;

  bool get isReal => imaginary == 0;
  double get magnitude => math.sqrt(real * real + imaginary * imaginary);

  @override
  String toString() => isReal ? '$real' : '$real + ${imaginary}i';
}

class PolynomialRootResult {
  const PolynomialRootResult({
    required this.roots,
    required this.converged,
    this.message,
  });

  final List<ComplexRoot> roots;
  final bool converged;
  final String? message;
}

/// Finds all roots of `coefficients[0]·x^n + … + coefficients[n]`.
///
/// Throws [CalcError] for an all-zero polynomial. A non-converged numerical
/// result is still returned with [PolynomialRootResult.converged] false so the
/// UI can be honest instead of silently presenting bad roots.
PolynomialRootResult polynomialRoots(List<double> coefficients) {
  final values = _trim(coefficients);
  if (values.isEmpty) {
    throw const CalcError(
      CalcErrorKind.math,
      detail: 'كل المعاملات صفر — مفيش معادلة.',
    );
  }
  final degree = values.length - 1;
  if (degree == 0) {
    return const PolynomialRootResult(roots: <ComplexRoot>[], converged: true);
  }

  if (degree == 1) {
    final root = -values[1] / values[0];
    return PolynomialRootResult(
      roots: <ComplexRoot>[_rootWithRationalHint(root)],
      converged: true,
    );
  }

  if (degree == 2) return _quadratic(values[0], values[1], values[2]);

  final monic = <double>[for (final value in values) value / values[0]];
  final radius =
      1 +
      monic
          .sublist(1)
          .map((value) => value.abs())
          .fold<double>(0, math.max);
  final roots = <double>[
    for (var i = 0; i < degree; i++)
      radius * math.cos(2 * math.pi * i / degree + 0.4),
  ];
  final imaginary = <double>[
    for (var i = 0; i < degree; i++)
      radius * math.sin(2 * math.pi * i / degree + 0.4),
  ];

  var converged = false;
  var iterations = 0;
  for (; iterations < 4000; iterations++) {
    var maximumDelta = 0.0;
    for (var i = 0; i < degree; i++) {
      var realDenominator = 1.0;
      var imaginaryDenominator = 0.0;
      for (var j = 0; j < degree; j++) {
        if (i == j) continue;
        final dr = roots[i] - roots[j];
        final di = imaginary[i] - imaginary[j];
        final denominator = dr * dr + di * di;
        if (denominator < 1e-30) continue;
        // (root_i - root_j)^-1
        final invR = dr / denominator;
        final invI = -di / denominator;
        final nextR =
            realDenominator * invR - imaginaryDenominator * invI;
        final nextI =
            realDenominator * invI + imaginaryDenominator * invR;
        realDenominator = nextR;
        imaginaryDenominator = nextI;
      }
      final value = _evaluateComplex(monic, roots[i], imaginary[i]);
      final quotientR =
          value.$1 * realDenominator - value.$2 * imaginaryDenominator;
      final quotientI =
          value.$1 * imaginaryDenominator + value.$2 * realDenominator;
      roots[i] -= quotientR;
      imaginary[i] -= quotientI;
      maximumDelta = math.max(
        maximumDelta,
        math.sqrt(quotientR * quotientR + quotientI * quotientI),
      );
    }
    if (maximumDelta < 1e-11) {
      converged = true;
      break;
    }
  }

  // Polish and deduplicate near-identical roots.
  final result = <ComplexRoot>[];
  for (var i = 0; i < degree; i++) {
    final real = roots[i];
    final imag = imaginary[i].abs() < 1e-9 ? 0.0 : imaginary[i];
    final root = _rootWithRationalHint(real, imaginary: imag);
    final duplicate = result.any(
      (existing) =>
          (existing.real - root.real).abs() < 1e-7 &&
          (existing.imaginary - root.imaginary).abs() < 1e-7,
    );
    if (!duplicate) result.add(root);
  }
  result.sort(_compareRoots);
  return PolynomialRootResult(
    roots: result,
    converged: converged,
    message: converged
        ? null
        : 'التقريب العددي ما وصلش لدقة كاملة بعد $iterations تكرار.',
  );
}

PolynomialRootResult _quadratic(double a, double b, double c) {
  final discriminant = b * b - 4 * a * c;
  if (discriminant.abs() < 1e-12) {
    final root = -b / (2 * a);
    return PolynomialRootResult(
      roots: <ComplexRoot>[_rootWithRationalHint(root)],
      converged: true,
    );
  }
  if (discriminant < 0) {
    final real = -b / (2 * a);
    final imaginary = math.sqrt(-discriminant) / (2 * a).abs();
    return PolynomialRootResult(
      roots: <ComplexRoot>[
        ComplexRoot(real, imaginary),
        ComplexRoot(real, -imaginary),
      ],
      converged: true,
    );
  }
  final sqrt = math.sqrt(discriminant);
  // Numerically stable quadratic formula.
  final q = -0.5 * (b + (b >= 0 ? sqrt : -sqrt));
  final first = q / a;
  final second = q == 0 ? first : c / q;
  final roots = <ComplexRoot>[
    _rootWithRationalHint(first),
    _rootWithRationalHint(second),
  ]..sort(_compareRoots);
  return PolynomialRootResult(roots: roots, converged: true);
}

ComplexRoot _rootWithRationalHint(double real, {double imaginary = 0}) {
  Rational? exact;
  if (imaginary == 0) {
    final round = real.roundToDouble();
    if ((real - round).abs() < 1e-10 && round.abs() < 1e15) {
      exact = Rational.fromInt(round.toInt());
    } else {
      exact = Rational.approximate(
        real,
        maxDenominator: 100000,
        tolerance: 1e-10,
      );
    }
  }
  return ComplexRoot(real, imaginary, exactReal: exact);
}

int _compareRoots(ComplexRoot a, ComplexRoot b) {
  if (a.isReal != b.isReal) return a.isReal ? -1 : 1;
  final real = a.real.compareTo(b.real);
  if (real != 0) return real;
  return a.imaginary.compareTo(b.imaginary);
}

List<double> _trim(List<double> coefficients) {
  var start = 0;
  while (start < coefficients.length && coefficients[start].abs() < 1e-14) {
    start++;
  }
  return coefficients.sublist(start);
}

(double, double) _evaluateComplex(List<double> coefficients, double real, double imag) {
  var realValue = coefficients.first;
  var imaginaryValue = 0.0;
  for (var i = 1; i < coefficients.length; i++) {
    final nextReal = realValue * real - imaginaryValue * imag + coefficients[i];
    final nextImaginary = realValue * imag + imaginaryValue * real;
    realValue = nextReal;
    imaginaryValue = nextImaginary;
  }
  return (realValue, imaginaryValue);
}

double evaluatePolynomial(List<double> coefficients, double x) {
  var value = 0.0;
  for (final coefficient in coefficients) {
    value = value * x + coefficient;
  }
  return value;
}

List<double> derivativeCoefficients(List<double> coefficients) {
  if (coefficients.length <= 1) return const <double>[0];
  final degree = coefficients.length - 1;
  return <double>[
    for (var i = 0; i < degree; i++) coefficients[i] * (degree - i),
  ];
}

/// Extracts exact polynomial coefficients from [expression] in [variable].
///
/// Returns coefficients from highest degree to constant, or `null` when the
/// expression is not a polynomial (for example `sin(x)` or `x^x`).
List<Rational>? polynomialCoefficients(Expr expression, String variable) {
  List<Rational>? add(
    List<Rational>? a,
    List<Rational>? b,
    int sign,
  ) {
    if (a == null || b == null) return null;
    final length = math.max(a.length, b.length);
    final result = List<Rational>.filled(length, Rational.zero);
    for (var i = 0; i < length; i++) {
      final ai = i - (length - a.length);
      final bi = i - (length - b.length);
      result[i] =
          (ai >= 0 ? a[ai] : Rational.zero) +
          (bi >= 0 ? b[bi] : Rational.zero) * Rational.fromInt(sign);
    }
    return result;
  }

  List<Rational>? multiply(List<Rational>? a, List<Rational>? b) {
    if (a == null || b == null) return null;
    final result = List<Rational>.filled(
      a.length + b.length - 1,
      Rational.zero,
    );
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < b.length; j++) {
        result[i + j] = result[i + j] + a[i] * b[j];
      }
    }
    return result;
  }

  List<Rational>? divideByConstant(List<Rational>? a, Rational divisor) {
    if (a == null || divisor.isZero) return null;
    return [for (final coefficient in a) coefficient / divisor];
  }

  List<Rational>? visit(Expr node) {
    switch (node) {
      case LiteralExpr():
        return <Rational>[node.value];
      case VariableExpr():
        return node.name == variable
            ? <Rational>[Rational.one, Rational.zero]
            : <Rational>[Rational.zero];
      case ConstantExpr():
        if (node.name == 'pi' || node.name == 'e') return null;
        return null;
      case UnaryExpr():
        final operand = visit(node.operand);
        if (operand == null) return null;
        if (node.operator == '+') return operand;
        if (node.operator == '-') {
          return [for (final coefficient in operand) -coefficient];
        }
        if (node.operator == '%') {
          return divideByConstant(operand, Rational.fromInt(100));
        }
        return null;
      case BinaryExpr():
        final left = visit(node.left);
        final right = visit(node.right);
        switch (node.operator) {
          case '+':
            return add(left, right, 1);
          case '-':
            return add(left, right, -1);
          case '*':
            return multiply(left, right);
          case '/':
            if (right == null || right.length != 1 || right[0].isZero) {
              return null;
            }
            return divideByConstant(left, right[0]);
          case '^':
            if (right == null || right.length != 1) return null;
            final exponent = right[0];
            if (!exponent.isInteger) return null;
            final power = exponent.toInt();
            if (power == null || power < 0 || power > 64) return null;
            if (left == null) return null;
            var result = <Rational>[Rational.one];
            for (var i = 0; i < power; i++) {
              result = multiply(result, left)!;
            }
            return result;
        }
        return null;
      case PostfixExpr():
        final operand = visit(node.operand);
        if (operand == null) return null;
        switch (node.operator) {
          case '²':
            return multiply(operand, operand);
          case '³':
            return multiply(multiply(operand, operand), operand);
          case '%':
            return divideByConstant(operand, Rational.fromInt(100));
        }
        return null;
      case FunctionExpr():
        return null;
    }
  }

  final coefficients = visit(expression);
  if (coefficients == null || coefficients.isEmpty) return null;
  // Remove leading zero coefficients.
  var start = 0;
  while (start < coefficients.length - 1 &&
      coefficients[start].isZero) {
    start++;
  }
  return coefficients.sublist(start);
}

/// Finds exact rational roots using the rational-root theorem.
List<Rational> rationalRoots(List<Rational> coefficients) {
  if (coefficients.length <= 1) return const <Rational>[];
  final roots = <Rational>[];
  var working = List<Rational>.of(coefficients);

  // Clear denominators so the rational-root theorem applies to integers.
  var lcm = BigInt.one;
  for (final coefficient in working) {
    lcm = _lcm(lcm, coefficient.denominator);
  }
  working = [
    for (final coefficient in working)
      Rational(coefficient.numerator * (lcm ~/ coefficient.denominator)),
  ];

  while (working.length > 1) {
    if (working.last.isZero) {
      roots.add(Rational.zero);
      working.removeLast();
      continue;
    }
    final leading = working.first.numerator.abs();
    final constant = working.last.numerator.abs();
    final candidates = <Rational>{};
    for (final p in _divisors(constant)) {
      for (final q in _divisors(leading)) {
        final candidate = Rational(p, q);
        candidates.add(candidate);
        candidates.add(-candidate);
      }
    }
    Rational? found;
    for (final candidate in candidates) {
      if (evaluateRationalPolynomial(working, candidate).isZero) {
        found = candidate;
        break;
      }
    }
    if (found == null) break;
    roots.add(found);
    working = _syntheticDivide(working, found);
  }
  return roots;
}

Rational evaluateRationalPolynomial(List<Rational> coefficients, Rational x) {
  var value = Rational.zero;
  for (final coefficient in coefficients) {
    value = value * x + coefficient;
  }
  return value;
}

List<Rational> _syntheticDivide(List<Rational> coefficients, Rational root) {
  final result = <Rational>[coefficients.first];
  for (var i = 1; i < coefficients.length - 1; i++) {
    result.add(result.last * root + coefficients[i]);
  }
  return result;
}

Set<BigInt> _divisors(BigInt value) {
  if (value == BigInt.zero) return <BigInt>{BigInt.one};
  if (value > BigInt.from(100000000)) {
    return <BigInt>{BigInt.one, value};
  }
  final integer = value.toInt();
  final result = <BigInt>{};
  for (var i = 1; i * i <= integer && i <= 2000; i++) {
    if (integer % i == 0) {
      result.add(BigInt.from(i));
      result.add(BigInt.from(integer ~/ i));
      if (result.length > 400) break;
    }
  }
  return result;
}

BigInt _lcm(BigInt a, BigInt b) => a ~/ a.gcd(b) * b;

/// Formats polynomial coefficients (highest degree first) as an expression.
String formatPolynomial(
  List<Rational> coefficients,
  String variable, {
  bool zeroTerms = false,
}) {
  final buffer = StringBuffer();
  final degree = coefficients.length - 1;
  for (var i = 0; i < coefficients.length; i++) {
    final coefficient = coefficients[i];
    if (coefficient.isZero && !zeroTerms) continue;
    final power = degree - i;
    final negative = coefficient.isNegative;
    final absolute = coefficient.abs();
    final isFirst = buffer.isEmpty;
    if (isFirst) {
      if (negative) buffer.write('−');
    } else {
      buffer.write(negative ? ' − ' : ' + ');
    }
    final needsCoefficient = power == 0 || absolute != Rational.one;
    if (needsCoefficient) buffer.write(absolute.toString());
    if (power > 0) {
      buffer.write(variable);
      if (power == 2) {
        buffer.write('²');
      } else if (power == 3) {
        buffer.write('³');
      } else if (power > 3) {
        buffer.write('^$power');
      }
    }
  }
  return buffer.isEmpty ? '0' : buffer.toString();
}

/// Factors a polynomial over the rationals. The returned string is exact.
String factorPolynomial(List<Rational> coefficients, String variable) {
  if (coefficients.length <= 1) return coefficients.isEmpty ? '0' : coefficients.first.toString();
  var working = List<Rational>.of(coefficients);
  final factors = <String>[];
  final roots = rationalRoots(working);
  for (final root in roots) {
    working = _syntheticDivide(working, root);
    // (x - root), written without awkward double signs.
    if (root.isZero) {
      factors.add(variable);
    } else if (root.isPositive) {
      factors.add('($variable − ${root.toString()})');
    } else {
      factors.add('($variable + ${(-root).toString()})');
    }
  }
  // Normalise the leading coefficient into a separate factor.
  final leading = working.first;
  final monic = <Rational>[for (final coefficient in working) coefficient / leading];
  if (leading != Rational.one && leading != Rational.fromInt(-1)) {
    factors.insert(0, leading.toString());
  } else if (leading == Rational.fromInt(-1)) {
    factors.insert(0, '−1');
  }
  final remainder = formatPolynomial(monic, variable);
  if (remainder != '1') factors.add('($remainder)');
  return factors.isEmpty ? '1' : factors.join('·');
}
