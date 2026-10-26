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
  final start = DateTime.utc(2026, 10, 25, 8);
  late DateTime now;

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
    root = await Directory.systemTemp.createTemp('zaker_admin_');
    files = BatchFileStore(root: root);
    keyValues = _MemoryStore();
    now = start;
    repository = LocalBatchRepository(
      files: files,
      store: keyValues,
      codes: BatchCodeService(
        random: _SequenceRandom([1, 2, 3, 4, 5, 6, 7, 8]),
      ),
      clock: () => now,
    );
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

  Matcher failure(BatchFailureCode code) =>
      isA<BatchFailure>().having((item) => item.code, 'code', code);

  test('the owner reads the newest audit entry first', () async {
    now = start.add(const Duration(minutes: 1));
    await repository.rotateCode(uid, batch.id);

    final entries = await repository.loadAudit(uid, batch.id);
    expect(entries, hasLength(2));
    expect(entries.first.action, 'codeRotated');
    expect(entries.last.action, 'batchCreated');
    expect(entries.first.actorUid, uid);
  });

  test('an admin reads the audit and a member is refused', () async {
    await repository.rotateCode(uid, batch.id);
    await setRole(BatchRole.admin);
    expect(await repository.loadAudit(uid, batch.id), hasLength(2));

    await setRole(BatchRole.member);
    await expectLater(
      repository.loadAudit(uid, batch.id),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
    await setRole(BatchRole.pending);
    await expectLater(
      repository.loadAudit(uid, batch.id),
      throwsA(failure(BatchFailureCode.notAuthorized)),
    );
  });

  test('an account outside the workspace reads no audit', () async {
    await expectLater(
      repository.loadAudit('guest-other', batch.id),
      throwsA(failure(BatchFailureCode.notFound)),
    );
  });

  test('a missing audit document reads as an empty list', () async {
    final path = batchStore().auditFile;
    if (await path.exists()) await path.delete();
    expect(await repository.loadAudit(uid, batch.id), isEmpty);
  });

  test('the audit keeps the newest two hundred entries', () async {
    final seeded = [
      for (var index = 0; index < 205; index++)
        AuditEntry(
          id: 'audit_seed_$index',
          batchId: batch.id,
          actorUid: uid,
          action: 'subjectAdded',
          at: start.add(Duration(minutes: index)),
        ),
    ];
    await batchStore().audit.save(seeded);

    now = start.add(const Duration(hours: 6));
    await repository.rotateCode(uid, batch.id);

    final entries = await repository.loadAudit(uid, batch.id);
    expect(entries, hasLength(LocalBatchRepository.auditCap));
    expect(entries.first.action, 'codeRotated');
    expect(
      entries.where((entry) => entry.id == 'audit_seed_0'),
      isEmpty,
    );
    expect(
      entries.where((entry) => entry.id == 'audit_seed_204'),
      hasLength(1),
    );
  });

  test('a corrupt audit document is reported, not replaced', () async {
    await files.batchDir(uid, batch.id).create(recursive: true);
    final path = batchStore().auditFile;
    await path.parent.create(recursive: true);
    await path.writeAsString('{not json');

    await expectLater(
      repository.loadAudit(uid, batch.id),
      throwsA(failure(BatchFailureCode.corruptStore)),
    );
    expect(await path.exists(), isFalse);
  });
}
