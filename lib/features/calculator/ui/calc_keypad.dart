/// Casio-style keypad, modifier strip and four-way cursor pad.
library;

import 'package:flutter/material.dart';

import 'calc_palette.dart';
import 'calc_widgets.dart';

class CalcModifierBar extends StatelessWidget {
  const CalcModifierBar({
    super.key,
    required this.shift,
    required this.alpha,
    required this.haptics,
    required this.onShift,
    required this.onAlpha,
    required this.onLeft,
    required this.onRight,
    required this.onUp,
    required this.onDown,
    required this.onSign,
    required this.onSd,
    required this.onSto,
    required this.onRcl,
    required this.onMemoryPlus,
    required this.onFunctions,
  });

  final bool shift;
  final bool alpha;
  final bool haptics;
  final VoidCallback onShift;
  final VoidCallback onAlpha;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onSign;
  final VoidCallback onSd;
  final VoidCallback onSto;
  final VoidCallback onRcl;
  final VoidCallback onMemoryPlus;
  final VoidCallback onFunctions;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 62,
              height: 46,
              child: CalcKeyButton(
                haptics: haptics,
                spec: CalcKeySpec(
                  label: 'SHIFT',
                  tone: CalcKeyTone.shift,
                  active: shift,
                  semanticLabel: shift ? 'إلغاء SHIFT' : 'SHIFT',
                  onTap: onShift,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 62,
              height: 46,
              child: CalcKeyButton(
                haptics: haptics,
                spec: CalcKeySpec(
                  label: 'ALPHA',
                  tone: CalcKeyTone.alpha,
                  active: alpha,
                  semanticLabel: alpha ? 'إلغاء ALPHA' : 'ALPHA',
                  onTap: onAlpha,
                ),
              ),
            ),
            const SizedBox(width: 6),
            CalcDpad(
              onLeft: onLeft,
              onRight: onRight,
              onUp: onUp,
              onDown: onDown,
            ),
            const SizedBox(width: 6),
            CalcSoftButton(
              label: '±',
              compact: true,
              height: 46,
              semanticLabel: 'تغيير الإشارة',
              onPressed: onSign,
              color: palette.label,
            ),
            const SizedBox(width: 6),
            CalcSoftButton(
              label: 'S⇔D',
              compact: true,
              height: 46,
              onPressed: onSd,
              color: palette.accent,
            ),
            const SizedBox(width: 6),
            CalcSoftButton(
              label: 'STO',
              compact: true,
              height: 46,
              onPressed: onSto,
            ),
            const SizedBox(width: 6),
            CalcSoftButton(
              label: 'RCL',
              compact: true,
              height: 46,
              onPressed: onRcl,
            ),
            const SizedBox(width: 6),
            CalcSoftButton(
              label: 'M+',
              compact: true,
              height: 46,
              onPressed: onMemoryPlus,
              color: palette.shift,
            ),
            const SizedBox(width: 6),
            CalcSoftButton(
              label: 'f(x)',
              compact: true,
              height: 46,
              onPressed: onFunctions,
            ),
          ],
        ),
      ),
    );
  }
}

class CalcKeypad extends StatelessWidget {
  const CalcKeypad({
    super.key,
    required this.shift,
    required this.alpha,
    required this.haptics,
    required this.onInsert,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
    required this.onFraction,
  });

  final bool shift;
  final bool alpha;
  final bool haptics;
  final ValueChanged<String> onInsert;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;
  final VoidCallback onFraction;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_PadKey>>[
      <_PadKey>[
        const _PadKey('sin', shiftLabel: 'sin⁻¹', alphaLabel: 'A', normal: 'sin(', shift: 'asin(', alpha: 'A'),
        const _PadKey('cos', shiftLabel: 'cos⁻¹', alphaLabel: 'B', normal: 'cos(', shift: 'acos(', alpha: 'B'),
        const _PadKey('tan', shiftLabel: 'tan⁻¹', alphaLabel: 'C', normal: 'tan(', shift: 'atan(', alpha: 'C'),
        const _PadKey('log', shiftLabel: '10ˣ', alphaLabel: 'D', normal: 'log(', shift: '10^(', alpha: 'D'),
        const _PadKey('ln', shiftLabel: 'eˣ', alphaLabel: 'E', normal: 'ln(', shift: 'e^(', alpha: 'E'),
      ],
      <_PadKey>[
        const _PadKey('x²', shiftLabel: 'x³', alphaLabel: 'F', normal: '²', shift: '³', alpha: 'F', tone: CalcKeyTone.operation),
        const _PadKey('xⁿ', shiftLabel: 'ⁿ√', alphaLabel: 'X', normal: '^', shift: 'root(', alpha: 'X', tone: CalcKeyTone.operation),
        const _PadKey('√', shiftLabel: '∛', alphaLabel: 'Y', normal: '√(', shift: '∛(', alpha: 'Y', tone: CalcKeyTone.operation),
        const _PadKey('(', normal: '(', tone: CalcKeyTone.operation),
        const _PadKey(')', normal: ')', tone: CalcKeyTone.operation),
      ],
      <_PadKey>[
        const _PadKey('a b/c', tone: CalcKeyTone.utility, action: _PadAction.fraction),
        const _PadKey('x⁻¹', normal: '^(-1)', tone: CalcKeyTone.operation),
        const _PadKey('|x|', normal: 'abs(', tone: CalcKeyTone.operation),
        const _PadKey('π', shiftLabel: 'e', alphaLabel: 'θ', normal: 'π', shift: 'e', alpha: 'θ', tone: CalcKeyTone.utility),
        const _PadKey('e', shiftLabel: 'Ans', normal: 'e', shift: 'Ans', tone: CalcKeyTone.utility),
      ],
      <_PadKey>[
        const _PadKey('7', alphaLabel: 'A', normal: '7', alpha: 'A'),
        const _PadKey('8', alphaLabel: 'B', normal: '8', alpha: 'B'),
        const _PadKey('9', alphaLabel: 'C', normal: '9', alpha: 'C'),
        const _PadKey('DEL', tone: CalcKeyTone.delete, action: _PadAction.backspace),
        const _PadKey('AC', tone: CalcKeyTone.clear, action: _PadAction.clear),
      ],
      <_PadKey>[
        const _PadKey('4', alphaLabel: 'D', normal: '4', alpha: 'D'),
        const _PadKey('5', alphaLabel: 'E', normal: '5', alpha: 'E'),
        const _PadKey('6', alphaLabel: 'F', normal: '6', alpha: 'F'),
        const _PadKey('×', normal: '×', tone: CalcKeyTone.operation),
        const _PadKey('÷', normal: '÷', tone: CalcKeyTone.operation),
      ],
      <_PadKey>[
        const _PadKey('1', alphaLabel: 'X', normal: '1', alpha: 'X'),
        const _PadKey('2', alphaLabel: 'Y', normal: '2', alpha: 'Y'),
        const _PadKey('3', alphaLabel: 'θ', normal: '3', alpha: 'θ'),
        const _PadKey('+', normal: '+', tone: CalcKeyTone.operation),
        const _PadKey('−', normal: '−', tone: CalcKeyTone.operation),
      ],
      <_PadKey>[
        const _PadKey('0', normal: '0'),
        const _PadKey('.', normal: '.'),
        const _PadKey('%', shiftLabel: '!', normal: '%', shift: '!', tone: CalcKeyTone.operation),
        const _PadKey('Ans', shiftLabel: '×10ˣ', normal: 'Ans', shift: '×10^(', tone: CalcKeyTone.utility),
        const _PadKey('=', tone: CalcKeyTone.equals, action: _PadAction.equals),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxHeight < 330 ? 4.0 : 6.0;
        final available = constraints.maxHeight - gap * (rows.length - 1);
        final rowHeight = available / rows.length;
        Widget buildRow(List<_PadKey> keys, double scale) {
          return Row(
            children: <Widget>[
              for (var column = 0; column < keys.length; column++) ...<Widget>[
                Expanded(
                  child: CalcKeyButton(
                    haptics: haptics,
                    fontScale: scale,
                    spec: _specFor(keys[column]),
                  ),
                ),
                if (column != keys.length - 1) SizedBox(width: gap),
              ],
            ],
          );
        }

        if (rowHeight < 34) {
          // Short landscape bodies cannot fit seven readable rows. Keep the
          // keys at a usable height and let the pad scroll instead of drawing
          // 12-pixel keys.
          const minimumRow = 44.0;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: <Widget>[
                for (var row = 0; row < rows.length; row++) ...<Widget>[
                  SizedBox(
                    height: minimumRow,
                    child: buildRow(rows[row], 0.9),
                  ),
                  if (row != rows.length - 1) SizedBox(height: gap),
                ],
              ],
            ),
          );
        }
        final fontScale = (rowHeight / 49).clamp(0.82, 1.08);
        return Column(
          children: <Widget>[
            for (var row = 0; row < rows.length; row++) ...<Widget>[
              Expanded(child: buildRow(rows[row], fontScale)),
              if (row != rows.length - 1) SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }

  CalcKeySpec _specFor(_PadKey key) {
    if (key.action != null) {
      return CalcKeySpec(
        label: key.label,
        shiftLabel: key.shiftLabel,
        tone: key.tone,
        semanticLabel: switch (key.action!) {
          _PadAction.fraction => 'إدراج كسر',
          _PadAction.backspace => 'حذف',
          _PadAction.clear => 'مسح الكل',
          _PadAction.equals => 'يساوي',
        },
        onTap: switch (key.action!) {
          _PadAction.fraction => onFraction,
          _PadAction.backspace => onBackspace,
          _PadAction.clear => onClear,
          _PadAction.equals => onEquals,
        },
      );
    }
    final String? token;
    if (shift && key.shift != null) {
      token = key.shift;
    } else if (alpha && key.alpha != null) {
      token = key.alpha;
    } else {
      token = key.normal;
    }
    return CalcKeySpec(
      label: key.label,
      shiftLabel: key.shiftLabel,
      alphaLabel: key.alphaLabel,
      tone: key.tone,
      active: (shift && key.shift != null) || (!shift && alpha && key.alpha != null),
      onTap: token == null ? null : () => onInsert(token!),
    );
  }
}

enum _PadAction { fraction, backspace, clear, equals }

class _PadKey {
  const _PadKey(
    this.label, {
    this.shiftLabel,
    this.alphaLabel,
    this.normal,
    this.shift,
    this.alpha,
    this.tone = CalcKeyTone.basic,
    this.action,
  });

  final String label;
  final String? shiftLabel;
  final String? alphaLabel;
  final String? normal;
  final String? shift;
  final String? alpha;
  final CalcKeyTone tone;
  final _PadAction? action;
}
