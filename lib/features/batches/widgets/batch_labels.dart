/// Small formatters shared by the batch screens.
library;

const List<String> _arabicDigits = [
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩'
];

/// Renders [value] with Arabic-Indic digits, as the labels in the spec use.
String arabicDigits(int value) {
  final buffer = StringBuffer();
  for (final rune in value.toString().runes) {
    final digit = rune - 0x30;
    buffer.write(digit >= 0 && digit <= 9 ? _arabicDigits[digit] : rune);
  }
  return buffer.toString();
}

/// `الأسبوع ١ · اليوم ٢`
String weekDayLabel(int week, int day) =>
    'الأسبوع ${arabicDigits(week)} · اليوم ${arabicDigits(day)}';

/// Arabic names in the order the app shows the week: Saturday first.
const List<String> _weekdayNames = [
  'الاتنين',
  'التلات',
  'الأربع',
  'الخميس',
  'الجمعة',
  'السبت',
  'الحد',
];

/// The day numbers the app lists in order, starting on Saturday.
const List<int> scheduleWeekOrder = [
  DateTime.saturday,
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
];

/// The Arabic name of a `DateTime.weekday` value.
String weekdayName(int dayOfWeek) =>
    dayOfWeek >= DateTime.monday && dayOfWeek <= DateTime.sunday
        ? _weekdayNames[dayOfWeek - 1]
        : '';

/// `٨:٠٠ ص`, with minutes from midnight.
String formatScheduleTime(int minutes) {
  final safe = minutes.clamp(0, 24 * 60);
  final hour24 = safe ~/ 60;
  final minute = safe % 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final suffix = hour24 < 12 ? 'ص' : 'م';
  final paddedMinute =
      minute < 10 ? '٠${arabicDigits(minute)}' : arabicDigits(minute);
  return '${arabicDigits(hour12)}:$paddedMinute $suffix';
}

/// `٨:٠٠ ص – ٩:٣٠ ص`
String formatScheduleRange(int startMinutes, int endMinutes) =>
    '${formatScheduleTime(startMinutes)} – ${formatScheduleTime(endMinutes)}';

/// Arabic copy for a parser uncertainty label.
String scheduleFieldLabel(String field) => switch (field) {
      'startMinutes' => 'وقت البداية',
      'endMinutes' => 'وقت النهاية',
      'dayOfWeek' => 'اليوم',
      'title' => 'العنوان',
      _ => field,
    };

/// Human file size. Files are never described with a fake precision.
String formatBytes(int bytes) {
  if (bytes < 1024) return '${arabicDigits(bytes)} بايت';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${arabicDigits(kilobytes.round())} كيلوبايت';
  }
  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(1)} ميجابايت';
}

/// `mm:ss`, or `h:mm:ss` for a long recording.
String formatDuration(int milliseconds) {
  final totalSeconds = (milliseconds / 1000).round();
  final seconds = totalSeconds % 60;
  final minutes = (totalSeconds ~/ 60) % 60;
  final hours = totalSeconds ~/ 3600;
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  }
  return '$minutes:$paddedSeconds';
}

/// `25/10/2026` in the device's local zone.
String formatBatchDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
