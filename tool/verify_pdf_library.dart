/// Flutter-free verification of the PDF library layer.
///
/// Run with the local Dart SDK:
///
///     dart run tool/verify_pdf_library.dart
///
/// Every assertion here is deterministic and offline. Flutter-only code
/// (widgets, channels) is covered by `flutter test` in CI instead.
library;

import 'dart:convert';

import '../lib/core/key_value_store.dart';
import '../lib/core/pdf/pdf_library_index.dart';
import '../lib/core/pdf/pdf_library_repository.dart';
import '../lib/core/pdf/pdf_page_geometry.dart';
import '../lib/models/pdf_document.dart';

var _checks = 0;
final _failures = <String>[];

void check(bool condition, String description) {
  _checks++;
  if (!condition) _failures.add(description);
}

void checkClose(num actual, num expected, String description) {
  check((actual - expected).abs() < 1e-9, '$description (got $actual)');
}

/// A [KeyValueStore] that keeps values in memory.
class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

PdfDocumentEntry _entry({
  String id = 'one',
  String name = 'كيمياء',
  int size = 1024,
  DateTime? addedAt,
  int? pageCount = 10,
  bool favorite = false,
  DateTime? lastOpenedAt,
}) {
  return PdfDocumentEntry(
    id: id,
    displayName: name,
    baseFileName: '$id.pdf',
    sizeBytes: size,
    pageCount: pageCount,
    addedAt: addedAt ?? DateTime.utc(2026, 10, 20),
    favorite: favorite,
    lastOpenedAt: lastOpenedAt,
  );
}

Future<void> main() async {
  _models();
  _index();
  await _repository();
  _geometry();

  if (_failures.isEmpty) {
    // ignore: avoid_print
    print('All $_checks checks passed');
    return;
  }
  // ignore: avoid_print
  print('$_failures.length of $_checks checks failed:');
  for (final failure in _failures) {
    // ignore: avoid_print
    print(' - $failure');
  }
  throw StateError('verification failed');
}

void _models() {
  final entry = _entry();
  final round = PdfDocumentEntry.fromJson(entry.toJson());
  check(
    jsonEncode(round.toJson()) == jsonEncode(entry.toJson()),
    'entry survives a JSON round-trip',
  );

  final sparse = PdfDocumentEntry.fromJson({
    'id': 'a',
    'name': 'x',
    'base': 'a.pdf',
    'size': 1,
    'addedAt': '2026-10-25T00:00:00.000Z',
  });
  check(sparse.pageCount == null, 'missing pages stays null');
  check(sparse.lastPage == 1, 'lastPage defaults to 1');
  check(!sparse.favorite, 'favorite defaults to false');
  check(sparse.annotationCount == 0, 'annotations default to 0');
  check(
    sparse.source == PdfDocumentSource.imported,
    'source defaults to imported',
  );
  check(
    sparse.encryption == PdfEncryptionState.unknown,
    'encryption defaults to unknown',
  );
  check(sparse.thumbnailFileName == null, 'thumbnail stays null');

  final unknown = PdfDocumentEntry.fromJson({
    'id': 'a',
    'name': 'x',
    'base': 'a.pdf',
    'size': 1,
    'addedAt': '2026-10-25T00:00:00.000Z',
    'encryption': 'maybe',
  });
  check(
    unknown.encryption == PdfEncryptionState.unknown,
    'unknown encryption value falls back to unknown',
  );

  var threw = false;
  try {
    PdfDocumentEntry.fromJson({'id': 'a', 'name': 'x'});
  } on FormatException {
    threw = true;
  }
  check(threw, 'missing required keys throw a FormatException');
}

void _index() {
  check(PdfLibraryIndex.fromJson(null).entries.isEmpty, 'null root is empty');

  final mixed = PdfLibraryIndex.fromJson({
    'version': 1,
    'documents': [
      {'id': 'a', 'name': 'x', 'base': 'a.pdf', 'size': 1},
      _entry(id: 'b').toJson(),
    ],
  });
  check(mixed.entries.length == 1, 'malformed documents are skipped');
  check(mixed.entries.single.id == 'b', 'the valid document survives');

  final index = PdfLibraryIndex.empty()
      .upsert(_entry(id: 'a', name: 'كيمياء', size: 10))
      .upsert(_entry(id: 'b', name: 'فيزياء', size: 20))
      .upsert(_entry(id: 'c', name: 'AI notes', size: 30));

  check(index.entries.length == 3, 'upsert appends new ids');
  final replaced = index.upsert(_entry(id: 'b', name: 'أحياء', size: 99));
  check(replaced.entries.length == 3, 'upsert does not grow on replace');
  check(
    replaced.entries.firstWhere((e) => e.id == 'b').sizeBytes == 99,
    'upsert replaces the existing entry',
  );

  check(
    index.query(search: 'كيم').map((e) => e.id).toList().join(',') == 'a',
    'Arabic search matches by substring',
  );
  check(
    index.query(search: 'ai').map((e) => e.id).toList().join(',') == 'c',
    'search is case-insensitive',
  );

  final sorted = index.query(sort: PdfSort.name, descending: false);
  check(
    sorted.first.displayName == 'AI notes',
    'name sort ascending starts at A',
  );
  check(sorted.last.displayName == 'كيمياء', 'name sort ascending ends at ك');
  final desc = index.query(sort: PdfSort.size, descending: true);
  check(desc.first.id == 'c', 'size sort descending puts the largest first');
  check(
    index.query(sort: PdfSort.size, descending: false).first.id == 'a',
    'size sort ascending puts the smallest first',
  );
  check(index.query(limit: 2).length == 2, 'limit truncates');
  check(
    index.query(favoritesOnly: true).isEmpty,
    'favorites filter excludes non-favorites',
  );

  final pruned = index.pruneMissing((e) => e.id != 'a');
  check(pruned.entries.length == 2, 'pruneMissing drops missing files');
  check(pruned.entries.every((e) => e.id != 'a'), 'the dropped id is gone');
}

void _geometry() {
  const geometry = PdfPageGeometry(widthPoints: 600, heightPoints: 800);
  checkClose(
    geometry.fitScale(400),
    2 / 3,
    'fit scale fills the viewport width',
  );
  checkClose(
    geometry.displayWidth(fitScale: 2 / 3, zoom: 1),
    400,
    'zoom 1 is fit-width',
  );
  checkClose(
    geometry.displayWidth(fitScale: 2 / 3, zoom: 5),
    2000,
    'zoom 5 is 500% of fit-width',
  );
  checkClose(
    geometry.displayHeight(fitScale: 2 / 3, zoom: 5),
    800 * (2 / 3) * 5,
    'display height follows the same scale',
  );

  final zoomed = geometry.visibleSource(
    scrollX: 0,
    scrollY: 0,
    viewportWidth: 400,
    viewportHeight: 600,
    fitScale: 2 / 3,
    zoom: 5,
    margin: 0,
  );
  checkClose(zoomed.left, 0, 'a fresh zoom starts at the page edge');
  checkClose(zoomed.top, 0, 'a fresh zoom starts at the top');
  checkClose(zoomed.width, 0.2, 'a 5x zoom sees a fifth of the width');
  checkClose(zoomed.height, 0.225, 'the visible height follows the viewport');

  final padded = geometry.visibleSource(
    scrollX: 0,
    scrollY: 0,
    viewportWidth: 400,
    viewportHeight: 600,
    fitScale: 2 / 3,
    zoom: 5,
  );
  checkClose(padded.left, 0, 'the prefetch margin clamps at the page edge');
  checkClose(padded.top, 0, 'the prefetch margin clamps at the page top');
  checkClose(padded.right, 0.35, 'the prefetch margin widens the tile');
  checkClose(padded.bottom, 0.375, 'the prefetch margin deepens the tile');

  final atEnd = geometry.visibleSource(
    scrollX: 99999,
    scrollY: 0,
    viewportWidth: 400,
    viewportHeight: 600,
    fitScale: 2 / 3,
    zoom: 5,
    margin: 0,
  );
  checkClose(atEnd.left, 0.8, 'scrolling past the end pins the left edge');
  checkClose(atEnd.right, 1, 'the tile never runs past the right edge');

  for (var zoom = 1.0; zoom <= 5.0; zoom += 0.5) {
    for (final scroll in [-500.0, 0.0, 333.0, 99999.0]) {
      final rect = geometry.visibleSource(
        scrollX: scroll,
        scrollY: scroll,
        viewportWidth: 400,
        viewportHeight: 600,
        fitScale: 2 / 3,
        zoom: zoom,
      );
      check(
        rect.left >= 0 &&
            rect.top >= 0 &&
            rect.right <= 1 &&
            rect.bottom <= 1 &&
            rect.width >= 0 &&
            rect.height >= 0,
        'tile source stays inside the page at $zoom x ($scroll)',
      );
    }
  }

  const rect = NormalizedRect(0.1, 0.2, 0.3, 0.4);
  final identity = PdfPageGeometry.unrotateSource(rect, 0);
  checkClose(identity.left, 0.1, 'no rotation keeps the left edge');
  checkClose(identity.width, 0.3, 'no rotation keeps the width');

  final once = PdfPageGeometry.unrotateSource(rect, 1);
  checkClose(once.left, 0.2, 'a quarter turn moves the left edge');
  checkClose(once.top, 0.6, 'a quarter turn moves the top edge');
  checkClose(once.width, 0.4, 'a quarter turn swaps the width');
  checkClose(once.height, 0.3, 'a quarter turn swaps the height');

  final twice = PdfPageGeometry.unrotateSource(rect, 2);
  checkClose(twice.left, 0.6, 'a half turn mirrors the left edge');
  checkClose(twice.top, 0.4, 'a half turn mirrors the top edge');

  final thrice = PdfPageGeometry.unrotateSource(rect, 3);
  checkClose(thrice.left, 0.4, 'three quarters turn the left edge');
  checkClose(thrice.top, 0.1, 'three quarters turn the top edge');

  final negative = PdfPageGeometry.unrotateSource(rect, -1);
  checkClose(negative.left, thrice.left, 'negative turns wrap to three');
  checkClose(negative.top, thrice.top, 'negative turns wrap the top edge');
}

Future<void> _repository() async {
  final store = MemoryStore();
  final repository = PdfLibraryRepository(store);
  final index = PdfLibraryIndex.empty().upsert(_entry());
  await repository.save(index);
  final loaded = repository.load();
  check(loaded.entries.length == 1, 'repository round-trips through the store');
  check(
    jsonEncode(loaded.toJson()) == jsonEncode(index.toJson()),
    'repository preserves the index JSON',
  );
}
