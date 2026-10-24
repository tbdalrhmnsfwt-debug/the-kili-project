/// Time formatting used by the prayer cards and countdowns.
///
/// Digits stay Latin (like the rest of the app); the period marker is the
/// Arabic «ص» / «م».  Countdowns are always zero-padded so the live seconds
/// do not make the card jump between widths.
library;

/// «5:04 ص» — the time shown next to a prayer name.
String formatClockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'ص' : 'م'}';
}

/// «5:04» — the compact form used in the five-prayer strip.
String formatShortClockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// `HH:MM:SS`, clamped at zero.
String formatCountdown(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// The countdown broken into its three display blocks.
({int hours, int minutes, int seconds}) countdownParts(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  return (
    hours: total ~/ 3600,
    minutes: (total % 3600) ~/ 60,
    seconds: total % 60,
  );
}

/// A non-negative duration, useful because a stale clock can produce a
/// negative difference for one frame around a prayer time.
Duration nonNegative(Duration duration) =>
    duration.isNegative ? Duration.zero : duration;
