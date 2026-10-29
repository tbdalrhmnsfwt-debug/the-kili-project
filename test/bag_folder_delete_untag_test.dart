import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';
import 'package:zaker_ai/core/my_bag/my_bag_store.dart';
import 'package:zaker_ai/core/pdf/pdf_library_controller.dart';
import 'package:zaker_ai/core/pdf/pdf_library_index.dart';
import 'package:zaker_ai/core/pdf/pdf_library_repository.dart';
import 'package:zaker_ai/core/pdf/pdf_library_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/my_bag_screen.dart';
import 'package:zaker_ai/models/pdf_document.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/my_bag_providers.dart';
import 'package:zaker_ai/providers/pdf_providers.dart';

import 'support/my_bag_fixtures.dart';

/// Deleting a folder promises its PDFs stay in the library «من غير وسم»;
/// this pins the untagging half of that promise.
void main() {
  late Directory root;
  late Directory cache;
  late MyBagStore store;
  late LocalStore local;
  late PdfLibraryStore pdfStore;
  late MemoryKv libraryKv;
  late PdfLibraryController libraryController;
  final folder = MyBagFolder.subject(
    gradeId: 'sec1',
    subjectKey: 'الرياضيات',
    name: 'الرياضيات',
    colorValue: 0xFF2F5EA8,
    createdAt: DateTime.utc(2026, 10, 1),
  );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_bag_untag_');
    cache = Directory.systemTemp.createTempSync('zaker_bag_untag_cache_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
    local = LocalStore.memory();
    libraryKv = MemoryKv();
    pdfStore = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await pdfStore.ensureReady();

    final tagged = PdfDocumentEntry(
      id: 'p1',
      displayName: 'ملزمة الرياضيات',
      baseFileName: 'p1.pdf',
      sizeBytes: 1200,
      addedAt: DateTime.utc(2026, 10, 1),
      gradeId: 'sec1',
      subjectKey: 'الرياضيات',
    );
    await store.saveIndex(
      MyBagIndex().upsert(folder.copyWith(pdfIds: const ['p1'])),
    );
    await libraryKv.setString(
      PdfLibraryRepository.storeKey,
      jsonEncode(PdfLibraryIndex([tagged]).toJson()),
    );
    pdfStore.baseFile('p1').writeAsBytesSync(utf8.encode('%PDF-1.7'));
    libraryController = PdfLibraryController(
      store: pdfStore,
      repository: PdfLibraryRepository(libraryKv),
      probe: (file) async => const PdfProbeResult(pageCount: 3),
      thumbnailer: (base, thumb) async {},
    );
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  Widget app() => ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(local),
          myBagStoreProvider.overrideWithValue(store),
          bagSeedSubjectsProvider.overrideWithValue(const []),
          bagSubjectProgressProvider.overrideWithValue(const {}),
          pdfLibraryStoreProvider.overrideWithValue(pdfStore),
          pdfLibraryControllerProvider.overrideWith(
            (ref) => libraryController,
          ),
          pdfProbeProvider.overrideWithValue(
            (file) async => const PdfProbeResult(pageCount: 3),
          ),
          pdfThumbnailerProvider.overrideWithValue((base, thumb) async {}),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          home: const MyBagScreen(),
        ),
      );

  testWidgets('deleting a folder untags its PDFs and keeps the file', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('bag-folder-menu-${folder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المجلد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('احذف'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyBagScreen)),
    );
    for (var i = 0; i < 50; i++) {
      if (container.read(pdfLibraryControllerProvider).entries.isEmpty) break;
      if (container.read(pdfLibraryControllerProvider).entries.single.gradeId ==
          '') {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    final entry = container.read(pdfLibraryControllerProvider).entries.single;
    expect(entry.gradeId, isEmpty);
    expect(entry.subjectKey, isEmpty);
    expect(entry.sourceDocId, isEmpty);
    // The document itself survives; only its tag went away.
    expect(pdfStore.baseFile('p1').existsSync(), isTrue);
    expect(
        container.read(myBagControllerProvider).folderById(folder.id), isNull);
  });
}
