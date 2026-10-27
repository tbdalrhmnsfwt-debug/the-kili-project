/// A day-to-day calculator for the daily-tools grid.
///
/// The keypad builds a plain-text expression using the same symbols it shows
/// (`×`, `÷`, `−`, `%`, parentheses). A small recursive-descent parser
/// evaluates it without `dart:math`'s `eval` (which does not exist) or any
/// third-party dependency, so the screen also works fully offline.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';

/// The calculator screen.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _preview = '';
  String? _error;
  final List<({String expression, String result})> _history = [];

  void _append(String token) {
    setState(() {
      _error = null;
      _expression += token;
      _refreshPreview();
    });
  }

  void _clear() {
    setState(() {
      _expression = '';
      _preview = '';
      _error = null;
    });
  }

  void _backspace() {
    if (_expression.isEmpty) return;
    setState(() {
      _error = null;
      _expression = _expression.substring(0, _expression.length - 1);
      _refreshPreview();
    });
  }

  void _refreshPreview() {
    final value = _evaluate(_expression);
    _preview = value == null ? '' : _format(value);
  }

  void _equals() {
    final value = _evaluate(_expression);
    if (value == null) {
      setState(() => _error = 'اكتب عملية صحيحة الأول.');
      return;
    }
    final result = _format(value);
    setState(() {
      _history.insert(0, (expression: _expression, result: result));
      if (_history.length > 6) _history.removeLast();
      _expression = result;
      _preview = '';
      _error = null;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const TrText('الآلة الحاسبة')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Display(
                  expression: _expression.isEmpty ? '0' : _expression,
                  preview: _preview,
                  error: _error,
                ),
                const SizedBox(height: 16),
                _Keypad(
                  onDigit: _append,
                  onClear: _clear,
                  onBackspace: _backspace,
                  onEquals: _equals,
                ),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedClock01,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      TrText(
                        'آخر العمليات',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(_history.clear),
                        child: const TrText('مسح'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final entry in _history)
                    _HistoryRow(
                      expression: entry.expression,
                      result: entry.result,
                      onTap: () => setState(() {
                        _expression = entry.expression;
                        _error = null;
                        _refreshPreview();
                      }),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- display

class _Display extends StatelessWidget {
  const _Display({
    required this.expression,
    required this.preview,
    required this.error,
  });

  final String expression;
  final String preview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? const [ZakerColors.navyDeep, Color(0xFF0F172A)]
              : const [ZakerColors.navy, ZakerColors.navyLight],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ZakerColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCalculator01,
                size: 18,
                color: ZakerColors.goldLight,
              ),
              const SizedBox(width: 8),
              TrText(
                'احسب بسرعة',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFF2E4B0),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Numbers always read left-to-right, even inside the RTL app.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              expression,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: ZakerTheme.fontUi,
                fontSize: 38,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 24,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                error ?? (preview.isEmpty ? ' ' : '= $preview'),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ZakerTheme.fontUi,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: error != null
                      ? const Color(0xFFFDE68A)
                      : ZakerColors.goldLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- keypad

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onClear,
    required this.onBackspace,
    required this.onEquals,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBackspace;
  final VoidCallback onEquals;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_Key>>[
      [
        _Key('C', onClear, kind: _KeyKind.clear),
        _Key('⌫', onBackspace, kind: _KeyKind.function),
        _Key('(', () => onDigit('('), kind: _KeyKind.function),
        _Key(')', () => onDigit(')'), kind: _KeyKind.function),
      ],
      [
        _Key('7', () => onDigit('7')),
        _Key('8', () => onDigit('8')),
        _Key('9', () => onDigit('9')),
        _Key('÷', () => onDigit('÷'), kind: _KeyKind.operator),
      ],
      [
        _Key('4', () => onDigit('4')),
        _Key('5', () => onDigit('5')),
        _Key('6', () => onDigit('6')),
        _Key('×', () => onDigit('×'), kind: _KeyKind.operator),
      ],
      [
        _Key('1', () => onDigit('1')),
        _Key('2', () => onDigit('2')),
        _Key('3', () => onDigit('3')),
        _Key('−', () => onDigit('−'), kind: _KeyKind.operator),
      ],
      [
        _Key('0', () => onDigit('0')),
        _Key('.', () => onDigit('.')),
        _Key('%', () => onDigit('%'), kind: _KeyKind.function),
        _Key('+', () => onDigit('+'), kind: _KeyKind.operator),
      ],
      [
        _Key('=', onEquals, kind: _KeyKind.equals),
      ],
    ];

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  Expanded(child: _KeyButton(keyData: rows[r][c])),
                  if (c != rows[r].length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (r != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

enum _KeyKind { digit, operator, function, clear, equals }

class _Key {
  const _Key(this.label, this.onTap, {this.kind = _KeyKind.digit});

  final String label;
  final VoidCallback onTap;
  final _KeyKind kind;
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.keyData});

  final _Key keyData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (background, foreground, border) = switch (keyData.kind) {
      _KeyKind.operator => (
        theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.10),
        theme.colorScheme.primary,
        theme.colorScheme.primary.withValues(alpha: 0.24),
      ),
      _KeyKind.function => (
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        theme.colorScheme.onSurface,
        theme.dividerTheme.color ?? Colors.black12,
      ),
      _KeyKind.clear => (
        ZakerColors.danger.withValues(alpha: isDark ? 0.20 : 0.08),
        ZakerColors.danger,
        ZakerColors.danger.withValues(alpha: 0.20),
      ),
      _KeyKind.equals || _KeyKind.digit => (
        isDark ? const Color(0xFF1E293B) : Colors.white,
        theme.colorScheme.onSurface,
        theme.dividerTheme.color ?? Colors.black12,
      ),
    };

    final isEquals = keyData.kind == _KeyKind.equals;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: keyData.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: isEquals
                ? const LinearGradient(
                    colors: [ZakerColors.primary, ZakerColors.primaryLight],
                  )
                : null,
            color: isEquals ? null : background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isEquals ? Colors.transparent : border),
            boxShadow: isEquals
                ? [
                    BoxShadow(
                      color: ZakerColors.primary.withValues(alpha: 0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              keyData.label,
              style: TextStyle(
                fontFamily: ZakerTheme.fontUi,
                fontSize: isEquals ? 22 : 21,
                fontWeight: FontWeight.w800,
                color: isEquals ? Colors.white : foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- history

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.expression,
    required this.result,
    required this.onTap,
  });

  final String expression;
  final String result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    expression,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '= $result',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ evaluator

/// Evaluates [source], returning `null` when it is incomplete or invalid.
double? _evaluate(String source) {
  if (source.trim().isEmpty) return null;
  try {
    final parser = _Parser(source);
    final value = parser.parse();
    if (value == null || !value.isFinite) return null;
    return value;
  } on FormatException {
    return null;
  }
}

String _format(double value) {
  if (!value.isFinite) return 'خطأ';
  if ((value - value.roundToDouble()).abs() < 1e-9) {
    return value.round().toString();
  }
  var text = value.toStringAsFixed(8);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

class _Parser {
  _Parser(this.source);

  final String source;
  int _index = 0;

  double? parse() {
    final value = _expression();
    _skipSpaces();
    if (_index != source.length) return null;
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
    var value = _factor();
    while (true) {
      _skipSpaces();
      if (_match('×') || _match('*')) {
        value *= _factor();
      } else if (_match('÷') || _match('/')) {
        final divisor = _factor();
        if (divisor == 0) throw const FormatException('division by zero');
        value /= divisor;
      } else if (_match('%')) {
        value /= 100;
      } else {
        return value;
      }
    }
  }

  double _factor() {
    _skipSpaces();
    if (_match('+')) return _factor();
    if (_match('−') || _match('-')) return -_factor();
    if (_match('(')) {
      final value = _expression();
      _skipSpaces();
      if (!_match(')')) throw const FormatException('missing )');
      return value;
    }
    return _number();
  }

  double _number() {
    _skipSpaces();
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
    if (start == _index) throw const FormatException('number expected');
    final value = double.tryParse(source.substring(start, _index));
    if (value == null) throw const FormatException('bad number');
    return value;
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
}
