/// EQN mode: polynomial roots of degree 2–4 and simultaneous linear systems
/// from 2×2 to 4×4.
library;

import 'package:flutter/material.dart';

import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/linear_systems.dart';
import '../engine/math_value.dart';
import '../engine/matrix.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../engine/polynomial.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

enum _EquationKind { polynomial, system }

class EqnMode extends StatefulWidget {
  const EqnMode({super.key, required this.angleUnit, this.haptics = true});

  /// Coefficients may contain trigonometric functions, so they must be read
  /// with the angle unit selected in settings.
  final AngleUnit angleUnit;

  /// Mirrors the calculator's haptics setting for the toggles in this mode.
  final bool haptics;

  @override
  State<EqnMode> createState() => _EqnModeState();
}

class _EqnModeState extends State<EqnMode> {
  _EquationKind _kind = _EquationKind.polynomial;
  int _degree = 2;
  int _size = 2;
  final List<TextEditingController> _coefficients = <TextEditingController>[
    for (var i = 0; i < 5; i++) TextEditingController(),
  ];
  final List<TextEditingController> _system = <TextEditingController>[
    for (var i = 0; i < 25; i++) TextEditingController(),
  ];
  String? _result;
  String? _error;
  String? _detail;
  bool _warning = false;

  @override
  void initState() {
    super.initState();
    _coefficients[0].text = '1';
    _coefficients[1].text = '0';
    _coefficients[2].text = '-4';
    for (var i = 0; i < _size * _size; i++) {
      _system[i].text = i % (_size + 1) == 0 ? '1' : '0';
    }
    for (var row = 0; row < _size; row++) {
      _system[_size * _size + row].text = '0';
    }
  }

  @override
  void dispose() {
    for (final controller in _coefficients) {
      controller.dispose();
    }
    for (final controller in _system) {
      controller.dispose();
    }
    super.dispose();
  }

  Rational _parseCoefficient(String raw, String label) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw CalcError(
        CalcErrorKind.argument,
        detail: 'املأ المعامل $label.',
      );
    }
    try {
      final value = Evaluator(
        EvalContext(angleUnit: widget.angleUnit),
      ).evaluate(parseExpression(text));
      if (!value.isReal) {
        throw CalcError(
          CalcErrorKind.argument,
          detail: 'المعامل $label لازم يكون عدد حقيقي.',
        );
      }
      if (value.exact != null) return value.exact!;
      // The solver works over the rationals. Only accept an inexact entry
      // when it is genuinely a simple rational (for example sin(30°)); an
      // irrational such as √2 or π would otherwise be silently replaced by a
      // nearby fraction and produce a wrong equation.
      final approximate = Rational.approximate(
        value.realPart,
        maxDenominator: 10000,
        tolerance: 1e-9,
      );
      if (approximate == null) {
        throw CalcError(
          CalcErrorKind.argument,
          detail: 'المعامل $label مش نسبي. الحل بالمعاملات النسبية فقط — '
              'استخدم عدد صحيح أو كسر أو قيمة عشرية.',
        );
      }
      return approximate;
    } on CalcError catch (error) {
      throw CalcError(
        error.kind,
        detail: 'المعامل $label: ${error.detail ?? error.hint}',
      );
    }
  }

  void _solvePolynomial() {
    try {
      final coefficients = <Rational>[
        for (var i = 0; i <= _degree; i++)
          _parseCoefficient(_coefficients[i].text, 'abcde'[i]),
      ];
      if (coefficients.first.isZero) {
        throw const CalcError(
          CalcErrorKind.argument,
          detail: 'معامل أعلى درجة (a) لا يساوي صفر.',
        );
      }
      final result = polynomialRoots(
        <double>[
          for (final coefficient in coefficients) coefficient.toDouble()
        ],
      );
      final buffer = StringBuffer();
      buffer.writeln(formatPolynomial(coefficients, 'x'));
      buffer.writeln('= 0');
      buffer.writeln();
      if (result.roots.isEmpty) {
        buffer.write('مفيش جذور.');
      } else {
        for (var i = 0; i < result.roots.length; i++) {
          buffer.writeln(
              'x${_subscript(i + 1)} = ${_formatRoot(result.roots[i])}');
        }
      }
      setState(() {
        _result = buffer.toString();
        _error = null;
        _detail = null;
        _warning = !result.converged || result.message != null;
        if (result.message != null) _detail = result.message;
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _detail = null;
        _warning = false;
      });
    }
  }

  String _formatRoot(ComplexRoot root) {
    if (root.isReal) {
      final exact = root.exactReal;
      if (exact != null) return formatRational(exact);
      final rounded = root.real.roundToDouble();
      if ((root.real - rounded).abs() < 1e-10) {
        return formatRational(Rational.fromInt(rounded.toInt()));
      }
      return formatReal(root.real);
    }
    final real = root.real.abs() < 1e-12 ? '' : '${formatReal(root.real)} ';
    final imaginary = formatReal(root.imaginary.abs());
    final coefficient = root.imaginary.abs() == 1 ? '' : imaginary;
    final sign = root.imaginary < 0 ? '−' : '+';
    return '$real$sign ${coefficient}i'.trim();
  }

  String _subscript(int number) {
    const digits = '₀₁₂₃₄₅₆₇₈₉';
    return '$number'.split('').map((digit) {
      final value = int.tryParse(digit);
      return value == null ? digit : digits[value];
    }).join();
  }

  void _solveSystem() {
    try {
      final matrix = <List<double>>[];
      final rhs = <double>[];
      for (var row = 0; row < _size; row++) {
        final values = <double>[];
        for (var column = 0; column < _size; column++) {
          final coefficient = _parseCoefficient(
            _system[row * _size + column].text,
            '${_variable(row)}${_variable(column)}',
          );
          values.add(coefficient.toDouble());
        }
        matrix.add(values);
        final b = _parseCoefficient(
          _system[_size * _size + row].text,
          'b${_superscript(row + 1)}',
        );
        rhs.add(b.toDouble());
      }
      final solution = solveLinearSystem(matrix, rhs);
      final names = <String>[
        for (var i = 0; i < _size; i++) _variable(i),
      ];
      final matrixObject = Matrix(matrix);
      final buffer = StringBuffer();
      if (solution.hasUniqueSolution) {
        buffer.writeln(formatLinearSolution(solution, names));
      } else {
        buffer.writeln(solution.message ?? 'مفيش حل وحيد.');
      }
      buffer.writeln();
      buffer.write('det(A) = ${formatReal(matrixObject.determinant())}');
      setState(() {
        _result = buffer.toString();
        _error = null;
        _detail = solution.hasUniqueSolution ? null : solution.message;
        _warning = !solution.hasUniqueSolution;
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _detail = null;
        _warning = false;
      });
    }
  }

  String _variable(int index) => const <String>['x', 'y', 'z', 'w'][index];

  String _superscript(int number) {
    const digits = '⁰¹²³⁴⁵⁶⁷⁸⁹';
    return '$number'.split('').map((digit) {
      final value = int.tryParse(digit);
      return value == null ? digit : digits[value];
    }).join();
  }

  void _changeKind(_EquationKind kind) {
    setState(() {
      _kind = kind;
      _result = null;
      _error = null;
      _detail = null;
      _warning = false;
    });
  }

  void _changeDegree(int degree) {
    setState(() {
      _degree = degree;
      _result = null;
      _error = null;
      _detail = null;
      _warning = false;
    });
  }

  void _changeSize(int size) {
    setState(() {
      _size = size;
      _result = null;
      _error = null;
      _detail = null;
      _warning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return CalcModePage(
      title: 'EQN — المعادلات',
      subtitle: 'جذور حقيقية ومركبة لكثيرات الحدود، وحل أنظمة خطية حتى 4×4.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: CalcSegmented<_EquationKind>(
              values: _EquationKind.values,
              selected: _kind,
              labelFor: (kind) =>
                  kind == _EquationKind.polynomial ? 'كثيرة حدود' : 'نظام خطي',
              haptics: widget.haptics,
              onChanged: _changeKind,
            ),
          ),
          if (_kind == _EquationKind.polynomial)
            ..._polynomialSection(palette)
          else
            ..._systemSection(palette),
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
                  const CalcSectionTitle(
                    title: 'النتيجة',
                    subtitle: 'الجذور تقريبية إلا لما تكون نسبية بالكامل.',
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? Colors.black.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.divider),
                    ),
                    child: Text(
                      _result!,
                      style: CalcTypography.math(palette, size: 15),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  if (_warning && _detail != null) ...[
                    const SizedBox(height: 7),
                    CalcNote(
                      icon: Icons.warning_amber_rounded,
                      text: _detail!,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _polynomialSection(CalcPalette palette) {
    final labels = <String>['a', 'b', 'c', 'd', 'e'];
    String suffixFor(int index) {
      final power = _degree - index;
      return switch (power) {
        0 => '— الحد الثابت',
        1 => 'x',
        2 => 'x²',
        3 => 'x³',
        _ => 'x⁴',
      };
    }

    return [
      CalcModeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalcSectionTitle(
              title: 'كثيرة الحدود',
              subtitle: 'اختار الدرجة واكتب المعاملات من أعلى درجة لأسفل.',
              trailing: SizedBox(
                width: 142,
                child: CalcSegmented<int>(
                  values: const <int>[2, 3, 4],
                  selected: _degree,
                  labelFor: (degree) => 'درجة $degree',
                  compact: true,
                  haptics: widget.haptics,
                  onChanged: _changeDegree,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 9,
              children: [
                for (var i = 0; i <= _degree; i++)
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 70) / 3,
                    child: CalcLabeledField(
                      label: '${labels[i]} ${suffixFor(i)}',
                      controller: _coefficients[i],
                      hint: i == 0 ? '≠ 0' : '0',
                      autofocus: i == 0,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CalcSoftButton(
                    label: 'حل المعادلة',
                    icon: Icons.calculate_outlined,
                    expanded: true,
                    color: palette.accent,
                    onPressed: _solvePolynomial,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: CalcSoftButton(
                    label: 'مسح',
                    icon: Icons.clear_all_rounded,
                    expanded: true,
                    onPressed: () {
                      setState(() {
                        for (final controller in _coefficients) {
                          controller.clear();
                        }
                        _coefficients[0].text = '1';
                        _result = null;
                        _error = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const CalcNote(
              text: 'المعادلة على الصورة ax² + bx + c = 0 وهكذا. '
                  'الحل بيستخدم صيغًا مغلقة وحساب Durand–Kerner للدرجات الأعلى.',
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _systemSection(CalcPalette palette) {
    return [
      CalcModeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalcSectionTitle(
              title: 'نظام معادلات خطية',
              subtitle:
                  'عدد المعادلات = عدد المتغيرات. اكتب معاملات كل معادلة.',
              trailing: SizedBox(
                width: 118,
                child: CalcSegmented<int>(
                  values: const <int>[2, 3, 4],
                  selected: _size,
                  labelFor: (size) => '${size}×$size',
                  compact: true,
                  haptics: widget.haptics,
                  onChanged: _changeSize,
                ),
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                for (var column = 0; column < _size; column++) ...[
                  if (column > 0) const SizedBox(width: 5),
                  Expanded(
                    child: Center(
                      child: Text(
                        _variable(column),
                        style: CalcTypography.label(palette, size: 10),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 22),
                SizedBox(
                  width: 52,
                  child: Center(
                    child: Text(
                      '=',
                      style: CalcTypography.label(palette, size: 11),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            for (var row = 0; row < _size; row++) ...[
              if (row > 0) const SizedBox(height: 6),
              Row(
                children: [
                  for (var column = 0; column < _size; column++) ...[
                    if (column > 0) const SizedBox(width: 5),
                    Expanded(
                      child: _CompactNumberField(
                        controller: _system[row * _size + column],
                        hint: '0',
                        semanticLabel:
                            'معامل ${_variable(row)} في المعادلة ${row + 1}',
                      ),
                    ),
                  ],
                  const SizedBox(width: 22),
                  SizedBox(
                    width: 52,
                    child: _CompactNumberField(
                      controller: _system[_size * _size + row],
                      hint: '0',
                      semanticLabel: 'الطرف الأيمن للمعادلة ${row + 1}',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CalcSoftButton(
                    label: 'حل النظام',
                    icon: Icons.grid_on_rounded,
                    expanded: true,
                    color: palette.accent,
                    onPressed: _solveSystem,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: CalcSoftButton(
                    label: 'مسح',
                    icon: Icons.clear_all_rounded,
                    expanded: true,
                    onPressed: () {
                      setState(() {
                        for (var i = 0; i < 25; i++) {
                          _system[i].clear();
                        }
                        _result = null;
                        _error = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const CalcNote(
              text: 'النظام بيتم حله بحذف غاوس مع pivoting جزئي. '
                  'لو المحدد صفر، النتيجة بتوضح هل النظام متسق وله حلول لا نهائية أو غير متسق.',
            ),
          ],
        ),
      ),
    ];
  }
}

class _CompactNumberField extends StatelessWidget {
  const _CompactNumberField({
    required this.controller,
    required this.hint,
    required this.semanticLabel,
  });

  final TextEditingController controller;
  final String hint;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Semantics(
      label: semanticLabel,
      textField: true,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: CalcTypography.math(palette, size: 14).copyWith(
          fontWeight: FontWeight.w600,
        ),
        cursorColor: palette.accent,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: palette.isDark
              ? Colors.black.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.58),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
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
