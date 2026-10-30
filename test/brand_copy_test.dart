import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/localization.dart';

void main() {
  test('brand strings are fixed', () {
    expect(RafiqBrand.appName, 'رفيق الطالب');
    expect(RafiqBrand.developer, 'عبد الرحمن صفوت عطا');
    expect(RafiqBrand.studio, 'عبد الرحمن صفوت عطا');
    expect(RafiqBrand.credit, 'من تطوير: عبد الرحمن صفوت عطا');
    expect(RafiqBrand.copyright, 'المطور عبد الرحمن صفوت عطا');
  });

  test('the old studio suffix is gone from the shipped source', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('سوفت')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('brand strings have English entries', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final localizations = await AppLocalizations.load(const Locale('en'));
    expect(localizations.t('رفيق الطالب'), 'Rafiq Al-Talib');
    expect(localizations.t('عبد الرحمن صفوت عطا'), 'Abdurrahman Safwat Atta');
    expect(
      localizations.t('من تطوير: عبد الرحمن صفوت عطا'),
      'Developed by: Abdurrahman Safwat Atta',
    );
    expect(
      localizations.t('المطور عبد الرحمن صفوت عطا'),
      'Developer: Abdurrahman Safwat Atta',
    );
  });

  test('the window title and the app name are the new brand', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('RafiqBrand.appName'));
    expect(main, isNot(contains("t('ذاكرلي')")));
  });

  test('the old app name survives only on the legacy layout labels', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('appearance.dart')) continue;
      if (entity.readAsStringSync().contains('ذاكرلي')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
