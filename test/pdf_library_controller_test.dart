import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/key_value_store.dart';
import '../lib/core/pdf/pdf_library_controller.dart';
import '../lib/core/pdf/pdf_library_repository.dart';
import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/core/pdf/pdf_render_channel.dart';
import '../lib/models/pdf_document.dart';

class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

PdfImportSource source(String name, String body) => PdfImportSource(
      name: name,
      sizeBytes: body.length,
      openRead: () => Stream.value(body.codeUnits),
    );

void main() {
  late Directory root;
  late Directory cache;
  late PdfLibraryStore store;
  late MemoryStore keyValues;
  var ids = 0;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_pdf_root_');
    cache = Directory.systemTemp.createTempSync('zaker_pdf_cache_');
    store = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await store.ensureReady();
    keyValues = MemoryStore();
    ids = 0;
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  PdfLibraryController controller({
    PdfProbe? probe,
    PdfThumbnailer? thumbnailer,
  }) {
    return PdfLibraryController(
      store: store,
      repository: PdfLibraryRepository(keyValues),
      probe: probe ?? (file) async => const PdfProbeResult(pageCount: 4),
      thumbnailer: thumbnailer ??
          (base, thumb) async => thumb.writeAsBytes(const [1, 2, 3]),
      newId: () => 'id${++ids}',
    );
  }

  test('importing a PDF records, persists and probes it', () async {
    final lib = controller();
    final result = await lib.import([source('محاضرة.pdf', '%PDF-1.7 body')]);

    expect(result.failures, isEmpty);
    expect(result.imported, hasLength(1));
    final entry = result.imported.single;
    expect(entry.displayName, 'محاضرة');
    expect(entry.pageCount, 4);
    expect(entry.encryption, PdfEncryptionState.no);
    expect(store.baseFile(entry.id).existsSync(), isTrue);
    expect(store.thumbFile(entry.id).existsSync(), isTrue);

    final persisted = PdfLibraryRepository(keyValues).load();
    expect(persisted.entries.single.id, entry.id);
    expect(lib.state.entries.single.id, entry.id);
  });

  test('a non-PDF source fails without creating an entry', () async {
    final lib = controller();
    final result = await lib.import([source('notes.pdf', 'hello')]);

    expect(result.imported, isEmpty);
    expect(result.failures, [PdfImportFailure.invalidHeader]);
    expect(lib.state.entries, isEmpty);
    expect(PdfLibraryRepository(keyValues).load().entries, isEmpty);
  });

  test('an encrypted import keeps the entry without a thumbnail', () async {
    final lib = controller(
      probe: (file) async => const PdfProbeResult(encrypted: true),
    );
    final result = await lib.import([source('locked.pdf', '%PDF-1.7')]);

    final entry = result.imported.single;
    expect(entry.pageCount, isNull);
    expect(entry.encryption, PdfEncryptionState.yes);
    expect(store.thumbFile(entry.id).existsSync(), isFalse);
  });

  test('a probe that demands a password keeps the entry encrypted', () async {
    final lib = controller(
      probe: (file) async =>
          throw const PdfRenderException(PdfRenderFailure.passwordRequired),
    );
    final result = await lib.import([source('locked.pdf', '%PDF-1.7')]);

    final entry = result.imported.single;
    expect(entry.pageCount, isNull);
    expect(entry.encryption, PdfEncryptionState.yes);
    expect(store.thumbFile(entry.id).existsSync(), isFalse);
  });

  test('refresh keeps entries whose base file is gone', () async {
    final lib = controller();
    final entry =
        (await lib.import([source('a.pdf', '%PDF-1.7 a')])).imported.single;

    await store.baseFile(entry.id).delete();
    await lib.refresh();

    expect(lib.state.entries.single.id, entry.id);
    expect(PdfLibraryRepository(keyValues).load().entries.single.id, entry.id);
  });

  test('last read page survives a fresh controller', () async {
    final first = controller();
    final entry =
        (await first.import([source('a.pdf', '%PDF-1.7 a')])).imported.single;
    await first.markOpened(entry.id, page: 7);

    final second = controller();
    await second.refresh();

    expect(second.state.entries.single.lastPage, 7);
  });

  test('rename and favorite persist, remove deletes the files', () async {
    final lib = controller();
    final entry =
        (await lib.import([source('a.pdf', '%PDF-1.7 a')])).imported.single;

    await lib.rename(entry.id, 'اسم جديد');
    await lib.setFavorite(entry.id, true);
    final saved = PdfLibraryRepository(keyValues).load().entries.single;
    expect(saved.displayName, 'اسم جديد');
    expect(saved.favorite, isTrue);

    await lib.remove(entry.id);
    expect(lib.state.entries, isEmpty);
    expect(store.baseFile(entry.id).existsSync(), isFalse);
    expect(PdfLibraryRepository(keyValues).load().entries, isEmpty);
  });

  test('subject tags persist and can be cleared', () async {
    final lib = controller();
    final entry = (await lib.import([source('درس.pdf', '%PDF-1.7 body')]))
        .imported
        .single;

    await lib.setSubjectTag(
      entry.id,
      gradeId: 'sec1',
      subjectKey: 'الرياضيات',
    );
    expect(lib.state.entries.single.subjectKey, 'الرياضيات');
    expect(lib.state.entries.single.gradeId, 'sec1');

    final reloaded = PdfLibraryRepository(keyValues).load().entries.single;
    expect(reloaded.subjectKey, 'الرياضيات');

    await lib.clearSubjectTag(entry.id);
    expect(lib.state.entries.single.subjectKey, isEmpty);
    expect(lib.state.entries.single.gradeId, isEmpty);
  });

  test('old entries without tags load with empty strings', () {
    final json = {
      'id': 'p9',
      'name': 'قديم',
      'base': 'p9.pdf',
      'size': 10,
      'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
    };
    final entry = PdfDocumentEntry.fromJson(json);
    expect(entry.subjectKey, isEmpty);
    expect(entry.gradeId, isEmpty);
    expect(entry.sourceDocId, isEmpty);
  });

  test('markOpened keeps the zoom and rotation the reader restored', () async {
    final lib = controller();
    await lib.import([source('a.pdf', '%PDF-1.7 body')]);
    final id = lib.state.entries.single.id;

    await lib.markOpened(id, page: 4, zoom: 2.5, quarterTurns: 1);

    final entry = lib.state.entryById(id)!;
    expect(entry.lastPage, 4);
    expect(entry.lastZoom, 2.5);
    expect(entry.lastQuarterTurns, 1);
  });

  test('an entry round-trips its reading position through JSON', () {
    final entry = PdfDocumentEntry(
      id: 'a',
      displayName: 'ملف',
      baseFileName: 'a.pdf',
      sizeBytes: 10,
      addedAt: DateTime.utc(2026, 1, 1),
    ).copyWith(lastZoom: 3, lastQuarterTurns: 2);

    final restored = PdfDocumentEntry.fromJson(entry.toJson());

    expect(restored.lastZoom, 3);
    expect(restored.lastQuarterTurns, 2);
  });

  test('a stored zoom outside 1..5 is clamped on load', () {
    final json = PdfDocumentEntry(
      id: 'a',
      displayName: 'ملف',
      baseFileName: 'a.pdf',
      sizeBytes: 10,
      addedAt: DateTime.utc(2026, 1, 1),
    ).toJson()
      ..['lastZoom'] = 9.0
      ..['lastQuarterTurns'] = 6;

    final restored = PdfDocumentEntry.fromJson(json);

    expect(restored.lastZoom, 5);
    expect(restored.lastQuarterTurns, 2);
  });
}
