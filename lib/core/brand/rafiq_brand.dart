/// The product identity shown in the shell, splash, Settings and share text.
///
/// These are plain Arabic strings, not a second dictionary: every widget that
/// shows them passes them through `TrText`, so the English table in
/// `assets/i18n/en.json` translates them without changing these constants.
abstract final class RafiqBrand {
  static const String appName = 'رفيق الطالب';
  static const String developer = 'عبد الرحمن صفوت عطا';
  static const String studio = 'عبد الرحمن سوفت';
  static const String credit = 'من تطوير: $developer';

  /// The short credit shown at the bottom of the home screen.
  static const String copyright = 'المطور عبد الرحمن سوفت';
}
