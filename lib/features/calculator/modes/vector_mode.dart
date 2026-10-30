/// VECTOR mode for 2D and 3D vector arithmetic.
library;

import 'package:flutter/material.dart';

import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../engine/vector.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

class VectorMode extends StatefulWidget {
  const VectorMode({super.key, required this.angleUnit, this.haptics = true});

  /// Components may contain trigonometric functions, so they follow the
  /// selected angle unit.
  final AngleUnit angleUnit;

  /// Mirrors the calculator's haptics setting for the toggles in this mode.
  final bool haptics;

  @override
  State<VectorMode> createState() => _VectorModeState();
}

class _VectorModeState extends State<VectorMode> {
  int _dimension = 2;
  final List<TextEditingController> _a = <TextEditingController>[
    for (var i = 0; i < 3; i++) TextEditingController(),
  ];
  final List<TextEditingController> _b = <TextEditingController>[
    for (var i = 0; i < 3; i++) TextEditingController(),
  ];
  String? _result;
  String? _operation;
  String? _error;
  String? _note;

  @override
  void initState() {
    super.initState();
    _a[0].text = '1';
    _a[1].text = '0';
    _b[0].text = '0';
    _b[1].text = '1';
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

  double _component(TextEditingController controller, String label) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      throw CalcError(
        CalcErrorKind.argument,
        detail: 'المكوّن $label فاضي.',
      );
    }
    try {
      final value = Evaluator(
        EvalContext(angleUnit: widget.angleUnit),
      ).evaluate(parseExpression(text));
      if (!value.isReal) {
        throw CalcError(
          CalcErrorKind.argument,
          detail: 'المكوّن $label لازم يكون حقيقي.',
        );
      }
      return value.realPart;
    } on CalcError catch (error) {
      throw CalcError(
        error.kind,
        detail: 'المكوّن $label: ${error.detail ?? error.hint}',
      );
    }
  }

  VectorValue _vector(List<TextEditingController> controllers, String name) {
    return VectorValue(<double>[
      for (var i = 0; i < _dimension; i++)
        _component(controllers[i], '$name${i + 1}'),
    ]);
  }

  void _run(
      String label, String Function(VectorValue a, VectorValue b) action) {
    try {
      final a = _vector(_a, 'a');
      final b = _vector(_b, 'b');
      final result = action(a, b);
      setState(() {
        _result = result;
        _operation = label;
        _error = null;
        _note = _dimension == 3
            ? 'المتجهات ثلاثية الأبعاد.'
            : 'المتجهات ثنائية الأبعاد؛ الضرب الاتجاهي محتاج 3D.';
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _operation = null;
        _note = null;
      });
    }
  }

  String _formatScalar(double value) => formatReal(value);

  void _normA() {
    try {
      final a = _vector(_a, 'a');
      setState(() {
        _result = '‖a‖ = ${formatReal(a.norm)}';
        _operation = 'طول المتجه a';
        _error = null;
        _note = 'الطول دائمًا غير سالب.';
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _operation = null;
        _note = null;
      });
    }
  }

  void _switchDimension(int dimension) {
    setState(() {
      _dimension = dimension;
      _result = null;
      _operation = null;
      _error = null;
      _note = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return CalcModePage(
      title: 'VECTOR — المتجهات',
      subtitle: 'جمع وطرح وضرب نقطي واتجاهي، طول وزاوية وإسقاط.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalcSegmented<int>(
                  values: const <int>[2, 3],
                  selected: _dimension,
                  labelFor: (value) => value == 2 ? '2D' : '3D',
                  haptics: widget.haptics,
                  onChanged: _switchDimension,
                ),
                const SizedBox(height: 11),
                _vectorEditor(palette, 'a', _a, palette.accent),
                const SizedBox(height: 10),
                _vectorEditor(palette, 'b', _b, palette.shift),
                const SizedBox(height: 9),
                const CalcNote(
                  text: 'الضرب الاتجاهي (a×b) متاح لـ 3D فقط. '
                      'الزاوية بين المتجهين بتتحسب بالدرجات دائمًا.',
                ),
              ],
            ),
          ),
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CalcSectionTitle(
                  title: 'العمليات',
                  subtitle: 'كل عملية بتعيد حساب المكوّنات من الحقول الحالية.',
                ),
                const SizedBox(height: 10),
                CalcActionGrid(
                  actions: <Widget>[
                    CalcSoftButton(
                      label: 'a + b',
                      expanded: true,
                      onPressed: () =>
                          _run('a + b', (a, b) => (a + b).format()),
                    ),
                    CalcSoftButton(
                      label: 'a − b',
                      expanded: true,
                      onPressed: () =>
                          _run('a − b', (a, b) => (a - b).format()),
                    ),
                    CalcSoftButton(
                      label: 'a · b',
                      expanded: true,
                      color: palette.accent,
                      onPressed: () => _run(
                        'a · b',
                        (a, b) => 'a · b = ${_formatScalar(a.dot(b))}',
                      ),
                    ),
                    CalcSoftButton(
                      label: 'a × b',
                      expanded: true,
                      onPressed: () => _run(
                        'a × b',
                        (a, b) => 'a × b = ${a.cross(b).format()}',
                      ),
                    ),
                    CalcSoftButton(
                      label: '‖a‖',
                      expanded: true,
                      onPressed: _normA,
                    ),
                    CalcSoftButton(
                      label: 'â',
                      expanded: true,
                      onPressed: () => _run(
                        'وحدة الاتجاه â',
                        (a, b) => a.normalized.format(),
                      ),
                    ),
                    CalcSoftButton(
                      label: '∠(a, b)',
                      expanded: true,
                      onPressed: () => _run(
                        'الزاوية بين a وb',
                        (a, b) => '∠ = ${_formatScalar(a.angleBetween(b))}°',
                      ),
                    ),
                    CalcSoftButton(
                      label: 'إسقاط a على b',
                      expanded: true,
                      onPressed: () => _run(
                        'إسقاط a على b',
                        (a, b) => 'proj_b(a) = ${a.projectionOnto(b).format()}',
                      ),
                    ),
                  ],
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
                    title: _operation ?? 'النتيجة',
                    subtitle: _note,
                    trailing: const CalcPill(
                      label: 'VECTOR',
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _result!,
                      style: CalcTypography.math(
                        palette,
                        size: 17,
                        color: palette.accent,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _vectorEditor(
    CalcPalette palette,
    String name,
    List<TextEditingController> controllers,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CalcPill(label: name, compact: true, color: color, active: true),
            const SizedBox(width: 7),
            Text(
              _dimension == 2 ? 'ثنائي الأبعاد' : 'ثلاثي الأبعاد',
              style: CalcTypography.label(palette, size: 10).copyWith(
                color: palette.mathMuted,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            for (var i = 0; i < _dimension; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: CalcLabeledField(
                  label: '${name}${_subscript(i + 1)}',
                  controller: controllers[i],
                  hint: '0',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _subscript(int number) {
    const digits = '₀₁₂₃₄₅₆₇₈₉';
    return '$number'.split('').map((digit) {
      final value = int.tryParse(digit);
      return value == null ? digit : digits[value];
    }).join();
  }
}
