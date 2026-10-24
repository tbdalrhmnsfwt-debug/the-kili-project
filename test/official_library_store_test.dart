import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/key_value_store.dart';
import '../lib/core/official_library_store.dart';
import '../lib/models/official_book.dart';

/// In-memory [KeyValueStore] that mirrors what `LocalStore` does without
/// needing a Flutter binding.
class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

const _row = BookLocalState(
  bookId: 'g10-math',
  downloadStatus: BookDownloadStatus.downloaded,
  filePath: '/books/g10-math.pdf',
  sha256: 'abc123',
  extractedPath: '/books/g10-math.json',
);

void main() {
  test('an empty store loads an empty state', () {
    final load = OfficialLibraryStore(_MemoryStore()).load();
    expect(load.state.isEmpty, isTrue);
    expect(load.corrupt, isFalse);
  });

  test('saves round-trip and keep a backup of the previous value', () async {
    final memory = _MemoryStore();
    final store = OfficialLibraryStore(memory);
    await store.save(
      const OfficialLibraryState(books: {'g10-math': _row}, catalogVersion: 2),
    );
    await store.save(
      const OfficialLibraryState(books: {'g10-math': _row}, queue: ['g10-math']),
    );

    expect(memory.values[kOfficialLibraryBackupKey], isNotNull);
    final load = store.load();
    expect(load.state.queue, ['g10-math']);
    expect(load.state.books['g10-math']?.sha256, 'abc123');
  });

  test('a corrupt primary value recovers from the backup', () async {
    final memory = _MemoryStore();
    final store = OfficialLibraryStore(memory);
    await store.save(const OfficialLibraryState(books: {'g10-math': _row}));
    await store.save(const OfficialLibraryState(books: {'g10-math': _row}));
    memory.values[kOfficialLibraryKey] = '{not json';

    final load = store.load();
    expect(load.recoveredFromBackup, isTrue);
    expect(load.corrupt, isFalse);
    expect(load.state.books['g10-math']?.filePath, '/books/g10-math.pdf');
    expect(memory.values[kOfficialLibraryCorruptKey], '{not json');
  });

  test('corrupt primary and backup report corruption without throwing', () {
    final memory = _MemoryStore();
    memory.values[kOfficialLibraryKey] = '[[[';
    memory.values[kOfficialLibraryBackupKey] = 'oops';
    final load = OfficialLibraryStore(memory).load();
    expect(load.corrupt, isTrue);
    expect(load.state.isEmpty, isTrue);
    expect(memory.values[kOfficialLibraryCorruptKey], '[[[');
  });

  test('unversioned payloads are migrated', () {
    final memory = _MemoryStore();
    memory.values[kOfficialLibraryKey] = jsonEncode({
      'pending': ['b1'],
      'books': [
        {
          'book_id': 'b1',
          'download_status': 'downloaded',
          'file_path': '/b1.pdf',
        },
      ],
    });
    final load = OfficialLibraryStore(memory).load();
    expect(load.migratedFrom, 0);
    expect(load.state.schemaVersion, kOfficialLibrarySchemaVersion);
    expect(load.state.queue, ['b1']);
    expect(load.state.books.length, 1);
  });

  test('interrupted downloads and extractions become resumable', () {
    final memory = _MemoryStore();
    memory.values[kOfficialLibraryKey] = jsonEncode({
      'schema_version': kOfficialLibrarySchemaVersion,
      'queue': <String>[],
      'books': {
        'down': {
          'book_id': 'down',
          'download_status': 'downloading',
          'extraction_status': 'extracting',
        },
      },
    });
    final state = OfficialLibraryStore(memory).load().state;
    expect(state.books['down']?.downloadStatus, BookDownloadStatus.queued);
    expect(
      state.books['down']?.extractionStatus,
      BookExtractionStatus.notStarted,
    );
    expect(state.queue, contains('down'));
  });

  test('export omits device paths and imports never replace local files',
      () async {
    final memory = _MemoryStore();
    final store = OfficialLibraryStore(memory);
    await store.save(const OfficialLibraryState(books: {'g10-math': _row}));
    final exported = store.export();
    final exportedRow =
        (exported['books'] as Map<String, dynamic>)['g10-math']
            as Map<String, dynamic>;
    expect(exportedRow['file_path'], '');

    await store.save(const OfficialLibraryState(books: {'g10-math': _row}));
    final conflict = await store.importJson(
      jsonEncode({
        'kind': 'thakir_official_library',
        'books': {
          'g10-math': {
            'book_id': 'g10-math',
            'download_status': 'downloaded',
            'file_path': '/other.pdf',
            'sha256': 'other-hash',
          },
        },
      }),
    );
    expect(conflict.conflicts, 1);
    expect(store.load().state.books['g10-math']?.filePath, '/books/g10-math.pdf');
  });

  test('invalid exports are rejected', () async {
    final store = OfficialLibraryStore(_MemoryStore());
    expect((await store.importJson('not json')).ok, isFalse);
    expect(
      (await store.importJson('{"kind":"other","books":{}}')).ok,
      isFalse,
    );
    expect(
      (await store.importJson(
        '{"kind":"thakir_official_library","books":[]}',
      ))
          .ok,
      isFalse,
    );
  });
}
