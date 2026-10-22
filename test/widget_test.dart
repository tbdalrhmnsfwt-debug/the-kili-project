import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
          child: Scaffold(body: Text('ذاكرلي')),
        ),
      ),
    );

    expect(find.text('ذاكرلي'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('ذاكرلي'))).colorScheme.primary,
      ZakerColors.primary,
    );
  });
}
