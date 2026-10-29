import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';
import 'package:zaker_ai/core/my_bag/my_bag_store.dart';
import 'package:zaker_ai/core/pdf/pdf_library_controller.dart';
import 'package:zaker_ai/core/pdf/pdf_library_index.dart';
import 'package:zaker_ai/core/pdf/pdf_library_repository.dart';
import 'package:zaker_ai/core/pdf/pdf_library_store.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_pocket_screen.dart';
import 'package:zaker_ai/features/pdf/widgets/pdf_import_button.dart';
import 'package:zaker_ai/models/pdf_document.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/my_bag_providers.dart';
import 'package:zaker_ai/providers/pdf_providers.dart';

import 'support/my_bag_fixtures.dart';

void main() {
  late Directory root;
  late Directory cache;
  late MyBagStore store;
  late LocalStore local;
  late PdfLibraryStore pdfStore;
  late MemoryKv libraryKv;
  late PdfLibraryController libraryController;
  const folderId = 'subject:sec1:الرياضيات';

  PdfDocumentEntry entry(
    String id,
    String name, {
    int? pageCount,
    int lastPage = 1,
  }) =>
      PdfDocumentEntry(
        id: id,
        displayName: name,
        baseFileName: '$id.pdf',
        sizeBytes: 1200,
        pageCount: pageCount,
        addedAt: DateTime.utc(2026, 10, 1),
        lastPage: lastPage,
      );

  Future<void> seed({
    List<PdfDocumentEntry> library = const [],
    List<String> pdfIds = const [],
    bool writeBases = true,
  }) async {
    await store.saveIndex(
      MyBagIndex().upsert(
        MyBagFolder.subject(
          gradeId: 'sec1',
          subjectKey: 'الرياضيات',
          name: 'الرياضيات',
          colorValue: 0xFF2F5EA8,
          createdAt: DateTime.utc(2026, 10, 1),
        ).copyWith(pdfIds: pdfIds),
      ),
    );
    await libraryKv.setString(
      PdfLibraryRepository.storeKey,
      jsonEncode(PdfLibraryIndex(library).toJson()),
    );
    // The controller loads its catalog in the constructor, so it is built
    // after the seed lands in the store.
    libraryController = PdfLibraryController(
      store: pdfStore,
      repository: PdfLibraryRepository(libraryKv),
      probe: (file) async => const PdfProbeResult(pageCount: 3),
      thumbnailer: (base, thumb) async {},
    );
    if (writeBases) {
      for (final item in library) {
        pdfStore.baseFile(item.id).writeAsBytesSync(utf8.encode('%PDF-1.7'));
      }
    }
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_bag_pdf_');
    cache = Directory.systemTemp.createTempSync('zaker_bag_pdf_cache_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
    local = LocalStore.memory();
    libraryKv = MemoryKv();
    pdfStore = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await pdfStore.ensureReady();
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  Widget app({PdfPicker? picker}) {
    final router = GoRouter(
      initialLocation: '/pocket',
      routes: [
        GoRoute(
          path: '/pocket',
          builder: (context, state) => const BagPocketScreen(
            folderId: folderId,
            kind: BagPocketKind.pdfs,
          ),
        ),
        GoRoute(
          path: '/pdf-viewer',
          builder: (context, state) =>
              Text('reader ${state.uri.queryParameters['docId']}'),
        ),
      ],
    );
    return ProviderScope(
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
        if (picker != null) pdfPickerProvider.overrideWithValue(picker),
      ],
      child:
          MaterialApp.router(routerConfig: router, theme: ZakerTheme.light()),
    );
  }

  testWidgets('a tagged PDF shows its progress and opens the reader', (
    tester,
  ) async {
    await seed(
      library: [entry('p1', 'ملزمة الرياضيات', pageCount: 240, lastPage: 12)],
      pdfIds: const ['p1'],
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('ملزمة الرياضيات'), findsOneWidget);
    expect(find.text('صفحة 12 من 240'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bag-pdf-p1')));
    await tester.pumpAndSettle();
    expect(find.text('reader p1'), findsOneWidget);
  });

  testWidgets('a reference the library no longer has is pruned on open', (
    tester,
  ) async {
    await seed(library: const [], pdfIds: const ['ghost']);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bag-pdf-ghost')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BagPocketScreen)),
    );
    expect(
      container.read(myBagControllerProvider).folderById(folderId)!.pdfIds,
      isEmpty,
    );
  });

  testWidgets('a PDF whose file vanished is stale, not fatal', (tester) async {
    await seed(
      library: [entry('p2', 'ملزمة قديمة')],
      pdfIds: const ['p2'],
      writeBases: false,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bag-pdf-stale-p2')), findsOneWidget);
    expect(find.text('الملف مش موجود'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bag-pdf-forget-p2')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BagPocketScreen)),
    );
    expect(
      container.read(myBagControllerProvider).folderById(folderId)!.pdfIds,
      isEmpty,
    );
    // The library entry is untouched: only the bag reference went away.
    expect(container.read(pdfLibraryControllerProvider).entries, hasLength(1));
  });

  testWidgets('«أضف PDF» imports, tags and adds the reference', (tester) async {
    await seed();
    await tester.pumpWidget(
      app(
        picker: () async => [
          PdfImportSource(
            name: 'جديد.pdf',
            sizeBytes: 9,
            openRead: () => Stream.value(utf8.encode('%PDF-1.7 x')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-pocket-add')));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BagPocketScreen)),
    );
    // The import copies real bytes on the real event loop; pumpAndSettle alone
    // can return before the copy lands.
    for (var i = 0; i < 50; i++) {
      if (container.read(pdfLibraryControllerProvider).entries.isNotEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final library = container.read(pdfLibraryControllerProvider);
    expect(library.entries, hasLength(1));
    expect(library.entries.single.subjectKey, 'الرياضيات');
    expect(library.entries.single.gradeId, 'sec1');
    expect(
      container.read(myBagControllerProvider).folderById(folderId)!.pdfIds,
      [library.entries.single.id],
    );
  });
}
