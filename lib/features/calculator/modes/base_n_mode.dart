/// BASE-N mode with per-base keypad, precedence, bitwise operations and
/// simultaneous conversion to the other three bases.
library;

import 'package:flutter/material.dart';

import '../calc_history.dart';
import '../calc_session.dart';
import '../engine/base_expression.dart';
import '../engine/base_n.dart';
import '../engine/calculator_error.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

class BaseNMode extends StatefulWidget {
  const BaseNMode({
    super.key,
    required this.session,
    required this.onChanged,
  });

  final CalcSession session;
  final VoidCallback onChanged;

  @override
  State<BaseNMode> createState() => BaseNModeState();
}

class BaseNModeState extends State<BaseNMode> {
  final TextEditingController _controller = TextEditingController();
  NumberBase _base = NumberBase.decimal;
  BigInt? _result;
  CalcError? _error;
  String? _notice;

  /// Restores an expression recorded as `expression  [BASE]`.
  ///
  /// The shell calls this from the shared history sheet so BASE-N entries
  /// reopen in their original base instead of being parsed in COMP.
  void loadHistory(String expression) {
    var source = expression;
    var base = _base;
    final marker = expression.lastIndexOf('  [');
    if (marker >= 0 && expression.trimRight().endsWith(']')) {
      final label = expression.substring(
        marker + 3,
        expression.trimRight().length - 1,
      );
      for (final candidate in NumberBase.values) {
        if (candidate.label == label) {
          base = candidate;
          source = expression.substring(0, marker);
          break;
        }
      }
    }
    final text = source.trim();
    setState(() {
      _base = base;
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _result = null;
      _error = null;
      _notice = 'اتفتح من السجل في ${base.label}.';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _source => _controller.text;

  void _insert(String token) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _source.length;
    final end = selection.isValid ? selection.end : _source.length;
    final text = _source.replaceRange(start, end, token);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {
      _error = null;
      _notice = null;
      _result = null;
    });
  }

  void _backspace() {
    final selection = _controller.selection;
    if (selection.isValid && selection.start != selection.end) {
      _insert('');
      return;
    }
    final cursor = selection.isValid ? selection.start : _source.length;
    if (cursor <= 0) return;
    final before = _source.substring(0, cursor);
    const compound = <String>[
      ' AND ',
      ' XOR ',
      ' XNOR ',
      ' OR ',
      ' NOT ',
      ' MOD ',
      ' << ',
      ' >> ',
    ];
    var remove = 1;
    for (final token in compound) {
      if (before.toUpperCase().endsWith(token)) {
        remove = token.length;
        break;
      }
    }
    _controller.value = TextEditingValue(
      text: _source.replaceRange(cursor - remove, cursor, ''),
      selection: TextSelection.collapsed(offset: cursor - remove),
    );
    setState(() {
      _error = null;
      _result = null;
      _notice = null;
    });
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _result = null;
      _error = null;
      _notice = null;
    });
  }

  void _switchBase(NumberBase base) {
    if (base == _base) return;
    BigInt? converted;
    if (_source.trim().isNotEmpty) {
      try {
        converted = evaluateBaseExpression(_source, _base);
      } on CalcError {
        converted = null;
      }
    }
    setState(() {
      _base = base;
      _error = null;
      _notice = null;
      _result = null;
      if (converted != null) {
        final literal = formatBase(converted, base, group: false);
        _controller.value = TextEditingValue(
          text: literal,
          selection: TextSelection.collapsed(offset: literal.length),
        );
        _notice = 'اتحوّل آخر تعبير صالح لـ ${base.label}.';
      } else if (_source.trim().isNotEmpty) {
        _controller.clear();
        _notice = 'التعبير فيه رموز مش صالحة في ${base.label}، فاتمسح.';
      }
    });
  }

  void _equals() {
    final source = _source.trim();
    if (source.isEmpty) {
      setState(() {
        _error = const CalcError(CalcErrorKind.empty);
      });
      return;
    }
    try {
      final value = evaluateBaseExpression(source, _base);
      setState(() {
        _result = value;
        _error = null;
        _notice = null;
      });
      widget.session.record(
        CalcHistoryEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}-BASE',
          expression: '$source  [${_base.label}]',
          result: formatBase(value, _base).replaceAll('-', '−'),
          mode: 'BASE-N',
          angleUnit: widget.session.settings.angleUnit.label,
          timestamp: DateTime.now(),
        ),
      );
      widget.onChanged();
    } on CalcError catch (error) {
      setState(() {
        _error = error;
        _result = null;
      });
    }
  }

  BigInt? _livePreview() {
    if (_source.trim().isEmpty) return null;
    try {
      return evaluateBaseExpression(_source, _base);
    } on CalcError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 380;
        final palette = CalcPalette.of(context);
        final preview = _livePreview();
        final displayValue = _result ?? preview;
        return CalcModePage(
          title: 'BASE-N — الأنظمة العددية',
          subtitle:
              'حساب في ${_base.label} مع أقواس وأسبقية، وتحويل فوري لكل الأنظمة.',
          scrollable: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CalcPanel(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                radius: 18,
                color: palette.display,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CalcSegmented<NumberBase>(
                            values: NumberBase.values,
                            selected: _base,
                            labelFor: (value) => value.label,
                            compact: true,
                            haptics: widget.session.settings.haptics,
                            onChanged: _switchBase,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CalcPill(
                          label: '${_base.radix}',
                          compact: true,
                          color: palette.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _controller,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        style: CalcTypography.math(palette, size: 18),
                        cursorColor: palette.accent,
                        onChanged: (_) {
                          setState(() {
                            _error = null;
                            _notice = null;
                            _result = null;
                          });
                        },
                        onSubmitted: (_) => _equals(),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'اكتب تعبير BASE-N',
                          hintStyle: TextStyle(color: palette.mathMuted),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _error?.label ??
                          (displayValue == null
                              ? '—'
                              : formatBase(displayValue, _base)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: CalcTypography.math(
                        palette,
                        size: 24,
                        color: _error != null ? palette.danger : palette.accent,
                      ).copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    if (_error != null)
                      Text(
                        '${_error!.hint}${_error!.detail == null ? '' : ' ${_error!.detail}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style:
                            CalcTypography.label(palette, size: 9.5).copyWith(
                          color: palette.danger,
                        ),
                      )
                    else if (_notice != null)
                      Text(
                        _notice!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style:
                            CalcTypography.label(palette, size: 9.5).copyWith(
                          color: palette.mathMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (displayValue != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.isDark
                        ? Colors.black.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.divider),
                  ),
                  child: Row(
                    children: [
                      for (final base in NumberBase.values)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                base.label,
                                style: CalcTypography.label(palette, size: 8)
                                    .copyWith(
                                  color: base == _base
                                      ? palette.accent
                                      : palette.mathMuted,
                                ),
                              ),
                              Text(
                                formatBase(displayValue, base),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CalcTypography.math(
                                  palette,
                                  size: 11,
                                  color: base == _base
                                      ? palette.accent
                                      : palette.math,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              if (compact)
                SizedBox(height: 240, child: _buildKeypad(palette))
              else
                Expanded(child: _buildKeypad(palette)),
              const SizedBox(height: 4),
              const CalcNote(
                text: 'العمليات المنطقية: AND OR XOR XNOR NOT، والإزاحة ≪ ≫. '
                    'الأرقام بتخص الأساس الحالي، والأرقام غير الصالحة بتكون معطلة.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeypad(CalcPalette palette) {
    final rows = <List<(String, String?)>>[
      [('0', '0'), ('1', '1'), ('2', '2'), ('3', '3'), ('4', '4'), ('5', '5')],
      [('6', '6'), ('7', '7'), ('8', '8'), ('9', '9'), ('A', 'A'), ('B', 'B')],
      [('C', 'C'), ('D', 'D'), ('E', 'E'), ('F', 'F'), ('(', '('), (')', ')')],
      [
        ('AND', ' AND '),
        ('OR', ' OR '),
        ('XOR', ' XOR '),
        ('XNOR', ' XNOR '),
        ('NOT', ' NOT '),
        ('MOD', ' MOD '),
      ],
      [
        ('+', '+'),
        ('−', '−'),
        ('×', '×'),
        ('÷', '÷'),
        ('≪', '<<'),
        ('≫', '>>')
      ],
    ];
    Widget key(String label, String? token,
        {CalcKeyTone? tone, VoidCallback? action}) {
      final isDigit =
          label.length == 1 && RegExp(r'^[0-9A-F]$').hasMatch(label);
      final enabled = !isDigit || _digitValid(label);
      return CalcKeyButton(
        haptics: widget.session.settings.haptics,
        fontScale: 0.9,
        spec: CalcKeySpec(
          label: label,
          tone: tone ??
              (isDigit
                  ? CalcKeyTone.basic
                  : (token == null
                      ? CalcKeyTone.clear
                      : CalcKeyTone.operation)),
          semanticLabel:
              isDigit && !enabled ? '$label غير صالح في ${_base.label}' : label,
          onTap: enabled
              ? (action ?? (token == null ? null : () => _insert(token)))
              : null,
        ),
      );
    }

    return Column(
      children: [
        for (var row = 0; row < rows.length; row++) ...[
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < rows[row].length; column++) ...[
                  if (column > 0) const SizedBox(width: 5),
                  Expanded(
                    child: key(rows[row][column].$1, rows[row][column].$2),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 5),
        ],
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: key('DEL', null,
                    tone: CalcKeyTone.delete, action: _backspace),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child: key('AC', null, tone: CalcKeyTone.clear, action: _clear),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 2,
                child:
                    key('=', null, tone: CalcKeyTone.equals, action: _equals),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _digitValid(String digit) {
    final value = int.tryParse(digit, radix: 16);
    return value != null && value < _base.radix;
  }
}
