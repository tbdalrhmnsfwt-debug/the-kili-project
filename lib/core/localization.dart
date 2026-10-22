/// Localisation layer.
///
/// The shipped app uses **Arabic source strings as the translation keys**:
/// `assets/i18n/en.json` is a flat map from the Arabic source string to its
/// English rendering, e.g.
/// ```json
/// { "افتح": "Open", "  (ص {0})": "  (p. {0})" }
/// ```
/// The Arabic locale therefore needs no lookup table at all — the key *is* the
/// text. Only non-Arabic locales load a JSON map.
///
/// Plural and gender handling is left to the phrasing already baked into the
/// source strings, matching the original behaviour.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Access to the active translation table.
class AppLocalizations {
  AppLocalizations(this.locale, this._table);

  final Locale locale;

  /// Arabic-source -> translation map. Empty for the Arabic locale.
  final Map<String, String> _table;

  static AppLocalizations of(BuildContext context) {
    final local = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(local != null, 'AppLocalizations not found in context');
    return local!;
  }

  /// Looks up [key] (an Arabic source string) in the active table.
  String t(String key) => _table[key] ?? key;

  /// Substitutes `{0}`, `{1}`, … placeholders in [key].
  String f(String key, [List<Object?> args = const []]) {
    var out = t(key);
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', args[i]?.toString() ?? '');
    }
    return out;
  }

  /// Loads the translation table for [locale].
  static Future<AppLocalizations> load(Locale locale) async {
    final isArabic = locale.languageCode == 'ar';
    if (isArabic) {
      return AppLocalizations(locale, const {});
    }
    final table = <String, String>{};
    try {
      final raw = await rootBundle.loadString('assets/i18n/en.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((k, v) => table[k] = v.toString());
    } catch (e) {
      debugPrint('i18n: failed to load en.json ($e)');
    }
    return AppLocalizations(locale, table);
  }
}

/// Delegate that installs [AppLocalizations] into the widget tree.
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

/// Convenience accessors mirroring the original app's `S.of(context)` style.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).t(key);
  String trf(String key, [List<Object?> args = const []]) =>
      AppLocalizations.of(this).f(key, args);
}
