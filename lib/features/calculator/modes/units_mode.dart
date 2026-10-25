/// Unit converter with linear factors and temperature offsets.
library;

import 'package:flutter/material.dart';

import '../calc_session.dart';
import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../engine/units.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

class UnitsMode extends StatefulWidget {
  const UnitsMode({super.key, required this.session});

  final CalcSession session;

  @override
  State<UnitsMode> createState() => _UnitsModeState();
}

class _UnitsModeState extends State<UnitsMode> {
  final TextEditingController _value = TextEditingController(text: '1');
  String _categoryId = 'length';
  String _fromId = 'meter';
  String _toId = 'kilometer';
  String? _error;
  String? _result;
  double? _resultValue;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  UnitCategory get _category =>
      unitCategory(_categoryId) ?? unitCategories.first;

  UnitDefinition get _from => _category.unit(_fromId) ?? _category.units.first;

  UnitDefinition get _to =>
      _category.unit(_toId) ?? _category.units[1 % _category.units.length];

  void _switchCategory(String categoryId) {
    final category = unitCategory(categoryId);
    if (category == null) return;
    setState(() {
      _categoryId = categoryId;
      _fromId = category.units.first.id;
      _toId = category.units.length > 1
          ? category.units[1].id
          : category.units.first.id;
      _error = null;
      _result = null;
      _resultValue = null;
    });
  }

  double _parseValue() {
    final text = _value.text.trim();
    if (text.isEmpty) {
      throw const CalcError(
        CalcErrorKind.argument,
        detail: 'اكتب القيمة المطلوب تحويلها.',
      );
    }
    try {
      final value = Evaluator(
        EvalContext(angleUnit: widget.session.settings.angleUnit),
      ).evaluate(parseExpression(text));
      if (!value.isReal) {
        throw const CalcError(
          CalcErrorKind.argument,
          detail: 'المحوّل بيقبل أعدادًا حقيقية فقط.',
        );
      }
      return value.realPart;
    } on CalcError catch (error) {
      throw CalcError(
        error.kind,
        detail: error.detail ?? error.hint,
      );
    }
  }

  void _convert() {
    try {
      final value = _parseValue();
      final converted = convertUnit(value, _from, _to);
      setState(() {
        _result = formatUnitResult(converted, _to);
        _resultValue = converted;
        _error = null;
      });
      FocusScope.of(context).unfocus();
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _result = null;
        _resultValue = null;
      });
    }
  }

  void _swap() {
    setState(() {
      final old = _fromId;
      _fromId = _toId;
      _toId = old;
      _error = null;
      _result = null;
      _resultValue = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final category = _category;
    final from = _from;
    final to = _to;
    return CalcModePage(
      title: 'محوّل الوحدات',
      subtitle:
          'تحويل دقيق بين وحدات الطول والمساحة والحجم والكتلة والحرارة وغيرها.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'الفئة',
                  style: CalcTypography.label(palette, size: 10),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 31,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      for (final item in unitCategories) ...[
                        CalcPill(
                          label: item.nameAr,
                          compact: true,
                          active: item.id == _categoryId,
                          onTap: () => _switchCategory(item.id),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                CalcLabeledField(
                  label: 'القيمة',
                  controller: _value,
                  hint: '1',
                  onSubmitted: (_) => _convert(),
                  suffix: IconButton(
                    tooltip: 'تحويل',
                    icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                    onPressed: _convert,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _UnitPicker(
                        label: 'من',
                        units: category.units,
                        selectedId: from.id,
                        onChanged: (id) {
                          setState(() {
                            _fromId = id;
                            _error = null;
                            _result = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 38,
                      height: 40,
                      child: IconButton(
                        tooltip: 'تبديل الوحدتين',
                        onPressed: _swap,
                        style: IconButton.styleFrom(
                          backgroundColor: palette.accentSoft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: palette.accent.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        icon: Icon(
                          Icons.swap_horiz_rounded,
                          color: palette.accent,
                          size: 21,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _UnitPicker(
                        label: 'إلى',
                        units: category.units,
                        selectedId: to.id,
                        onChanged: (id) {
                          setState(() {
                            _toId = id;
                            _error = null;
                            _result = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                CalcSoftButton(
                  label: 'تحويل',
                  icon: Icons.transform_rounded,
                  expanded: true,
                  color: palette.accent,
                  onPressed: _convert,
                ),
                const SizedBox(height: 8),
                CalcNote(
                  text:
                      'الوحدات الخطية تستخدم معاملًا واحدًا. درجات الحرارة تستخدم إزاحة إضافية، '
                      'فـ 0°C = 32°F و0°C = 273.15 K من غير تقريب.',
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
                  const CalcSectionTitle(
                    title: 'النتيجة',
                    subtitle: 'القيمة بعد التحويل مع رمز الوحدة.',
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
                        size: 22,
                        color: palette.accent,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '${_value.text.trim()} ${from.symbol} = ${_result!}',
                    style: CalcTypography.label(palette, size: 11).copyWith(
                      color: palette.mathMuted,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  if (_resultValue != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'بالوحدة الأساسية (${category.baseSymbol}): '
                      '${formatReal(to.toBase(_resultValue!))}',
                      style: CalcTypography.label(palette, size: 10).copyWith(
                        color: palette.mathMuted,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ],
              ),
            ),
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CalcSectionTitle(
                  title: 'علاقة التحويل',
                  subtitle: 'مشتقة من معاملات الوحدة الأساسية.',
                ),
                const SizedBox(height: 8),
                Text(
                  '1 ${from.symbol} = ${formatReal(convertUnit(1, from, to))} ${to.symbol}',
                  style: CalcTypography.math(
                    palette,
                    size: 15,
                    color: palette.math,
                  ),
                  textDirection: TextDirection.ltr,
                ),
                if (from.offset != 0 || to.offset != 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    'تحتوي على إزاحة (offset) — التحويل مش مجرد ضرب في معامل.',
                    style: CalcTypography.label(palette, size: 9.5).copyWith(
                      color: palette.shift,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitPicker extends StatelessWidget {
  const _UnitPicker({
    required this.label,
    required this.units,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final List<UnitDefinition> units;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CalcTypography.label(palette, size: 10),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 4),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: palette.isDark
                ? Colors.black.withValues(alpha: 0.23)
                : Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: DropdownButton<String>(
            value: units.any((unit) => unit.id == selectedId)
                ? selectedId
                : units.first.id,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: palette.panelStrong,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: palette.mathMuted,
            ),
            style: CalcTypography.label(palette, size: 11).copyWith(
              fontWeight: FontWeight.w600,
            ),
            items: [
              for (final unit in units)
                DropdownMenuItem<String>(
                  value: unit.id,
                  child: Text(
                    '${unit.nameAr} · ${unit.symbol}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: CalcTypography.label(palette, size: 11).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
