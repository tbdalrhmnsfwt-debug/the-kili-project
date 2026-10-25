/// CAS mode exposing the calculator's honest symbolic subset.
///
/// Symbolic differentiation, polynomial integration/factoring and structural
/// simplification are supported. Everything else reports `Not Supported`
/// instead of inventing a result. Definite integration and the derivative at a
/// point are explicitly labelled numerical.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calc_session.dart';
import '../engine/calculator_error.dart';
import '../engine/cas.dart';
import '../engine/evaluator.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import '../ui/natural_math.dart';
import 'mode_scaffold.dart';

class CasMode extends StatefulWidget {
  const CasMode({super.key, required this.session});

  final CalcSession session;

  @override
  State<CasMode> createState() => _CasModeState();
}

class _CasModeState extends State<CasMode> {
  final TextEditingController _expression =
      TextEditingController(text: 'x^2 + 3x + 2');
  final TextEditingController _variable = TextEditingController(text: 'x');
  final TextEditingController _lower = TextEditingController(text: '0');
  final TextEditingController _upper = TextEditingController(text: '1');
  final TextEditingController _point = TextEditingController(text: '1');
  final CasEngine _engine = const CasEngine();
  String? _result;
  String? _resultLabel;
  String? _note;
  String? _error;
  bool _exact = true;

  @override
  void dispose() {
    _expression.dispose();
    _variable.dispose();
    _lower.dispose();
    _upper.dispose();
    _point.dispose();
    super.dispose();
  }

  String get _variableName {
    final name = _variable.text.trim();
    if (RegExp(r'^[A-Za-zθ]$').hasMatch(name)) return name;
    throw const CalcError(
      CalcErrorKind.argument,
      detail: 'اسم المتغير لازم يكون حرف واحد، مثل x أو t أو θ.',
    );
  }

  void _run(
    String label,
    String Function(String source, String variable) operation, {
    String note = '',
    bool exact = true,
  }) {
    try {
      final source = _expression.text.trim();
      if (source.isEmpty) {
        throw const CalcError(
          CalcErrorKind.empty,
          detail: 'اكتب تعبير رمزي أولًا.',
        );
      }
      final result = operation(source, _variableName);
      setState(() {
        _result = result;
        _resultLabel = label;
        _note = note;
        _error = null;
        _exact = exact;
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _resultLabel = null;
        _note = null;
      });
    }
  }

  void _simplify() {
    _run(
      'تبسيط',
      (source, variable) => _engine.simplify(source),
      note: 'تبسيط بنيوي وكثيرات حدود نسبية؛ مش تحليل شامل لكل الصيغ.',
    );
  }

  void _differentiate() {
    _run(
      'المشتقة',
      (source, variable) => _engine.differentiate(source, variable).expression,
      note: 'المشتقة رمزية دقيقة. القواعد المدعومة: + − × ÷ ^ √ والدوال الشائعة.',
    );
  }

  void _integrate() {
    _run(
      'التكامل غير المحدد',
      (source, variable) => _engine.integrate(source, variable).expression,
      note: 'تكامل رمزي لكثيرات الحدود فقط، مع ثابت التكامل C.',
    );
  }

  void _factor() {
    _run(
      'التحليل إلى عوامل',
      (source, variable) => _engine.factor(source, variable: variable).expression,
      note: 'تحليل على الأعداد النسبية فقط؛ العوامل غير النسبية مش هتظهر.',
    );
  }

  void _definiteIntegral() {
    try {
      final source = _expression.text.trim();
      if (source.isEmpty) throw const CalcError(CalcErrorKind.empty);
      final variable = _variableName;
      final lower = _lower.text.trim();
      final upper = _upper.text.trim();
      if (lower.isEmpty || upper.isEmpty) {
        throw const CalcError(
          CalcErrorKind.argument,
          detail: 'اكتب حدود التكامل.',
        );
      }
      final expression = parseExpression(
        'integral(($source), $variable, $lower, $upper)',
      );
      final value = Evaluator(
        EvalContext(angleUnit: widget.session.settings.angleUnit),
      ).evaluate(expression);
      final formatted = formatCalcValue(value).display;
      setState(() {
        _result = formatted;
        _resultLabel = 'التكامل المحدد (عددي)';
        _note =
            'تكامل عددي بطريقة Simpson التكيفية من $lower إلى $upper. '
            'النتيجة تقريبية، وليست تعبيرًا رمزيًا.';
        _error = null;
        _exact = false;
      });
      HapticFeedback.mediumImpact();
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _resultLabel = null;
        _note = null;
      });
    }
  }

  void _derivativeAtPoint() {
    try {
      final source = _expression.text.trim();
      if (source.isEmpty) throw const CalcError(CalcErrorKind.empty);
      final variable = _variableName;
      final point = _point.text.trim();
      final expression = parseExpression(
        'diff(($source), $variable, $point)',
      );
      final value = Evaluator(
        EvalContext(angleUnit: widget.session.settings.angleUnit),
      ).evaluate(expression);
      setState(() {
        _result = formatCalcValue(value).display;
        _resultLabel = 'المشتقة عند نقطة (عددية)';
        _note =
            'فرق مركزي عددي عند $variable = $point. '
            'استخدم زر المشتقة للحصول على تعبير رمزي.';
        _error = null;
        _exact = false;
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _resultLabel = null;
        _note = null;
      });
    }
  }

  Future<void> _copyResult() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result));
    if (!mounted) return;
    setState(() {
      _note = 'النتيجة اتنسخت.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return CalcModePage(
      title: 'CAS — الجبر الرمزي',
      subtitle:
          'مشتقة، تكامل، تبسيط وتحليل — بمجموعة مدعومة بوضوح بدون نتائج ملفقة.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalcLabeledField(
                  label: 'التعبير',
                  controller: _expression,
                  hint: 'x^2 + 3x + 2',
                  onSubmitted: (_) => _simplify(),
                ),
                const SizedBox(height: 9),
                CalcFieldRow(
                  children: [
                    CalcLabeledField(
                      label: 'المتغير',
                      controller: _variable,
                      hint: 'x',
                    ),
                    CalcLabeledField(
                      label: 'نقطة المشتقة',
                      controller: _point,
                      hint: '1',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CalcActionGrid(
                  actions: <Widget>[
                    CalcSoftButton(
                      label: 'بسّط',
                      expanded: true,
                      icon: Icons.auto_fix_high_rounded,
                      onPressed: _simplify,
                    ),
                    CalcSoftButton(
                      label: 'اشتق',
                      expanded: true,
                      icon: Icons.linear_scale_rounded,
                      color: palette.accent,
                      onPressed: _differentiate,
                    ),
                    CalcSoftButton(
                      label: '∫ رمزي',
                      expanded: true,
                      icon: Icons.integration_instructions_rounded,
                      onPressed: _integrate,
                    ),
                    CalcSoftButton(
                      label: 'حلّل',
                      expanded: true,
                      icon: Icons.account_tree_outlined,
                      onPressed: _factor,
                    ),
                    CalcSoftButton(
                      label: 'd/dx عند نقطة',
                      expanded: true,
                      onPressed: _derivativeAtPoint,
                    ),
                    CalcSoftButton(
                      label: 'نسخ الناتج',
                      icon: Icons.copy_all_rounded,
                      expanded: true,
                      onPressed: _result == null ? null : _copyResult,
                    ),
                  ],
                ),
              ],
            ),
          ),
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalcSectionTitle(
                  title: 'التكامل المحدد',
                  subtitle:
                      'عددي تكيفي — منفصل عن التكامل الرمزي لكثيرات الحدود.',
                ),
                const SizedBox(height: 9),
                CalcFieldRow(
                  children: [
                    CalcLabeledField(
                      label: 'الحد الأدنى',
                      controller: _lower,
                      hint: '0',
                    ),
                    CalcLabeledField(
                      label: 'الحد الأعلى',
                      controller: _upper,
                      hint: '1',
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                CalcSoftButton(
                  label: 'احسب التكامل المحدد',
                  icon: Icons.functions_rounded,
                  expanded: true,
                  color: palette.accent,
                  onPressed: _definiteIntegral,
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
                    title: _resultLabel ?? 'النتيجة',
                    subtitle: _note,
                    trailing: CalcPill(
                      label: _exact ? 'SYMBOLIC' : 'NUMERIC',
                      compact: true,
                      color: _exact ? palette.shift : palette.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    constraints: const BoxConstraints(minHeight: 52),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? Colors.black.withValues(alpha: 0.24)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _exact
                            ? palette.shift.withValues(alpha: 0.3)
                            : palette.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: _exact
                        ? NaturalMathView(
                            source: _result!,
                            fontSize: 20,
                            maxLines: 5,
                          )
                        : Text(
                            _result!,
                            style: CalcTypography.math(
                              palette,
                              size: 20,
                              color: palette.accent,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                  ),
                  const SizedBox(height: 8),
                  const CalcNote(
                    icon: Icons.verified_outlined,
                    text:
                        'المحرك الرمزي محلي ومكتوب في Dart. مش بيستخدم Symja أو أي مكتبة Java/JNI، '
                        'وبيرفض العمليات خارج مجموعته المدعومة بدل ما يخمّن.',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
