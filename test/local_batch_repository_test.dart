import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
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
  final fixed = DateTime.utc(2026, 10, 25, 8);
  const uid = 'guest-0123456789';

  LocalBatchRepository repository({DateTime Function()? clock}) {
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
    root = await Directory.systemTemp.createTemp('zaker_batches_');
    files = BatchFileStore(root: root);
    store = _MemoryStore();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('create and list', () {
    test('creates an owner membership, subjects and an eight-digit code',
        () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: 'طالب',
        name: '  دفعة أولى  ',
        subjects: ['رياضيات', 'فيزياء'],
      );

      expect(batch.name, 'دفعة أولى');
      expect(batch.ownerUid, uid);
      expect(batch.codeState.code, '00000001');
      expect(batch.codeState.code.length, 8);
      expect(batch.subjects.map((s) => s.name), ['رياضيات', 'فيزياء']);
      expect(batch.subjects.map((s) => s.order), [0, 1]);
      expect(await files.batchDir(uid, batch.id).exists(), isTrue);

      final snapshot = await repo.loadBatch(uid, batch.id);
      expect(snapshot.members.single.role, BatchRole.owner);
      expect(snapshot.members.single.displayName, 'طالب');

      final summaries = await repo.listBatches(uid);
      expect(summaries.length, 1);
      expect(summaries.single.name, 'دفعة أولى');
      expect(summaries.single.isAvailable, isTrue);
      expect(summaries.single.resourceCount, 0);
      expect(store.values['batches.index.v1.$uid'], contains(batch.id));
    });

    test('rejects invalid names and subjects', () async {
      final repo = repository();
      await expectLater(
        repo.createBatch(
          uid: uid,
          displayName: '',
          name: 'x',
          subjects: const ['رياضيات'],
        ),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.invalidName,
          ),
        ),
      );
      await expectLater(
        repo.createBatch(
          uid: uid,
          displayName: '',
          name: 'دفعة',
          subjects: const [],
        ),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.invalidSubject,
          ),
        ),
      );
      await expectLater(
        repo.createBatch(
          uid: uid,
          displayName: '',
          name: 'دفعة',
          subjects: const ['Math', 'math'],
        ),
        throwsA(isA<BatchFailure>()),
      );
      expect(await repo.listBatches(uid), isEmpty);
    });

    test('rescues a batch directory that is missing from the index', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      store.values.remove('batches.index.v1.$uid');

      final summaries = await repo.listBatches(uid);
      expect(summaries.single.batchId, batch.id);
      expect(store.values['batches.index.v1.$uid'], contains(batch.id));
    });

    test('never lists another uid\'s batches or document', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      expect(await repo.listBatches('guest-other'), isEmpty);
      await expectLater(
        repo.loadBatch('guest-other', batch.id),
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

  group('subjects and settings', () {
    test('adds, renames and deletes subjects with duplicate guards', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات', 'فيزياء'],
      );
      final added = await repo.addSubject(uid, batch.id, 'كيمياء');
      expect(added.order, 2);

      await expectLater(
        repo.addSubject(uid, batch.id, 'كيمياء'),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.invalidSubject,
          ),
        ),
      );

      await repo.renameSubject(uid, batch.id, added.id, 'أحياء');
      var snapshot = await repo.loadBatch(uid, batch.id);
      expect(snapshot.batch.subjects.last.name, 'أحياء');

      await expectLater(
        repo.renameSubject(
          uid,
          batch.id,
          added.id,
          snapshot.batch.subjects.first.name,
        ),
        throwsA(isA<BatchFailure>()),
      );

      await repo.deleteSubject(uid, batch.id, added.id);
      snapshot = await repo.loadBatch(uid, batch.id);
      expect(snapshot.batch.subjects.map((s) => s.name), ['رياضيات', 'فيزياء']);
      expect(snapshot.batch.subjects.map((s) => s.order), [0, 1]);
    });

    test('refuses to delete a subject that still has resources', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      final subject = batch.subjects.single;
      final batchStore = BatchStore(directory: files.batchDir(uid, batch.id));
      final snapshot = await repo.loadBatch(uid, batch.id);
      await batchStore.batch.save(
        snapshot.copyWith(
          resources: [
            BatchResource(
              id: 'r1',
              batchId: batch.id,
              subjectId: subject.id,
              kind: ResourceKind.pdf,
              title: 'ملزمة',
              uploaderUid: uid,
              createdAt: fixed,
            ),
          ],
        ),
      );

      await expectLater(
        repo.deleteSubject(uid, batch.id, subject.id),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            BatchFailureCode.validationFailed,
          ),
        ),
      );
    });

    test('persists settings and touches last activity', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      final later = fixed.add(const Duration(hours: 2));
      final updated = await repository(clock: () => later).updateSettings(
        uid,
        batch.id,
        const BatchSettings(
          uploadsAdminOnly: false,
          notificationDetail: BatchNotificationDetail.titled,
        ),
      );
      expect(updated.settings.uploadsAdminOnly, isFalse);
      expect(
        updated.settings.notificationDetail,
        BatchNotificationDetail.titled,
      );
      expect(updated.lastActivityAt, later);
    });
  });

  group('invite code lifecycle', () {
    test('rotates to a new code and revokes it', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      expect(batch.codeState.code, '00000001');

      final rotated = await repo.rotateCode(uid, batch.id);
      expect(rotated.code, '00000002');
      expect(rotated.rotationCount, 1);
      expect(rotated.isActive, isTrue);

      final revoked = await repo.revokeCode(uid, batch.id);
      expect(revoked.isActive, isFalse);
      expect(revoked.revokedAt, isNotNull);

      final again = await repo.rotateCode(uid, batch.id);
      expect(again.code, isNot(rotated.code));
      expect(again.isActive, isTrue);
      expect(again.rotationCount, 2);

      final ledger = jsonDecode(
        store.values['batches.codes.v1.$uid']!,
      ) as Map<String, dynamic>;
      final hashes = (ledger['hashes'] as List).cast<String>();
      expect(hashes.length, 3);
      expect(
        hashes.contains(BatchCodeService.codeHash(again.code)),
        isTrue,
      );
      expect(store.values.toString(), isNot(contains(again.code)));
    });
  });

  group('deletion', () {
    test('removes the document, files and index entry', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      await repo.deleteBatch(uid, batch.id);

      expect(await files.batchDir(uid, batch.id).exists(), isFalse);
      expect(await repo.listBatches(uid), isEmpty);
      await expectLater(
        repo.loadBatch(uid, batch.id),
        throwsA(isA<BatchFailure>()),
      );
    });

    test('deletes a batch whose document is from a newer schema', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      final snapshot = await repo.loadBatch(uid, batch.id);
      final file = BatchStore(
        directory: files.batchDir(uid, batch.id),
      ).batchFile;
      await file.writeAsString(
        jsonEncode({'schema': 2, ...snapshot.toJson()}),
      );

      final summaries = await repo.listBatches(uid);
      expect(summaries.single.isAvailable, isFalse);
      expect(
        summaries.single.failure!.code,
        BatchFailureCode.migrationUnsupported,
      );

      await repo.deleteBatch(uid, batch.id);
      expect(await files.batchDir(uid, batch.id).exists(), isFalse);
    });
  });

  group('corruption scope', () {
    test('a corrupt updates document does not take down the batch', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'دفعة',
        subjects: const ['رياضيات'],
      );
      final updates = BatchStore(
        directory: files.batchDir(uid, batch.id),
      ).updatesFile;
      await updates.parent.create(recursive: true);
      await updates.writeAsString('{oops');

      final summaries = await repo.listBatches(uid);
      expect(summaries.single.isAvailable, isTrue);
      expect(summaries.single.unreadUpdates, 0);
      expect((await repo.loadBatch(uid, batch.id)).batch.name, 'دفعة');
    });

    test('recovers the batch document from its backup', () async {
      final repo = repository();
      final batch = await repo.createBatch(
        uid: uid,
        displayName: '',
        name: 'الاسم الأول',
        subjects: const ['رياضيات'],
      );
      await repo.updateSettings(
        uid,
        batch.id,
        const BatchSettings(uploadsAdminOnly: false),
      );
      final storeFile = BatchStore(
        directory: files.batchDir(uid, batch.id),
      ).batchFile;
      await storeFile.writeAsString('{corrupt');

      final snapshot = await repo.loadBatch(uid, batch.id);
      expect(snapshot.batch.name, 'الاسم الأول');
      // The recovered document is the one saved before the last change.
      expect(snapshot.batch.settings.uploadsAdminOnly, isTrue);

      final summaries = await repo.listBatches(uid);
      expect(summaries.single.isAvailable, isTrue);
    });
  });
}
