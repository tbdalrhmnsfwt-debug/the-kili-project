import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';

void main() {
  test('every appearance exposes the feature accents', () {
    for (final style in ZakerThemeStyle.values) {
      expect(
        ZakerTheme.forStyle(style).extension<ZakerFeatureAccents>(),
        isNotNull,
        reason: style.id,
      );
    }
  });

  test('a bare theme falls back to the light accents', () {
    final fallback = featureAccentsOf(ThemeData.light());
    final light = ZakerTheme.light().extension<ZakerFeatureAccents>()!;
    expect(fallback.assistant, light.assistant);
  });

  test('the home uses its own navy-glass palette, not the old rainbow', () {
    final source =
        File('lib/features/home/home_screen.dart').readAsStringSync();
    expect(source.contains('_Accents.'), isFalse);
    for (final old in const [
      '_Accents.',
      '_subjectAccents.',
      '0xFF7C3AED',
      '0xFF2563EB',
      '0xFFD97706',
      '0xFFE11D48',
      '0xFF0284C7',
      '0xFF059669',
    ]) {
      expect(source.contains(old), isFalse, reason: old);
    }
    expect(source.contains('HomePalette'), isTrue);
  });
}
