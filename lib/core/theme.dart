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

/// The four selectable appearances. The first two keep the app's original
/// look; the other two are full palettes, not brightness overrides.
enum ZakerThemeStyle {
  light('light', 'فاتح', Brightness.light),
  dark('dark', 'غامق', Brightness.dark),
  blackGold('black_gold', 'أسود وذهبي', Brightness.dark),
  deepBlue('deep_blue', 'أزرق عميق', Brightness.dark);

  const ZakerThemeStyle(this.id, this.label, this.brightness);

  final String id;
  final String label;
  final Brightness brightness;

  static ZakerThemeStyle fromId(String? id) {
    for (final style in values) {
      if (style.id == id) return style;
    }
    return light;
  }
}

/// The per-feature accent colours of the active appearance.
class ZakerFeatureAccents extends ThemeExtension<ZakerFeatureAccents> {
  const ZakerFeatureAccents({
    required this.assistant,
    required this.study,
    required this.tasks,
    required this.islamic,
    required this.prayer,
    required this.qibla,
    required this.azkar,
    required this.hifz,
  });

  final Color assistant;
  final Color study;
  final Color tasks;
  final Color islamic;
  final Color prayer;
  final Color qibla;
  final Color azkar;
  final Color hifz;

  @override
  ZakerFeatureAccents copyWith({
    Color? assistant,
    Color? study,
    Color? tasks,
    Color? islamic,
    Color? prayer,
    Color? qibla,
    Color? azkar,
    Color? hifz,
  }) {
    return ZakerFeatureAccents(
      assistant: assistant ?? this.assistant,
      study: study ?? this.study,
      tasks: tasks ?? this.tasks,
      islamic: islamic ?? this.islamic,
      prayer: prayer ?? this.prayer,
      qibla: qibla ?? this.qibla,
      azkar: azkar ?? this.azkar,
      hifz: hifz ?? this.hifz,
    );
  }

  @override
  ZakerFeatureAccents lerp(covariant ZakerFeatureAccents? other, double t) {
    if (other == null) return this;
    return ZakerFeatureAccents(
      assistant: Color.lerp(assistant, other.assistant, t)!,
      study: Color.lerp(study, other.study, t)!,
      tasks: Color.lerp(tasks, other.tasks, t)!,
      islamic: Color.lerp(islamic, other.islamic, t)!,
      prayer: Color.lerp(prayer, other.prayer, t)!,
      qibla: Color.lerp(qibla, other.qibla, t)!,
      azkar: Color.lerp(azkar, other.azkar, t)!,
      hifz: Color.lerp(hifz, other.hifz, t)!,
    );
  }
}

/// The concrete colours of one appearance.
class ZakerPalette {
  const ZakerPalette({
    required this.style,
    required this.seed,
    required this.primary,
    required this.onPrimary,
    required this.surface,
    required this.card,
    required this.border,
    required this.onSurface,
    required this.muted,
    required this.heroGradient,
    required this.accents,
  });

  final ZakerThemeStyle style;
  final Color seed;
  final Color primary;
  final Color onPrimary;
  final Color surface;
  final Color card;
  final Color border;
  final Color onSurface;
  final Color muted;
  final List<Color> heroGradient;
  final ZakerFeatureAccents accents;

  bool get isDark => style.brightness == Brightness.dark;
}

/// Builds the themed [ThemeData] for the selected appearance.
class ZakerTheme {
  const ZakerTheme._();

  static const String fontUi = 'Cairo';

  /// Body copy uses the same family as headings so the approved mockup keeps
  /// a single, consistent typographic voice. (The recovered APK also ships
  /// Tajawal; it stays bundled for PDF embedding.)
  static const String fontBody = 'Cairo';
  static const String fontQuran = 'Amiri';

  static ThemeData light() => forStyle(ZakerThemeStyle.light);
  static ThemeData dark() => forStyle(ZakerThemeStyle.dark);

  static ThemeData forStyle(ZakerThemeStyle style) => _build(paletteFor(style));

  static ZakerPalette paletteFor(ZakerThemeStyle style) => switch (style) {
    ZakerThemeStyle.light => _lightPalette,
    ZakerThemeStyle.dark => _darkPalette,
    ZakerThemeStyle.blackGold => _blackGoldPalette,
    ZakerThemeStyle.deepBlue => _deepBluePalette,
  };

  static ThemeData _build(ZakerPalette palette) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.seed,
          brightness: palette.style.brightness,
        ).copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          secondary: palette.accents.azkar,
          onSecondary: palette.isDark ? const Color(0xFF0B1220) : Colors.white,
          surface: palette.surface,
          onSurface: palette.onSurface,
          outline: palette.border,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: palette.style.brightness,
      fontFamily: fontUi,
      scaffoldBackgroundColor: palette.surface,
      extensions: <ThemeExtension<dynamic>>[palette.accents],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: palette.surface,
        foregroundColor: palette.onSurface,
        titleTextStyle: TextStyle(
          fontFamily: fontUi,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: palette.onSurface,
        ),
        systemOverlayStyle: palette.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: ZakerRadius.card,
          side: BorderSide(color: palette.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
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
        fillColor: palette.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZakerSpacing.lg,
          vertical: ZakerSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZakerRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: palette.card,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontBody,
            fontSize: 12,
            color: palette.onSurface,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
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
        bodyColor: palette.onSurface,
        displayColor: palette.onSurface,
      ),
    );
  }

  static const ZakerPalette _lightPalette = ZakerPalette(
    style: ZakerThemeStyle.light,
    seed: ZakerColors.primary,
    primary: ZakerColors.primary,
    onPrimary: Colors.white,
    surface: ZakerColors.surface,
    card: Colors.white,
    border: Color(0xFFE2E8F0),
    onSurface: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    heroGradient: [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF0D4F4A)],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFF6D28D9),
      study: Color(0xFF1D4ED8),
      tasks: Color(0xFF15803D),
      islamic: Color(0xFF0F766E),
      prayer: Color(0xFF0F766E),
      qibla: Color(0xFF0369A1),
      azkar: Color(0xFFB45309),
      hifz: Color(0xFF15803D),
    ),
  );

  static const ZakerPalette _darkPalette = ZakerPalette(
    style: ZakerThemeStyle.dark,
    seed: ZakerColors.primaryLight,
    primary: ZakerColors.primaryLight,
    onPrimary: Color(0xFF06121A),
    surface: ZakerColors.surfaceDark,
    card: Color(0xFF1E293B),
    border: Color(0xFF334155),
    onSurface: Color(0xFFF8FAFC),
    muted: Color(0xFF94A3B8),
    heroGradient: [Color(0xFF0F766E), Color(0xFF0B4F49), Color(0xFF062F2B)],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFFC4B5FD),
      study: Color(0xFF93C5FD),
      tasks: Color(0xFF5EEAD4),
      islamic: Color(0xFF5EEAD4),
      prayer: Color(0xFF5EEAD4),
      qibla: Color(0xFF7DD3FC),
      azkar: Color(0xFFFBBF24),
      hifz: Color(0xFF86EFAC),
    ),
  );

  static const ZakerPalette _blackGoldPalette = ZakerPalette(
    style: ZakerThemeStyle.blackGold,
    seed: Color(0xFFD4AF37),
    primary: Color(0xFFD4AF37),
    onPrimary: Color(0xFF0B0B0B),
    surface: Color(0xFF000000),
    card: Color(0xFF141414),
    border: Color(0xFF332C1C),
    onSurface: Color(0xFFF5F1E6),
    muted: Color(0xFFA8A29E),
    heroGradient: [Color(0xFF2A220E), Color(0xFF1A1608), Color(0xFF050505)],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFFE9D5FF),
      study: Color(0xFFE3C05B),
      tasks: Color(0xFF9FE3D4),
      islamic: Color(0xFFE3C05B),
      prayer: Color(0xFFE3C05B),
      qibla: Color(0xFFD6C08A),
      azkar: Color(0xFFF5D07A),
      hifz: Color(0xFFB7E4C7),
    ),
  );

  static const ZakerPalette _deepBluePalette = ZakerPalette(
    style: ZakerThemeStyle.deepBlue,
    seed: Color(0xFF60A5FA),
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF04101F),
    surface: Color(0xFF071426),
    card: Color(0xFF0E2038),
    border: Color(0xFF1E3A5F),
    onSurface: Color(0xFFE8F0FB),
    muted: Color(0xFF9DB2CE),
    heroGradient: [Color(0xFF12345A), Color(0xFF0B2A52), Color(0xFF071426)],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFFA5B4FC),
      study: Color(0xFF93C5FD),
      tasks: Color(0xFF5EEAD4),
      islamic: Color(0xFF60A5FA),
      prayer: Color(0xFF60A5FA),
      qibla: Color(0xFF7DD3FC),
      azkar: Color(0xFFFBBF24),
      hifz: Color(0xFF86EFAC),
    ),
  );
}
