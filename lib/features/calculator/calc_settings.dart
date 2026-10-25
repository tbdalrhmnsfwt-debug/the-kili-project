/// Calculator preferences, persisted as JSON by the screen.
library;

import 'dart:convert';

import 'engine/evaluator.dart';

enum CalcFinish { midnight, paper }

class CalcSettings {
  const CalcSettings({
    this.angleUnit = AngleUnit.degrees,
    this.naturalInput = true,
    this.haptics = true,
    this.finish = CalcFinish.midnight,
    this.preferExact = true,
    this.mixedFractions = false,
    this.polarComplex = false,
    this.fix,
  });

  final AngleUnit angleUnit;

  /// MATH (natural/pretty) vs LINE editing.
  final bool naturalInput;
  final bool haptics;
  final CalcFinish finish;
  final bool preferExact;
  final bool mixedFractions;
  final bool polarComplex;

  /// FIX 0–10, or null for NORM.
  final int? fix;

  CalcSettings copyWith({
    AngleUnit? angleUnit,
    bool? naturalInput,
    bool? haptics,
    CalcFinish? finish,
    bool? preferExact,
    bool? mixedFractions,
    bool? polarComplex,
    int? fix,
    bool clearFix = false,
  }) {
    return CalcSettings(
      angleUnit: angleUnit ?? this.angleUnit,
      naturalInput: naturalInput ?? this.naturalInput,
      haptics: haptics ?? this.haptics,
      finish: finish ?? this.finish,
      preferExact: preferExact ?? this.preferExact,
      mixedFractions: mixedFractions ?? this.mixedFractions,
      polarComplex: polarComplex ?? this.polarComplex,
      fix: clearFix ? null : (fix ?? this.fix),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'angle': angleUnit.name,
    'natural': naturalInput,
    'haptics': haptics,
    'finish': finish.name,
    'exact': preferExact,
    'mixed': mixedFractions,
    'polar': polarComplex,
    'fix': fix,
  };

  String encode() => jsonEncode(toJson());

  static CalcSettings decode(String? raw) {
    if (raw == null || raw.isEmpty) return const CalcSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const CalcSettings();
      return CalcSettings(
        angleUnit: AngleUnit.fromName(decoded['angle'] as String?),
        naturalInput: decoded['natural'] is bool ? decoded['natural'] as bool : true,
        haptics: decoded['haptics'] is bool ? decoded['haptics'] as bool : true,
        finish: (decoded['finish'] as String?) == CalcFinish.paper.name
            ? CalcFinish.paper
            : CalcFinish.midnight,
        preferExact: decoded['exact'] is bool ? decoded['exact'] as bool : true,
        mixedFractions:
            decoded['mixed'] is bool ? decoded['mixed'] as bool : false,
        polarComplex: decoded['polar'] is bool ? decoded['polar'] as bool : false,
        fix: decoded['fix'] is int ? (decoded['fix'] as int).clamp(0, 10) : null,
      );
    } on FormatException {
      return const CalcSettings();
    }
  }
}
