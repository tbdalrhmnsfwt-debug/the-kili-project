import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/local_batch_repository.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/batches/batches_screen.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/batch_providers.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _SequenceRandom implements Random {
  _SequenceRandom(this.values);

  final List<int> values;
  int _index = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    final value = values[_index % values.length];
    _index++;
    return value % max;
  }
}

void main() {
  const uid = 'guest-test';
  late Directory root;
  late BatchFileStore files;
  late _MemoryStore store;
  late LocalBatchRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_batches_ui_');
    files = BatchFileStore(root: root);
    store = _MemoryStore();
    repository = LocalBatchRepository(
      files: files,
      store: store,
      codes: BatchCodeService(random: _SequenceRandom([1])),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<Batch> createBatch() => repository.createBatch(
        uid: uid,
        displayName: 'طالب',
        name: 'دفعة تالتة ثانوي',
        subjects: const ['رياضيات', 'فيزياء'],
      );

  Widget app({double textScale = 1}) {
    return ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(LocalStore.memory()),
        batchRootDirProvider.overrideWithValue(root),
        authUserProvider.overrideWith(
          (ref) => const AuthUser(uid: uid, displayName: 'طالب'),
        ),
      ],
      child: MaterialApp(
        theme: ZakerTheme.light(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const BatchesScreen(),
      ),
    );
  }

  testWidgets('shows the honest empty state', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('مفيش دفعات على الجهاز'), findsOneWidget);
    expect(
      find.textContaining('الدفعات بتتحفظ على الجهاز ده لوحده'),
      findsOneWidget,
    );
  });

  testWidgets('lists a batch with its subjects and owner code', (tester) async {
    await createBatch();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('دفعة تالتة ثانوي'), findsOneWidget);
    expect(find.textContaining('2 مواد'), findsOneWidget);
    expect(find.textContaining('أنت بس على الجهاز'), findsOneWidget);
    expect(find.textContaining('كود الدخول: 00000001'), findsOneWidget);
    expect(find.byTooltip('حذف الدفعة'), findsOneWidget);
  });

  testWidgets('deletes after an explicit confirmation', (tester) async {
    final batch = await createBatch();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حذف الدفعة'));
    await tester.pumpAndSettle();
    expect(find.text('حذف الدفعة؟'), findsOneWidget);
    expect(find.textContaining('مفيش نسخة على سيرفر'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(find.text('مفيش دفعات على الجهاز'), findsOneWidget);
    expect(await files.batchDir(uid, batch.id).exists(), isFalse);
  });

  testWidgets('cancelling the dialog keeps the batch', (tester) async {
    await createBatch();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('حذف الدفعة'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('دفعة تالتة ثانوي'), findsOneWidget);
  });

  testWidgets('renders an unavailable batch with a delete path', (
    tester,
  ) async {
    final batch = await createBatch();
    final batchStore = BatchStore(directory: files.batchDir(uid, batch.id));
    await batchStore.batchFile.writeAsString('{broken');

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('دفعة مش متاحة'), findsOneWidget);
    expect(find.byTooltip('حذف الدفعة'), findsOneWidget);
  });

  testWidgets('survives a narrow RTL surface with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await createBatch();
    await tester.pumpWidget(app(textScale: 1.5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('دفعة تالتة ثانوي'), findsOneWidget);
  });
}
