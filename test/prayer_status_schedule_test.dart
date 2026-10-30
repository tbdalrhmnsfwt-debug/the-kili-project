import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/prayer_methods.dart';
import 'package:zaker_ai/features/prayer/prayer_status_schedule.dart';

PrayerTimes _times(DateTime date) => PrayerTimes(
      date: date,
      coordinates: Coordinates(30.0444, 31.2357),
      calculationParameters: prayerParameters(
        methodId: 'egyptian',
        madhabId: 'shafi',
      ),
    );

void main() {
  final day1 = _times(DateTime(2026, 10, 29));
  final day2 = _times(DateTime(2026, 10, 30));

  test('emits every prayer in ascending order regardless of input order', () {
    final list = buildPrayerStatusBoundaries(
      days: [day2, day1],
      now: DateTime(2026, 10, 29),
    );
    expect(list.map((b) => b.name).take(6), [
      'الفجر',
      'الظهر',
      'العصر',
      'المغرب',
      'العشاء',
      'الفجر',
    ]);
    for (var i = 1; i < list.length; i++) {
      expect(list[i].at.isAfter(list[i - 1].at), isTrue);
    }
    expect(list.first.at, day1.fajr.toLocal());
  });

  test("after Isha the next target is tomorrow's Fajr", () {
    final now = day1.isha.toLocal().add(const Duration(minutes: 1));
    final list = buildPrayerStatusBoundaries(days: [day1, day2], now: now);
    expect(list.first.name, 'الفجر');
    expect(list.first.at, day1.fajrAfter.toLocal());
  });

  test('a boundary inside the lead window is skipped', () {
    final now = day1.dhuhr.toLocal().subtract(const Duration(seconds: 4));
    final list = buildPrayerStatusBoundaries(days: [day1], now: now);
    expect(list.first.name, 'العصر');
  });

  test('carries the local hour and minute for the notification text', () {
    final list = buildPrayerStatusBoundaries(
      days: [day1],
      now: DateTime(2026, 10, 29),
    );
    final asr = list.firstWhere((b) => b.name == 'العصر');
    final local = day1.asr.toLocal();
    expect(asr.hour, local.hour);
    expect(asr.minute, local.minute);
    expect(asr.toJson(), {
      'at': local.millisecondsSinceEpoch,
      'name': 'العصر',
      'hour': local.hour,
      'minute': local.minute,
    });
  });

  test('the bar is shown only when every gate is open', () {
    bool show({
      bool adhan = true,
      bool bar = true,
      bool location = true,
      bool notifications = true,
    }) =>
        shouldShowPrayerStatusBar(
          adhanEnabled: adhan,
          statusBarEnabled: bar,
          hasLocation: location,
          notificationsAllowed: notifications,
        );
    expect(show(), isTrue);
    expect(show(adhan: false), isFalse);
    expect(show(bar: false), isFalse);
    expect(show(location: false), isFalse);
    expect(show(notifications: false), isFalse);
  });
}
