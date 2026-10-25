/// Matrix arithmetic up to 4×4 (the class itself is dimension-agnostic) with
/// determinant, inverse, transpose, powers and eigenvalues.
///
/// Eigenvalues are obtained from the characteristic polynomial and are
/// therefore numerical; the result carries a convergence flag.
library;

import 'dart:math' as math;

import 'calculator_error.dart';
import 'math_value.dart';
import 'number_format.dart';
import 'polynomial.dart';

class Matrix {
  Matrix._(this.rows, this.columns, this.values);

  factory Matrix(List<List<double>> rows) {
    if (rows.isEmpty) {
      throw const CalcError(CalcErrorKind.dimension, detail: 'مصفوفة فاضية.');
    }
    final columns = rows.first.length;
    if (columns == 0 || rows.any((row) => row.length != columns)) {
      throw const CalcError(
        CalcErrorKind.dimension,
        detail: 'كل الصفوف لازم يكون لها نفس عدد الأعمدة.',
      );
    }
    return Matrix._(rows.length, columns, [
      for (final row in rows) List<double>.unmodifiable(row),
    ]);
  }

  factory Matrix.identity(int size) => Matrix([
    for (var i = 0; i < size; i++)
      [for (var j = 0; j < size; j++) i == j ? 1.0 : 0.0],
  ]);

  final int rows;
  final int columns;
  final List<List<double>> values;

  bool get isSquare => rows == columns;

  Matrix operator +(Matrix other) {
    _requireSameShape(other);
    return Matrix([
      for (var i = 0; i < rows; i++)
        [for (var j = 0; j < columns; j++) values[i][j] + other.values[i][j]],
    ]);
  }

  Matrix operator -(Matrix other) {
    _requireSameShape(other);
    return Matrix([
      for (var i = 0; i < rows; i++)
        [for (var j = 0; j < columns; j++) values[i][j] - other.values[i][j]],
    ]);
  }

  Matrix operator *(Matrix other) {
    if (columns != other.rows) {
      throw CalcError(
        CalcErrorKind.dimension,
        detail:
            'ضرب ${rows}×$columns في ${other.rows}×${other.columns} مش ممكن.',
      );
    }
    return Matrix([
      for (var i = 0; i < rows; i++)
        [
          for (var j = 0; j < other.columns; j++)
            () {
              var sum = 0.0;
              for (var k = 0; k < columns; k++) {
                sum += values[i][k] * other.values[k][j];
              }
              return sum;
            }(),
        ],
    ]);
  }

  Matrix scale(double factor) => Matrix([
    for (final row in values) [for (final value in row) value * factor],
  ]);

  Matrix transpose() => Matrix([
    for (var j = 0; j < columns; j++)
      [for (var i = 0; i < rows; i++) values[i][j]],
  ]);

  double determinant() {
    if (!isSquare) {
      throw const CalcError(
        CalcErrorKind.dimension,
        detail: 'المحدد يحتاج مصفوفة مربعة.',
      );
    }
    final a = [
      for (final row in values) List<double>.of(row),
    ];
    var result = 1.0;
    for (var column = 0; column < columns; column++) {
      var pivot = column;
      for (var row = column + 1; row < rows; row++) {
        if (a[row][column].abs() > a[pivot][column].abs()) pivot = row;
      }
      if (a[pivot][column].abs() < 1e-14) return 0;
      if (pivot != column) {
        final swap = a[pivot];
        a[pivot] = a[column];
        a[column] = swap;
        result = -result;
      }
      final pivotValue = a[column][column];
      result *= pivotValue;
      for (var row = column + 1; row < rows; row++) {
        final factor = a[row][column] / pivotValue;
        for (var j = column; j < columns; j++) {
          a[row][j] -= factor * a[column][j];
        }
      }
    }
    return result;
  }

  Matrix inverse() {
    if (!isSquare) {
      throw const CalcError(
        CalcErrorKind.dimension,
        detail: 'المعكوس يحتاج مصفوفة مربعة.',
      );
    }
    final augmented = <List<double>>[
      for (var i = 0; i < rows; i++)
        <double>[...values[i], for (var j = 0; j < columns; j++) i == j ? 1.0 : 0.0],
    ];
    for (var column = 0; column < columns; column++) {
      var pivot = column;
      for (var row = column + 1; row < rows; row++) {
        if (augmented[row][column].abs() > augmented[pivot][column].abs()) {
          pivot = row;
        }
      }
      if (augmented[pivot][column].abs() < 1e-12) {
        throw const CalcError(
          CalcErrorKind.math,
          detail: 'المصفوفة مفردة (المحدد = 0) — مفيش معكوس.',
        );
      }
      if (pivot != column) {
        final swap = augmented[pivot];
        augmented[pivot] = augmented[column];
        augmented[column] = swap;
      }
      final pivotValue = augmented[column][column];
      for (var j = 0; j < 2 * columns; j++) {
        augmented[column][j] /= pivotValue;
      }
      for (var row = 0; row < rows; row++) {
        if (row == column) continue;
        final factor = augmented[row][column];
        if (factor.abs() < 1e-15) continue;
        for (var j = 0; j < 2 * columns; j++) {
          augmented[row][j] -= factor * augmented[column][j];
        }
      }
    }
    return Matrix([
      for (var i = 0; i < rows; i++) augmented[i].sublist(columns),
    ]);
  }

  Matrix power(int exponent) {
    if (!isSquare) {
      throw const CalcError(CalcErrorKind.dimension);
    }
    if (exponent < 0) {
      return inverse().power(-exponent);
    }
    var result = Matrix.identity(rows);
    var base = this;
    var remaining = exponent;
    while (remaining > 0) {
      if (remaining.isOdd) result = result * base;
      base = base * base;
      remaining >>= 1;
    }
    return result;
  }

  double get trace {
    if (!isSquare) throw const CalcError(CalcErrorKind.dimension);
    var sum = 0.0;
    for (var i = 0; i < rows; i++) {
      sum += values[i][i];
    }
    return sum;
  }

  /// Eigenvalues via the Faddeev–LeVerrier characteristic polynomial.
  PolynomialRootResult eigenvalues() {
    if (!isSquare) {
      throw const CalcError(
        CalcErrorKind.dimension,
        detail: 'القيم الذاتية تحتاج مصفوفة مربعة.',
      );
    }
    if (rows == 1) {
      return PolynomialRootResult(
        roots: <ComplexRoot>[
          ComplexRoot(values[0][0], 0, exactReal: _hint(values[0][0])),
        ],
        converged: true,
      );
    }
    // Faddeev–LeVerrier.
    var b = Matrix.identity(rows);
    final coefficients = <double>[1];
    for (var k = 1; k <= rows; k++) {
      final ab = this * b;
      final c = -ab.trace / k;
      coefficients.add(c);
      b = ab + Matrix.identity(rows).scale(c);
    }
    final result = polynomialRoots(coefficients);
    return result;
  }

  static Rational? _hint(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 1e-10) {
      return Rational.fromInt(rounded.toInt());
    }
    return null;
  }

  String format({int? fix}) {
    final formatted = [
      for (final row in values)
        [for (final value in row) formatReal(value, fix: fix)],
    ];
    final widths = <int>[
      for (var j = 0; j < columns; j++)
        formatted.map((row) => row[j].length).fold<int>(0, math.max),
    ];
    return formatted
        .map(
          (row) => [
            for (var j = 0; j < columns; j++)
              row[j].padLeft(widths[j]),
          ].join('   '),
        )
        .join('\n');
  }

  String toSource() => values
      .map((row) => row.map((value) => formatReal(value)).join(' '))
      .join('\n');

  void _requireSameShape(Matrix other) {
    if (rows != other.rows || columns != other.columns) {
      throw CalcError(
        CalcErrorKind.dimension,
        detail:
            'الأبعاد مختلفة: ${rows}×$columns و${other.rows}×${other.columns}.',
      );
    }
  }
}
