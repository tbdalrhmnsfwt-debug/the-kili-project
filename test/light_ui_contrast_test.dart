import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zaker_ai/core/curriculum.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/prayer/qibla_compass.dart';
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

  for (final style in ZakerThemeStyle.values) {
    for (final aligned in const [false, true]) {
      testWidgets(
          'the qibla disc keeps its icon and ring visible on every stop '
          '(${style.id}, aligned: $aligned)', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ZakerTheme.forStyle(style),
            home: Scaffold(
              body: Center(
                child: SizedBox.square(
                  dimension: 320,
                  child: QiblaCompassDial(
                    qiblaBearing: 120,
                    heading: null,
                    aligned: aligned,
                  ),
                ),
              ),
            ),
          ),
        );

        final icon = tester.widget<HugeIcon>(find.byType(HugeIcon));
        // The disc is the Container that paints the icon; measure its real
        // gradient and ring rather than a copy of what the code should build.
        final disc = tester.widget<Container>(
          find
              .ancestor(
                of: find.byType(HugeIcon),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = disc.decoration! as BoxDecoration;
        final ring = (decoration.border! as Border).top.color;
        for (final stop in (decoration.gradient! as LinearGradient).colors) {
          expect(
            contrastRatio(icon.color!, stop),
            greaterThanOrEqualTo(3),
            reason: 'kaaba icon on $stop (${style.id}, aligned: $aligned)',
          );
          expect(
            contrastRatio(Color.alphaBlend(ring, stop), stop),
            greaterThanOrEqualTo(3),
            reason: 'disc ring on $stop (${style.id}, aligned: $aligned)',
          );
        }
      });
    }
  }

  test('white copy is kept only where it is readable', () {
    for (final background in <Color>[
      ZakerColors.navy,
      ZakerColors.gold,
      const Color(0xFF7BC47F),
      const Color(0xFF64B5F6),
    ]) {
      expect(
        contrastRatio(readableTextColor(Colors.white, background), background),
        greaterThanOrEqualTo(4.5),
        reason: 'white copy on $background',
      );
    }
  });

  test('every subject hero carries its white copy on both stops', () {
    for (final grade in curriculumGrades.values) {
      for (final subject in grade.subjects) {
        // The hero gradients from the base colour to 70% of it.
        final base = heroBaseOf(subject.color);
        final deep = Color.lerp(base, Colors.black, 0.30)!;
        for (final stop in <Color>[base, deep]) {
          expect(
            contrastRatio(Colors.white, stop),
            greaterThanOrEqualTo(4.5),
            reason: '${subject.id} title on $stop',
          );
          final soft = Color.alphaBlend(
            Colors.white.withValues(alpha: 0.85),
            stop,
          );
          expect(
            contrastRatio(soft, stop),
            greaterThanOrEqualTo(4.5),
            reason: '${subject.id} subtitle on $stop',
          );
        }
      }
    }
  });

  test('every brand accent clears 4.5:1 on its own tint', () {
    const accents = <String, Color>{
      'gold': ZakerColors.accent,
      'green': ZakerColors.success,
      'red': ZakerColors.danger,
    };
    for (final style in ZakerThemeStyle.values) {
      final theme = ZakerTheme.forStyle(style);
      final card = cardSurfaceOf(theme);
      for (final accent in accents.entries) {
        for (final alpha in const [0.11, 0.12, 0.14, 0.15, 0.16]) {
          final tint =
              Color.alphaBlend(accent.value.withValues(alpha: alpha), card);
          final ink = cardAccentOnTintOf(accent.value, theme, alpha: alpha);
          expect(
            contrastRatio(ink, tint),
            greaterThanOrEqualTo(4.5),
            reason: '${accent.key} @$alpha on ${style.id}',
          );
        }
      }
    }
  });
}
