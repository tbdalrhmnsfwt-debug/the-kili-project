import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/hijri_date.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/widgets/prayer_pill.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';

final PrayerLocation _cairo = PrayerLocation(
  latitude: 30.0444,
  longitude: 31.2357,
  city: 'القاهرة',
);
final HijriDate _hijri = HijriDate.fromGregorian(DateTime(2026, 10, 27));

PrayerDay _day() {
  DateTime at(int hour, int minute) => DateTime(2026, 10, 27, hour, minute);
  return PrayerDay(
    date: DateTime(2026, 10, 27),
    now: at(4, 0),
    prayers: [
      PrayerMoment(name: PrayerName.fajr, time: at(5, 4)),
      PrayerMoment(name: PrayerName.dhuhr, time: at(11, 50)),
      PrayerMoment(name: PrayerName.asr, time: at(15, 10)),
      PrayerMoment(name: PrayerName.maghrib, time: at(17, 25)),
      PrayerMoment(name: PrayerName.isha, time: at(18, 55)),
    ],
    next: PrayerMoment(name: PrayerName.fajr, time: at(5, 4)),
    previousTime: DateTime(2026, 10, 26, 18, 55),
    location: _cairo,
  );
}

Widget _host(Widget pill) => MaterialApp(
      theme: ZakerTheme.light(),
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: pill))),
    );

void main() {
  test('a bare theme still yields feature accents', () {
    final fallback = featureAccentsOf(ThemeData.light());
    final light = ZakerTheme.light().extension<ZakerFeatureAccents>()!;
    expect(fallback.prayer, light.prayer);
  });

  testWidgets('shows the next prayer, its time, the countdown and the day', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PrayerPillView(
          day: _day(),
          location: _cairo,
          hijri: _hijri,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('صلاة الفجر'), findsOneWidget);
    expect(find.text('5:04 ص'), findsOneWidget);
    expect(find.text('01:04:00'), findsOneWidget);
    expect(find.text('القاهرة'), findsOneWidget);
    expect(find.text(_hijri.formatted), findsOneWidget);
    expect(find.byKey(const Key('home-prayer-chevron')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-prayer-pill')));
    expect(taps, 1);
  });

  testWidgets('the compact badge keeps the prayer and countdown on one line', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: PrayerPillView(
              compact: true,
              day: _day(),
              location: _cairo,
              hijri: _hijri,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    final badge = find.byKey(const Key('home-prayer-badge'));
    expect(badge, findsOneWidget);
    expect(find.text('صلاة الفجر'), findsOneWidget);
    expect(find.text('01:04:00'), findsOneWidget);
    // Loose width: the badge hugs its content and stays one fixed-height line.
    expect(tester.getSize(badge).height, 30);
    expect(tester.getSize(badge).width, lessThan(320));
    expect(
      tester.getCenter(find.text('صلاة الفجر')).dy,
      closeTo(tester.getCenter(find.text('01:04:00')).dy, 1),
    );
    await tester.tap(find.byKey(const Key('home-prayer-pill')));
    expect(taps, 1);
  });

  testWidgets('the compact badge survives 2.0x text in a 46 dp strip', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ZakerTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 150,
              height: 46,
              child: PrayerPillView(
                compact: true,
                day: _day(),
                location: _cairo,
                hijri: _hijri,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('home-prayer-badge')), findsOneWidget);
  });

  testWidgets('without a location it asks for one and still opens /islam', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PrayerPillView(
          day: null,
          location: null,
          hijri: _hijri,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('حدد موقعك لمعرفة مواقيت الصلاة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-prayer-pill')));
    expect(taps, 1);
  });

  testWidgets('the countdown honours the full text scale at 2.0x', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZakerTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: PrayerPillView(
              day: _day(),
              location: _cairo,
              hijri: _hijri,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    // The spec forbids clamping text scaling to hide an overflow: the live
    // countdown must be laid out at the scale the reader asked for.
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('01:04:00'))),
      const TextScaler.linear(2),
    );
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ZakerTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: PrayerPillView(
              day: _day(),
              location: _cairo,
              hijri: _hijri,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('home-prayer-pill'))).height,
      greaterThanOrEqualTo(64),
    );
  });
}
