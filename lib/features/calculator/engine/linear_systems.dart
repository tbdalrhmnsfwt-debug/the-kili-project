/// Simultaneous linear equations (2×2 through 4×4) with honest handling of
/// singular, inconsistent and under-determined systems.
library;

import 'dart:math' as math;

enum LinearSolutionKind { unique, infinite, none }

class LinearSolution {
  const LinearSolution._(
    this.kind, {
    this.values = const <double>[],
    this.freeVariables = 0,
    this.message,
  });

  final LinearSolutionKind kind;
  final List<double> values;
  final int freeVariables;
  final String? message;

  bool get hasUniqueSolution => kind == LinearSolutionKind.unique;
}

/// Solves `matrix · x = rhs` using Gaussian elimination with partial pivoting.
LinearSolution solveLinearSystem(
  List<List<double>> matrix,
  List<double> rhs,
) {
  final n = matrix.length;
  if (n == 0 || rhs.length != n || matrix.any((row) => row.length != n)) {
    return const LinearSolution._(
      LinearSolutionKind.none,
      message: 'أبعاد النظام غير متوافقة.',
    );
  }

  final scale = matrix
      .expand((row) => row)
      .fold<double>(1, (value, element) => math.max(value, element.abs()));
  final tolerance = 1e-12 * scale;

  final a = <List<double>>[
    for (var i = 0; i < n; i++) <double>[...matrix[i], rhs[i]],
  ];

  var rank = 0;
  final pivotColumns = <int>[];
  for (var column = 0; column < n && rank < n; column++) {
    var pivot = rank;
    for (var row = rank + 1; row < n; row++) {
      if (a[row][column].abs() > a[pivot][column].abs()) pivot = row;
    }
    if (a[pivot][column].abs() <= tolerance) continue;
    final swap = a[rank];
    a[rank] = a[pivot];
    a[pivot] = swap;

    final pivotValue = a[rank][column];
    for (var j = column; j <= n; j++) {
      a[rank][j] /= pivotValue;
    }
    for (var row = 0; row < n; row++) {
      if (row == rank) continue;
      final factor = a[row][column];
      if (factor.abs() <= tolerance) continue;
      for (var j = column; j <= n; j++) {
        a[row][j] -= factor * a[rank][j];
      }
    }
    pivotColumns.add(column);
    rank++;
  }

  for (var row = rank; row < n; row++) {
    final left = a[row].sublist(0, n).every((value) => value.abs() <= tolerance);
    if (left && a[row][n].abs() > tolerance) {
      return const LinearSolution._(
        LinearSolutionKind.none,
        message: 'النظام غير متسق — مفيش حل مشترك.',
      );
    }
  }

  if (rank < n) {
    return LinearSolution._(
      LinearSolutionKind.infinite,
      freeVariables: n - rank,
      message:
          'في ${n - rank} متغير حر — النظام له عدد لا نهائي من الحلول.',
    );
  }

  final values = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    values[pivotColumns[i]] = a[i][n];
  }
  return LinearSolution._(LinearSolutionKind.unique, values: values);
}

/// Formats the solution values for the EQN result card.
String formatLinearSolution(LinearSolution solution, List<String> names) {
  if (!solution.hasUniqueSolution) {
    return solution.message ?? 'مفيش حل وحيد.';
  }
  return [
    for (var i = 0; i < solution.values.length; i++)
      '${names.length > i ? names[i] : 'x${i + 1}'} = ${_format(solution.values[i])}',
  ].join('\n');
}

String _format(double value) {
  if (value.abs() < 1e-12) return '0';
  final text = value.toStringAsPrecision(12);
  if (!text.contains('e') && text.contains('.')) {
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
