/// Flutter-free verification of the calculator engine.
///
/// Run with the local Dart SDK:
///
///     dart run tool/verify_calculator_logic.dart
///
/// Exits non-zero when any check fails, so CI gates on the result.
/// Every assertion here is deterministic and offline.
library;

import 'dart:io' show exitCode;
import 'dart:math' as math;

import '../lib/features/calculator/calc_history.dart';
import '../lib/features/calculator/calc_session.dart';
import '../lib/features/calculator/calc_settings.dart';
import '../lib/features/calculator/engine/ast.dart';
import '../lib/features/calculator/engine/base_expression.dart';
import '../lib/features/calculator/engine/base_n.dart';
import '../lib/features/calculator/engine/calculator_error.dart';
import '../lib/features/calculator/engine/cas.dart';
import '../lib/features/calculator/engine/evaluator.dart';
import '../lib/features/calculator/engine/formulas.dart';
import '../lib/features/calculator/engine/graph.dart';
import '../lib/features/calculator/engine/input_editing.dart';
import '../lib/features/calculator/engine/lexer.dart';
import '../lib/features/calculator/engine/linear_systems.dart';
import '../lib/features/calculator/engine/math_value.dart';
import '../lib/features/calculator/engine/matrix.dart';
import '../lib/features/calculator/engine/number_format.dart';
import '../lib/features/calculator/engine/parser.dart';
import '../lib/features/calculator/engine/polynomial.dart';
import '../lib/features/calculator/engine/statistics.dart';
import '../lib/features/calculator/engine/table.dart';
import '../lib/features/calculator/engine/units.dart';
import '../lib/features/calculator/engine/vector.dart';

var _checks = 0;
final _failures = <String>[];

void check(bool condition, String description) {
  _checks++;
  if (!condition) _failures.add(description);
}

void equal(Object? actual, Object? expected, String description) {
  check(
    actual == expected,
    '$description (expected: $expected, actual: $actual)',
  );
}

void close(double actual, double expected, String description,
    {double tolerance = 1e-9}) {
  check(
    (actual - expected).abs() <= tolerance,
    '$description (expected: $expected, actual: $actual)',
  );
}

EvalValue evaluate(
  String source, {
  AngleUnit angle = AngleUnit.degrees,
  Map<String, EvalValue>? variables,
  bool complex = false,
  EvalValue? answer,
}) {
  return Evaluator(
    EvalContext(
      angleUnit: angle,
      variables: variables,
      allowComplex: complex,
      answer: answer,
    ),
  ).evaluate(parseExpression(source));
}

void throwsCalc(
  void Function() body,
  String description, {
  CalcErrorKind? kind,
}) {
  _checks++;
  try {
    body();
    _failures.add('$description (did not throw)');
  } on CalcError catch (error) {
    if (kind != null && error.kind != kind) {
      _failures.add(
        '$description (expected $kind, got ${error.kind}: ${error.detail})',
      );
    }
  } catch (error) {
    _failures.add('$description (wrong exception: $error)');
  }
}

void verifyParserAndEvaluator() {
  equal(evaluate('2 + 3 × 4').displayValue, '14', 'precedence × before +');
  equal(evaluate('(2 + 3) × 4').displayValue, '20', 'parentheses');
  equal(evaluate('2 + 3 * 4').displayValue, '14', 'ASCII operators');
  equal(evaluate('2^3^2').displayValue, '512', 'power is right-associative');
  equal(evaluate('-2^2').displayValue, '−4', 'unary minus below power');
  equal(evaluate('(-2)^2').displayValue, '4', 'parenthesised negative base');
  equal(evaluate('2^-3').displayValue, '1/8', 'negative exponent exact');
  equal(
      evaluate('2π').displayValue, '6.28318530718', 'implicit multiplication');
  equal(evaluate('3(4+1)').displayValue, '15', 'implicit parentheses');
  equal(evaluate('2sin(30)').displayValue, '1', 'implicit function');
  equal(evaluate('(2+1)(2-1)').displayValue, '3', 'adjacent parentheses');
  equal(evaluate('½'.replaceAll('½', '1/2')).displayValue, '1/2', 'fraction');
  equal(evaluate('50%').displayValue, '1/2', 'percent postfix');
  equal(evaluate('200+10%').displayValue, '220', 'Casio add-percent');
  equal(evaluate('200-10%').displayValue, '180', 'Casio subtract-percent');
  equal(evaluate('200×10%').displayValue, '20', 'multiply-percent');
  equal(evaluate('5!').displayValue, '120', 'factorial');
  equal(evaluate('0!').displayValue, '1', 'zero factorial');
  throwsCalc(() => evaluate('(−1)!'), 'negative factorial',
      kind: CalcErrorKind.math);
  throwsCalc(() => evaluate('2.5!'), 'fractional factorial',
      kind: CalcErrorKind.math);
  throwsCalc(() => evaluate('171!'), 'factorial limit',
      kind: CalcErrorKind.math);
  equal(evaluate('2!^3').displayValue, '8', 'postfix before power');
  equal(evaluate('√9').displayValue, '3', 'square root exact');
  equal(evaluate('√(9+7)').displayValue, '4', 'square root parentheses');
  equal(evaluate('∛(−8)').displayValue, '−2', 'cube root negative');
  throwsCalc(() => evaluate('√(−1)'), 'sqrt negative in COMP',
      kind: CalcErrorKind.math);
  equal(evaluate('root(3,27)').displayValue, '3', 'nth root');
  equal(evaluate('2^0.5').displayValue, '1.41421356237', 'irrational power');
  equal(evaluate('1/3').displayValue, '1/3', 'third exact');
  equal(evaluate('0.1+0.2').displayValue, '3/10',
      'no binary float noise (exact)');
  equal(formatCalcValue(evaluate('0.1+0.2'), preferExact: false).display, '0.3',
      'decimal 0.3');
  equal(evaluate('7/2').displayValue, '7/2', 'improper fraction');
  equal(formatCalcValue(evaluate('7/2'), mixed: true).display, '3 1/2',
      'mixed number');
  throwsCalc(() => evaluate('1/0'), 'division by zero',
      kind: CalcErrorKind.math);
  throwsCalc(() => evaluate('(1+2'), 'unclosed parenthesis',
      kind: CalcErrorKind.syntax);
  throwsCalc(() => evaluate(''), 'empty expression', kind: CalcErrorKind.empty);
  throwsCalc(() => evaluate('2+'), 'trailing operator',
      kind: CalcErrorKind.syntax);
  throwsCalc(() => evaluate('sin'), 'missing argument',
      kind: CalcErrorKind.syntax);
  throwsCalc(() => evaluate('foo(2)'), 'unknown function',
      kind: CalcErrorKind.syntax);
  equal(evaluate('|−3|').displayValue, '3', 'absolute bars');
  equal(evaluate('3²').displayValue, '9', 'superscript square');
  equal(evaluate('2³').displayValue, '8', 'superscript cube');
  equal(evaluate('1.2e3').displayValue, '1200', 'scientific literal');
  equal(evaluate('2e').displayValue, '5.43656365692', '2·e not 2e literal');
  equal(evaluate('nCr(5,2)').displayValue, '10', 'combination');
  equal(evaluate('nPr(5,2)').displayValue, '20', 'permutation');
  equal(evaluate('gcd(12,18)').displayValue, '6', 'gcd');
  equal(evaluate('lcm(12,18)').displayValue, '36', 'lcm');
  equal(evaluate('sum(x^2, x, 1, 4)').displayValue, '30', 'summation');
  equal(evaluate('product(x, x, 1, 5)').displayValue, '120', 'product');
  close(evaluate('integral(x^2, x, 0, 3)').realPart, 9, 'definite integral');
  close(evaluate('diff(x^2, x, 3)').realPart, 6, 'numeric derivative');
  equal(evaluate('Ans×2', answer: EvalValue.integer(5)).displayValue, '10',
      'Ans');
  final variables = <String, EvalValue>{'A': EvalValue.integer(3)};
  equal(evaluate('A+1', variables: variables).displayValue, '4', 'variable A');
  equal(evaluate('B+1').displayValue, '1', 'unset variable is zero');
  equal(evaluate('theta').displayValue, '0', 'theta variable defaults to zero');
  equal(
      parseExpression('cos(0)').runtimeType, FunctionExpr, 'AST function node');
}

extension on EvalValue {
  String get displayValue => formatCalcValue(this).display;
}

void verifyAngles() {
  equal(evaluate('sin(30)').displayValue, '1/2', 'sin 30 DEG exact');
  equal(evaluate('cos(60)').displayValue, '1/2', 'cos 60 DEG exact');
  equal(evaluate('tan(45)').displayValue, '1', 'tan 45 DEG exact');
  equal(evaluate('sin(90)').displayValue, '1', 'sin 90 DEG');
  equal(evaluate('sin(180)').displayValue, '0', 'sin 180 DEG');
  equal(evaluate('cos(90)').displayValue, '0', 'cos 90 DEG');
  equal(evaluate('sin(390)').displayValue, '1/2', 'sin 390 DEG');
  throwsCalc(() => evaluate('tan(90)'), 'tan 90 undefined',
      kind: CalcErrorKind.math);
  close(evaluate('sin(pi/2)', angle: AngleUnit.radians).realPart, 1,
      'sin π/2 RAD');
  close(
      evaluate('cos(pi)', angle: AngleUnit.radians).realPart, -1, 'cos π RAD');
  close(evaluate('sin(100)', angle: AngleUnit.gradians).realPart, 1,
      'sin 100 GRA');
  close(evaluate('asin(0.5)').realPart, 30, 'asin 0.5 DEG');
  close(evaluate('acos(0)', angle: AngleUnit.radians).realPart, math.pi / 2,
      'acos 0 RAD');
  close(evaluate('atan(1)').realPart, 45, 'atan 1 DEG');
  throwsCalc(() => evaluate('asin(2)'), 'asin domain',
      kind: CalcErrorKind.math);
  equal(
      evaluate('sin(30°)', angle: AngleUnit.radians).displayValue,
      formatCalcValue(EvalValue.real(math.sin(math.pi / 6))).display,
      'degree mark in RAD mode');
}

void verifyComplex() {
  final product = evaluate('(2+3i)×(1−4i)', complex: true);
  close(product.realPart, 14, 'complex product real');
  close(product.imaginaryPart, -5, 'complex product imaginary');
  throwsCalc(
    () => evaluate('2+3i'),
    'imaginary unit blocked in COMP',
    kind: CalcErrorKind.math,
  );
  final square = evaluate('i^2', complex: true);
  close(square.realPart, -1, 'i² real');
  close(square.imaginaryPart, 0, 'i² imaginary');
  final root = evaluate('sqrt(-1)', complex: true);
  close(root.realPart, 0, 'sqrt(-1) real');
  close(root.imaginaryPart, 1, 'sqrt(-1) imaginary');
  close(evaluate('abs(3+4i)', complex: true).realPart, 5, 'complex modulus');
  close(
      evaluate('arg(1+i)', complex: true).realPart, 45, 'complex argument DEG');
  final polar = formatCalcValue(
    EvalValue.complex(0, 1),
    polar: true,
    angleUnit: AngleUnit.degrees,
  ).display;
  equal(polar, '1∠90', 'polar display');
  close(
      evaluate('exp(i*pi)', complex: true).realPart, -1, 'Euler identity real');
  final quotient = evaluate('(1+i)/(1−i)', complex: true);
  close(quotient.realPart, 0, 'complex division real');
  close(quotient.imaginaryPart, 1, 'complex division imaginary');
}

void verifyFormatting() {
  equal(formatReal(1 / 3), '0.333333333333', 'thirds formatted');
  equal(formatReal(0.1 + 0.2), '0.3', 'float noise removed');
  equal(formatReal(double.infinity), 'Math ERROR', 'infinity display');
  equal(formatReal(12345678901234), '1.23456789012e13', 'scientific large');
  equal(formatReal(0.0000000001), '1e-10', 'scientific small');
  equal(formatReal(1.2345, fix: 2), '1.23', 'FIX');
  equal(formatRational(Rational.fromInt(7, 2), mixed: true), '3 1/2',
      'mixed format');
  equal(formatRational(Rational.fromInt(-7, 2), mixed: true), '−3 1/2',
      'negative mixed');
  equal(formatComplex(2, 0), '2', 'real complex format');
  equal(formatComplex(0, -1), '−i', 'negative imaginary unit');
  equal(formatComplex(0, 1), 'i', 'imaginary unit');
  equal(formatGraphLabel(0.000012345), '1.234e-5', 'graph label');
  equal(formatRationalDecimal(Rational.parse('1e400')), '1e400',
      'huge exact decimal');
  equal(formatRationalDecimal(Rational.parse('-1e400')), '−1e400',
      'negative huge exact decimal');
  equal(formatRationalDecimal(Rational.parse('1e-400')), '1e-400',
      'tiny exact decimal');
  equal(formatRationalDecimal(Rational.fromInt(-3, 2)), '−1.5',
      'in-range exact decimal');
  equal(formatRationalDecimal(Rational.parse('1.2345678901234567e400')),
      '1.23456789012e400', 'huge exact decimal keeps 12 significant digits');
  final huge = EvalValue.exact(Rational.parse('1e400'));
  equal(formatCalcValue(huge).decimal, '1e400', 'huge value decimal form');
  equal(formatCalcValue(huge, preferExact: false).display, '1e400',
      'huge value as a plain decimal');
  equal(formatCalcValue(huge, fix: 2).display, '1e400',
      'FIX does not turn a huge exact value into Math ERROR');
  final tiny = EvalValue.exact(Rational.parse('1e-400'));
  equal(formatCalcValue(tiny, preferExact: false).display, '1e-400',
      'tiny value is not reported as zero');
}

void verifyPolynomials() {
  final quadratic = polynomialRoots(<double>[1, -5, 6]);
  equal(quadratic.roots.length, 2, 'quadratic root count');
  close(quadratic.roots[0].real, 2, 'quadratic root 2');
  close(quadratic.roots[1].real, 3, 'quadratic root 3');
  final complex = polynomialRoots(<double>[1, 0, 1]);
  equal(complex.roots.length, 2, 'complex root count');
  close(complex.roots[0].real, 0, 'complex root real');
  close(complex.roots[0].imaginary, 1, 'complex root imaginary');
  final cubic = polynomialRoots(<double>[1, -6, 11, -6]);
  equal(cubic.roots.length, 3, 'cubic roots');
  final cubicValues = cubic.roots.map((root) => root.real).toList()..sort();
  close(cubicValues[0], 1, 'cubic root 1');
  close(cubicValues[1], 2, 'cubic root 2');
  close(cubicValues[2], 3, 'cubic root 3');
  final repeated = polynomialRoots(<double>[1, -2, 1]);
  equal(repeated.roots.length, 1, 'repeated quadratic root deduplicated');
  close(repeated.roots[0].real, 1, 'repeated root value');
  final quartic = polynomialRoots(<double>[1, 0, -5, 0, 4]);
  equal(quartic.roots.length, 4, 'quartic root count');
  final coefficients = polynomialCoefficients(parseExpression('(x+1)^2'), 'x');
  equal(coefficients?.map((value) => value.toString()).join(','), '1,2,1',
      'polynomial extraction');
  final roots = rationalRoots(
      <Rational>[Rational.one, Rational.fromInt(-5), Rational.fromInt(6)]);
  equal(
      roots.map((root) => root.toString()).join(','), '2,3', 'rational roots');
  equal(
      factorPolynomial(<Rational>[
        Rational.one,
        Rational.fromInt(-5),
        Rational.fromInt(6)
      ], 'x')
          .replaceAll(' ', ''),
      '(x−2)·(x−3)',
      'factor exact');
}

void verifyLinearSystems() {
  final solution = solveLinearSystem(
    <List<double>>[
      <double>[2, 1],
      <double>[1, -1],
    ],
    <double>[5, 1],
  );
  check(solution.hasUniqueSolution, 'system unique solution');
  close(solution.values[0], 2, 'system x');
  close(solution.values[1], 1, 'system y');
  final inconsistent = solveLinearSystem(
    <List<double>>[
      <double>[1, 1],
      <double>[1, 1],
    ],
    <double>[2, 3],
  );
  equal(inconsistent.kind, LinearSolutionKind.none, 'inconsistent system');
  final infinite = solveLinearSystem(
    <List<double>>[
      <double>[1, 1],
      <double>[2, 2],
    ],
    <double>[2, 4],
  );
  equal(infinite.kind, LinearSolutionKind.infinite, 'infinite system');
  final four = solveLinearSystem(
    <List<double>>[
      <double>[1, 0, 0, 0],
      <double>[0, 1, 0, 0],
      <double>[0, 0, 1, 0],
      <double>[0, 0, 0, 1],
    ],
    <double>[1, 2, 3, 4],
  );
  equal(four.values.map((value) => value.round()).join(','), '1,2,3,4',
      '4×4 system');
}

void verifyMatrix() {
  final a = Matrix(<List<double>>[
    <double>[1, 2],
    <double>[3, 4],
  ]);
  close(a.determinant(), -2, '2×2 determinant');
  final inverse = a.inverse();
  close(inverse.values[0][0], -2, 'inverse 00');
  close(inverse.values[0][1], 1, 'inverse 01');
  close(inverse.values[1][0], 1.5, 'inverse 10');
  close(inverse.values[1][1], -0.5, 'inverse 11');
  final product = a * a.inverse();
  close(product.values[0][0], 1, 'A·A⁻¹ identity');
  close(product.values[0][1], 0, 'A·A⁻¹ off-diagonal');
  final singular = Matrix(<List<double>>[
    <double>[1, 2],
    <double>[2, 4],
  ]);
  close(singular.determinant(), 0, 'singular determinant');
  throwsCalc(() => singular.inverse(), 'singular inverse',
      kind: CalcErrorKind.math);
  final three = Matrix(<List<double>>[
    <double>[6, 1, 1],
    <double>[4, -2, 5],
    <double>[2, 8, 7],
  ]);
  close(three.determinant(), -306, '3×3 determinant');
  final identity = Matrix.identity(4);
  close(identity.determinant(), 1, '4×4 identity determinant');
  final diagonal = Matrix(<List<double>>[
    <double>[2, 0],
    <double>[0, 3],
  ]);
  final eigenvalues = diagonal.eigenvalues();
  final values = eigenvalues.roots.map((root) => root.real).toList()..sort();
  close(values[0], 2, 'eigenvalue 2');
  close(values[1], 3, 'eigenvalue 3');
  throwsCalc(
    () => Matrix(<List<double>>[
      <double>[1, 2, 3],
      <double>[4, 5, 6],
    ]).determinant(),
    'non-square determinant',
    kind: CalcErrorKind.dimension,
  );
}

void verifyStatistics() {
  final summary = StatisticsSummary.fromValues(<double>[4, 8, 6, 5, 3]);
  equal(summary.count, 5, 'stats count');
  close(summary.mean, 5.2, 'stats mean');
  close(summary.median, 5, 'stats median');
  close(summary.minimum, 3, 'stats min');
  close(summary.maximum, 8, 'stats max');
  close(summary.range, 5, 'stats range');
  close(summary.varianceSample, 3.7, 'stats sample variance');
  close(summary.sdSample, math.sqrt(3.7), 'stats sample sd');
  final mode = StatisticsSummary.fromValues(<double>[1, 2, 2, 3]);
  equal(mode.modes.map(formatReal).join(','), '2', 'stats mode');
  final regression = linearRegression(<double>[1, 2, 3], <double>[3, 5, 7]);
  close(regression.coefficients[0], 2, 'regression slope');
  close(regression.coefficients[1], 1, 'regression intercept');
  close(regression.correlation, 1, 'regression correlation');
  close(regression.rSquared, 1, 'regression r²');
  equal(regression.equation, 'y = 2x + 1', 'regression equation');
  final quadratic =
      quadraticRegression(<double>[0, 1, 2, 3], <double>[1, 4, 9, 16]);
  close(quadratic.coefficients[0], 1, 'quadratic regression a');
  close(quadratic.coefficients[1], 2, 'quadratic regression b');
  close(quadratic.coefficients[2], 1, 'quadratic regression c');
  throwsCalc(
    () => StatisticsSummary.fromValues(<double>[]),
    'empty stats',
    kind: CalcErrorKind.argument,
  );
}

void verifyBases() {
  equal(parseBase('FF', NumberBase.hexadecimal).toString(), '255', 'hex FF');
  equal(parseBase('1011', NumberBase.binary).toString(), '11', 'binary 1011');
  equal(parseBase('777', NumberBase.octal).toString(), '511', 'octal 777');
  equal(parseBase('-10', NumberBase.decimal).toString(), '-10',
      'negative decimal');
  throwsCalc(
    () => parseBase('2', NumberBase.binary),
    'invalid binary digit',
    kind: CalcErrorKind.syntax,
  );
  equal(
      formatBase(BigInt.from(255), NumberBase.hexadecimal), 'FF', 'format hex');
  equal(
      formatBase(BigInt.from(15), NumberBase.binary), '1111', 'format binary');
  equal(formatBase(BigInt.from(65535), NumberBase.binary),
      '1111 1111 1111 1111', 'grouped binary');
  equal(
    applyBaseOperation(BigInt.from(12), BigInt.from(10), BaseOperation.and)
        .toString(),
    '8',
    'bitwise and',
  );
  equal(
    applyBaseOperation(BigInt.from(12), BigInt.from(10), BaseOperation.or)
        .toString(),
    '14',
    'bitwise or',
  );
  equal(
    applyBaseOperation(BigInt.from(12), BigInt.from(10), BaseOperation.xor)
        .toString(),
    '6',
    'bitwise xor',
  );
  equal(applyBaseOperation(BigInt.from(5), null, BaseOperation.not).toString(),
      '-6', 'bitwise not');
  equal(
    applyBaseOperation(BigInt.from(3), BigInt.from(2), BaseOperation.shiftLeft)
        .toString(),
    '12',
    'shift left',
  );
  throwsCalc(
    () => applyBaseOperation(
        BigInt.from(5), BigInt.from(-3), BaseOperation.shiftLeft),
    'negative shift left',
    kind: CalcErrorKind.argument,
  );
  throwsCalc(
    () => applyBaseOperation(
        BigInt.from(5), BigInt.from(-3), BaseOperation.shiftRight),
    'negative shift right',
    kind: CalcErrorKind.argument,
  );
  throwsCalc(
    () => applyBaseOperation(BigInt.one, BigInt.zero, BaseOperation.divide),
    'base divide by zero',
    kind: CalcErrorKind.math,
  );
  equal(
    evaluateBaseExpression('1+2*3', NumberBase.decimal).toString(),
    '7',
    'base precedence',
  );
  equal(
    evaluateBaseExpression('(1+2)*3', NumberBase.decimal).toString(),
    '9',
    'base parentheses',
  );
  equal(
    evaluateBaseExpression('FF AND 0F', NumberBase.hexadecimal).toString(),
    '15',
    'base hex AND',
  );
  equal(
    evaluateBaseExpression('1010 XOR 0110', NumberBase.binary).toString(),
    '12',
    'base binary XOR',
  );
  equal(
    evaluateBaseExpression('1 << 4', NumberBase.decimal).toString(),
    '16',
    'base shift left expression',
  );
  equal(
    evaluateBaseExpression('~5', NumberBase.decimal).toString(),
    '-6',
    'base unary NOT',
  );
  equal(
    evaluateBaseExpression('A0 + 1', NumberBase.hexadecimal).toString(),
    '161',
    'base hex arithmetic',
  );
  equal(
    evaluateBaseExpression('٢+٣', NumberBase.decimal).toString(),
    '5',
    'base Arabic digits',
  );
  throwsCalc(
    () => evaluateBaseExpression('5/0', NumberBase.decimal),
    'base expression division by zero',
    kind: CalcErrorKind.math,
  );
  throwsCalc(
    () => evaluateBaseExpression('1+', NumberBase.decimal),
    'base incomplete expression',
    kind: CalcErrorKind.syntax,
  );
}

void verifySession() {
  final decimalPreference = CalcSession(
    settings: const CalcSettings(preferExact: false),
  );
  final half = EvalValue.exact(Rational.fromInt(1, 2));
  equal(
    decimalPreference.format(half).display,
    '0.5',
    'session honours decimal preference',
  );
  equal(
    decimalPreference.format(half, forceExact: true).display,
    '1/2',
    'S⇔D can force exact despite decimal preference',
  );
  equal(
    decimalPreference.format(half, forceDecimal: true).display,
    '0.5',
    'S⇔D can force decimal',
  );
  final fixedSession = CalcSession(
    settings: const CalcSettings(fix: 2),
  );
  equal(
    fixedSession.format(half).display,
    '0.50',
    'FIX controls the default decimal display',
  );
  equal(
    fixedSession.format(half, forceExact: true).display,
    '1/2',
    'S⇔D still reaches the exact form under FIX',
  );
  final mixedSession = CalcSession(
    settings: const CalcSettings(mixedFractions: true),
  );
  equal(
    mixedSession.format(EvalValue.exact(Rational.fromInt(7, 3))).display,
    '2 1/3',
    'session mixed fraction preference',
  );
  final rational = EvalValue.exact(Rational.fromInt(-7, 3));
  final restored = CalcSession.decodeValue(CalcSession.encodeValue(rational));
  equal(restored.exact.toString(), '-7/3', 'exact value persistence');
  final complex = EvalValue.complex(2, -3);
  final restoredComplex =
      CalcSession.decodeValue(CalcSession.encodeValue(complex));
  close(restoredComplex.realPart, 2, 'complex value persistence real');
  close(
      restoredComplex.imaginaryPart, -3, 'complex value persistence imaginary');
  equal(
    CalcSession.decodeValue('r:1/0').displayValue,
    '0',
    'zero denominator rejected on restore',
  );
  final session = CalcSession(answer: EvalValue.integer(9));
  equal(
    evaluate('Ans+1', answer: session.answer).displayValue,
    '10',
    'session answer feeds Ans',
  );
  session.memory = EvalValue.integer(4);
  check(session.memoryActive, 'memory indicator active');
  session.record(
    CalcHistoryEntry(
      id: '1',
      expression: '2+2',
      result: '4',
      timestamp: DateTime.utc(2026, 10, 24),
    ),
  );
  check(session.history.length == 1, 'session records history');
  session.clearHistory();
  check(session.history.isEmpty, 'session clears history');
}

void verifyInputEditing() {
  ({String source, int cursor}) sign(String source, [int? cursor]) =>
      toggleSignAt(source, cursor ?? source.length);

  final negated = sign('3');
  equal(negated.source, '−3', 'sign change negates a number');
  equal(negated.cursor, 2, 'sign change keeps caret after the number');
  equal(sign('−3').source, '3', 'sign change removes an attached unary minus');
  equal(sign('2+3').source, '2+−3', 'sign change negates the last operand');
  equal(
    sign('2−3').source,
    '2−−3',
    'sign change does not consume binary subtraction',
  );
  equal(
    sign('2+−').source,
    '2+',
    'sign change removes the unary minus it just inserted',
  );
  equal(sign('−').source, '', 'sign change clears a lone unary minus');
  equal(
    sign('2−').source,
    '2−−',
    'sign change after binary subtraction starts a negative operand',
  );
  equal(
    sign('sin(30').source,
    'sin(−30',
    'sign change negates an argument',
  );
  final empty = sign('');
  equal(empty.source, '−', 'sign change on empty input inserts unary minus');
  equal(empty.cursor, 1, 'sign change caret after inserted minus');
  equal(
    sign('1.5×10^').source,
    '1.5×10^−',
    'sign change after an operator inserts unary minus',
  );
  equal(
    sign('2×(3').source,
    '2×(−3',
    'sign change after an open parenthesis',
  );
  equal(
    sign('1e−3').source,
    '−1e−3',
    'sign change negates a whole scientific-notation literal',
  );
  equal(
    toggleSignAt('12+34', 2).source,
    '−12+34',
    'sign change targets the number before the caret',
  );
  equal(
    toggleSignAt('(2−3)+4', 4).source,
    '(2−−3)+4',
    'sign change leaves later operands untouched',
  );
}

void verifyUnits() {
  final atmosphere = findUnit('atmosphere')!;
  final pascal = findUnit('pascal')!;
  close(convertUnit(1, atmosphere, pascal), 101325, 'atm to Pa');
  final celsius = findUnit('celsius')!;
  final fahrenheit = findUnit('fahrenheit')!;
  final kelvin = findUnit('kelvin')!;
  close(convertUnit(0, celsius, fahrenheit), 32, '0°C to °F');
  close(convertUnit(100, celsius, fahrenheit), 212, '100°C to °F');
  close(convertUnit(0, celsius, kelvin), 273.15, '0°C to K');
  close(convertUnit(32, fahrenheit, celsius), 0, '32°F to °C');
  final mile = findUnit('mile')!;
  final meter = findUnit('meter')!;
  close(convertUnit(1, mile, meter), 1609.344, 'mile to metre');
  final kwh = findUnit('kilowatt_hour')!;
  final joule = findUnit('joule')!;
  close(convertUnit(1, kwh, joule), 3.6e6, 'kWh to J');
  final knot = findUnit('knot')!;
  final mps = findUnit('meter_per_second')!;
  close(convertUnit(1, knot, mps), 0.5144444444444445, 'knot to m/s');
  equal(searchUnits('بار').any((unit) => unit.id == 'bar'), true,
      'Arabic unit search');
  equal(searchUnits('pascal').any((unit) => unit.id == 'pascal'), true,
      'English unit search');
  throwsCalc(
    () => convertUnit(1, atmosphere, meter),
    'cross-category conversion',
    kind: CalcErrorKind.dimension,
  );
}

void verifyFormulas() {
  check(formulaLibrary.length >= 35, 'formula library size');
  final quadratic = formulaById('quadratic_plus')!;
  final root = quadratic.evaluate(<String, double>{'a': 1, 'b': -3, 'c': 2});
  close(root.realPart, 2, 'quadratic formula');
  final gas = formulaById('ideal_gas')!;
  final volume = gas.evaluate(<String, double>{'P': 1, 'n': 1, 'T': 273.15});
  close(volume.realPart, 22.414, 'ideal gas volume', tolerance: 0.01);
  final trig = formulaById('trig_identity')!;
  close(trig.evaluate(<String, double>{'θ': 37}).realPart, 1, 'trig identity');
  equal(searchFormulas('فيثاغورس').any((entry) => entry.id == 'pythagoras'),
      true, 'Arabic formula search');
  equal(searchFormulas('ohm').any((entry) => entry.id == 'ohms_law'), true,
      'English formula search');
  equal(
      searchFormulas('').length, formulaLibrary.length, 'empty formula search');
}

void verifyGraph() {
  final sine = sampleCartesian(
    'sin(x)',
    minX: 0,
    maxX: 2 * math.pi,
    samples: 400,
    angleUnit: AngleUnit.radians,
  );
  check(!sine.isEmpty, 'sine sample non-empty');
  check(sine.segments.length == 1, 'sine is one segment');
  final reciprocal = sampleCartesian(
    '1/x',
    minX: -1,
    maxX: 1,
    samples: 401,
  );
  check(reciprocal.discontinuities >= 1, '1/x discontinuity detected');
  final roots = findRoots('x^2-4', minX: -5, maxX: 5);
  equal(roots.length, 2, 'quadratic roots found');
  close(roots[0], -2, 'graph root -2');
  close(roots[1], 2, 'graph root 2');
  final extrema = findExtrema('x^2', minX: -2, maxX: 2);
  equal(extrema.length, 1, 'one extremum');
  close(extrema.first.point.x, 0, 'minimum x');
  check(extrema.first.isMinimum, 'x² minimum');
  final intersections = findIntersections('x^2', 'x', minX: -2, maxX: 2);
  equal(intersections.length, 2, 'two intersections');
  final tangent = tangentAt('x^2', 2);
  close(tangent.slope, 4, 'tangent slope');
  close(tangent.intercept, -4, 'tangent intercept');
  final implicit = sampleImplicit(
    'x^2+y^2-1',
    minX: -2,
    maxX: 2,
    minY: -2,
    maxY: 2,
    resolution: 40,
  );
  check(implicit.length > 50, 'implicit circle segments');
  final polar = samplePolar(
    '2',
    minAngle: 0,
    maxAngle: 2 * math.pi,
    samples: 300,
    angleUnit: AngleUnit.radians,
  );
  check(!polar.isEmpty, 'polar circle sample');
  final parametric = sampleParametric(
    'cos(t)',
    'sin(t)',
    minT: 0,
    maxT: 2 * math.pi,
    samples: 300,
    angleUnit: AngleUnit.radians,
  );
  check(!parametric.isEmpty, 'parametric circle sample');
}

void verifyTable() {
  final table = buildTable('x^2', start: 1, end: 5, step: 1);
  equal(table.rows.length, 5, 'table row count');
  equal(table.rows.first.formatted, '1', 'table first value');
  equal(table.rows.last.formatted, '25', 'table last value');
  final descending = buildTable('x', start: 3, end: 1, step: -1);
  equal(descending.rows.map((row) => row.x).join(','), '3.0,2.0,1.0',
      'descending table');
  final errors = buildTable('1/x', start: -1, end: 1, step: 1);
  equal(errors.rows[1].formatted, 'Math ERROR', 'table error cell');
  final truncated =
      buildTable('x', start: 0, end: 1000, step: 0.01, maximumRows: 20);
  equal(truncated.rows.length, 20, 'table maximum rows');
  check(truncated.truncated, 'table truncation flag');
  throwsCalc(
    () => buildTable('x', start: 0, end: 1, step: 0),
    'zero table step',
    kind: CalcErrorKind.argument,
  );
}

void verifyCas() {
  const cas = CasEngine();
  equal(cas.differentiate('x^2', 'x').expression, '2x', 'derivative x²');
  equal(
    cas.differentiate('x²+5', 'x').expression,
    '2x',
    'derivative of keypad x² glyph',
  );
  equal(
    cas.differentiate('x³', 'x').expression,
    '3x²',
    'derivative of keypad x³ glyph',
  );
  equal(cas.differentiate('x^3+2x', 'x').expression, '3x² + 2',
      'derivative cubic');
  equal(
      cas.differentiate('sin(x)', 'x').expression, 'cos(x)', 'derivative sin');
  equal(
      cas.differentiate('cos(x)', 'x').expression, '−sin(x)', 'derivative cos');
  equal(cas.differentiate('ln(x)', 'x').expression, '1 / x', 'derivative ln');
  equal(cas.simplify('(x+1)^2'), 'x² + 2x + 1', 'simplify expanded square');
  equal(cas.simplify('2x+3x'), '5x', 'simplify like terms');
  equal(cas.simplify('x*0+3'), '3', 'simplify zero product');
  equal(cas.factor('x^2-5x+6').expression.replaceAll(' ', ''), '(x−2)·(x−3)',
      'CAS factor');
  equal(cas.factor('x^2-1').expression.replaceAll(' ', ''), '(x−1)·(x+1)',
      'CAS factor difference of squares');
  equal(cas.integrate('3x^2', 'x').expression, 'x³ + C', 'CAS integrate');
  throwsCalc(
    () => cas.integrate('sin(x)', 'x'),
    'unsupported symbolic integral',
    kind: CalcErrorKind.unsupported,
  );
  throwsCalc(
    () => cas.factor('sin(x)'),
    'unsupported factor',
    kind: CalcErrorKind.unsupported,
  );
  throwsCalc(
    () => cas.differentiate('x!', 'x'),
    'unsupported factorial derivative',
    kind: CalcErrorKind.unsupported,
  );
}

void verifyVector() {
  final a = VectorValue(<double>[1, 2, 3]);
  final b = VectorValue(<double>[4, 5, 6]);
  close(a.dot(b), 32, 'dot product');
  final cross = a.cross(b);
  equal(cross.components.join(','), '-3.0,6.0,-3.0', 'cross product');
  close(a.norm, math.sqrt(14), 'vector norm');
  close(a.angleBetween(VectorValue(<double>[1, 0, 0])),
      math.acos(1 / math.sqrt(14)) * 180 / math.pi, 'vector angle');
  final projection =
      VectorValue(<double>[3, 4]).projectionOnto(VectorValue(<double>[1, 0]));
  equal(projection.format(), '(3, 0)', 'vector projection');
  throwsCalc(
    () => a.cross(VectorValue(<double>[1, 2])),
    'cross dimension',
    kind: CalcErrorKind.dimension,
  );
  throwsCalc(
    () => VectorValue(<double>[1, 2, 3, 4]),
    'vector dimension limit',
    kind: CalcErrorKind.dimension,
  );
}

void verifyHistoryAndSettings() {
  final now = DateTime.utc(2026, 10, 24);
  final entries = <CalcHistoryEntry>[
    for (var i = 0; i < 250; i++)
      CalcHistoryEntry(
        id: '$i',
        expression: '$i+1',
        result: '${i + 1}',
        timestamp: now.add(Duration(seconds: i)),
      ),
  ];
  final encoded = CalcHistory.encode(entries);
  final decoded = CalcHistory.decode(encoded);
  equal(decoded.length, 200, 'history capped at 200');
  equal(decoded.first.expression, '0+1', 'history order preserved');
  equal(decoded.last.expression, '199+1', 'history oldest kept');
  equal(CalcHistory.decode('not json').length, 0, 'corrupt history ignored');
  equal(
    CalcHistory.decode('[{"expression":"1+1","result":"2","time":"bad"}]')
        .length,
    1,
    'history row with bad time still readable',
  );
  final legacy = CalcHistory.fromLegacy(<String>['2+2\u000120', 'bad']);
  equal(legacy.length, 1, 'legacy migration');
  equal(legacy.first.expression, '2+2', 'legacy expression');
  equal(legacy.first.result, '20', 'legacy result');
  final settings = const CalcSettings(
    angleUnit: AngleUnit.gradians,
    naturalInput: false,
    haptics: false,
    finish: CalcFinish.paper,
    preferExact: false,
    mixedFractions: true,
    polarComplex: true,
    fix: 3,
  );
  final restored = CalcSettings.decode(settings.encode());
  equal(restored.angleUnit, AngleUnit.gradians, 'settings angle roundtrip');
  equal(restored.naturalInput, false, 'settings natural roundtrip');
  equal(restored.haptics, false, 'settings haptics roundtrip');
  equal(restored.finish, CalcFinish.paper, 'settings finish roundtrip');
  equal(restored.fix, 3, 'settings fix roundtrip');
  equal(restored.copyWith(clearFix: true).fix, null, 'settings clear fix');
}

void verifyLexerNormalization() {
  equal(normalizeCalculatorInput('٢+٣'), '2+3', 'Arabic-Indic digits');
  equal(normalizeCalculatorInput('3×4'), '3*4', 'times glyph');
  equal(normalizeCalculatorInput('6÷2'), '6/2', 'divide glyph');
  equal(normalizeCalculatorInput('5−2'), '5-2', 'minus glyph');
  equal(evaluate('٣+٤').displayValue, '7', 'Arabic digits evaluate');
}

void verifyVariables() {
  final variables = <String, EvalValue>{'E': EvalValue.integer(7)};
  equal(evaluate('E+1', variables: variables).displayValue, '8',
      'uppercase E is the session variable');
  equal(evaluate('E', variables: variables).displayValue, '7',
      'uppercase E alone is the session variable');
  equal(evaluate('e').displayValue, '2.71828182846', 'lowercase e is Euler');
  equal(
      evaluate('E', variables: {'E': EvalValue.exact(Rational.fromInt(3, 2))})
          .displayValue,
      '3/2',
      'E keeps an exact value');
}

void verifyVariablePersistence() {
  final variables = <String, EvalValue>{
    'A': EvalValue.integer(7),
    'θ': EvalValue.exact(Rational.fromInt(1, 3)),
    'F': EvalValue.real(2.5),
  };
  final restored =
      CalcSession.decodeVariables(CalcSession.encodeVariables(variables));
  equal(restored.length, 3, 'variables round trip');
  equal(restored['A']?.displayValue, '7', 'integer variable survives');
  equal(restored['θ']?.displayValue, '1/3', 'theta keeps its exact value');
  equal(restored['F']?.displayValue, '2.5', 'decimal variable survives');
  equal(CalcSession.decodeVariables('').length, 0, 'empty payload decodes');
  equal(CalcSession.decodeVariables(null).length, 0, 'missing payload decodes');
}

void verifyAnsRuns() {
  final answer = EvalValue.integer(25);
  final x = <String, EvalValue>{'x': EvalValue.integer(3)};
  check(
    evaluate('Anse', answer: answer).displayValue != '0',
    'Ans followed by e is not a zero product',
  );
  equal(
    evaluate('Anse', answer: answer).displayValue,
    evaluate('Ans*e', answer: answer).displayValue,
    'Anse means Ans times e',
  );
  equal(
    evaluate('Ansx', answer: answer, variables: x).displayValue,
    evaluate('Ans*x', answer: answer, variables: x).displayValue,
    'Ansx means Ans times x',
  );
}

void verifyRationalLimits() {
  check(
    Rational.tryParse('1e100000') == null,
    'a huge positive exponent is rejected',
  );
  check(
    Rational.tryParse('1e-100000') == null,
    'a huge negative exponent is rejected',
  );
  check(
    Rational.tryParse('1e400') != null,
    'a large but bounded exponent still parses',
  );
  check(
    Rational.tryParse('0.${'0' * 10001}1') == null,
    'an absurd number of decimal places is rejected',
  );
}

void verifyNumericalStability() {
  final exposed = evaluate('exp(-30)').displayValue;
  final powered = evaluate('e^(-30)').displayValue;
  equal(exposed, powered, 'exp and the power form agree on tiny results');
  equal(exposed, '9.35762296884e-14', 'exp(-30) keeps its tiny value');
  var reciprocal = '';
  try {
    reciprocal = evaluate('1/exp(-30)').displayValue;
  } on CalcError catch (error) {
    reciprocal = 'ERROR ${error.detail}';
  }
  check(
    !reciprocal.contains('ERROR'),
    'dividing by exp(-30) is not a Math ERROR',
  );
  equal(evaluate('(-1)^0.5', complex: true).displayValue, 'i',
      'a zero real part is snapped in a complex result');
  equal(evaluate('sin(180)').displayValue, '0', 'trig noise stays zero');
}

void verifyRandomness() {
  final session = CalcSession();
  check(
    identical(session.contextFor().random, session.contextFor().random),
    'a session reuses one random source',
  );
  final values = <String>{};
  for (var i = 0; i < 20; i++) {
    values.add(
      Evaluator(session.contextFor())
          .evaluate(parseExpression('rand(1000000)'))
          .displayValue,
    );
  }
  check(values.length > 1, 'rand changes between evaluations');
}

void main() {
  verifyParserAndEvaluator();
  verifyAngles();
  verifyComplex();
  verifyFormatting();
  verifyPolynomials();
  verifyLinearSystems();
  verifyMatrix();
  verifyStatistics();
  verifyBases();
  verifyUnits();
  verifyFormulas();
  verifyGraph();
  verifyTable();
  verifyCas();
  verifyVector();
  verifyHistoryAndSettings();
  verifyLexerNormalization();
  verifyVariables();
  verifyRandomness();
  verifyNumericalStability();
  verifyRationalLimits();
  verifyAnsRuns();
  verifyVariablePersistence();
  verifySession();
  verifyInputEditing();

  if (_failures.isEmpty) {
    print('OK — $_checks checks passed.');
  } else {
    print('FAILED — ${_failures.length} of $_checks checks failed:');
    for (final failure in _failures) {
      print(' • $failure');
    }
    exitCode = 1;
  }
}
