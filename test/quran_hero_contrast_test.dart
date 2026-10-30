import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/strings.dart' show ZakerStrings;
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/quran/quran_home_screen.dart';

/// The six entry points rendered by [QuranHomeScreen].
const _titles = [
  ZakerStrings.s_c2dba,
  ZakerStrings.s_265c6,
  ZakerStrings.s_f9f8b,
  ZakerStrings.s_be531,
  ZakerStrings.s_5e8f1,
  ZakerStrings.s_7b273,
];

void main() {
  for (final style in ZakerThemeStyle.values) {
    testWidgets('Quran entry titles stay readable (${style.id})', (
      tester,
    ) async {
      final theme = ZakerTheme.forStyle(style);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: theme, home: const QuranHomeScreen()),
        ),
      );

      for (final title in _titles) {
        final finder = find.text(title);
        expect(finder, findsOneWidget, reason: title);
        final color = tester.widget<Text>(finder).style?.color;
        expect(color, isNotNull, reason: '$title colour');

        // The tinted card paints over the scaffold; composite the two before
        // measuring contrast.
        final card = tester.widget<Container>(
          find.ancestor(of: finder, matching: find.byType(Container)).first,
        );
        final decoration = card.decoration! as BoxDecoration;
        final background = Color.alphaBlend(
          decoration.color!,
          theme.scaffoldBackgroundColor,
        );
        expect(
          contrastRatio(color!, background),
          greaterThanOrEqualTo(4.5),
          reason: '$title on ${style.id}',
        );
      }
    });
  }
}
