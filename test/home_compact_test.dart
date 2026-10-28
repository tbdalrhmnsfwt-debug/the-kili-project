import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/shad_theme.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_preview_provider.dart';
import 'package:zaker_ai/features/home/home_screen.dart';
import 'package:zaker_ai/features/home/widgets/home_top_bar.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';
import 'package:zaker_ai/providers/app_providers.dart';

/// The real controller reports the first run only through its stored state, so
/// the test seeds the flag by subclassing instead of writing a file.
class _OnboardedSettings extends PrayerSettingsController {
  _OnboardedSettings() : super(LocalStore.memory()) {
    state = const PrayerSettings(onboarded: true);
  }
}

List<BagFolderPreview> _folders(int count) => [
      for (var i = 1; i <= count; i++)
        BagFolderPreview(
          id: 'f$i',
          name: 'مادة $i',
          colorValue: 0xFF2F5EA8,
          pocketCounts: const [1, 0, 0, 0],
        ),
    ];

Widget _app({
  ZakerThemeStyle style = ZakerThemeStyle.light,
  double textScale = 1,
  List<BagFolderPreview>? folders,
}) =>
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore.memory()),
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: 'u1', displayName: 'طالب'),
        ),
        prayerSettingsProvider.overrideWith((ref) => _OnboardedSettings()),
        bagFolderPreviewProvider.overrideWithValue(folders ?? _folders(7)),
      ],
      child: MaterialApp(
        theme: ZakerTheme.forStyle(style),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            // shadcn_ui reads its own theme; without this the ShadInput throws.
            child: ShadTheme(
              data: ZakerShadTheme.forStyle(style),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: const Scaffold(body: HomeScreen()),
      ),
    );

Future<void> _pumpAt(
  WidgetTester tester, {
  double width = 400,
  double height = 800,
  double textScale = 1,
  ZakerThemeStyle style = ZakerThemeStyle.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(textScale: textScale, style: style));
  await tester.pump();
}

void main() {
  for (final width in [320.0, 360.0, 411.0, 800.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('no overflow at $width dp and ${scale}x text',
          (tester) async {
        await _pumpAt(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('اسأل معلم AI عن أي حاجة…'), findsOneWidget);

        // The list lays out only what fits in the viewport plus its cache
        // extent, so the first screen cannot vouch for the daily tools or the
        // all-tools grid. Drag the keyed body to the bottom and check again.
        await tester.dragUntilVisible(
          find.text('كل حاجة في رفيق الطالب على بُعد ضغطة واحدة.'),
          find.byKey(const Key('home-body')),
          const Offset(0, -400),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final style in ZakerThemeStyle.values) {
    testWidgets('no overflow in ${style.id} at 320 dp and 2.0x text', (
      tester,
    ) async {
      await _pumpAt(tester, width: 320, textScale: 2, style: style);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the top bar is the formula height at 800 dp', (tester) async {
    await _pumpAt(tester);
    expect(
      tester.getSize(find.byKey(const Key('home-top-bar'))).height,
      closeTo(homeTopBarHeightFor(800), 1e-9),
    );
  });

  testWidgets('the old prayer block and the Islamic hub card are gone', (
    tester,
  ) async {
    await _pumpAt(tester);
    expect(find.text('الصلاة القادمة'), findsNothing);
    expect(find.text('الأذان'), findsNothing);
    expect(find.text('الإسلاميات'), findsNothing);
    expect(find.byKey(const Key('home-prayer-pill')), findsOneWidget);
  });

  testWidgets('the bag preview stops at six folders', (tester) async {
    await _pumpAt(tester);
    expect(find.text('مادة 6'), findsOneWidget);
    expect(find.text('مادة 7'), findsNothing);
    expect(find.text('افتح الشنطة'), findsOneWidget);
  });

  testWidgets('the all-tools grid is still reachable by scrolling', (
    tester,
  ) async {
    await _pumpAt(tester);
    // Drag the keyed body, not `find.byType(Scrollable).first`: the search
    // field owns a scrollable of its own.
    await tester.dragUntilVisible(
      find.text('كل الأدوات'),
      find.byKey(const Key('home-body')),
      const Offset(0, -400),
    );
    expect(find.text('كل الأدوات'), findsOneWidget);
  });
}
