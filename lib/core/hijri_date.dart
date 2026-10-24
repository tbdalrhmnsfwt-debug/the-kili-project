/// Hijri dates for the prayer screens.
///
/// The conversion itself comes from the `hijri` package (Umm al-Qura data).
/// The package ships unhamzated Arabic month names, so the display names here
/// are the spellings used in Egyptian school books and calendars.  A small
/// arithmetic fallback keeps the UI working if the conversion ever fails.
library;

import 'package:hijri/hijri_calendar.dart';

/// A Hijri calendar date, plus the Gregorian weekday it falls on.
class HijriDate {
  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
    required this.weekday,
  });

  final int year;
  final int month;
  final int day;

  /// `DateTime.weekday`: 1 = Monday … 7 = Sunday.
  final int weekday;

  static const List<String> monthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<String> weekdayNames = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  String get monthName => monthNames[(month - 1).clamp(0, 11)];

  String get weekdayName => weekdayNames[(weekday - 1).clamp(0, 6)];

  /// «24 ربيع الآخر 1447 هـ».
  String get formatted => '$day $monthName $year هـ';

  /// «الجمعة 24 ربيع الآخر 1447 هـ».
  String get withWeekday => '$weekdayName $formatted';

  /// Converts a Gregorian date using the Umm al-Qura calendar.
  factory HijriDate.fromGregorian(DateTime date) {
    try {
      final calendar = HijriCalendar.setLocal('ar');
      calendar.gregorianToHijri(date.year, date.month, date.day);
      final year = calendar.hYear;
      final month = calendar.hMonth;
      final day = calendar.hDay;
      if (year > 1200 && month >= 1 && month <= 12 && day >= 1) {
        return HijriDate(
          year: year,
          month: month,
          day: day,
          weekday: date.weekday,
        );
      }
    } catch (_) {
      // Fall through to the arithmetic conversion below.
    }
    return _tabularFallback(date);
  }

  @override
  String toString() => formatted;
}

/// Arabic month names for the Gregorian calendar.
const List<String> kArabicGregorianMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// «الجمعة 24 أكتوبر 2026».
String formatGregorianDate(DateTime date, {bool withWeekday = true}) {
  final weekday = HijriDate.weekdayNames[(date.weekday - 1).clamp(0, 6)];
  final month = kArabicGregorianMonths[(date.month - 1).clamp(0, 11)];
  final prefix = withWeekday ? '$weekday ' : '';
  return '$prefix${date.day} $month ${date.year}';
}

/// The weekday name for [date], from the shared Arabic list.
String arabicWeekdayName(DateTime date) =>
    HijriDate.weekdayNames[(date.weekday - 1).clamp(0, 6)];

/// A tabular Islamic calendar conversion used only when the Umm al-Qura
/// package cannot convert the date (for example a date far outside its table).
HijriDate _tabularFallback(DateTime date) {
  final julianDay = _gregorianJulianDay(date.year, date.month, date.day);
  var l = julianDay - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j =
      ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
      (l ~/ 5670) * ((43 * l) ~/ 15238);
  var rest =
      l -
      ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
      (j ~/ 16) * ((15238 * j) ~/ 43) +
      29;
  final month = (24 * rest) ~/ 709;
  rest = rest - (709 * month) ~/ 24;
  final day = rest;
  final year = 30 * n + j - 30;
  return HijriDate(
    year: year,
    month: month.clamp(1, 12),
    day: day < 1 ? 1 : day,
    weekday: date.weekday,
  );
}

int _gregorianJulianDay(int year, int month, int day) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = y ~/ 100;
  final b = 2 - a + a ~/ 4;
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      b -
      1524;
}
