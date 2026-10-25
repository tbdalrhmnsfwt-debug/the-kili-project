/// The parsed expression tree used by the scientific calculator.
///
/// Input is never executed with `eval`. The lexer and parser turn it into this
/// closed set of nodes, and the evaluator and CAS consume the nodes directly.
library;

import 'math_value.dart';

sealed class Expr {
  const Expr();
}

/// An exact numeric literal. Decimals are stored as exact rationals.
class LiteralExpr extends Expr {
  const LiteralExpr(this.value, {required this.raw});

  final Rational value;
  final String raw;
}

class VariableExpr extends Expr {
  const VariableExpr(this.name);

  final String name;
}

/// `pi`, `e` or `i`.
class ConstantExpr extends Expr {
  const ConstantExpr(this.name);

  final String name;
}

class UnaryExpr extends Expr {
  const UnaryExpr(this.operator, this.operand);

  /// `+`, `-`, `%`.
  final String operator;
  final Expr operand;
}

class BinaryExpr extends Expr {
  const BinaryExpr(this.operator, this.left, this.right);

  /// `+`, `-`, `*`, `/`, `^`.
  final String operator;
  final Expr left;
  final Expr right;
}

class PostfixExpr extends Expr {
  const PostfixExpr(this.operator, this.operand);

  /// `!`, `%`, `²`, `³`, `°`.
  final String operator;
  final Expr operand;
}

class FunctionExpr extends Expr {
  const FunctionExpr(this.name, this.arguments);

  final String name;
  final List<Expr> arguments;
}

/// Returns a compact infix representation suitable for re-editing the
/// expression or writing a CAS result back into the input line.
String exprToSource(Expr expr, {bool parenthesize = false}) {
  final String text;
  switch (expr) {
    case LiteralExpr():
      text = expr.raw;
    case VariableExpr():
      text = expr.name;
    case ConstantExpr():
      text = expr.name == 'pi' ? 'π' : expr.name;
    case UnaryExpr():
      text =
          '${expr.operator == '-' ? '−' : expr.operator}'
          '${exprToSource(expr.operand, parenthesize: true)}';
    case BinaryExpr():
      final op = switch (expr.operator) {
        '*' => '×',
        '/' => '÷',
        '-' => '−',
        _ => expr.operator,
      };
      text =
          '${exprToSource(expr.left, parenthesize: true)} $op '
          '${exprToSource(expr.right, parenthesize: true)}';
    case PostfixExpr():
      text = switch (expr.operator) {
        '²' => '${exprToSource(expr.operand, parenthesize: true)}²',
        '³' => '${exprToSource(expr.operand, parenthesize: true)}³',
        _ => '${exprToSource(expr.operand, parenthesize: true)}${expr.operator}',
      };
    case FunctionExpr():
      text =
          '${expr.name}(${expr.arguments.map((argument) => exprToSource(argument)).join(', ')})';
  }
  if (!parenthesize) return text;
  return switch (expr) {
    BinaryExpr() || UnaryExpr() => '($text)',
    _ => text,
  };
}

/// Collects every variable name used by [expr], in source order.
Set<String> exprVariables(Expr expr) {
  final names = <String>{};
  void visit(Expr node) {
    switch (node) {
      case LiteralExpr() || ConstantExpr():
        break;
      case VariableExpr():
        names.add(node.name);
      case UnaryExpr():
        visit(node.operand);
      case BinaryExpr():
        visit(node.left);
        visit(node.right);
      case PostfixExpr():
        visit(node.operand);
      case FunctionExpr():
        for (final argument in node.arguments) {
          visit(argument);
        }
    }
  }

  visit(expr);
  return names;
}
