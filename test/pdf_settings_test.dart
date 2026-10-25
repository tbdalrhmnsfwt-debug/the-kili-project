import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/key_value_store.dart';
import '../lib/core/local_store.dart';
import '../lib/core/pdf/pdf_library_controller.dart';
import '../lib/core/pdf/pdf_library_repository.dart';
import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/core/pdf/pdf_page_geometry.dart';
import '../lib/core/pdf/pdf_render_channel.dart';
import '../lib/core/theme.dart';
import '../lib/features/pdf/pdf_reader_screen.dart';
import '../lib/features/pdf/widgets/pdf_reader_viewport.dart';
import '../lib/features/pdf/widgets/pdf_settings_sheet.dart';
import '../lib/models/pdf_settings.dart';
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

class FakeChannel extends PdfRenderChannel {
  FakeChannel({this.pageCount = 10});

  final int pageCount;

  @override
  Future<PdfRendererHandle> open(String path, {String? password}) async {
    return PdfRendererHandle(
      id: 1,
      pageCount: pageCount,
      pages: List.generate(pageCount, (_) => const PdfPageSize(595, 842)),
    );
  }

  @override
  Future<Uint8List> render({
    required int handle,
    required int pageIndex,
    required double scale,
    required NormalizedRect source,
    int maxPixels = 4096,
  }) async {
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> close(int handle) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory cache;
  late PdfLibraryStore store;
  late PdfLibraryRepository repository;
  late PdfLibraryController controller;

  /// A fresh controller per provider scope: a `pumpWidget` that replaces the
  /// scope disposes the notifier it was given, and the next scope cannot use
  /// it again. Both read the same catalog, so persistence is still tested.
  PdfLibraryController newController() => PdfLibraryController(
    store: store,
    repository: repository,
    probe: (file) async => const PdfProbeResult(pageCount: 10),
    thumbnailer: (base, thumb) async {},
    newId: () => 'doc',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('zaker_pdf_settings_root_');
    cache = Directory.systemTemp.createTempSync('zaker_pdf_settings_cache_');
    store = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await store.ensureReady();
    repository = PdfLibraryRepository(MemoryStore());
    controller = newController();
    await controller.import([
      PdfImportSource(
        name: 'lecture.pdf',
        sizeBytes: 8,
        openRead: () => Stream.value(Uint8List.fromList('%PDF-1.7'.codeUnits)),
      ),
    ]);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  Future<void> pumpReader(
    WidgetTester tester,
    FakeChannel channel,
    Widget home,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfRenderChannelProvider.overrideWithValue(channel),
          pdfLibraryStoreProvider.overrideWithValue(store),
          pdfLibraryControllerProvider.overrideWith((ref) => newController()),
        ],
        child: MaterialApp(theme: ZakerTheme.light(), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('missing settings fall back to the defaults', () {
    expect(PdfReaderSettings.fromJson(null).scrollMode, PdfScrollMode.vertical);
    expect(PdfReaderSettings.fromJson(null).nightMode, isFalse);
    expect(PdfReaderSettings.fromJson(null).haptics, isTrue);
  });

  test('an unknown scroll mode falls back to vertical', () {
    final settings = PdfReaderSettings.fromJson({'scroll': 'sideways'});

    expect(settings.scrollMode, PdfScrollMode.vertical);
  });

  test('night mode persists across controllers over the same store', () async {
    final settingsStore = await LocalStore.open();
    final first = PdfSettingsController(settingsStore);

    first.setNightMode(true);
    await pumpEventQueue();

    final second = PdfSettingsController(settingsStore);
    expect(second.state.nightMode, isTrue);
  });

  testWidgets('a library document reopens on its last page', (tester) async {
    final channel = FakeChannel(pageCount: 10);
    await pumpReader(tester, channel, const PdfReaderScreen(docId: 'doc'));
    expect(find.text('صفحة 1 من 10'), findsOneWidget);

    await tester.tap(find.text('صفحة 1 من 10'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('انتقال'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    await pumpReader(
      tester,
      FakeChannel(pageCount: 10),
      const PdfReaderScreen(docId: 'doc'),
    );

    expect(find.text('صفحة 4 من 10'), findsOneWidget);
  });

  testWidgets('the settings sheet changes the reader', (tester) async {
    final channel = FakeChannel(pageCount: 3);
    await pumpReader(
      tester,
      channel,
      const PdfReaderScreen(path: '/tmp/s.pdf'),
    );

    var viewport = tester.widget<PdfReaderViewport>(
      find.byType(PdfReaderViewport),
    );
    expect(viewport.nightMode, isFalse);
    expect(viewport.vertical, isTrue);

    await tester.tap(find.byTooltip('إعدادات القراءة'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('وضع الليل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أفقي'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    viewport = tester.widget<PdfReaderViewport>(find.byType(PdfReaderViewport));
    expect(viewport.nightMode, isTrue);
    expect(viewport.vertical, isFalse);
  });

  testWidgets('the sheet persists the scroll direction and haptics', (
    tester,
  ) async {
    await pumpReader(
      tester,
      FakeChannel(pageCount: 3),
      const Scaffold(body: PdfSettingsSheet()),
    );

    await tester.tap(find.text('أفقي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اهتزاز خفيف'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PdfSettingsSheet)),
    );
    final settings = container.read(pdfSettingsProvider);
    expect(settings.scrollMode, PdfScrollMode.horizontal);
    expect(settings.haptics, isFalse);
  });
}
