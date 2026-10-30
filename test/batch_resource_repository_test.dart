import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_resource_paths.dart';
import 'package:zaker_ai/core/batches/batch_store.dart';
import 'package:zaker_ai/core/batches/local_batch_repository.dart';
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

class _SequenceRandom implements Random {
  _SequenceRandom(this.values);

  final List<int> values;
  int _index = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    final value = values[_index % values.length];
    _index++;
    return value % max;
  }
}

void main() {
  late Directory root;
  late BatchFileStore files;
  late _MemoryStore store;
  late LocalBatchRepository repository;
  late Batch batch;
  const uid = 'guest-0123456789';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  LocalBatchRepository buildRepository({DateTime Function()? clock}) {
    return LocalBatchRepository(
      files: files,
      store: store,
      codes: BatchCodeService(
        random: _SequenceRandom([1, 2, 3, 4, 5, 6, 7, 8]),
      ),
      clock: clock ?? () => fixed,
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_resources_');
    files = BatchFileStore(root: root);
    store = _MemoryStore();
    repository = buildRepository();
    batch = await repository.createBatch(
      uid: uid,
      displayName: 'طالب',
      name: 'دفعة',
      subjects: const ['رياضيات', 'فيزياء'],
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  BatchResource pdf(
    String id, {
    String? subjectId,
    String title = 'ملزمة',
  }) {
    return BatchResource(
      id: id,
      batchId: batch.id,
      subjectId: subjectId ?? batch.subjects.first.id,
      kind: ResourceKind.pdf,
      title: title,
      fileName: '$id.pdf',
      mime: 'application/pdf',
      sizeBytes: 12,
      uploaderUid: uid,
      createdAt: fixed,
    );
  }

  Future<List<String>> auditActions() async {
    final audit = await BatchStore(
      directory: files.batchDir(uid, batch.id),
    ).audit.load();
    return [for (final entry in audit.value ?? const []) entry.action];
  }

  group('addResource', () {
    test('trims the title and persists the record', () async {
      final saved = await repository.addResource(
        uid,
        batch.id,
        pdf('res-1', title: '  ملزمة  '),
      );

      expect(saved.title, 'ملزمة');
      final snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.resources.single.id, 'res-1');
      expect(snapshot.resources.single.createdAt, fixed);
      expect(await auditActions(), contains('resourceAdded'));
    });

    test('rejects malformed records without writing them', () async {
      await expectLater(
        repository.addResource(uid, batch.id, pdf('res-1')),
        completes,
      );
      await expectLater(
        repository.addResource(uid, batch.id, pdf('res-1')),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.conflict,
          ),
        ),
      );
      await expectLater(
        repository.addResource(
          uid,
          batch.id,
          pdf('res-2', subjectId: 'subject-missing'),
        ),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.notFound,
          ),
        ),
      );
      await expectLater(
        repository.addResource(
          uid,
          batch.id,
          pdf('res-3').copyWith(title: '   '),
        ),
        throwsA(isA<BatchFailure>()),
      );
      await expectLater(
        repository.addResource(
          uid,
          batch.id,
          pdf('res-4').copyWith(fileName: 'notes.txt'),
        ),
        throwsA(isA<BatchFailure>()),
      );
      await expectLater(
        repository.addResource(
          uid,
          batch.id,
          pdf('res-5').copyWith(sizeBytes: 0),
        ),
        throwsA(isA<BatchFailure>()),
      );

      final snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.resources.map((item) => item.id), ['res-1']);
    });

    test('validates and trims text notes', () async {
      final note = BatchResource(
        id: 'note-1',
        batchId: batch.id,
        subjectId: batch.subjects.first.id,
        kind: ResourceKind.note,
        title: '  خلاصة  ',
        note: '  نص الملاحظة  ',
        uploaderUid: uid,
        createdAt: fixed,
      );
      final saved = await repository.addResource(uid, batch.id, note);
      expect(saved.title, 'خلاصة');
      expect(saved.note, 'نص الملاحظة');

      await expectLater(
        repository.addResource(
          uid,
          batch.id,
          note.copyWith(note: '   '),
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
  });

  group('setStarred', () {
    test('toggles this account only and leaves last activity alone', () async {
      await repository.addResource(uid, batch.id, pdf('res-1'));
      final before =
          (await repository.loadBatch(uid, batch.id)).batch.lastActivityAt;
      final later = fixed.add(const Duration(hours: 2));

      final starred = await buildRepository(clock: () => later).setStarred(
        uid,
        batch.id,
        'res-1',
        true,
      );
      expect(starred.starredBy, {uid});
      var snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.resources.single.starredBy, {uid});
      expect(snapshot.batch.lastActivityAt, before);

      await repository.setStarred(uid, batch.id, 'res-1', false);
      snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.resources.single.starredBy, isEmpty);
      expect(
        await auditActions(),
        containsAll(['resourceStarred', 'resourceUnstarred']),
      );
    });

    test('reports a missing resource', () async {
      await expectLater(
        repository.setStarred(uid, batch.id, 'res-missing', true),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.notFound,
          ),
        ),
      );
    });
  });

  group('deleteResource', () {
    test('removes the index entry, file, thumbnail and text cache', () async {
      final sha = List.filled(64, 'a').join();
      await repository.addResource(
        uid,
        batch.id,
        pdf('res-1').copyWith(sha256: sha),
      );
      await files.writeBytes(
        uid: uid,
        batchId: batch.id,
        relativePath: 'resources/res-1.pdf',
        bytes: const [1, 2, 3],
      );
      await files.writeBytes(
        uid: uid,
        batchId: batch.id,
        relativePath: BatchResourcePaths.thumbnailPath('res-1'),
        bytes: const [4, 5],
      );
      await files.writeBytes(
        uid: uid,
        batchId: batch.id,
        relativePath: BatchResourcePaths.textCachePath(sha),
        bytes: const [6],
      );

      await repository.deleteResource(uid, batch.id, 'res-1');

      final snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.resources, isEmpty);
      expect(
        await files.fileExists(
          uid: uid,
          batchId: batch.id,
          relativePath: 'resources/res-1.pdf',
        ),
        isFalse,
      );
      expect(
        await files.fileExists(
          uid: uid,
          batchId: batch.id,
          relativePath: BatchResourcePaths.thumbnailPath('res-1'),
        ),
        isFalse,
      );
      expect(
        await files.fileExists(
          uid: uid,
          batchId: batch.id,
          relativePath: BatchResourcePaths.textCachePath(sha),
        ),
        isFalse,
      );
      expect(await auditActions(), contains('resourceDeleted'));
    });
  });

  group('deleteSubject with resources', () {
    test('moves the resources when another subject is chosen', () async {
      final target = batch.subjects[1];
      await repository.addResource(
        uid,
        batch.id,
        pdf('res-1', subjectId: target.id),
      );
      await repository.addResource(uid, batch.id, pdf('res-2'));
      await files.writeBytes(
        uid: uid,
        batchId: batch.id,
        relativePath: 'resources/res-2.pdf',
        bytes: const [1],
      );

      await repository.deleteSubject(
        uid,
        batch.id,
        batch.subjects.first.id,
        moveToSubjectId: target.id,
      );

      final snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.batch.subjects.single.id, target.id);
      expect(snapshot.batch.subjects.single.order, 0);
      expect(
        snapshot.resources.every((item) => item.subjectId == target.id),
        isTrue,
      );
      expect(snapshot.resources.map((item) => item.id), ['res-1', 'res-2']);
      expect(
        await files.fileExists(
          uid: uid,
          batchId: batch.id,
          relativePath: 'resources/res-2.pdf',
        ),
        isTrue,
      );
      expect(await auditActions(), contains('subjectDeleted'));
    });

    test('deletes the files only when the owner chooses to', () async {
      final other = batch.subjects[1];
      await repository.addResource(uid, batch.id, pdf('res-1'));
      await repository.addResource(
        uid,
        batch.id,
        pdf('res-2', subjectId: other.id),
      );
      await files.writeBytes(
        uid: uid,
        batchId: batch.id,
        relativePath: 'resources/res-1.pdf',
        bytes: const [1],
      );

      await repository.deleteSubject(
        uid,
        batch.id,
        batch.subjects.first.id,
        deleteResources: true,
      );

      final snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.batch.subjects.single.id, other.id);
      expect(snapshot.resources.map((item) => item.id), ['res-2']);
      expect(
        await files.fileExists(
          uid: uid,
          batchId: batch.id,
          relativePath: 'resources/res-1.pdf',
        ),
        isFalse,
      );
    });

    test('refuses to drop the resources silently', () async {
      await repository.addResource(uid, batch.id, pdf('res-1'));
      await expectLater(
        repository.deleteSubject(
          uid,
          batch.id,
          batch.subjects.first.id,
        ),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.validationFailed,
          ),
        ),
      );
      final snapshot = await repository.loadBatch(uid, batch.id);
      expect(snapshot.resources, hasLength(1));
      expect(snapshot.batch.subjects, hasLength(2));
    });
  });
}
