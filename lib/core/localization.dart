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
  AppLocalizations(this.locale, this._table)
    : _byShape = _indexTemplates(_table);

  final Locale locale;

  /// Arabic-source -> translation map. Empty for the Arabic locale.
  final Map<String, String> _table;

  /// Shape index for strings built by interpolation: `"3 نقطة"` finds the
  /// shipped template `"{0} نقطة"` and renders `"3 points"`.
  final Map<String, List<String>> _byShape;

  static final Map<String, RegExp> _patterns = <String, RegExp>{};

  static final RegExp _placeholders = RegExp(r'\{\d+\}');
  static final RegExp _numberRuns = RegExp(r'\d+');

  static AppLocalizations of(BuildContext context) {
    final local = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(local != null, 'AppLocalizations not found in context');
    return local!;
  }

  /// Looks up [key] (an Arabic source string) in the active table.
  String t(String key) {
    final direct = _table[key];
    if (direct != null) return direct;
    if (_table.isEmpty) return key;

    final candidates = _byShape[_shape(key)];
    if (candidates == null) return key;
    for (final template in candidates) {
      final match = _patternFor(template).firstMatch(key);
      if (match == null) continue;
      final groups = _placeholderOrder(template);
      return _table[template]!.replaceAllMapped(_placeholders, (m) {
        final position = groups.indexOf(int.parse(m[1]!));
        return position < 0 ? m[0]! : (match.group(position + 1) ?? '');
      });
    }
    return key;
  }

  /// Substitutes `{0}`, `{1}`, … placeholders in [key].
  String f(String key, [List<Object?> args = const []]) {
    var out = t(key);
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', args[i]?.toString() ?? '');
    }
    return out;
  }

  static Map<String, List<String>> _indexTemplates(Map<String, String> table) {
    final index = <String, List<String>>{};
    for (final key in table.keys) {
      if (!_placeholders.hasMatch(key)) continue;
      index.putIfAbsent(_shape(key), () => <String>[]).add(key);
    }
    return index;
  }

  static String _shape(String value) =>
      value.replaceAll(_placeholders, '#').replaceAll(_numberRuns, '#');

  static List<int> _placeholderOrder(String template) => _placeholders
      .allMatches(template)
      .map((m) => int.parse(m[1]!))
      .toList(growable: false);

  static RegExp _patternFor(String template) {
    return _patterns.putIfAbsent(template, () {
      final parts = template.split(_placeholders);
      final buffer = StringBuffer('^');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) buffer.write('(.+?)');
        buffer.write(RegExp.escape(parts[i]));
      }
      buffer.write(r'$');
      return RegExp(buffer.toString());
    });
  }

  /// Loads the translation table for [locale].
  static Future<AppLocalizations> load(Locale locale) async {
    final isArabic = locale.languageCode == 'ar';
    if (isArabic) {
      return AppLocalizations(locale, const {});
    }
    final table = <String, String>{
      ...await _readTable('assets/i18n/en.json'),
      // Hand-written translations for strings the replica adds on top of the
      // shipped app.
      ...await _readTable('assets/i18n/en_extra.json'),
    };
    return AppLocalizations(locale, table);
  }

  static Future<Map<String, String>> _readTable(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('i18n: failed to load $path ($e)');
      return const {};
    }
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
