import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/prayer_methods.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';

final PrayerLocation _cairo = PrayerLocation(
  latitude: 30.0444,
  longitude: 31.2357,
  city: 'القاهرة',
);
final PrayerTimes _times = PrayerTimes(
  date: DateTime(2026, 10, 29),
  coordinates: Coordinates(30.0444, 31.2357),
  calculationParameters: prayerParameters(
    methodId: 'egyptian',
    madhabId: 'shafi',
  ),
);

void main() {
  test('one second before Fajr, Fajr is next', () {
    final day = PrayerDay.fromTimes(
      times: _times,
      location: _cairo,
      now: _times.fajr.toLocal().subtract(const Duration(seconds: 1)),
    );
    expect(day.next.name, PrayerName.fajr);
    expect(day.next.tomorrow, isFalse);
  });

  test('at the exact Fajr second the next prayer is Dhuhr', () {
    final day = PrayerDay.fromTimes(
      times: _times,
      location: _cairo,
      now: _times.fajr.toLocal(),
    );
    expect(day.next.name, PrayerName.dhuhr);
  });

  test("after Isha the next prayer is tomorrow's Fajr", () {
    final day = PrayerDay.fromTimes(
      times: _times,
      location: _cairo,
      now: _times.isha.toLocal().add(const Duration(minutes: 1)),
    );
    expect(day.next.name, PrayerName.fajr);
    expect(day.next.tomorrow, isTrue);
    expect(day.next.time, _times.fajrAfter.toLocal());
    expect(day.previousTime, _times.isha.toLocal());
  });

  test("before Fajr the previous prayer is yesterday's Isha", () {
    final day = PrayerDay.fromTimes(
      times: _times,
      location: _cairo,
      now: _times.fajr.toLocal().subtract(const Duration(minutes: 1)),
    );
    expect(day.next.name, PrayerName.fajr);
    expect(day.previousTime, _times.ishaBefore.toLocal());
    expect(day.progress, inInclusiveRange(0, 1));
  });
}
