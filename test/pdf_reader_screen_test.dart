import 'dart:async';
import 'dart:convert';
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
import '../lib/features/pdf/widgets/pdf_page_view.dart';
import '../lib/features/pdf/widgets/pdf_reader_viewport.dart';
import '../lib/features/tools/pdf_viewer_screen.dart';
import '../lib/providers/pdf_providers.dart';

import 'dart:io';

/// A 1×1 transparent PNG, so `Image.memory` decodes without an error.
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

class RenderCall {
  const RenderCall({
    required this.pageIndex,
    required this.scale,
    required this.source,
  });

  final int pageIndex;
  final double scale;
  final NormalizedRect source;
}

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
  FakeChannel({
    this.pageCount = 10,
    List<PdfRenderFailure?>? failures,
    this.expectedPassword,
  }) : _failures = failures ?? [];

  final int pageCount;
  final List<PdfRenderFailure?> _failures;

  /// When set, `open` demands this password on every call.
  final String? expectedPassword;
  final List<String?> passwords = [];
  final List<RenderCall> renders = [];
  int opens = 0;
  int closes = 0;

  /// When true, `render` never completes.
  bool hangRenders = false;

  @override
  Future<PdfRendererHandle> open(String path, {String? password}) async {
    opens += 1;
    passwords.add(password);
    if (expectedPassword != null) {
      if (password == null) {
        throw const PdfRenderException(PdfRenderFailure.passwordRequired);
      }
      if (password != expectedPassword) {
        throw const PdfRenderException(PdfRenderFailure.wrongPassword);
      }
    }
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
    renders.add(RenderCall(pageIndex: pageIndex, scale: scale, source: source));
    if (hangRenders) return Completer<Uint8List>().future;
    return _onePixelPng;
  }

  @override
  Future<void> close(int handle) async {
    closes += 1;
  }
}

PdfRendererHandle _handle(
  int pageCount, {
  PdfPageSize size = const PdfPageSize(595, 842),
}) {
  return PdfRendererHandle(
    id: 7,
    pageCount: pageCount,
    pages: List.generate(pageCount, (_) => size),
  );
}

PdfReaderViewport _portraitViewport({double zoom = 1}) {
  return PdfReaderViewport(
    handle: _handle(1),
    geometry: const [PdfPageGeometry(widthPoints: 595, heightPoints: 842)],
    initialPage: 0,
    onPageChanged: (_) {},
    initialZoom: zoom,
  );
}

PdfReaderViewport _squareViewport({
  required double zoom,
  int quarterTurns = 0,
}) {
  return PdfReaderViewport(
    handle: _handle(1, size: const PdfPageSize(600, 600)),
    geometry: const [PdfPageGeometry(widthPoints: 600, heightPoints: 600)],
    initialPage: 0,
    onPageChanged: (_) {},
    quarterTurns: quarterTurns,
    initialZoom: zoom,
  );
}

Future<void> _pumpViewport(
  WidgetTester tester, {
  required FakeChannel channel,
  required PdfReaderViewport viewport,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pdfRenderChannelProvider.overrideWithValue(channel)],
      child: MaterialApp(
        theme: ZakerTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 400, height: 800, child: viewport),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
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
    expect(find.byType(PdfReaderViewport), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
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

  testWidgets('the first frame requests page zero at fit-width', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 1);
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _portraitViewport(),
    );

    expect(channel.renders, isNotEmpty);
    final call = channel.renders.first;
    expect(call.pageIndex, 0);
    expect(call.source.left, closeTo(0, 0.01));
    expect(call.source.top, closeTo(0, 0.01));
    expect(call.source.width, closeTo(1, 0.01));
    expect(call.source.height, closeTo(1, 0.01));
  });

  testWidgets('zooming in requests a narrower source and paints the tile', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 1);
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _portraitViewport(),
    );
    final wide = channel.renders.last.source.width;
    expect(wide, closeTo(1, 0.01));

    channel.renders.clear();
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _portraitViewport(zoom: 5),
    );

    expect(channel.renders, isNotEmpty);
    final narrow = channel.renders.last.source.width;
    expect(narrow, lessThan(0.6));
    expect(narrow, lessThan(wide));
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('a slow renderer shows the placeholder without an exception', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 1)..hangRenders = true;
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _portraitViewport(),
    );

    expect(channel.renders, isNotEmpty);
    expect(find.byType(PdfPageView), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quarter turns swap the requested source', (tester) async {
    final channel = FakeChannel(pageCount: 1);
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _squareViewport(zoom: 2),
    );
    final upright = channel.renders.last.source;

    channel.renders.clear();
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _squareViewport(zoom: 2, quarterTurns: 1),
    );
    final rotated = channel.renders.last.source;

    expect(rotated.width, closeTo(upright.height, 0.001));
    expect(rotated.height, closeTo(upright.width, 0.001));
  });

  testWidgets('page mode shows one page at a time', (tester) async {
    final channel = FakeChannel(pageCount: 3);
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: PdfReaderViewport(
        handle: _handle(3),
        geometry: List.filled(
          3,
          const PdfPageGeometry(widthPoints: 595, heightPoints: 842),
        ),
        initialPage: 0,
        onPageChanged: (_) {},
        vertical: false,
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('three wrong passwords still allow a fresh retry', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 3, expectedPassword: 'secret');
    await pump(tester, channel, const PdfReaderScreen(path: '/tmp/locked.pdf'));

    for (var attempt = 0; attempt < 3; attempt++) {
      expect(find.text('الملف محمي بكلمة سر'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'nope$attempt');
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
    }

    expect(find.text('تعذّر فتح الملف'), findsOneWidget);

    await tester.tap(find.text('جرّب تاني'));
    await tester.pumpAndSettle();

    expect(find.text('الملف محمي بكلمة سر'), findsOneWidget);
  });

  testWidgets('rotated pages report the page under the viewport', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 3);
    final changes = <int>[];
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: PdfReaderViewport(
        handle: PdfRendererHandle(
          id: 7,
          pageCount: 3,
          pages: List.filled(3, const PdfPageSize(200, 400)),
        ),
        geometry: List.filled(
          3,
          const PdfPageGeometry(widthPoints: 200, heightPoints: 400),
        ),
        initialPage: 0,
        onPageChanged: changes.add,
        quarterTurns: 1,
        initialZoom: 2,
      ),
    );

    await tester.drag(find.byType(PdfReaderViewport), const Offset(0, -790));
    await tester.pumpAndSettle();

    expect(changes, isNotEmpty);
    expect(changes.last, 1);
  });

  testWidgets('tiles for pages far off screen are released', (tester) async {
    final channel = FakeChannel(pageCount: 6);
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: PdfReaderViewport(
        handle: _handle(6),
        geometry: List.filled(
          6,
          const PdfPageGeometry(widthPoints: 595, heightPoints: 842),
        ),
        initialPage: 0,
        onPageChanged: (_) {},
      ),
    );
    final state = tester.state<PdfReaderViewportState>(
      find.byType(PdfReaderViewport),
    );
    expect(state.retainedTilePages, contains(0));

    await tester.drag(find.byType(PdfReaderViewport), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(state.retainedTilePages, isNot(contains(0)));
  });

  testWidgets('a document with no pages fails without leaking its handle', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 0);
    await pump(tester, channel, const PdfReaderScreen(path: '/tmp/empty.pdf'));

    expect(find.text('تعذّر فتح الملف'), findsOneWidget);
    expect(channel.closes, 1);

    await tester.tap(find.text('جرّب تاني'));
    await tester.pumpAndSettle();

    expect(channel.closes, 2, reason: 'each retry must release its own handle');
  });

  testWidgets('a reader that cannot write session bytes reports storage', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 3);
    final brokenStore = PdfLibraryStore(
      rootDir: root,
      cacheDir: Directory('/proc/zaker_no_such_cache'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfRenderChannelProvider.overrideWithValue(channel),
          pdfLibraryStoreProvider.overrideWithValue(brokenStore),
          pdfLibraryControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          home: PdfReaderScreen(bytes: Uint8List.fromList([1, 2, 3])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مفيش مساحة كافية على الجهاز.'), findsOneWidget);
    expect(channel.opens, 0);
  });
}
