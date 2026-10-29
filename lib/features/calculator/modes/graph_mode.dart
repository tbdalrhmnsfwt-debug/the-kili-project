/// GRAPH mode: interactive multiple-function plotting with numerical analysis.
///
/// Sampling is done by the pure-Dart graph engine. The painter only receives
/// finite polylines and marching-squares segments, so an asymptote never turns
/// into a false vertical line. Every analysis command is explicitly numerical
/// and is restricted to the function kinds where it is mathematically defined.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../calc_session.dart';
import '../engine/calculator_error.dart';
import '../engine/evaluator.dart';
import '../engine/graph.dart';
import '../engine/math_value.dart';
import '../engine/number_format.dart';
import '../engine/parser.dart';
import '../engine/table.dart';
import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';
import 'mode_scaffold.dart';

enum _GraphKind { cartesian, polar, parametric, implicit }

extension on _GraphKind {
  String get label => switch (this) {
        _GraphKind.cartesian => 'ديكارتي',
        _GraphKind.polar => 'قطبي',
        _GraphKind.parametric => 'وسيطي',
        _GraphKind.implicit => 'ضمني',
      };

  String get equation => switch (this) {
        _GraphKind.cartesian => 'y = f(x)',
        _GraphKind.polar => 'r = f(θ)',
        _GraphKind.parametric => 'x(t), y(t)',
        _GraphKind.implicit => 'F(x, y) = 0',
      };
}

class _GraphEntry {
  _GraphEntry({
    required this.id,
    String xSource = '',
    String ySource = '',
  })  : x = TextEditingController(text: xSource),
        y = TextEditingController(text: ySource);

  final String id;
  final TextEditingController x;
  final TextEditingController y;
  bool visible = true;

  void dispose() {
    x.dispose();
    y.dispose();
  }
}

class _PlotSeries {
  const _PlotSeries({
    required this.color,
    required this.segments,
    this.implicitSegments = const <GraphSegment>[],
    this.discontinuities = 0,
  });

  final Color color;
  final List<List<GraphPoint>> segments;
  final List<GraphSegment> implicitSegments;
  final int discontinuities;

  bool get isEmpty =>
      implicitSegments.isEmpty && segments.every((item) => item.length < 2);
}

class _PlotComputation {
  _PlotComputation(this.series, this.errors);

  final List<_PlotSeries> series;
  final List<String> errors;

  bool get isEmpty => series.isEmpty || series.every((item) => item.isEmpty);
}

class GraphMode extends StatefulWidget {
  const GraphMode({super.key, required this.session});

  final CalcSession session;

  @override
  State<GraphMode> createState() => _GraphModeState();
}

class _GraphModeState extends State<GraphMode> {
  _GraphKind _kind = _GraphKind.cartesian;
  late List<_GraphEntry> _entries;
  int _nextId = 1;

  double _centerX = 0;
  double _centerY = 0;
  double _spanX = 20;
  Size _plotSize = const Size(320, 300);

  bool _traceEnabled = true;
  double _traceX = 0;
  int _traceIndex = 0;

  final TextEditingController _xPoint = TextEditingController(text: '1');
  final Map<String, GraphSample> _cache = <String, GraphSample>{};
  final Map<String, List<GraphSegment>> _implicitCache =
      <String, List<GraphSegment>>{};

  String? _analysisTitle;
  List<String> _analysisDetails = <String>[];
  String? _analysisError;
  String? _analysisNote;
  List<GraphPoint> _markers = <GraphPoint>[];
  TangentLine? _tangent;

  double? _gestureSpan;
  double? _gestureFocusX;
  double? _gestureFocusY;

  CalcSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _entries = _defaultEntries(_kind);
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    _xPoint.dispose();
    super.dispose();
  }

  List<_GraphEntry> _defaultEntries(_GraphKind kind) {
    _nextId = 1;
    _GraphEntry make(String x, [String y = '']) =>
        _GraphEntry(id: 'e${_nextId++}', xSource: x, ySource: y);
    return switch (kind) {
      _GraphKind.cartesian => <_GraphEntry>[
          make('sin(x)'),
          make('x^2 - 2'),
        ],
      _GraphKind.polar => <_GraphEntry>[
          make('1 + cos(θ)'),
          make('sin(3θ)'),
        ],
      _GraphKind.parametric => <_GraphEntry>[
          make('cos(t)', 'sin(t)'),
          make('cos(3t)', 'sin(2t)'),
        ],
      _GraphKind.implicit => <_GraphEntry>[
          make('x^2 + y^2 - 4'),
          make('x^2 - y^2 - 1'),
        ],
    };
  }

  void _switchKind(_GraphKind kind) {
    if (kind == _kind) return;
    final old = _entries;
    setState(() {
      _kind = kind;
      _entries = _defaultEntries(kind);
      _cache.clear();
      _implicitCache.clear();
      _traceIndex = 0;
      _traceX = 0;
      _traceEnabled = kind != _GraphKind.implicit;
      _resetAnalysis();
    });
    for (final entry in old) {
      entry.dispose();
    }
  }

  void _addEntry() {
    if (_entries.length >= 6) return;
    final index = _entries.length + 1;
    final (String x, String y) = switch (_kind) {
      _GraphKind.cartesian => ('x', ''),
      _GraphKind.polar => ('1 + cos(θ)', ''),
      _GraphKind.parametric => ('cos($index t)', 'sin($index t)'),
      _GraphKind.implicit => ('x^2 + y^2 - $index', ''),
    };
    setState(() {
      _entries.add(_GraphEntry(id: 'e${_nextId++}', xSource: x, ySource: y));
    });
  }

  void _removeEntry(_GraphEntry entry) {
    if (_entries.length <= 1) return;
    setState(() {
      _entries.remove(entry);
      _traceIndex = _traceIndex.clamp(0, _entries.length - 1);
      _resetAnalysis();
    });
    entry.dispose();
  }

  void _clearAnalysis() {
    setState(_resetAnalysis);
  }

  void _resetAnalysis() {
    _analysisTitle = null;
    _analysisDetails = <String>[];
    _analysisError = null;
    _analysisNote = null;
    _markers = <GraphPoint>[];
    _tangent = null;
  }

  double get _xMin => _centerX - _spanX / 2;

  double get _xMax => _centerX + _spanX / 2;

  double get _spanY {
    final aspect = _plotSize.height / math.max(1, _plotSize.width);
    return _spanX * aspect.clamp(0.15, 6);
  }

  double get _yMin => _centerY - _spanY / 2;

  double get _yMax => _centerY + _spanY / 2;

  bool get _canTrace => _kind != _GraphKind.implicit;

  List<_GraphEntry> get _visibleEntries =>
      _entries.where((entry) => entry.visible).toList(growable: false);

  List<_GraphEntry> get _visibleCartesian =>
      _kind == _GraphKind.cartesian ? _visibleEntries : const <_GraphEntry>[];

  String _entryLabel(int index) {
    final symbol = switch (_kind) {
      _GraphKind.cartesian => 'f',
      _GraphKind.polar => 'r',
      _GraphKind.parametric => 'curve',
      _GraphKind.implicit => 'F',
    };
    final subscript = _subscript(index + 1);
    return switch (_kind) {
      _GraphKind.cartesian => '$symbol$subscript(x)',
      _GraphKind.polar => '$symbol$subscript(θ)',
      _GraphKind.parametric => '$symbol$subscript(t)',
      _GraphKind.implicit => '$symbol$subscript(x, y)',
    };
  }

  String _subscript(int number) {
    const digits = '₀₁₂₃₄₅₆₇₈₉';
    return '$number'.split('').map((digit) {
      final value = int.tryParse(digit);
      return value == null ? digit : digits[value];
    }).join();
  }

  List<Color> _seriesColors(CalcPalette palette) {
    return palette.isDark
        ? <Color>[
            palette.accent,
            palette.shift,
            const Color(0xFF7FA8FF),
            const Color(0xFFC79BFF),
            const Color(0xFF6BE59A),
            const Color(0xFFFF8FA3),
          ]
        : <Color>[
            palette.accent,
            const Color(0xFFB87400),
            const Color(0xFF2456C7),
            const Color(0xFF7A2EB5),
            const Color(0xFF137A3A),
            const Color(0xFFB01E45),
          ];
  }

  String _demoKey(
    String source,
    String second,
  ) {
    return '${_kind.name}|$source|$second|$_xMin|$_xMax|$_yMin|$_yMax|'
        '${_session.settings.angleUnit.name}';
  }

  GraphSample? _cachedSample(String key, GraphSample Function() build) {
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final sample = build();
      if (_cache.length >= 48) _cache.remove(_cache.keys.first);
      _cache[key] = sample;
      return sample;
    } on CalcError {
      rethrow;
    }
  }

  List<GraphSegment>? _cachedImplicit(
    String key,
    List<GraphSegment> Function() build,
  ) {
    final cached = _implicitCache[key];
    if (cached != null) return cached;
    final segments = build();
    if (_implicitCache.length >= 24) {
      _implicitCache.remove(_implicitCache.keys.first);
    }
    _implicitCache[key] = segments;
    return segments;
  }

  _PlotComputation _computePlot(CalcPalette palette) {
    final colors = _seriesColors(palette);
    final series = <_PlotSeries>[];
    final errors = <String>[];
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (!entry.visible) continue;
      final color = colors[i % colors.length];
      final label = _entryLabel(i);
      try {
        switch (_kind) {
          case _GraphKind.cartesian:
            final source = entry.x.text.trim();
            if (source.isEmpty) continue;
            final sample = _cachedSample(
              _demoKey(source, ''),
              () => sampleCartesian(
                source,
                minX: _xMin,
                maxX: _xMax,
                samples: 900,
                angleUnit: _session.settings.angleUnit,
              ),
            )!;
            series.add(
              _PlotSeries(
                color: color,
                segments: sample.segments,
                discontinuities: sample.discontinuities,
              ),
            );
          case _GraphKind.polar:
            final source = entry.x.text.trim();
            if (source.isEmpty) continue;
            final sample = _cachedSample(
              _demoKey(source, ''),
              () => samplePolar(
                source,
                minAngle: _xMin,
                maxAngle: _xMax,
                samples: 1000,
                angleUnit: _session.settings.angleUnit,
              ),
            )!;
            series.add(
              _PlotSeries(
                color: color,
                segments: sample.segments,
                discontinuities: sample.discontinuities,
              ),
            );
          case _GraphKind.parametric:
            final xSource = entry.x.text.trim();
            final ySource = entry.y.text.trim();
            if (xSource.isEmpty || ySource.isEmpty) continue;
            final sample = _cachedSample(
              _demoKey(xSource, ySource),
              () => sampleParametric(
                xSource,
                ySource,
                minT: _xMin,
                maxT: _xMax,
                samples: 900,
                angleUnit: _session.settings.angleUnit,
              ),
            )!;
            series.add(
              _PlotSeries(
                color: color,
                segments: sample.segments,
                discontinuities: sample.discontinuities,
              ),
            );
          case _GraphKind.implicit:
            final source = entry.x.text.trim();
            if (source.isEmpty) continue;
            final segments = _cachedImplicit(
              _demoKey(source, ''),
              () => sampleImplicit(
                source,
                minX: _xMin,
                maxX: _xMax,
                minY: _yMin,
                maxY: _yMax,
                resolution: 56,
                angleUnit: _session.settings.angleUnit,
              ),
            )!;
            series.add(
              _PlotSeries(
                color: color,
                segments: const <List<GraphPoint>>[],
                implicitSegments: segments,
              ),
            );
        }
      } on CalcError catch (error) {
        errors.add('$label: ${error.detail ?? error.hint}');
      }
    }
    return _PlotComputation(series, errors);
  }

  double _evaluateAt(String source, String variable, double value) {
    try {
      final context = EvalContext(
        angleUnit: _session.settings.angleUnit,
      );
      context.variables[variable] = EvalValue.real(value);
      final result = Evaluator(context).evaluate(parseExpression(source));
      if (!result.isReal || !result.realPart.isFinite) return double.nan;
      return result.realPart;
    } on CalcError {
      return double.nan;
    } on FormatException {
      return double.nan;
    }
  }

  GraphPoint? _tracePoint() {
    if (!_canTrace) return null;
    final visible = _visibleEntries;
    if (visible.isEmpty) return null;
    _traceIndex = _traceIndex.clamp(0, visible.length - 1);
    final entry = visible[_traceIndex];
    switch (_kind) {
      case _GraphKind.cartesian:
        final y = _evaluateAt(entry.x.text.trim(), 'x', _traceX);
        return y.isFinite ? GraphPoint(_traceX, y) : null;
      case _GraphKind.polar:
        final radius = _evaluateAt(entry.x.text.trim(), 'θ', _traceX);
        if (!radius.isFinite) return null;
        final radians = _angleToRadians(_traceX);
        return GraphPoint(
          radius * math.cos(radians),
          radius * math.sin(radians),
        );
      case _GraphKind.parametric:
        final x = _evaluateAt(entry.x.text.trim(), 't', _traceX);
        final y = _evaluateAt(entry.y.text.trim(), 't', _traceX);
        if (!x.isFinite || !y.isFinite) return null;
        return GraphPoint(x, y);
      case _GraphKind.implicit:
        return null;
    }
  }

  List<String> _traceValues() {
    final visible = _visibleEntries;
    if (!_canTrace || visible.isEmpty) return const <String>[];
    final entry = visible[_traceIndex.clamp(0, visible.length - 1)];
    switch (_kind) {
      case _GraphKind.cartesian:
        final y = _evaluateAt(entry.x.text.trim(), 'x', _traceX);
        return <String>[
          'x = ${formatGraphLabel(_traceX)}',
          'f(x) = ${formatGraphLabel(y)}',
        ];
      case _GraphKind.polar:
        final radius = _evaluateAt(entry.x.text.trim(), 'θ', _traceX);
        final point = _tracePoint();
        return <String>[
          'θ = ${formatGraphLabel(_traceX)}',
          'r = ${formatGraphLabel(radius)}',
          if (point != null)
            '(x, y) = (${formatGraphLabel(point.x)}, ${formatGraphLabel(point.y)})',
        ];
      case _GraphKind.parametric:
        final x = _evaluateAt(entry.x.text.trim(), 't', _traceX);
        final y = _evaluateAt(entry.y.text.trim(), 't', _traceX);
        return <String>[
          't = ${formatGraphLabel(_traceX)}',
          'x(t) = ${formatGraphLabel(x)}',
          'y(t) = ${formatGraphLabel(y)}',
        ];
      case _GraphKind.implicit:
        return const <String>[];
    }
  }

  double _angleToRadians(double value) => switch (_session.settings.angleUnit) {
        AngleUnit.degrees => value * math.pi / 180,
        AngleUnit.radians => value,
        AngleUnit.gradians => value * math.pi / 200,
      };

  void _zoom(double factor) {
    setState(() {
      _spanX = (_spanX * factor).clamp(0.05, 400.0);
      _resetAnalysis();
    });
  }

  void _resetViewport() {
    setState(() {
      _centerX = 0;
      _centerY = 0;
      _spanX = 20;
      _traceX = 0;
      _resetAnalysis();
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureSpan = _spanX;
    final width = math.max(1.0, _plotSize.width);
    final height = math.max(1.0, _plotSize.height);
    _gestureFocusX = _xMin + (details.localFocalPoint.dx / width) * _spanX;
    _gestureFocusY = _yMax - (details.localFocalPoint.dy / height) * _spanY;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final width = math.max(1.0, _plotSize.width);
    final height = math.max(1.0, _plotSize.height);
    if (details.pointerCount > 1 &&
        _gestureSpan != null &&
        _gestureFocusX != null &&
        _gestureFocusY != null) {
      final newSpan = (_gestureSpan! / details.scale).clamp(0.05, 400.0);
      final newSpanY = newSpan * (height / width).clamp(0.15, 6);
      final focusX = _gestureFocusX!;
      final focusY = _gestureFocusY!;
      setState(() {
        _spanX = newSpan;
        _centerX =
            focusX - (details.localFocalPoint.dx / width - 0.5) * newSpan;
        _centerY =
            focusY + (details.localFocalPoint.dy / height - 0.5) * newSpanY;
        _resetAnalysis();
      });
      return;
    }
    if (_traceEnabled && _canTrace) {
      final x = _xMin + (details.localFocalPoint.dx / width) * _spanX;
      setState(() {
        _traceX = x.clamp(_xMin, _xMax);
      });
      return;
    }
    final delta = details.focalPointDelta;
    setState(() {
      _centerX -= delta.dx / width * _spanX;
      _centerY += delta.dy / height * _spanY;
      _resetAnalysis();
    });
  }

  void _moveTraceTo(Offset localPosition) {
    if (!_traceEnabled || !_canTrace) return;
    final width = math.max(1.0, _plotSize.width);
    setState(() {
      _traceX =
          (_xMin + (localPosition.dx / width) * _spanX).clamp(_xMin, _xMax);
    });
  }

  void _requireCartesian() {
    if (_kind == _GraphKind.cartesian) return;
    throw const CalcError(
      CalcErrorKind.unsupported,
      detail:
          'الجذور والقيم القصوى والتقاطعات والمماس وجدول القيم متاحة لدوال y = f(x) الديكارتية فقط.',
    );
  }

  _GraphEntry _firstEntry() {
    final visible = _visibleCartesian;
    if (visible.isEmpty) {
      throw const CalcError(
        CalcErrorKind.argument,
        detail: 'مفيش دالة ديكارتية ظاهرة.',
      );
    }
    return visible.first;
  }

  void _runAnalysis(
    String title,
    List<String> Function() operation,
  ) {
    try {
      _requireCartesian();
      _markers = <GraphPoint>[];
      _tangent = null;
      final details = operation();
      setState(() {
        _analysisTitle = title;
        _analysisDetails = details;
        _analysisError = null;
        _analysisNote =
            'نتائج عددية على نطاق x الظاهر فقط. تغيير النطاق أو النوع بيمسح التحليل.';
      });
    } on CalcError catch (error) {
      setState(() {
        _analysisTitle = null;
        _analysisDetails = <String>[];
        _analysisError = '${error.label}: ${error.detail ?? error.hint}';
        _analysisNote = null;
        _markers = <GraphPoint>[];
        _tangent = null;
      });
    }
  }

  void _findRoots() {
    if (_kind != _GraphKind.cartesian) {
      _runAnalysis('الجذور', () => const <String>[]);
      return;
    }
    _runAnalysis('الجذور العددية', () {
      final entry = _firstEntry();
      final roots = findRoots(
        entry.x.text.trim(),
        minX: _xMin,
        maxX: _xMax,
        angleUnit: _session.settings.angleUnit,
      );
      if (roots.isEmpty) {
        return const <String>['مفيش جذور حقيقية اتلقت داخل النطاق الظاهر.'];
      }
      _markers = <GraphPoint>[for (final root in roots) GraphPoint(root, 0)];
      return <String>[
        for (final root in roots)
          'x = ${formatGraphLabel(root)}  ·  f(x) = '
              '${formatGraphLabel(_evaluateAt(entry.x.text.trim(), 'x', root))}',
      ];
    });
  }

  void _findExtrema() {
    _runAnalysis('القيم العظمى والصغرى', () {
      final entry = _firstEntry();
      final extrema = findExtrema(
        entry.x.text.trim(),
        minX: _xMin,
        maxX: _xMax,
        angleUnit: _session.settings.angleUnit,
      );
      if (extrema.isEmpty) {
        return const <String>[
          'مفيش قيم قصوى داخل النطاق الظاهر (أو الدالة غير قابلة للاشتقاق).',
        ];
      }
      _markers = <GraphPoint>[for (final item in extrema) item.point];
      return <String>[
        for (final item in extrema)
          '${item.isMinimum ? 'قيمة صغرى' : 'قيمة عظمى'} عند '
              'x = ${formatGraphLabel(item.point.x)}  ·  y = '
              '${formatGraphLabel(item.point.y)}',
      ];
    });
  }

  void _findIntersections() {
    _runAnalysis('نقاط التقاطع', () {
      final visible = _visibleCartesian;
      if (visible.length < 2) {
        throw const CalcError(
          CalcErrorKind.argument,
          detail: 'نقاط التقاطع تحتاج دالتين ديكارتيتين ظاهرتين على الأقل.',
        );
      }
      final points = findIntersections(
        visible[0].x.text.trim(),
        visible[1].x.text.trim(),
        minX: _xMin,
        maxX: _xMax,
        angleUnit: _session.settings.angleUnit,
      );
      if (points.isEmpty) {
        return const <String>['مفيش نقاط تقاطع اتلقت داخل النطاق الظاهر.'];
      }
      _markers = points;
      return <String>[
        for (final point in points)
          '(x, y) = (${formatGraphLabel(point.x)}, '
              '${formatGraphLabel(point.y)})',
      ];
    });
  }

  void _findTangent() {
    _runAnalysis('المماس عند نقطة', () {
      final entry = _firstEntry();
      final raw = _xPoint.text.trim().replaceAll('−', '-');
      final x = double.tryParse(raw);
      if (x == null || !x.isFinite) {
        throw const CalcError(
          CalcErrorKind.argument,
          detail: 'اكتب قيمة عددية صالحة للنقطة x.',
        );
      }
      final tangent = tangentAt(
        entry.x.text.trim(),
        x,
        angleUnit: _session.settings.angleUnit,
      );
      _tangent = tangent;
      _markers = <GraphPoint>[tangent.point];
      return <String>[
        'نقطة التماس: (${formatGraphLabel(tangent.point.x)}, '
            '${formatGraphLabel(tangent.point.y)})',
        'الميل m = ${formatGraphLabel(tangent.slope)}',
        'y = ${formatGraphLabel(tangent.slope)}·x '
            '${tangent.intercept < 0 ? '−' : '+'} '
            '${formatGraphLabel(tangent.intercept.abs())}',
      ];
    });
  }

  void _buildValueTable() {
    _runAnalysis('جدول القيم', () {
      final entry = _firstEntry();
      final step = _spanX / 10;
      final table = buildTable(
        entry.x.text.trim(),
        start: _xMin,
        end: _xMax,
        step: step,
        angleUnit: _session.settings.angleUnit,
        maximumRows: 11,
      );
      return <String>[
        for (final row in table.rows)
          'x = ${formatGraphLabel(row.x)}  →  f(x) = ${row.formatted}',
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final colors = _seriesColors(palette);
    final computation = _computePlot(palette);
    final plot = _tracePoint();
    final traceValues = _traceValues();
    final visibleEntries = _visibleEntries;
    final traceColors = <Color>[
      for (var i = 0; i < _entries.length; i++)
        if (_entries[i].visible) colors[i % colors.length],
    ];
    final legend = <Widget>[];
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (!entry.visible) continue;
      final source = _kind == _GraphKind.parametric
          ? '${entry.x.text} , ${entry.y.text}'
          : entry.x.text;
      legend.add(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i % colors.length],
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${_entryLabel(i)} = ${source.isEmpty ? '…' : source}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CalcTypography.label(palette, size: 9.5).copyWith(
                    color: palette.mathMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final discontinuities = computation.series.fold<int>(
      0,
      (sum, item) => sum + item.discontinuities,
    );
    return CalcModePage(
      title: 'GRAPH — الرسم البياني',
      subtitle:
          'دوال متعددة، تكبير وتحريك، تتبع، وجذور وقيم قصوى وتقاطعات مماس وجدول — '
          'كلها عددية داخل النطاق الظاهر.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalcSegmented<_GraphKind>(
                  values: _GraphKind.values,
                  selected: _kind,
                  labelFor: (kind) => kind.label,
                  onChanged: _switchKind,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_kind.equation} · في القطبي والوسيطي يمثل المحور الأفقي نطاق θ أو t.',
                        style:
                            CalcTypography.label(palette, size: 9.5).copyWith(
                          color: palette.mathMuted,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'إضافة دالة (حتى 6)',
                      visualDensity: VisualDensity.compact,
                      onPressed: _entries.length >= 6 ? null : _addEntry,
                      icon: const Icon(Icons.add_chart_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < _entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _entryEditor(
                      palette, _entries[i], i, colors[i % colors.length]),
                ],
              ],
            ),
          ),
          CalcModeCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'x ∈ [${formatGraphLabel(_xMin)}, ${formatGraphLabel(_xMax)}]  ·  '
                        'y ∈ [${formatGraphLabel(_yMin)}, ${formatGraphLabel(_yMax)}]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            CalcTypography.label(palette, size: 9.5).copyWith(
                          color: palette.mathMuted,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    CalcPill(
                      label: 'تتبع',
                      compact: true,
                      active: _traceEnabled && _canTrace,
                      onTap: _canTrace
                          ? () {
                              setState(() {
                                _traceEnabled = !_traceEnabled;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(width: 4),
                    _miniIcon(
                      palette,
                      Icons.add_rounded,
                      'تكبير',
                      () => _zoom(0.78),
                    ),
                    _miniIcon(
                      palette,
                      Icons.remove_rounded,
                      'تصغير',
                      () => _zoom(1.28),
                    ),
                    _miniIcon(
                      palette,
                      Icons.restart_alt_rounded,
                      'إعادة الضبط',
                      _resetViewport,
                    ),
                  ],
                ),
                if (_traceEnabled &&
                    _canTrace &&
                    visibleEntries.length > 1) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 26,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visibleEntries.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 5),
                      itemBuilder: (context, index) => CalcPill(
                        label: 'f${index + 1}',
                        compact: true,
                        active: index == _traceIndex,
                        color: traceColors[index % traceColors.length],
                        onTap: () {
                          setState(() {
                            _traceIndex = index;
                          });
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                SizedBox(
                  height: 292,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      if (size != _plotSize) {
                        _plotSize = size;
                      }
                      return Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: palette.displayBorder,
                          ),
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _handleScaleStart,
                          onScaleUpdate: _handleScaleUpdate,
                          onTapDown: (details) =>
                              _moveTraceTo(details.localPosition),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _GraphPainter(
                                  palette: palette,
                                  xMin: _xMin,
                                  xMax: _xMax,
                                  yMin: _yMin,
                                  yMax: _yMax,
                                  series: computation.series,
                                  markers: _markers,
                                  tangent: _tangent,
                                  tracePoint: plot,
                                  showGrid: true,
                                ),
                              ),
                              if (computation.isEmpty &&
                                  computation.errors.isEmpty)
                                IgnorePointer(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Text(
                                        _kind == _GraphKind.implicit
                                            ? 'مفيش منحنى داخل النطاق الحالي. '
                                                'كبّر أو حرّك الرسم، أو عدّل التعبير.'
                                            : 'اكتب تعبيرًا صالحًا لعرض المنحنى.',
                                        textAlign: TextAlign.center,
                                        style: CalcTypography.label(
                                          palette,
                                          size: 11,
                                        ).copyWith(
                                          color: palette.mathMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(spacing: 10, runSpacing: 5, children: legend),
                if (computation.errors.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  for (final error in computation.errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        error,
                        style:
                            CalcTypography.label(palette, size: 9.5).copyWith(
                          color: palette.danger,
                          height: 1.35,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                ],
                if (discontinuities > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'تم فصل $discontinuities موضع عدم اتصال بدل رسم خط رأسي مزيف.',
                    style: CalcTypography.label(palette, size: 9).copyWith(
                      color: palette.shift,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
                if (_traceEnabled && _canTrace) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 14,
                          color: palette.accent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            traceValues.isEmpty
                                ? 'التتبع غير متاح للنوع ده.'
                                : traceValues.join('   ·   '),
                            style: CalcTypography.math(
                              palette,
                              size: 11,
                              color: palette.mathMuted,
                            ),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_canTrace)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: CalcNote(
                      text: 'التتبع بيحتاج دالة صريحة أو قطبية أو وسيطية. '
                          'الرسم الضمني بيعرض المنحنى والتحليل الديكارتي مش متاح له.',
                    ),
                  ),
              ],
            ),
          ),
          CalcModeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CalcSectionTitle(
                  title: 'التحليل العددي',
                  subtitle:
                      'يعمل على أول دالة ديكارتية ظاهرة. النتيجة تخص النطاق المعروض وقت التنفيذ.',
                ),
                const SizedBox(height: 9),
                CalcLabeledField(
                  label: 'نقطة المماس x',
                  controller: _xPoint,
                  hint: '1',
                  onSubmitted: (_) => _findTangent(),
                ),
                const SizedBox(height: 9),
                CalcActionGrid(
                  actions: <Widget>[
                    CalcSoftButton(
                      label: 'الجذور',
                      icon: Icons.adjust_rounded,
                      expanded: true,
                      onPressed: _findRoots,
                    ),
                    CalcSoftButton(
                      label: 'القيم القصوى',
                      icon: Icons.show_chart_rounded,
                      expanded: true,
                      onPressed: _findExtrema,
                    ),
                    CalcSoftButton(
                      label: 'التقاطعات',
                      icon: Icons.join_inner_rounded,
                      expanded: true,
                      onPressed: _findIntersections,
                    ),
                    CalcSoftButton(
                      label: 'المماس',
                      icon: Icons.timeline_rounded,
                      expanded: true,
                      color: palette.accent,
                      onPressed: _findTangent,
                    ),
                    CalcSoftButton(
                      label: 'جدول القيم',
                      icon: Icons.table_rows_rounded,
                      expanded: true,
                      onPressed: _buildValueTable,
                    ),
                    CalcSoftButton(
                      label: 'مسح التحليل',
                      icon: Icons.layers_clear_rounded,
                      expanded: true,
                      onPressed: _clearAnalysis,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CalcNote(
                  text: 'الجذور بتستخدم bisection، القيم القصوى بحث ذهبي، '
                      'والتقاطعات بتقارن الدالتين. كلها تقريبية، والمناطق غير المتصلة بتتفصل.',
                ),
              ],
            ),
          ),
          if (_analysisError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CalcResultBanner(
                isError: true,
                child: Text(_analysisError!, textDirection: TextDirection.rtl),
              ),
            ),
          if (_analysisTitle != null)
            CalcModeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalcSectionTitle(
                    title: _analysisTitle!,
                    subtitle: _analysisNote,
                    trailing: const CalcPill(label: 'NUMERIC', compact: true),
                  ),
                  const SizedBox(height: 9),
                  for (final detail in _analysisDetails)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.isDark
                            ? Colors.black.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.divider),
                      ),
                      child: Text(
                        detail,
                        style: CalcTypography.math(
                          palette,
                          size: 12,
                          color: palette.math,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniIcon(
    CalcPalette palette,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: palette.label),
    );
  }

  void _onSourceChanged(String _) {
    // Markers and tangent lines belong to the previous expression.
    setState(_resetAnalysis);
  }

  Widget _entryEditor(
    CalcPalette palette,
    _GraphEntry entry,
    int index,
    Color color,
  ) {
    final parametric = _kind == _GraphKind.parametric;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.black.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 17),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: parametric
                ? Row(
                    children: [
                      Expanded(
                        child: CalcLabeledField(
                          label: 'x${_subscript(index + 1)}(t) =',
                          controller: entry.x,
                          hint: 'cos(t)',
                          onChanged: _onSourceChanged,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CalcLabeledField(
                          label: 'y${_subscript(index + 1)}(t) =',
                          controller: entry.y,
                          hint: 'sin(t)',
                          onChanged: _onSourceChanged,
                        ),
                      ),
                    ],
                  )
                : CalcLabeledField(
                    label: switch (_kind) {
                      _GraphKind.cartesian => 'f${_subscript(index + 1)}(x) =',
                      _GraphKind.polar => 'r${_subscript(index + 1)}(θ) =',
                      _GraphKind.parametric => '',
                      _GraphKind.implicit =>
                        'F${_subscript(index + 1)}(x, y) = 0',
                    },
                    controller: entry.x,
                    hint: switch (_kind) {
                      _GraphKind.cartesian => 'sin(x)',
                      _GraphKind.polar => '1 + cos(θ)',
                      _GraphKind.parametric => 'cos(t)',
                      _GraphKind.implicit => 'x^2 + y^2 - 4',
                    },
                    onChanged: (_) => setState(() {}),
                  ),
          ),
          const SizedBox(width: 3),
          IconButton(
            tooltip: entry.visible ? 'إخفاء' : 'إظهار',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                entry.visible = !entry.visible;
                _traceIndex = _traceIndex.clamp(
                  0,
                  math.max(0, _visibleEntries.length - 1),
                );
                _resetAnalysis();
              });
            },
            icon: Icon(
              entry.visible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              size: 17,
              color: entry.visible ? palette.accent : palette.mathMuted,
            ),
          ),
          IconButton(
            tooltip: 'حذف الدالة',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
            onPressed: _entries.length <= 1 ? null : () => _removeEntry(entry),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 17,
              color: _entries.length <= 1
                  ? palette.mathMuted.withValues(alpha: 0.35)
                  : palette.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.palette,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.series,
    required this.markers,
    required this.tangent,
    required this.tracePoint,
    required this.showGrid,
  });

  final CalcPalette palette;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final List<_PlotSeries> series;
  final List<GraphPoint> markers;
  final TangentLine? tangent;
  final GraphPoint? tracePoint;
  final bool showGrid;

  Offset _map(double x, double y, Size size) {
    return Offset(
      (x - xMin) / (xMax - xMin) * size.width,
      size.height - (y - yMin) / (yMax - yMin) * size.height,
    );
  }

  double _niceStep(double range) {
    final raw = range.abs() / 8;
    if (!raw.isFinite || raw <= 0) return 1;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    final factor = normalized < 1.5
        ? 1
        : normalized < 3.2
            ? 2
            : normalized < 7
                ? 5
                : 10;
    return factor * magnitude;
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontFeatures: CalcTypography.tabular,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 1 || size.height <= 1) return;
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[palette.display, palette.displayAlt],
      ).createShader(rect);
    canvas.drawRect(rect, background);
    final plotRect = rect.deflate(0.5);
    canvas.save();
    canvas.clipRect(plotRect);

    final xStep = _niceStep(xMax - xMin);
    final yStep = _niceStep(yMax - yMin);
    if (showGrid) {
      final gridPaint = Paint()
        ..color = palette.mathMuted.withValues(alpha: 0.13)
        ..strokeWidth = 0.7;
      final axisPaint = Paint()
        ..color = palette.mathMuted.withValues(alpha: 0.55)
        ..strokeWidth = 1.1;
      var startX = (xMin / xStep).ceil() * xStep;
      for (var i = 0; i < 200; i++) {
        final x = startX + i * xStep;
        if (x > xMax) break;
        final dx = _map(x, 0, size).dx;
        canvas.drawLine(
          Offset(dx, 0),
          Offset(dx, size.height),
          x.abs() < xStep * 1e-6 ? axisPaint : gridPaint,
        );
        if (x.abs() > xStep * 1e-6) {
          _label(
            canvas,
            formatGraphLabel(x),
            Offset(dx + 2, size.height - 13),
            palette.mathMuted,
          );
        }
      }
      var startY = (yMin / yStep).ceil() * yStep;
      for (var i = 0; i < 200; i++) {
        final y = startY + i * yStep;
        if (y > yMax) break;
        final dy = _map(0, y, size).dy;
        canvas.drawLine(
          Offset(0, dy),
          Offset(size.width, dy),
          y.abs() < yStep * 1e-6 ? axisPaint : gridPaint,
        );
        if (y.abs() > yStep * 1e-6) {
          _label(
            canvas,
            formatGraphLabel(y),
            Offset(3, dy - 11),
            palette.mathMuted,
          );
        }
      }
    }

    for (final item in series) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = item.color;
      for (final segment in item.segments) {
        if (segment.length < 2) continue;
        final path = Path();
        var started = false;
        for (final point in segment) {
          final offset = _map(point.x, point.y, size);
          if (!started) {
            path.moveTo(offset.dx, offset.dy);
            started = true;
          } else {
            path.lineTo(offset.dx, offset.dy);
          }
        }
        canvas.drawPath(path, paint);
      }
      final implicitPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = item.color;
      for (final segment in item.implicitSegments) {
        canvas.drawLine(
          _map(segment.start.x, segment.start.y, size),
          _map(segment.end.x, segment.end.y, size),
          implicitPaint,
        );
      }
    }

    final tangent = this.tangent;
    if (tangent != null && tangent.slope.isFinite) {
      final paint = Paint()
        ..color = palette.shift
        ..strokeWidth = 1.4;
      canvas.drawLine(
        _map(xMin, tangent.valueAt(xMin), size),
        _map(xMax, tangent.valueAt(xMax), size),
        paint,
      );
    }

    for (final marker in markers) {
      if (!marker.isFinite) continue;
      final offset = _map(marker.x, marker.y, size);
      if (!plotRect.contains(offset)) continue;
      canvas.drawCircle(
        offset,
        4.4,
        Paint()..color = palette.display,
      );
      canvas.drawCircle(
        offset,
        3.1,
        Paint()..color = palette.accent,
      );
    }

    final trace = tracePoint;
    if (trace != null && trace.isFinite) {
      final offset = _map(trace.x, trace.y, size);
      final dashed = Paint()
        ..color = palette.accent.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      _drawDashedVertical(canvas, offset.dx, size.height, dashed);
      canvas.drawCircle(offset, 6, Paint()..color = palette.display);
      canvas.drawCircle(
        offset,
        4.5,
        Paint()
          ..color = palette.accent
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        offset,
        4.5,
        Paint()
          ..color = palette.display
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    canvas.restore();
  }

  void _drawDashedVertical(
      Canvas canvas, double x, double height, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + dash, height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}
