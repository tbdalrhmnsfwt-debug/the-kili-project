/// Visual design system for Zakerly.
///
/// The app is Arabic-first and therefore RTL by default.  It ships the
/// following font families (recovered from the APK's `assets/fonts` and
/// `FontManifest.json`):
///   * Cairo     — UI / headings
///   * Tajawal   — body
///   * Amiri     — Quranic / classical text
///   * Naskh     — classical text (PDF rendering)
///   * Almarai   — sheet rendering
///   * Changa / ReadexPro — sheet rendering
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand colours recovered from the APK resources.
class ZakerColors {
  const ZakerColors._();

  /// Primary brand colour.
  static const Color primary = Color(0xFF0F766E);

  /// Lighter primary used for gradients and highlights.
  static const Color primaryLight = Color(0xFF14B8A6);

  /// Deep primary for text on light surfaces.
  static const Color primaryDark = Color(0xFF115E59);

  /// Accent used for streaks / achievements.
  static const Color accent = Color(0xFFF59E0B);

  /// Error colour.
  static const Color danger = Color(0xFFDC2626);

  /// Success colour.
  static const Color success = Color(0xFF16A34A);

  /// Neutral surfaces.
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0F172A);
}

/// The app's spacing scale (4pt grid).
class ZakerSpacing {
  const ZakerSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets screen = EdgeInsets.all(lg);
  static const EdgeInsets card = EdgeInsets.all(md);
}

/// Corner radii used across the app.
class ZakerRadius {
  const ZakerRadius._();

  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(26),
  );
}

/// Builds the light and dark [ThemeData] for the app.
class ZakerTheme {
  const ZakerTheme._();

  static const String fontUi = 'Cairo';

  /// Body copy uses the same family as headings so the approved mockup keeps
  /// a single, consistent typographic voice. (The recovered APK also ships
  /// Tajawal; it stays bundled for PDF embedding.)
  static const String fontBody = 'Cairo';
  static const String fontQuran = 'Amiri';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ZakerColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? ZakerColors.primaryLight : ZakerColors.primary,
          secondary: ZakerColors.accent,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: fontUi,
      scaffoldBackgroundColor: isDark
          ? ZakerColors.surfaceDark
          : ZakerColors.surface,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? ZakerColors.surfaceDark : ZakerColors.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontUi,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: ZakerRadius.card,
          side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: ZakerSpacing.xl,
            vertical: ZakerSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZakerRadius.pill),
          ),
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: ZakerSpacing.xl,
            vertical: ZakerSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZakerRadius.pill),
          ),
          textStyle: const TextStyle(
            fontFamily: fontUi,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.pill),
        ),
        labelStyle: const TextStyle(fontFamily: fontBody, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.lg,
          vertical: ZakerSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontFamily: fontBody, fontSize: 12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : Colors.black12,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
        ),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontUi,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }
}
