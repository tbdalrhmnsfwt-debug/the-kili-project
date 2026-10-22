/// Zakerly — ذاكرلي
///
/// A Flutter study companion for Egyptian students: the "manhaji" textbook
/// library, exams and question banks, Quran and adhkar tools, a focus timer
/// and an on-device AI teacher.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ZakerlyApp()));
}

/// Root widget.
class ZakerlyApp extends StatelessWidget {
  const ZakerlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ذاكرلي',
      debugShowCheckedModeBanner: false,
      theme: ZakerTheme.light(),
      darkTheme: ZakerTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      locale: const Locale('ar'),
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
