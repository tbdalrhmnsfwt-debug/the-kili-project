import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/router.dart';
import 'package:zaker_ai/core/shad_theme.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/my_bag_screen.dart';
import 'package:zaker_ai/features/home/shell_screen.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/my_bag_providers.dart';

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
    // The bag tab now owns real folders, so its store needs a root.
    final bagRoot = Directory.systemTemp.createTempSync('zaker_shell_bag_');
    addTearDown(() => bagRoot.deleteSync(recursive: true));

    appRouter.go(ZakerRoutes.bag);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(LocalStore.memory()),
          myBagRootDirProvider.overrideWithValue(bagRoot),
          authUserProvider.overrideWith(
            (ref) => const AuthUser(uid: 'u1', displayName: 'طالب'),
          ),
          prayerSettingsProvider.overrideWith((ref) => _OnboardedSettings()),
        ],
        child: MaterialApp.router(
          routerConfig: appRouter,
          theme: ZakerTheme.light(),
          // The shell's IndexedStack builds the home tab too, and its search
          // field reads shadcn_ui's theme; the real app supplies one.
          builder: (context, child) => ShadTheme(
            data: ZakerShadTheme.forStyle(ZakerThemeStyle.light),
            child: child ?? const SizedBox.shrink(),
          ),
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
