import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/router.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/widgets/prayer_pill.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';
import 'package:zaker_ai/providers/app_providers.dart';

class _OnboardedSettings extends PrayerSettingsController {
  _OnboardedSettings() : super(LocalStore.memory()) {
    state = const PrayerSettings(onboarded: true);
  }
}

void main() {
  testWidgets('the pill opens /islam', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: PrayerPill()),
        ),
        GoRoute(
          path: ZakerRoutes.islamicHub,
          builder: (context, state) => const Scaffold(body: Text('islam')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          prayerSettingsProvider.overrideWith((ref) => _OnboardedSettings()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ZakerTheme.light(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('home-prayer-pill')));
    await tester.pumpAndSettle();
    expect(find.text('islam'), findsOneWidget);
  });

  testWidgets('the first-run sheet appears once and is remembered', (
    tester,
  ) async {
    final store = LocalStore.memory();
    Widget app() => ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            prayerSettingsProvider.overrideWith(
              (ref) => PrayerSettingsController(store),
            ),
          ],
          child: MaterialApp(
            theme: ZakerTheme.light(),
            home: const Scaffold(body: PrayerPill()),
          ),
        );

    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('مواقيت الصلاة في جيبك'), findsOneWidget);

    await tester.tap(find.text('بعدين'));
    await tester.pumpAndSettle();
    expect(find.text('مواقيت الصلاة في جيبك'), findsNothing);
    expect(store.getBool('prayer_onboarded'), isTrue);

    // A fresh mount over the same store must stay quiet.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('مواقيت الصلاة في جيبك'), findsNothing);
  });
}
