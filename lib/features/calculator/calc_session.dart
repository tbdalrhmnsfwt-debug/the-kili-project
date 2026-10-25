/// Mutable state shared by all calculator modes.
///
/// History, preferences and memory are owned by the shell so switching from
/// COMP to MATRIX and back never loses the session. The engine values remain
/// exact where possible; persistence encodes them without going through a
/// lossy UI string.
library;

import 'calc_history.dart';
import 'calc_settings.dart';
import 'engine/evaluator.dart';
import 'engine/math_value.dart';
import 'engine/number_format.dart';

class CalcSession {
  CalcSession({
    this.settings = const CalcSettings(),
    List<CalcHistoryEntry>? history,
    EvalValue? answer,
    EvalValue? memory,
  })  : history = history ?? <CalcHistoryEntry>[],
        answer = answer ?? EvalValue.integer(0),
        memory = memory ?? EvalValue.integer(0);

  CalcSettings settings;

  /// Newest first, capped at [CalcHistory.maximumEntries].
  final List<CalcHistoryEntry> history;

  EvalValue answer;
  EvalValue memory;

  /// Casio A–F, X, Y and θ.
  final Map<String, EvalValue> variables = <String, EvalValue>{};

  static const List<String> variableNames = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'X',
    'Y',
    'θ',
  ];

  bool get memoryActive => !memory.isZero;

  String get memoryDisplay => formatCalcValue(memory).display;

  void record(CalcHistoryEntry entry) {
    history.insert(0, entry);
    if (history.length > CalcHistory.maximumEntries) {
      history.removeRange(CalcHistory.maximumEntries, history.length);
    }
  }

  void removeHistory(String id) {
    history.removeWhere((entry) => entry.id == id);
  }

  void clearHistory() => history.clear();

  ValueFormat format(
    EvalValue value, {
    bool complex = false,
    bool forceDecimal = false,
    bool forceExact = false,
  }) {
    return formatCalcValue(
      value,
      preferExact: forceDecimal
          ? false
          : (forceExact ? true : settings.preferExact),
      mixed: settings.mixedFractions,
      polar: complex && settings.polarComplex,
      angleUnit: settings.angleUnit,
      // FIX rounds decimal results, but S⇔D must still be able to show the
      // exact fraction, so the exact override bypasses FIX.
      fix: forceExact ? null : settings.fix,
    );
  }

  static String encodeValue(EvalValue value) {
    final exact = value.exact;
    if (exact != null) return 'r:${exact.numerator}/${exact.denominator}';
    if (value.isReal) return 'd:${value.realPart}';
    return 'c:${value.realPart}:${value.imaginaryPart}';
  }

  static EvalValue decodeValue(String? raw) {
    if (raw == null || raw.isEmpty) return EvalValue.integer(0);
    if (raw.startsWith('r:')) {
      final parts = raw.substring(2).split('/');
      if (parts.length == 2) {
        final numerator = BigInt.tryParse(parts[0]);
        final denominator = BigInt.tryParse(parts[1]);
        if (numerator != null && denominator != null && denominator != BigInt.zero) {
          return EvalValue.exact(Rational(numerator, denominator));
        }
      }
      return EvalValue.integer(0);
    }
    if (raw.startsWith('d:')) {
      final value = double.tryParse(raw.substring(2));
      return value == null || !value.isFinite
          ? EvalValue.integer(0)
          : EvalValue.real(value);
    }
    if (raw.startsWith('c:')) {
      final parts = raw.substring(2).split(':');
      if (parts.length == 2) {
        final real = double.tryParse(parts[0]);
        final imaginary = double.tryParse(parts[1]);
        if (real != null && imaginary != null && real.isFinite && imaginary.isFinite) {
          return EvalValue.complex(real, imaginary);
        }
      }
    }
    return EvalValue.integer(0);
  }

  EvalContext contextFor({
    bool complex = false,
    String extraVariable = 'x',
    double? extraValue,
  }) {
    final context = EvalContext(
      angleUnit: settings.angleUnit,
      answer: answer,
      allowComplex: complex,
      variables: variables,
    );
    if (extraValue != null) {
      context.variables[extraVariable] = EvalValue.real(extraValue);
    }
    return context;
  }
}
