import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/router.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/my_bag_screen.dart';
import 'package:zaker_ai/features/home/shell_screen.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';
import 'package:zaker_ai/providers/app_providers.dart';

class _OnboardedSettings extends PrayerSettingsController {
  _OnboardedSettings() : super(LocalStore.memory()) {
    state = const PrayerSettings(onboarded: true);
  }
}

void main() {
  testWidgets('a /bag deep link opens the shell on the bag tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    appRouter.go(ZakerRoutes.bag);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          authUserProvider.overrideWith(
            (ref) => const AuthUser(uid: 'u1', displayName: 'طالب'),
          ),
          prayerSettingsProvider.overrideWith((ref) => _OnboardedSettings()),
        ],
        child: MaterialApp.router(
          routerConfig: appRouter,
          theme: ZakerTheme.light(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MyBagScreen), findsWidgets);
    expect(
      tester.widget<ShellBottomNav>(find.byType(ShellBottomNav)).selected,
      1,
    );

    // The deep link is not a dead end: the first tab is one tap away.
    await tester.tap(find.text('الرئيسية'));
    await tester.pump();
    expect(
      tester.widget<ShellBottomNav>(find.byType(ShellBottomNav)).selected,
      0,
    );
  });
}
