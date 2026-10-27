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

/// Brand colours recovered from the APK resources, retuned to the
/// «رفيق الطالب» identity.
class ZakerColors {
  const ZakerColors._();

  /// Deep navy: the light theme's brand fill and the ink on white cards.
  static const Color navy = Color(0xFF121E36);

  /// The darkest navy, used to end gradients and back dark surfaces.
  static const Color navyDeep = Color(0xFF0B1426);

  /// Raised navy: gradient middle stop and raised surfaces on navy.
  static const Color navyLight = Color(0xFF1B2B4A);

  /// The brand gold: icon fills, indicators and accents.
  static const Color gold = Color(0xFFD4AF37);

  /// Light gold for text and icons on navy.
  static const Color goldLight = Color(0xFFE5C158);

  /// Gold-family text on white (meets 4.5:1); plain [gold] does not.
  static const Color goldDeep = Color(0xFF8A6A12);

  /// The light scaffold behind white cards.
  static const Color page = Color(0xFFF8F9FB);

  /// Body text on white.
  static const Color ink = Color(0xFF121E36);

  /// Secondary text on light surfaces.
  static const Color muted = Color(0xFF5B6678);

  /// Card hairline.
  static const Color border = Color(0xFFE6E9F0);

  /// The red of the «شنطتي» backpack only.
  static const Color backpack = Color(0xFFD32F2F);

  /// Primary brand colour.
  static const Color primary = navy;

  /// Lighter primary used for gradients and highlights.
  static const Color primaryLight = navyLight;

  /// Deep primary for text on light surfaces.
  static const Color primaryDark = navyDeep;

  /// Accent used for streaks / achievements.
  static const Color accent = gold;

  /// The navy surface used by banners and highlight cards.
  ///
  /// These cards keep white or light foregrounds in every appearance, so the
  /// gradient must stay navy rather than follow `colorScheme.primary` (which
  /// is gold in the three dark appearances).
  static const List<Color> navyGradient = [navy, navyLight, navyDeep];

  /// Error colour.
  static const Color danger = Color(0xFFDC2626);

  /// Success colour.
  static const Color success = Color(0xFF16A34A);

  /// Neutral surfaces.
  static const Color surface = page;
  static const Color surfaceDark = Color(0xFF0B1220);
}

/// WCAG relative contrast ratio between two opaque colours.
double contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Adjusts an accent until it reaches the 4.5:1 contrast that small text
/// needs against [background].
///
/// The app uses raw brand accents for icons and fills, but the same shades are
/// too light for 9–11px labels on the light theme. This darkens (or lightens
/// on dark surfaces) only the text copy, keeping the palette recognisable.
Color readableTextColor(Color color, Color background) {
  if (contrastRatio(color, background) >= 4.5) return color;
  final darkBackground = background.computeLuminance() < 0.5;
  final toward = darkBackground ? Colors.white : Colors.black;
  var adjusted = color;
  for (var step = 1; step <= 10; step++) {
    adjusted = Color.lerp(color, toward, step / 10)!;
    if (contrastRatio(adjusted, background) >= 4.5) return adjusted;
  }
  return toward;
}

/// The card surface the theme paints behind content.
Color cardSurfaceOf(ThemeData theme) =>
    theme.cardTheme.color ?? theme.colorScheme.surface;

/// [accent] adapted for use as text or an indicator on the active card.
///
/// Static brand navy is invisible on the dark cards, and the light palette's
/// gold is too light on a white card; both are lifted to a readable shade
/// without losing the hue where it already passes.
Color cardAccentOf(Color accent, ThemeData theme) =>
    readableTextColor(accent, cardSurfaceOf(theme));

final ZakerFeatureAccents _fallbackAccents =
    ZakerTheme.light().extension<ZakerFeatureAccents>()!;

/// [theme]'s feature accents, or the light palette's when a bare [ThemeData]
/// (a test harness, a dialog outside the app theme) carries none.
ZakerFeatureAccents featureAccentsOf(ThemeData theme) =>
    theme.extension<ZakerFeatureAccents>() ?? _fallbackAccents;

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

  /// The card corner of the brand system (16 dp).
  static const double cardValue = 16;

  static const BorderRadius card = BorderRadius.all(
    Radius.circular(cardValue),
  );
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(26),
  );
}

/// Elevations used across the app.
///
/// Cards are flat white surfaces with a hairline border and this one soft
/// shadow; Material elevation is never used for them.
class ZakerShadows {
  const ZakerShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14203A5C), blurRadius: 10, offset: Offset(0, 4)),
  ];
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
    required this.secondary,
    required this.onSecondary,
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

  /// The gold accent of the appearance: fills and indicators.
  final Color secondary;

  /// Text and icons drawn on [secondary].
  final Color onSecondary;
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
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seed,
      brightness: palette.style.brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      onSecondary: palette.onSecondary,
      surface: palette.surface,
      surfaceTint: Colors.transparent,
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
    seed: ZakerColors.navy,
    primary: ZakerColors.navy,
    onPrimary: Colors.white,
    secondary: ZakerColors.gold,
    onSecondary: ZakerColors.navy,
    surface: ZakerColors.page,
    card: Colors.white,
    border: ZakerColors.border,
    onSurface: ZakerColors.ink,
    muted: ZakerColors.muted,
    heroGradient: [
      ZakerColors.navy,
      ZakerColors.navyLight,
      ZakerColors.navyDeep,
    ],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFF5B4BC4),
      study: Color(0xFF2F5EA8),
      tasks: Color(0xFF4F7A4A),
      islamic: ZakerColors.goldDeep,
      prayer: ZakerColors.goldDeep,
      qibla: Color(0xFF5B6678),
      azkar: Color(0xFFA2603A),
      hifz: Color(0xFF5C6B2A),
    ),
  );

  static const ZakerPalette _darkPalette = ZakerPalette(
    style: ZakerThemeStyle.dark,
    seed: ZakerColors.goldLight,
    primary: ZakerColors.goldLight,
    onPrimary: ZakerColors.navy,
    secondary: ZakerColors.goldLight,
    onSecondary: ZakerColors.navy,
    surface: Color(0xFF0B1220),
    card: Color(0xFF16233C),
    border: Color(0xFF26344F),
    onSurface: Color(0xFFF2F5FA),
    muted: Color(0xFF9AA6BC),
    heroGradient: [
      ZakerColors.navyDeep,
      ZakerColors.navy,
      ZakerColors.navyLight,
    ],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFFB9AEF7),
      study: Color(0xFF9CC3F2),
      tasks: Color(0xFFA8CBA0),
      islamic: ZakerColors.goldLight,
      prayer: ZakerColors.goldLight,
      qibla: Color(0xFFAEB8C8),
      azkar: Color(0xFFE0A882),
      hifz: Color(0xFFC3CE8A),
    ),
  );

  static const ZakerPalette _blackGoldPalette = ZakerPalette(
    style: ZakerThemeStyle.blackGold,
    seed: Color(0xFFD4AF37),
    primary: ZakerColors.gold,
    onPrimary: Color(0xFF0B0B0B),
    secondary: ZakerColors.gold,
    onSecondary: Color(0xFF0B0B0B),
    surface: Color(0xFF000000),
    card: Color(0xFF141414),
    border: Color(0xFF332C1C),
    onSurface: Color(0xFFF5F1E6),
    muted: Color(0xFFA8A29E),
    heroGradient: [Color(0xFF2A220E), Color(0xFF1A1608), Color(0xFF050505)],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFFE9D5FF),
      study: Color(0xFFE3C05B),
      tasks: Color(0xFFC3CE8A),
      islamic: Color(0xFFE3C05B),
      prayer: Color(0xFFE3C05B),
      qibla: Color(0xFFD6C08A),
      azkar: Color(0xFFF5D07A),
      hifz: Color(0xFFB7E4C7),
    ),
  );

  static const ZakerPalette _deepBluePalette = ZakerPalette(
    style: ZakerThemeStyle.deepBlue,
    seed: ZakerColors.goldLight,
    primary: ZakerColors.goldLight,
    onPrimary: ZakerColors.navy,
    secondary: ZakerColors.goldLight,
    onSecondary: ZakerColors.navy,
    surface: Color(0xFF071426),
    card: Color(0xFF0E2038),
    border: Color(0xFF1E3A5F),
    onSurface: Color(0xFFE8F0FB),
    muted: Color(0xFF9DB2CE),
    heroGradient: [Color(0xFF071426), ZakerColors.navy, ZakerColors.navyDeep],
    accents: ZakerFeatureAccents(
      assistant: Color(0xFFA5B4FC),
      study: Color(0xFF9CC3F2),
      tasks: Color(0xFFA8CBA0),
      islamic: ZakerColors.goldLight,
      prayer: ZakerColors.goldLight,
      qibla: Color(0xFFAEB8C8),
      azkar: Color(0xFFE0A882),
      hifz: Color(0xFFC3CE8A),
    ),
  );
}
