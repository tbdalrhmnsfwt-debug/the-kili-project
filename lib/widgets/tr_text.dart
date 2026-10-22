/// A [Text] that renders the active locale's translation of its source.
///
/// The shipped app uses the Arabic source string as the translation key (see
/// `assets/i18n/en.json`). Routing every user-visible [Text] through this
/// widget means a screen only has to change its locale — not every string —
/// to switch between Arabic and English. In Arabic the table is empty, so the
/// source is rendered unchanged; a missing English key also falls back to the
/// Arabic source instead of showing a placeholder.
library;

import 'package:flutter/widgets.dart';

import '../core/localization.dart';

/// Text that translates its [data] before rendering.
class TrText extends StatelessWidget {
  const TrText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  /// The Arabic source string, or its final interpolated value.
  final String data;

  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Text(
      l10n?.t(data) ?? data,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
