/// BASE-N conversion and bitwise arithmetic on arbitrary-precision integers.
///
/// Unlike the fixed-width 32-bit BASE-N of a physical calculator, this engine
/// keeps every bit the user enters. Results of bitwise NOT therefore use the
/// mathematical two's-complement identity `~x = -x - 1` and are shown with a
/// sign instead of silently wrapping at 32 bits.
library;

import 'calculator_error.dart';

enum NumberBase {
  binary('BIN', 2),
  octal('OCT', 8),
  decimal('DEC', 10),
  hexadecimal('HEX', 16);

  const NumberBase(this.label, this.radix);

  final String label;
  final int radix;

  static NumberBase? byRadix(int radix) {
    for (final base in NumberBase.values) {
      if (base.radix == radix) return base;
    }
    return null;
  }
}

BigInt parseBase(String source, NumberBase base) {
  var text = source.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) {
    throw const CalcError(CalcErrorKind.syntax, detail: 'اكتب رقم أولًا.');
  }
  // Accept the common programming prefixes when they match the selected base.
  if (text.startsWith('0X') && base == NumberBase.hexadecimal) {
    text = text.substring(2);
  } else if (text.startsWith('0B') && base == NumberBase.binary) {
    text = text.substring(2);
  } else if (text.startsWith('0O') && base == NumberBase.octal) {
    text = text.substring(2);
  }
  var sign = BigInt.one;
  if (text.startsWith('-')) {
    sign = -BigInt.one;
    text = text.substring(1);
  } else if (text.startsWith('+')) {
    text = text.substring(1);
  }
  if (text.isEmpty || text == '.') {
    throw const CalcError(CalcErrorKind.syntax, detail: 'رقم غير مكتمل.');
  }
  final digits = <int>[];
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final value = _digitValue(char);
    if (value < 0 || value >= base.radix) {
      throw CalcError(
        CalcErrorKind.syntax,
        detail: 'الرقم «$char» مش صالح في ${base.label}.',
      );
    }
    digits.add(value);
  }
  var result = BigInt.zero;
  final radix = BigInt.from(base.radix);
  for (final digit in digits) {
    result = result * radix + BigInt.from(digit);
  }
  return result * sign;
}

String formatBase(
  BigInt value,
  NumberBase base, {
  bool group = true,
  bool upperCase = true,
}) {
  var text = value.abs().toRadixString(base.radix);
  if (upperCase) text = text.toUpperCase();
  if (group && base != NumberBase.decimal && text.length > 4) {
    final groups = <String>[];
    for (var end = text.length; end > 0; end -= 4) {
      groups.insert(0, text.substring((end - 4).clamp(0, text.length), end));
    }
    text = groups.join(' ');
  }
  return value.isNegative ? '-$text' : text;
}

int _digitValue(String char) {
  final code = char.codeUnitAt(0);
  if (code >= 0x30 && code <= 0x39) return code - 0x30;
  if (code >= 0x41 && code <= 0x46) return code - 0x41 + 10;
  return -1;
}

enum BaseOperation {
  add('+'),
  subtract('−'),
  multiply('×'),
  divide('÷'),
  and('AND'),
  or('OR'),
  xor('XOR'),
  xnor('XNOR'),
  not('NOT'),
  shiftLeft('≪'),
  shiftRight('≫'),
  mod('MOD');

  const BaseOperation(this.label);

  final String label;

  bool get needsSecondOperand => this != BaseOperation.not;
}

BigInt applyBaseOperation(
  BigInt left,
  BigInt? right,
  BaseOperation operation,
) {
  if (operation == BaseOperation.not) return ~left;
  if (right == null) {
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'العملية محتاجة رقمين.',
    );
  }
  switch (operation) {
    case BaseOperation.add:
      return left + right;
    case BaseOperation.subtract:
      return left - right;
    case BaseOperation.multiply:
      return left * right;
    case BaseOperation.divide:
      if (right == BigInt.zero) {
        throw const CalcError(CalcErrorKind.math, detail: 'قسمة على صفر.');
      }
      return left ~/ right;
    case BaseOperation.mod:
      if (right == BigInt.zero) {
        throw const CalcError(CalcErrorKind.math, detail: 'قسمة على صفر.');
      }
      return left.remainder(right);
    case BaseOperation.and:
      return left & right;
    case BaseOperation.or:
      return left | right;
    case BaseOperation.xor:
      return left ^ right;
    case BaseOperation.xnor:
      return ~(left ^ right);
    case BaseOperation.shiftLeft:
      final shift = right.toInt();
      if (shift.abs() > 100000) {
        throw const CalcError(CalcErrorKind.math, detail: 'الإزاحة كبيرة.');
      }
      return left << shift;
    case BaseOperation.shiftRight:
      final shift = right.toInt();
      if (shift.abs() > 100000) {
        throw const CalcError(CalcErrorKind.math, detail: 'الإزاحة كبيرة.');
      }
      return left >> shift;
    case BaseOperation.not:
      return ~left;
  }
}
