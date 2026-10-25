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
    if (lower == 'e') return const ConstantExpr('e');
    if (lower == 'i') return const ConstantExpr('i');
    if (lower == 'θ' || lower == 'theta') return const VariableExpr('θ');

    if (knownFunctionNames.contains(lower)) {
      final arguments = <Expr>[];
      if (_peek.kind == TokenKind.leftParen) {
        _position++;
        if (_peek.kind != TokenKind.rightParen) {
          arguments.add(_additive());
          while (_matchKind(TokenKind.comma)) {
            arguments.add(_additive());
          }
        }
        _expect(TokenKind.rightParen, 'قوس قافل )');
      } else {
        // Casio-style `sin 30` without parentheses.
        arguments.add(_unary());
      }
      validateFunctionArity(lower, arguments.length);
      return FunctionExpr(lower, arguments);
    }

    if (raw.length == 1) {
      return VariableExpr(raw);
    }

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
    Expr product = VariableExpr(raw[0]);
    for (var i = 1; i < raw.length; i++) {
      product = BinaryExpr('*', product, VariableExpr(raw[i]));
    }
    return product;
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
        detail: '$description متوقع${_peek.kind == TokenKind.eof ? '' : ' عند «${_peek.text}»'}',
      );
    }
    _position++;
  }
}

/// Convenience helper used by tests and non-UI callers.
Expr parseExpression(String source) => Parser(source).parse();
