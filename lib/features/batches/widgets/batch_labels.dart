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
