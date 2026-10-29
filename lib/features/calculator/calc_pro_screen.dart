/// Premium scientific calculator shell.
///
/// The shell owns persistence and cross-mode state. Each visible mode is a real
/// implementation; modes are created lazily so the graphing and CAS surfaces
/// never run while another mode is being used. Settings, history, memory and
/// the last answer survive app restarts. Existing `/calculator` entry points
/// keep working because the route still points here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/appearance_screen.dart';
import 'calc_history.dart';
import 'calc_session.dart';
import 'calc_settings.dart';
import 'engine/evaluator.dart';
import 'engine/math_value.dart';
import 'ui/calc_palette.dart';
import 'ui/calc_widgets.dart';
import 'modes/base_n_mode.dart';
import 'modes/cas_mode.dart';
import 'modes/computation_mode.dart';
import 'modes/eqn_mode.dart';
import 'modes/formulas_mode.dart';
import 'modes/graph_mode.dart';
import 'modes/matrix_mode.dart';
import 'modes/mode_scaffold.dart';
import 'modes/stat_mode.dart';
import 'modes/table_mode.dart';
import 'modes/units_mode.dart';
import 'modes/vector_mode.dart';

enum _ModeSection { primary, extra, tool }

class _ModeInfo {
  const _ModeInfo({
    required this.code,
    required this.short,
    required this.nameAr,
    required this.description,
    required this.icon,
    required this.section,
  });

  final String code;
  final String short;
  final String nameAr;
  final String description;
  final IconData icon;
  final _ModeSection section;
}

const List<_ModeInfo> _modeCatalog = <_ModeInfo>[
  _ModeInfo(
    code: 'COMP',
    short: 'COMP',
    nameAr: 'حساب عام',
    description: 'حساب وكسور ونسب ودقة كسرية',
    icon: Icons.calculate_outlined,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'CMPLX',
    short: 'CMPLX',
    nameAr: 'أعداد مركبة',
    description: 'مستطيل وقطبي ومرافق',
    icon: Icons.blur_circular_rounded,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'STAT',
    short: 'STAT',
    nameAr: 'إحصاء',
    description: 'متغير واحد أو اثنان وانحدار',
    icon: Icons.bar_chart_rounded,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'BASE-N',
    short: 'BASE-N',
    nameAr: 'أنظمة العد',
    description: 'عشري وست عشري وثنائي وثماني',
    icon: Icons.data_object_rounded,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'EQN',
    short: 'EQN',
    nameAr: 'معادلات',
    description: 'كثيرات حدود وأنظمة خطية',
    icon: Icons.functions_rounded,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'MATRIX',
    short: 'MATRIX',
    nameAr: 'مصفوفات',
    description: 'حتى 4×4 ومحدد ومعكوس وقيم ذاتية',
    icon: Icons.grid_on_rounded,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'TABLE',
    short: 'TABLE',
    nameAr: 'جدول',
    description: 'قيم دالة على نطاق وCSV',
    icon: Icons.table_chart_outlined,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'VECTOR',
    short: 'VECTOR',
    nameAr: 'متجهات',
    description: '2D و3D وضرب اتجاهي',
    icon: Icons.arrow_outward_rounded,
    section: _ModeSection.primary,
  ),
  _ModeInfo(
    code: 'GRAPH',
    short: 'GRAPH',
    nameAr: 'رسم بياني',
    description: 'دوال وتحليل وتتبع تفاعلي',
    icon: Icons.show_chart_rounded,
    section: _ModeSection.extra,
  ),
  _ModeInfo(
    code: 'CAS',
    short: 'CAS',
    nameAr: 'جبر رمزي',
    description: 'تبسيط واشتقاق وتكامل محدود',
    icon: Icons.auto_awesome_rounded,
    section: _ModeSection.extra,
  ),
  _ModeInfo(
    code: 'FORMULAS',
    short: 'قوانين',
    nameAr: 'مكتبة القوانين',
    description: 'بحث وتقييم فوري',
    icon: Icons.menu_book_outlined,
    section: _ModeSection.tool,
  ),
  _ModeInfo(
    code: 'UNITS',
    short: 'وحدات',
    nameAr: 'محوّل الوحدات',
    description: 'مع إزاحة درجات الحرارة',
    icon: Icons.swap_horiz_rounded,
    section: _ModeSection.tool,
  ),
];

class CalculatorProScreen extends StatefulWidget {
  const CalculatorProScreen({super.key});

  @override
  State<CalculatorProScreen> createState() => _CalculatorProScreenState();
}

class _CalculatorProScreenState extends State<CalculatorProScreen> {
  static const String _settingsKey = 'calc_pro_settings_v1';
  static const String _historyKey = 'calc_pro_history_v1';
  static const String _answerKey = 'calc_pro_answer_v1';
  static const String _memoryKey = 'calc_pro_memory_v1';
  static const String _variablesKey = 'calc_pro_variables_v1';

  static const String _legacyHistoryKey = 'calc_history_v1';
  static const String _legacyRadiansKey = 'calc_radians';
  static const String _legacyFixKey = 'calc_fix';
  static const String _legacyFractionKey = 'calc_fraction';
  static const String _legacyMemoryKey = 'calc_memory';

  CalcSession _session = CalcSession();
  bool _loaded = false;
  int _modeIndex = 0;
  final Set<int> _visitedModes = <int>{0};

  final GlobalKey<ComputationModeState> _compKey =
      GlobalKey<ComputationModeState>();
  final GlobalKey<ComputationModeState> _cmplxKey =
      GlobalKey<ComputationModeState>();
  final GlobalKey<BaseNModeState> _baseNKey = GlobalKey<BaseNModeState>();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    CalcSettings settings = const CalcSettings();
    List<CalcHistoryEntry> history = <CalcHistoryEntry>[];
    EvalValue answer = EvalValue.integer(0);
    EvalValue memory = EvalValue.integer(0);
    Map<String, EvalValue> variables = <String, EvalValue>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawSettings = prefs.getString(_settingsKey);
      if (rawSettings != null && rawSettings.isNotEmpty) {
        settings = CalcSettings.decode(rawSettings);
      } else {
        settings = CalcSettings(
          angleUnit: (prefs.getBool(_legacyRadiansKey) ?? false)
              ? AngleUnit.radians
              : AngleUnit.degrees,
          fix: prefs.getInt(_legacyFixKey)?.clamp(0, 10),
          preferExact: prefs.getBool(_legacyFractionKey) ?? true,
        );
      }
      final rawHistory = prefs.getString(_historyKey);
      if (rawHistory != null && rawHistory.isNotEmpty) {
        history = CalcHistory.decode(rawHistory);
      } else {
        history = CalcHistory.fromLegacy(
          prefs.getStringList(_legacyHistoryKey) ?? const <String>[],
        );
      }
      final rawAnswer = prefs.getString(_answerKey);
      if (rawAnswer != null && rawAnswer.isNotEmpty) {
        answer = CalcSession.decodeValue(rawAnswer);
      }
      final rawMemory = prefs.getString(_memoryKey);
      if (rawMemory != null && rawMemory.isNotEmpty) {
        memory = CalcSession.decodeValue(rawMemory);
      } else {
        final legacyMemory = prefs.getDouble(_legacyMemoryKey);
        if (legacyMemory != null && legacyMemory.isFinite) {
          memory = EvalValue.real(legacyMemory);
        }
      }
      variables = CalcSession.decodeVariables(prefs.getString(_variablesKey));
    } catch (_) {
      // The calculator remains fully usable when storage is unavailable.
    }
    if (!mounted) return;
    setState(() {
      _session = CalcSession(
        settings: settings,
        history: history,
        answer: answer,
        memory: memory,
        variables: variables,
      );
      _loaded = true;
    });
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, _session.settings.encode());
      await prefs.setString(_historyKey, CalcHistory.encode(_session.history));
      await prefs.setString(
        _answerKey,
        CalcSession.encodeValue(_session.answer),
      );
      await prefs.setString(
        _memoryKey,
        CalcSession.encodeValue(_session.memory),
      );
      await prefs.setString(
        _variablesKey,
        CalcSession.encodeVariables(_session.variables),
      );
    } catch (_) {
      // Ignore persistence failures; calculations continue in memory.
    }
  }

  void _onSessionChanged() {
    setState(() {});
    _persist();
  }

  void _activateMode(int index) {
    if (index < 0 || index >= _modeCatalog.length) return;
    setState(() {
      _visitedModes.add(index);
      _modeIndex = index;
    });
  }

  void _activateFromSheet(BuildContext sheetContext, int index) {
    Navigator.of(sheetContext).pop();
    _activateMode(index);
  }

  Future<void> _loadHistoryEntry(CalcHistoryEntry entry) async {
    final angle = AngleUnit.fromName(entry.angleUnit);
    if (_session.settings.angleUnit != angle) {
      _session.settings = _session.settings.copyWith(angleUnit: angle);
      _persist();
    }
    final mode = entry.mode.toUpperCase();
    final complex = mode == 'CMPLX';
    final baseN = mode == 'BASE-N';
    final index = baseN ? 3 : (complex ? 1 : 0);
    setState(() {
      _visitedModes.add(index);
      _modeIndex = index;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (baseN) {
        _baseNKey.currentState?.loadHistory(entry.expression);
        return;
      }
      final key = complex ? _cmplxKey : _compKey;
      key.currentState?.loadSource(entry.expression);
    });
  }

  String _historyTime(DateTime time) {
    if (time.millisecondsSinceEpoch == 0) return 'سجل قديم';
    final now = DateTime.now();
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    final sameDay =
        time.year == now.year && time.month == now.month && time.day == now.day;
    if (sameDay) return 'اليوم $hours:$minutes';
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day  $hours:$minutes';
  }

  ThemeData _calcThemeData(BuildContext context) {
    final dark = _session.settings.finish == CalcFinish.midnight;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final base = Theme.of(context);
    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor:
          dark ? CalcPalette.dark.background : CalcPalette.light.background,
      canvasColor:
          dark ? CalcPalette.dark.panelStrong : CalcPalette.light.panelStrong,
      colorScheme: base.colorScheme.copyWith(brightness: brightness),
    );
  }

  CalcPalette _sheetPalette() => _session.settings.finish == CalcFinish.midnight
      ? CalcPalette.dark
      : CalcPalette.light;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _calcThemeData(context),
      child: Builder(
        builder: (context) {
          final palette = CalcPalette.of(context);
          final dark = palette.isDark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: palette.backgroundAlt,
              systemNavigationBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
            ),
            child: Scaffold(
              backgroundColor: palette.background,
              body: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[palette.background, palette.backgroundAlt],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -150,
                      right: -110,
                      child: IgnorePointer(
                        child: Container(
                          width: 310,
                          height: 310,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                palette.accent.withValues(alpha: 0.12),
                                palette.accent.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(context, palette),
                              const SizedBox(height: 7),
                              _modeRail(palette),
                              const SizedBox(height: 5),
                              Expanded(
                                child: _loaded
                                    ? _modeStack()
                                    : Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: palette.accent,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'بنستعيد السجل والإعدادات…',
                                              style: CalcTypography.label(
                                                palette,
                                                size: 11.5,
                                              ).copyWith(
                                                color: palette.mathMuted,
                                              ),
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, CalcPalette palette) {
    final mode = _modeCatalog[_modeIndex];
    final subtitle = '${mode.code} · ${_session.settings.angleUnit.label} · '
        '${_session.settings.naturalInput ? 'MATH' : 'LINE'} · '
        '${_session.settings.finish == CalcFinish.midnight ? 'MIDNIGHT' : 'PAPER'}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 7, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: calcPanelDecoration(
        palette,
        radius: 18,
        elevated: false,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              tooltip: 'رجوع',
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(
                Icons.arrow_forward_rounded,
                size: 21,
                color: palette.label,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'الحاسبة العلمية',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CalcTypography.title(palette, size: 16),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: palette.accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '991 PLUS',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CalcTypography.label(palette, size: 9).copyWith(
                    color: palette.mathMuted,
                    letterSpacing: 0.35,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          _headerAction(
            palette,
            Icons.grid_view_rounded,
            'كل الأوضاع',
            _openModeMenu,
            showDot: false,
          ),
          _headerAction(
            palette,
            Icons.history_rounded,
            'السجل',
            _openHistory,
            showDot: _session.history.isNotEmpty,
          ),
          _headerAction(
            palette,
            Icons.tune_rounded,
            'الإعدادات',
            _openSettings,
            showDot: false,
          ),
        ],
      ),
    );
  }

  Widget _headerAction(
    CalcPalette palette,
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    required bool showDot,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: palette.label),
              if (showDot)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.accent,
                      border: Border.all(color: palette.panel, width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeRail(CalcPalette palette) {
    Widget divider() => Container(
          width: 1,
          height: 17,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: palette.divider,
        );
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (var i = 0; i < 8; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            _ModeChip(
              info: _modeCatalog[i],
              selected: _modeIndex == i,
              onTap: () => _activateMode(i),
            ),
          ],
          divider(),
          for (var i = 8; i < 10; i++) ...[
            if (i > 8) const SizedBox(width: 5),
            _ModeChip(
              info: _modeCatalog[i],
              selected: _modeIndex == i,
              onTap: () => _activateMode(i),
            ),
          ],
          divider(),
          for (var i = 10; i < 12; i++) ...[
            if (i > 10) const SizedBox(width: 5),
            _ModeChip(
              info: _modeCatalog[i],
              selected: _modeIndex == i,
              onTap: () => _activateMode(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeStack() {
    final children = <Widget>[];
    for (var i = 0; i < _modeCatalog.length; i++) {
      children.add(
        _visitedModes.contains(i) ? _buildMode(i) : const SizedBox.shrink(),
      );
    }
    return IndexedStack(
      index: _modeIndex,
      sizing: StackFit.expand,
      children: children,
    );
  }

  Widget _buildMode(int index) {
    return switch (index) {
      0 => ComputationMode(
          key: _compKey,
          session: _session,
          complex: false,
          onChanged: _onSessionChanged,
          onHistory: _openHistory,
        ),
      1 => ComputationMode(
          key: _cmplxKey,
          session: _session,
          complex: true,
          onChanged: _onSessionChanged,
          onHistory: _openHistory,
        ),
      2 => StatMode(session: _session),
      3 => BaseNMode(
          key: _baseNKey,
          session: _session,
          onChanged: _onSessionChanged,
        ),
      4 => EqnMode(angleUnit: _session.settings.angleUnit),
      5 => MatrixMode(angleUnit: _session.settings.angleUnit),
      6 => TableMode(session: _session),
      7 => VectorMode(angleUnit: _session.settings.angleUnit),
      8 => GraphMode(session: _session),
      9 => CasMode(session: _session),
      10 => FormulasMode(session: _session),
      11 => UnitsMode(session: _session),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _sheetHandle(CalcPalette palette) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 38,
          height: 3,
          decoration: BoxDecoration(
            color: palette.mathMuted.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  Widget _sheetHeader(
    BuildContext context,
    CalcPalette palette,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: CalcTypography.title(palette, size: 17),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: CalcTypography.label(palette, size: 10).copyWith(
                    color: palette.mathMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: palette.label, size: 21),
          ),
        ],
      ),
    );
  }

  Widget _sheetContainer(CalcPalette palette, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: palette.panelStrong,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }

  Future<void> _openModeMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final palette = _sheetPalette();
            Widget sectionLabel(String title, String note) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: CalcTypography.title(palette, size: 13),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: CalcTypography.label(palette, size: 9.5).copyWith(
                        color: palette.mathMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              );
            }

            Widget tile(int index) {
              final info = _modeCatalog[index];
              final selected = index == _modeIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _activateFromSheet(context, index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? palette.accent.withValues(alpha: 0.13)
                            : (palette.isDark
                                ? Colors.white.withValues(alpha: 0.035)
                                : Colors.white.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? palette.accent.withValues(alpha: 0.5)
                              : palette.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: selected
                                  ? palette.accentSoft
                                  : (palette.isDark
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              info.icon,
                              size: 18,
                              color:
                                  selected ? palette.accent : palette.mathMuted,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      info.code,
                                      style: CalcTypography.math(
                                        palette,
                                        size: 11,
                                        color: selected
                                            ? palette.accent
                                            : palette.label,
                                      ).copyWith(fontWeight: FontWeight.w800),
                                      textDirection: TextDirection.ltr,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        info.nameAr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: CalcTypography.label(
                                          palette,
                                          size: 11,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  info.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CalcTypography.label(
                                    palette,
                                    size: 9,
                                  ).copyWith(
                                    color: palette.mathMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: palette.accent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Theme(
              data: _calcThemeData(sheetContext),
              child: FractionallySizedBox(
                heightFactor: 0.9,
                child: _sheetContainer(
                  palette,
                  Column(
                    children: [
                      _sheetHandle(palette),
                      _sheetHeader(
                        context,
                        palette,
                        'أوضاع الحاسبة',
                        'الأوضاع الأساسية بترتيب القائمة، ثم GRAPH وCAS كإضافتين، وأدوات مستقلة.',
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            sectionLabel(
                              'الأوضاع الأساسية',
                              'نفس ترتيب قائمة الأوضاع: COMP ← VECTOR.',
                            ),
                            for (var i = 0; i < 8; i++) tile(i),
                            sectionLabel(
                              'أوضاع إضافية',
                              'قدرات أعلى من الحاسبة الكلاسيكية، منفصلة بوضوح.',
                            ),
                            for (var i = 8; i < 10; i++) tile(i),
                            sectionLabel(
                              'الأدوات',
                              'مراجع وأدوات مساعدة تعمل بنفس المحرك.',
                            ),
                            for (var i = 10; i < 12; i++) tile(i),
                            const CalcNote(
                              text:
                                  'الحاسبة تعمل بالكامل دون إنترنت. النتائج الرمزية والعددية متميزة دائمًا داخل كل وضع.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openHistory() async {
    final search = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final palette = _sheetPalette();
            final query = search.text.trim().toLowerCase();
            final entries = query.isEmpty
                ? _session.history
                : _session.history
                    .where(
                      (entry) =>
                          entry.expression.toLowerCase().contains(query) ||
                          entry.result.toLowerCase().contains(query) ||
                          entry.mode.toLowerCase().contains(query),
                    )
                    .toList(growable: false);

            void removeEntry(CalcHistoryEntry entry) {
              setState(() {
                _session.removeHistory(entry.id);
              });
              setSheetState(() {});
              _persist();
            }

            Future<void> clearAll() async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => Theme(
                  data: _calcThemeData(context),
                  child: AlertDialog(
                    backgroundColor: palette.isDark
                        ? CalcPalette.dark.panelStrong
                        : CalcPalette.light.panelStrong,
                    title: Text(
                      'مسح السجل بالكامل؟',
                      style: CalcTypography.title(palette, size: 17),
                      textDirection: TextDirection.rtl,
                    ),
                    content: Text(
                      'هتتم إزالة كل العمليات المحفوظة. الإعدادات والذاكرة مش هتتأثر.',
                      style: CalcTypography.label(palette, size: 13),
                      textDirection: TextDirection.rtl,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text('إلغاء',
                            style: TextStyle(color: palette.mathMuted)),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('امسح'),
                      ),
                    ],
                  ),
                ),
              );
              if (confirmed != true) return;
              setState(() {
                _session.clearHistory();
              });
              setSheetState(() {});
              _persist();
            }

            return Theme(
              data: _calcThemeData(sheetContext),
              child: FractionallySizedBox(
                heightFactor: 0.9,
                child: _sheetContainer(
                  palette,
                  Column(
                    children: [
                      _sheetHandle(palette),
                      _sheetHeader(
                        context,
                        palette,
                        'سجل العمليات',
                        '${_session.history.length} من ${CalcHistory.maximumEntries} عملية محفوظة محليًا.',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: search,
                                textDirection: TextDirection.rtl,
                                style: CalcTypography.label(palette, size: 12),
                                cursorColor: palette.accent,
                                onChanged: (_) => setSheetState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'ابحث في التعبير أو الناتج…',
                                  hintTextDirection: TextDirection.rtl,
                                  hintStyle: TextStyle(
                                    color: palette.mathMuted,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: palette.isDark
                                      ? Colors.black.withValues(alpha: 0.22)
                                      : Colors.white.withValues(alpha: 0.6),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                  ),
                                  suffixIcon: search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'مسح البحث',
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 17,
                                          ),
                                          onPressed: () {
                                            search.clear();
                                            setSheetState(() {});
                                          },
                                        ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 9,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: palette.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: palette.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: palette.accent,
                                      width: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            IconButton(
                              tooltip: 'مسح الكل',
                              onPressed:
                                  _session.history.isEmpty ? null : clearAll,
                              icon: Icon(
                                Icons.delete_sweep_outlined,
                                size: 20,
                                color: _session.history.isEmpty
                                    ? palette.mathMuted.withValues(alpha: 0.4)
                                    : palette.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: entries.isEmpty
                            ? CalcEmptyState(
                                icon: search.text.trim().isEmpty
                                    ? Icons.history_toggle_off_rounded
                                    : Icons.search_off_rounded,
                                title: search.text.trim().isEmpty
                                    ? 'السجل فاضي'
                                    : 'مفيش نتائج',
                                message: search.text.trim().isEmpty
                                    ? 'أول نتيجة بتحسبها هتتحفظ هنا وتفضل بعد إغلاق التطبيق.'
                                    : 'جرّب كلمة تانية في البحث.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  14,
                                  18,
                                ),
                                physics: const BouncingScrollPhysics(),
                                itemCount: entries.length,
                                itemBuilder: (context, index) {
                                  final entry = entries[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 7),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _loadHistoryEntry(entry);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(
                                            10,
                                            8,
                                            4,
                                            8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.035,
                                                  )
                                                : Colors.white.withValues(
                                                    alpha: 0.5,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: palette.border,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        CalcPill(
                                                          label: entry.mode,
                                                          compact: true,
                                                          color: entry.mode
                                                                      .toUpperCase() ==
                                                                  'CMPLX'
                                                              ? palette.alpha
                                                              : palette.accent,
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            _historyTime(
                                                              entry.timestamp,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                CalcTypography
                                                                    .label(
                                                              palette,
                                                              size: 8.5,
                                                            ).copyWith(
                                                              color: palette
                                                                  .mathMuted,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                            textDirection:
                                                                TextDirection
                                                                    .rtl,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      entry.expression,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          CalcTypography.math(
                                                        palette,
                                                        size: 13,
                                                      ).copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      textDirection:
                                                          TextDirection.ltr,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            '= ${entry.result}',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                CalcTypography
                                                                    .math(
                                                              palette,
                                                              size: 12,
                                                              color: palette
                                                                  .accent,
                                                            ),
                                                            textDirection:
                                                                TextDirection
                                                                    .ltr,
                                                          ),
                                                        ),
                                                        if (entry.exactResult !=
                                                            null)
                                                          Text(
                                                            entry.exactResult!,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                CalcTypography
                                                                    .label(
                                                              palette,
                                                              size: 9,
                                                            ).copyWith(
                                                              color: palette
                                                                  .mathMuted,
                                                            ),
                                                            textDirection:
                                                                TextDirection
                                                                    .ltr,
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                tooltip: 'خيارات',
                                                padding: EdgeInsets.zero,
                                                icon: Icon(
                                                  Icons.more_vert_rounded,
                                                  size: 18,
                                                  color: palette.mathMuted,
                                                ),
                                                onSelected: (action) {
                                                  switch (action) {
                                                    case 'edit':
                                                      Navigator.of(context)
                                                          .pop();
                                                      _loadHistoryEntry(entry);
                                                    case 'copy':
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text: entry.result,
                                                        ),
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'النتيجة اتنسخت.',
                                                          ),
                                                        ),
                                                      );
                                                    case 'delete':
                                                      removeEntry(entry);
                                                  }
                                                },
                                                itemBuilder: (context) =>
                                                    <PopupMenuEntry<String>>[
                                                  const PopupMenuItem<String>(
                                                    value: 'edit',
                                                    child: Text(
                                                      'تحرير / إعادة استخدام',
                                                    ),
                                                  ),
                                                  const PopupMenuItem<String>(
                                                    value: 'copy',
                                                    child: Text('نسخ الناتج'),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: 'delete',
                                                    child: Text(
                                                      'حذف',
                                                      style: TextStyle(
                                                        color: palette.danger,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    search.dispose();
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final palette = _sheetPalette();
            final settings = _session.settings;

            void apply(CalcSettings next) {
              setState(() {
                _session.settings = next;
              });
              setSheetState(() {});
              _persist();
              if (next.haptics) HapticFeedback.selectionClick();
            }

            Widget sectionTitle(String title, String subtitle) {
              return Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 7),
                child: CalcSectionTitle(title: title, subtitle: subtitle),
              );
            }

            Widget toggleRow({
              required String label,
              required String description,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: CalcTypography.label(palette, size: 11.5),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            description,
                            style:
                                CalcTypography.label(palette, size: 9).copyWith(
                              color: palette.mathMuted,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 99,
                      child: CalcSegmented<bool>(
                        values: const <bool>[true, false],
                        selected: value,
                        labelFor: (item) => item ? 'ON' : 'OFF',
                        compact: true,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Theme(
              data: _calcThemeData(sheetContext),
              child: FractionallySizedBox(
                heightFactor: 0.93,
                child: _sheetContainer(
                  palette,
                  Column(
                    children: [
                      _sheetHandle(palette),
                      _sheetHeader(
                        context,
                        palette,
                        'إعدادات الحاسبة',
                        'كل التغييرات بتتحفظ فورًا وتتطبق على الأوضاع كلها.',
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            sectionTitle(
                              'وحدة الزاوية',
                              'تتطبق على sin وcos وtan والدوال العكسية والقطبي.',
                            ),
                            CalcSegmented<AngleUnit>(
                              values: AngleUnit.values,
                              selected: settings.angleUnit,
                              labelFor: (unit) => unit.label,
                              onChanged: (unit) =>
                                  apply(settings.copyWith(angleUnit: unit)),
                            ),
                            const SizedBox(height: 8),
                            CalcNote(
                              text: 'DEG درجات، RAD راديان، GRA جراديان. '
                                  'التحويل داخلي ثابت ولا يعتمد على تقريب الواجهة.',
                            ),
                            sectionTitle(
                              'طريقة الإدخال',
                              'MATH بيعرض الكسور والجذور والأسس بشكل طبيعي، وLINE نصًا خطيًا.',
                            ),
                            CalcSegmented<bool>(
                              values: const <bool>[true, false],
                              selected: settings.naturalInput,
                              labelFor: (value) => value ? 'MATH' : 'LINE',
                              onChanged: (value) =>
                                  apply(settings.copyWith(naturalInput: value)),
                            ),
                            const SizedBox(height: 10),
                            toggleRow(
                              label: 'الاهتزاز',
                              description:
                                  'اهتزاز خفيف عند الضغط على المفاتيح والأوضاع.',
                              value: settings.haptics,
                              onChanged: (value) =>
                                  apply(settings.copyWith(haptics: value)),
                            ),
                            sectionTitle(
                              'عرض النتائج',
                              'الدقة الكسرية منفصلة عن التقريب العشري.',
                            ),
                            toggleRow(
                              label: 'تفضيل القيم الدقيقة',
                              description:
                                  'يعرض 1/3 بدل 0.333… عندما يظل الكسر ممكنًا، مع S⇔D للتبديل.',
                              value: settings.preferExact,
                              onChanged: (value) =>
                                  apply(settings.copyWith(preferExact: value)),
                            ),
                            toggleRow(
                              label: 'كسور مختلطة',
                              description:
                                  'يعرض 7/3 كـ 2 1/3 في النتائج الكسرية.',
                              value: settings.mixedFractions,
                              onChanged: (value) => apply(
                                settings.copyWith(mixedFractions: value),
                              ),
                            ),
                            toggleRow(
                              label: 'المركب القطبي',
                              description:
                                  'نتائج CMPLX تظهر r∠θ بدل a+bi عند الإمكان.',
                              value: settings.polarComplex,
                              onChanged: (value) => apply(
                                settings.copyWith(polarComplex: value),
                              ),
                            ),
                            sectionTitle(
                              'تقريب FIX',
                              'NORM يعرض 12 رقمًا معنويًا مع إزالة ضوضاء الفاصلة العائمة.',
                            ),
                            SizedBox(
                              height: 31,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  CalcPill(
                                    label: 'NORM',
                                    compact: true,
                                    active: settings.fix == null,
                                    onTap: () => apply(
                                      settings.copyWith(clearFix: true),
                                    ),
                                  ),
                                  for (var i = 0; i <= 10; i++) ...[
                                    const SizedBox(width: 5),
                                    CalcPill(
                                      label: 'FIX $i',
                                      compact: true,
                                      active: settings.fix == i,
                                      onTap: () => apply(
                                        settings.copyWith(fix: i),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            sectionTitle(
                              'مظهر الحاسبة',
                              'اختيار مستقل عن ثيم التطبيق، وبيتطبق فورًا على كل الأوضاع.',
                            ),
                            CalcSegmented<CalcFinish>(
                              values: CalcFinish.values,
                              selected: settings.finish,
                              labelFor: (finish) => switch (finish) {
                                CalcFinish.midnight => 'MIDNIGHT',
                                CalcFinish.paper => 'PAPER',
                              },
                              onChanged: (finish) =>
                                  apply(settings.copyWith(finish: finish)),
                            ),
                            const SizedBox(height: 9),
                            CalcSoftButton(
                              label: 'ثيم التطبيق والألوان',
                              icon: Icons.palette_outlined,
                              expanded: true,
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AppearanceScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'السجل: ${_session.history.length} عملية محفوظة',
                                    style: CalcTypography.label(
                                      palette,
                                      size: 10,
                                    ).copyWith(color: palette.mathMuted),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _openHistory();
                                  },
                                  child: const Text('إدارة السجل'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            TextButton.icon(
                              onPressed: () => apply(const CalcSettings()),
                              icon: Icon(
                                Icons.restart_alt_rounded,
                                size: 18,
                                color: palette.mathMuted,
                              ),
                              label: Text(
                                'استعادة الإعدادات الافتراضية',
                                style: TextStyle(
                                  color: palette.mathMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const CalcNote(
                              icon: Icons.lock_outline_rounded,
                              text:
                                  'الحاسبة لا تطلب أي صلاحية ولا تستخدم الإنترنت. '
                                  'كل التعبيرات تُقيَّم بمحرك Dart محلي بدون eval غير آمن.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _ModeInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final foreground = selected
        ? (palette.isDark ? Colors.black : Colors.white)
        : palette.label;
    return Semantics(
      button: true,
      selected: selected,
      label: info.nameAr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected
                ? palette.accent
                : (palette.isDark
                    ? Colors.white.withValues(alpha: 0.045)
                    : Colors.white.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                info.icon,
                size: 12.5,
                color: selected ? foreground : palette.mathMuted,
              ),
              const SizedBox(width: 4),
              Text(
                info.short,
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                textDirection: info.section == _ModeSection.tool
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
