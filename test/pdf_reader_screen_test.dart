import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/key_value_store.dart';
import '../lib/core/pdf/pdf_library_controller.dart';
import '../lib/core/pdf/pdf_library_repository.dart';
import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/core/pdf/pdf_page_geometry.dart';
import '../lib/core/pdf/pdf_render_channel.dart';
import '../lib/core/theme.dart';
import '../lib/features/pdf/pdf_reader_screen.dart';
import '../lib/features/tools/pdf_viewer_screen.dart';
import '../lib/providers/pdf_providers.dart';

import 'dart:io';

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
  FakeChannel({this.pageCount = 10, List<PdfRenderFailure?>? failures})
    : _failures = failures ?? [];

  final int pageCount;
  final List<PdfRenderFailure?> _failures;
  final List<String?> passwords = [];
  int opens = 0;
  int closes = 0;

  @override
  Future<PdfRendererHandle> open(String path, {String? password}) async {
    opens += 1;
    passwords.add(password);
    if (_failures.isNotEmpty) {
      final failure = _failures.removeAt(0);
      if (failure != null) throw PdfRenderException(failure);
    }
    return PdfRendererHandle(
      id: opens,
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
  Future<void> close(int handle) async {
    closes += 1;
  }
}

void main() {
  late Directory root;
  late Directory cache;
  late PdfLibraryStore store;
  late PdfLibraryController controller;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_pdf_reader_root_');
    cache = Directory.systemTemp.createTempSync('zaker_pdf_reader_cache_');
    store = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await store.ensureReady();
    controller = PdfLibraryController(
      store: store,
      repository: PdfLibraryRepository(MemoryStore()),
      probe: (file) async => const PdfProbeResult(pageCount: 10),
      thumbnailer: (base, thumb) async {},
      newId: () => 'doc',
    );
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester,
    FakeChannel channel,
    Widget home,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfRenderChannelProvider.overrideWithValue(channel),
          pdfLibraryStoreProvider.overrideWithValue(store),
          pdfLibraryControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(theme: ZakerTheme.light(), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a ten-page document shows the page counter', (tester) async {
    final channel = FakeChannel(pageCount: 10);
    await pump(tester, channel, const PdfReaderScreen(path: '/tmp/zaker.pdf'));

    expect(find.text('صفحة 1 من 10'), findsOneWidget);
  });

  testWidgets('a locked document asks for the password and reopens with it', (
    tester,
  ) async {
    final channel = FakeChannel(
      pageCount: 3,
      failures: [
        PdfRenderFailure.passwordRequired,
        PdfRenderFailure.wrongPassword,
      ],
    );
    await pump(tester, channel, const PdfReaderScreen(path: '/tmp/locked.pdf'));

    expect(find.text('الملف محمي بكلمة سر'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(channel.passwords, [null, 'secret']);
    expect(find.text('الملف محمي بكلمة سر'), findsOneWidget);
    expect(find.text('كلمة السر مش صح — جرّب تاني.'), findsOneWidget);
  });

  testWidgets('a corrupt file offers a retry that opens again', (tester) async {
    final channel = FakeChannel(
      pageCount: 10,
      failures: [PdfRenderFailure.corrupt],
    );
    await pump(tester, channel, const PdfReaderScreen(path: '/tmp/broken.pdf'));

    expect(find.text('تعذّر فتح الملف'), findsOneWidget);

    await tester.tap(find.text('جرّب تاني'));
    await tester.pumpAndSettle();

    expect(channel.opens, 2);
    expect(find.text('صفحة 1 من 10'), findsOneWidget);
  });

  testWidgets('in-memory bytes use a session temp file that is deleted', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 4);
    await pump(
      tester,
      channel,
      PdfReaderScreen(bytes: Uint8List.fromList('%PDF-1.7'.codeUnits)),
    );

    expect(store.sessionTempDir.listSync(), hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(store.sessionTempDir.listSync(), isEmpty);
    expect(channel.closes, 1);
  });

  testWidgets('the legacy viewer builds the reader', (tester) async {
    final channel = FakeChannel(pageCount: 10);
    await pump(tester, channel, const PdfViewerScreen(path: '/x.pdf'));

    expect(find.byType(PdfReaderScreen), findsOneWidget);
  });
}
