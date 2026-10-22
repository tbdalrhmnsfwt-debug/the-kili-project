/// Zakerly — ذاكرلي
///
/// A Flutter study companion for Egyptian students: the "manhaji" textbook
/// library, exams and question banks, Quran and adhkar tools, a focus timer
/// and an on-device AI teacher.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/local_store.dart';
import 'core/localization.dart';
import 'core/notification_service.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.open();
  // Tapping a reminder opens the task list.
  NotificationService.instance.onTap = (payload) {
    if (payload == 'tasks') appRouter.go(ZakerRoutes.tasks);
  };
  // Register the notification channel early so an already-scheduled reminder
  // can be shown right after a reboot, before the first frame.
  await NotificationService.instance.init();
  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const ZakerlyApp(),
    ),
  );
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

    return MaterialApp.router(
      onGenerateTitle: (context) =>
          Localizations.of<AppLocalizations>(context, AppLocalizations)
              ?.t('ذاكرلي') ??
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
        return Directionality(
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
