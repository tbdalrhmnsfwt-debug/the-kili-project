import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/widgets/common.dart';

void main() {
  for (final style in ZakerThemeStyle.values) {
    testWidgets(
        'FeatureTile uses the 16 dp card and the soft shadow (${style.id})', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZakerTheme.forStyle(style),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: FeatureTile(title: 'أداة', icon: Icons.calculate),
            ),
          ),
        ),
      );

      final inner = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(inner.borderRadius, ZakerRadius.card);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(FeatureTile),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, ZakerRadius.card);
      expect(decoration.boxShadow, ZakerShadows.card);
    });
  }
}
