/// The full scientific calculator («الآلة الحاسبة العلمية»).
///
/// The screen recreates the classic FX layout on top of the app's teal design
/// system: a mint LCD with a two-line display, DEG/RAD, SHIFT and ALPHA
/// modifiers, a four-way pad, memory keys, and a green circular `=`.
/// Everything is evaluated offline by [CalcEngine]; history and settings are
/// persisted with `shared_preferences`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'calc_dialogs.dart';
import 'calc_engine.dart';

typedef _HistoryEntry = ({String expression, String result});

/// The scientific calculator screen.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const _historyKey = 'calc_history_v1';
  static const _radiansKey = 'calc_radians';
  static const _fixKey = 'calc_fix';
  static const _fractionKey = 'calc_fraction';
  static const _memoryKey = 'calc_memory';

  String _expression = '';
  int _cursor = 0;
  String _preview = '';
  String _result = '0';
  String _lastExpression = '';
  String? _error;
  bool _shift = false;
  bool _alpha = false;
  bool _radians = false;
  bool _justEvaluated = false;
  int? _fix;
  bool _fraction = false;
  double _answer = 0;
  double _memory = 0;
  int _historyCursor = -1;
  final List<_HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_historyKey);
      if (!mounted) return;
      setState(() {
        _radians = prefs.getBool(_radiansKey) ?? false;
        _fix = prefs.getInt(_fixKey);
        _fraction = prefs.getBool(_fractionKey) ?? false;
        _memory = prefs.getDouble(_memoryKey) ?? 0;
        if (saved != null) {
          for (final raw in saved.take(50)) {
            final split = raw.indexOf('\u0001');
            if (split <= 0) continue;
            _history.add((
              expression: raw.substring(0, split),
              result: raw.substring(split + 1),
            ));
          }
        }
      });
    } catch (_) {
      // Storage is optional: the calculator still works without it.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _historyKey,
        [
          for (final entry in _history.take(50))
            '${entry.expression}\u0001${entry.result}',
        ],
      );
      await prefs.setBool(_radiansKey, _radians);
      await prefs.setBool(_fractionKey, _fraction);
      await prefs.setDouble(_memoryKey, _memory);
      if (_fix == null) {
        await prefs.remove(_fixKey);
      } else {
        await prefs.setInt(_fixKey, _fix!);
      }
    } catch (_) {
      // Ignore storage errors on platforms without shared preferences.
    }
  }

  CalcEngine get _engine => CalcEngine(
    radians: _radians,
    answer: _answer,
    variables: const <String, double>{},
  );

  String _format(double value) =>
      formatCalc(value, fix: _fix, asFraction: _fraction);

  void _refreshPreview() {
    if (_expression.trim().isEmpty) {
      _preview = '';
      return;
    }
    try {
      _preview = _format(_engine.evaluate(_expression));
    } on CalcException {
      _preview = '';
    }
  }

  /// Inserts [token] at the cursor, clearing the modifier flags.
  void _insert(String token) {
    HapticFeedback.selectionClick();
    setState(() {
      _shift = false;
      _alpha = false;
      _error = null;
      _historyCursor = -1;
      if (_justEvaluated) {
        final continues = const ['+', '−', '×', '÷', '^', '%', '!'].any(
          (op) => token.startsWith(op),
        );
        _expression = continues ? _result : '';
        _justEvaluated = false;
        _cursor = _expression.length;
      }
      final before = _expression.substring(0, _cursor);
      final after = _expression.substring(_cursor);
      _expression = '$before$token$after';
      _cursor = (before + token).length;
      _refreshPreview();
    });
  }

  void _allClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _expression = '';
      _cursor = 0;
      _preview = '';
      _result = '0';
      _lastExpression = '';
      _error = null;
      _justEvaluated = false;
      _shift = false;
      _alpha = false;
      _historyCursor = -1;
    });
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _shift = false;
      _alpha = false;
      if (_justEvaluated) {
        _expression = '';
        _cursor = 0;
        _justEvaluated = false;
        _preview = '';
        return;
      }
      if (_cursor == 0) return;
      _expression =
          _expression.substring(0, _cursor - 1) +
          _expression.substring(_cursor);
      _cursor--;
      _refreshPreview();
    });
  }

  void _moveCursor(int delta) {
    if (_expression.isEmpty) return;
    setState(() {
      _cursor = (_cursor + delta).clamp(0, _expression.length);
    });
  }

  void _browseHistory(int delta) {
    if (_history.isEmpty) return;
    setState(() {
      _shift = false;
      _alpha = false;
      _justEvaluated = false;
      _error = null;
      final next = (_historyCursor + delta).clamp(-1, _history.length - 1);
      _historyCursor = next;
      if (next < 0) {
        _expression = '';
        _cursor = 0;
      } else {
        _expression = _history[next].expression;
        _cursor = _expression.length;
      }
      _refreshPreview();
    });
  }

  void _equals() {
    final source = _expression.trim();
    if (source.isEmpty) return;
    try {
      final value = _engine.evaluate(source);
      final formatted = _format(value);
      HapticFeedback.mediumImpact();
      setState(() {
        _answer = value;
        _result = formatted;
        _lastExpression = source;
        _history.insert(0, (expression: source, result: formatted));
        if (_history.length > 50) _history.removeLast();
        _historyCursor = -1;
        _expression = '';
        _cursor = 0;
        _preview = '';
        _justEvaluated = true;
        _error = null;
        _shift = false;
        _alpha = false;
      });
      _persist();
    } on CalcException catch (e) {
      HapticFeedback.vibrate();
      setState(() {
        _error = e.message;
        _preview = '';
      });
    }
  }

  /// Evaluates the current expression (or the last answer) for memory keys.
  double? _currentValue() {
    if (_expression.trim().isNotEmpty) {
      try {
        return _engine.evaluate(_expression);
      } on CalcException {
        return null;
      }
    }
    return _answer;
  }

  void _memoryAdd(int sign) {
    final value = _currentValue();
    if (value == null) return;
    setState(() {
      _memory += sign * value;
      _shift = false;
      _alpha = false;
    });
    _persist();
  }

  void _insertAdvanced(String text) {
    final first = text.split('\n').first.trim();
    final candidate = first.contains('=')
        ? first.substring(first.lastIndexOf('=') + 1).trim()
        : first;
    // Only plain numbers can safely become part of the expression. Matrix,
    // statistics and complex results keep letters or several rows, so those
    // are copied instead.
    final plain = RegExp(
      r'^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$',
    );
    if (!text.contains('\n') && plain.hasMatch(candidate)) {
      _insert(candidate);
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: TrText('النتيجة اتنسخت — الصقها في أي مكان.')),
    );
  }

  Future<void> _insertFraction() async {
    final numerator = TextEditingController();
    final denominator = TextEditingController(text: '2');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('كسر  a b/c'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: numerator,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: 'البسط'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: ZakerSpacing.sm),
              child: Text('/'),
            ),
            Expanded(
              child: TextField(
                controller: denominator,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: 'المقام'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final n = numerator.text.trim();
              final d = denominator.text.trim();
              if (n.isEmpty || d.isEmpty || double.tryParse(d) == 0) return;
              Navigator.of(context).pop('($n)/($d)');
            },
            child: const TrText('إدراج'),
          ),
        ],
      ),
    );
    numerator.dispose();
    denominator.dispose();
    if (value != null) _insert(value);
  }

  Future<void> _openAdvanced(Future<String?> Function() open) async {
    final result = await open();
    if (result == null || !mounted) return;
    _insertAdvanced(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const TrText('الآلة الحاسبة العلمية'),
        actions: [
          IconButton(
            tooltip: 'السجل',
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyHeight = ((constraints.maxHeight - 390) / 7).clamp(
                  38.0,
                  54.0,
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                  children: [
                    _Lcd(
                      expression: _expression.isEmpty
                          ? (_justEvaluated ? _lastExpression : '')
                          : _expression,
                      cursor: _expression.isEmpty ? -1 : _cursor,
                      result: _error ??
                          (_expression.trim().isEmpty
                              ? _result
                              : (_preview.isEmpty ? ' ' : _preview)),
                      isPreview: _expression.trim().isNotEmpty &&
                          _error == null,
                      radians: _radians,
                      shift: _shift,
                      alpha: _alpha,
                      memory: _memory,
                      fix: _fix,
                      fraction: _fraction,
                      onAngleTap: () =>
                          setState(() => _radians = !_radians),
                    ),
                    const SizedBox(height: 10),
                    _ModeStrip(
                      radians: _radians,
                      fraction: _fraction,
                      fix: _fix,
                      onRadians: (value) {
                        setState(() => _radians = value);
                        _persist();
                      },
                      onFraction: (value) {
                        setState(() => _fraction = value);
                        _persist();
                        if (_expression.trim().isNotEmpty) {
                          setState(_refreshPreview);
                        }
                      },
                      onFix: (value) {
                        setState(() => _fix = value);
                        _persist();
                        if (_expression.trim().isNotEmpty) {
                          setState(_refreshPreview);
                        }
                      },
                      onSettings: _openSettings,
                    ),
                    const SizedBox(height: 8),
                    _ToolStrip(
                      memory: _memory,
                      onIntegral: () => _openAdvanced(
                        () => showIntegralDialog(
                          context,
                          radians: _radians,
                          variables: const <String, double>{},
                          answer: _answer,
                        ),
                      ),
                      onDerivative: () => _openAdvanced(
                        () => showDerivativeDialog(
                          context,
                          radians: _radians,
                          variables: const <String, double>{},
                          answer: _answer,
                        ),
                      ),
                      onSolve: () => _openAdvanced(
                        () => showSolveDialog(
                          context,
                          radians: _radians,
                          variables: const <String, double>{},
                          answer: _answer,
                        ),
                      ),
                      onMatrix: () => _openAdvanced(
                        () => showMatrixDialog(context),
                      ),
                      onStat: () => _openAdvanced(
                        () => showStatDialog(context),
                      ),
                      onComplex: () => _openAdvanced(
                        () => showComplexDialog(context),
                      ),
                      onMemoryAdd: () => _memoryAdd(1),
                      onMemorySubtract: () => _memoryAdd(-1),
                      onMemoryRecall: () => _insert(formatCalc(_memory)),
                      onMemoryClear: () {
                        setState(() => _memory = 0);
                        _persist();
                      },
                    ),
                    const SizedBox(height: 10),
                    _ControlStrip(
                      shift: _shift,
                      alpha: _alpha,
                      onShift: () => setState(() {
                        _shift = !_shift;
                        if (_shift) _alpha = false;
                      }),
                      onAlpha: () => setState(() {
                        _alpha = !_alpha;
                        if (_alpha) _shift = false;
                      }),
                      onUp: () => _browseHistory(1),
                      onDown: () => _browseHistory(-1),
                      onLeft: () => _moveCursor(-1),
                      onRight: () => _moveCursor(1),
                      onCenter: () => setState(() {
                        _fraction = !_fraction;
                        _refreshPreview();
                      }),
                      onMode: _openSettings,
                    ),
                    const SizedBox(height: 8),
                    _Keypad(
                      keyHeight: keyHeight,
                      shift: _shift,
                      alpha: _alpha,
                      onKey: _insert,
                      onBackspace: _backspace,
                      onClear: _allClear,
                      onEquals: _equals,
                      onFraction: _insertFraction,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _openHistory,
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const TrText('سجل العمليات'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- history

  Future<void> _openHistory() async {
    final selected = await showModalBottomSheet<_HistoryEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZakerSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TrText(
                          'سجل العمليات',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_history.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(_history.clear);
                            _persist();
                            Navigator.of(sheetContext).pop();
                          },
                          child: const TrText('مسح الكل'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(
                          child: TrText(
                            'لسه مفيش عمليات — ابدأ احسب وهتلاقيها هنا.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = _history[index];
                            return ListTile(
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(entry),
                              title: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  entry.expression,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              subtitle: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '= ${entry.result}',
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'انسخ الناتج',
                                icon: const Icon(Icons.copy_rounded, size: 19),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: entry.result),
                                  );
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: TrText(
                                            'النتيجة اتنسخت ✅',
                                          ),
                                        ),
                                      );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _expression = selected.expression;
      _cursor = _expression.length;
      _justEvaluated = false;
      _error = null;
      _refreshPreview();
    });
  }

  // --------------------------------------------------------------- settings

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final theme = Theme.of(context);
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  0,
                  ZakerSpacing.lg,
                  ZakerSpacing.lg +
                      MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'إعدادات الحاسبة',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: ZakerSpacing.lg),
                    const _SettingsLabel('وحدة الزاوية'),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('DEG'),
                          selected: !_radians,
                          onSelected: (_) {
                            setState(() => _radians = false);
                            setSheet(() {});
                            _persist();
                            if (_expression.isNotEmpty) {
                              setState(_refreshPreview);
                            }
                          },
                        ),
                        const SizedBox(width: ZakerSpacing.sm),
                        ChoiceChip(
                          label: const Text('RAD'),
                          selected: _radians,
                          onSelected: (_) {
                            setState(() => _radians = true);
                            setSheet(() {});
                            _persist();
                            if (_expression.isNotEmpty) {
                              setState(_refreshPreview);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.lg),
                    const _SettingsLabel('طريقة العرض'),
                    Wrap(
                      spacing: ZakerSpacing.sm,
                      runSpacing: ZakerSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: const TrText('NORM'),
                          selected: _fix == null,
                          onSelected: (_) {
                            setState(() => _fix = null);
                            setSheet(() {});
                            _persist();
                          },
                        ),
                        for (final digits in [0, 1, 2, 3, 4, 6])
                          ChoiceChip(
                            label: Text('FIX $digits'),
                            selected: _fix == digits,
                            onSelected: (_) {
                              setState(() => _fix = digits);
                              setSheet(() {});
                              _persist();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.sm),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const TrText('اعرض الناتج ككسر'),
                      subtitle: const TrText(
                        'زي 3/4 بدل 0.75 لما يكون الكسر بسيط.',
                      ),
                      value: _fraction,
                      onChanged: (value) {
                        setState(() => _fraction = value);
                        setSheet(() {});
                        _persist();
                        if (_expression.isNotEmpty) {
                          setState(_refreshPreview);
                        }
                      },
                    ),
                    const Divider(height: ZakerSpacing.xl),
                    const _SettingsLabel('الذاكرة'),
                    Row(
                      children: [
                        Expanded(
                          child: TrText(
                            'M = ${formatCalc(_memory)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _memory = 0);
                            setSheet(() {});
                            _persist();
                          },
                          child: const TrText('تصفير'),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.sm),
                    const Divider(height: ZakerSpacing.xl),
                    const _SettingsLabel('السجل'),
                    Row(
                      children: [
                        Expanded(
                          child: TrText(
                            '${_history.length} عملية محفوظة',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(_history.clear);
                            setSheet(() {});
                            _persist();
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const TrText('مسح السجل'),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const TrText('تمام'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --------------------------------------------------------------------- LCD

/// The mint LCD with the expression above and the large result below.
class _Lcd extends StatelessWidget {
  const _Lcd({
    required this.expression,
    required this.cursor,
    required this.result,
    required this.isPreview,
    required this.radians,
    required this.shift,
    required this.alpha,
    required this.memory,
    required this.fix,
    required this.fraction,
    required this.onAngleTap,
  });

  final String expression;
  final int cursor;
  final String result;
  final bool isPreview;
  final bool radians;
  final bool shift;
  final bool alpha;
  final double memory;
  final int? fix;
  final bool fraction;
  final VoidCallback onAngleTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF12433B);
    const faded = Color(0xFF4B7A70);
    final display = cursor >= 0 && cursor <= expression.length
        ? '${expression.substring(0, cursor)}▏${expression.substring(cursor)}'
        : expression;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4F6E9), Color(0xFFC5E7D3)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF9CCDB4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x99FFFFFF),
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Indicator(
                text: radians ? 'RAD' : 'DEG',
                active: true,
                color: ink,
                onTap: onAngleTap,
              ),
              const SizedBox(width: 6),
              if (shift) const _Indicator(text: 'SHIFT', active: true),
              if (alpha) const _Indicator(text: 'ALPHA', active: true),
              if (memory != 0) const _Indicator(text: 'M', active: true),
              if (fix != null) _Indicator(text: 'FIX ${fix!}', active: true),
              if (fraction) const _Indicator(text: 'a b/c', active: true),
              const Spacer(),
              const TrText(
                'رفيق الطالب',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: faded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                display.isEmpty ? ' ' : display,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 17,
                  height: 1.4,
                  color: faded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 54,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    result.trim().isEmpty ? '0' : result,
                    maxLines: 2,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: isPreview ? 34 : 40,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      color: isPreview ? faded : ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny LCD status tag.
class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.text,
    required this.active,
    this.color,
    this.onTap,
  });

  final String text;
  final bool active;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = color ?? const Color(0xFF12433B);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: base.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: base,
        ),
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: chip,
    );
  }
}

// --------------------------------------------------------------- mode strip

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({
    required this.radians,
    required this.fraction,
    required this.fix,
    required this.onRadians,
    required this.onFraction,
    required this.onFix,
    required this.onSettings,
  });

  final bool radians;
  final bool fraction;
  final int? fix;
  final ValueChanged<bool> onRadians;
  final ValueChanged<bool> onFraction;
  final ValueChanged<int?> onFix;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: selected,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => onTap(),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('DEG', !radians, () => onRadians(false)),
                chip('RAD', radians, () => onRadians(true)),
                chip(
                  'كسر',
                  fraction,
                  () => onFraction(!fraction),
                ),
                chip(
                  fix == null ? 'NORM' : 'FIX ${fix!}',
                  fix != null,
                  () => onFix(fix == null ? 2 : null),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'إعدادات',
          visualDensity: VisualDensity.compact,
          onPressed: onSettings,
          icon: Icon(
            Icons.tune_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- tool strip

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({
    required this.memory,
    required this.onIntegral,
    required this.onDerivative,
    required this.onSolve,
    required this.onMatrix,
    required this.onStat,
    required this.onComplex,
    required this.onMemoryAdd,
    required this.onMemorySubtract,
    required this.onMemoryRecall,
    required this.onMemoryClear,
  });

  final double memory;
  final VoidCallback onIntegral;
  final VoidCallback onDerivative;
  final VoidCallback onSolve;
  final VoidCallback onMatrix;
  final VoidCallback onStat;
  final VoidCallback onComplex;
  final VoidCallback onMemoryAdd;
  final VoidCallback onMemorySubtract;
  final VoidCallback onMemoryRecall;
  final VoidCallback onMemoryClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = <(String, IconData, VoidCallback)>[
      ('∫ dx', Icons.calculate_rounded, onIntegral),
      ('d/dx', Icons.functions_rounded, onDerivative),
      ('SOLVE', Icons.search_rounded, onSolve),
      ('MATRIX', Icons.grid_on_rounded, onMatrix),
      ('STAT', Icons.bar_chart_rounded, onStat),
      ('CMPLX', Icons.change_circle_outlined, onComplex),
      ('M+', Icons.add_circle_outline_rounded, onMemoryAdd),
      ('M−', Icons.remove_circle_outline_rounded, onMemorySubtract),
      (
        memory == 0 ? 'MR' : 'MR ${formatCalc(memory)}',
        Icons.memory_rounded,
        onMemoryRecall,
      ),
      ('MC', Icons.backspace_outlined, onMemoryClear),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final (label, icon, onTap) = tools[index];
          return ActionChip(
            avatar: Icon(icon, size: 15, color: theme.colorScheme.primary),
            label: Text(
              label,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: onTap,
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------ control strip

class _ControlStrip extends StatelessWidget {
  const _ControlStrip({
    required this.shift,
    required this.alpha,
    required this.onShift,
    required this.onAlpha,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onCenter,
    required this.onMode,
  });

  final bool shift;
  final bool alpha;
  final VoidCallback onShift;
  final VoidCallback onAlpha;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onCenter;
  final VoidCallback onMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          Expanded(
            child: _ModifierKey(
              label: 'SHIFT',
              color: const Color(0xFFF59E0B),
              active: shift,
              onTap: onShift,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModifierKey(
              label: 'ALPHA',
              color: const Color(0xFF7C3AED),
              active: alpha,
              onTap: onAlpha,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModifierKey(
              label: 'MODE',
              color: theme.colorScheme.primary,
              active: false,
              onTap: onMode,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 74,
            child: _DPad(
              background: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: theme.dividerTheme.color ?? Colors.black12,
              onUp: onUp,
              onDown: onDown,
              onLeft: onLeft,
              onRight: onRight,
              onCenter: onCenter,
            ),
          ),
        ],
      ),
    );
  }
}

/// A SHIFT/ALPHA/MODE key with a tinted background.
class _ModifierKey extends StatelessWidget {
  const _ModifierKey({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: active
                ? color
                : color.withValues(alpha: isDark ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: ZakerTheme.fontUi,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: active ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The compact four-way pad.
class _DPad extends StatelessWidget {
  const _DPad({
    required this.background,
    required this.border,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onCenter,
  });

  final Color background;
  final Color border;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    Widget arrow(IconData icon, VoidCallback tap, Alignment alignment) {
      return Align(
        alignment: alignment,
        child: InkResponse(
          onTap: tap,
          radius: 13,
          child: SizedBox(
            width: 24,
            height: 22,
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          arrow(Icons.keyboard_arrow_up_rounded, onUp, Alignment.topCenter),
          arrow(
            Icons.keyboard_arrow_down_rounded,
            onDown,
            Alignment.bottomCenter,
          ),
          arrow(Icons.keyboard_arrow_left_rounded, onLeft, Alignment.centerLeft),
          arrow(
            Icons.keyboard_arrow_right_rounded,
            onRight,
            Alignment.centerRight,
          ),
          Center(
            child: InkResponse(
              onTap: onCenter,
              radius: 14,
              child: Icon(
                Icons.circle_outlined,
                size: 11,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- keypad

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.keyHeight,
    required this.shift,
    required this.alpha,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
    required this.onFraction,
  });

  final double keyHeight;
  final bool shift;
  final bool alpha;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;
  final VoidCallback onFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // (label, shift label, alpha label, insert, kind)
    final rows = <List<_KeySpec>>[
      [
        _KeySpec('x²', 'x³', null, '²', shiftInsert: '³'),
        _KeySpec('xⁿ', null, null, '^'),
        _KeySpec('√', '∛', null, '√', shiftInsert: '∛('),
        _KeySpec('∛', null, null, '∛('),
        _KeySpec('x⁻¹', null, null, '^(-1)'),
      ],
      [
        _KeySpec('(', null, null, '('),
        _KeySpec(')', null, null, ')'),
        _KeySpec('log', '10ˣ', null, 'log(', shiftInsert: '10^('),
        _KeySpec('ln', 'eˣ', null, 'ln(', shiftInsert: 'e^('),
        _KeySpec('a b/c', null, null, '', action: _KeyAction.fraction),
      ],
      [
        _KeySpec('sin', 'sin⁻¹', 'A', 'sin(', shiftInsert: 'asin(', alphaInsert: 'A'),
        _KeySpec('cos', 'cos⁻¹', 'B', 'cos(', shiftInsert: 'acos(', alphaInsert: 'B'),
        _KeySpec('tan', 'tan⁻¹', 'C', 'tan(', shiftInsert: 'atan(', alphaInsert: 'C'),
        _KeySpec('π', 'e', 'D', 'π', shiftInsert: 'e', alphaInsert: 'D'),
        _KeySpec('e', 'Ans', 'E', 'e', shiftInsert: 'Ans', alphaInsert: 'E'),
      ],
      [
        _KeySpec('7', null, 'F', '7', alphaInsert: 'F'),
        _KeySpec('8', null, 'X', '8', alphaInsert: 'X'),
        _KeySpec('9', null, 'Y', '9', alphaInsert: 'Y'),
        _KeySpec(
          'DEL',
          null,
          null,
          '',
          action: _KeyAction.backspace,
          kind: _KeyKind.orange,
        ),
        _KeySpec(
          'AC',
          null,
          null,
          '',
          action: _KeyAction.clear,
          kind: _KeyKind.orange,
        ),
      ],
      [
        _KeySpec('4', null, null, '4'),
        _KeySpec('5', null, null, '5'),
        _KeySpec('6', null, null, '6'),
        _KeySpec('×', null, null, '×', kind: _KeyKind.operator),
        _KeySpec('÷', null, null, '÷', kind: _KeyKind.operator),
      ],
      [
        _KeySpec('1', null, null, '1'),
        _KeySpec('2', null, null, '2'),
        _KeySpec('3', null, null, '3'),
        _KeySpec('+', null, null, '+', kind: _KeyKind.operator),
        _KeySpec('−', null, null, '−', kind: _KeyKind.operator),
      ],
      [
        _KeySpec('0', null, null, '0'),
        _KeySpec('.', null, null, '.'),
        _KeySpec('Ans', null, null, 'Ans'),
        _KeySpec('%', '!', null, '%', shiftInsert: '!'),
        _KeySpec(
          '=',
          null,
          null,
          '',
          action: _KeyAction.equals,
          kind: _KeyKind.equals,
        ),
      ],
    ];

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          SizedBox(
            height: keyHeight,
            child: Row(
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  Expanded(
                    child: _KeyButton(
                      spec: rows[r][c],
                      shift: shift,
                      alpha: alpha,
                      primary: primary,
                      onTap: () => _dispatch(rows[r][c]),
                    ),
                  ),
                  if (c != rows[r].length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          if (r != rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  void _dispatch(_KeySpec spec) {
    switch (spec.action) {
      case _KeyAction.backspace:
        onBackspace();
      case _KeyAction.clear:
        onClear();
      case _KeyAction.equals:
        onEquals();
      case _KeyAction.fraction:
        onFraction();
      case null:
        final usesAlpha = alpha && spec.alphaInsert != null;
        final usesShift = shift && spec.shiftInsert != null;
        final text = usesAlpha
            ? spec.alphaInsert!
            : usesShift
            ? spec.shiftInsert!
            : spec.insert;
        if (text.isNotEmpty) onKey(text);
    }
  }
}

enum _KeyAction { backspace, clear, equals, fraction }

enum _KeyKind { digit, operator, orange, equals }

class _KeySpec {
  const _KeySpec(
    this.label,
    this.shiftLabel,
    this.alphaLabel,
    this.insert, {
    this.shiftInsert,
    this.alphaInsert,
    this.action,
    this.kind = _KeyKind.digit,
  });

  final String label;
  final String? shiftLabel;
  final String? alphaLabel;
  final String insert;
  final String? shiftInsert;
  final String? alphaInsert;
  final _KeyAction? action;
  final _KeyKind kind;
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.spec,
    required this.shift,
    required this.alpha,
    required this.primary,
    required this.onTap,
  });

  final _KeySpec spec;
  final bool shift;
  final bool alpha;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (background, foreground, border) = switch (spec.kind) {
      _KeyKind.operator => (
        primary.withValues(alpha: isDark ? 0.24 : 0.10),
        primary,
        primary.withValues(alpha: 0.28),
      ),
      _KeyKind.orange => (
        const Color(0xFFF97316).withValues(alpha: isDark ? 0.24 : 0.10),
        const Color(0xFFEA580C),
        const Color(0xFFF97316).withValues(alpha: 0.30),
      ),
      _KeyKind.equals => (Colors.transparent, Colors.white, Colors.transparent),
      _KeyKind.digit => (
        isDark ? const Color(0xFF1E293B) : Colors.white,
        theme.colorScheme.onSurface,
        theme.dividerTheme.color ?? Colors.black12,
      ),
    };

    final isEquals = spec.kind == _KeyKind.equals;
    final usesShift = shift && spec.shiftLabel != null;
    final usesAlpha = alpha && spec.alphaLabel != null;
    final label = usesAlpha
        ? spec.alphaLabel!
        : usesShift
        ? spec.shiftLabel!
        : spec.label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(isEquals ? 999 : 12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: isEquals ? null : background,
            gradient: isEquals
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                  )
                : null,
            borderRadius: BorderRadius.circular(isEquals ? 999 : 12),
            border: Border.all(color: border),
            boxShadow: isEquals
                ? const [
                    BoxShadow(
                      color: Color(0x4415803D),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : isDark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: ZakerTheme.fontUi,
                    fontSize: isEquals ? 24 : 17,
                    fontWeight: isEquals ? FontWeight.w900 : FontWeight.w700,
                    color: usesAlpha
                        ? const Color(0xFF7C3AED)
                        : usesShift
                        ? const Color(0xFFD97706)
                        : foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small bold section heading inside the settings sheet.
class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: TrText(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
