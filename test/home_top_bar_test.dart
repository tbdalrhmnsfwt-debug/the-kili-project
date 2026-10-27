import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/widgets/home_top_bar.dart';

Widget _host(
  Widget bar, {
  Size size = const Size(400, 800),
  double topPadding = 24,
  double textScale = 1,
}) =>
    MaterialApp(
      theme: ZakerTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: EdgeInsets.only(top: topPadding),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: bar),
      ),
    );

void main() {
  test('height follows the 6% formula inside a 48–56 dp clamp', () {
    expect(homeTopBarHeightFor(600), 48);
    expect(homeTopBarHeightFor(700), 48);
    expect(homeTopBarHeightFor(800), 48);
    expect(homeTopBarHeightFor(900), closeTo(54, 1e-9));
    expect(homeTopBarHeightFor(1200), 56);
  });

  testWidgets('the bar is the formula height plus the top safe inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeTopBar(
          showBadge: true,
          onMenu: () {},
          onNotifications: () {},
          onSettings: () {},
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('home-top-bar'))).height,
      closeTo(48 + 24, 1e-9),
    );
    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-menu')), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-bell')), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-badge')), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-settings')), findsOneWidget);
  });

  testWidgets('the badge and the menu disappear when they do not apply', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeTopBar(
          showBadge: false,
          onNotifications: () {},
          onSettings: () {},
        ),
      ),
    );
    expect(find.byKey(const Key('home-top-bar-badge')), findsNothing);
    expect(find.byKey(const Key('home-top-bar-menu')), findsNothing);
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeTopBar(
          showBadge: true,
          onMenu: () {},
          onNotifications: () {},
          onSettings: () {},
        ),
        size: const Size(320, 800),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
