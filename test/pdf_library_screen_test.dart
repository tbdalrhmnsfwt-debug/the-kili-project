import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/key_value_store.dart';
import '../lib/core/pdf/pdf_library_controller.dart';
import '../lib/core/pdf/pdf_library_repository.dart';
import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/core/theme.dart';
import '../lib/features/pdf/pdf_library_screen.dart';
import '../lib/features/tools/pdf_tools_screen.dart';
import '../lib/providers/pdf_providers.dart';

class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

PdfImportSource source(String name) => PdfImportSource(
  name: name,
  sizeBytes: 12,
  openRead: () => Stream.value('%PDF-1.7 body'.codeUnits),
);

void main() {
  late Directory root;
  late Directory cache;
  late PdfLibraryStore store;
  late PdfLibraryController controller;
  var ids = 0;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_pdf_ui_root_');
    cache = Directory.systemTemp.createTempSync('zaker_pdf_ui_cache_');
    store = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await store.ensureReady();
    ids = 0;
    controller = PdfLibraryController(
      store: store,
      repository: PdfLibraryRepository(MemoryStore()),
      probe: (file) async => const PdfProbeResult(pageCount: 3),
      thumbnailer: (base, thumb) async {},
      newId: () => 'id${++ids}',
    );
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfLibraryControllerProvider.overrideWith((ref) => controller),
          pdfLibraryStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(theme: ZakerTheme.light(), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty library invites the first import', (tester) async {
    await pump(tester, const PdfLibraryScreen());

    expect(find.text('لسه مفيش ملفات'), findsOneWidget);
    expect(find.text('ضيف PDF'), findsWidgets);
  });

  testWidgets('entries render and a long name is clipped to two lines', (
    tester,
  ) async {
    const long =
        'مذكرة المراجعة النهائية لمادة الفيزياء للصف الثالث الثانوي الفصل الدراسي الأول';
    // Real file I/O has to run outside the widget test's fake async zone.
    await tester.runAsync(
      () => controller.import([source('محاضرة.pdf'), source('$long.pdf')]),
    );

    await pump(tester, const PdfLibraryScreen());

    expect(find.text('محاضرة'), findsOneWidget);
    final clipped = tester.widget<Text>(find.text(long));
    expect(clipped.maxLines, 2);
    expect(clipped.overflow, TextOverflow.ellipsis);
  });

  testWidgets('deleting asks first and cancelling keeps the entry', (
    tester,
  ) async {
    await tester.runAsync(() => controller.import([source('تقرير.pdf')]));

    await pump(tester, const PdfLibraryScreen());
    await tester.tap(find.byTooltip('خيارات').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('تقرير'), findsWidgets);

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(controller.state.entries, hasLength(1));
    expect(find.text('تقرير'), findsOneWidget);
  });

  testWidgets('a file deleted outside the app is shown as unavailable', (
    tester,
  ) async {
    final entry = (await tester.runAsync(
      () => controller.import([source('تقرير.pdf')]),
    ))!.imported.single;
    await tester.runAsync(() => store.baseFile(entry.id).delete());

    await pump(tester, const PdfLibraryScreen());

    expect(find.text('تقرير'), findsOneWidget);
    expect(find.text('الملف مش موجود'), findsOneWidget);
    expect(controller.state.entries, hasLength(1));
  });

  testWidgets('the hub shows the library only when it has files', (
    tester,
  ) async {
    await pump(tester, const PdfToolsScreen());

    expect(find.text('ملفاتي'), findsNothing);
    expect(find.text('عرض الكل'), findsNothing);

    await tester.runAsync(() => controller.import([source('تقرير.pdf')]));
    await pump(tester, const PdfToolsScreen());

    expect(find.text('ملفاتي'), findsOneWidget);
    expect(find.text('عرض الكل'), findsOneWidget);
  });
}
