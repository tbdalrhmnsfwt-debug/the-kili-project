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
import 'package:zaker_ai/core/router.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_folder_screen.dart';
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

  const folderId = 'subject:sec1:الرياضيات';

  final folder = MyBagFolder.subject(
    gradeId: 'sec1',
    subjectKey: 'الرياضيات',
    name: 'الرياضيات',
    colorValue: 0xFF2F5EA8,
    createdAt: DateTime.utc(2026, 10, 1),
  ).copyWith(pdfIds: const ['p1']);

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_bag_folder_');
    cache = Directory.systemTemp.createTempSync('zaker_bag_cache_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
    local = LocalStore.memory();
    pdfStore = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await pdfStore.ensureReady();
    await store.saveIndex(MyBagIndex().upsert(folder));
    await store.saveMedia(
      folderId,
      const MyBagFolderMedia(
        links: [
          MyBagLink(
            id: 'l1',
            title: 'درس',
            url: 'https://example.com',
            createdAtMs: 9,
          ),
        ],
      ),
    );
    await local.setString(
      PdfLibraryRepository.storeKey,
      jsonEncode(
        PdfLibraryIndex([
          PdfDocumentEntry(
            id: 'p1',
            displayName: 'ملزمة الرياضيات',
            baseFileName: 'p1.pdf',
            sizeBytes: 1200,
            pageCount: 240,
            addedAt: DateTime.utc(2026, 10, 1),
            lastPage: 12,
          ),
        ]).toJson(),
      ),
    );
    pdfStore.baseFile('p1').writeAsBytesSync(utf8.encode('%PDF-1.7'));
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  Widget app(String id) {
    final router = GoRouter(
      initialLocation: ZakerRoutes.bagFolderPath(id),
      routes: [
        GoRoute(
          path: '/bag/:folderId',
          builder: (context, state) =>
              BagFolderScreen(folderId: state.pathParameters['folderId']!),
        ),
        GoRoute(
          path: '/bag/:folderId/:kind',
          builder: (context, state) => Scaffold(
            body: Text('pocket ${state.pathParameters['kind']}'),
          ),
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
        pdfProbeProvider.overrideWithValue(
          (file) async => const PdfProbeResult(pageCount: 3),
        ),
        pdfThumbnailerProvider.overrideWithValue((base, thumb) async {}),
      ],
      child:
          MaterialApp.router(routerConfig: router, theme: ZakerTheme.light()),
    );
  }

  testWidgets('a folder shows its header, four pockets and recent additions', (
    tester,
  ) async {
    await tester.pumpWidget(app(folderId));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bag-folder-screen')), findsOneWidget);
    expect(find.text('الرياضيات'), findsWidgets);
    for (final kind in BagPocketKind.values) {
      expect(find.byKey(Key('bag-pocket-${kind.name}')), findsOneWidget);
    }
    expect(find.byKey(const Key('bag-recent')), findsOneWidget);
    expect(find.text('درس'), findsOneWidget);
  });

  testWidgets('a pocket opens its own screen', (tester) async {
    await tester.pumpWidget(app(folderId));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bag-pocket-links')));
    await tester.pumpAndSettle();
    expect(find.text('pocket links'), findsOneWidget);
  });

  testWidgets('an unknown folder explains itself instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(app('custom:missing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bag-pocket-missing')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
