/// TABLE mode: evaluate one expression over an arithmetic x-range.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calc_session.dart';
import '../engine/calculator_error.dart';
import '../engine/number_format.dart';
import '../engine/table.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

class TableMode extends StatefulWidget {
  const TableMode({super.key, required this.session});

  final CalcSession session;

  @override
  State<TableMode> createState() => _TableModeState();
}

class _TableModeState extends State<TableMode> {
  final TextEditingController _expression = TextEditingController(text: 'x²');
  final TextEditingController _start = TextEditingController(text: '-3');
  final TextEditingController _end = TextEditingController(text: '3');
  final TextEditingController _step = TextEditingController(text: '1');
  TableResult? _table;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _expression.dispose();
    _start.dispose();
    _end.dispose();
    _step.dispose();
    super.dispose();
  }

  void _generate() {
    final start = double.tryParse(_start.text.trim().replaceAll('−', '-'));
    final end = double.tryParse(_end.text.trim().replaceAll('−', '-'));
    final step = double.tryParse(_step.text.trim().replaceAll('−', '-'));
    if (start == null || end == null || step == null) {
      setState(() {
        _error = 'Start وEnd وStep لازم يكونوا أعداد صالحة.';
        _table = null;
      });
      return;
    }
    try {
      final table = buildTable(
        _expression.text.trim(),
        start: start,
        end: end,
        step: step,
        angleUnit: widget.session.settings.angleUnit,
      );
      setState(() {
        _table = table;
        _error = null;
        _notice = table.truncated
            ? 'الجدول اتوقف عند 100 صف. قلّل النطاق أو كبّر الخطوة.'
            : null;
      });
    } on CalcError catch (error) {
      setState(() {
        _error = '${error.label}: ${error.detail ?? error.hint}';
        _table = null;
        _notice = null;
      });
    }
  }

  Future<void> _copyCsv() async {
    final table = _table;
    if (table == null) return;
    final buffer = StringBuffer('x,f(x)\n');
    for (final row in table.rows) {
      buffer.writeln('${row.x},${row.formatted}'.replaceAll('−', '-'));
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    setState(() {
      _notice = 'الجدول اتنسخ بصيغة CSV.';
    });
  }

  void _clear() {
    setState(() {
      _expression.clear();
      _start.text = '-3';
      _end.text = '3';
      _step.text = '1';
      _table = null;
      _error = null;
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return CalcModePage(
      title: 'TABLE — جدول القيم',
      subtitle:
          'قيم f(x) على نطاق محدد. الزاوية الحالية: ${widget.session.settings.angleUnit.label}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalcLabeledField(
                  label: 'f(x) =',
                  controller: _expression,
                  hint: 'x² + 2x',
                  onSubmitted: (_) => _generate(),
                ),
                const SizedBox(height: 9),
                CalcFieldRow(
                  children: [
                    CalcLabeledField(
                      label: 'Start',
                      controller: _start,
                      hint: '-3',
                      onSubmitted: (_) => _generate(),
                    ),
                    CalcLabeledField(
                      label: 'End',
                      controller: _end,
                      hint: '3',
                      onSubmitted: (_) => _generate(),
                    ),
                    CalcLabeledField(
                      label: 'Step',
                      controller: _step,
                      hint: '1',
                      onSubmitted: (_) => _generate(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CalcSoftButton(
                        label: 'توليد الجدول',
                        expanded: true,
                        color: palette.accent,
                        onPressed: _generate,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: CalcSoftButton(
                        label: 'CSV',
                        expanded: true,
                        onPressed: _table == null ? null : _copyCsv,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: CalcSoftButton(
                        label: 'مسح',
                        expanded: true,
                        onPressed: _clear,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const CalcNote(
                  text:
                      'الجدول بيستخدم نفس محرك الحساب، فالدوال المثلثية بتتبع وحدة الزاوية المختارة. '
                      'الخطوة لازم تكون باتجاه النطاق (سالب للنزول).',
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
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CalcResultBanner(
                note: _notice,
                child: Text(
                  _table?.truncated == true ? 'الجدول مقطوع' : 'جاهز',
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          if (_table != null)
            CalcModeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalcSectionTitle(
                    title: 'القيم',
                    subtitle:
                        '${_table!.rows.length} صف · خطوة ${formatGraphLabel(_table!.step)}',
                    trailing: const CalcPill(
                      label: 'TABLE',
                      compact: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: palette.divider),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'x',
                                  style: CalcTypography.label(
                                    palette,
                                    size: 11,
                                  ).copyWith(color: palette.accent),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'f(x)',
                                  textAlign: TextAlign.right,
                                  style: CalcTypography.label(
                                    palette,
                                    size: 11,
                                  ).copyWith(color: palette.accent),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                for (final row in _table!.rows)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: palette.divider,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            formatGraphLabel(row.x),
                                            style: CalcTypography.math(
                                              palette,
                                              size: 12,
                                              color: palette.mathMuted,
                                            ),
                                            textDirection: TextDirection.ltr,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            row.formatted,
                                            textAlign: TextAlign.right,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: CalcTypography.math(
                                              palette,
                                              size: 13,
                                              color: row.value == null
                                                  ? palette.danger
                                                  : palette.math,
                                            ),
                                            textDirection: TextDirection.ltr,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
