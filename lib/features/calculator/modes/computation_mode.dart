/// COMP and CMPLX computation surface with natural input, exact results,
/// cursor editing, memory, fractions and history reuse.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../calc_history.dart';
import '../calc_session.dart';
import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/input_editing.dart';
import '../engine/math_value.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../ui/calc_keypad.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import '../ui/natural_math.dart';

class ComputationMode extends StatefulWidget {
  const ComputationMode({
    super.key,
    required this.session,
    required this.complex,
    required this.onChanged,
    required this.onHistory,
  });

  final CalcSession session;
  final bool complex;
  final VoidCallback onChanged;
  final VoidCallback onHistory;

  @override
  State<ComputationMode> createState() => ComputationModeState();
}

class ComputationModeState extends State<ComputationMode> {
  String _expression = '';
  int _cursor = 0;
  ValueFormat? _preview;
  EvalValue? _lastValue;
  ValueFormat? _lastFormat;
  CalcError? _error;
  String? _notice;
  bool _justEvaluated = false;
  bool _forceDecimal = false;
  bool _shift = false;
  bool _alpha = false;
  int _historyCursor = -1;
  (String, int)? _draft;
  final FocusNode _focus = FocusNode();

  CalcSession get _session => widget.session;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Loads a history expression or a value from the shell.
  void loadSource(String source) {
    setState(() {
      _expression = source;
      _cursor = source.length;
      _justEvaluated = false;
      _forceDecimal = false;
      _lastValue = null;
      _lastFormat = null;
      _preview = null;
      _error = null;
      _notice = null;
      _historyCursor = -1;
      _draft = null;
      _shift = false;
      _alpha = false;
    });
    _refreshPreview();
  }

  void _refreshPreview() {
    if (_expression.trim().isEmpty) {
      setState(() {
        _preview = null;
        _error = null;
      });
      return;
    }
    try {
      final value = Evaluator(
        _session.contextFor(complex: widget.complex),
      ).evaluate(parseExpression(_expression));
      setState(() {
        _preview = _session.format(value, complex: widget.complex);
        _error = null;
      });
    } on CalcError {
      // Incomplete input is normal while typing; the error is only surfaced
      // when the user asks for a result.
      setState(() {
        _preview = null;
      });
    } on FormatException {
      setState(() {
        _preview = null;
      });
    }
  }

  void _insert(String token) {
    setState(() {
      _shift = false;
      _alpha = false;
      _error = null;
      _notice = null;
      _historyCursor = -1;
      _draft = null;
      if (_justEvaluated) {
        final continues = const <String>[
          '+',
          '−',
          '×',
          '÷',
          '^',
          '%',
          '!',
          '²',
          '³',
          ')',
        ].any(token.startsWith);
        _expression = continues ? _resultSource() : '';
        _cursor = _expression.length;
        _justEvaluated = false;
        _lastValue = null;
        _lastFormat = null;
      }
      final before = _expression.substring(0, _cursor);
      final after = _expression.substring(_cursor);
      _expression = '$before$token$after';
      _cursor = (before + token).length;
      _preview = null;
    });
    _refreshPreview();
  }

  String _resultSource() {
    final value = _lastValue;
    return value == null ? '' : _sourceFor(value);
  }

  String _sourceFor(EvalValue value) {
    if (value.isComplex) {
      return '(${formatComplex(value.realPart, value.imaginaryPart)})';
    }
    if (value.exact != null) {
      if (value.exact!.isInteger) return value.exact!.numerator.toString();
      return '(${value.exact!.numerator}/${value.exact!.denominator})';
    }
    final text = formatReal(value.realPart, significant: 15);
    return text.replaceAll('−', '-');
  }

  void _backspace() {
    if (_justEvaluated) {
      setState(() {
        _expression = '';
        _cursor = 0;
        _justEvaluated = false;
        _lastValue = null;
        _lastFormat = null;
        _preview = null;
        _error = null;
        _notice = null;
        _shift = false;
        _alpha = false;
      });
      return;
    }
    if (_cursor <= 0 || _expression.isEmpty) return;
    final before = _expression.substring(0, _cursor);
    const compound = <String>[
      '×10^(',
      'integral(',
      'product(',
      'sqrt(',
      'cbrt(',
      'root(',
      'asin(',
      'acos(',
      'atan(',
      'sin(',
      'cos(',
      'tan(',
      'log(',
      'ln(',
      'abs(',
      'exp(',
      'conj(',
      're(',
      'im(',
      'sum(',
      'diff(',
      'Ans',
      '^(-1)',
      '√(',
      '∛(',
      '10^(',
      'e^(',
    ];
    var remove = 1;
    for (final token in compound) {
      if (before.endsWith(token)) {
        remove = token.length;
        break;
      }
    }
    if (_cursor >= 2) {
      final unit = _expression.codeUnitAt(_cursor - 1);
      if (unit >= 0xDC00 && unit <= 0xDFFF) remove = math.max(remove, 2);
    }
    setState(() {
      _expression = _expression.substring(0, _cursor - remove) +
          _expression.substring(_cursor);
      _cursor -= remove;
      _justEvaluated = false;
      _preview = null;
      _error = null;
      _notice = null;
      _shift = false;
      _alpha = false;
      _historyCursor = -1;
    });
    _refreshPreview();
  }

  void _clear() {
    setState(() {
      _expression = '';
      _cursor = 0;
      _preview = null;
      _lastValue = null;
      _lastFormat = null;
      _error = null;
      _notice = null;
      _justEvaluated = false;
      _forceDecimal = false;
      _shift = false;
      _alpha = false;
      _historyCursor = -1;
      _draft = null;
    });
  }

  void _equals() {
    final source = _expression.trim();
    if (source.isEmpty) {
      setState(() {
        _error = const CalcError(CalcErrorKind.empty);
        _notice = null;
      });
      return;
    }
    try {
      final value = Evaluator(
        _session.contextFor(complex: widget.complex),
      ).evaluate(parseExpression(source));
      final format = _session.format(value, complex: widget.complex);
      _session.answer = value;
      _session.record(
        CalcHistoryEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}-${widget.complex ? 'CMPLX' : 'COMP'}',
          expression: source,
          result: format.display,
          exactResult: format.exact,
          mode: widget.complex ? 'CMPLX' : 'COMP',
          angleUnit: _session.settings.angleUnit.label,
          timestamp: DateTime.now(),
        ),
      );
      setState(() {
        _lastValue = value;
        _lastFormat = format;
        _justEvaluated = true;
        _forceDecimal = false;
        _error = null;
        _notice = null;
        _shift = false;
        _alpha = false;
        _historyCursor = -1;
      });
      widget.onChanged();
    } on CalcError catch (error) {
      setState(() {
        _error = error;
        _notice = null;
        _justEvaluated = false;
      });
    } on FormatException catch (error) {
      setState(() {
        _error = CalcError(
          CalcErrorKind.syntax,
          detail: error.message,
        );
        _notice = null;
        _justEvaluated = false;
      });
    }
  }

  void _toggleSd() {
    final value = _justEvaluated ? _lastValue : _previewValue();
    if (value == null) {
      setState(() {
        _notice =
            'احسب تعبير الأول، وبعدها S⇔D بيبدّل بين الصورة الدقيقة والعشرية.';
      });
      return;
    }
    final before = _justEvaluated ? _lastFormat : _preview;
    final exact = before?.exact;
    if (before == null || exact == null) {
      setState(() {
        _notice = 'القيمة دي تقريبية، مفيش صيغة دقيقة بديلة.';
      });
      return;
    }
    // Compare the shown form instead of flipping a flag: with FIX or the
    // decimal preference the shown form can be decimal even before the first
    // press, and a flag flip would then be a silent no-op.
    final showingExact = before.display == exact;
    setState(() {
      _forceDecimal = showingExact;
      final format = _session.format(
        value,
        complex: widget.complex,
        forceDecimal: showingExact,
        forceExact: !showingExact,
      );
      if (_justEvaluated) {
        _lastFormat = format;
      } else {
        _preview = format;
      }
      _notice = null;
    });
  }

  EvalValue? _previewValue() {
    if (_expression.trim().isEmpty) return null;
    try {
      return Evaluator(
        _session.contextFor(complex: widget.complex),
      ).evaluate(parseExpression(_expression));
    } on Object {
      return null;
    }
  }

  EvalValue? _currentValue() {
    if (_justEvaluated) return _lastValue;
    return _previewValue();
  }

  void _toggleSign() {
    final result = _lastValue;
    if (_justEvaluated && result != null) {
      // After `=`, ± negates the result itself (including exact fractions and
      // complex values) and starts a fresh expression from that value.
      final negated = result.negate();
      final source = _sourceFor(negated);
      setState(() {
        _expression = source;
        _cursor = source.length;
        _justEvaluated = false;
        _lastValue = null;
        _lastFormat = null;
        _preview = _session.format(negated, complex: widget.complex);
        _error = null;
        _notice = null;
        _shift = false;
        _alpha = false;
      });
      return;
    }
    final edited = toggleSignAt(_expression, _cursor);
    setState(() {
      _expression = edited.source;
      _cursor = edited.cursor;
      _justEvaluated = false;
      _preview = null;
      _error = null;
      _notice = null;
      _shift = false;
      _alpha = false;
    });
    _refreshPreview();
  }

  void _memoryPlus() {
    final value = _currentValue();
    if (value == null) {
      setState(() {
        _notice = 'مفيش قيمة صالحة تضيفها للذاكرة.';
      });
      return;
    }
    _session.memory = _session.memory + value;
    setState(() {
      _notice = 'M+ اتضافت — الذاكرة = ${_session.memoryDisplay}';
    });
    widget.onChanged();
  }

  void _showMemory() {
    final value = _currentValue();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CalcSheet(
        theme: _calcTheme,
        title: 'الذاكرة',
        subtitle: 'M = ${_session.memoryDisplay}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in <(String, VoidCallback)>[
              (
                'M+  إضافة القيمة الحالية',
                () {
                  if (value == null) return;
                  _session.memory = _session.memory + value;
                  Navigator.pop(context);
                  setState(() {
                    _notice = 'M+ — الذاكرة = ${_session.memoryDisplay}';
                  });
                  widget.onChanged();
                },
              ),
              (
                'M−  طرح القيمة الحالية',
                () {
                  if (value == null) return;
                  _session.memory = _session.memory - value;
                  Navigator.pop(context);
                  setState(() {
                    _notice = 'M− — الذاكرة = ${_session.memoryDisplay}';
                  });
                  widget.onChanged();
                },
              ),
              (
                'M  تخزين القيمة الحالية',
                () {
                  if (value == null) return;
                  _session.memory = value;
                  Navigator.pop(context);
                  setState(() {
                    _notice = 'M اتخزنت — ${_session.memoryDisplay}';
                  });
                  widget.onChanged();
                },
              ),
            ]) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CalcSoftButton(
                  label: action.$1,
                  expanded: true,
                  onPressed: value == null ? null : action.$2,
                ),
              ),
            ],
            CalcSoftButton(
              label: 'مسح الذاكرة (MC)',
              icon: Icons.delete_outline_rounded,
              expanded: true,
              color: CalcPalette.of(context).danger,
              onPressed: () {
                _session.memory = EvalValue.integer(0);
                Navigator.pop(context);
                setState(() {
                  _notice = 'الذاكرة اتمسحت.';
                });
                widget.onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStore() async {
    final value = _currentValue();
    if (value == null) {
      setState(() {
        _notice = 'اكتب تعبير صالح قبل STO.';
      });
      return;
    }
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CalcSheet(
        theme: _calcTheme,
        title: 'STO — تخزين',
        subtitle: '${_session.format(value, complex: widget.complex).display}',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in <String>[
              ...CalcSession.variableNames,
              'M',
            ])
              SizedBox(
                width: 72,
                child: CalcSoftButton(
                  label: name,
                  expanded: true,
                  onPressed: () => Navigator.pop(context, name),
                ),
              ),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    setState(() {
      if (target == 'M') {
        _session.memory = value;
        _notice = 'M = ${_session.memoryDisplay}';
      } else {
        _session.variables[target] = value;
        _notice =
            '$target = ${_session.format(value, complex: widget.complex).display}';
      }
    });
    widget.onChanged();
  }

  Future<void> _showRecall() async {
    final names = <String>[...CalcSession.variableNames, 'M', 'Ans'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CalcSheet(
        theme: _calcTheme,
        title: 'RCL — استرجاع',
        subtitle: 'اختار القيمة اللي عايز تحطها في التعبير.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final name in names)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _ValueRow(
                  name: name,
                  value: switch (name) {
                    'M' => _session.memory,
                    'Ans' => _session.answer,
                    _ => _session.variables[name] ?? EvalValue.integer(0),
                  },
                  complex: widget.complex,
                  onTap: () => Navigator.pop(context, name),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final value = switch (selected) {
      'M' => _session.memory,
      'Ans' => _session.answer,
      _ => _session.variables[selected] ?? EvalValue.integer(0),
    };
    _insert(_sourceForValue(value, selected));
  }

  String _sourceForValue(EvalValue value, String name) {
    if (name == 'Ans') return 'Ans';
    if (name == 'M') {
      return value.exact?.isInteger == true
          ? value.exact!.numerator.toString()
          : (value.exact != null
              ? '(${value.exact!.numerator}/${value.exact!.denominator})'
              : formatReal(value.realPart).replaceAll('−', '-'));
    }
    if (value.exact?.isInteger == true || value.exact != null || value.isReal) {
      // Variables are dynamic: recalling the name keeps the stored value live.
      return name;
    }
    return '(${formatComplex(value.realPart, value.imaginaryPart)})';
  }

  void _historyUp() {
    final entries = _session.history
        .where((entry) => entry.mode == (widget.complex ? 'CMPLX' : 'COMP'))
        .toList(growable: false);
    if (entries.isEmpty) {
      setState(() {
        _notice = 'مفيش تاريخ لسه في الوضع ده.';
      });
      return;
    }
    if (_historyCursor == -1) {
      _draft = (_expression, _cursor);
      _historyCursor = 0;
    } else {
      _historyCursor = math.min(_historyCursor + 1, entries.length - 1);
    }
    final entry = entries[_historyCursor];
    setState(() {
      _expression = entry.expression;
      _cursor = entry.expression.length;
      _justEvaluated = false;
      _preview = null;
      _error = null;
      _notice = null;
    });
    _refreshPreview();
  }

  void _historyDown() {
    if (_historyCursor == -1) return;
    final entries = _session.history
        .where((entry) => entry.mode == (widget.complex ? 'CMPLX' : 'COMP'))
        .toList(growable: false);
    if (entries.isEmpty) {
      _historyCursor = -1;
      _draft = null;
      return;
    }
    if (_historyCursor > 0) {
      if (_historyCursor >= entries.length) _historyCursor = entries.length;
      _historyCursor--;
      final entry = entries[_historyCursor];
      setState(() {
        _expression = entry.expression;
        _cursor = entry.expression.length;
        _preview = null;
        _error = null;
        _notice = null;
      });
      _refreshPreview();
      return;
    }
    _historyCursor = -1;
    final draft = _draft;
    _draft = null;
    setState(() {
      _expression = draft?.$1 ?? '';
      _cursor = draft?.$2 ?? 0;
      _preview = null;
      _error = null;
      _notice = null;
    });
    _refreshPreview();
  }

  /// Dialog routes sit above the calculator's [Theme], so they must be given
  /// the palette and theme captured from this screen explicitly.
  CalcPalette get _calcPalette => CalcPalette.of(context);

  ThemeData get _calcTheme => Theme.of(context);

  Future<void> _showFraction() async {
    final whole = TextEditingController();
    final numerator = TextEditingController();
    final denominator = TextEditingController(text: '1');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final palette = _calcPalette;
        return Theme(
          data: _calcTheme,
          child: AlertDialog(
            backgroundColor: palette.panelStrong,
            title: Text(
              'إدخال كسر',
              style: CalcTypography.title(palette),
              textDirection: TextDirection.rtl,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CalcLabeledField(
                  label: 'العدد الصحيح (اختياري)',
                  controller: whole,
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                CalcLabeledField(
                  label: 'البسط',
                  controller: numerator,
                  hint: '1',
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                CalcLabeledField(
                  label: 'المقام',
                  controller: denominator,
                  hint: '2',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final w = int.tryParse(whole.text.trim()) ?? 0;
                  final n = int.tryParse(numerator.text.trim());
                  final d = int.tryParse(denominator.text.trim());
                  if (n == null || d == null || d == 0) {
                    return;
                  }
                  final total = w.abs() * d.abs() + n.abs();
                  if (total == 0) {
                    Navigator.pop(context, '0');
                    return;
                  }
                  final negative = w != 0 ? w < 0 : (n < 0) != (d < 0);
                  Navigator.pop(
                    context,
                    negative ? '(-($total/${d.abs()}))' : '($total/${d.abs()})',
                  );
                },
                child: const Text('إدراج'),
              ),
            ],
          ),
        );
      },
    );
    whole.dispose();
    numerator.dispose();
    denominator.dispose();
    if (result != null && mounted) _insert(result);
  }

  Future<void> _showComplexPolar() async {
    final radius = TextEditingController();
    final angle = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final palette = _calcPalette;
        return Theme(
          data: _calcTheme,
          child: AlertDialog(
            backgroundColor: palette.panelStrong,
            title: Text(
              'إدخال قطبي r∠θ',
              style: CalcTypography.title(palette),
              textDirection: TextDirection.rtl,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'θ بوحدة ${_session.settings.angleUnit.label} الحالية.',
                  style: CalcTypography.label(palette, size: 11).copyWith(
                    color: palette.mathMuted,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 10),
                CalcLabeledField(
                  label: 'المقدار r',
                  controller: radius,
                  hint: '5',
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                CalcLabeledField(
                  label: 'الزاوية θ',
                  controller: angle,
                  hint: '30',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final r = double.tryParse(radius.text.trim());
                  final t = double.tryParse(angle.text.trim());
                  if (r == null || t == null) return;
                  Navigator.pop(
                    context,
                    '($r×cos($t)+$r×sin($t)×i)',
                  );
                },
                child: const Text('إدراج'),
              ),
            ],
          ),
        );
      },
    );
    radius.dispose();
    angle.dispose();
    if (result != null && mounted) _insert(result);
  }

  void _showFunctions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Theme(
        data: _calcTheme,
        child: _FunctionSheet(
          onInsert: (token) {
            Navigator.pop(context);
            _insert(token);
          },
          onSeries: () {
            Navigator.pop(context);
            _showSeries(product: false);
          },
          onProduct: () {
            Navigator.pop(context);
            _showSeries(product: true);
          },
          onIntegral: () {
            Navigator.pop(context);
            _showAdvanced(
              title: 'التكامل العددي المحدد',
              fields: const <String>[
                'التعبير',
                'المتغير',
                'الحد الأدنى',
                'الحد الأعلى'
              ],
              defaults: const <String>['', 'x', '0', '1'],
              build: (values) =>
                  'integral((${values[0]}), ${values[1]}, ${values[2]}, ${values[3]})',
            );
          },
          onDerivative: () {
            Navigator.pop(context);
            _showAdvanced(
              title: 'المشتقة العددية',
              fields: const <String>['التعبير', 'المتغير', 'النقطة'],
              defaults: const <String>['', 'x', '1'],
              build: (values) =>
                  'diff((${values[0]}), ${values[1]}, ${values[2]})',
            );
          },
        ),
      ),
    );
  }

  Future<void> _showSeries({required bool product}) async {
    await _showAdvanced(
      title: product ? 'حاصل الضرب Π' : 'المجموع Σ',
      fields: const <String>['التعبير', 'المتغير', 'من', 'إلى'],
      defaults: const <String>['', 'n', '1', '10'],
      build: (values) =>
          '${product ? 'product' : 'sum'}((${values[0]}), ${values[1]}, ${values[2]}, ${values[3]})',
    );
  }

  Future<void> _showAdvanced({
    required String title,
    required List<String> fields,
    required List<String> defaults,
    required String Function(List<String>) build,
  }) async {
    final controllers = <TextEditingController>[
      for (var i = 0; i < fields.length; i++)
        TextEditingController(text: defaults[i]),
    ];
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final palette = _calcPalette;
        return Theme(
          data: _calcTheme,
          child: AlertDialog(
            backgroundColor: palette.panelStrong,
            title: Text(
              title,
              style: CalcTypography.title(palette),
              textDirection: TextDirection.rtl,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(height: 9),
                    CalcLabeledField(
                      label: fields[i],
                      controller: controllers[i],
                      autofocus: i == 0,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final values = [for (final c in controllers) c.text.trim()];
                  if (values.isEmpty || values.first.isEmpty) return;
                  if (values.length > 1 &&
                      (values[1].length != 1 ||
                          !RegExp(r'^[A-Za-zθ]$').hasMatch(values[1]))) {
                    return;
                  }
                  Navigator.pop(context, build(values));
                },
                child: const Text('إدراج'),
              ),
            ],
          ),
        );
      },
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (result != null && mounted) _insert(result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final format = _justEvaluated ? _lastFormat : _preview;
    final resultText = format?.display ?? '0';
    final exact = format?.isExact ?? false;
    final display = CalcPanel(
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
      radius: 20,
      color: palette.display,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 24,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  CalcPill(
                    label: widget.complex ? 'CMPLX' : 'COMP',
                    compact: true,
                    active: true,
                    color: widget.complex ? palette.alpha : palette.accent,
                  ),
                  const SizedBox(width: 5),
                  CalcPill(
                    label: _session.settings.angleUnit.label,
                    compact: true,
                    color: palette.label,
                  ),
                  const SizedBox(width: 5),
                  CalcPill(
                    label: _session.settings.naturalInput ? 'MATH' : 'LINE',
                    compact: true,
                    color: palette.label,
                  ),
                  if (_session.memoryActive) ...[
                    const SizedBox(width: 5),
                    CalcPill(
                      label: 'M',
                      compact: true,
                      color: palette.shift,
                      active: true,
                      onTap: _showMemory,
                    ),
                  ],
                  if (exact) ...[
                    const SizedBox(width: 5),
                    CalcPill(
                      label: 'EXACT',
                      compact: true,
                      color: palette.accent,
                    ),
                  ],
                  if (widget.complex) ...[
                    const SizedBox(width: 5),
                    CalcPill(
                      label: 'i',
                      compact: true,
                      color: palette.alpha,
                      onTap: () => _insert('i'),
                    ),
                    const SizedBox(width: 5),
                    CalcPill(
                      label: 'r∠θ',
                      compact: true,
                      color: palette.alpha,
                      onTap: _showComplexPolar,
                    ),
                    const SizedBox(width: 5),
                    CalcPill(
                      label: _session.settings.polarComplex ? 'POLAR' : 'RECT',
                      compact: true,
                      color: palette.accent,
                      onTap: () {
                        _session.settings = _session.settings.copyWith(
                          polarComplex: !_session.settings.polarComplex,
                        );
                        if (_lastValue != null) {
                          _lastFormat = _session.format(
                            _lastValue!,
                            complex: true,
                            forceDecimal: _forceDecimal,
                          );
                        }
                        setState(() {});
                        widget.onChanged();
                      },
                    ),
                  ],
                  const SizedBox(width: 5),
                  CalcPill(
                    label: 'سجل',
                    icon: Icons.history_rounded,
                    compact: true,
                    color: palette.accent,
                    onTap: widget.onHistory,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: NaturalMathView(
                  source: _expression,
                  cursor: _justEvaluated ? null : _cursor,
                  raw: !_session.settings.naturalInput,
                  fontSize: 25,
                  maxLines: 2,
                  alignEnd: true,
                  color: palette.math,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_justEvaluated)
                  Text(
                    '=',
                    style: TextStyle(
                      fontSize: 18,
                      color: palette.math,
                    ),
                  ),
                if (_justEvaluated) const SizedBox(width: 7),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _error?.label ?? resultText,
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                      style: CalcTypography.math(
                        palette,
                        size: 25,
                        color: _error != null
                            ? palette.danger
                            : (exact && !_forceDecimal
                                ? palette.accent
                                : palette.math),
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_justEvaluated && format != null && format.canToggle) ...[
                  const SizedBox(width: 6),
                  Text(
                    _forceDecimal ? 'EXACT' : 'DEC',
                    style: CalcTypography.label(palette, size: 9).copyWith(
                      color: palette.mathMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${_error!.hint}${_error!.detail == null ? '' : ' ${_error!.detail}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: CalcTypography.label(palette, size: 9.5).copyWith(
                  color: palette.danger,
                  height: 1.25,
                ),
              ),
            )
          else if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _notice!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: CalcTypography.label(palette, size: 9.5).copyWith(
                  color: palette.accent,
                ),
              ),
            ),
        ],
      ),
    );
    final keyboard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalcModifierBar(
          shift: _shift,
          alpha: _alpha,
          haptics: _session.settings.haptics,
          onShift: () {
            setState(() {
              _shift = !_shift;
              if (_shift) _alpha = false;
            });
          },
          onAlpha: () {
            setState(() {
              _alpha = !_alpha;
              if (_alpha) _shift = false;
            });
          },
          onLeft: () {
            if (_cursor <= 0) return;
            setState(() {
              _cursor--;
              _shift = false;
              _alpha = false;
            });
          },
          onRight: () {
            if (_cursor >= _expression.length) return;
            setState(() {
              _cursor++;
              _shift = false;
              _alpha = false;
            });
          },
          onUp: _historyUp,
          onDown: _historyDown,
          onSign: _toggleSign,
          onSd: _toggleSd,
          onSto: _showStore,
          onRcl: _showRecall,
          onMemoryPlus: _memoryPlus,
          onFunctions: _showFunctions,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: CalcKeypad(
            shift: _shift,
            alpha: _alpha,
            haptics: _session.settings.haptics,
            onInsert: _insert,
            onBackspace: _backspace,
            onClear: _clear,
            onEquals: _equals,
            onFraction: _showFraction,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // In landscape the screen is wider than it is tall, so the display
        // and the keypad sit side by side instead of squeezing seven key rows
        // into a short column.
        final landscape = constraints.maxWidth > constraints.maxHeight &&
            constraints.maxHeight < 560;
        if (landscape) {
          return Row(
            children: [
              Expanded(flex: 42, child: display),
              const SizedBox(width: 8),
              Expanded(flex: 58, child: keyboard),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 32, child: display),
            const SizedBox(height: 6),
            Expanded(flex: 68, child: keyboard),
          ],
        );
      },
    );
  }
}

class _CalcSheet extends StatelessWidget {
  const _CalcSheet({
    required this.title,
    required this.child,
    required this.theme,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme.brightness == Brightness.dark
        ? CalcPalette.dark
        : CalcPalette.light;
    return Theme(
      data: theme,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration:
                calcPanelDecoration(palette, color: palette.panelStrong),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: CalcTypography.title(palette),
                  textDirection: TextDirection.rtl,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: CalcTypography.label(palette, size: 11).copyWith(
                      color: palette.mathMuted,
                      height: 1.4,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.name,
    required this.value,
    required this.complex,
    required this.onTap,
  });

  final String name;
  final EvalValue value;
  final bool complex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final format = formatCalcValue(value, polar: complex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
          color: palette.isDark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.white.withValues(alpha: 0.55),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                name,
                style: CalcTypography.title(palette, size: 13),
                textDirection: TextDirection.ltr,
              ),
            ),
            Expanded(
              child: Text(
                format.display,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CalcTypography.math(palette, size: 15),
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunctionSheet extends StatelessWidget {
  const _FunctionSheet({
    required this.onInsert,
    required this.onSeries,
    required this.onProduct,
    required this.onIntegral,
    required this.onDerivative,
  });

  final ValueChanged<String> onInsert;
  final VoidCallback onSeries;
  final VoidCallback onProduct;
  final VoidCallback onIntegral;
  final VoidCallback onDerivative;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final groups = <(String, List<(String, String)>)>[
      (
        'مثلثات',
        const <(String, String)>[
          ('sin', 'sin('),
          ('cos', 'cos('),
          ('tan', 'tan('),
          ('sin⁻¹', 'asin('),
          ('cos⁻¹', 'acos('),
          ('tan⁻¹', 'atan('),
          ('sinh', 'sinh('),
          ('cosh', 'cosh('),
          ('tanh', 'tanh('),
        ],
      ),
      (
        'لوغاريتمات وجذور',
        const <(String, String)>[
          ('log', 'log('),
          ('ln', 'ln('),
          ('√', '√('),
          ('∛', '∛('),
          ('ⁿ√', 'root('),
          ('|x|', 'abs('),
          ('eˣ', 'e^('),
          ('10ˣ', '10^('),
          (',', ','),
        ],
      ),
      (
        'أعداد وتوافيق',
        const <(String, String)>[
          ('nCr', 'ncr('),
          ('nPr', 'npr('),
          ('gcd', 'gcd('),
          ('lcm', 'lcm('),
          ('min', 'min('),
          ('max', 'max('),
          ('rand', 'rand('),
        ],
      ),
      (
        'ثوابت',
        const <(String, String)>[
          ('π', 'π'),
          ('e', 'e'),
          ('i', 'i'),
          ('Ans', 'Ans'),
        ],
      ),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          padding: const EdgeInsets.all(16),
          decoration: calcPanelDecoration(palette, color: palette.panelStrong),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'الدوال والقوالب',
                  style: CalcTypography.title(palette),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 3),
                Text(
                  'كل دالة بتتدرج في موضع المؤشر. القوالب بتفتح حقول عشان تمنع أخطاء الفواصل.',
                  style: CalcTypography.label(palette, size: 10.5).copyWith(
                    color: palette.mathMuted,
                    height: 1.4,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 14),
                for (final group in groups) ...[
                  Text(
                    group.$1,
                    style: CalcTypography.label(palette, size: 11),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final item in group.$2)
                        CalcPill(
                          label: item.$1,
                          compact: true,
                          onTap: () => onInsert(item.$2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  'تحليل وجمع',
                  style: CalcTypography.label(palette, size: 11),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    CalcPill(
                      label: 'Σ مجموع',
                      compact: true,
                      color: palette.shift,
                      onTap: onSeries,
                    ),
                    CalcPill(
                      label: 'Π حاصل ضرب',
                      compact: true,
                      color: palette.shift,
                      onTap: onProduct,
                    ),
                    CalcPill(
                      label: '∫ تكامل عددي',
                      compact: true,
                      color: palette.accent,
                      onTap: onIntegral,
                    ),
                    CalcPill(
                      label: 'd/dx مشتقة عددية',
                      compact: true,
                      color: palette.accent,
                      onTap: onDerivative,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
