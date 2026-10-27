import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/brand/rafiq_mark.dart';
import 'package:zaker_ai/core/brand/rafiq_splash_gate.dart';

Widget _app({bool disabled = false}) => MaterialApp(
      home: RafiqSplashGate(
        animationsDisabled: disabled,
        child: const Scaffold(body: Text('home')),
      ),
    );

void main() {
  testWidgets('shows the mark, name and credit, then gets out of the way', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    expect(find.byKey(const Key('rafiq-splash')), findsOneWidget);
    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(find.text(RafiqBrand.credit), findsOneWidget);
    expect(find.byType(RafiqMark), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byKey(const Key('rafiq-splash')), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the overlay is opaque on the very first frame', (tester) async {
    await tester.pumpWidget(_app());
    final overlay = tester.widget<AnimatedOpacity>(
      find.byKey(const Key('rafiq-splash')),
    );
    expect(overlay.opacity, 1);
    // Drain the gate's timers so none outlive the widget tree.
    await tester.pump(const Duration(milliseconds: 1600));
  });

  testWidgets('reduced motion finishes fast and never animates forever', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disabled: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('rafiq-splash')), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('does not replay on rebuild', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpWidget(_app());
    expect(find.byKey(const Key('rafiq-splash')), findsNothing);
  });

  testWidgets('the mark paints at every used size', (tester) async {
    for (final size in [22.0, 72.0, 180.0]) {
      await tester.pumpWidget(
        MaterialApp(home: Center(child: RafiqMark(size: size))),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
