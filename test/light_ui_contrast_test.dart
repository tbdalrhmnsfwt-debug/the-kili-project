import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/widgets/common.dart';

/// Colour of [text] once its own alpha is composited over [backdrop].
Color _effective(Text text, Color backdrop) =>
    Color.alphaBlend(text.style!.color!, backdrop);

/// Every text in [labels] must reach 4.5:1 against [backdrop].
void _expectReadable(
    WidgetTester tester, List<String> labels, Color backdrop, String where) {
  for (final label in labels) {
    final text = tester.widget<Text>(find.text(label));
    expect(text.style?.color, isNotNull, reason: '$label colour');
    expect(
      contrastRatio(_effective(text, backdrop), backdrop),
      greaterThanOrEqualTo(4.5),
      reason: '$label on $where',
    );
  }
}

Widget _host(ThemeData theme, Widget child, Color backdrop) => MaterialApp(
      theme: theme,
      home: Scaffold(
        backgroundColor: backdrop,
        body: Center(child: child),
      ),
    );

void main() {
  for (final style in ZakerThemeStyle.values) {
    testWidgets(
        'StatChip keeps its text readable on a navy banner '
        '(${style.id})', (tester) async {
      await tester.pumpWidget(
        _host(
          ZakerTheme.forStyle(style),
          const StatChip(
            value: '42',
            label: 'نقاطك',
            icon: Icons.stars_rounded,
            color: Colors.white,
          ),
          ZakerColors.navy,
        ),
      );

      // The chip paints an accent tint over the banner behind it.
      final chip = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.10),
        ZakerColors.navy,
      );
      _expectReadable(
          tester, const ['42', 'نقاطك'], chip, 'banner ${style.id}');
    });

    testWidgets(
        'StatChip keeps gold and green text readable on the card '
        '(${style.id})', (tester) async {
      final theme = ZakerTheme.forStyle(style);
      final card = cardSurfaceOf(theme);

      for (final accent in <String, Color>{
        'gold': ZakerColors.accent,
        'green': ZakerColors.success,
      }.entries) {
        await tester.pumpWidget(
          _host(
            theme,
            StatChip(value: '7', label: 'مهمة', color: accent.value),
            card,
          ),
        );
        final chip = Color.alphaBlend(
          accent.value.withValues(alpha: 0.10),
          card,
        );
        _expectReadable(
          tester,
          const ['7', 'مهمة'],
          chip,
          '${accent.key} card ${style.id}',
        );
      }
    });
  }
}
