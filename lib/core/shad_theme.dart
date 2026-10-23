/// The `shadcn_ui` theme for Zakerly.
///
/// `theme.dart` remains the source of truth for Material widgets. This maps
/// the same brand palette and the Cairo family onto a [ShadThemeData] so the
/// shadcn components used by the screens (inputs, icon buttons, badges) look
/// like the rest of the app.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'theme.dart';

/// Builds the shadcn theme for each brightness.
class ZakerShadTheme {
  const ZakerShadTheme._();

  static ShadThemeData light() => _build(Brightness.light);
  static ShadThemeData dark() => _build(Brightness.dark);

  static ShadThemeData _build(Brightness brightness) {
    return ShadThemeData(
      brightness: brightness,
      colorScheme: brightness == Brightness.dark ? _dark : _light,
      radius: BorderRadius.circular(ZakerRadius.md),
      textTheme: ShadTextTheme(family: ZakerTheme.fontUi),
    );
  }

  /// Mirrors the Material light scheme.
  static const ShadColorScheme _light = ShadColorScheme(
    background: ZakerColors.surface,
    foreground: Color(0xFF0F172A),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF0F172A),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF0F172A),
    primary: ZakerColors.primary,
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFF1F5F9),
    secondaryForeground: Color(0xFF0F172A),
    muted: Color(0xFFF1F5F9),
    mutedForeground: Color(0xFF64748B),
    accent: Color(0xFFF1F5F9),
    accentForeground: Color(0xFF0F172A),
    destructive: ZakerColors.danger,
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    input: Color(0xFFE2E8F0),
    ring: ZakerColors.primary,
    selection: Color(0xFF99F6E4),
  );

  /// Mirrors the Material dark scheme.
  static const ShadColorScheme _dark = ShadColorScheme(
    background: ZakerColors.surfaceDark,
    foreground: Color(0xFFF8FAFC),
    card: Color(0xFF1E293B),
    cardForeground: Color(0xFFF8FAFC),
    popover: Color(0xFF1E293B),
    popoverForeground: Color(0xFFF8FAFC),
    primary: ZakerColors.primaryLight,
    primaryForeground: Color(0xFF0F172A),
    secondary: Color(0xFF334155),
    secondaryForeground: Color(0xFFF8FAFC),
    muted: Color(0xFF334155),
    mutedForeground: Color(0xFF94A3B8),
    accent: Color(0xFF334155),
    accentForeground: Color(0xFFF8FAFC),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFF334155),
    input: Color(0xFF334155),
    ring: ZakerColors.primaryLight,
    selection: Color(0xFF0F766E),
  );
}
