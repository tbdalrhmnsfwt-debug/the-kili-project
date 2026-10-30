/// Exact rational arithmetic and the value type used by the calculator engine.
///
/// The calculator keeps an exact `BigInt` rational whenever the user's input
/// and the operation allow it. Only transcendental functions, roots that are
/// not perfect, and explicitly complex operations fall back to floating point.
/// This is what prevents artefacts such as `0.1 + 0.2 = 0.30000000000000004`.
library;

import 'dart:math' as math;

/// An exact rational number with a positive, reduced denominator.
class Rational implements Comparable<Rational> {
  Rational._(this.numerator, this.denominator);

  factory Rational(BigInt numerator, [BigInt? denominator]) {
    var n = numerator;
    var d = denominator ?? BigInt.one;
    if (d == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'zero');
    }
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final gcd = n.abs().gcd(d);
    if (gcd > BigInt.one) {
      n = n ~/ gcd;
      d = d ~/ gcd;
    }
    return Rational._(n, d);
  }

  /// Upper bound on a literal's exponent and decimal places, matching
  /// `Evaluator._maxExactExponent`.
  static const int maxLiteralExponent = 10000;

  factory Rational.fromInt(int value, [int denominator = 1]) =>
      Rational(BigInt.from(value), BigInt.from(denominator));

  factory Rational.parse(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      throw const FormatException('empty rational');
    }
    var sign = BigInt.one;
    var body = text;
    if (body.startsWith('+')) {
      body = body.substring(1);
    } else if (body.startsWith('-')) {
      sign = -BigInt.one;
      body = body.substring(1);
    }
    var exponent = 0;
    final eIndex = body.indexOf(RegExp('[eE]'));
    if (eIndex >= 0) {
      exponent = int.parse(body.substring(eIndex + 1));
      // `1e999999999` would allocate a BigInt of ~400 MB during a keystroke
      // preview. Reject anything past the evaluator's exact-exponent ceiling.
      if (exponent.abs() > maxLiteralExponent) {
        throw FormatException('exponent out of range', source);
      }
      body = body.substring(0, eIndex);
    }
    final dot = body.indexOf('.');
    String digits;
    var scale = 0;
    if (dot >= 0) {
      digits = body.substring(0, dot) + body.substring(dot + 1);
      scale = body.length - dot - 1;
    } else {
      digits = body;
    }
    if (digits.isEmpty || digits == '.') {
      throw FormatException('invalid rational', source);
    }
    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      throw FormatException('invalid rational', source);
    }
    if (scale > maxLiteralExponent) {
      throw FormatException('too many decimal places', source);
    }
    var numerator = BigInt.parse(digits) * sign;
    var denominator = BigInt.one;
    final shift = scale - exponent;
    if (shift > 0) {
      denominator = BigInt.from(10).pow(shift);
    } else if (shift < 0) {
      numerator *= BigInt.from(10).pow(-shift);
    }
    return Rational(numerator, denominator);
  }

  /// Tries to parse a decimal string, returning `null` when it is malformed.
  static Rational? tryParse(String source) {
    try {
      return Rational.parse(source);
    } on FormatException {
      return null;
    }
  }

  static final Rational zero = Rational.fromInt(0);
  static final Rational one = Rational.fromInt(1);
  static final Rational two = Rational.fromInt(2);

  final BigInt numerator;
  final BigInt denominator;

  bool get isInteger => denominator == BigInt.one;
  bool get isZero => numerator == BigInt.zero;
  bool get isPositive => numerator > BigInt.zero;
  bool get isNegative => numerator < BigInt.zero;
  int get sign => numerator.sign;

  double toDouble() => numerator.toDouble() / denominator.toDouble();

  /// Returns the integer value when this rational is an integer.
  int? toInt() => isInteger ? numerator.toInt() : null;

  BigInt get floor {
    if (isInteger) return numerator;
    if (isPositive) return numerator ~/ denominator;
    return (numerator - denominator + BigInt.one) ~/ denominator;
  }

  Rational abs() => isNegative ? -this : this;

  Rational operator -() => Rational._(-numerator, denominator);

  Rational operator +(Rational other) => Rational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator -(Rational other) => Rational(
        numerator * other.denominator - other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator *(Rational other) => Rational(
        numerator * other.numerator,
        denominator * other.denominator,
      );

  Rational operator /(Rational other) {
    if (other.isZero) {
      throw const DivisionByZero();
    }
    return Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  Rational reciprocal() {
    if (isZero) throw const DivisionByZero();
    return Rational(denominator, numerator);
  }

  /// Integer exponent. `0^0` follows the calculator convention and is `1`.
  Rational pow(int exponent) {
    if (exponent == 0) return one;
    if (exponent < 0) {
      if (isZero) throw const DivisionByZero();
      return Rational(
        denominator.pow(-exponent),
        numerator.pow(-exponent),
      );
    }
    return Rational(numerator.pow(exponent), denominator.pow(exponent));
  }

  /// The exact integer root, or `null` when the root is irrational.
  Rational? nthRoot(int n) {
    if (n <= 0) return null;
    if (isZero) return zero;
    if (isNegative) {
      if (n.isEven) return null;
      final root = (-this).nthRoot(n);
      return root == null ? null : -root;
    }
    final numRoot = _integerNthRoot(numerator, n);
    final denRoot = _integerNthRoot(denominator, n);
    if (numRoot == null || denRoot == null) return null;
    return Rational(numRoot, denRoot);
  }

  /// A rational approximation of [value] with a bounded denominator.
  ///
  /// Uses the continued-fraction expansion, tolerating floating-point noise.
  static Rational? approximate(
    double value, {
    int maxDenominator = 1000000,
    double tolerance = 1e-12,
  }) {
    if (!value.isFinite || value.abs() > 1e15) return null;
    if (value == value.roundToDouble()) {
      return Rational.fromInt(value.round());
    }
    final sign = value.isNegative ? -1 : 1;
    var target = value.abs();
    var h1 = 1, h0 = 0, k1 = 0, k0 = 1;
    for (var i = 0; i < 64; i++) {
      final whole = target.floor();
      final h2 = whole * h1 + h0;
      final k2 = whole * k1 + k0;
      if (k2 > maxDenominator || k2 <= 0) break;
      h0 = h1;
      h1 = h2;
      k0 = k1;
      k1 = k2;
      final fraction = target - whole;
      if (fraction.abs() < 1e-14) break;
      target = 1 / fraction;
    }
    if (k1 == 0) return null;
    final approximated = h1 / k1 * sign;
    if ((approximated - value).abs() > tolerance * math.max(1, value.abs())) {
      return null;
    }
    return Rational.fromInt(sign * h1, k1);
  }

  bool closeTo(Rational other, {double tolerance = 1e-12}) {
    final a = toDouble();
    final b = other.toDouble();
    return (a - b).abs() <= tolerance * math.max(1, math.max(a.abs(), b.abs()));
  }

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() =>
      isInteger ? numerator.toString() : '$numerator/$denominator';
}

class DivisionByZero implements Exception {
  const DivisionByZero();

  @override
  String toString() => 'DivisionByZero';
}

/// Returns the exact integer n-th root of a non-negative [BigInt], if any.
BigInt? _integerNthRoot(BigInt value, int n) {
  if (value == BigInt.zero) return BigInt.zero;
  if (value == BigInt.one) return BigInt.one;
  var low = BigInt.zero;
  var high = BigInt.one;
  while (high.pow(n) <= value) {
    high *= BigInt.two;
  }
  while (low + BigInt.one < high) {
    final middle = (low + high) ~/ BigInt.two;
    if (middle.pow(n) <= value) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return low.pow(n) == value ? low : null;
}

/// A real value that is either exact (a [Rational]) or a floating estimate.
///
/// Complex values are always approximate. The class is immutable.
class EvalValue {
  const EvalValue._(this.exact, this.realPart, this.imaginaryPart);

  factory EvalValue.exact(Rational value) =>
      EvalValue._(value, value.toDouble(), 0);

  factory EvalValue.real(double value) {
    if (value.isNaN || !value.isFinite) {
      throw const NonFiniteValue();
    }
    return EvalValue._(null, value, 0);
  }

  factory EvalValue.complex(double real, double imaginary) {
    if (real.isNaN ||
        imaginary.isNaN ||
        !real.isFinite ||
        !imaginary.isFinite) {
      throw const NonFiniteValue();
    }
    // Remove floating residue such as 1.2246467991473532e-16 i after
    // evaluating sin(pi), and the mirror case: `(-1)^0.5` leaves a 6.1e-17
    // real part next to `i`. Both parts are judged against the same scale so a
    // complex result never shows one component of pure noise.
    final scale = math.max(1.0, math.max(real.abs(), imaginary.abs()));
    if (real.abs() < 1e-13 * scale) real = 0;
    if (imaginary.abs() < 1e-13 * scale) imaginary = 0;
    if (imaginary == 0) {
      return EvalValue._(null, real, 0);
    }
    return EvalValue._(null, real, imaginary);
  }

  factory EvalValue.integer(int value) =>
      EvalValue.exact(Rational.fromInt(value));

  /// Exact real value, or `null` for an approximation/complex value.
  final Rational? exact;
  final double realPart;
  final double imaginaryPart;

  bool get isExact => exact != null;
  bool get isReal => imaginaryPart == 0;
  bool get isComplex => imaginaryPart != 0;

  /// The epsilon only applies to approximations. An exact rational knows
  /// whether it is zero, and `1e-16` is a perfectly good divisor.
  bool get isZero {
    final value = exact;
    if (value != null) return value.isZero;
    return isReal && realPart.abs() < 1e-15;
  }

  double get magnitude => isReal
      ? realPart.abs()
      : math.sqrt(realPart * realPart + imaginaryPart * imaginaryPart);

  double get argument {
    if (isReal) {
      if (realPart >= 0) return 0;
      return math.pi;
    }
    return math.atan2(imaginaryPart, realPart);
  }

  EvalValue get conjugate =>
      isComplex ? EvalValue.complex(realPart, -imaginaryPart) : this;

  /// A close rational approximation, used only for display (never for maths).
  Rational? get rationalApproximation {
    if (exact != null) return exact;
    if (isComplex) return null;
    if (realPart == realPart.roundToDouble() && realPart.abs() < 1e12) {
      return Rational.fromInt(realPart.round());
    }
    return Rational.approximate(realPart, maxDenominator: 100000);
  }

  EvalValue operator +(EvalValue other) {
    if (exact != null && other.exact != null) {
      return EvalValue.exact(exact! + other.exact!);
    }
    return EvalValue.complex(
      realPart + other.realPart,
      imaginaryPart + other.imaginaryPart,
    );
  }

  EvalValue operator -(EvalValue other) {
    if (exact != null && other.exact != null) {
      return EvalValue.exact(exact! - other.exact!);
    }
    return EvalValue.complex(
      realPart - other.realPart,
      imaginaryPart - other.imaginaryPart,
    );
  }

  EvalValue operator *(EvalValue other) {
    if (exact != null && other.exact != null) {
      return EvalValue.exact(exact! * other.exact!);
    }
    return EvalValue.complex(
      realPart * other.realPart - imaginaryPart * other.imaginaryPart,
      realPart * other.imaginaryPart + imaginaryPart * other.realPart,
    );
  }

  EvalValue operator /(EvalValue other) {
    if (other.isZero) throw const DivisionByZero();
    if (exact != null && other.exact != null) {
      return EvalValue.exact(exact! / other.exact!);
    }
    final denominator = other.realPart * other.realPart +
        other.imaginaryPart * other.imaginaryPart;
    if (denominator == 0) throw const DivisionByZero();
    return EvalValue.complex(
      (realPart * other.realPart + imaginaryPart * other.imaginaryPart) /
          denominator,
      (imaginaryPart * other.realPart - realPart * other.imaginaryPart) /
          denominator,
    );
  }

  EvalValue negate() => exact != null
      ? EvalValue.exact(-exact!)
      : EvalValue.complex(-realPart, -imaginaryPart);

  /// Integer power, keeping exactness for real values.
  EvalValue powInt(int exponent) {
    if (exponent == 0) return EvalValue.integer(1);
    if (exact != null) {
      try {
        return EvalValue.exact(exact!.pow(exponent));
      } on DivisionByZero {
        throw const DivisionByZero();
      }
    }
    if (isReal) {
      final value = math.pow(realPart, exponent).toDouble();
      return EvalValue.real(value);
    }
    var result = EvalValue.integer(1);
    var base = this;
    var power = exponent.abs();
    while (power > 0) {
      if (power.isOdd) result = result * base;
      base = base * base;
      power >>= 1;
    }
    return exponent < 0 ? EvalValue.integer(1) / result : result;
  }

  static EvalValue fromNum(num value) => value is int
      ? EvalValue.integer(value)
      : EvalValue.real(value.toDouble());

  @override
  String toString() => isComplex
      ? '${realPart.toString()}${imaginaryPart < 0 ? ' - ' : ' + '}'
          '${imaginaryPart.abs()}i'
      : (exact?.toString() ?? realPart.toString());
}

class NonFiniteValue implements Exception {
  const NonFiniteValue();

  @override
  String toString() => 'NonFiniteValue';
}
