/// 2D/3D vector arithmetic with explicit dimension checks.
library;

import 'dart:math' as math;

import 'calculator_error.dart';
import 'number_format.dart';

class VectorValue {
  VectorValue(List<double> components)
    : components = List<double>.unmodifiable(components) {
    if (components.length < 2 || components.length > 3) {
      throw const CalcError(
        CalcErrorKind.dimension,
        detail: 'المتجه لازم يكون 2 أو 3 أبعاد.',
      );
    }
    if (components.any((value) => !value.isFinite)) {
      throw const CalcError(CalcErrorKind.math);
    }
  }

  final List<double> components;

  int get dimension => components.length;

  double operator [](int index) => components[index];

  double get norm => math.sqrt(
    components.fold<double>(0, (sum, value) => sum + value * value),
  );

  VectorValue get normalized {
    final length = norm;
    if (length == 0) {
      throw const CalcError(
        CalcErrorKind.math,
        detail: 'متجه الصفر ملهوش اتجاه.',
      );
    }
    return VectorValue([for (final value in components) value / length]);
  }

  VectorValue operator +(VectorValue other) {
    _sameDimension(other);
    return VectorValue([
      for (var i = 0; i < dimension; i++) components[i] + other[i],
    ]);
  }

  VectorValue operator -(VectorValue other) {
    _sameDimension(other);
    return VectorValue([
      for (var i = 0; i < dimension; i++) components[i] - other[i],
    ]);
  }

  VectorValue scale(double factor) =>
      VectorValue([for (final value in components) value * factor]);

  double dot(VectorValue other) {
    _sameDimension(other);
    var sum = 0.0;
    for (var i = 0; i < dimension; i++) {
      sum += components[i] * other[i];
    }
    return sum;
  }

  VectorValue cross(VectorValue other) {
    if (dimension != 3 || other.dimension != 3) {
      throw const CalcError(
        CalcErrorKind.dimension,
        detail: 'الضرب الاتجاهي متاح للمتجهات 3D فقط.',
      );
    }
    return VectorValue(<double>[
      components[1] * other[2] - components[2] * other[1],
      components[2] * other[0] - components[0] * other[2],
      components[0] * other[1] - components[1] * other[0],
    ]);
  }

  /// Angle between two vectors in degrees.
  double angleBetween(VectorValue other) {
    _sameDimension(other);
    final denominator = norm * other.norm;
    if (denominator == 0) {
      throw const CalcError(CalcErrorKind.math, detail: 'متجه صفري.');
    }
    final cosine = (dot(other) / denominator).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }

  VectorValue projectionOnto(VectorValue other) {
    final denominator = other.dot(other);
    if (denominator == 0) {
      throw const CalcError(CalcErrorKind.math, detail: 'الإسقاط على متجه صفري.');
    }
    return other.scale(dot(other) / denominator);
  }

  String format() =>
      '(${components.map((value) => formatReal(value)).join(', ')})';

  void _sameDimension(VectorValue other) {
    if (dimension != other.dimension) {
      throw CalcError(
        CalcErrorKind.dimension,
        detail: 'المتجهات بأبعاد مختلفة ($dimension و${other.dimension}).',
      );
    }
  }
}
