/// STAT mode: one-variable statistics and two-variable regression.
library;

import 'package:flutter/material.dart';

import '../calc_session.dart';
import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../engine/statistics.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

class StatMode extends StatefulWidget {
  const StatMode({super.key, required this.session});

  final CalcSession session;

  @override
  State<StatMode> createState() => _StatModeState();
}

class _StatModeState extends State<StatMode> {
  final TextEditingController _xInput = TextEditingController();
  final TextEditingController _yInput = TextEditingController();
  final TextEditingController _predictInput = TextEditingController();
  final List<double> _xs = <double>[];
  final List<double> _ys = <double>[];
  bool _twoVariable = false;
  bool _quadratic = false;
  StatisticsSummary? _xSummary;
  StatisticsSummary? _ySummary;
  RegressionResult? _regression;
  String? _error;
  String? _prediction;
  String? _notice;

  @override
  void dispose() {
    _xInput.dispose();
    _yInput.dispose();
    _predictInput.dispose();
    super.dispose();
  }

  List<double> _parseList(String source) {
    final pieces = source
        .split(RegExp(r'[,;\s]+'))
        .where((piece) => piece.trim().isNotEmpty);
    final values = <double>[];
    final context = EvalContext(angleUnit: widget.session.settings.angleUnit);
    for (final piece in pieces) {
      try {
        final value = Evaluator(context).evaluate(parseExpression(piece));
        if (!value.isReal) {
          throw const CalcError(
            CalcErrorKind.argument,
            detail: 'STAT بيقبل أعداد حقيقية فقط.',
          );
        }
        values.add(value.realPart);
      } on CalcError catch (error) {
        throw CalcError(
          CalcErrorKind.syntax,
          detail: '«$piece»: ${error.detail ?? error.label}',
        );
      }
    }
    if (values.isEmpty) {
      throw const CalcError(
        CalcErrorKind.argument,
        detail: 'اكتب قيمة واحدة على الأقل.',
      );
    }
    return values;
  }

  void _add() {
    try {
      final xs = _parseList(_xInput.text);
      if (_twoVariable) {
        final ys = _parseList(_yInput.text);
        if (xs.length != ys.length) {
          throw CalcError(
            CalcErrorKind.dimension,
            detail:
                'عدد قيم X (${xs.length}) لازم يساوي عدد قيم Y (${ys.length}).',
          );
        }
        _xs.addAll(xs);
        _ys.addAll(ys);
      } else {
        _xs.addAll(xs);
      }
      _xInput.clear();
      _yInput.clear();
      _error = null;
      _notice = null;
      _calculate();
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
      });
    }
  }

  void _calculate() {
    setState(() {
      _error = null;
      _prediction = null;
      _xSummary = null;
      _ySummary = null;
      _regression = null;
      if (_xs.isEmpty) {
        _error = 'أضف بيانات أولًا.';
        return;
      }
      try {
        _xSummary = StatisticsSummary.fromValues(_xs);
        if (_twoVariable) {
          if (_xs.length < 2) {
            throw const CalcError(
              CalcErrorKind.argument,
              detail: 'الانحدار محتاج نقطتين على الأقل.',
            );
          }
          if (_ys.length != _xs.length) {
            throw const CalcError(CalcErrorKind.dimension);
          }
          _ySummary = StatisticsSummary.fromValues(_ys);
          _regression = _quadratic
              ? quadraticRegression(_xs, _ys)
              : linearRegression(_xs, _ys);
          _updatePrediction();
        }
      } on CalcError catch (error) {
        _error = '${error.label}: ${error.detail ?? error.hint}';
      } on ArgumentError catch (error) {
        _error = 'Argument ERROR: ${error.message}';
      }
    });
  }

  void _updatePrediction() {
    final regression = _regression;
    final raw = _predictInput.text.trim();
    if (regression == null || raw.isEmpty) {
      _prediction = null;
      return;
    }
    final x = double.tryParse(raw);
    if (x == null) {
      _prediction = 'قيمة x غير صالحة.';
      return;
    }
    final coeff = regression.coefficients;
    final y = regression.kind == 'quadratic'
        ? coeff[0] * x * x + coeff[1] * x + coeff[2]
        : coeff[0] * x + coeff[1];
    _prediction = 'ŷ(${formatReal(x)}) = ${formatReal(y)}';
  }

  void _removeAt(int index) {
    setState(() {
      if (index < _xs.length) _xs.removeAt(index);
      if (_twoVariable && index < _ys.length) _ys.removeAt(index);
    });
    _calculate();
  }

  void _clearAll() {
    setState(() {
      _xs.clear();
      _ys.clear();
      _xSummary = null;
      _ySummary = null;
      _regression = null;
      _error = null;
      _prediction = null;
      _notice = null;
      _xInput.clear();
      _yInput.clear();
      _predictInput.clear();
    });
  }

  void _switchMode(bool twoVariable) {
    if (twoVariable == _twoVariable) return;
    setState(() {
      _twoVariable = twoVariable;
      // X-only rows cannot be paired with later Y input, so switching starts a
      // clean dataset instead of leaving an unusable half-filled table.
      _xs.clear();
      _ys.clear();
      _quadratic = false;
      _xSummary = null;
      _ySummary = null;
      _regression = null;
      _error = null;
      _prediction = null;
      _xInput.clear();
      _yInput.clear();
      _predictInput.clear();
      _notice = twoVariable
          ? 'اتفرغت البيانات للتبديل إلى 2-VAR. أضف كل زوج X وY مع بعض.'
          : 'اتفرغت البيانات للتبديل إلى 1-VAR.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return CalcModePage(
      title: 'STAT — الإحصاء',
      subtitle: 'إحصاء وصفي لمتغير واحد، وانحدار خطي أو تربيعي لمتغيرين.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalcSegmented<bool>(
                  values: const <bool>[false, true],
                  selected: _twoVariable,
                  labelFor: (value) => value ? '2-VAR' : '1-VAR',
                  onChanged: _switchMode,
                ),
                const SizedBox(height: 11),
                CalcLabeledField(
                  label: _twoVariable ? 'قيم X' : 'القيم',
                  controller: _xInput,
                  hint: '1, 2, 3 أو 4 5 6',
                  keyboardType: TextInputType.text,
                  onSubmitted: (_) => _add(),
                ),
                if (_twoVariable) ...[
                  const SizedBox(height: 9),
                  CalcLabeledField(
                    label: 'قيم Y',
                    controller: _yInput,
                    hint: '2, 4, 6',
                    onSubmitted: (_) => _add(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CalcSoftButton(
                        label: 'إضافة',
                        icon: Icons.add_rounded,
                        expanded: true,
                        onPressed: _add,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: CalcSoftButton(
                        label: 'حساب',
                        icon: Icons.functions_rounded,
                        expanded: true,
                        onPressed: _calculate,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: CalcSoftButton(
                        label: 'مسح',
                        icon: Icons.delete_sweep_outlined,
                        expanded: true,
                        color: palette.danger,
                        onPressed: _xs.isEmpty ? null : _clearAll,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CalcNote(
                  text:
                      'القيم بتتقبل تعبيرات زي 1/2 أو π، وبتتقسم بفاصلة أو مسافة. '
                      'الانحدار التربيعي محتاج 3 نقاط مختلفة على الأقل.',
                ),
              ],
            ),
          ),
          if (_xs.isNotEmpty)
            CalcModeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalcSectionTitle(
                    title: 'البيانات (${_xs.length})',
                    subtitle: 'اضغط على × لحذف نقطة وإعادة الحساب.',
                  ),
                  const SizedBox(height: 9),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 168),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          for (var i = 0; i < _xs.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: _DataRow(
                                index: i + 1,
                                x: _xs[i],
                                y: _twoVariable && i < _ys.length
                                    ? _ys[i]
                                    : null,
                                onDelete: () => _removeAt(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _notice!,
                style: CalcTypography.label(palette, size: 10.5).copyWith(
                  color: palette.accent,
                  height: 1.4,
                ),
                textDirection: TextDirection.rtl,
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
          if (_xSummary != null)
            CalcModeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalcSectionTitle(
                    title: _twoVariable ? 'إحصاء X' : 'الإحصاء الوصفي',
                    subtitle: _twoVariable
                        ? 'نفس المقاييس مطبقة على قيم X.'
                        : 'النتائج محسوبة من كل القيم المضافة.',
                  ),
                  const SizedBox(height: 10),
                  _summaryGrid(_xSummary!),
                ],
              ),
            ),
          if (_ySummary != null)
            CalcModeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CalcSectionTitle(
                    title: 'إحصاء Y',
                    subtitle: 'المقاييس الوصفية لقيم Y.',
                  ),
                  const SizedBox(height: 10),
                  _summaryGrid(_ySummary!),
                ],
              ),
            ),
          if (_twoVariable && _xs.length >= 2)
            CalcModeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalcSectionTitle(
                    title: 'الانحدار',
                    subtitle: 'خطي أو تربيعي بطريقة المربعات الصغرى.',
                    trailing: SizedBox(
                      width: 150,
                      child: CalcSegmented<bool>(
                        values: const <bool>[false, true],
                        selected: _quadratic,
                        labelFor: (value) => value ? 'تربيعي' : 'خطي',
                        compact: true,
                        onChanged: (value) {
                          setState(() {
                            _quadratic = value;
                          });
                          _calculate();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_regression != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _regression!.equation,
                        textAlign: TextAlign.left,
                        style: CalcTypography.math(
                          palette,
                          size: 17,
                          color: palette.accent,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _metric('r', formatReal(_regression!.correlation)),
                        _metric('R²', formatReal(_regression!.rSquared)),
                        _metric('n', '${_xs.length}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CalcLabeledField(
                      label: 'توقع قيمة ŷ عند x =',
                      controller: _predictInput,
                      hint: '5',
                      onChanged: (_) {
                        setState(_updatePrediction);
                      },
                    ),
                    if (_prediction != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _prediction!,
                        style: CalcTypography.math(
                          palette,
                          size: 15,
                          color: palette.accent,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryGrid(StatisticsSummary summary) {
    final entries = <(String, String)>[
      ('n', '${summary.count}'),
      ('Σx', formatReal(summary.sum)),
      ('Σx²', formatReal(summary.sumSquares)),
      ('x̄', formatReal(summary.mean)),
      ('الوسيط', formatReal(summary.median)),
      (
        'المنوال',
        summary.modes.isEmpty
            ? 'لا يوجد'
            : summary.modes.map(formatReal).join(', ')
      ),
      ('Q₁', formatReal(summary.q1)),
      ('Q₃', formatReal(summary.q3)),
      ('IQR', formatReal(summary.iqr)),
      ('s', formatReal(summary.sdSample)),
      ('σ', formatReal(summary.sdPopulation)),
      ('المدى', formatReal(summary.range)),
      ('أصغر', formatReal(summary.minimum)),
      ('أكبر', formatReal(summary.maximum)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 14) / 3;
        final safeWidth = width < 78 ? (constraints.maxWidth - 7) / 2 : width;
        return Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final entry in entries)
              SizedBox(
                width: safeWidth,
                child: CalcMetric(label: entry.$1, value: entry.$2),
              ),
          ],
        );
      },
    );
  }

  Widget _metric(String label, String value) => CalcMetric(
        label: label,
        value: value,
        accent: true,
      );
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.index,
    required this.x,
    required this.y,
    required this.onDelete,
  });

  final int index;
  final double x;
  final double? y;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2, top: 3, bottom: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$index',
              style: CalcTypography.label(palette, size: 10).copyWith(
                color: palette.mathMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              y == null
                  ? 'x = ${formatReal(x)}'
                  : 'x = ${formatReal(x)}   ·   y = ${formatReal(y!)}',
              style: CalcTypography.math(palette, size: 13),
              textDirection: TextDirection.ltr,
            ),
          ),
          SizedBox(
            width: 34,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: 'حذف',
              onPressed: onDelete,
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: palette.mathMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
