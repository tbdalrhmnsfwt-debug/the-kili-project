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

/// Builds the shadcn theme for the selected appearance.
class ZakerShadTheme {
  const ZakerShadTheme._();

  static ShadThemeData light() => forStyle(ZakerThemeStyle.light);
  static ShadThemeData dark() => forStyle(ZakerThemeStyle.dark);

  static ShadThemeData forStyle(ZakerThemeStyle style) =>
      _build(ZakerTheme.paletteFor(style));

  static ShadThemeData _build(ZakerPalette palette) {
    return ShadThemeData(
      brightness: palette.style.brightness,
      colorScheme: ShadColorScheme(
        background: palette.surface,
        foreground: palette.onSurface,
        card: palette.card,
        cardForeground: palette.onSurface,
        popover: palette.card,
        popoverForeground: palette.onSurface,
        primary: palette.primary,
        primaryForeground: palette.onPrimary,
        secondary: palette.card,
        secondaryForeground: palette.onSurface,
        muted: palette.card,
        mutedForeground: palette.muted,
        accent: palette.card,
        accentForeground: palette.onSurface,
        destructive: palette.isDark
            ? const Color(0xFFF87171)
            : ZakerColors.danger,
        destructiveForeground: Colors.white,
        border: palette.border,
        input: palette.border,
        ring: palette.primary,
        selection: palette.primary.withValues(alpha: 0.30),
      ),
      radius: BorderRadius.circular(ZakerRadius.md),
      textTheme: ShadTextTheme(family: ZakerTheme.fontUi),
    );
  }
}
