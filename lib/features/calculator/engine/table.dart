/// Function value tables for TABLE mode.
library;

import 'calculator_error.dart';
import 'evaluator.dart';
import 'math_value.dart';
import 'number_format.dart';
import 'parser.dart';

class TableRow {
  const TableRow(this.x, this.value, {this.formatted = 'ERROR'});

  final double x;
  final EvalValue? value;
  final String formatted;
}

class TableResult {
  const TableResult({
    required this.rows,
    required this.step,
    this.truncated = false,
  });

  final List<TableRow> rows;
  final double step;
  final bool truncated;
}

TableResult buildTable(
  String source, {
  required double start,
  required double end,
  required double step,
  AngleUnit angleUnit = AngleUnit.degrees,
  int maximumRows = 100,
}) {
  if (step == 0) {
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'خطوة الجدول لا تساوي صفر.',
    );
  }
  if (!start.isFinite || !end.isFinite) {
    throw const CalcError(CalcErrorKind.argument);
  }
  final expression = parseExpression(source);
  final context = EvalContext(angleUnit: angleUnit);
  final rows = <TableRow>[];
  final ascending = step > 0;
  if (ascending ? end < start : end > start) {
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'اتجاه الخطوة مش مناسب للبداية والنهاية.',
    );
  }

  var x = start;
  var iterations = 0;
  while ((ascending ? x <= end + step.abs() * 1e-9 : x >= end - step.abs() * 1e-9) &&
      iterations < maximumRows) {
    final roundedX = double.parse(x.toStringAsPrecision(14));
    context.variables['x'] = EvalValue.real(roundedX);
    EvalValue? value;
    String formatted;
    try {
      final evaluated = Evaluator(context).evaluate(expression);
      value = evaluated;
      formatted = formatCalcValue(evaluated).display;
    } on CalcError catch (error) {
      formatted = error.label;
    }
    rows.add(TableRow(roundedX, value, formatted: formatted));
    x += step;
    iterations++;
  }
  final reachedEnd = ascending ? x > end : x < end;
  return TableResult(
    rows: rows,
    step: step,
    truncated: !reachedEnd && rows.length >= maximumRows,
  );
}
