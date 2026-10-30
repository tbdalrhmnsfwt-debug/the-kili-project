import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';

void main() {
  test('the day key separates the same date at different UTC offsets', () {
    expect(
      prayerDayKeyFor(2026, 10, 29, 120),
      isNot(prayerDayKeyFor(2026, 10, 29, 180)),
    );
    expect(
      prayerDayKeyFor(2026, 10, 29, 120),
      prayerDayKeyFor(2026, 10, 29, 120),
    );
  });

  test('prayerDayKey reads the wall clock and the device offset', () {
    final now = DateTime(2026, 10, 29, 15, 10);
    final key = prayerDayKey(now);
    expect(key.year, 2026);
    expect(key.month, 10);
    expect(key.day, 29);
    expect(key.offsetMinutes, now.timeZoneOffset.inMinutes);
  });
}
