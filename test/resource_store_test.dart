import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_resource_paths.dart';
import 'package:zaker_ai/core/batches/local_batch_repository.dart';
import 'package:zaker_ai/core/batches/resource_store.dart';
import 'package:zaker_ai/core/key_value_store.dart';
import 'package:zaker_ai/models/batch.dart';
import 'package:zaker_ai/models/batch_resource.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FailingRepository extends LocalBatchRepository {
  _FailingRepository({required super.files, required super.store});

  @override
  Future<BatchResource> addResource(
    String uid,
    String batchId,
    BatchResource resource,
  ) async {
    throw const BatchFailure(BatchFailureCode.conflict);
  }
}

void main() {
  late Directory root;
  late Directory sources;
  late BatchFileStore files;
  late _MemoryStore store;
  late LocalBatchRepository repository;
  late Batch batch;
  late ResourceStore importer;
  const uid = 'guest-0123456789';
  final fixed = DateTime.utc(2026, 10, 25, 8);
  final pdfBytes = utf8.encode('%PDF-1.4\n');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_import_');
    sources = await Directory.systemTemp.createTemp('zaker_sources_');
    files = BatchFileStore(root: root);
    store = _MemoryStore();
    repository = LocalBatchRepository(
      files: files,
      store: store,
      codes: BatchCodeService(),
      clock: () => fixed,
    );
    batch = await repository.createBatch(
      uid: uid,
      displayName: 'طالب',
      name: 'دفعة',
      subjects: const ['رياضيات'],
    );
    importer = ResourceStore(
      files: files,
      repository: repository,
      clock: () => fixed,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
    if (await sources.exists()) await sources.delete(recursive: true);
  });

  Future<String> source(String name, List<int> bytes) async {
    final file = File(p.join(sources.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  test('copies a PDF, derives its title and records the digest', () async {
    final path = await source('ملزمة الرياضيات.pdf', pdfBytes);
    final imported = await importer.importFile(
      uid: uid,
      batchId: batch.id,
      subjectId: batch.subjects.single.id,
      kind: ResourceKind.pdf,
      sourcePath: path,
    );

    expect(imported.title, 'ملزمة الرياضيات');
    expect(imported.fileName, 'ملزمة الرياضيات.pdf');
    expect(imported.mime, 'application/pdf');
    expect(imported.sizeBytes, pdfBytes.length);
    expect(imported.sha256, sha256.convert(pdfBytes).toString());
    expect(imported.createdAt, fixed);
    expect(imported.uploaderUid, uid);

    final relativePath = BatchResourcePaths.filePath(imported);
    expect(relativePath, isNotNull);
    expect(
      await files.fileExists(
        uid: uid,
        batchId: batch.id,
        relativePath: relativePath!,
      ),
      isTrue,
    );
    final snapshot = await repository.loadBatch(uid, batch.id);
    expect(snapshot.resources.single.id, imported.id);
  });

  test('keeps an explicit title', () async {
    final path = await source('file.pdf', pdfBytes);
    final imported = await importer.importFile(
      uid: uid,
      batchId: batch.id,
      subjectId: batch.subjects.single.id,
      kind: ResourceKind.pdf,
      sourcePath: path,
      title: '  باب أول  ',
    );
    expect(imported.title, 'باب أول');
  });

  test('rejects an unsupported extension before copying anything', () async {
    final path = await source('image.png', const [1, 2, 3]);
    await expectLater(
      importer.importFile(
        uid: uid,
        batchId: batch.id,
        subjectId: batch.subjects.single.id,
        kind: ResourceKind.pdf,
        sourcePath: path,
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.unsupportedFile,
        ),
      ),
    );
    final snapshot = await repository.loadBatch(uid, batch.id);
    expect(snapshot.resources, isEmpty);
  });

  test('rejects a .pdf without the PDF header', () async {
    final path = await source('fake.pdf', utf8.encode('not a pdf'));
    await expectLater(
      importer.importFile(
        uid: uid,
        batchId: batch.id,
        subjectId: batch.subjects.single.id,
        kind: ResourceKind.pdf,
        sourcePath: path,
      ),
      throwsA(isA<BatchFailure>()),
    );
    final snapshot = await repository.loadBatch(uid, batch.id);
    expect(snapshot.resources, isEmpty);
  });

  test('imports the audio containers the player understands', () async {
    final path = await source('recording.m4a', const [1, 2, 3]);
    final imported = await importer.importFile(
      uid: uid,
      batchId: batch.id,
      subjectId: batch.subjects.single.id,
      kind: ResourceKind.audio,
      sourcePath: path,
    );
    expect(imported.kind, ResourceKind.audio);
    expect(imported.mime, 'audio/mp4');
    expect(imported.sizeBytes, 3);
  });

  test('rejects a note through importFile', () async {
    final path = await source('note.pdf', pdfBytes);
    await expectLater(
      importer.importFile(
        uid: uid,
        batchId: batch.id,
        subjectId: batch.subjects.single.id,
        kind: ResourceKind.note,
        sourcePath: path,
      ),
      throwsA(isA<BatchFailure>()),
    );
  });

  test('adds a note with the same title and note rules', () async {
    final note = await importer.addNote(
      uid: uid,
      batchId: batch.id,
      subjectId: batch.subjects.single.id,
      title: '  خلاصة  ',
      note: '  النص  ',
    );
    expect(note.title, 'خلاصة');
    expect(note.note, 'النص');
    expect(note.kind, ResourceKind.note);

    await expectLater(
      importer.addNote(
        uid: uid,
        batchId: batch.id,
        subjectId: batch.subjects.single.id,
        title: 'عنوان',
        note: '   ',
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.field,
          'field',
          'note',
        ),
      ),
    );
  });

  test('removes the copied file when the index write fails', () async {
    final failing = ResourceStore(
      files: files,
      repository: _FailingRepository(files: files, store: store),
      clock: () => fixed,
    );
    final path = await source('file.pdf', pdfBytes);
    await expectLater(
      failing.importFile(
        uid: uid,
        batchId: batch.id,
        subjectId: batch.subjects.single.id,
        kind: ResourceKind.pdf,
        sourcePath: path,
      ),
      throwsA(isA<BatchFailure>()),
    );

    final resourcesDir = Directory(
      p.join(files.batchDir(uid, batch.id).path, 'resources'),
    );
    final leftovers = await resourcesDir.exists()
        ? await resourcesDir.list().toList()
        : const <FileSystemEntity>[];
    expect(leftovers, isEmpty);
    expect((await repository.loadBatch(uid, batch.id)).resources, isEmpty);
  });
}
