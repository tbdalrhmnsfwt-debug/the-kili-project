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
import 'package:zaker_ai/features/bag/bag_image_picker.dart';
import 'package:zaker_ai/features/bag/bag_pocket_screen.dart';
import 'package:zaker_ai/providers/app_providers.dart';
import 'package:zaker_ai/providers/my_bag_providers.dart';
import 'package:zaker_ai/providers/pdf_providers.dart';

import 'support/my_bag_fixtures.dart';

const String _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=';

class _FakePicker implements BagImagePicker {
  _FakePicker(this.images);
  final List<BagPickedImage> images;
  int calls = 0;

  @override
  Future<List<BagPickedImage>> pick({required BagImageSource source}) async {
    calls++;
    return images;
  }
}

void main() {
  late Directory root;
  late Directory cache;
  late MyBagStore store;
  late LocalStore local;
  late PdfLibraryStore pdfStore;
  late MemoryKv libraryKv;
  late PdfLibraryController libraryController;
  late List<BagPickedImage> picked;
  const folderId = 'subject:sec1:الرياضيات';
  final folder = MyBagFolder.subject(
    gradeId: 'sec1',
    subjectKey: 'الرياضيات',
    name: 'الرياضيات',
    colorValue: 0xFF2F5EA8,
    createdAt: DateTime.utc(2026, 10, 1),
  );

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_bag_boards_');
    cache = Directory.systemTemp.createTempSync('zaker_bag_boards_cache_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
    local = LocalStore.memory();
    libraryKv = MemoryKv();
    pdfStore = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await pdfStore.ensureReady();
    await store.saveIndex(MyBagIndex().upsert(folder));
    await libraryKv.setString(
      PdfLibraryRepository.storeKey,
      jsonEncode(PdfLibraryIndex.empty().toJson()),
    );
    libraryController = PdfLibraryController(
      store: pdfStore,
      repository: PdfLibraryRepository(libraryKv),
      probe: (file) async => const PdfProbeResult(pageCount: 1),
      thumbnailer: (base, thumb) async {},
    );

    final bytes = base64Decode(_pngBase64);
    picked = [
      for (var i = 0; i < 2; i++)
        BagPickedImage(
          path: '${root.path}/picked$i.png',
          bytes: bytes,
          width: 1,
          height: 1,
        ),
    ];
    for (final image in picked) {
      File(image.path).writeAsBytesSync(image.bytes);
    }
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
            (file) async => const PdfProbeResult(pageCount: 1),
          ),
          pdfThumbnailerProvider.overrideWithValue((base, thumb) async {}),
          bagImagePickerProvider.overrideWithValue(_FakePicker(picked)),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          home: const BagPocketScreen(
            folderId: folderId,
            kind: BagPocketKind.boards,
          ),
        ),
      );

  /// Runs real file I/O between frames until [done] holds.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100; i++) {
      if (done()) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pickGallery(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('bag-board-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bag-board-source-gallery')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await waitFor(tester, () => store.loadMedia(folderId).boards.length == 2);
  }

  testWidgets('gallery images import and can be deleted', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await pickGallery(tester);

    final boards = store.loadMedia(folderId).boards;
    expect(boards, hasLength(2));
    expect(find.byKey(Key('bag-board-${boards.first.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('bag-board-delete-${boards.first.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('احذف'));
    await tester.pump();
    await waitFor(tester, () => store.loadMedia(folderId).boards.length == 1);
    expect(store.loadMedia(folderId).boards, hasLength(1));
  });

  testWidgets('a long-press draggable is wired for reordering', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await pickGallery(tester);

    expect(find.byType(LongPressDraggable<String>), findsNWidgets(2));
  });

  testWidgets('«كوّن PDF» builds, imports, tags and adds the PDF', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await pickGallery(tester);

    await tester.tap(find.byKey(const Key('bag-boards-compile')));
    await tester.pump();
    await waitFor(
      tester,
      () => find.text('تم تكوين ملف PDF').evaluate().isNotEmpty,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BagPocketScreen)),
    );
    final library = container.read(pdfLibraryControllerProvider);
    expect(library.entries, hasLength(1));
    expect(library.entries.single.subjectKey, 'الرياضيات');
    expect(library.entries.single.sourceDocId, folderId);
    expect(
      container.read(myBagControllerProvider).folderById(folderId)!.pdfIds,
      [library.entries.single.id],
    );
    expect(find.text('تم تكوين ملف PDF'), findsOneWidget);
  });

  testWidgets('«كوّن PDF» refuses more than 25 images at once', (tester) async {
    final bytes = base64Decode(_pngBase64);
    final boards = <MyBagBoardImage>[];
    for (var i = 0; i < 26; i++) {
      final fileName = 'seed$i.png';
      await store.writeBoardImage(folderId, fileName, bytes);
      boards.add(
        MyBagBoardImage(
          id: 'seed$i',
          fileName: fileName,
          width: 1,
          height: 1,
          createdAtMs: 0,
        ),
      );
    }
    await store.saveMedia(folderId, MyBagFolderMedia(boards: boards));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-boards-compile')));
    await tester.pump();

    expect(find.text('أقصى 25 صورة في المرة.'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BagPocketScreen)),
    );
    expect(container.read(pdfLibraryControllerProvider).entries, isEmpty);
    expect(
      container.read(myBagControllerProvider).folderById(folderId)!.pdfIds,
      isEmpty,
    );
  });
}
