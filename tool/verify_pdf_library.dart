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
