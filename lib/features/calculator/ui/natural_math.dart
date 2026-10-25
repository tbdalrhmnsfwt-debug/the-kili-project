/// Natural textbook display for the calculator input.
///
/// This is deliberately a presentation-only renderer. It never evaluates the
/// source; it recognises the same glyphs the parser accepts, stacks fractions,
/// lifts powers, draws radicals, and formats summations and integrals. The raw
/// string remains the single source of truth for editing, so moving the cursor
/// never changes the expression.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calc_palette.dart';

class NaturalMathView extends StatefulWidget {
  const NaturalMathView({
    super.key,
    required this.source,
    this.cursor,
    this.fontSize = 25,
    this.color,
    this.mutedColor,
    this.accentColor,
    this.maxLines = 3,
    this.alignEnd = false,
    this.emptyPlaceholder = '0',
    this.raw = false,
  });

  final String source;
  final int? cursor;
  final double fontSize;
  final Color? color;
  final Color? mutedColor;
  final Color? accentColor;
  final int maxLines;
  final bool alignEnd;
  final String emptyPlaceholder;

  /// LINE mode bypasses the textbook layout and shows the literal source.
  final bool raw;

  @override
  State<NaturalMathView> createState() => _NaturalMathViewState();
}

class _NaturalMathViewState extends State<NaturalMathView> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToCaret();
  }

  @override
  void didUpdateWidget(covariant NaturalMathView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source || oldWidget.cursor != widget.cursor) {
      _scrollToCaret();
    }
  }

  void _scrollToCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final cursor = widget.cursor;
      if (cursor != null && cursor >= widget.source.length - 1) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final color = widget.color ?? palette.math;
    final muted = widget.mutedColor ?? palette.mathMuted;
    final accent = widget.accentColor ?? palette.accent;
    final style = CalcTypography.math(
      palette,
      size: widget.fontSize,
      color: color,
    );
    final builder = _NaturalBuilder(
      source: widget.source,
      cursor: widget.cursor,
      style: style,
      smallStyle: style.copyWith(fontSize: widget.fontSize * 0.58),
      operatorStyle: style.copyWith(
        color: color.withValues(alpha: 0.86),
        fontWeight: FontWeight.w400,
      ),
      functionStyle: style.copyWith(fontStyle: FontStyle.normal),
      variableStyle: style.copyWith(fontStyle: FontStyle.italic),
      mutedStyle: style.copyWith(color: muted),
      caretColor: accent,
      caretHeight: widget.fontSize * 1.25,
    );

    Widget content;
    if (widget.source.trim().isEmpty) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.cursor != null)
            _BlinkingCaret(color: accent, height: widget.fontSize * 1.25),
          Text(
            widget.emptyPlaceholder,
            style: style.copyWith(color: muted.withValues(alpha: 0.7)),
          ),
        ],
      );
    } else if (widget.raw) {
      content = _buildRaw(style, accent);
    } else {
      content = builder.build();
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: widget.alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.fontSize * 1.4),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildRaw(TextStyle style, Color accent) {
    final rawStyle = style.copyWith(
      fontFamily: 'monospace',
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
    final cursor = widget.cursor;
    if (cursor == null) {
      return Text(
        widget.source,
        style: rawStyle,
        maxLines: widget.maxLines,
        overflow: TextOverflow.visible,
        textDirection: TextDirection.ltr,
      );
    }
    final safe = cursor.clamp(0, widget.source.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (safe > 0)
          Text(
            widget.source.substring(0, safe),
            style: rawStyle,
            textDirection: TextDirection.ltr,
          ),
        _BlinkingCaret(color: accent, height: widget.fontSize * 1.25),
        if (safe < widget.source.length)
          Text(
            widget.source.substring(safe),
            style: rawStyle,
            textDirection: TextDirection.ltr,
          ),
      ],
    );
  }
}

class _NaturalBuilder {
  _NaturalBuilder({
    required this.source,
    required this.cursor,
    required this.style,
    required this.smallStyle,
    required this.operatorStyle,
    required this.functionStyle,
    required this.variableStyle,
    required this.mutedStyle,
    required this.caretColor,
    required this.caretHeight,
  });

  final String source;
  final int? cursor;
  final TextStyle style;
  final TextStyle smallStyle;
  final TextStyle operatorStyle;
  final TextStyle functionStyle;
  final TextStyle variableStyle;
  final TextStyle mutedStyle;
  final Color caretColor;
  final double caretHeight;

  bool caretPlaced = false;

  bool get hasCursor => cursor != null;

  Widget build() {
    final (start, end) = _trim(0, source.length);
    if (start >= end) {
      return _caretOr(const SizedBox(width: 2));
    }
    final rendered = _render(start, end);
    if (hasCursor && !caretPlaced) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[rendered, _caret()],
      );
    }
    return rendered;
  }

  Widget _caret() {
    caretPlaced = true;
    return _BlinkingCaret(color: caretColor, height: caretHeight);
  }

  Widget _caretOr(Widget fallback) {
    if (!hasCursor || caretPlaced) return fallback;
    return _caret();
  }

  Widget _render(int rawStart, int rawEnd) {
    if (rawStart >= rawEnd) {
      return _caretOr(const SizedBox(width: 1));
    }
    final (start, end) = _trim(rawStart, rawEnd);
    if (start >= end) return _caretOr(const SizedBox(width: 1));

    // Lowest precedence first: addition/subtraction.
    final additive = _topLevelOperators(start, end, const <String>{'+', '−', '-'}, additive: true);
    if (additive.isNotEmpty) {
      final op = additive.last;
      return _binaryRow(start, end, op, _symbolAt(op), additive: true);
    }

    // Multiplication and division. Division becomes a stacked fraction.
    final multiplicative =
        _topLevelOperators(start, end, const <String>{'*', '×', '/', '÷'});
    if (multiplicative.isNotEmpty) {
      final op = multiplicative.last;
      final glyph = source[op];
      if (glyph == '/' || glyph == '÷') {
        return _fraction(start, end, op);
      }
      return _binaryRow(start, end, op, '×');
    }

    // Exponentiation, right associative: split at the first top-level ^.
    final powers = _topLevelOperators(
      start,
      end,
      const <String>{'^'},
      doubleStar: true,
    );
    if (powers.isNotEmpty) {
      return _power(start, end, powers.first);
    }

    // Prefix sign.
    final signIndex = _firstNonSpace(start, end);
    if ((source[signIndex] == '+' ||
            source[signIndex] == '−' ||
            source[signIndex] == '-') &&
        signIndex == start &&
        end - start > 1) {
      return _unary(start, end, signIndex);
    }

    // Parenthesised group covering the whole range.
    if (source[start] == '(') {
      final close = _matching(start, end, '(', ')');
      if (close == end - 1) {
        return _group(start, end, '(', ')');
      }
    }
    if (source[start] == '[') {
      final close = _matching(start, end, '[', ']');
      if (close == end - 1) {
        return _group(start, end, '[', ']');
      }
    }

    // Radical glyphs.
    if (source[start] == '√' || source[start] == '∛') {
      final symbol = source[start];
      final (innerStart, innerEnd) = _trim(start + 1, end);
      return _radical(
        symbol: symbol == '√' ? '√' : '∛',
        innerStart: innerStart,
        innerEnd: innerEnd,
      );
    }

    // Absolute value bars.
    if (source[start] == '|') {
      final close = _nextBar(start + 1, end);
      if (close == end - 1) {
        return _absolute(start, end, close);
      }
    }

    // Function call covering the whole range.
    final identifierEnd = _identifierEnd(start, end);
    if (identifierEnd > start) {
      final name = source.substring(start, identifierEnd);
      final (parenStart, _) = _trim(identifierEnd, end);
      if (parenStart < end && source[parenStart] == '(') {
        final close = _matching(parenStart, end, '(', ')');
        if (close == end - 1) {
          return _function(start, identifierEnd, name, parenStart, close);
        }
      }
      // A lone identifier is handled by the leaf sequence below.
    }

    return _leafSequence(start, end);
  }

  Widget _binaryRow(
    int start,
    int end,
    int op,
    String glyph, {
    bool additive = false,
  }) {
    final (leftStart, leftEnd) = _trim(start, op);
    final (rightStart, rightEnd) = _trim(op + 1, end);
    final spaced = additive ? '  $glyph  ' : ' $glyph ';
    final children = <Widget>[];
    children.add(_render(leftStart, leftEnd));
    if (hasCursor &&
        !caretPlaced &&
        cursor! >= leftEnd &&
        cursor! <= op + 1) {
      children.add(_caret());
    }
    children.add(
      Text(
        spaced,
        style: operatorStyle,
        textDirection: TextDirection.ltr,
      ),
    );
    if (hasCursor && !caretPlaced && cursor! > op + 1 && cursor! <= rightStart) {
      children.add(_caret());
    }
    children.add(_render(rightStart, rightEnd));
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _fraction(int start, int end, int slash) {
    final (numeratorStart, numeratorEnd) = _trim(start, slash);
    final (denominatorStart, denominatorEnd) = _trim(slash + 1, end);
    final numerator = _render(numeratorStart, numeratorEnd);
    final denominator = _render(denominatorStart, denominatorEnd);
    final fraction = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: numerator,
        ),
        Container(
          height: 1.8,
          constraints: const BoxConstraints(minWidth: 12),
          margin: const EdgeInsets.symmetric(vertical: 3),
          color: style.color,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: denominator,
        ),
      ],
    );
    if (hasCursor && !caretPlaced && cursor! == slash) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[fraction, _caret()],
      );
    }
    return fraction;
  }

  Widget _power(int start, int end, int caretIndex) {
    final operatorLength = caretIndex + 1 < end && source[caretIndex] == '*' ? 2 : 1;
    final (baseStart, baseEnd) = _trim(start, caretIndex);
    final (exponentStart, exponentEnd) = _trim(caretIndex + operatorLength, end);
    final exponent = _render(exponentStart, exponentEnd);
    final children = <Widget>[
      _render(baseStart, baseEnd),
    ];
    if (hasCursor &&
        !caretPlaced &&
        cursor! >= baseEnd &&
        cursor! <= exponentStart) {
      children.add(_caret());
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 1),
        child: Transform.translate(
          offset: const Offset(0, -8),
          child: exponent,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _unary(int start, int end, int signIndex) {
    final glyph = source[signIndex] == '-' ? '−' : source[signIndex];
    final (innerStart, innerEnd) = _trim(signIndex + 1, end);
    final children = <Widget>[];
    if (hasCursor && !caretPlaced && cursor! <= signIndex) {
      children.add(_caret());
    }
    children.add(Text(glyph, style: operatorStyle, textDirection: TextDirection.ltr));
    if (hasCursor && !caretPlaced && cursor! == signIndex + 1) {
      children.add(_caret());
    }
    children.add(_render(innerStart, innerEnd));
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _group(int start, int end, String open, String closeGlyph) {
    final children = <Widget>[
      _tokenText(open, start, operatorStyle),
      _render(start + 1, end - 1),
      _tokenText(closeGlyph, end - 1, operatorStyle),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _absolute(int start, int end, int close) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _tokenText('|', start, operatorStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _render(start + 1, close),
        ),
        _tokenText('|', close, operatorStyle),
      ],
    );
  }

  Widget _radical({
    required String symbol,
    required int innerStart,
    required int innerEnd,
  }) {
    final radicand = innerStart < innerEnd
        ? _render(innerStart, innerEnd)
        : const SizedBox(width: 8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (hasCursor && !caretPlaced && cursor! < innerStart)
          _caret(),
        Text(
          symbol,
          style: style.copyWith(fontSize: style.fontSize! * 1.18, height: 1),
          textDirection: TextDirection.ltr,
        ),
        Container(
          padding: const EdgeInsets.only(left: 2, right: 2, top: 2),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: style.color!.withValues(alpha: 0.9),
                width: 1.4,
              ),
            ),
          ),
          child: radicand,
        ),
      ],
    );
  }

  Widget _function(
    int start,
    int nameEnd,
    String name,
    int parenStart,
    int close,
  ) {
    final lower = name.toLowerCase();
    final innerStart = parenStart + 1;
    final innerEnd = close;
    if (lower == 'sqrt' || lower == 'cbrt') {
      return _radical(
        symbol: lower == 'sqrt' ? '√' : '∛',
        innerStart: innerStart,
        innerEnd: innerEnd,
      );
    }
    if (lower == 'abs') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _tokenText('|', start, operatorStyle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _render(innerStart, innerEnd),
          ),
          _tokenText('|', close, operatorStyle),
        ],
      );
    }

    final arguments = _splitArguments(innerStart, innerEnd);
    if (lower == 'sum' || lower == 'product') {
      if (arguments.length == 4) {
        return _bigOperator(
          start: start,
          nameEnd: nameEnd,
          glyph: lower == 'sum' ? 'Σ' : '∏',
          arguments: arguments,
          upperIndex: 3,
          lowerIndex: 2,
        );
      }
    }
    if (lower == 'integral') {
      if (arguments.length == 4) {
        return _bigOperator(
          start: start,
          nameEnd: nameEnd,
          glyph: '∫',
          arguments: arguments,
          upperIndex: 3,
          lowerIndex: 2,
          showDifferential: true,
        );
      }
    }

    final nameStyle = lower == 'ans' ? style : functionStyle;
    final children = <Widget>[
      _tokenText(name, start, nameStyle),
      _tokenText('(', parenStart, operatorStyle),
    ];
    for (var i = 0; i < arguments.length; i++) {
      if (i > 0) {
        final comma = _commaBefore(arguments[i], innerStart);
        children.add(_tokenText(', ', comma, operatorStyle));
      }
      children.add(_render(arguments[i].$1, arguments[i].$2));
    }
    children.add(_tokenText(')', close, operatorStyle));
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _bigOperator({
    required int start,
    required int nameEnd,
    required String glyph,
    required List<(int, int)> arguments,
    required int upperIndex,
    required int lowerIndex,
    bool showDifferential = false,
  }) {
    final body = _render(arguments[0].$1, arguments[0].$2);
    final variable = _render(arguments[1].$1, arguments[1].$2);
    final lower = _render(arguments[lowerIndex].$1, arguments[lowerIndex].$2);
    final upper = _render(arguments[upperIndex].$1, arguments[upperIndex].$2);
    final children = <Widget>[];
    if (hasCursor && !caretPlaced && cursor! <= nameEnd) {
      children.add(_caret());
    }
    children.add(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          DefaultTextStyle.merge(
            style: smallStyle,
            child: Transform.scale(scale: 0.82, child: upper),
          ),
          Text(
            glyph,
            style: style.copyWith(fontSize: style.fontSize! * 1.5, height: 0.95),
            textDirection: TextDirection.ltr,
          ),
          DefaultTextStyle.merge(
            style: smallStyle,
            child: Transform.scale(scale: 0.82, child: lower),
          ),
        ],
      ),
    );
    children.add(
      Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            body,
            if (showDifferential)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('d', style: smallStyle, textDirection: TextDirection.ltr),
                  variable,
                ],
              ),
          ],
        ),
      ),
    );
    if (hasCursor && !caretPlaced) {
      children.add(_caret());
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }

  Widget _leafSequence(int start, int end) {
    final tokens = <Widget>[];
    var index = start;
    while (index < end) {
      if (_isSpace(source[index])) {
        index++;
        continue;
      }
      final tokenStart = index;
      Widget token;
      final char = source[index];

      if (_isDigit(char) || (char == '.' && index + 1 < end && _isDigit(source[index + 1]))) {
        final numberEnd = _numberEnd(index, end);
        token = _tokenText(source.substring(index, numberEnd), index, style);
        index = numberEnd;
      } else if (char == '√' || char == '∛') {
        final innerStart = _skipSpaceForward(index + 1, end);
        var innerEnd = innerStart;
        if (innerStart < end && source[innerStart] == '(') {
          final close = _matching(innerStart, end, '(', ')');
          innerEnd = close >= 0 ? math.min(close + 1, end) : end;
        } else {
          innerEnd = _numberEnd(innerStart, end);
          if (innerEnd == innerStart) innerEnd = math.min(innerStart + 1, end);
        }
        token = _radical(
          symbol: char,
          innerStart: innerStart,
          innerEnd: innerEnd,
        );
        index = innerEnd;
      } else if (char == '(' || char == '[') {
        final closeGlyph = char == '(' ? ')' : ']';
        final close = _matching(index, end, char, closeGlyph);
        if (close >= 0) {
          final children = <Widget>[
            _tokenText(char, index, operatorStyle),
            _render(index + 1, close),
            _tokenText(closeGlyph, close, operatorStyle),
          ];
          token = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          );
          index = close + 1;
        } else {
          token = _tokenText(char, index, operatorStyle);
          index++;
        }
      } else if (char == '|') {
        final close = _nextBar(index + 1, end);
        if (close > index) {
          token = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _tokenText('|', index, operatorStyle),
              _render(index + 1, close),
              _tokenText('|', close, operatorStyle),
            ],
          );
          index = close + 1;
        } else {
          token = _tokenText('|', index, operatorStyle);
          index++;
        }
      } else if (_isLetter(char)) {
        final identifierEnd = _identifierEnd(index, end);
        final raw = source.substring(index, identifierEnd);
        final lower = raw.toLowerCase();
        final isVariable = raw.length == 1 || lower == 'theta' || lower == 'θ';
        token = _tokenText(
          raw,
          index,
          lower == 'ans' ? style : (isVariable ? variableStyle : functionStyle),
        );
        index = identifierEnd;
      } else if (char == '²' || char == '³' || char == '°') {
        token = Text(
          char,
          style: style.copyWith(fontSize: style.fontSize! * 0.72),
          textDirection: TextDirection.ltr,
        );
        index++;
      } else {
        token = _tokenText(
          char,
          index,
          const <String>{'+', '−', '-', '×', '*', '÷', '/', '^', '%', '!', ','}
                  .contains(char)
              ? operatorStyle
              : style,
        );
        index++;
      }

      if (hasCursor && !caretPlaced && cursor! == tokenStart) {
        tokens.add(_caret());
      }
      tokens.add(token);
      if (tokenStart == index) index++;
    }
    if (hasCursor && !caretPlaced && cursor! == end) {
      tokens.add(_caret());
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: tokens,
    );
  }

  Widget _tokenText(String text, int start, TextStyle textStyle) {
    if (!hasCursor ||
        caretPlaced ||
        cursor! < start ||
        cursor! > start + text.length) {
      return Text(text, style: textStyle, textDirection: TextDirection.ltr);
    }
    final local = cursor! - start;
    caretPlaced = true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (local > 0)
          Text(
            text.substring(0, local),
            style: textStyle,
            textDirection: TextDirection.ltr,
          ),
        _BlinkingCaret(color: caretColor, height: caretHeight),
        if (local < text.length)
          Text(
            text.substring(local),
            style: textStyle,
            textDirection: TextDirection.ltr,
          ),
      ],
    );
  }

  (int, int) _trim(int start, int end) {
    var a = start;
    var b = end;
    while (a < b && _isSpace(source[a])) {
      a++;
    }
    while (b > a && _isSpace(source[b - 1])) {
      b--;
    }
    return (a, b);
  }

  int _firstNonSpace(int start, int end) {
    for (var i = start; i < end; i++) {
      if (!_isSpace(source[i])) return i;
    }
    return start;
  }

  List<int> _topLevelOperators(
    int start,
    int end,
    Set<String> operators, {
    bool additive = false,
    bool doubleStar = false,
  }) {
    final result = <int>[];
    var depth = 0;
    var barOpen = false;
    for (var i = start; i < end; i++) {
      final char = source[i];
      if (char == '(' || char == '[') {
        depth++;
        continue;
      }
      if (char == ')' || char == ']') {
        if (depth > 0) depth--;
        continue;
      }
      if (char == '|') {
        if (depth == 0) barOpen = !barOpen;
        continue;
      }
      if (depth != 0 || barOpen) continue;

      if (doubleStar && char == '*' && i + 1 < end && source[i + 1] == '*') {
        result.add(i);
        i++;
        continue;
      }
      if (!operators.contains(char)) continue;
      if (char == '*' && i + 1 < end && source[i + 1] == '*') {
        i++;
        continue;
      }
      if (additive && (char == '+' || char == '-' || char == '−')) {
        if (_isUnaryOperator(i, start, end)) continue;
      }
      result.add(i);
    }
    return result;
  }

  bool _isUnaryOperator(int index, int start, int end) {
    var probe = index - 1;
    while (probe >= start && _isSpace(source[probe])) {
      probe--;
    }
    if (probe < start) return true;
    final previous = source[probe];
    if ('+-−*/^×(,÷'.contains(previous)) return true;
    if (previous == 'e' || previous == 'E') {
      var beforeE = probe - 1;
      while (beforeE >= start && _isSpace(source[beforeE])) {
        beforeE--;
      }
      if (beforeE >= start &&
          _isDigit(source[beforeE]) &&
          index + 1 < end &&
          _isDigit(source[index + 1])) {
        return true;
      }
    }
    return false;
  }

  String _symbolAt(int index) => source[index] == '-' ? '−' : source[index];

  int _matching(int openIndex, int end, String open, String close) {
    if (openIndex < 0 || openIndex >= end || source[openIndex] != open) {
      return -1;
    }
    var depth = 0;
    for (var i = openIndex; i < end; i++) {
      if (source[i] == open) depth++;
      if (source[i] == close) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  int _nextBar(int start, int end) {
    for (var i = start; i < end; i++) {
      if (source[i] == '|') return i;
    }
    return -1;
  }

  int _identifierEnd(int start, int end) {
    var i = start;
    while (i < end && _isLetter(source[i])) {
      i++;
    }
    return i;
  }

  int _numberEnd(int start, int end) {
    var i = start;
    var dot = false;
    while (i < end) {
      final char = source[i];
      if (_isDigit(char)) {
        i++;
      } else if (char == '.' && !dot) {
        dot = true;
        i++;
      } else {
        break;
      }
    }
    if (i < end && (source[i] == 'e' || source[i] == 'E')) {
      var probe = i + 1;
      if (probe < end && (source[probe] == '+' || source[probe] == '-')) {
        probe++;
      }
      final digitsStart = probe;
      while (probe < end && _isDigit(source[probe])) {
        probe++;
      }
      if (probe > digitsStart) i = probe;
    }
    return i;
  }

  int _skipSpaceForward(int start, int end) {
    var i = start;
    while (i < end && _isSpace(source[i])) {
      i++;
    }
    return i;
  }

  List<(int, int)> _splitArguments(int start, int end) {
    final result = <(int, int)>[];
    if (start >= end) return result;
    var depth = 0;
    var barOpen = false;
    var partStart = start;
    for (var i = start; i < end; i++) {
      final char = source[i];
      if (char == '(' || char == '[') {
        depth++;
      } else if (char == ')' || char == ']') {
        if (depth > 0) depth--;
      } else if (char == '|') {
        if (depth == 0) barOpen = !barOpen;
      } else if (char == ',' && depth == 0 && !barOpen) {
        final (a, b) = _trim(partStart, i);
        result.add((a, b));
        partStart = i + 1;
      }
    }
    final (a, b) = _trim(partStart, end);
    result.add((a, b));
    return result;
  }

  int _commaBefore((int, int) argument, int fallback) {
    var probe = argument.$1 - 1;
    while (probe >= 0 && _isSpace(source[probe])) {
      probe--;
    }
    return probe >= 0 && source[probe] == ',' ? probe : fallback;
  }

  static bool _isSpace(String char) =>
      char == ' ' || char == '\t' || char == '\n' || char == '\r';

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isLetter(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        char == 'θ' ||
        char == 'π' ||
        char == 'φ';
  }
}

class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.95, end: 0.18).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 2,
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.color.withValues(alpha: 0.45),
              blurRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}
