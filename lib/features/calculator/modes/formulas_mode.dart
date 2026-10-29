/// Searchable offline formula reference with live evaluation.
library;

import 'package:flutter/material.dart';

import '../calc_session.dart';
import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/formulas.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import '../ui/natural_math.dart';
import 'mode_scaffold.dart';

class FormulasMode extends StatefulWidget {
  const FormulasMode({super.key, required this.session});

  final CalcSession session;

  @override
  State<FormulasMode> createState() => _FormulasModeState();
}

class _FormulasModeState extends State<FormulasMode> {
  final TextEditingController _search = TextEditingController();
  final Map<String, TextEditingController> _inputs =
      <String, TextEditingController>{};
  String? _selectedId;
  String? _category;
  ValueFormat? _result;
  String? _error;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _disposeInputs();
    super.dispose();
  }

  void _disposeInputs() {
    for (final controller in _inputs.values) {
      controller.dispose();
    }
    _inputs.clear();
  }

  void _select(FormulaEntry formula) {
    FocusScope.of(context).unfocus();
    setState(() {
      if (_selectedId == formula.id) {
        _selectedId = null;
        _disposeInputs();
      } else {
        _selectedId = formula.id;
        _disposeInputs();
        for (final variable in formula.variables) {
          _inputs[variable.symbol] = TextEditingController();
        }
      }
      _result = null;
      _error = null;
    });
  }

  double _parseValue(String raw, String label) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw CalcError(
        CalcErrorKind.argument,
        detail: 'املأ $label.',
      );
    }
    try {
      final value = Evaluator(
        EvalContext(angleUnit: widget.session.settings.angleUnit),
      ).evaluate(parseExpression(text));
      if (!value.isReal) {
        throw CalcError(
          CalcErrorKind.argument,
          detail: '$label لازم يكون قيمة حقيقية.',
        );
      }
      return value.realPart;
    } on CalcError catch (error) {
      throw CalcError(
        error.kind,
        detail: '$label: ${error.detail ?? error.hint}',
      );
    }
  }

  void _evaluate(FormulaEntry formula) {
    try {
      final values = <String, double>{};
      for (final variable in formula.variables) {
        values[variable.symbol] = _parseValue(
          _inputs[variable.symbol]?.text ?? '',
          variable.nameAr,
        );
      }
      final value = formula.evaluate(
        values,
        angleUnit: widget.session.settings.angleUnit,
      );
      setState(() {
        _result = formatCalcValue(
          value,
          preferExact: false,
          angleUnit: widget.session.settings.angleUnit,
        );
        _error = null;
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final categories = <String>{
      for (final formula in formulaLibrary) formula.category,
    }.toList(growable: false)
      ..sort();
    var formulas = searchFormulas(_query);
    if (_category != null) {
      formulas = formulas
          .where((formula) => formula.category == _category)
          .toList(growable: false);
    }
    return CalcModePage(
      title: 'مكتبة القوانين',
      subtitle:
          'مرجع محلي قابل للبحث، وكل قانون بيتقيّم بقيمك داخل نفس الحاسبة.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  textDirection: TextDirection.rtl,
                  style: CalcTypography.label(palette, size: 13),
                  cursorColor: palette.accent,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الصيغة أو التصنيف…',
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: TextStyle(color: palette.mathMuted),
                    isDense: true,
                    filled: true,
                    fillColor: palette.isDark
                        ? Colors.black.withValues(alpha: 0.24)
                        : Colors.white.withValues(alpha: 0.6),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: palette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(
                        color: palette.accent,
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      CalcPill(
                        label: 'الكل',
                        compact: true,
                        active: _category == null,
                        onTap: () {
                          setState(() {
                            _category = null;
                          });
                        },
                      ),
                      for (final category in categories) ...[
                        const SizedBox(width: 5),
                        CalcPill(
                          label: category,
                          compact: true,
                          active: _category == category,
                          onTap: () {
                            setState(() {
                              _category =
                                  _category == category ? null : category;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${formulas.length} قانون · ${widget.session.settings.angleUnit.label} للدوال المثلثية',
                  style: CalcTypography.label(palette, size: 9.5).copyWith(
                    color: palette.mathMuted,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          if (formulas.isEmpty)
            const CalcModeCard(
              child: CalcEmptyState(
                icon: Icons.search_off_rounded,
                title: 'مفيش نتائج',
                message: 'جرّب كلمة تانية أو غيّر التصنيف.',
              ),
            )
          else
            for (final formula in formulas)
              _formulaCard(context, palette, formula),
          const CalcNote(
            icon: Icons.menu_book_outlined,
            text: 'القوانين مرجع دراسي عام وليست قائمة منهج رسمي. '
                'الوحدات المكتوبة بجانب المتغيرات إرشادية، والحاسبة لا تحوّل الوحدات تلقائيًا داخل القانون.',
          ),
        ],
      ),
    );
  }

  Widget _formulaCard(
    BuildContext context,
    CalcPalette palette,
    FormulaEntry formula,
  ) {
    final selected = _selectedId == formula.id;
    return CalcModeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _select(formula),
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formula.nameAr,
                            style: CalcTypography.title(palette, size: 14),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formula.nameEn,
                            style: CalcTypography.label(palette, size: 9.5)
                                .copyWith(color: palette.mathMuted),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CalcPill(
                      label: formula.category,
                      compact: true,
                      color: selected ? palette.accent : palette.label,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      selected
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 19,
                      color: palette.mathMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: NaturalMathView(
                    source: formula.expression,
                    fontSize: 16,
                    maxLines: 3,
                    color: palette.math,
                  ),
                ),
                if (formula.noteAr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    formula.noteAr,
                    style: CalcTypography.label(palette, size: 9.5).copyWith(
                      color: palette.mathMuted,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: palette.divider),
            const SizedBox(height: 11),
            if (formula.variables.isEmpty)
              Text(
                'مفيش متغيرات مطلوبة.',
                style: CalcTypography.label(palette, size: 11).copyWith(
                  color: palette.mathMuted,
                ),
                textDirection: TextDirection.rtl,
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 8,
                children: [
                  for (final variable in formula.variables)
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 76) / 2,
                      child: CalcLabeledField(
                        label:
                            '${variable.symbol} — ${variable.nameAr}${variable.unit.isEmpty ? '' : ' (${variable.unit})'}',
                        controller: _inputs[variable.symbol]!,
                        hint: '0',
                        onSubmitted: (_) => _evaluate(formula),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 9),
            CalcSoftButton(
              label: 'احسب الناتج',
              icon: Icons.calculate_outlined,
              expanded: true,
              color: palette.accent,
              onPressed: () => _evaluate(formula),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              CalcResultBanner(
                isError: true,
                child: Text(_error!, textDirection: TextDirection.rtl),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _result!.display,
                        style: CalcTypography.math(
                          palette,
                          size: 18,
                          color: palette.accent,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    if (_result!.secondary != null)
                      Text(
                        _result!.secondary!,
                        style: CalcTypography.math(
                          palette,
                          size: 12,
                          color: palette.mathMuted,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
