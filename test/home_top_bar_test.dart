import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  test('height follows the screen and stays inside a 56–64 dp clamp', () {
    expect(homeTopBarHeightFor(600), 56);
    expect(homeTopBarHeightFor(667), 56);
    expect(homeTopBarHeightFor(700), 56);
    expect(homeTopBarHeightFor(800), 60);
    expect(homeTopBarHeightFor(900), 64);
    expect(homeTopBarHeightFor(1200), 64);
    for (final height in [320.0, 667.0, 800.0, 900.0, 1200.0]) {
      expect(homeTopBarHeightFor(height), inInclusiveRange(56, 64));
    }
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
      closeTo(homeTopBarHeightFor(800) + 24, 1e-9),
    );
    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(find.byKey(const Key('home-app-name')), findsOneWidget);
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

  testWidgets('the controls start below the status-bar inset', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeTopBar(
          showBadge: false,
          onMenu: () {},
          onNotifications: () {},
          onSettings: () {},
        ),
        topPadding: 44,
      ),
    );
    // A control centred in an inset + bar box would sit inside the cutout and
    // put half its tap target under the status bar.
    for (final key in [
      'home-top-bar-menu',
      'home-top-bar-bell',
      'home-top-bar-settings',
    ]) {
      expect(
        tester.getTopLeft(find.byKey(Key(key))).dy,
        greaterThanOrEqualTo(44),
        reason: key,
      );
    }
    expect(
      tester.getSize(find.byKey(const Key('home-top-bar'))).height,
      closeTo(homeTopBarHeightFor(800) + 44, 1e-9),
    );
  });

  testWidgets('the light strip asks for dark status icons', (tester) async {
    Widget bar() => HomeTopBar(
          showBadge: false,
          onMenu: () {},
          onNotifications: () {},
          onSettings: () {},
        );

    await tester.pumpWidget(_host(bar(), topPadding: 24));
    var overlay = find.descendant(
      of: find.byType(HomeTopBar),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    var region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(overlay);
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.statusBarBrightness, Brightness.light);

    // The page is light at every inset, including the wide shell where
    // SafeArea consumes the status-bar padding.
    await tester.pumpWidget(_host(bar(), topPadding: 0));
    overlay = find.descendant(
      of: find.byType(HomeTopBar),
      matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(overlay);
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.statusBarBrightness, Brightness.light);
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    // MediaQuery alone would change the formula's screen height but not the
    // width the bar is actually laid out at.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
