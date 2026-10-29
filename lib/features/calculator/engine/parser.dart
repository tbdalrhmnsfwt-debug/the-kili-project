/// Recursive-descent parser that builds a closed [Expr] tree.
///
/// Grammar (from lowest to highest precedence):
///
///     expression := term (('+' | '-') term)*
///     term       := unary (('*' | '/' | implicit) unary)*
///     unary      := ('+' | '-') unary | power
///     power      := postfix ('^' unary)?
///     postfix    := primary ('!' | '%' | '²' | '³' | '°')*
///     primary    := number | constant | variable | function call
///                 | '(' expression ')' | '√' unary | '∛' unary
///                 | '|' expression '|'
///
/// The parser never evaluates, so malformed input is rejected without any code
/// execution. Unary minus binds below exponentiation (`-2^2` is `-(2^2)`), the
/// usual mathematical convention, while a signed exponent (`2^-3`) is allowed.
library;

import 'ast.dart';
import 'calculator_error.dart';
import 'function_catalog.dart';
import 'lexer.dart';
import 'math_value.dart';

class Parser {
  Parser(String source) : _tokens = Lexer(source).tokenize();

  final List<Token> _tokens;
  int _position = 0;

  /// Parses the whole input and throws [CalcError] on malformed expressions.
  Expr parse() {
    if (_peek.kind == TokenKind.eof) {
      throw const CalcError(CalcErrorKind.empty);
    }
    final expression = _additive();
    if (_peek.kind != TokenKind.eof) {
      throw CalcError(
        CalcErrorKind.syntax,
        detail: 'جزء غير متوقع «${_peek.text}» بعد التعبير',
      );
    }
    return expression;
  }

  Expr _additive() {
    var left = _multiplicative();
    while (true) {
      if (_matchSymbol('+')) {
        left = BinaryExpr('+', left, _multiplicative());
      } else if (_matchSymbol('-')) {
        left = BinaryExpr('-', left, _multiplicative());
      } else {
        return left;
      }
    }
  }

  Expr _multiplicative() {
    var left = _unary();
    while (true) {
      if (_matchSymbol('*')) {
        left = BinaryExpr('*', left, _unary());
      } else if (_matchSymbol('/')) {
        left = BinaryExpr('/', left, _unary());
      } else if (_startsValue(_peek)) {
        // Implicit multiplication: 2π, 3(4+1), 2sin(30), (x+1)(x-1).
        left = BinaryExpr('*', left, _unary());
      } else {
        return left;
      }
    }
  }

  Expr _unary() {
    if (_matchSymbol('+')) return UnaryExpr('+', _unary());
    if (_matchSymbol('-')) return UnaryExpr('-', _unary());
    return _power();
  }

  Expr _power() {
    final base = _postfix();
    if (_matchSymbol('^')) {
      return BinaryExpr('^', base, _unary());
    }
    return base;
  }

  Expr _postfix() {
    var value = _primary();
    while (true) {
      if (_matchSymbol('!')) {
        value = PostfixExpr('!', value);
      } else if (_matchSymbol('%')) {
        value = PostfixExpr('%', value);
      } else if (_matchSymbol('²')) {
        value = PostfixExpr('²', value);
      } else if (_matchSymbol('³')) {
        value = PostfixExpr('³', value);
      } else if (_matchSymbol('°')) {
        value = PostfixExpr('°', value);
      } else {
        return value;
      }
    }
  }

  Expr _primary() {
    final token = _peek;
    switch (token.kind) {
      case TokenKind.number:
        _position++;
        final value = Rational.tryParse(token.text);
        if (value == null) {
          throw CalcError(
            CalcErrorKind.syntax,
            detail: 'رقم غير صالح «${token.text}»',
          );
        }
        return LiteralExpr(value, raw: token.text);
      case TokenKind.leftParen:
        _position++;
        final inner = _additive();
        _expect(TokenKind.rightParen, 'قوس قافل )');
        return inner;
      case TokenKind.identifier:
        return _identifier();
      case TokenKind.symbol:
        if (_matchSymbol('√')) {
          return FunctionExpr('sqrt', <Expr>[_unary()]);
        }
        if (_matchSymbol('∛')) {
          return FunctionExpr('cbrt', <Expr>[_unary()]);
        }
        if (_matchSymbol('|')) {
          final inner = _additive();
          if (!_matchSymbol('|')) {
            throw const CalcError(
              CalcErrorKind.syntax,
              detail: 'قيمة مطلقة غير مقفولة |',
            );
          }
          return FunctionExpr('abs', <Expr>[inner]);
        }
        throw CalcError(
          CalcErrorKind.syntax,
          detail: 'الرمز «${token.text}» مش متوقع هنا',
        );
      case TokenKind.rightParen:
        throw const CalcError(CalcErrorKind.syntax, detail: 'قوس قافل زيادة )');
      case TokenKind.comma:
        throw const CalcError(CalcErrorKind.syntax, detail: 'فاصلة مش متوقعة');
      case TokenKind.eof:
        throw const CalcError(CalcErrorKind.syntax, detail: 'التعبير ناقص');
    }
  }

  Expr _identifier() {
    final token = _peek;
    _position++;
    final raw = token.text;
    final lower = raw.toLowerCase();

    if (lower == 'ans') return const VariableExpr('Ans');
    if (lower == 'pi') return const ConstantExpr('pi');
    // Only lowercase `e` is Euler's number. Uppercase `E` is one of the
    // Casio session variables (STO/RCL E), so it must reach the evaluator.
    if (raw == 'e') return const ConstantExpr('e');
    if (lower == 'i') return const ConstantExpr('i');
    if (lower == 'θ' || lower == 'theta') return const VariableExpr('θ');

    if (knownFunctionNames.contains(lower)) {
      if (_peek.kind == TokenKind.leftParen) return _functionCall(lower);
      // Casio-style `sin 30` without parentheses.
      final argument = _unary();
      validateFunctionArity(lower, 1);
      return FunctionExpr(lower, [argument]);
    }

    if (raw.length == 1) {
      return VariableExpr(raw);
    }

    // `Anse` (the Ans key followed by the e key) means Ans·e, `AnsAns` means
    // Ans·Ans, and `Anssin(30)` means Ans·sin(30). The run has to be handled
    // before the unknown-function check below, because `Anssin(` would
    // otherwise throw.
    final reserved = _reservedRun(raw);
    if (reserved != null) return reserved;

    if (_peek.kind == TokenKind.leftParen) {
      throw CalcError(
        CalcErrorKind.syntax,
        detail: 'دالة غير معروفة «$raw».',
      );
    }

    // `xy` is read as x·y, matching the way students type implicit products.
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(raw)) {
      throw CalcError(
        CalcErrorKind.variable,
        detail: 'اسم غير صالح «$raw».',
      );
    }
    Expr product = _simpleName(raw[0]);
    for (var i = 1; i < raw.length; i++) {
      product = BinaryExpr('*', product, _simpleName(raw[i]));
    }
    return product;
  }

  /// Reads `name(...)` after the caller has seen the opening parenthesis.
  Expr _functionCall(String lower) {
    final arguments = <Expr>[];
    _expect(TokenKind.leftParen, 'قوس فاتح (');
    if (_peek.kind != TokenKind.rightParen) {
      arguments.add(_additive());
      while (_matchKind(TokenKind.comma)) {
        arguments.add(_additive());
      }
    }
    _expect(TokenKind.rightParen, 'قوس قافل )');
    validateFunctionArity(lower, arguments.length);
    return FunctionExpr(lower, arguments);
  }

  /// Splits a letter run that starts with the reserved `Ans` name.
  ///
  /// Returns `null` when the run does not start with `Ans`, so the caller
  /// keeps the generic handling. A trailing function name followed by `(`
  /// stays whole, so `Anssin(30)` calls `sin` instead of reading `s·i·n`.
  Expr? _reservedRun(String raw) {
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(raw)) return null;
    var rest = raw;
    final parts = <Expr>[];
    while (rest.length >= 3 && rest.substring(0, 3).toLowerCase() == 'ans') {
      parts.add(const VariableExpr('Ans'));
      rest = rest.substring(3);
    }
    if (parts.isEmpty) return null;
    if (rest.isNotEmpty) {
      final restLower = rest.toLowerCase();
      if (_peek.kind == TokenKind.leftParen &&
          knownFunctionNames.contains(restLower)) {
        parts.add(_functionCall(restLower));
      } else {
        for (final part in rest.split('')) {
          parts.add(_simpleName(part));
        }
      }
    }
    var product = parts.first;
    for (final part in parts.skip(1)) {
      product = BinaryExpr('*', product, part);
    }
    return product;
  }

  /// Resolves one part of a split run the same way a whole identifier is.
  Expr _simpleName(String part) {
    final lower = part.toLowerCase();
    if (lower == 'ans') return const VariableExpr('Ans');
    if (lower == 'pi') return const ConstantExpr('pi');
    if (part == 'e') return const ConstantExpr('e');
    if (lower == 'i') return const ConstantExpr('i');
    if (part == 'θ' || lower == 'theta') return const VariableExpr('θ');
    return VariableExpr(part);
  }

  bool _startsValue(Token token) {
    if (token.kind == TokenKind.number ||
        token.kind == TokenKind.identifier ||
        token.kind == TokenKind.leftParen) {
      return true;
    }
    if (token.kind == TokenKind.symbol &&
        const {'√', '∛'}.contains(token.text)) {
      return true;
    }
    return false;
  }

  Token get _peek => _tokens[_position];

  bool _matchSymbol(String symbol) {
    final token = _peek;
    if (token.kind == TokenKind.symbol && token.text == symbol) {
      _position++;
      return true;
    }
    return false;
  }

  bool _matchKind(TokenKind kind) {
    if (_peek.kind == kind) {
      _position++;
      return true;
    }
    return false;
  }

  void _expect(TokenKind kind, String description) {
    if (_peek.kind != kind) {
      throw CalcError(
        CalcErrorKind.syntax,
        detail:
            '$description متوقع${_peek.kind == TokenKind.eof ? '' : ' عند «${_peek.text}»'}',
      );
    }
    _position++;
  }
}

/// Convenience helper used by tests and non-UI callers.
Expr parseExpression(String source) => Parser(source).parse();
