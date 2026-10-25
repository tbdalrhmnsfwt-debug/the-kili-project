/// A deliberately small, honest computer-algebra layer.
///
/// Supported exactly:
///   * simplification of arithmetic, identities and single-variable
///     polynomials over the rationals;
///   * symbolic differentiation of +, −, ×, ÷, powers, roots and the common
///     elementary functions;
///   * polynomial factoring over the rationals;
///   * indefinite integration of polynomials.
///
/// Anything outside that subset raises [CalcErrorKind.unsupported] instead of
/// returning a made-up answer. The UI also offers numerical definite
/// integration and numerical differentiation, which are clearly approximate.
library;

import 'ast.dart';
import 'calculator_error.dart';
import 'math_value.dart';
import 'parser.dart';
import 'polynomial.dart';

class CasResult {
  const CasResult(this.expression, {required this.supported, this.noteAr = ''});

  final String expression;
  final bool supported;
  final String noteAr;
}

class CasEngine {
  const CasEngine();

  String simplify(String source) {
    final expression = parseExpression(source);
    return _simplifiedSource(expression);
  }

  CasResult differentiate(
    String source,
    String variable, {
    bool simplifyResult = true,
  }) {
    final expression = parseExpression(source);
    final derivative = _derivative(expression, variable);
    final simplified = simplifyResult ? _simplify(derivative) : derivative;
    return CasResult(
      _printWithPolynomial(simplified),
      supported: true,
      noteAr: simplifyResult ? '' : 'المشتقة قبل التبسيط.',
    );
  }

  CasResult integrate(String source, String variable) {
    final coefficients = polynomialCoefficients(parseExpression(source), variable);
    if (coefficients == null) {
      throw const CalcError(
        CalcErrorKind.unsupported,
        detail:
            'التكامل الرمزي هنا بيدعم كثيرات الحدود فقط. استخدم التكامل العددي المحدد للدوال التانية.',
      );
    }
    final degree = coefficients.length - 1;
    final integrated = <Rational>[
      for (var i = 0; i < coefficients.length; i++)
        coefficients[i] / Rational.fromInt(degree - i + 1),
      Rational.zero,
    ];
    return CasResult(
      '${formatPolynomial(integrated, variable)} + C',
      supported: true,
      noteAr: 'ثابت التكامل C مش معروف من التعبير.',
    );
  }

  CasResult factor(String source, {String variable = 'x'}) {
    final coefficients = polynomialCoefficients(parseExpression(source), variable);
    if (coefficients == null) {
      throw const CalcError(
        CalcErrorKind.unsupported,
        detail: 'التحليل هنا بيدعم كثيرات الحدود في متغير واحد.',
      );
    }
    final factored = factorPolynomial(coefficients, variable);
    return CasResult(
      factored,
      supported: true,
      noteAr: 'تحليل على الأعداد النسبية فقط.',
    );
  }

  String _simplifiedSource(Expr expression) {
    final simplified = _simplify(expression);
    return _printWithPolynomial(simplified);
  }

  String _printWithPolynomial(Expr expression) {
    final variables = exprVariables(expression);
    if (variables.length == 1) {
      final variable = variables.first;
      final coefficients = polynomialCoefficients(expression, variable);
      if (coefficients != null) {
        return formatPolynomial(coefficients, variable);
      }
    }
    return _print(expression);
  }

  Expr _simplify(Expr expression) {
    switch (expression) {
      case LiteralExpr() || VariableExpr() || ConstantExpr():
        return expression;
      case UnaryExpr():
        final operand = _simplify(expression.operand);
        if (operand is LiteralExpr) {
          switch (expression.operator) {
            case '-':
              return _literal(-operand.value);
            case '+':
              return operand;
            case '%':
              return _literal(operand.value / Rational.fromInt(100));
          }
        }
        if (expression.operator == '-' && operand is UnaryExpr && operand.operator == '-') {
          return operand.operand;
        }
        if (expression.operator == '+') return operand;
        return UnaryExpr(expression.operator, operand);
      case BinaryExpr():
        final left = _simplify(expression.left);
        final right = _simplify(expression.right);
        if (left is LiteralExpr && right is LiteralExpr) {
          final folded = _foldBinary(expression.operator, left.value, right.value);
          if (folded != null) return _literal(folded);
        }
        final zero = Rational.zero;
        final one = Rational.one;
        switch (expression.operator) {
          case '+':
            if (_isNumber(left, zero)) return right;
            if (_isNumber(right, zero)) return left;
          case '-':
            if (_isNumber(right, zero)) return left;
            if (_isNumber(left, zero)) return UnaryExpr('-', right);
          case '*':
            if (_isNumber(left, zero) || _isNumber(right, zero)) {
              return _literal(zero);
            }
            if (_isNumber(left, one)) return right;
            if (_isNumber(right, one)) return left;
            if (_isNumber(left, Rational.fromInt(-1))) return UnaryExpr('-', right);
            if (_isNumber(right, Rational.fromInt(-1))) return UnaryExpr('-', left);
            if (_same(left, right)) {
              return BinaryExpr('^', left, _literal(Rational.two));
            }
          case '/':
            if (_isNumber(left, zero)) return _literal(zero);
            if (_isNumber(right, one)) return left;
            if (_same(left, right)) return _literal(one);
          case '^':
            if (_isNumber(right, zero)) return _literal(one);
            if (_isNumber(right, one)) return left;
            if (_isNumber(left, one)) return _literal(one);
            if (_isNumber(left, zero) && _isPositiveNumber(right)) {
              return _literal(zero);
            }
        }
        return BinaryExpr(expression.operator, left, right);
      case PostfixExpr():
        final operand = _simplify(expression.operand);
        if (operand is LiteralExpr && expression.operator == '%') {
          return _literal(operand.value / Rational.fromInt(100));
        }
        return PostfixExpr(expression.operator, operand);
      case FunctionExpr():
        final arguments = [
          for (final argument in expression.arguments) _simplify(argument),
        ];
        return FunctionExpr(expression.name, arguments);
    }
  }

  Rational? _foldBinary(String operator, Rational left, Rational right) {
    try {
      switch (operator) {
        case '+':
          return left + right;
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          return right.isZero ? null : left / right;
        case '^':
          if (right.isInteger) {
            final exponent = right.toInt();
            if (exponent != null && exponent.abs() <= 10000) {
              return left.pow(exponent);
            }
          }
      }
    } on DivisionByZero {
      return null;
    }
    return null;
  }

  LiteralExpr _literal(Rational value) =>
      LiteralExpr(value, raw: value.toString());

  bool _isNumber(Expr expression, Rational value) =>
      expression is LiteralExpr && expression.value == value;

  bool _isPositiveNumber(Expr expression) =>
      expression is LiteralExpr && expression.value.isPositive;

  bool _same(Expr left, Expr right) => _print(left) == _print(right);

  Expr _derivative(Expr expression, String variable) {
    switch (expression) {
      case LiteralExpr() || ConstantExpr():
        return _literal(Rational.zero);
      case VariableExpr():
        return _literal(
          expression.name == variable ? Rational.one : Rational.zero,
        );
      case UnaryExpr():
        final inner = _derivative(expression.operand, variable);
        switch (expression.operator) {
          case '+':
            return inner;
          case '-':
            return UnaryExpr('-', inner);
          case '%':
            return BinaryExpr('/', inner, _literal(Rational.fromInt(100)));
        }
        throw CalcError(
          CalcErrorKind.unsupported,
          detail: 'مشتقة العملية ${expression.operator} مش مدعومة.',
        );
      case BinaryExpr():
        final u = expression.left;
        final v = expression.right;
        final du = _derivative(u, variable);
        final dv = _derivative(v, variable);
        switch (expression.operator) {
          case '+':
            return BinaryExpr('+', du, dv);
          case '-':
            return BinaryExpr('-', du, dv);
          case '*':
            return BinaryExpr(
              '+',
              BinaryExpr('*', du, v),
              BinaryExpr('*', u, dv),
            );
          case '/':
            return BinaryExpr(
              '/',
              BinaryExpr(
                '-',
                BinaryExpr('*', du, v),
                BinaryExpr('*', u, dv),
              ),
              BinaryExpr('^', v, _literal(Rational.two)),
            );
          case '^':
            final exponentIsConstant = !_dependsOn(v, variable);
            final baseIsConstant = !_dependsOn(u, variable);
            if (baseIsConstant && exponentIsConstant) {
              return _literal(Rational.zero);
            }
            if (exponentIsConstant) {
              return BinaryExpr(
                '*',
                BinaryExpr(
                  '*',
                  v,
                  BinaryExpr(
                    '^',
                    u,
                    BinaryExpr('-', v, _literal(Rational.one)),
                  ),
                ),
                du,
              );
            }
            if (baseIsConstant) {
              return BinaryExpr(
                '*',
                BinaryExpr(
                  '*',
                  expression,
                  FunctionExpr('ln', <Expr>[u]),
                ),
                dv,
              );
            }
            return BinaryExpr(
              '*',
              expression,
              BinaryExpr(
                '+',
                BinaryExpr('*', dv, FunctionExpr('ln', <Expr>[u])),
                BinaryExpr(
                  '/',
                  BinaryExpr('*', v, du),
                  u,
                ),
              ),
            );
        }
        throw CalcError(
          CalcErrorKind.unsupported,
          detail: 'مشتقة ${expression.operator} مش مدعومة.',
        );
      case PostfixExpr():
        // x² and x³ are the keypad's shorthand for powers, so differentiate
        // them through the same power rule instead of rejecting them.
        final exponent = switch (expression.operator) {
          '²' => Rational.two,
          '³' => Rational.fromInt(3),
          _ => null,
        };
        if (exponent != null) {
          return _derivative(
            BinaryExpr('^', expression.operand, _literal(exponent)),
            variable,
          );
        }
        throw CalcError(
          CalcErrorKind.unsupported,
          detail: 'المشتقة الرمزية للعمليات ! و%% غير مدعومة.',
        );
      case FunctionExpr():
        if (expression.arguments.length != 1) {
          throw const CalcError(
            CalcErrorKind.unsupported,
            detail: 'الدوال متعددة الوسائط مش مدعومة في المشتقة الرمزية.',
          );
        }
        final argument = expression.arguments.first;
        final inner = _derivative(argument, variable);
        final name = expression.name.toLowerCase();
        final function = FunctionExpr(name, <Expr>[argument]);
        final chain = switch (name) {
          'sin' => FunctionExpr('cos', <Expr>[argument]),
          'cos' => UnaryExpr('-', FunctionExpr('sin', <Expr>[argument])),
          'tan' => BinaryExpr(
            '/',
            _literal(Rational.one),
            BinaryExpr(
              '^',
              FunctionExpr('cos', <Expr>[argument]),
              _literal(Rational.two),
            ),
          ),
          'sinh' => FunctionExpr('cosh', <Expr>[argument]),
          'cosh' => FunctionExpr('sinh', <Expr>[argument]),
          'tanh' => BinaryExpr(
            '/',
            _literal(Rational.one),
            BinaryExpr(
              '^',
              FunctionExpr('cosh', <Expr>[argument]),
              _literal(Rational.two),
            ),
          ),
          'ln' => BinaryExpr(
            '/',
            _literal(Rational.one),
            argument,
          ),
          'log' => BinaryExpr(
            '/',
            _literal(Rational.one),
            BinaryExpr(
              '*',
              argument,
              FunctionExpr('ln', <Expr>[_literal(Rational.fromInt(10))]),
            ),
          ),
          'sqrt' => BinaryExpr(
            '/',
            _literal(Rational.one),
            BinaryExpr(
              '*',
              _literal(Rational.fromInt(2)),
              function,
            ),
          ),
          'exp' => function,
          'asin' => BinaryExpr(
            '/',
            _literal(Rational.one),
            FunctionExpr(
              'sqrt',
              <Expr>[
                BinaryExpr(
                  '-',
                  _literal(Rational.one),
                  BinaryExpr('^', argument, _literal(Rational.two)),
                ),
              ],
            ),
          ),
          'acos' => UnaryExpr(
            '-',
            BinaryExpr(
              '/',
              _literal(Rational.one),
              FunctionExpr(
                'sqrt',
                <Expr>[
                  BinaryExpr(
                    '-',
                    _literal(Rational.one),
                    BinaryExpr('^', argument, _literal(Rational.two)),
                  ),
                ],
              ),
            ),
          ),
          'atan' => BinaryExpr(
            '/',
            _literal(Rational.one),
            BinaryExpr(
              '+',
              _literal(Rational.one),
              BinaryExpr('^', argument, _literal(Rational.two)),
            ),
          ),
          'abs' => FunctionExpr('sign', <Expr>[argument]),
          _ => null,
        };
        if (chain == null) {
          throw CalcError(
            CalcErrorKind.unsupported,
            detail: 'مشتقة الدالة $name مش مدعومة رمزيًا.',
          );
        }
        return BinaryExpr('*', chain, inner);
    }
  }

  bool _dependsOn(Expr expression, String variable) =>
      exprVariables(expression).contains(variable);

  /// Prints with conventional precedence and light typographic sugar.
  String _print(Expr expression, {int parent = 0}) {
    final text = _printRaw(expression);
    final precedence = _precedence(expression);
    final fractionalLiteral =
        expression is LiteralExpr && !expression.value.isInteger;
    final needs = precedence < parent || (fractionalLiteral && parent > 0);
    return needs ? '($text)' : text;
  }

  int _precedence(Expr expression) => switch (expression) {
    BinaryExpr(operator: '+' || '-') => 1,
    BinaryExpr(operator: '*' || '/') => 2,
    UnaryExpr() => 2,
    BinaryExpr(operator: '^') => 3,
    PostfixExpr() => 4,
    FunctionExpr() => 5,
    _ => 6,
  };

  String _printRaw(Expr expression) {
    switch (expression) {
      case LiteralExpr():
        final value = expression.value;
        if (value.isInteger) {
          return value.numerator.toString().replaceFirst('-', '−');
        }
        return value.toString().replaceFirst('-', '−');
      case VariableExpr():
        return expression.name;
      case ConstantExpr():
        return expression.name == 'pi' ? 'π' : expression.name;
      case UnaryExpr():
        final operand = _print(expression.operand, parent: 2);
        return '${expression.operator == '-' ? '−' : expression.operator}$operand';
      case BinaryExpr():
        final leftOperand = expression.left;
        final rightOperand = expression.right;
        if (expression.operator == '*' &&
            leftOperand is LiteralExpr &&
            leftOperand.value.isInteger &&
            leftOperand.value.abs() != Rational.one) {
          final coefficient = leftOperand.value.numerator
              .toString()
              .replaceFirst('-', '−');
          final right = _print(rightOperand, parent: 2);
          return '$coefficient$right';
        }
        if (expression.operator == '*' &&
            leftOperand is LiteralExpr &&
            leftOperand.value == Rational.fromInt(-1)) {
          return '−${_print(rightOperand, parent: 2)}';
        }
        final operator = switch (expression.operator) {
          '*' => '×',
          '/' => '/',
          '-' => '−',
          _ => expression.operator,
        };
        final (leftParent, rightParent) = switch (expression.operator) {
          '+' || '-' => (1, 2),
          '*' || '/' => (2, 3),
          '^' => (4, 3),
          _ => (2, 2),
        };
        final left = _print(leftOperand, parent: leftParent);
        final right = _print(rightOperand, parent: rightParent);
        if (expression.operator == '^' &&
            rightOperand is LiteralExpr &&
            rightOperand.value.isInteger) {
          final exponent = rightOperand.value.toInt();
          if (exponent == 2) return '$left²';
          if (exponent == 3) return '$left³';
        }
        return '$left $operator $right';
      case PostfixExpr():
        final operand = _print(expression.operand, parent: 4);
        return switch (expression.operator) {
          '²' => '$operand²',
          '³' => '$operand³',
          _ => '$operand${expression.operator}',
        };
      case FunctionExpr():
        return '${expression.name}(${expression.arguments.map((argument) => _print(argument)).join(', ')})';
    }
  }
}
