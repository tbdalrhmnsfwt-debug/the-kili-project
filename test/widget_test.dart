import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/brand/rafiq_brand.dart';
import '../lib/core/theme.dart';

void main() {
  testWidgets('renders the Arabic UI right-to-left in the brand theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ZakerTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Text(RafiqBrand.appName)),
        ),
      ),
    );

    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text(RafiqBrand.appName)))
          .colorScheme
          .primary,
      ZakerColors.primary,
    );
  });
}
