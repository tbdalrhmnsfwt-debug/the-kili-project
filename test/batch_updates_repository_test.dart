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
import 'package:zaker_ai/models/batch_update.dart';

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
  late _MemoryStore keyValues;
  late LocalBatchRepository repository;
  late Batch batch;
  const uid = 'guest-0123456789';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  LocalBatchRepository buildRepository({DateTime Function()? clock}) {
    return LocalBatchRepository(
      files: files,
      store: keyValues,
      codes: BatchCodeService(
        random: _SequenceRandom([1, 2, 3, 4, 5, 6, 7, 8]),
      ),
      clock: clock ?? () => fixed,
    );
  }

  BatchStore batchStore() =>
      BatchStore(directory: files.batchDir(uid, batch.id));

  Future<void> setRole(BatchRole role) async {
    final document = batchStore();
    final load = await document.batch.load();
    final snapshot = load.value!;
    await document.batch.save(
      snapshot.copyWith(
        members: [
          for (final member in snapshot.members)
            if (member.uid == uid)
              Membership(
                batchId: member.batchId,
                uid: member.uid,
                displayName: member.displayName,
                role: role,
                joinedAt: member.joinedAt,
              )
            else
              member,
        ],
      ),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_updates_');
    files = BatchFileStore(root: root);
    keyValues = _MemoryStore();
    repository = buildRepository();
    batch = await repository.createBatch(
      uid: uid,
      displayName: 'طالب',
      name: 'دفعة',
      subjects: const ['رياضيات'],
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Matcher failure(
    BatchFailureCode code, {
    String? field,
  }) =>
      isA<BatchFailure>()
          .having((item) => item.code, 'code', code)
          .having((item) => item.field, 'field', field);

  test('publishing trims the text and records the author', () async {
    final published = await repository.publishUpdate(
      uid,
      batch.id,
      title: '  مراجعة يوم الخميس  ',
      body: '  هنراجع الفصل الأول.  ',
    );

    expect(published.title, 'مراجعة يوم الخميس');
    expect(published.body, 'هنراجع الفصل الأول.');
    expect(published.authorUid, uid);
    expect(published.authorName, 'طالب');
    expect(published.batchId, batch.id);
    expect(published.kind, BatchUpdateKind.announcement);
    expect(published.createdAt, fixed);
    expect(published.readBy, isEmpty);

    final readBack = await repository.loadUpdates(uid, batch.id);
    expect(readBack.single.id, published.id);
    expect(readBack.single.title, 'مراجعة يوم الخميس');
  });

  test('an empty title and an overlong body are refused without writing',
      () async {
    await expectLater(
      repository.publishUpdate(uid, batch.id, title: '   ', body: ''),
      throwsA(failure(BatchFailureCode.validationFailed, field: 'title')),
    );
    await expectLater(
      repository.publishUpdate(
        uid,
        batch.id,
        title: 'عنوان',
        body: 'x' * (LocalBatchRepository.maxUpdateBodyChars + 1),
      ),
      throwsA(failure(BatchFailureCode.validationFailed, field: 'body')),
    );
    expect(await repository.loadUpdates(uid, batch.id), isEmpty);
  });

  test('members read but cannot post, edit or delete', () async {
    final published = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'مستجد',
      body: '',
    );
    await setRole(BatchRole.member);

    expect(await repository.loadUpdates(uid, batch.id), hasLength(1));
    await expectLater(
      repository.publishUpdate(uid, batch.id, title: 'تاني', body: ''),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
    await expectLater(
      repository.editUpdate(
        uid,
        batch.id,
        published.id,
        title: 'تعديل',
        body: '',
      ),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
    await expectLater(
      repository.deleteUpdate(uid, batch.id, published.id),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
    // Reading is still allowed, so opening the post can mark it read.
    final read = await repository.markUpdateRead(uid, batch.id, published.id);
    expect(read.isReadBy(uid), isTrue);
  });

  test('a muted member can read but cannot post', () async {
    final published = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'مستجد',
      body: '',
    );
    await setRole(BatchRole.muted);

    expect(await repository.loadUpdates(uid, batch.id), hasLength(1));
    expect(
      (await repository.markUpdateRead(uid, batch.id, published.id))
          .isReadBy(uid),
      isTrue,
    );
    await expectLater(
      repository.publishUpdate(uid, batch.id, title: 'تاني', body: ''),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
  });

  test('an admin may post, edit and delete', () async {
    await setRole(BatchRole.admin);
    final published = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'الأول',
      body: '',
    );

    final edited = await repository.editUpdate(
      uid,
      batch.id,
      published.id,
      title: 'الأول بعد التعديل',
      body: 'تفاصيل',
    );
    expect(edited.title, 'الأول بعد التعديل');
    expect(edited.body, 'تفاصيل');
    expect(edited.createdAt, published.createdAt);
    expect(edited.editedAt, isNotNull);

    await repository.deleteUpdate(uid, batch.id, published.id);
    expect(await repository.loadUpdates(uid, batch.id), isEmpty);
  });

  test('an unknown update is reported as missing', () async {
    await expectLater(
      repository.editUpdate(
        uid,
        batch.id,
        'update_missing',
        title: 'عنوان',
        body: '',
      ),
      throwsA(failure(BatchFailureCode.notFound, field: 'updateId')),
    );
    await expectLater(
      repository.deleteUpdate(uid, batch.id, 'update_missing'),
      throwsA(failure(BatchFailureCode.notFound, field: 'updateId')),
    );
    await expectLater(
      repository.markUpdateRead(uid, batch.id, 'update_missing'),
      throwsA(failure(BatchFailureCode.notFound, field: 'updateId')),
    );
  });

  test('marking read is idempotent and keeps the reading uid', () async {
    final published = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'مستجد',
      body: '',
    );

    final first = await repository.markUpdateRead(uid, batch.id, published.id);
    final second = await repository.markUpdateRead(uid, batch.id, published.id);

    expect(first.readBy, {uid});
    expect(second.readBy, {uid});
    final stored = await repository.loadUpdates(uid, batch.id);
    expect(stored.single.readBy, {uid});
  });

  test('the batches list counts a post until the reader opens it', () async {
    final published = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'مستجد',
      body: '',
    );

    var summary = (await repository.listBatches(uid)).single;
    expect(summary.unreadUpdates, 1);

    await repository.markUpdateRead(uid, batch.id, published.id);

    summary = (await repository.listBatches(uid)).single;
    expect(summary.unreadUpdates, 0);
  });

  test('pinned posts float above newer unpinned ones', () async {
    var minute = 0;
    repository = buildRepository(
      clock: () => fixed.add(Duration(minutes: minute++)),
    );
    final older = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'قديم',
      body: '',
    );
    final newer = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'جديد',
      body: '',
    );

    final document = batchStore();
    final load = await document.updates.load();
    await document.updates.save([
      for (final item in load.value!)
        item.id == older.id ? item.copyWith(pinned: true) : item,
    ]);

    final ordered = await repository.loadUpdates(uid, batch.id);
    expect(ordered.map((item) => item.title), ['قديم', 'جديد']);
    expect(ordered.first.pinned, isTrue);
    expect(ordered.last.id, newer.id);
  });

  test('a corrupt updates document is quarantined, not silently replaced',
      () async {
    final document = batchStore();
    await document.updatesFile.parent.create(recursive: true);
    await document.updatesFile.writeAsString('{not json');

    await expectLater(
      repository.loadUpdates(uid, batch.id),
      throwsA(failure(BatchFailureCode.corruptStore)),
    );

    final quarantined = [
      await for (final entity in document.updatesFile.parent.list())
        if (entity.path.contains('.corrupt-')) entity,
    ];
    expect(quarantined, hasLength(1));
    expect(await File(quarantined.single.path).readAsString(), '{not json');
    expect(await document.updatesFile.exists(), isFalse);

    // A later post starts a fresh document and leaves the bad copy alone.
    final published = await repository.publishUpdate(
      uid,
      batch.id,
      title: 'عنوان',
      body: '',
    );
    expect(published.title, 'عنوان');
    expect(await repository.loadUpdates(uid, batch.id), hasLength(1));
    expect(await File(quarantined.single.path).readAsString(), '{not json');
  });

  test('the document stops accepting posts at the cap', () async {
    final document = batchStore();
    await document.updates.save([
      for (var i = 0; i < LocalBatchRepository.maxUpdates; i++)
        BatchUpdate(
          id: 'update_$i',
          batchId: batch.id,
          authorUid: uid,
          authorName: 'طالب',
          title: 'مستجد $i',
          body: '',
          createdAt: fixed,
          kind: BatchUpdateKind.announcement,
        ),
    ]);

    await expectLater(
      repository.publishUpdate(uid, batch.id, title: 'زيادة', body: ''),
      throwsA(failure(BatchFailureCode.validationFailed, field: 'updates')),
    );
    final load = await document.updates.load();
    expect(load.value, hasLength(LocalBatchRepository.maxUpdates));
  });

  test('a cross-batch read is refused', () async {
    await expectLater(
      repository.loadUpdates(uid, 'someone_else'),
      throwsA(failure(BatchFailureCode.notFound)),
    );
  });

  test('the audit trail never carries the post text', () async {
    await repository.publishUpdate(
      uid,
      batch.id,
      title: 'كلمة سر الرحلة',
      body: 'تفاصيل خاصة',
    );

    final audit = await batchStore().audit.load();
    final encoded = jsonEncode([
      for (final entry in audit.value ?? const <AuditEntry>[]) entry.toJson(),
    ]);
    expect(encoded, contains('updatePublished'));
    expect(encoded, isNot(contains('كلمة سر الرحلة')));
    expect(encoded, isNot(contains('تفاصيل خاصة')));
  });
}
