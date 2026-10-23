/// The advanced calculation sheets of the scientific calculator: definite
/// integration, numerical differentiation, equation solving, matrices,
/// statistics and complex numbers.
///
/// Every sheet computes on-device with [CalcEngine] and returns the formatted
/// result when the user chooses «استخدم الناتج», so it can be inserted into
/// the main expression.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'calc_engine.dart';

/// Shows the definite-integration sheet. Returns the result to insert.
Future<String?> showIntegralDialog(
  BuildContext context, {
  required bool radians,
  required Map<String, double> variables,
  required double answer,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => _SheetBody(
      title: 'التكامل المحدد  ∫dx',
      subtitle: 'احسب ∫ f(x) dx بين الحدين اللي تحت.',
      child: _IntegralSheet(
        radians: radians,
        variables: variables,
        answer: answer,
      ),
    ),
  );
}

/// Shows the numerical-derivative sheet.
Future<String?> showDerivativeDialog(
  BuildContext context, {
  required bool radians,
  required Map<String, double> variables,
  required double answer,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => _SheetBody(
      title: 'المشتقة  d/dx',
      subtitle: 'قيمة المشتقة عند نقطة معينة — بحساب عددي دقيق.',
      child: _DerivativeSheet(
        radians: radians,
        variables: variables,
        answer: answer,
      ),
    ),
  );
}

/// Shows the single-variable equation solver.
Future<String?> showSolveDialog(
  BuildContext context, {
  required bool radians,
  required Map<String, double> variables,
  required double answer,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => _SheetBody(
      title: 'حل المعادلة  SOLVE',
      subtitle: 'اكتب المعادلة بعلامة = وحدد نطاق البحث.',
      child: _SolveSheet(
        radians: radians,
        variables: variables,
        answer: answer,
      ),
    ),
  );
}

/// Shows the matrix operations sheet.
Future<String?> showMatrixDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => const _SheetBody(
      title: 'المصفوفات  MATRIX',
      subtitle: 'اكتب عناصر المصفوفة صف ورا صف، مفصولة بمسافات أو فواصل.',
      child: _MatrixSheet(),
    ),
  );
}

/// Shows the descriptive-statistics sheet.
Future<String?> showStatDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => const _SheetBody(
      title: 'الإحصاء  STAT',
      subtitle: 'الصق الأرقام مفصولة بمسافات أو فواصل.',
      child: _StatSheet(),
    ),
  );
}

/// Shows the complex-number sheet.
Future<String?> showComplexDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
    builder: (_) => const _SheetBody(
      title: 'الأعداد المركبة  CMPLX',
      subtitle: 'كل عدد على شكل a + bi — اكتب الجزء الحقيقي والتخيلي.',
      child: _ComplexSheet(),
    ),
  );
}

// --------------------------------------------------------------- shared UI

/// The rounded sheet with a title, subtitle and scrollable child.
class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          0,
          ZakerSpacing.lg,
          ZakerSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              TrText(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: ZakerSpacing.lg),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled text field using LTR math text.
class _MathField extends StatelessWidget {
  const _MathField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType ?? TextInputType.text,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 15,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintTextDirection: TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }
}

/// The green result card shared by the sheets.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onInsert});

  final String result;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: ZakerSpacing.sm),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            'النتيجة',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            result,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: onInsert,
                icon: const Icon(Icons.input_rounded, size: 18),
                label: const TrText('استخدم الناتج'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An inline error line.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: ZakerSpacing.sm),
      child: TrText(
        message,
        style: const TextStyle(
          color: ZakerColors.danger,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Builds an engine with `X` bound to [x].
CalcEngine _engineAt({
  required bool radians,
  required Map<String, double> variables,
  required double answer,
  required double x,
}) {
  return CalcEngine(
    radians: radians,
    variables: {...variables, 'X': x},
    answer: answer,
  );
}

// ------------------------------------------------------------------ integral

class _IntegralSheet extends StatefulWidget {
  const _IntegralSheet({
    required this.radians,
    required this.variables,
    required this.answer,
  });

  final bool radians;
  final Map<String, double> variables;
  final double answer;

  @override
  State<_IntegralSheet> createState() => _IntegralSheetState();
}

class _IntegralSheetState extends State<_IntegralSheet> {
  final _function = TextEditingController(text: 'x^2');
  final _from = TextEditingController(text: '0');
  final _to = TextEditingController(text: '1');
  String? _result;
  String? _error;

  @override
  void dispose() {
    _function.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _compute() {
    final source = _function.text.trim();
    final a = double.tryParse(_from.text.trim());
    final b = double.tryParse(_to.text.trim());
    if (source.isEmpty || a == null || b == null) {
      setState(() {
        _result = null;
        _error = 'اكتب الدالة والحدين صح.';
      });
      return;
    }
    try {
      final steps = 2000;
      final h = (b - a) / steps;
      if (h == 0) throw const CalcException('Math ERROR');
      double valueAt(double x) => _engineAt(
        radians: widget.radians,
        variables: widget.variables,
        answer: widget.answer,
        x: x,
      ).evaluate(source);

      var sum = valueAt(a) + valueAt(b);
      for (var i = 1; i < steps; i++) {
        sum += (i.isEven ? 2 : 4) * valueAt(a + i * h);
      }
      final value = sum * h / 3;
      setState(() {
        _result = formatCalc(value);
        _error = null;
      });
    } catch (e) {
      setState(() {
        _result = null;
        _error = e is CalcException ? e.message : 'مش قادر أحسب التكامل.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MathField(
          label: 'الدالة f(x)',
          controller: _function,
          hint: 'مثال: x^2 + 3',
        ),
        Row(
          children: [
            Expanded(
              child: _MathField(
                label: 'من (a)',
                controller: _from,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: _MathField(
                label: 'إلى (b)',
                controller: _to,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: _compute,
          icon: const Icon(Icons.calculate_rounded),
          label: const TrText('احسب التكامل'),
        ),
        if (_error != null) _ErrorLine(_error!),
        if (_result != null)
          _ResultCard(
            result: _result!,
            onInsert: () => Navigator.of(context).pop(_result),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- derivative

class _DerivativeSheet extends StatefulWidget {
  const _DerivativeSheet({
    required this.radians,
    required this.variables,
    required this.answer,
  });

  final bool radians;
  final Map<String, double> variables;
  final double answer;

  @override
  State<_DerivativeSheet> createState() => _DerivativeSheetState();
}

class _DerivativeSheetState extends State<_DerivativeSheet> {
  final _function = TextEditingController(text: 'x^2');
  final _at = TextEditingController(text: '1');
  String? _result;
  String? _error;

  @override
  void dispose() {
    _function.dispose();
    _at.dispose();
    super.dispose();
  }

  void _compute() {
    final source = _function.text.trim();
    final x = double.tryParse(_at.text.trim());
    if (source.isEmpty || x == null) {
      setState(() {
        _result = null;
        _error = 'اكتب الدالة والنقطة صح.';
      });
      return;
    }
    try {
      double valueAt(double point) => _engineAt(
        radians: widget.radians,
        variables: widget.variables,
        answer: widget.answer,
        x: point,
      ).evaluate(source);

      final h = 1e-5 * (1 + x.abs());
      final derivative = (valueAt(x + h) - valueAt(x - h)) / (2 * h);
      if (!derivative.isFinite) throw const CalcException('Math ERROR');
      setState(() {
        _result = formatCalc(derivative);
        _error = null;
      });
    } catch (e) {
      setState(() {
        _result = null;
        _error = e is CalcException ? e.message : 'مش قادر أحسب المشتقة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MathField(
          label: 'الدالة f(x)',
          controller: _function,
          hint: 'مثال: sin(x) + x^2',
        ),
        _MathField(
          label: 'عند x =',
          controller: _at,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
        ),
        FilledButton.icon(
          onPressed: _compute,
          icon: const Icon(Icons.functions_rounded),
          label: const TrText('احسب المشتقة'),
        ),
        if (_error != null) _ErrorLine(_error!),
        if (_result != null)
          _ResultCard(
            result: _result!,
            onInsert: () => Navigator.of(context).pop(_result),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------- solve

class _SolveSheet extends StatefulWidget {
  const _SolveSheet({
    required this.radians,
    required this.variables,
    required this.answer,
  });

  final bool radians;
  final Map<String, double> variables;
  final double answer;

  @override
  State<_SolveSheet> createState() => _SolveSheetState();
}

class _SolveSheetState extends State<_SolveSheet> {
  final _equation = TextEditingController(text: 'x^2 - 4 = 0');
  final _min = TextEditingController(text: '-50');
  final _max = TextEditingController(text: '50');
  String? _result;
  String? _error;

  @override
  void dispose() {
    _equation.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _compute() {
    final equation = _equation.text.trim();
    final low = double.tryParse(_min.text.trim());
    final high = double.tryParse(_max.text.trim());
    final sides = equation.split('=');
    if (sides.length != 2 || low == null || high == null || low >= high) {
      setState(() {
        _result = null;
        _error = 'اكتب معادلة فيها = واحدة، ونطاق صحيح.';
      });
      return;
    }

    final left = sides[0];
    final right = sides[1];
    try {
      double valueAt(double x) {
        final engine = _engineAt(
          radians: widget.radians,
          variables: widget.variables,
          answer: widget.answer,
          x: x,
        );
        return engine.evaluate('($left) - ($right)');
      }

      final samples = 4000;
      final step = (high - low) / samples;
      double? root;
      var previousX = low;
      var previousY = valueAt(low);
      if (previousY.abs() < 1e-10) root = low;
      for (var i = 1; i <= samples && root == null; i++) {
        final x = low + i * step;
        final y = valueAt(x);
        if (y.abs() < 1e-10) {
          root = x;
          break;
        }
        if (previousY.sign != y.sign) {
          var a = previousX;
          var b = x;
          var ya = previousY;
          for (var j = 0; j < 80; j++) {
            final mid = (a + b) / 2;
            final ym = valueAt(mid);
            if (ym.abs() < 1e-12) {
              a = mid;
              b = mid;
              break;
            }
            if (ya.sign != ym.sign) {
              b = mid;
            } else {
              a = mid;
              ya = ym;
            }
          }
          root = (a + b) / 2;
        }
        previousX = x;
        previousY = y;
      }

      if (root == null) {
        setState(() {
          _result = null;
          _error = 'مفيش جذر في النطاق ده — جرّب توسّعه.';
        });
        return;
      }
      setState(() {
        _result = 'x = ${formatCalc(root!)}\n'
            'f(x) = ${formatCalc(valueAt(root))}';
        _error = null;
      });
    } catch (e) {
      setState(() {
        _result = null;
        _error = e is CalcException ? e.message : 'مش قادر أحل المعادلة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MathField(
          label: 'المعادلة',
          controller: _equation,
          hint: 'مثال: x^2 - 4 = 0',
        ),
        Row(
          children: [
            Expanded(
              child: _MathField(
                label: 'من',
                controller: _min,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: _MathField(
                label: 'إلى',
                controller: _max,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: _compute,
          icon: const Icon(Icons.search_rounded),
          label: const TrText('حل المعادلة'),
        ),
        if (_error != null) _ErrorLine(_error!),
        if (_result != null)
          _ResultCard(
            result: _result!,
            onInsert: () => Navigator.of(context).pop(_result),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------------- matrix

enum _MatrixOp { add, subtract, multiply, determinant, inverse }

class _MatrixSheet extends StatefulWidget {
  const _MatrixSheet();

  @override
  State<_MatrixSheet> createState() => _MatrixSheetState();
}

class _MatrixSheetState extends State<_MatrixSheet> {
  final _a = TextEditingController(text: '1 2\n3 4');
  final _b = TextEditingController(text: '5 6\n7 8');
  int _size = 2;
  _MatrixOp _operation = _MatrixOp.add;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _setSize(int size) {
    setState(() {
      _size = size;
      _a.text = size == 2 ? '1 2\n3 4' : '1 2 3\n4 5 6\n7 8 9';
      _b.text = size == 2 ? '5 6\n7 8' : '9 8 7\n6 5 4\n3 2 1';
      _result = null;
      _error = null;
    });
  }

  List<List<double>>? _parse(String raw) {
    final tokens = raw
        .replaceAll(RegExp(r'[;,،]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.length != _size * _size) return null;
    final values = <double>[];
    for (final token in tokens) {
      final value = double.tryParse(token);
      if (value == null) return null;
      values.add(value);
    }
    return [
      for (var row = 0; row < _size; row++)
        values.sublist(row * _size, (row + 1) * _size),
    ];
  }

  void _compute() {
    final a = _parse(_a.text);
    final b = _parse(_b.text);
    if (a == null || b == null) {
      setState(() {
        _result = null;
        _error = 'كل مصفوفة لازم يكون فيها ${_size * _size} أرقام.';
      });
      return;
    }

    List<List<double>> matrix = [
      for (var i = 0; i < _size; i++) List<double>.filled(_size, 0),
    ];
    String? error;
    switch (_operation) {
      case _MatrixOp.add:
      case _MatrixOp.subtract:
        final sign = _operation == _MatrixOp.add ? 1 : -1;
        for (var i = 0; i < _size; i++) {
          for (var j = 0; j < _size; j++) {
            matrix[i][j] = a[i][j] + sign * b[i][j];
          }
        }
      case _MatrixOp.multiply:
        for (var i = 0; i < _size; i++) {
          for (var j = 0; j < _size; j++) {
            var sum = 0.0;
            for (var k = 0; k < _size; k++) {
              sum += a[i][k] * b[k][j];
            }
            matrix[i][j] = sum;
          }
        }
      case _MatrixOp.determinant:
        final det = _determinant(a);
        setState(() {
          _result = 'det(A) = ${formatCalc(det)}';
          _error = null;
        });
        return;
      case _MatrixOp.inverse:
        final det = _determinant(a);
        if (det.abs() < 1e-12) {
          error = 'المصفوفة مفردة — مفيش معكوس.';
        } else {
          matrix = _inverse(a, det);
        }
    }

    if (error != null) {
      setState(() {
        _result = null;
        _error = error;
      });
      return;
    }
    setState(() {
      _result = matrix
          .map((row) => row.map(formatCalc).join('   '))
          .join('\n');
      _error = null;
    });
  }

  double _determinant(List<List<double>> m) {
    if (_size == 2) return m[0][0] * m[1][1] - m[0][1] * m[1][0];
    return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  }

  List<List<double>> _inverse(List<List<double>> m, double det) {
    if (_size == 2) {
      return [
        [m[1][1] / det, -m[0][1] / det],
        [-m[1][0] / det, m[0][0] / det],
      ];
    }
    List<List<double>> cofactor(int r, int c) {
      final rows = [for (var i = 0; i < 3; i++) if (i != r) i];
      final cols = [for (var j = 0; j < 3; j++) if (j != c) j];
      return [
        [m[rows[0]][cols[0]], m[rows[0]][cols[1]]],
        [m[rows[1]][cols[0]], m[rows[1]][cols[1]]],
      ];
    }

    final result = [
      for (var i = 0; i < 3; i++) List<double>.filled(3, 0),
    ];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final sign = (i + j).isEven ? 1 : -1;
        result[i][j] = sign * _determinant(cofactor(j, i)) / det;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: ZakerSpacing.sm,
          children: [
            ChoiceChip(
              label: const TrText('2×2'),
              selected: _size == 2,
              onSelected: (_) => _setSize(2),
            ),
            ChoiceChip(
              label: const TrText('3×3'),
              selected: _size == 3,
              onSelected: (_) => _setSize(3),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.sm),
        _MathField(label: 'المصفوفة A', controller: _a, maxLines: 3),
        _MathField(label: 'المصفوفة B', controller: _b, maxLines: 3),
        Wrap(
          spacing: ZakerSpacing.sm,
          runSpacing: ZakerSpacing.sm,
          children: [
            _OperationChip(
              label: 'A + B',
              selected: _operation == _MatrixOp.add,
              onTap: () => setState(() => _operation = _MatrixOp.add),
            ),
            _OperationChip(
              label: 'A − B',
              selected: _operation == _MatrixOp.subtract,
              onTap: () => setState(() => _operation = _MatrixOp.subtract),
            ),
            _OperationChip(
              label: 'A × B',
              selected: _operation == _MatrixOp.multiply,
              onTap: () => setState(() => _operation = _MatrixOp.multiply),
            ),
            _OperationChip(
              label: 'det(A)',
              selected: _operation == _MatrixOp.determinant,
              onTap: () => setState(() => _operation = _MatrixOp.determinant),
            ),
            _OperationChip(
              label: 'A⁻¹',
              selected: _operation == _MatrixOp.inverse,
              onTap: () => setState(() => _operation = _MatrixOp.inverse),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        FilledButton.icon(
          onPressed: _compute,
          icon: const Icon(Icons.grid_on_rounded),
          label: const TrText('احسب'),
        ),
        if (_error != null) _ErrorLine(_error!),
        if (_result != null)
          _ResultCard(
            result: _result!,
            onInsert: () => Navigator.of(context).pop(_result),
          ),
      ],
    );
  }
}

/// A selectable matrix operation.
class _OperationChip extends StatelessWidget {
  const _OperationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// ---------------------------------------------------------------------- stat

class _StatSheet extends StatefulWidget {
  const _StatSheet();

  @override
  State<_StatSheet> createState() => _StatSheetState();
}

class _StatSheetState extends State<_StatSheet> {
  final _numbers = TextEditingController(text: '12, 15, 11, 18, 15, 20');
  String? _result;
  String? _error;

  @override
  void dispose() {
    _numbers.dispose();
    super.dispose();
  }

  void _compute() {
    final values = _numbers.text
        .replaceAll(RegExp(r'[;،]'), ' ')
        .replaceAll(',', ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map(double.tryParse)
        .toList();
    if (values.isEmpty || values.any((v) => v == null)) {
      setState(() {
        _result = null;
        _error = 'اكتب أرقام صحيحة مفصولة بمسافات أو فواصل.';
      });
      return;
    }
    final numbers = values.cast<double>();
    double sum = 0;
    for (final n in numbers) {
      sum += n;
    }
    final mean = sum / numbers.length;
    final sorted = [...numbers]..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    var variance = 0.0;
    for (final n in numbers) {
      variance += (n - mean) * (n - mean);
    }
    variance = numbers.length > 1 ? variance / (numbers.length - 1) : 0;
    final std = variance <= 0 ? 0.0 : math.sqrt(variance);

    setState(() {
      _result = [
        'n = ${numbers.length}',
        'Σx = ${formatCalc(sum)}',
        'المتوسط = ${formatCalc(mean)}',
        'الوسيط = ${formatCalc(median)}',
        'التباين = ${formatCalc(variance)}',
        'الانحراف المعياري = ${formatCalc(std)}',
        'أصغر قيمة = ${formatCalc(sorted.first)}',
        'أكبر قيمة = ${formatCalc(sorted.last)}',
      ].join('\n');
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MathField(
          label: 'الأرقام',
          controller: _numbers,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
        ),
        FilledButton.icon(
          onPressed: _compute,
          icon: const Icon(Icons.pie_chart_outline_rounded),
          label: const TrText('احسب الإحصاء'),
        ),
        if (_error != null) _ErrorLine(_error!),
        if (_result != null)
          _ResultCard(
            result: _result!,
            onInsert: () => Navigator.of(context).pop(_result),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------- complex

enum _ComplexOp { add, subtract, multiply, divide, modulus, argument }

class _ComplexSheet extends StatefulWidget {
  const _ComplexSheet();

  @override
  State<_ComplexSheet> createState() => _ComplexSheetState();
}

class _ComplexSheetState extends State<_ComplexSheet> {
  final _a = TextEditingController(text: '3');
  final _b = TextEditingController(text: '4');
  final _c = TextEditingController(text: '1');
  final _d = TextEditingController(text: '-2');
  _ComplexOp _operation = _ComplexOp.add;
  String? _result;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    _d.dispose();
    super.dispose();
  }

  void _compute() {
    final a = double.tryParse(_a.text.trim());
    final b = double.tryParse(_b.text.trim());
    final c = double.tryParse(_c.text.trim());
    final d = double.tryParse(_d.text.trim());
    if (a == null || b == null || c == null || d == null) {
      setState(() {
        _result = null;
        _error = 'كل الأجزاء لازم تكون أرقام.';
      });
      return;
    }

    double re;
    double im;
    switch (_operation) {
      case _ComplexOp.add:
        re = a + c;
        im = b + d;
      case _ComplexOp.subtract:
        re = a - c;
        im = b - d;
      case _ComplexOp.multiply:
        re = a * c - b * d;
        im = a * d + b * c;
      case _ComplexOp.divide:
        final denominator = c * c + d * d;
        if (denominator == 0) {
          setState(() {
            _result = null;
            _error = 'القسمة على صفر.';
          });
          return;
        }
        re = (a * c + b * d) / denominator;
        im = (b * c - a * d) / denominator;
      case _ComplexOp.modulus:
        final modulus = math.sqrt(a * a + b * b);
        setState(() {
          _result = '|z₁| = ${formatCalc(modulus)}';
          _error = null;
        });
        return;
      case _ComplexOp.argument:
        final angle = math.atan2(b, a) * 180 / math.pi;
        setState(() {
          _result = 'arg(z₁) = ${formatCalc(angle)}°';
          _error = null;
        });
        return;
    }
    setState(() {
      _result = _formatComplex(re, im);
      _error = null;
    });
  }

  String _formatComplex(double re, double im) {
    if (im.abs() < 1e-12) return formatCalc(re);
    final imaginary = formatCalc(im.abs());
    final sign = im < 0 ? '−' : '+';
    if (re.abs() < 1e-12) return '${im < 0 ? '−' : ''}${imaginary}i';
    return '${formatCalc(re)} $sign ${imaginary}i';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrText(
          'العدد الأول z₁',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _MathField(label: 'a', controller: _a),
            ),
            const SizedBox(width: ZakerSpacing.sm),
            Expanded(
              child: _MathField(label: 'b', controller: _b),
            ),
          ],
        ),
        const TrText(
          'العدد الثاني z₂',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _MathField(label: 'c', controller: _c),
            ),
            const SizedBox(width: ZakerSpacing.sm),
            Expanded(
              child: _MathField(label: 'd', controller: _d),
            ),
          ],
        ),
        Wrap(
          spacing: ZakerSpacing.sm,
          runSpacing: ZakerSpacing.sm,
          children: [
            _OperationChip(
              label: 'z₁ + z₂',
              selected: _operation == _ComplexOp.add,
              onTap: () => setState(() => _operation = _ComplexOp.add),
            ),
            _OperationChip(
              label: 'z₁ − z₂',
              selected: _operation == _ComplexOp.subtract,
              onTap: () => setState(() => _operation = _ComplexOp.subtract),
            ),
            _OperationChip(
              label: 'z₁ × z₂',
              selected: _operation == _ComplexOp.multiply,
              onTap: () => setState(() => _operation = _ComplexOp.multiply),
            ),
            _OperationChip(
              label: 'z₁ ÷ z₂',
              selected: _operation == _ComplexOp.divide,
              onTap: () => setState(() => _operation = _ComplexOp.divide),
            ),
            _OperationChip(
              label: '|z₁|',
              selected: _operation == _ComplexOp.modulus,
              onTap: () => setState(() => _operation = _ComplexOp.modulus),
            ),
            _OperationChip(
              label: 'arg(z₁)',
              selected: _operation == _ComplexOp.argument,
              onTap: () => setState(() => _operation = _ComplexOp.argument),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        FilledButton.icon(
          onPressed: _compute,
          icon: const Icon(Icons.exposure_plus_2_rounded),
          label: const TrText('احسب'),
        ),
        if (_error != null) _ErrorLine(_error!),
        if (_result != null)
          _ResultCard(
            result: _result!,
            onInsert: () => Navigator.of(context).pop(_result),
          ),
      ],
    );
  }
}
