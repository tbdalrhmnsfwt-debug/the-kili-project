/// Evaluator for the calculator AST.
///
/// Exact rational values are preserved for arithmetic, integer powers, roots
/// that are perfect, factorials, permutations/combinations and the common
/// degree-based trigonometric values. Everything else is computed numerically.
/// Complex numbers are enabled by [EvalContext.allowComplex] (CMPLX mode) and
/// are always reported as approximate.
library;

import 'dart:math' as math;

import 'ast.dart';
import 'calculator_error.dart';
import 'function_catalog.dart';
import 'math_value.dart';

enum AngleUnit {
  degrees('DEG'),
  radians('RAD'),
  gradians('GRA');

  const AngleUnit(this.label);

  final String label;

  static AngleUnit fromName(String? name) {
    final lower = (name ?? '').toLowerCase();
    return switch (lower) {
      'rad' || 'radians' || 'radian' => AngleUnit.radians,
      'gra' || 'grad' || 'gradians' || 'gradian' => AngleUnit.gradians,
      _ => AngleUnit.degrees,
    };
  }
}

/// Variables, angle unit and answer used during evaluation.
class EvalContext {
  EvalContext({
    this.angleUnit = AngleUnit.degrees,
    Map<String, EvalValue>? variables,
    EvalValue? answer,
    this.allowComplex = false,
    math.Random? random,
  }) : variables = variables == null
           ? <String, EvalValue>{}
           : Map<String, EvalValue>.of(variables),
       answer = answer ?? EvalValue.integer(0),
       random = random ?? math.Random(0x5eed);

  AngleUnit angleUnit;
  final Map<String, EvalValue> variables;
  EvalValue answer;
  bool allowComplex;
  final math.Random random;

  EvalContext copy() => EvalContext(
    angleUnit: angleUnit,
    variables: variables,
    answer: answer,
    allowComplex: allowComplex,
    random: random,
  );

  double toRadians(double value) => switch (angleUnit) {
    AngleUnit.degrees => value * math.pi / 180,
    AngleUnit.radians => value,
    AngleUnit.gradians => value * math.pi / 200,
  };

  double fromRadians(double value) => switch (angleUnit) {
    AngleUnit.degrees => value * 180 / math.pi,
    AngleUnit.radians => value,
    AngleUnit.gradians => value * 200 / math.pi,
  };
}

class Evaluator {
  Evaluator(this.context);

  final EvalContext context;

  static const int _maxDepth = 200;
  static const int _maxExactExponent = 10000;
  static const int _maxFactorial = 170;

  EvalValue evaluate(Expr expression) => _eval(expression, 0);

  EvalValue _eval(Expr expression, int depth) {
    if (depth > _maxDepth) {
      throw const CalcError(CalcErrorKind.stack);
    }
    try {
      return switch (expression) {
        LiteralExpr() => EvalValue.exact(expression.value),
        VariableExpr() => _variable(expression.name),
        ConstantExpr() => _constant(expression.name),
        UnaryExpr() => _unary(expression, depth),
        BinaryExpr() => _binary(expression, depth),
        PostfixExpr() => _postfix(expression, depth),
        FunctionExpr() => _function(expression, depth),
      };
    } on DivisionByZero {
      throw const CalcError(CalcErrorKind.math, detail: 'القسمة على صفر');
    } on NonFiniteValue {
      throw const CalcError(CalcErrorKind.math, detail: 'النتيجة غير منتهية');
    }
  }

  EvalValue _variable(String name) {
    if (name.toLowerCase() == 'ans') return context.answer;
    final direct = context.variables[name];
    if (direct != null) return direct;
    if (name.length == 1) {
      final upper = name.toUpperCase();
      return context.variables[upper] ??
          context.variables[name.toLowerCase()] ??
          EvalValue.integer(0);
    }
    return EvalValue.integer(0);
  }

  EvalValue _constant(String name) {
    switch (name) {
      case 'pi':
        return EvalValue.real(math.pi);
      case 'e':
        return EvalValue.real(math.e);
      case 'i':
        if (!context.allowComplex) {
          throw const CalcError(
            CalcErrorKind.math,
            detail: 'العدد التخيلي متاح في وضع CMPLX.',
          );
        }
        return EvalValue.complex(0, 1);
    }
    throw CalcError(CalcErrorKind.variable, detail: 'ثابت غير معروف $name');
  }

  EvalValue _unary(UnaryExpr expression, int depth) {
    final value = _eval(expression.operand, depth + 1);
    switch (expression.operator) {
      case '+':
        return value;
      case '-':
        return value.negate();
      case '%':
        return value / EvalValue.integer(100);
    }
    throw const CalcError(CalcErrorKind.syntax);
  }

  EvalValue _binary(BinaryExpr expression, int depth) {
    // Casio-style percentages in addition/subtraction: 200 + 10% = 220.
    if ((expression.operator == '+' || expression.operator == '-') &&
        expression.right is PostfixExpr &&
        (expression.right as PostfixExpr).operator == '%') {
      final left = _eval(expression.left, depth + 1);
      final ratio =
          _eval((expression.right as PostfixExpr).operand, depth + 1) /
          EvalValue.integer(100);
      final adjustment = left * ratio;
      return expression.operator == '+' ? left + adjustment : left - adjustment;
    }

    final left = _eval(expression.left, depth + 1);
    final right = _eval(expression.right, depth + 1);
    switch (expression.operator) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '*':
        return left * right;
      case '/':
        if (right.isZero) {
          throw const CalcError(CalcErrorKind.math, detail: 'القسمة على صفر');
        }
        return left / right;
      case '^':
        return _power(left, right);
    }
    throw const CalcError(CalcErrorKind.syntax);
  }

  EvalValue _postfix(PostfixExpr expression, int depth) {
    final value = _eval(expression.operand, depth + 1);
    switch (expression.operator) {
      case '!':
        return _factorial(value);
      case '%':
        return value / EvalValue.integer(100);
      case '²':
        return value * value;
      case '³':
        return value * value * value;
      case '°':
        // A literal degree mark converts degrees into the current angle unit.
        if (!value.isReal) {
          throw const CalcError(CalcErrorKind.argument);
        }
        return EvalValue.real(
          switch (context.angleUnit) {
            AngleUnit.degrees => value.realPart,
            AngleUnit.radians => value.realPart * math.pi / 180,
            AngleUnit.gradians => value.realPart * 10 / 9,
          },
        );
    }
    throw const CalcError(CalcErrorKind.syntax);
  }

  EvalValue _factorial(EvalValue value) {
    if (!value.isReal || value.exact == null || !value.exact!.isInteger) {
      throw const CalcError(
        CalcErrorKind.math,
        detail: 'المضروب محتاج عدد صحيح غير سالب.',
      );
    }
    final n = value.exact!.numerator;
    if (n.isNegative || n > BigInt.from(_maxFactorial)) {
      throw const CalcError(
        CalcErrorKind.math,
        detail: 'المضروب مسموح من 0 إلى 170.',
      );
    }
    var result = BigInt.one;
    for (var i = 2; i <= n.toInt(); i++) {
      result *= BigInt.from(i);
    }
    return EvalValue.exact(Rational(result));
  }

  EvalValue _power(EvalValue base, EvalValue exponent) {
    if (base.exact != null && exponent.exact != null) {
      final exactExponent = exponent.exact!;
      if (exactExponent.isInteger) {
        final n = exactExponent.toInt();
        if (n != null && n.abs() <= _maxExactExponent) {
          if (n == 0) return EvalValue.integer(1);
          if (base.isZero && n < 0) {
            throw const CalcError(CalcErrorKind.math, detail: 'القسمة على صفر');
          }
          return EvalValue.exact(base.exact!.pow(n));
        }
      } else {
        final p = exactExponent.numerator;
        final q = exactExponent.denominator;
        if (q <= BigInt.from(64) && p.abs() <= BigInt.from(_maxExactExponent)) {
          final root = base.exact!.nthRoot(q.toInt());
          if (root != null) {
            return EvalValue.exact(root.pow(p.toInt()));
          }
        }
      }
    }

    if (!base.isComplex && !exponent.isComplex) {
      if (base.realPart == 0 && exponent.realPart < 0) {
        throw const CalcError(CalcErrorKind.math, detail: 'القسمة على صفر');
      }
      if (base.realPart < 0 && !_isIntegerDouble(exponent.realPart)) {
        if (!context.allowComplex) {
          throw const CalcError(CalcErrorKind.math);
        }
        final result = _complexPow(
          _asComplex(base),
          _asComplex(exponent),
        );
        return result;
      }
      final result = math.pow(base.realPart, exponent.realPart).toDouble();
      if (result.isNaN || !result.isFinite) {
        throw const CalcError(CalcErrorKind.math);
      }
      return EvalValue.real(result);
    }

    if (!context.allowComplex) {
      throw const CalcError(CalcErrorKind.math);
    }
    return _complexPow(_asComplex(base), _asComplex(exponent));
  }

  EvalValue _function(FunctionExpr expression, int depth) {
    final name = expression.name.toLowerCase();

    switch (name) {
      case 'sum':
      case 'product':
        return _sumOrProduct(expression, depth, name == 'sum');
      case 'integral':
        return _integral(expression, depth);
      case 'diff':
        return _numericDerivative(expression, depth);
      case 'rand':
        if (expression.arguments.isEmpty) {
          return EvalValue.real(context.random.nextDouble());
        }
        final limit = _integerArgument(expression.arguments[0], depth, 'rand');
        if (limit <= 0 || limit > 1000000000) {
          throw const CalcError(CalcErrorKind.argument);
        }
        return EvalValue.integer(context.random.nextInt(limit));
    }

    final arguments = <EvalValue>[
      for (final argument in expression.arguments) _eval(argument, depth + 1),
    ];
    validateFunctionArity(name, arguments.length);
    return _apply(name, arguments);
  }

  EvalValue _sumOrProduct(FunctionExpr expression, int depth, bool sum) {
    _validateLazyShape(expression, 'sum/product');
    final variable = expression.arguments[1];
    if (variable is! VariableExpr) {
      throw const CalcError(
        CalcErrorKind.argument,
        detail: 'الوسيط التاني لازم يكون متغير.',
      );
    }
    final start = _integerArgument(expression.arguments[2], depth, 'sum');
    final end = _integerArgument(expression.arguments[3], depth, 'sum');
    if ((end - start).abs() > 10000) {
      throw const CalcError(
        CalcErrorKind.math,
        detail: 'عدد حدود الجمع أكبر من 10001.',
      );
    }
    final previous = context.variables[variable.name];
    var total = EvalValue.integer(sum ? 0 : 1);
    final step = end >= start ? 1 : -1;
    try {
      for (var i = start; step > 0 ? i <= end : i >= end; i += step) {
        context.variables[variable.name] = EvalValue.integer(i);
        final term = _eval(expression.arguments[0], depth + 1);
        total = sum ? total + term : total * term;
      }
    } finally {
      if (previous == null) {
        context.variables.remove(variable.name);
      } else {
        context.variables[variable.name] = previous;
      }
    }
    return total;
  }

  EvalValue _integral(FunctionExpr expression, int depth) {
    _validateLazyShape(expression, 'integral');
    final variable = expression.arguments[1];
    if (variable is! VariableExpr) {
      throw const CalcError(CalcErrorKind.argument);
    }
    final a = _eval(expression.arguments[2], depth + 1);
    final b = _eval(expression.arguments[3], depth + 1);
    if (!a.isReal || !b.isReal) {
      throw const CalcError(CalcErrorKind.argument);
    }
    final body = expression.arguments[0];
    final previous = context.variables[variable.name];
    double f(double x) {
      context.variables[variable.name] = EvalValue.real(x);
      final value = _eval(body, depth + 1);
      if (!value.isReal) throw const CalcError(CalcErrorKind.argument);
      return value.realPart;
    }

    try {
      final value = _adaptiveSimpson(f, a.realPart, b.realPart);
      if (!value.isFinite) throw const CalcError(CalcErrorKind.math);
      return EvalValue.real(value);
    } finally {
      if (previous == null) {
        context.variables.remove(variable.name);
      } else {
        context.variables[variable.name] = previous;
      }
    }
  }

  EvalValue _numericDerivative(FunctionExpr expression, int depth) {
    _validateLazyShape(expression, 'diff');
    final variable = expression.arguments[1];
    if (variable is! VariableExpr) {
      throw const CalcError(CalcErrorKind.argument);
    }
    final at = _eval(expression.arguments[2], depth + 1);
    if (!at.isReal) throw const CalcError(CalcErrorKind.argument);
    final body = expression.arguments[0];
    final previous = context.variables[variable.name];
    double f(double x) {
      context.variables[variable.name] = EvalValue.real(x);
      final value = _eval(body, depth + 1);
      if (!value.isReal) throw const CalcError(CalcErrorKind.argument);
      return value.realPart;
    }

    try {
      final x = at.realPart;
      final h = math.max(1e-7, x.abs() * 1e-7);
      final slope = (f(x + h) - f(x - h)) / (2 * h);
      if (!slope.isFinite) throw const CalcError(CalcErrorKind.math);
      return EvalValue.real(_stabilize(slope));
    } finally {
      if (previous == null) {
        context.variables.remove(variable.name);
      } else {
        context.variables[variable.name] = previous;
      }
    }
  }

  void _validateLazyShape(FunctionExpr expression, String name) {
    validateFunctionArity(name, expression.arguments.length);
    if (expression.arguments.length != 4 &&
        (name == 'sum' || name == 'product' || name == 'integral')) {
      throw CalcError(
        CalcErrorKind.argument,
        detail: '$name(التعبير, المتغير, البداية, النهاية)',
      );
    }
  }

  int _integerArgument(Expr expression, int depth, String function) {
    final value = _eval(expression, depth + 1);
    if (!value.isReal || value.exact == null || !value.exact!.isInteger) {
      throw CalcError(
        CalcErrorKind.argument,
        detail: '$function محتاج حدود صحيحة.',
      );
    }
    final integer = value.exact!.toInt();
    if (integer == null) {
      throw const CalcError(CalcErrorKind.argument);
    }
    return integer;
  }

  EvalValue _apply(String name, List<EvalValue> arguments) {
    final first = arguments.first;
    switch (name) {
      case 'sin':
        return _trig(name, first);
      case 'cos':
        return _trig(name, first);
      case 'tan':
        return _trig(name, first);
      case 'asin':
      case 'arcsin':
        return _inverseTrig(name, first, (x) => math.asin(x), 'asin');
      case 'acos':
      case 'arccos':
        return _inverseTrig(name, first, (x) => math.acos(x), 'acos');
      case 'atan':
      case 'arctan':
        return _inverseTrig(name, first, (x) => math.atan(x), 'atan');
      case 'sinh':
        return _realFunction(first, _sinh, 'sinh');
      case 'cosh':
        return _realFunction(first, _cosh, 'cosh');
      case 'tanh':
        return _realFunction(first, _tanh, 'tanh');
      case 'asinh':
        return _realFunction(first, _asinh, 'asinh');
      case 'acosh':
        return _realFunction(first, _acosh, 'acosh');
      case 'atanh':
        return _realFunction(first, _atanh, 'atanh');
      case 'exp':
        if (first.isComplex) {
          return _complexExp(first);
        }
        return _realFunction(first, math.exp, 'exp');
      case 'ln':
        if (first.isComplex) return _complexLog(first);
        if (first.realPart <= 0) {
          if (context.allowComplex) return _complexLog(first);
          throw const CalcError(CalcErrorKind.math);
        }
        return _realFunction(first, math.log, 'ln');
      case 'log':
        final base = arguments.length > 1 ? arguments[1] : EvalValue.integer(10);
        if (arguments.length > 1) {
          if (!base.isReal || base.realPart <= 0 || base.realPart == 1) {
            throw const CalcError(CalcErrorKind.math);
          }
        }
        if (first.isComplex) {
          return _complexLog(first) /
              (arguments.length > 1
                  ? _complexLog(base)
                  : EvalValue.real(math.log(10)));
        }
        if (first.realPart <= 0) {
          if (context.allowComplex) {
            return _complexLog(first) /
                (arguments.length > 1
                    ? _complexLog(base)
                    : EvalValue.real(math.log(10)));
          }
          throw const CalcError(CalcErrorKind.math);
        }
        final value = arguments.length > 1
            ? math.log(first.realPart) / math.log(base.realPart)
            : math.log(first.realPart) / math.ln10;
        return EvalValue.real(_stabilize(value));
      case 'sqrt':
        return _sqrt(first);
      case 'cbrt':
        return _nthRootValue(first, 3);
      case 'root':
        final index = _requireInteger(arguments[0], 'root');
        if (index < 2 || index > 64) {
          throw const CalcError(CalcErrorKind.argument);
        }
        return _nthRootValue(arguments[1], index);
      case 'abs':
        if (first.exact != null) return EvalValue.exact(first.exact!.abs());
        if (first.isComplex) return EvalValue.real(first.magnitude);
        return EvalValue.real(first.realPart.abs());
      case 'sign':
        if (first.isComplex) {
          throw const CalcError(CalcErrorKind.argument);
        }
        return EvalValue.integer(first.realPart.sign.toInt());
      case 'floor':
        return _rounding(first, 'floor');
      case 'ceil':
        return _rounding(first, 'ceil');
      case 'round':
        return _rounding(first, 'round');
      case 'arg':
        return EvalValue.real(context.fromRadians(first.argument));
      case 'conj':
        return first.conjugate;
      case 're':
        return first.isComplex
            ? EvalValue.real(first.realPart)
            : first;
      case 'im':
        return EvalValue.real(first.imaginaryPart);
      case 'gcd':
        return _gcdOrLcm(arguments, true);
      case 'lcm':
        return _gcdOrLcm(arguments, false);
      case 'ncr':
        return _combinations(arguments, false);
      case 'npr':
        return _combinations(arguments, true);
      case 'min':
        return _minMax(arguments, true);
      case 'max':
        return _minMax(arguments, false);
      case 'hypot':
        final a = _requireReal(arguments[0], 'hypot');
        final b = _requireReal(arguments[1], 'hypot');
        return EvalValue.real(math.sqrt(a * a + b * b));
    }
    throw const CalcError(CalcErrorKind.unsupported);
  }

  EvalValue _trig(String name, EvalValue value) {
    if (value.isComplex) {
      if (!context.allowComplex) throw const CalcError(CalcErrorKind.math);
      return _complexTrig(name, value);
    }
    final exact = _exactDegreeTrig(name, value.exact);
    if (exact != null) return exact;

    final radians = context.toRadians(value.realPart);
    final result = switch (name) {
      'sin' => math.sin(radians),
      'cos' => math.cos(radians),
      _ => math.tan(radians),
    };
    if (!result.isFinite) throw const CalcError(CalcErrorKind.math);
    if (name == 'tan' && (math.cos(radians)).abs() < 1e-12) {
      throw const CalcError(CalcErrorKind.math);
    }
    return EvalValue.real(_stabilize(result));
  }

  EvalValue? _exactDegreeTrig(String name, Rational? degrees) {
    if (degrees == null || context.angleUnit != AngleUnit.degrees) return null;
    var normalized = degrees;
    final turns = (normalized / Rational.fromInt(360)).floor;
    normalized =
        normalized - Rational(turns, BigInt.one) * Rational.fromInt(360);
    if (normalized.isNegative) normalized += Rational.fromInt(360);

    Rational? result;
    if (name == 'sin') {
      result = _lookup(normalized, {
        0: Rational.zero,
        30: _half,
        90: Rational.one,
        150: _half,
        180: Rational.zero,
        210: _negativeHalf,
        270: Rational.fromInt(-1),
        330: _negativeHalf,
      });
    } else if (name == 'cos') {
      result = _lookup(normalized, {
        0: Rational.one,
        60: _half,
        90: Rational.zero,
        120: _negativeHalf,
        180: Rational.fromInt(-1),
        240: _negativeHalf,
        270: Rational.zero,
        300: _half,
      });
    } else {
      result = _lookup(normalized, {
        0: Rational.zero,
        45: Rational.one,
        135: Rational.fromInt(-1),
        180: Rational.zero,
        225: Rational.one,
        315: Rational.fromInt(-1),
      });
      if (result == null && (normalized == Rational.fromInt(90) ||
          normalized == Rational.fromInt(270))) {
        throw const CalcError(CalcErrorKind.math, detail: 'tan غير معرّف.');
      }
    }
    return result == null ? null : EvalValue.exact(result);
  }

  Rational? _lookup(Rational key, Map<int, Rational> table) {
    if (!key.isInteger) return null;
    final integer = key.toInt();
    return integer == null ? null : table[integer];
  }

  EvalValue _inverseTrig(
    String name,
    EvalValue value,
    double Function(double) function,
    String label,
  ) {
    if (value.isComplex) throw const CalcError(CalcErrorKind.math);
    final argument = value.realPart;
    if ((label == 'asin' || label == 'acos') && (argument < -1 || argument > 1)) {
      throw const CalcError(CalcErrorKind.math);
    }
    if (label == 'atanh' && (argument <= -1 || argument >= 1)) {
      throw const CalcError(CalcErrorKind.math);
    }
    final result = context.fromRadians(function(argument));
    return EvalValue.real(_stabilize(result));
  }

  EvalValue _realFunction(
    EvalValue value,
    double Function(double) function,
    String label,
  ) {
    if (!value.isReal) throw const CalcError(CalcErrorKind.math);
    final result = function(value.realPart);
    if (result.isNaN || !result.isFinite) {
      throw CalcError(CalcErrorKind.math, detail: '$label خارج النطاق.');
    }
    return EvalValue.real(_stabilize(result));
  }

  EvalValue _sqrt(EvalValue value) {
    if (value.exact != null) {
      if (value.exact!.isNegative) {
        if (!context.allowComplex) {
          throw const CalcError(CalcErrorKind.math);
        }
        final magnitude = math.sqrt(-value.exact!.toDouble());
        return EvalValue.complex(0, magnitude);
      }
      final exact = value.exact!.nthRoot(2);
      if (exact != null) return EvalValue.exact(exact);
    }
    if (value.isComplex) {
      if (!context.allowComplex) throw const CalcError(CalcErrorKind.math);
      final a = value.realPart;
      final b = value.imaginaryPart;
      final magnitude = math.sqrt(a * a + b * b);
      final real = math.sqrt(math.max(0, (magnitude + a) / 2));
      final imaginary =
          (b < 0 ? -1.0 : 1.0) *
          math.sqrt(math.max(0, (magnitude - a) / 2));
      return EvalValue.complex(real, imaginary);
    }
    if (value.realPart < 0) {
      if (!context.allowComplex) {
        throw const CalcError(CalcErrorKind.math);
      }
      return EvalValue.complex(0, math.sqrt(-value.realPart));
    }
    return EvalValue.real(math.sqrt(value.realPart));
  }

  EvalValue _nthRootValue(EvalValue value, int index) {
    if (value.exact != null) {
      final exact = value.exact!.nthRoot(index);
      if (exact != null) return EvalValue.exact(exact);
      if (value.exact!.isNegative && index.isEven && !context.allowComplex) {
        throw const CalcError(CalcErrorKind.math);
      }
    }
    if (value.isComplex) {
      final angle = value.argument / index;
      final radius = math.pow(value.magnitude, 1 / index).toDouble();
      return EvalValue.complex(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
    }
    final real = value.realPart;
    if (real < 0) {
      if (index.isEven) {
        if (!context.allowComplex) {
          throw const CalcError(CalcErrorKind.math);
        }
        final imaginary = math.pow(-real, 1 / index).toDouble();
        return EvalValue.complex(0, imaginary);
      }
      return EvalValue.real(
        -math.pow(-real, 1 / index).toDouble(),
      );
    }
    return EvalValue.real(math.pow(real, 1 / index).toDouble());
  }

  EvalValue _rounding(EvalValue value, String operation) {
    if (!value.isReal) throw const CalcError(CalcErrorKind.argument);
    if (value.exact != null) {
      final exact = value.exact!;
      final Rational rounded;
      switch (operation) {
        case 'floor':
          rounded = Rational(exact.floor, BigInt.one);
        case 'ceil':
          rounded = Rational(-((-exact).floor), BigInt.one);
        default:
          rounded = exact.isNegative
              ? Rational(-((-exact + _half).floor), BigInt.one)
              : Rational((exact + _half).floor, BigInt.one);
      }
      return EvalValue.exact(rounded);
    }
    final real = switch (operation) {
      'floor' => value.realPart.floorToDouble(),
      'ceil' => value.realPart.ceilToDouble(),
      _ => value.realPart.roundToDouble(),
    };
    return EvalValue.real(real);
  }

  EvalValue _gcdOrLcm(List<EvalValue> arguments, bool gcd) {
    var a = _requireInteger(arguments[0], gcd ? 'gcd' : 'lcm').abs();
    final b = _requireInteger(arguments[1], gcd ? 'gcd' : 'lcm').abs();
    if (gcd) {
      final result = a.gcd(b);
      return EvalValue.exact(Rational.fromInt(result));
    }
    if (a == 0 || b == 0) return EvalValue.integer(0);
    final result = a ~/ a.gcd(b) * b;
    return EvalValue.exact(Rational.fromInt(result));
  }

  EvalValue _combinations(List<EvalValue> arguments, bool permutation) {
    final n = _requireInteger(arguments[0], permutation ? 'nPr' : 'nCr');
    final r = _requireInteger(arguments[1], permutation ? 'nPr' : 'nCr');
    if (n < 0 || r < 0 || r > n || n > 100000) {
      throw const CalcError(CalcErrorKind.math);
    }
    var result = BigInt.one;
    for (var i = 0; i < r; i++) {
      result *= BigInt.from(n - i);
      if (!permutation) result ~/= BigInt.from(i + 1);
    }
    return EvalValue.exact(Rational(result));
  }

  EvalValue _minMax(List<EvalValue> arguments, bool minimum) {
    var best = _requireReal(arguments.first, minimum ? 'min' : 'max');
    for (final argument in arguments.skip(1)) {
      final value = _requireReal(argument, minimum ? 'min' : 'max');
      if (minimum ? value < best : value > best) best = value;
    }
    final exacts = arguments.every((element) => element.exact != null);
    if (exacts) {
      Rational? bestExact;
      for (final argument in arguments) {
        final candidate = argument.exact!;
        if (bestExact == null ||
            (minimum
                ? candidate.compareTo(bestExact) < 0
                : candidate.compareTo(bestExact) > 0)) {
          bestExact = candidate;
        }
      }
      if (bestExact != null) return EvalValue.exact(bestExact);
    }
    return EvalValue.real(best);
  }

  double _requireReal(EvalValue value, String label) {
    if (!value.isReal) {
      throw CalcError(CalcErrorKind.argument, detail: '$label تحتاج أعداد حقيقية.');
    }
    return value.realPart;
  }

  int _requireInteger(EvalValue value, String label) {
    if (!value.isReal || value.exact == null || !value.exact!.isInteger) {
      throw CalcError(CalcErrorKind.argument, detail: '$label تحتاج أعداد صحيحة.');
    }
    final integer = value.exact!.toInt();
    if (integer == null) {
      throw CalcError(CalcErrorKind.math, detail: '$label: العدد كبير جدًا.');
    }
    return integer;
  }

  EvalValue _complexPow(EvalValue base, EvalValue exponent) {
    if (base.isZero && exponent.realPart > 0) {
      return EvalValue.integer(0);
    }
    final log = _complexLog(base);
    final product = log * exponent;
    return _complexExp(product);
  }

  EvalValue _complexExp(EvalValue value) {
    final radius = math.exp(value.realPart);
    return EvalValue.complex(
      radius * math.cos(value.imaginaryPart),
      radius * math.sin(value.imaginaryPart),
    );
  }

  EvalValue _complexLog(EvalValue value) {
    if (value.isZero) throw const CalcError(CalcErrorKind.math);
    return EvalValue.complex(
      math.log(value.magnitude),
      value.argument,
    );
  }

  EvalValue _complexTrig(String name, EvalValue value) {
    final a = value.realPart;
    final b = value.imaginaryPart;
    switch (name) {
      case 'sin':
        return EvalValue.complex(
          math.sin(a) * _cosh(b),
          math.cos(a) * _sinh(b),
        );
      case 'cos':
        return EvalValue.complex(
          math.cos(a) * _cosh(b),
          -math.sin(a) * _sinh(b),
        );
      case 'tan':
        final sine = _complexTrig('sin', value);
        final cosine = _complexTrig('cos', value);
        return sine / cosine;
    }
    throw const CalcError(CalcErrorKind.unsupported);
  }

  EvalValue _asComplex(EvalValue value) => EvalValue.complex(
    value.realPart,
    value.imaginaryPart,
  );

  static double _sinh(double value) =>
      (math.exp(value) - math.exp(-value)) / 2;

  static double _cosh(double value) =>
      (math.exp(value) + math.exp(-value)) / 2;

  static double _tanh(double value) {
    final positive = math.exp(value);
    final negative = math.exp(-value);
    return (positive - negative) / (positive + negative);
  }

  static bool _isIntegerDouble(double value) =>
      value.isFinite && value == value.roundToDouble();

  static double _asinh(double value) =>
      math.log(value + math.sqrt(value * value + 1));

  static double _acosh(double value) =>
      math.log(value + math.sqrt(value * value - 1));

  static double _atanh(double value) =>
      0.5 * math.log((1 + value) / (1 - value));

  /// Removes floating noise such as sin(30) = 0.49999999999999994.
  static double _stabilize(double value) {
    if (value.abs() < 1e-13) return 0;
    final roundedInteger = value.roundToDouble();
    if ((value - roundedInteger).abs() < 1e-13) return roundedInteger;
    if (value.abs() < 1e13) {
      return double.parse(value.toStringAsPrecision(13));
    }
    return value;
  }

  static double _adaptiveSimpson(
    double Function(double) function,
    double a,
    double b,
  ) {
    if (a == b) return 0;
    final sign = b < a ? -1.0 : 1.0;
    final lower = math.min(a, b);
    final upper = math.max(a, b);
    double simpson(double left, double right, double fa, double fm, double fb) =>
        (right - left) * (fa + 4 * fm + fb) / 6;

    double recurse(
      double left,
      double right,
      double fa,
      double fm,
      double fb,
      double whole,
      int depth,
    ) {
      final middle = (left + right) / 2;
      final leftMiddle = (left + middle) / 2;
      final rightMiddle = (middle + right) / 2;
      final flm = function(leftMiddle);
      final frm = function(rightMiddle);
      final leftPart = simpson(left, middle, fa, flm, fm);
      final rightPart = simpson(middle, right, fm, frm, fb);
      final delta = leftPart + rightPart - whole;
      if (depth <= 0 || delta.abs() < 1e-12 * math.max(1, whole.abs())) {
        return leftPart + rightPart + delta / 15;
      }
      return recurse(left, middle, fa, flm, fm, leftPart, depth - 1) +
          recurse(middle, right, fm, frm, fb, rightPart, depth - 1);
    }

    final fa = function(lower);
    final fb = function(upper);
    final middle = (lower + upper) / 2;
    final fm = function(middle);
    final whole = simpson(lower, upper, fa, fm, fb);
    return sign * recurse(lower, upper, fa, fm, fb, whole, 18);
  }
}

final Rational _half = Rational.fromInt(1, 2);
final Rational _negativeHalf = Rational.fromInt(-1, 2);
