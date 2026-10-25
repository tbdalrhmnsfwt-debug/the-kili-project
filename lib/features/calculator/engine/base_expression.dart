/// Small expression evaluator for BASE-N mode.
///
/// The mode needs genuine precedence and parentheses rather than two fixed
/// operand boxes. Literals are read in the selected base; bitwise words and
/// symbols are accepted. All arithmetic still goes through [applyBaseOperation]
/// so division by zero, huge shifts and arbitrary-precision results behave the
/// same as the rest of the engine.
library;

import 'base_n.dart';
import 'calculator_error.dart';

BigInt evaluateBaseExpression(String source, NumberBase base) {
  final parser = _BaseParser(_baseTokens(source, base), base);
  final value = parser._parseOr(0);
  if (parser._peek.kind != _BaseTokenKind.eof) {
    throw CalcError(
      CalcErrorKind.syntax,
      detail: 'جزء غير متوقع «${parser._peek.text}».',
    );
  }
  return value;
}

enum _BaseTokenKind { number, operation, leftParen, rightParen, eof }

class _BaseToken {
  const _BaseToken(this.kind, this.text, {this.operation});

  final _BaseTokenKind kind;
  final String text;
  final BaseOperation? operation;

  bool isOperation(BaseOperation operation) =>
      kind == _BaseTokenKind.operation && this.operation == operation;
}

List<_BaseToken> _baseTokens(String source, NumberBase base) {
  final text = _normalizeBaseSource(source);
  final tokens = <_BaseToken>[];
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (char.trim().isEmpty) {
      index++;
      continue;
    }
    if (char == '(' || char == ')') {
      index++;
      tokens.add(
        _BaseToken(
          char == '(' ? _BaseTokenKind.leftParen : _BaseTokenKind.rightParen,
          char,
        ),
      );
      continue;
    }
    final operation = _operationAt(text, index);
    if (operation != null) {
      tokens.add(
        _BaseToken(
          _BaseTokenKind.operation,
          text.substring(index, index + operation.$2),
          operation: operation.$1,
        ),
      );
      index += operation.$2;
      continue;
    }
    if (_isBaseDigit(char, base)) {
      final start = index;
      while (index < text.length && _isBaseDigit(text[index], base)) {
        index++;
      }
      tokens.add(
        _BaseToken(_BaseTokenKind.number, text.substring(start, index)),
      );
      continue;
    }
    throw CalcError(
      CalcErrorKind.syntax,
      detail: 'الرمز «$char» مش صالح في ${base.label}.',
    );
  }
  tokens.add(const _BaseToken(_BaseTokenKind.eof, ''));
  return tokens;
}

String _normalizeBaseSource(String source) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    final char = String.fromCharCode(rune);
    final arabicIndex = arabic.indexOf(char);
    if (arabicIndex >= 0) {
      buffer.write(arabicIndex);
      continue;
    }
    buffer.write(
      switch (char) {
        '−' || '–' || '—' => '-',
        '×' => '*',
        '÷' => '/',
        '≪' => '<<',
        '≫' => '>>',
        '，' || '،' => ',',
        _ => char,
      },
    );
  }
  return buffer
      .toString()
      .toUpperCase()
      .replaceAll('_', '');
}

/// Returns an operation and its source length. Longer words are checked first
/// so `XNOR` never becomes `XOR` followed by `N`.
(BaseOperation, int)? _operationAt(String source, int index) {
  const words = <(String, BaseOperation)>[
    ('XNOR', BaseOperation.xnor),
    ('XOR', BaseOperation.xor),
    ('AND', BaseOperation.and),
    ('NOT', BaseOperation.not),
    ('MOD', BaseOperation.mod),
    ('OR', BaseOperation.or),
    ('<<', BaseOperation.shiftLeft),
    ('>>', BaseOperation.shiftRight),
  ];
  for (final word in words) {
    if (source.startsWith(word.$1, index)) return (word.$2, word.$1.length);
  }
  final char = source[index];
  final operation = switch (char) {
    '+' => BaseOperation.add,
    '-' => BaseOperation.subtract,
    '*' => BaseOperation.multiply,
    '/' => BaseOperation.divide,
    '%' => BaseOperation.mod,
    '&' => BaseOperation.and,
    '|' => BaseOperation.or,
    '^' => BaseOperation.xor,
    '~' => BaseOperation.not,
    _ => null,
  };
  return operation == null ? null : (operation, 1);
}

bool _isBaseDigit(String char, NumberBase base) {
  final code = char.codeUnitAt(0);
  if (code >= 0x30 && code <= 0x39) return code - 0x30 < base.radix;
  if (base == NumberBase.hexadecimal && code >= 0x41 && code <= 0x46) {
    return true;
  }
  return false;
}

class _BaseParser {
  _BaseParser(this.tokens, this.base);

  final List<_BaseToken> tokens;
  final NumberBase base;
  int position = 0;

  _BaseToken get _peek => tokens[position];

  _BaseToken _take() => tokens[position++];

  BigInt _parseOr(int depth) {
    _guard(depth);
    var left = _parseXor(depth + 1);
    while (_peek.isOperation(BaseOperation.or)) {
      _take();
      final right = _parseXor(depth + 1);
      left = applyBaseOperation(left, right, BaseOperation.or);
    }
    return left;
  }

  BigInt _parseXor(int depth) {
    var left = _parseAnd(depth + 1);
    while (_peek.isOperation(BaseOperation.xor) ||
        _peek.isOperation(BaseOperation.xnor)) {
      final operation = _take().operation!;
      final right = _parseAnd(depth + 1);
      left = applyBaseOperation(left, right, operation);
    }
    return left;
  }

  BigInt _parseAnd(int depth) {
    var left = _parseShift(depth + 1);
    while (_peek.isOperation(BaseOperation.and)) {
      _take();
      final right = _parseShift(depth + 1);
      left = applyBaseOperation(left, right, BaseOperation.and);
    }
    return left;
  }

  BigInt _parseShift(int depth) {
    var left = _parseAdditive(depth + 1);
    while (_peek.isOperation(BaseOperation.shiftLeft) ||
        _peek.isOperation(BaseOperation.shiftRight)) {
      final operation = _take().operation!;
      final right = _parseAdditive(depth + 1);
      left = applyBaseOperation(left, right, operation);
    }
    return left;
  }

  BigInt _parseAdditive(int depth) {
    var left = _parseMultiplicative(depth + 1);
    while (_peek.isOperation(BaseOperation.add) ||
        _peek.isOperation(BaseOperation.subtract)) {
      final operation = _take().operation!;
      final right = _parseMultiplicative(depth + 1);
      left = applyBaseOperation(left, right, operation);
    }
    return left;
  }

  BigInt _parseMultiplicative(int depth) {
    var left = _parseUnary(depth + 1);
    while (_peek.isOperation(BaseOperation.multiply) ||
        _peek.isOperation(BaseOperation.divide) ||
        _peek.isOperation(BaseOperation.mod)) {
      final operation = _take().operation!;
      final right = _parseUnary(depth + 1);
      left = applyBaseOperation(left, right, operation);
    }
    return left;
  }

  BigInt _parseUnary(int depth) {
    _guard(depth);
    if (_peek.isOperation(BaseOperation.subtract)) {
      _take();
      return -_parseUnary(depth + 1);
    }
    if (_peek.isOperation(BaseOperation.add)) {
      _take();
      return _parseUnary(depth + 1);
    }
    if (_peek.isOperation(BaseOperation.not)) {
      _take();
      return ~_parseUnary(depth + 1);
    }
    return _parsePrimary(depth + 1);
  }

  BigInt _parsePrimary(int depth) {
    _guard(depth);
    final token = _peek;
    switch (token.kind) {
      case _BaseTokenKind.number:
        _take();
        return parseBase(token.text, base);
      case _BaseTokenKind.leftParen:
        _take();
        final value = _parseOr(depth + 1);
        if (_peek.kind != _BaseTokenKind.rightParen) {
          throw const CalcError(
            CalcErrorKind.syntax,
            detail: 'قوس قافل ) ناقص.',
          );
        }
        _take();
        return value;
      case _BaseTokenKind.rightParen:
        throw const CalcError(CalcErrorKind.syntax, detail: 'قوس قافل زيادة.');
      case _BaseTokenKind.operation:
        throw CalcError(
          CalcErrorKind.syntax,
          detail: 'العلامة «${token.text}» مش متبوعة برقم.',
        );
      case _BaseTokenKind.eof:
        throw const CalcError(
          CalcErrorKind.syntax,
          detail: 'التعبير ناقص.',
        );
    }
  }

  void _guard(int depth) {
    if (depth > 120) {
      throw const CalcError(CalcErrorKind.stack);
    }
  }
}
