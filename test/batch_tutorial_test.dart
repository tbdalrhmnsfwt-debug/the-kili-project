import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/tutorial/batch_tutorial_overlay.dart';
import 'package:zaker_ai/features/batches/tutorial/batch_tutorial_progress.dart';
import 'package:zaker_ai/features/batches/tutorial/batch_tutorial_steps.dart';
import 'package:zaker_ai/providers/app_providers.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  const uid = 'guest-tour';
  final key = 'batches.tutorial.v1.$uid';

  group('controller', () {
    test('a tour resumes at its saved step for the same account', () {
      final store = _MemoryStore();
      final first = BatchTutorialController(store, uid)
        ..begin(
          BatchTutorialMode.full,
          step: 4,
          batchId: 'batch-1',
        );
      first.next();
      expect(first.state.step, 5);
      first.dispose();

      final second = BatchTutorialController(store, uid);
      expect(second.state.mode, BatchTutorialMode.full);
      expect(second.state.step, 5);
      expect(second.state.batchId, 'batch-1');
      expect(second.state.completed, isFalse);
      second.dispose();
    });

    test('the last getting-started step finishes the tour', () {
      final store = _MemoryStore();
      final controller = BatchTutorialController(store, uid)
        ..begin(BatchTutorialMode.gettingStarted, step: 7);
      controller.next();
      expect(controller.state.step, gettingStartedStepCount);
      expect(controller.state.completed, isTrue);

      final restored = BatchTutorialController(store, uid);
      expect(restored.state.completed, isTrue);
      expect(restored.state.step, gettingStartedStepCount);
      controller.dispose();
      restored.dispose();
    });

    test('begin restarts a finished tour from the requested step', () {
      final controller = BatchTutorialController(_MemoryStore(), uid)
        ..begin(BatchTutorialMode.full, step: 99);
      expect(controller.state.step, fullTutorialSteps.length);
      controller.finish();
      expect(controller.state.completed, isTrue);

      controller.begin(BatchTutorialMode.full);
      expect(controller.state.step, 1);
      expect(controller.state.completed, isFalse);
      controller.dispose();
    });

    test('back stops at the first step', () {
      final controller = BatchTutorialController(_MemoryStore(), uid)
        ..begin(BatchTutorialMode.full);
      controller.back();
      expect(controller.state.step, 1);
      controller.dispose();
    });

    test('a corrupt marker starts a fresh tour', () {
      final store = _MemoryStore()..values[key] = '{bad json';
      final controller = BatchTutorialController(store, uid);
      expect(controller.state.isStarted, isFalse);
      controller.dispose();
    });

    test('an empty account keeps the tour in memory only', () {
      final store = _MemoryStore();
      final controller = BatchTutorialController(store, '')
        ..begin(BatchTutorialMode.full);
      expect(controller.state.isStarted, isTrue);
      expect(store.values, isEmpty);
      controller.dispose();
    });
  });

  group('overlay', () {
    Widget host({
      required BatchTutorialMode mode,
      String batchId = '',
      int? startStep,
      bool disableAnimations = false,
      bool largeText = false,
    }) {
      return ProviderScope(
        overrides: [
          authUserProvider.overrideWith(
            (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
          ),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: disableAnimations,
                textScaler: largeText
                    ? const TextScaler.linear(1.5)
                    : MediaQuery.of(context).textScaler,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showBatchTutorial(
                    context,
                    mode: mode,
                    batchId: batchId,
                    startStep: startStep,
                  ),
                  child: const Text('افتح الجولة'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('getting started walks forward, back and closes',
        (tester) async {
      await tester.pumpWidget(host(mode: BatchTutorialMode.gettingStarted));
      await tester.tap(find.text('افتح الجولة'));
      await tester.pumpAndSettle();

      expect(find.text('تبويب الدفعات'), findsOneWidget);
      expect(find.textContaining('البداية السريعة'), findsOneWidget);
      expect(find.textContaining('خطوة ١ من ٧'), findsOneWidget);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('إنشاء دفعة'), findsOneWidget);
      expect(find.textContaining('خطوة ٢ من ٧'), findsOneWidget);

      await tester.tap(find.text('السابق'));
      await tester.pumpAndSettle();
      expect(find.text('تبويب الدفعات'), findsOneWidget);

      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();
      expect(find.text('تبويب الدفعات'), findsNothing);
      expect(find.text('افتح الجولة'), findsOneWidget);
    });

    testWidgets('the full tour ends on the administration step',
        (tester) async {
      await tester.pumpWidget(
        host(
          mode: BatchTutorialMode.full,
          batchId: 'batch-1',
          startStep: 13,
        ),
      );
      await tester.tap(find.text('افتح الجولة'));
      await tester.pumpAndSettle();

      expect(find.text('الإدارة والمساعدة'), findsOneWidget);
      expect(find.textContaining('الجولة الكاملة'), findsOneWidget);
      expect(find.textContaining('خطوة ١٣ من ١٣'), findsOneWidget);
      expect(find.text('خلصت الجولة'), findsOneWidget);

      await tester.tap(find.text('خلصت الجولة'));
      await tester.pumpAndSettle();
      expect(find.text('الإدارة والمساعدة'), findsNothing);
    });

    testWidgets('a batch-less step 8 explains how to continue', (tester) async {
      await tester.pumpWidget(
        host(mode: BatchTutorialMode.full, startStep: 8),
      );
      await tester.tap(find.text('افتح الجولة'));
      await tester.pumpAndSettle();

      expect(find.text('هيدر الدفعة'), findsOneWidget);
      expect(find.textContaining('الخطوات من ٨ محتاجة دفعة'), findsOneWidget);
      expect(find.text('اعمل دفعة'), findsOneWidget);
      expect(find.text('افتح الدفعة'), findsNothing);
    });

    testWidgets('a step with a batch offers its real screen', (tester) async {
      await tester.pumpWidget(
        host(
          mode: BatchTutorialMode.full,
          batchId: 'batch-1',
          startStep: 9,
        ),
      );
      await tester.tap(find.text('افتح الجولة'));
      await tester.pumpAndSettle();

      expect(find.text('المواد'), findsOneWidget);
      expect(find.text('افتح المواد'), findsOneWidget);
      expect(find.textContaining('الخطوات من ٨ محتاجة دفعة'), findsNothing);
    });

    testWidgets('the card renders with reduced motion and large text',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        host(
          mode: BatchTutorialMode.gettingStarted,
          disableAnimations: true,
          largeText: true,
        ),
      );
      await tester.tap(find.text('افتح الجولة'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('تبويب الدفعات'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
    });
  });
}
