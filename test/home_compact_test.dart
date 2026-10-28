import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/shad_theme.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/home_screen.dart';
import 'package:zaker_ai/features/home/widgets/home_top_bar.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';
import 'package:zaker_ai/models/schedule.dart';
import 'package:zaker_ai/providers/app_providers.dart';

/// The real controller reports the first run only through its stored state, so
/// the test seeds the flag by subclassing instead of writing a file.
class _OnboardedSettings extends PrayerSettingsController {
  _OnboardedSettings() : super(LocalStore.memory()) {
    state = const PrayerSettings(onboarded: true);
  }
}

Widget _app({
  ZakerThemeStyle style = ZakerThemeStyle.light,
  double textScale = 1,
  List<ScheduleEntry>? tasks,
}) =>
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore.memory()),
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: 'u1', displayName: 'طالب'),
        ),
        prayerSettingsProvider.overrideWith((ref) => _OnboardedSettings()),
        if (tasks != null)
          taskScheduleProvider.overrideWith(
            (ref) => TaskSchedule(title: 'قائمة المهام', entries: tasks),
          ),
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
  List<ScheduleEntry>? tasks,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _app(textScale: textScale, style: style, tasks: tasks),
  );
  await tester.pump();
}

void main() {
  // 1024 exercises the side-by-side banner and the four-column tools grid.
  for (final width in [320.0, 360.0, 411.0, 800.0, 1024.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('no overflow at $width dp and ${scale}x text',
          (tester) async {
        await _pumpAt(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('اسأل معلم AI عن أي حاجة…'), findsOneWidget);

        // The list lays out only what fits in the viewport plus its cache
        // extent, so the first screen cannot vouch for the daily tools or the
        // tools section. Drag the keyed body to the bottom and check again.
        await tester.dragUntilVisible(
          find.text('قسم الأدوات'),
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
      await tester.dragUntilVisible(
        find.text('قسم الأدوات'),
        find.byKey(const Key('home-body')),
        const Offset(0, -400),
      );
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

  testWidgets('the navy header holds the live prayer badge in its top strip', (
    tester,
  ) async {
    await _pumpAt(tester);
    expect(find.byKey(const Key('home-header')), findsOneWidget);
    expect(find.byKey(const Key('home-prayer-pill')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeTopBar),
        matching: find.byKey(const Key('home-prayer-badge')),
      ),
      findsOneWidget,
    );

    final header = tester.widget<Container>(
      find.byKey(const Key('home-header')),
    );
    final gradient = (header.decoration! as BoxDecoration).gradient!;
    expect(
      (gradient as LinearGradient).colors,
      const [ZakerColors.navy, ZakerColors.navyLight],
    );
  });

  testWidgets('the three primary actions sit side by side in pastels', (
    tester,
  ) async {
    await _pumpAt(tester, width: 400);
    final assistant = find.byKey(const Key('home-card-assistant'));
    final bag = find.byKey(const Key('home-card-bag'));
    final tasks = find.byKey(const Key('home-card-tasks'));
    for (final card in [assistant, bag, tasks]) {
      expect(card, findsOneWidget);
    }

    // RTL: the first card is the rightmost one, and all three share a row.
    final a = tester.getCenter(assistant);
    final b = tester.getCenter(bag);
    final c = tester.getCenter(tasks);
    expect(a.dy, closeTo(b.dy, 1));
    expect(b.dy, closeTo(c.dy, 1));
    expect(a.dx, greaterThan(b.dx));
    expect(b.dx, greaterThan(c.dx));

    expect(find.text('المساعد الذكي'), findsOneWidget);
    expect(find.text('ملفاتي بالمادة'), findsOneWidget);
    expect(find.text('مهامي'), findsOneWidget);

    const gradients = {
      'home-card-assistant': [Color(0xFFF0EBFF), Color(0xFFE5DBFF)],
      'home-card-bag': [Color(0xFFE8F9F1), Color(0xFFD1F4E2)],
      'home-card-tasks': [Color(0xFFEBF5FF), Color(0xFFD6EAFF)],
    };
    for (final entry in gradients.entries) {
      final card = tester.widget<Container>(find.byKey(Key(entry.key)));
      final gradient =
          (card.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, entry.value, reason: entry.key);
    }
  });

  testWidgets('the old bag and library cards are gone from the body', (
    tester,
  ) async {
    await _pumpAt(tester);
    expect(find.byKey(const Key('home-bag-preview')), findsNothing);
    expect(find.byKey(const Key('home-library-shortcut')), findsNothing);
  });

  testWidgets('the study library lives inside the tools section', (
    tester,
  ) async {
    await _pumpAt(tester);
    // Drag the keyed body, not `find.byType(Scrollable).first`: the search
    // field owns a scrollable of its own.
    await tester.dragUntilVisible(
      find.text('المكتبة الدراسية'),
      find.byKey(const Key('home-body')),
      const Offset(0, -400),
    );
    expect(find.text('قسم الأدوات'), findsOneWidget);
    expect(find.text('المكتبة الدراسية'), findsOneWidget);
    expect(find.byKey(const Key('home-library-shortcut')), findsNothing);
  });

  testWidgets('the notifications sheet scrolls at 320 dp and 2.0x text', (
    tester,
  ) async {
    final now = DateTime.now();
    final tasks = [
      for (var i = 0; i < 5; i++)
        ScheduleEntry(
          id: 'task-$i',
          title: 'مهمة رقم $i',
          dueAt: DateTime(now.year, now.month, now.day, 18, i),
        ),
    ];
    await _pumpAt(
      tester,
      width: 320,
      height: 600,
      textScale: 2,
      tasks: tasks,
    );

    await tester.tap(find.byKey(const Key('home-top-bar-bell')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    final sheet = find.byKey(const Key('notifications-sheet-scroll'));
    expect(sheet, findsOneWidget);
    await tester.dragUntilVisible(
      find.text('افتح أهداف اليوم'),
      sheet,
      const Offset(0, -200),
    );
    expect(tester.takeException(), isNull);
  });
}
