/// A small, strict lexer for calculator input.
///
/// It accepts the glyphs printed on the calculator keypad (`×`, `÷`, `−`, `√`,
/// `π`, `²`, `³`, `°`) as well as their plain-text equivalents, and normalises
/// Arabic-Indic digits. It never evaluates anything.
library;

import 'calculator_error.dart';

enum TokenKind { number, identifier, symbol, leftParen, rightParen, comma, eof }

class Token {
  const Token(this.kind, this.text, this.position);

  final TokenKind kind;
  final String text;
  final int position;

  bool isSymbol(String symbol) => kind == TokenKind.symbol && text == symbol;

  @override
  String toString() => '${kind.name}($text)@$position';
}

/// Converts keypad glyphs and Arabic-Indic digits into a canonical form.
String normalizeCalculatorInput(String source) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  const extendedDigits = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    final char = String.fromCharCode(rune);
    final arabic = arabicDigits.indexOf(char);
    if (arabic >= 0) {
      buffer.write(arabic);
      continue;
    }
    final extended = extendedDigits.indexOf(char);
    if (extended >= 0) {
      buffer.write(extended);
      continue;
    }
    buffer.write(
      switch (char) {
        '−' || '–' || '—' => '-',
        '×' || '·' || '•' => '*',
        '÷' => '/',
        '،' => ',',
        '٫' => '.',
        ' ' => ' ',
        _ => char,
      },
    );
  }
  var text = buffer.toString();
  text = text.replaceAll('**', '^');
  return text;
}

class Lexer {
  Lexer(String source)
    : source = normalizeCalculatorInput(source),
      _index = 0;

  final String source;
  int _index;

  List<Token> tokenize() {
    final tokens = <Token>[];
    while (true) {
      _skipWhitespace();
      if (_index >= source.length) {
        tokens.add(Token(TokenKind.eof, '', _index));
        return tokens;
      }
      final start = _index;
      final char = source[_index];

      if (_isDigit(char) || (char == '.' && _nextIsDigit())) {
        tokens.add(_number(start));
        continue;
      }
      if (char == 'π') {
        _index++;
        tokens.add(Token(TokenKind.identifier, 'pi', start));
        continue;
      }
      if (char == 'θ') {
        _index++;
        tokens.add(Token(TokenKind.identifier, 'θ', start));
        continue;
      }
      if (_isLetter(char)) {
        _index++;
        while (_index < source.length && _isLetter(source[_index])) {
          _index++;
        }
        tokens.add(
          Token(TokenKind.identifier, source.substring(start, _index), start),
        );
        continue;
      }
      if (char == '(') {
        _index++;
        tokens.add(Token(TokenKind.leftParen, char, start));
        continue;
      }
      if (char == ')') {
        _index++;
        tokens.add(Token(TokenKind.rightParen, char, start));
        continue;
      }
      if (char == ',') {
        _index++;
        tokens.add(Token(TokenKind.comma, char, start));
        continue;
      }
      if (const {
        '+',
        '-',
        '*',
        '/',
        '^',
        '!',
        '%',
        '²',
        '³',
        '°',
        '√',
        '∛',
        '|',
      }.contains(char)) {
        _index++;
        tokens.add(Token(TokenKind.symbol, char, start));
        continue;
      }
      throw CalcError(
        CalcErrorKind.syntax,
        detail: 'حرف غير معروف «$char» عند الموضع ${start + 1}',
      );
    }
  }

  Token _number(int start) {
    var seenDot = false;
    while (_index < source.length) {
      final char = source[_index];
      if (char == '.') {
        if (seenDot) break;
        seenDot = true;
        _index++;
        continue;
      }
      if (!_isDigit(char)) break;
      _index++;
    }
    // Scientific notation is consumed only when an exponent actually follows.
    if (_index < source.length &&
        (source[_index] == 'e' || source[_index] == 'E')) {
      var probe = _index + 1;
      if (probe < source.length &&
          (source[probe] == '+' || source[probe] == '-')) {
        probe++;
      }
      final digitsStart = probe;
      while (probe < source.length && _isDigit(source[probe])) {
        probe++;
      }
      if (probe > digitsStart) _index = probe;
    }
    final raw = source.substring(start, _index);
    if (raw == '.' || raw.isEmpty) {
      throw const CalcError(CalcErrorKind.syntax, detail: 'رقم غير مكتمل');
    }
    return Token(TokenKind.number, raw, start);
  }

  bool _nextIsDigit() =>
      _index + 1 < source.length && _isDigit(source[_index + 1]);

  void _skipWhitespace() {
    while (_index < source.length &&
        const {' ', '\t', '\n', '\r'}.contains(source[_index])) {
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
}
