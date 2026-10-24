/// Zakerly — ذاكرلي
///
/// A Flutter study companion for Egyptian students: the "manhaji" textbook
/// library, exams and question banks, Quran and adhkar tools, a focus timer
/// and an on-device AI teacher.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;

import 'core/adhan_voices.dart';
import 'core/local_store.dart';
import 'core/localization.dart';
import 'core/notification_service.dart';
import 'core/router.dart';
import 'core/shad_theme.dart';
import 'core/theme.dart';
import 'features/prayer/adhan_launch.dart';
import 'features/prayer/adhan_sync_host.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Detect any user-added `assets/adhan/egyptian_*.mp3` recording before the
  // first frame, so the picker and the persisted voice ids agree from the
  // start.
  await AdhanVoiceCatalog.instance.load();
  final store = await LocalStore.open();
  // Tapping a reminder opens its screen; tapping an adhan opens the
  // full-screen player.
  NotificationService.instance.onTap = handleNotificationPayload;
  // Register the notification channel early so an already-scheduled reminder
  // can be shown right after a reboot, before the first frame.
  await NotificationService.instance.init();
  // A locked phone launches the app from the adhan's full-screen intent; the
  // payload has to be read before the router is built.
  final launchPayload = await NotificationService.instance.launchPayload();
  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const ZakerlyApp(),
    ),
  );
  if (launchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handleNotificationPayload(launchPayload);
    });
  }
}

/// Root widget.
class ZakerlyApp extends ConsumerWidget {
  const ZakerlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the persistence listeners alive for the whole app session, and
    // restore the account (or the local guest identity) on first build.
    ref.watch(persistenceProvider);
    ref.watch(authBootstrapProvider);

    // The adhan host lives above the router: it reschedules the rolling
    // notification window on start, resume, midnight and settings changes.
    return AdhanSyncHost(
      child: MaterialApp.router(
        onGenerateTitle: (context) =>
            Localizations.of<AppLocalizations>(
              context,
              AppLocalizations,
            )?.t('ذاكرلي') ??
            'ذاكرلي',
        debugShowCheckedModeBanner: false,
        theme: ZakerTheme.light(),
        darkTheme: ZakerTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        locale: ref.watch(localeProvider),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          // The app is Arabic-first: force RTL for the Arabic locale.
          final locale = Localizations.localeOf(context);
          // shadcn_ui components read their colours and typography from a
          // ShadTheme; provide one that mirrors the active Material theme.
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Directionality(
            textDirection: locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: ShadTheme(
              data: isDark ? ZakerShadTheme.dark() : ZakerShadTheme.light(),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
