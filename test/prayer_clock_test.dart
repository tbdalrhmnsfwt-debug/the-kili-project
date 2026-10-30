import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';

void main() {
  testWidgets('the clock stops its timer when its provider is disposed', (
    tester,
  ) async {
    final seen = <DateTime>[];
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final clock = ref.watch(prayerClockProvider);
            if (clock.hasValue) seen.add(clock.requireValue);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    expect(seen, isNotEmpty);

    // Disposing the auto-dispose provider must cancel the one-second timer.
    // A timer that outlives the tree is reported by the test framework as a
    // failure once this body returns, so simply unmounting is the assertion.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
