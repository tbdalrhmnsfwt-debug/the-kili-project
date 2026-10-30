import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/core/pdf/pdf_page_geometry.dart';
import '../lib/core/pdf/pdf_render_channel.dart';
import '../lib/core/pdf/pdf_thumbnailer.dart';

class _FakeChannel extends PdfRenderChannel {
  final List<String> opened = [];
  final List<double> scales = [];
  int closes = 0;

  @override
  Future<PdfRendererHandle> open(String path, {String? password}) async {
    opened.add(path);
    return const PdfRendererHandle(
      id: 5,
      pageCount: 2,
      pages: [PdfPageSize(600, 800), PdfPageSize(600, 800)],
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
    scales.add(scale);
    return Uint8List.fromList([7, 8, 9]);
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

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_thumb_root_');
    cache = Directory.systemTemp.createTempSync('zaker_thumb_cache_');
    store = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await store.ensureReady();
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  test('renders page one at 120 px wide and closes the handle', () async {
    final channel = _FakeChannel();
    final base = store.baseFile('doc')..writeAsBytesSync([1, 2, 3]);

    await pdfThumbnailer(channel, store)(base, store.thumbFile('doc'));

    expect(channel.opened, [base.path]);
    expect(channel.scales.single, closeTo(120 / 600, 0.0001));
    expect(channel.closes, 1);
    expect(store.thumbFile('doc').readAsBytesSync(), [7, 8, 9]);
  });
}
