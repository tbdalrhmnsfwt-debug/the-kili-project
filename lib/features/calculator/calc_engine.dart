/// The expression engine behind the scientific calculator.
///
/// It is a small recursive-descent parser, so the calculator works completely
/// offline and without any third-party evaluation package. Supported syntax:
///
///   * numbers, including `1.5` and `1.2e-3`
///   * `+ − × ÷ ^`, parentheses, unary signs and implicit multiplication
///   * `!` (factorial), `%` (percent), `√`, `∛`
///   * `sin cos tan asin acos atan log ln sqrt cbrt abs exp floor ceil round`
///   * constants `π`/`pi` and `e`, the previous answer `Ans`, and variables
///     `A`–`F`, `X`, `Y` (missing variables read as zero)
///
/// Trigonometry follows the calculator's DEG/RAD mode. Domain errors and
/// malformed input throw [CalcException] with the label shown on the LCD
/// (`Syntax ERROR` or `Math ERROR`).
library;

import 'dart:math' as math;

/// A calculator input or domain error.
class CalcException implements Exception {
  const CalcException(this.message);

  /// `Syntax ERROR` or `Math ERROR`.
  final String message;

  @override
  String toString() => message;
}

/// Evaluates calculator expressions.
class CalcEngine {
  CalcEngine({
    this.radians = false,
    Map<String, double>? variables,
    this.answer = 0,
  }) : variables = variables ?? const <String, double>{};

  /// Whether trigonometric arguments and results are in radians.
  final bool radians;

  /// Values for `A`–`F`, `X` and `Y`.
  final Map<String, double> variables;

  /// The value substituted for `Ans`.
  final double answer;

  /// Evaluates [source] or throws [CalcException].
  double evaluate(String source) {
    final text = source.trim();
    if (text.isEmpty) throw const CalcException('Syntax ERROR');
    final value = _Parser(text, this).parse();
    if (value.isNaN || !value.isFinite) {
      throw const CalcException('Math ERROR');
    }
    return value;
  }

  /// Resolves a constant or variable name.
  double variable(String name) {
    final key = name.toUpperCase();
    if (key == 'ANS') return answer;
    if (key == 'PI' || name == 'π') return math.pi;
    if (key == 'E') return math.e;
    return variables[key] ?? 0;
  }

  /// Converts a value from the current angle unit into radians.
  double toRadians(double value) =>
      radians ? value : value * math.pi / 180.0;

  /// Converts a radian value into the current angle unit.
  double fromRadians(double value) =>
      radians ? value : value * 180.0 / math.pi;
}

class _Parser {
  _Parser(this.source, this.engine);

  final String source;
  final CalcEngine engine;
  int _index = 0;

  double parse() {
    final value = _expression();
    _skipSpaces();
    if (_index != source.length) throw const CalcException('Syntax ERROR');
    return value;
  }

  double _expression() {
    var value = _term();
    while (true) {
      _skipSpaces();
      if (_match('+')) {
        value += _term();
      } else if (_match('−') || _match('-')) {
        value -= _term();
      } else {
        return value;
      }
    }
  }

  double _term() {
    var value = _unary();
    while (true) {
      _skipSpaces();
      if (_match('×') || _match('*')) {
        value *= _unary();
      } else if (_match('÷') || _match('/')) {
        final divisor = _unary();
        if (divisor == 0) throw const CalcException('Math ERROR');
        value /= divisor;
      } else if (_startsValue()) {
        // Implicit multiplication: 2π, 3(4+1), 2sin(30).
        value *= _unary();
      } else {
        return value;
      }
    }
  }

  double _unary() {
    _skipSpaces();
    if (_match('+')) return _unary();
    if (_match('−') || _match('-')) return -_unary();
    return _power();
  }

  double _power() {
    final base = _postfix();
    _skipSpaces();
    if (_match('^')) {
      final exponent = _unary();
      final result = math.pow(base, exponent).toDouble();
      if (result.isNaN || !result.isFinite) {
        throw const CalcException('Math ERROR');
      }
      return result;
    }
    return base;
  }

  double _postfix() {
    var value = _primary();
    while (true) {
      _skipSpaces();
      if (_match('!')) {
        value = _factorial(value);
      } else if (_match('%')) {
        value /= 100;
      } else if (_match('²')) {
        value *= value;
      } else if (_match('³')) {
        value = value * value * value;
      } else {
        return value;
      }
    }
  }

  double _primary() {
    _skipSpaces();
    if (_match('(')) {
      final value = _expression();
      _skipSpaces();
      if (!_match(')')) throw const CalcException('Syntax ERROR');
      return value;
    }
    if (_match('√')) {
      final value = _primary();
      if (value < 0) throw const CalcException('Math ERROR');
      return math.sqrt(value);
    }
    if (_match('∛')) return _cbrt(_primary());
    if (_match('π')) return math.pi;

    if (_index >= source.length) throw const CalcException('Syntax ERROR');
    final char = source[_index];
    final code = char.codeUnitAt(0);
    if ((code >= 0x30 && code <= 0x39) || char == '.') return _number();
    if (_isLetter(char)) return _name();

    throw const CalcException('Syntax ERROR');
  }

  double _number() {
    final start = _index;
    var seenDot = false;
    while (_index < source.length) {
      final char = source[_index];
      if (char == '.') {
        if (seenDot) break;
        seenDot = true;
        _index++;
        continue;
      }
      final code = char.codeUnitAt(0);
      if (code < 0x30 || code > 0x39) break;
      _index++;
    }

    // Scientific notation: 1e3, 2.5E-4. A bare `e` is Euler's number, so the
    // exponent is only consumed when it starts with a digit or a sign.
    if (_index < source.length &&
        (source[_index] == 'e' || source[_index] == 'E')) {
      final mark = _index;
      var probe = _index + 1;
      if (probe < source.length &&
          (source[probe] == '+' || source[probe] == '-')) {
        probe++;
      }
      final digitsStart = probe;
      while (probe < source.length && _isDigit(source[probe])) {
        probe++;
      }
      if (probe > digitsStart) _index = probe; else _index = mark;
    }

    if (start == _index) throw const CalcException('Syntax ERROR');
    final value = double.tryParse(source.substring(start, _index));
    if (value == null) throw const CalcException('Syntax ERROR');
    return value;
  }

  double _name() {
    final start = _index;
    while (_index < source.length && _isLetter(source[_index])) {
      _index++;
    }
    final name = source.substring(start, _index);
    final lower = name.toLowerCase();

    if (lower == 'ans') return engine.answer;
    if (lower == 'pi') return math.pi;
    if (lower == 'e') return math.e;

    if (_isFunction(lower)) {
      _skipSpaces();
      final double argument;
      if (_match('(')) {
        argument = _expression();
        _skipSpaces();
        if (!_match(')')) throw const CalcException('Syntax ERROR');
      } else {
        argument = _primary();
      }
      return _apply(lower, argument);
    }

    if (name.length == 1) {
      // Single letters are variables; A–F, X and Y are exposed in the UI.
      return engine.variable(name);
    }
    throw const CalcException('Syntax ERROR');
  }

  double _apply(String name, double value) {
    switch (name) {
      case 'sin':
        return math.sin(engine.toRadians(value));
      case 'cos':
        return math.cos(engine.toRadians(value));
      case 'tan':
        final radians = engine.toRadians(value);
        if (math.cos(radians).abs() < 1e-12) {
          throw const CalcException('Math ERROR');
        }
        return math.tan(radians);
      case 'asin':
        if (value < -1 || value > 1) throw const CalcException('Math ERROR');
        return engine.fromRadians(math.asin(value));
      case 'acos':
        if (value < -1 || value > 1) throw const CalcException('Math ERROR');
        return engine.fromRadians(math.acos(value));
      case 'atan':
        return engine.fromRadians(math.atan(value));
      case 'log':
        if (value <= 0) throw const CalcException('Math ERROR');
        return math.log(value) / math.ln10;
      case 'ln':
        if (value <= 0) throw const CalcException('Math ERROR');
        return math.log(value);
      case 'sqrt':
        if (value < 0) throw const CalcException('Math ERROR');
        return math.sqrt(value);
      case 'cbrt':
        return _cbrt(value);
      case 'abs':
        return value.abs();
      case 'exp':
        return math.exp(value);
      case 'floor':
        return value.floorToDouble();
      case 'ceil':
        return value.ceilToDouble();
      case 'round':
        return value.roundToDouble();
    }
    throw const CalcException('Syntax ERROR');
  }

  bool _isFunction(String name) => const {
    'sin',
    'cos',
    'tan',
    'asin',
    'acos',
    'atan',
    'log',
    'ln',
    'sqrt',
    'cbrt',
    'abs',
    'exp',
    'floor',
    'ceil',
    'round',
  }.contains(name);

  bool _startsValue() {
    _skipSpaces();
    if (_index >= source.length) return false;
    final char = source[_index];
    if (char == '(' || char == '√' || char == '∛' || char == 'π') return true;
    if (char == '.') return true;
    if (_isDigit(char) || _isLetter(char)) return true;
    return false;
  }

  bool _match(String char) {
    if (_index < source.length && source[_index] == char) {
      _index++;
      return true;
    }
    return false;
  }

  void _skipSpaces() {
    while (_index < source.length && source[_index] == ' ') {
      _index++;
    }
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isLetter(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  }

  static double _cbrt(double value) =>
      value < 0 ? -math.pow(-value, 1 / 3).toDouble() : math.pow(value, 1 / 3).toDouble();

  static double _factorial(double value) {
    if (value < 0 || value != value.roundToDouble() || value > 170) {
      throw const CalcException('Math ERROR');
    }
    var result = 1.0;
    for (var i = 2; i <= value.round(); i++) {
      result *= i;
    }
    return result;
  }
}

/// Formats a result for the LCD.
///
/// [fix] switches to fixed decimals (FIX mode); [asFraction] asks for a
/// rational approximation when one is exact enough. Otherwise the value is
/// shown with up to ten decimal places, using scientific notation only for
/// very large or very small magnitudes.
String formatCalc(double value, {int? fix, bool asFraction = false}) {
  if (value.isNaN || !value.isFinite) return 'Math ERROR';
  if (asFraction) {
    final fraction = _asFraction(value);
    if (fraction != null) return fraction;
  }
  if (fix != null) {
    final text = value.toStringAsFixed(fix.clamp(0, 10));
    return text == '-0' ? '0' : text;
  }

  final magnitude = value.abs();
  if (magnitude != 0 && (magnitude >= 1e12 || magnitude < 1e-9)) {
    var text = value.toStringAsExponential(8);
    text = text.replaceFirst(RegExp(r'0+e'), 'e');
    text = text.replaceFirst(RegExp(r'\.e'), 'e');
    return text;
  }

  var text = value.toStringAsFixed(10);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : text;
}

/// Returns `n/d` when [value] is close to a simple rational number.
String? _asFraction(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  final sign = value < 0 ? -1 : 1;
  final target = value.abs();
  var h1 = 1, h0 = 0, k1 = 0, k0 = 1;
  var remainder = target;
  for (var i = 0; i < 32; i++) {
    final whole = remainder.floor();
    final h2 = whole * h1 + h0;
    final k2 = whole * k1 + k0;
    if (k2 > 10000) break;
    h0 = h1;
    h1 = h2;
    k0 = k1;
    k1 = k2;
    final fractional = remainder - whole;
    if (fractional.abs() < 1e-12) break;
    remainder = 1 / fractional;
  }
  if (k1 <= 1 || k1 > 10000) return null;
  if ((target - h1 / k1).abs() > 1e-9) return null;
  return '${sign * h1}/$k1';
}
