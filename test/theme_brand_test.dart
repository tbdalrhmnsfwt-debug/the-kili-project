import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';

void main() {
  test('brand tokens carry the specified values', () {
    expect(ZakerColors.navy, const Color(0xFF121E36));
    expect(ZakerColors.navyDeep, const Color(0xFF0B1426));
    expect(ZakerColors.navyLight, const Color(0xFF1B2B4A));
    expect(ZakerColors.gold, const Color(0xFFD4AF37));
    expect(ZakerColors.goldLight, const Color(0xFFE5C158));
    expect(ZakerColors.goldDeep, const Color(0xFF8A6A12));
    expect(ZakerColors.page, const Color(0xFFF8F9FB));
    expect(ZakerColors.ink, const Color(0xFF121E36));
    expect(ZakerColors.muted, const Color(0xFF5B6678));
    expect(ZakerColors.border, const Color(0xFFE6E9F0));
    expect(ZakerColors.backpack, const Color(0xFFD32F2F));
    expect(ZakerColors.primary, ZakerColors.navy);
    expect(ZakerColors.primaryLight, ZakerColors.navyLight);
    expect(ZakerColors.primaryDark, ZakerColors.navyDeep);
  });

  test('cards are 16 dp with the soft brand shadow', () {
    expect(ZakerRadius.cardValue, 16);
    expect(ZakerRadius.card, const BorderRadius.all(Radius.circular(16)));
    expect(ZakerRadius.md, 14);
    final shadow = ZakerShadows.card.single;
    expect(shadow.color, const Color(0x14203A5C));
    expect(shadow.blurRadius, 10);
    expect(shadow.offset, const Offset(0, 4));
  });

  test('the text pairs the design uses meet 4.5:1', () {
    expect(
      contrastRatio(Colors.white, ZakerColors.navy),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(ZakerColors.goldLight, ZakerColors.navy),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(ZakerColors.goldDeep, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(Colors.white, ZakerColors.backpack),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(ZakerColors.navy, ZakerColors.goldLight),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(ZakerColors.ink, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(ZakerColors.muted, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('plain gold is never a small-text colour on white', () {
    expect(contrastRatio(ZakerColors.gold, Colors.white), lessThan(4.5));
  });

  test('the four appearances keep their ids and on-primary contrast', () {
    expect(ZakerThemeStyle.values.map((s) => s.id).toList(), [
      'light',
      'dark',
      'black_gold',
      'deep_blue',
    ]);
    for (final style in ZakerThemeStyle.values) {
      final palette = ZakerTheme.paletteFor(style);
      expect(
        contrastRatio(palette.onPrimary, palette.primary),
        greaterThanOrEqualTo(4.5),
        reason: '${style.id} primary fill text',
      );
      expect(
        contrastRatio(palette.onSurface, palette.card),
        greaterThanOrEqualTo(4.5),
        reason: '${style.id} card text',
      );
      for (final accent in _accentValues(palette.accents)) {
        expect(
          contrastRatio(accent, palette.card),
          greaterThanOrEqualTo(4.5),
          reason: '${style.id} feature accent $accent on card',
        );
      }
    }
    expect(
      ZakerTheme.paletteFor(ZakerThemeStyle.light).primary,
      ZakerColors.navy,
    );
    expect(
      ZakerTheme.paletteFor(ZakerThemeStyle.dark).primary,
      ZakerColors.goldLight,
    );
    expect(
      ZakerTheme.paletteFor(ZakerThemeStyle.blackGold).primary,
      ZakerColors.gold,
    );
    expect(
      ZakerTheme.paletteFor(ZakerThemeStyle.deepBlue).primary,
      ZakerColors.goldLight,
    );
  });

  test('no legacy teal literal survives under lib/', () {
    const banned = [
      '0F766E',
      '14B8A6',
      '115E59',
      '0D9488',
      '134E4A',
      '0D4F4A',
      '0B4F49',
      '062F2B',
      '2DD4BF',
      '99F6E4',
      'CCFBF1',
      'F0FDFA',
      '9FE3D4',
      '5EEAD4',
    ];
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync().toUpperCase();
      for (final hex in banned) {
        if (text.contains(hex)) offenders.add('${entity.path}: $hex');
      }
    }
    expect(offenders, isEmpty);
  });
}

List<Color> _accentValues(ZakerFeatureAccents a) => [
      a.assistant,
      a.study,
      a.tasks,
      a.islamic,
      a.prayer,
      a.qibla,
      a.azkar,
      a.hifz,
    ];
