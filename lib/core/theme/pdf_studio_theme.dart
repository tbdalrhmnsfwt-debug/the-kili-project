/// The PDF Studio's dark navy design system.
///
/// The rest of the app keeps its light brand chrome; PDF Studio is a focused
/// workspace and deliberately uses its own palette so the paper stays the
/// brightest thing on screen. Every screen, sheet and card in
/// `lib/features/pdf/` reads these tokens instead of inventing a shade.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// The fixed colours of the PDF Studio.
abstract final class PdfStudioColors {
  const PdfStudioColors._();

  /// The workspace behind every screen.
  static const Color background = Color(0xFF08152E);

  /// Cards, bars and sheets.
  static const Color surface = Color(0xFF102344);

  /// A raised surface: search fields, tool tiles, the page counter.
  static const Color surfaceAlt = Color(0xFF162B50);

  /// A hairline on a dark surface.
  static const Color stroke = Color(0x24FFFFFF);

  static const Color blue = Color(0xFF4779FF);
  static const Color violet = Color(0xFF7C5CFF);
  static const Color cyan = Color(0xFF35BCE8);
  static const Color yellow = Color(0xFFF5D45A);

  /// Primary copy.
  static const Color text = Color(0xFFF2F6FF);

  /// Supporting copy.
  static const Color muted = Color(0xFF9FB1D1);

  /// The red PDF badge.
  static const Color pdfRed = Color(0xFFE5484D);

  /// An accent light enough for small text on [surface].
  static const Color blueText = Color(0xFF9DB6FF);
  static const Color violetText = Color(0xFFC3B4FF);
  static const Color cyanText = Color(0xFF8ADCF2);
  static const Color green = Color(0xFF3DDC97);

  /// The dark translucent wash behind the floating bars.
  static const Color glass = Color(0xE6102344);

  static const double cardRadius = 24;
  static const double tileRadius = 18;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  static const List<Color> pageGradient = [
    Color(0xFF0A1A38),
    Color(0xFF08152E),
  ];

  /// A card on the dashboard.
  static BoxDecoration card({Color? color, Gradient? gradient}) =>
      BoxDecoration(
        color: gradient == null ? (color ?? surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: stroke),
        boxShadow: cardShadow,
      );

  /// The gradient used by the hero storage card.
  static const LinearGradient storageGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1B3563), Color(0xFF14284E)],
  );
}

/// Typography and Material themes for the studio.
abstract final class PdfStudioTheme {
  const PdfStudioTheme._();

  static const String font = ZakerTheme.fontUi;

  static ColorScheme get colorScheme => const ColorScheme.dark(
        primary: PdfStudioColors.blue,
        onPrimary: Colors.white,
        secondary: PdfStudioColors.violet,
        onSecondary: Colors.white,
        tertiary: PdfStudioColors.cyan,
        onTertiary: Color(0xFF04202B),
        surface: PdfStudioColors.surface,
        onSurface: PdfStudioColors.text,
        surfaceContainerHighest: PdfStudioColors.surfaceAlt,
        onSurfaceVariant: PdfStudioColors.muted,
        error: PdfStudioColors.pdfRed,
        onError: Colors.white,
        outline: PdfStudioColors.stroke,
      );

  /// The theme wrapped around every PDF Studio route.
  static ThemeData dark() {
    final base = ZakerTheme.dark();
    final scheme = colorScheme;
    final textTheme = base.textTheme.apply(
        bodyColor: PdfStudioColors.text, displayColor: PdfStudioColors.text);
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: PdfStudioColors.background,
      canvasColor: PdfStudioColors.background,
      dividerColor: PdfStudioColors.stroke,
      textTheme: textTheme,
      primaryTextTheme: base.primaryTextTheme.apply(
        bodyColor: PdfStudioColors.text,
        displayColor: PdfStudioColors.text,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: PdfStudioColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: PdfStudioColors.text,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: PdfStudioColors.text,
        ),
      ),
      iconTheme: const IconThemeData(color: PdfStudioColors.text, size: 22),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: PdfStudioColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PdfStudioColors.cardRadius),
          side: const BorderSide(color: PdfStudioColors.stroke),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PdfStudioColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: PdfStudioColors.surface,
        modalBarrierColor: Color(0xB3000716),
        showDragHandle: true,
        dragHandleColor: PdfStudioColors.muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PdfStudioColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: PdfStudioColors.text,
        ),
        contentTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 14,
          height: 1.5,
          color: PdfStudioColors.muted,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PdfStudioColors.cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PdfStudioColors.surfaceAlt,
        hintStyle: const TextStyle(
          fontFamily: font,
          color: PdfStudioColors.muted,
          fontSize: 14,
        ),
        prefixIconColor: PdfStudioColors.muted,
        suffixIconColor: PdfStudioColors.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
          borderSide: const BorderSide(color: PdfStudioColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
          borderSide: const BorderSide(color: PdfStudioColors.blue, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PdfStudioColors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PdfStudioColors.blueText,
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PdfStudioColors.text,
          side: const BorderSide(color: PdfStudioColors.stroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PdfStudioColors.tileRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? PdfStudioColors.blue
              : PdfStudioColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? PdfStudioColors.blue.withValues(alpha: 0.35)
              : PdfStudioColors.surfaceAlt,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: PdfStudioColors.blue,
        inactiveTrackColor: PdfStudioColors.stroke,
        thumbColor: PdfStudioColors.blue,
        overlayColor: PdfStudioColors.blue.withValues(alpha: 0.18),
        valueIndicatorColor: PdfStudioColors.blue,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: PdfStudioColors.surfaceAlt,
        contentTextStyle: TextStyle(
          fontFamily: font,
          color: PdfStudioColors.text,
          fontSize: 13,
        ),
        actionTextColor: PdfStudioColors.cyanText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: PdfStudioColors.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(
          fontFamily: font,
          color: PdfStudioColors.text,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PdfStudioColors.stroke),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: PdfStudioColors.muted,
        textColor: PdfStudioColors.text,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PdfStudioColors.blue,
        linearTrackColor: PdfStudioColors.surfaceAlt,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: PdfStudioColors.surface,
        selectedItemColor: PdfStudioColors.blueText,
        unselectedItemColor: PdfStudioColors.muted,
      ),
    );
  }

  /// Opens a dark studio sheet, whatever the ambient app theme is.
  static Future<T?> showSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: PdfStudioColors.surface,
      barrierColor: const Color(0xB3000716),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Theme(
        data: dark(),
        child: Builder(builder: builder),
      ),
    );
  }
}
