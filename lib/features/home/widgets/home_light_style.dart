/// The light dashboard palette.
///
/// The home is deliberately lighter than the rest of the app's brand chrome:
/// a soft blue-grey page, white or pastel cards, and navy ink. Keeping these
/// tokens in one place means the header, feature cards and tool shelf cannot
/// drift into slightly different shades of "white".
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// The light dashboard's colours, radii and elevation.
abstract final class HomeLight {
  const HomeLight._();

  /// The page behind the dashboard.
  static const Color page = ZakerColors.page;

  /// The deeper stop of the page wash.
  static const Color pageAlt = ZakerColors.pageSoft;

  /// The card base.
  static const Color surface = Colors.white;

  /// Headlines and primary copy.
  static const Color ink = ZakerColors.ink;

  /// Supporting copy.
  static const Color muted = ZakerColors.muted;

  /// Supporting copy on a page wash or a pastel field.
  ///
  /// [muted] is the brief's secondary grey, but at the 9–12 px sizes used on
  /// the dashboard it only clears 4.5:1 against pure white. This darker stop
  /// keeps the same slate hue and is used wherever the backdrop is tinted.
  static const Color mutedStrong = Color(0xFF475569);

  /// Hairlines, used sparingly.
  static const Color border = ZakerColors.border;

  /// The main action blue.
  static const Color blue = Color(0xFF2563EB);

  /// The darker end of the action blue.
  static const Color blueDeep = Color(0xFF1D4ED8);

  static const Color mint = Color(0xFF0F9F6E);
  static const Color cyan = Color(0xFF0284C7);
  static const Color orange = Color(0xFFEA8A2E);
  static const Color purple = Color(0xFF7C3AED);
  static const Color teal = Color(0xFF0F9F8A);

  /// Dark stops used for text that sits on the matching pastel field, where
  /// the accent itself is too light for 4.5:1.
  static const Color mintDeep = Color(0xFF0B7A55);
  static const Color orangeDeep = Color(0xFF9A5B12);

  /// The exact corner of every dashboard card.
  static const double cardRadius = ZakerRadius.cardValue;

  /// The light, low-contrast elevation used by every card.
  static const List<BoxShadow> shadow = ZakerShadows.card;

  /// The welcome banner: pale sky blue into a barely-there mint.
  static const List<Color> headerGradient = [
    Color(0xFFE8F4FF),
    Color(0xFFE4F9F4),
  ];

  /// Pastel fields for the six primary features.
  static const List<Color> mintGradient = [
    Color(0xFFE9F9F1),
    Color(0xFFD5F3E4),
  ];
  static const List<Color> cyanGradient = [
    Color(0xFFE4F5FD),
    Color(0xFFD3ECFA),
  ];
  static const List<Color> orangeGradient = [
    Color(0xFFFFF2E4),
    Color(0xFFFFE3C7),
  ];
  static const List<Color> purpleGradient = [
    Color(0xFFF2ECFF),
    Color(0xFFE6DBFC),
  ];
  static const List<Color> deepBlueGradient = [
    Color(0xFFE7EEFF),
    Color(0xFFD4E1FF),
  ];
  static const List<Color> tealGradient = [
    Color(0xFFE4F8F3),
    Color(0xFFD1F0E7),
  ];

  /// The three quick-action fields.
  static const List<Color> assistantGradient = [
    Color(0xFFF3EFFF),
    Color(0xFFE5DDFF),
  ];
  static const List<Color> bagGradient = [
    Color(0xFFE9F9F1),
    Color(0xFFD5F3E4),
  ];
  static const List<Color> tasksGradient = [
    Color(0xFFFFF0E8),
    Color(0xFFFFDFD2),
  ];

  /// The countdown and advice fields.
  static const List<Color> countdownGradient = [
    Color(0xFFFFF7E9),
    Color(0xFFFFEBCB),
  ];
  static const List<Color> adviceGradient = [
    Color(0xFFE8F9F1),
    Color(0xFFD7F3E6),
  ];

  /// A reusable white surface with the dashboard's soft elevation.
  static BoxDecoration cardDecoration({
    Color color = surface,
    Gradient? gradient,
    double radius = cardRadius,
  }) =>
      BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      );
}
