/// Visual system for the premium scientific calculator.
///
/// The calculator is embedded in the Arabic-first app but every mathematical
/// surface is explicitly left-to-right. The palette follows the requested
/// instrument-like scheme in dark mode and keeps the same bevel language in
/// light mode so every colour variant of the app remains usable.
library;

import 'package:flutter/material.dart';

class CalcPalette {
  const CalcPalette({
    required this.isDark,
    required this.background,
    required this.backgroundAlt,
    required this.panel,
    required this.panelStrong,
    required this.border,
    required this.display,
    required this.displayAlt,
    required this.displayBorder,
    required this.math,
    required this.mathMuted,
    required this.lcd,
    required this.basicKey,
    required this.basicKeyTop,
    required this.operationKey,
    required this.operationKeyTop,
    required this.utilityKey,
    required this.utilityKeyTop,
    required this.shift,
    required this.shiftText,
    required this.alpha,
    required this.deleteKey,
    required this.clearKey,
    required this.equalsKey,
    required this.equalsText,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.shadow,
    required this.keyText,
    required this.operationText,
    required this.label,
    required this.divider,
  });

  final bool isDark;
  final Color background;
  final Color backgroundAlt;
  final Color panel;
  final Color panelStrong;
  final Color border;
  final Color display;
  final Color displayAlt;
  final Color displayBorder;
  final Color math;
  final Color mathMuted;
  final Color lcd;
  final Color basicKey;
  final Color basicKeyTop;
  final Color operationKey;
  final Color operationKeyTop;
  final Color utilityKey;
  final Color utilityKeyTop;
  final Color shift;

  /// Shift-coloured text that stays readable on light keys.
  final Color shiftText;
  final Color alpha;
  final Color deleteKey;
  final Color clearKey;
  final Color equalsKey;
  final Color equalsText;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;
  final Color shadow;
  final Color keyText;
  final Color operationText;
  final Color label;
  final Color divider;

  static const CalcPalette dark = CalcPalette(
    isDark: true,
    background: Color(0xFF1E1E24),
    backgroundAlt: Color(0xFF121212),
    panel: Color(0xF21F2027),
    panelStrong: Color(0xFF25262E),
    border: Color(0x33FFFFFF),
    display: Color(0xFF17181C),
    displayAlt: Color(0xFF111215),
    displayBorder: Color(0xFF343640),
    math: Color(0xFFFFFFFF),
    mathMuted: Color(0xFFA7ABB8),
    lcd: Color(0xFFA8B896),
    basicKey: Color(0xFF2A2A32),
    basicKeyTop: Color(0xFF383842),
    operationKey: Color(0xFF3A3A46),
    operationKeyTop: Color(0xFF4A4A58),
    utilityKey: Color(0xFF272831),
    utilityKeyTop: Color(0xFF343643),
    shift: Color(0xFFE6A100),
    shiftText: Color(0xFFE6A100),
    alpha: Color(0xFFC73E1D),
    deleteKey: Color(0xFF1B4965),
    clearKey: Color(0xFFD9534F),
    equalsKey: Color(0xFFE6A100),
    equalsText: Color(0xFF1A1407),
    accent: Color(0xFF6EE7D8),
    accentSoft: Color(0x246EE7D8),
    danger: Color(0xFFFF8A80),
    dangerSoft: Color(0x26FF8A80),
    shadow: Color(0xCC000000),
    keyText: Color(0xFFF7F7FA),
    operationText: Color(0xFFF0E4C8),
    label: Color(0xFFC7CBD5),
    divider: Color(0x1FFFFFFF),
  );

  static const CalcPalette light = CalcPalette(
    isDark: false,
    background: Color(0xFFE8EDF1),
    backgroundAlt: Color(0xFFD4DCE3),
    panel: Color(0xEBFFFFFF),
    panelStrong: Color(0xFFF8FAFC),
    border: Color(0x240F172A),
    display: Color(0xFFF8FAF7),
    displayAlt: Color(0xFFEDF2EE),
    displayBorder: Color(0xFFC7D1CB),
    math: Color(0xFF101418),
    mathMuted: Color(0xFF667085),
    lcd: Color(0xFF47624D),
    basicKey: Color(0xFFFFFFFF),
    basicKeyTop: Color(0xFFF4F7FA),
    operationKey: Color(0xFFDCE3EA),
    operationKeyTop: Color(0xFFEEF2F6),
    utilityKey: Color(0xFFE9EEF4),
    utilityKeyTop: Color(0xFFF7F9FC),
    shift: Color(0xFFB87400),
    shiftText: Color(0xFF7A4E00),
    alpha: Color(0xFFAA2F12),
    deleteKey: Color(0xFF1B4965),
    clearKey: Color(0xFFC4463F),
    equalsKey: Color(0xFFE6A100),
    equalsText: Color(0xFF1A1407),
    accent: Color(0xFF0F766E),
    accentSoft: Color(0x1A0F766E),
    danger: Color(0xFFB42318),
    dangerSoft: Color(0x14B42318),
    shadow: Color(0x2E1B2A3A),
    keyText: Color(0xFF12161B),
    operationText: Color(0xFF202833),
    label: Color(0xFF4B5563),
    divider: Color(0x140F172A),
  );

  static CalcPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class CalcTypography {
  const CalcTypography._();

  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  static TextStyle math(CalcPalette palette, {double size = 26, Color? color}) {
    return TextStyle(
      color: color ?? palette.math,
      fontSize: size,
      height: 1.12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      fontFeatures: tabular,
    );
  }

  static TextStyle label(CalcPalette palette, {double size = 12}) => TextStyle(
    color: palette.label,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static TextStyle title(CalcPalette palette, {double size = 16}) => TextStyle(
    color: palette.math,
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );
}

/// Shared bevel/elevation decoration for instrument panels.
BoxDecoration calcPanelDecoration(
  CalcPalette palette, {
  double radius = 20,
  Color? color,
  bool elevated = true,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: palette.border),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        color ?? palette.panel,
        Color.alphaBlend(
          (palette.isDark ? Colors.black : Colors.white).withValues(
            alpha: palette.isDark ? 0.16 : 0.28,
          ),
          color ?? palette.panel,
        ),
      ],
    ),
    boxShadow: elevated
        ? <BoxShadow>[
            BoxShadow(
              color: palette.shadow,
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: palette.isDark
                  ? Colors.white.withValues(alpha: 0.035)
                  : Colors.white.withValues(alpha: 0.8),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ]
        : null,
  );
}
