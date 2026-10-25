import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_claim_service.dart';
import 'package:zaker_ai/core/batches/batch_code_service.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/local_batch_repository.dart';
import 'package:zaker_ai/core/key_value_store.dart';

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
  const guest = 'guest-0123456789';
  const account = 'user-account-1';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  late Directory root;
  late BatchFileStore files;
  late _MemoryStore store;
  late LocalBatchRepository repository;
  late BatchClaimService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_claim_');
    files = BatchFileStore(root: root);
    store = _MemoryStore();
    repository = LocalBatchRepository(
      files: files,
      store: store,
      codes: BatchCodeService(
        random: _SequenceRandom([1, 2, 3, 4, 5, 6, 7, 8]),
      ),
      clock: () => fixed,
    );
    service = BatchClaimService(repository: repository, store: store);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<String> guestBatch(String name) async {
    final batch = await repository.createBatch(
      uid: guest,
      displayName: 'طالب',
      name: name,
      subjects: const [],
    );
    return batch.id;
  }

  test('offers the guest batches that are still on the guest workspace',
      () async {
    final id = await guestBatch('دفعة الضيف');

    final offered = await service.promptBatches(
      guestUid: guest,
      accountUid: account,
    );

    expect(offered.map((batch) => batch.id), [id]);
    expect(await service.shouldPrompt(guestUid: guest, accountUid: account),
        isTrue);
    expect(
      await service.shouldPrompt(guestUid: guest, accountUid: guest),
      isFalse,
    );
  });

  test('a declined batch stops prompting, a later one still does', () async {
    final first = await guestBatch('دفعة أولى');
    await service.decline(
      guestUid: guest,
      accountUid: account,
      batchIds: [first],
    );

    expect(
      await service.promptBatches(guestUid: guest, accountUid: account),
      isEmpty,
    );

    // A different account was not declined.
    expect(
      (await service.promptBatches(
        guestUid: guest,
        accountUid: 'user-account-2',
      ))
          .length,
      1,
    );

    final second = await guestBatch('دفعة تانية');
    final offered = await service.promptBatches(
      guestUid: guest,
      accountUid: account,
    );
    expect(offered.map((batch) => batch.id), [second]);
  });

  test('claiming moves the batch and empties the prompt', () async {
    final id = await guestBatch('دفعة الضيف');

    final result = await service.claim(
      guestUid: guest,
      accountUid: account,
      batchIds: [id],
    );

    expect(result.moved, [id]);
    expect(result.failed, isEmpty);
    expect(await repository.listBatches(guest), isEmpty);
    expect((await repository.listBatches(account)).single.batchId, id);
    expect(
      await service.promptBatches(guestUid: guest, accountUid: account),
      isEmpty,
    );
  });

  test('claiming twice is safe', () async {
    final id = await guestBatch('دفعة الضيف');
    await service.claim(
      guestUid: guest,
      accountUid: account,
      batchIds: [id],
    );

    final again = await service.claim(
      guestUid: guest,
      accountUid: account,
      batchIds: [id],
    );

    expect(again.moved, [id]);
    expect((await repository.listBatches(account)).length, 1);
  });

  test('one failure does not stop the other batches', () async {
    final id = await guestBatch('دفعة الضيف');

    final result = await service.claim(
      guestUid: guest,
      accountUid: account,
      batchIds: [id, 'batch-missing'],
    );

    expect(result.moved, [id]);
    expect(result.failed.single.batchId, 'batch-missing');
    expect(result.failed.single.failure.code, BatchFailureCode.notFound);
    expect(result.movedCount, 1);
    expect(result.failedCount, 1);
  });

  test('claiming removes the id from the declined list', () async {
    final id = await guestBatch('دفعة الضيف');
    await service.decline(
      guestUid: guest,
      accountUid: account,
      batchIds: [id],
    );

    await service.claim(
      guestUid: guest,
      accountUid: account,
      batchIds: [id],
    );

    final markers = store.values['batches.claim.v1.$guest']!;
    expect(markers, isNot(contains(id)));
  });
}
