/// Names and arities of the functions understood by the calculator.
library;

import 'calculator_error.dart';

/// A function's accepted number of arguments.
class FunctionArity {
  const FunctionArity(this.minimum, [int? maximum]) : maximum = maximum ?? minimum;

  final int minimum;
  final int maximum;

  bool accepts(int count) => count >= minimum && count <= maximum;
}

const Map<String, FunctionArity> functionArities = <String, FunctionArity>{
  'sin': FunctionArity(1),
  'cos': FunctionArity(1),
  'tan': FunctionArity(1),
  'asin': FunctionArity(1),
  'acos': FunctionArity(1),
  'atan': FunctionArity(1),
  'arcsin': FunctionArity(1),
  'arccos': FunctionArity(1),
  'arctan': FunctionArity(1),
  'sinh': FunctionArity(1),
  'cosh': FunctionArity(1),
  'tanh': FunctionArity(1),
  'asinh': FunctionArity(1),
  'acosh': FunctionArity(1),
  'atanh': FunctionArity(1),
  'log': FunctionArity(1, 2),
  'ln': FunctionArity(1),
  'sqrt': FunctionArity(1),
  'cbrt': FunctionArity(1),
  'root': FunctionArity(2),
  'abs': FunctionArity(1),
  'exp': FunctionArity(1),
  'floor': FunctionArity(1),
  'ceil': FunctionArity(1),
  'round': FunctionArity(1),
  'sign': FunctionArity(1),
  'arg': FunctionArity(1),
  'conj': FunctionArity(1),
  're': FunctionArity(1),
  'im': FunctionArity(1),
  'gcd': FunctionArity(2),
  'lcm': FunctionArity(2),
  'ncr': FunctionArity(2),
  'npr': FunctionArity(2),
  'min': FunctionArity(1, 8),
  'max': FunctionArity(1, 8),
  'sum': FunctionArity(4),
  'product': FunctionArity(4),
  'integral': FunctionArity(4),
  'diff': FunctionArity(3),
  'rand': FunctionArity(0, 1),
  'hypot': FunctionArity(2),
};

const Set<String> knownFunctionNames = {
  'sin',
  'cos',
  'tan',
  'asin',
  'acos',
  'atan',
  'arcsin',
  'arccos',
  'arctan',
  'sinh',
  'cosh',
  'tanh',
  'asinh',
  'acosh',
  'atanh',
  'log',
  'ln',
  'sqrt',
  'cbrt',
  'root',
  'abs',
  'exp',
  'floor',
  'ceil',
  'round',
  'sign',
  'arg',
  'conj',
  're',
  'im',
  'gcd',
  'lcm',
  'ncr',
  'npr',
  'min',
  'max',
  'sum',
  'product',
  'integral',
  'diff',
  'rand',
  'hypot',
};

void validateFunctionArity(String name, int count) {
  final arity = functionArities[name];
  if (arity != null && !arity.accepts(count)) {
    throw CalcError(
      CalcErrorKind.argument,
      detail: '$name expects ${arity.minimum == arity.maximum ? arity.minimum : '${arity.minimum}–${arity.maximum}'} argument(s), got $count',
    );
  }
}
