/// Display formatting for calculator values.
///
/// The formatter never shows binary floating-point noise. Approximate values
/// are rounded to 12 significant digits (or a user-selected FIX precision) and
/// trailing zeros are removed. Exact values can be shown as integers,
/// improper fractions or mixed numbers, with the decimal form kept for the
/// S⇔D key.
library;

import 'dart:math' as math;

import 'evaluator.dart';
import 'math_value.dart';

class ValueFormat {
  const ValueFormat({
    required this.display,
    required this.decimal,
    this.exact,
    this.secondary,
    required this.isExact,
  });

  /// The text currently shown on the result line.
  final String display;

  /// The approximate decimal representation.
  final String decimal;

  /// The exact representation, when the engine kept one.
  final String? exact;

  /// The alternate representation for the S⇔D key, if any.
  final String? secondary;

  final bool isExact;

  bool get canToggle => secondary != null;
}

/// Formats an exact rational.
String formatRational(
  Rational value, {
  bool mixed = false,
  bool improper = false,
}) {
  if (value.isInteger) return _displayMinus(value.numerator.toString());
  if (!mixed || improper) return _displayMinus(value.toString());
  final negative = value.isNegative;
  final absolute = value.abs();
  final whole = absolute.numerator ~/ absolute.denominator;
  final remainder = absolute.numerator % absolute.denominator;
  if (whole == BigInt.zero) {
    return '${negative ? '−' : ''}$remainder/${absolute.denominator}';
  }
  return '${negative ? '−' : ''}$whole $remainder/${absolute.denominator}';
}

/// Formats a real number without floating-point artefacts.
String formatReal(
  double value, {
  int? fix,
  int significant = 12,
}) {
  if (value.isNaN || !value.isFinite) return 'Math ERROR';
  if (value == 0) return '0';
  if (fix != null) {
    final text = value.toStringAsFixed(fix.clamp(0, 10));
    return text == '-0' ? '0' : _displayMinus(text);
  }
  final magnitude = value.abs();
  if (magnitude >= 1e12 || magnitude < 1e-9) {
    return formatScientific(value, significant: significant);
  }
  var text = value.toStringAsPrecision(significant.clamp(1, 17));
  if (text.contains('e')) {
    return formatScientific(
      double.parse(text),
      significant: significant,
    );
  }
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : _displayMinus(text);
}

String formatScientific(double value, {int significant = 12}) {
  var text = value.toStringAsExponential(
    (significant - 1).clamp(0, 17),
  );
  // Split mantissa and exponent so trailing zeros are trimmed safely.
  final index = text.indexOf('e');
  var mantissa = text.substring(0, index);
  var exponent = text.substring(index);
  if (mantissa.contains('.')) {
    mantissa = mantissa.replaceFirst(RegExp(r'0+$'), '');
    mantissa = mantissa.replaceFirst(RegExp(r'\.$'), '');
  }
  if (exponent.startsWith('e+')) {
    exponent = 'e${exponent.substring(2)}';
  }
  return '${_displayMinus(mantissa)}$exponent';
}

/// Formats an exact rational in decimal form without going through [double].
///
/// [formatReal] collapses when the value leaves the double range: `1e400`
/// becomes `Math ERROR` and `1e-400` becomes `0`. This walks the numerator and
/// denominator as [BigInt] so the exact value keeps a readable form.
String formatRationalDecimal(Rational value, {int significant = 12}) {
  if (value.isZero) return '0';
  final negative = value.isNegative;
  final numerator = value.numerator.abs();
  final denominator = value.denominator;
  final digits = significant.clamp(1, 17);

  // floor(log10(value)) from the digit lengths, corrected by one comparison.
  var exponent = numerator.toString().length - denominator.toString().length;
  if (_compareScaled(numerator, denominator, exponent) < 0) exponent--;

  // Scale so the mantissa has exactly [digits] digits, then round half-up.
  final shift = digits - 1 - exponent;
  final scaledNumerator = shift >= 0 ? numerator * _tenPow(shift) : numerator;
  final scaledDenominator =
      shift >= 0 ? denominator : denominator * _tenPow(-shift);
  var mantissa = (scaledNumerator * BigInt.two + scaledDenominator) ~/
      (scaledDenominator * BigInt.two);

  var mantissaText = mantissa.toString();
  if (mantissaText.length > digits) {
    // Rounding carried into a new digit: 9.99… became 10.0….
    mantissaText = mantissaText.substring(0, digits);
    exponent++;
  }
  final padded = mantissaText.padRight(digits, '0');
  var text = '${padded[0]}.${padded.substring(1)}';
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  final sign = negative ? '−' : '';
  if (exponent == 0) return '$sign$text';
  return '$sign${text}e$exponent';
}

int _compareScaled(BigInt numerator, BigInt denominator, int exponent) {
  if (exponent >= 0) {
    return numerator.compareTo(denominator * _tenPow(exponent));
  }
  return (numerator * _tenPow(-exponent)).compareTo(denominator);
}

BigInt _tenPow(int exponent) => BigInt.from(10).pow(exponent);

/// The calculator displays a true minus sign, while the lexer accepts it too.
String _displayMinus(String text) =>
    text.startsWith('-') ? '−${text.substring(1)}' : text;

/// Formats an [EvalValue] and exposes both exact and decimal forms.
ValueFormat formatCalcValue(
  EvalValue value, {
  bool preferExact = true,
  bool mixed = false,
  bool polar = false,
  AngleUnit angleUnit = AngleUnit.degrees,
  int? fix,
  int significant = 12,
}) {
  if (!value.isReal) {
    final rectangular = formatComplex(
      value.realPart,
      value.imaginaryPart,
      fix: fix,
      significant: significant,
    );
    if (polar) {
      final magnitude = formatReal(
        value.magnitude,
        fix: fix,
        significant: significant,
      );
      final argument = formatReal(
        _angleFromRadians(value.argument, angleUnit),
        fix: fix,
        significant: significant,
      );
      return ValueFormat(
        display: '$magnitude∠$argument',
        decimal: rectangular,
        secondary: rectangular,
        isExact: false,
      );
    }
    return ValueFormat(
      display: rectangular,
      decimal: rectangular,
      isExact: false,
    );
  }

  final exactValue = value.exact;
  final approximate = exactValue?.toDouble() ?? value.realPart;
  // A double cannot hold the value: `toDouble` gives infinity for huge
  // rationals and 0 for tiny ones, which `formatReal` would print as
  // `Math ERROR` and `0`. Format the exact rational instead.
  final outOfDoubleRange =
      exactValue != null && (!approximate.isFinite || approximate == 0);
  final decimal = outOfDoubleRange
      ? formatRationalDecimal(exactValue, significant: significant)
      : formatReal(approximate, fix: fix, significant: significant);
  if (value.exact != null) {
    final exact = formatRational(value.exact!, mixed: mixed);
    final showExact = preferExact && fix == null;
    return ValueFormat(
      display: showExact ? exact : decimal,
      decimal: decimal,
      exact: exact,
      secondary: showExact && exact != decimal
          ? decimal
          : (fix == null ? exact : null),
      isExact: true,
    );
  }
  return ValueFormat(display: decimal, decimal: decimal, isExact: false);
}

String formatComplex(
  double real,
  double imaginary, {
  int? fix,
  int significant = 12,
}) {
  final realText = formatReal(real, fix: fix, significant: significant);
  final imaginaryText = formatReal(
    imaginary.abs(),
    fix: fix,
    significant: significant,
  );
  if (imaginary == 0) return realText;
  final sign = imaginary < 0 ? '−' : '+';
  final coefficient = imaginary.abs() == 1 ? '' : imaginaryText;
  if (real == 0) {
    return '${imaginary < 0 ? '−' : ''}${coefficient}i';
  }
  return '$realText $sign ${coefficient}i';
}

double _angleFromRadians(double radians, AngleUnit unit) => switch (unit) {
      AngleUnit.degrees => radians * 180 / math.pi,
      AngleUnit.radians => radians,
      AngleUnit.gradians => radians * 200 / math.pi,
    };

/// A very short approximation for chart labels.
String formatGraphLabel(double value) {
  if (!value.isFinite) return '—';
  final magnitude = value.abs();
  if (magnitude >= 10000 || (magnitude > 0 && magnitude < 0.001)) {
    return formatScientific(value, significant: 4);
  }
  var text = value.toStringAsPrecision(5);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : _displayMinus(text);
}
