/// MATRIX mode for matrices up to 4×4.
library;

import 'package:flutter/material.dart';

import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/matrix.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../engine/polynomial.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

class MatrixMode extends StatefulWidget {
  const MatrixMode({super.key, required this.angleUnit});

  /// Cells may contain trigonometric functions, so they follow the selected
  /// angle unit.
  final AngleUnit angleUnit;

  @override
  State<MatrixMode> createState() => _MatrixModeState();
}

class _MatrixModeState extends State<MatrixMode> {
  int _aRows = 2;
  int _aColumns = 2;
  int _bRows = 2;
  int _bColumns = 2;
  final List<TextEditingController> _a = <TextEditingController>[
    for (var i = 0; i < 16; i++) TextEditingController(),
  ];
  final List<TextEditingController> _b = <TextEditingController>[
    for (var i = 0; i < 16; i++) TextEditingController(),
  ];
  String? _result;
  String? _operation;
  String? _error;
  String? _detail;

  @override
  void initState() {
    super.initState();
    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 2; column++) {
        _a[row * 4 + column].text = row == column ? '1' : '0';
        _b[row * 4 + column].text = row == column ? '1' : '0';
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _a) {
      controller.dispose();
    }
    for (final controller in _b) {
      controller.dispose();
    }
    super.dispose();
  }

  double _parseCell(TextEditingController controller, String label) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      throw CalcError(
        CalcErrorKind.argument,
        detail: 'الخانة $label فاضية.',
      );
    }
    try {
      final value = Evaluator(
        EvalContext(angleUnit: widget.angleUnit),
      ).evaluate(parseExpression(text));
      if (!value.isReal) {
        throw CalcError(
          CalcErrorKind.argument,
          detail: 'الخانة $label لازم تكون عدد حقيقي.',
        );
      }
      return value.realPart;
    } on CalcError catch (error) {
      throw CalcError(
        error.kind,
        detail: 'الخانة $label: ${error.detail ?? error.hint}',
      );
    }
  }

  Matrix _matrix(
    List<TextEditingController> controllers,
    int rows,
    int columns,
    String name,
  ) {
    return Matrix(<List<double>>[
      for (var row = 0; row < rows; row++)
        <double>[
          for (var column = 0; column < columns; column++)
            _parseCell(
              controllers[row * 4 + column],
              '$name${row + 1}${String.fromCharCode(65 + column)}',
            ),
        ],
    ]);
  }

  void _apply(String label, Matrix Function(Matrix a, Matrix b) operation) {
    try {
      final a = _matrix(_a, _aRows, _aColumns, 'A');
      final b = _matrix(_b, _bRows, _bColumns, 'B');
      final result = operation(a, b);
      setState(() {
        _result = result.format();
        _operation = '$label\n${result.rows}×${result.columns}';
        _error = null;
        _detail = a.isSquare
            ? 'det = ${formatReal(a.determinant())}'
            : 'المصفوفة A مش مربعة، فمفيش محدد.'
        ;
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _operation = null;
        _detail = null;
      });
    }
  }

  void _applyA(String label, Matrix Function(Matrix a) operation) {
    try {
      final a = _matrix(_a, _aRows, _aColumns, 'A');
      final result = operation(a);
      setState(() {
        _result = result.format();
        _operation = '$label\n${result.rows}×${result.columns}';
        _error = null;
        _detail = a.isSquare
            ? 'det(A) = ${formatReal(a.determinant())}'
            : 'المصفوفة A مش مربعة.';
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _operation = null;
        _detail = null;
      });
    }
  }

  void _determinant() {
    try {
      final a = _matrix(_a, _aRows, _aColumns, 'A');
      final value = a.determinant();
      setState(() {
        _result = formatReal(value);
        _operation = 'det(A)';
        _error = null;
        _detail = 'المحدد عددي؛ القيم القريبة جدًا من الصفر بتتعامل كصفر عدديًا.';
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _operation = null;
        _detail = null;
      });
    }
  }

  void _eigenvalues() {
    try {
      final a = _matrix(_a, _aRows, _aColumns, 'A');
      final values = a.eigenvalues();
      final buffer = StringBuffer();
      if (values.roots.isEmpty) {
        buffer.write('مفيش قيم ذاتية.');
      } else {
        for (var i = 0; i < values.roots.length; i++) {
          final root = values.roots[i];
          buffer.writeln('λ${_subscript(i + 1)} = ${_formatRoot(root)}');
        }
      }
      setState(() {
        _result = buffer.toString().trim();
        _operation = 'القيم الذاتية للمصفوفة A';
        _error = null;
        _detail = values.converged
            ? 'القيم الذاتية محسوبة عدديًا من كثيرة الحدود المميزة.'
            : 'الطريقة العددية لم تتقارب بشكل كامل — النتائج تقريبية.';
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _operation = null;
        _detail = null;
      });
    }
  }

  String _formatRoot(ComplexRoot root) {
    if (root.isReal) return formatReal(root.real);
    final real = root.real.abs() < 1e-10 ? '' : '${formatReal(root.real)} ';
    final sign = root.imaginary < 0 ? '−' : '+';
    final magnitude = formatReal(root.imaginary.abs());
    final coefficient = root.imaginary.abs() == 1 ? '' : magnitude;
    return '$real$sign ${coefficient}i'.trim();
  }

  String _subscript(int number) {
    const digits = '₀₁₂₃₄₅₆₇₈₉';
    return '$number'.split('').map((digit) {
      final value = int.tryParse(digit);
      return value == null ? digit : digits[value];
    }).join();
  }

  void _resize({required bool matrixA, int? rows, int? columns}) {
    setState(() {
      if (matrixA) {
        _aRows = rows ?? _aRows;
        _aColumns = columns ?? _aColumns;
      } else {
        _bRows = rows ?? _bRows;
        _bColumns = columns ?? _bColumns;
      }
      _result = null;
      _operation = null;
      _error = null;
      _detail = null;
    });
  }

  void _swap() {
    setState(() {
      final oldARows = _aRows;
      final oldAColumns = _aColumns;
      for (var i = 0; i < 16; i++) {
        final text = _a[i].text;
        _a[i].text = _b[i].text;
        _b[i].text = text;
      }
      _aRows = _bRows;
      _aColumns = _bColumns;
      _bRows = oldARows;
      _bColumns = oldAColumns;
      _result = null;
      _operation = null;
      _error = null;
      _detail = null;
    });
  }

  void _identityA() {
    setState(() {
      for (var row = 0; row < _aRows; row++) {
        for (var column = 0; column < _aColumns; column++) {
          _a[row * 4 + column].text =
              row == column && _aRows == _aColumns ? '1' : '0';
        }
      }
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return CalcModePage(
      title: 'MATRIX — المصفوفات',
      subtitle: 'جمع وطرح وضرب وتحويل، محدد ومعكوس وقيم ذاتية حتى 4×4.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _matrixCard(
            palette,
            name: 'A',
            controllers: _a,
            rows: _aRows,
            columns: _aColumns,
            onRows: (value) => _resize(matrixA: true, rows: value),
            onColumns: (value) => _resize(matrixA: true, columns: value),
            actions: <Widget>[
              CalcSoftButton(
                label: 'وحدة',
                icon: Icons.filter_center_focus_rounded,
                expanded: true,
                onPressed: _identityA,
              ),
              CalcSoftButton(
                label: 'تبديل A↔B',
                icon: Icons.swap_horiz_rounded,
                expanded: true,
                onPressed: _swap,
              ),
            ],
          ),
          _matrixCard(
            palette,
            name: 'B',
            controllers: _b,
            rows: _bRows,
            columns: _bColumns,
            onRows: (value) => _resize(matrixA: false, rows: value),
            onColumns: (value) => _resize(matrixA: false, columns: value),
            actions: <Widget>[
              CalcSoftButton(
                label: 'تصفير B',
                icon: Icons.grid_off_rounded,
                expanded: true,
                onPressed: () {
                  setState(() {
                    for (final controller in _b) {
                      controller.clear();
                    }
                    _result = null;
                    _error = null;
                  });
                },
              ),
            ],
          ),
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CalcSectionTitle(
                  title: 'العمليات',
                  subtitle:
                      'الجمع والطرح يحتاجان نفس الأبعاد؛ الضرب يحتاج توافق الأعمدة مع الصفوف.',
                ),
                const SizedBox(height: 10),
                CalcActionGrid(
                  actions: <Widget>[
                    CalcSoftButton(
                      label: 'A + B',
                      expanded: true,
                      onPressed: () => _apply('A + B', (a, b) => a + b),
                    ),
                    CalcSoftButton(
                      label: 'A − B',
                      expanded: true,
                      onPressed: () => _apply('A − B', (a, b) => a - b),
                    ),
                    CalcSoftButton(
                      label: 'A × B',
                      expanded: true,
                      color: palette.accent,
                      onPressed: () => _apply('A × B', (a, b) => a * b),
                    ),
                    CalcSoftButton(
                      label: 'Aᵀ',
                      expanded: true,
                      onPressed: () => _applyA('Aᵀ', (a) => a.transpose()),
                    ),
                    CalcSoftButton(
                      label: 'A²',
                      expanded: true,
                      onPressed: () => _applyA('A²', (a) => a.power(2)),
                    ),
                    CalcSoftButton(
                      label: 'det(A)',
                      expanded: true,
                      onPressed: _determinant,
                    ),
                    CalcSoftButton(
                      label: 'A⁻¹',
                      expanded: true,
                      onPressed: () => _applyA('A⁻¹', (a) => a.inverse()),
                    ),
                    CalcSoftButton(
                      label: 'λ(A)',
                      expanded: true,
                      onPressed: _eigenvalues,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const CalcNote(
                  text:
                      'المعكوس بيتطلب مصفوفة مربعة وغير مفردة. القيم الذاتية بتتحسب عدديًا '
                      'من كثيرة الحدود المميزة، وقد تظهر تقريبية لدرجات 3 و4.',
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CalcResultBanner(
                isError: true,
                child: Text(_error!, textDirection: TextDirection.rtl),
              ),
            ),
          if (_result != null)
            CalcModeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalcSectionTitle(
                    title: _operation?.split('\n').first ?? 'النتيجة',
                    subtitle: _operation?.contains('\n') == true
                        ? _operation!.split('\n').last
                        : null,
                    trailing: _operation?.split('\n').first == 'det(A)'
                        ? null
                        : const CalcPill(label: 'MATRIX', compact: true),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? Colors.black.withValues(alpha: 0.24)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.divider),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        _result!,
                        style: CalcTypography.math(palette, size: 15).copyWith(
                          height: 1.65,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ),
                  if (_detail != null) ...[
                    const SizedBox(height: 7),
                    CalcNote(text: _detail!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _matrixCard(
    CalcPalette palette, {
    required String name,
    required List<TextEditingController> controllers,
    required int rows,
    required int columns,
    required ValueChanged<int> onRows,
    required ValueChanged<int> onColumns,
    required List<Widget> actions,
  }) {
    return CalcModeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcSectionTitle(
            title: 'المصفوفة $name',
            subtitle: '$rows×$columns',
            trailing: CalcPill(
              label: name,
              compact: true,
              color: name == 'A' ? palette.accent : palette.shift,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _sizeColumn('الصفوف', rows, onRows, palette),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _sizeColumn('الأعمدة', columns, onColumns, palette),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _grid(controllers, rows, columns, name),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sizeColumn(
    String label,
    int selected,
    ValueChanged<int> onChanged,
    CalcPalette palette,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: CalcTypography.label(palette, size: 9.5).copyWith(
            color: palette.mathMuted,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 4),
        CalcSegmented<int>(
          values: const <int>[1, 2, 3, 4],
          selected: selected,
          labelFor: (value) => '$value',
          compact: true,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _grid(
    List<TextEditingController> controllers,
    int rows,
    int columns,
    String name,
  ) {
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: 5),
          Row(
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 5),
                Expanded(
                  child: _MatrixCell(
                    controller: controllers[row * 4 + column],
                    label: '$name${row + 1}${column + 1}',
                    onChanged: () {
                      setState(() {
                        _result = null;
                        _error = null;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Semantics(
      label: 'خانة $label',
      textField: true,
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: CalcTypography.math(palette, size: 14),
        cursorColor: palette.accent,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: palette.isDark
              ? Colors.black.withValues(alpha: 0.23)
              : Colors.white.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: palette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: palette.accent, width: 1.3),
          ),
        ),
      ),
    );
  }
}
