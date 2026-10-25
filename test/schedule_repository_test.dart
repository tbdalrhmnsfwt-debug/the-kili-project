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
import 'package:zaker_ai/models/batch_schedule.dart';

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

  Future<void> demoteToMember() async {
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
                role: BatchRole.member,
                joinedAt: member.joinedAt,
              )
            else
              member,
        ],
      ),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_schedules_');
    files = BatchFileStore(root: root);
    keyValues = _MemoryStore();
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

  TimetableEntry entry({
    String id = 'slot-1',
    String title = 'رياضيات',
    int start = 8 * 60,
    int end = 9 * 60,
    int day = DateTime.saturday,
    String? subjectId,
  }) {
    return TimetableEntry(
      id: id,
      dayOfWeek: day,
      startMinutes: start,
      endMinutes: end,
      title: title,
      subjectId: subjectId,
      confidence: 0.9,
      recurrence: TimetableRecurrence.weekly,
    );
  }

  TimetableDraft draftFor({
    String id = 'schedule-test',
    List<TimetableEntry>? entries,
    TimetableDraftStatus status = TimetableDraftStatus.draft,
    String? imagePath,
    String? batchId,
    List<String> warnings = const ['راجع الحصص قبل النشر.'],
  }) {
    return TimetableDraft(
      id: id,
      batchId: batchId ?? batch.id,
      sourceImageFileName: imagePath ?? 'schedules/$id.png',
      createdAt: fixed,
      updatedAt: fixed,
      status: status,
      entries: entries ?? [entry()],
      warnings: warnings,
    );
  }

  test('saves a draft and reads it back from disk', () async {
    final saved = await repository.saveScheduleDraft(uid, batch.id, draftFor());

    expect(saved.status, TimetableDraftStatus.draft);
    expect(saved.createdAt, fixed);
    expect(saved.updatedAt, fixed);
    expect(saved.entries.single.title, 'رياضيات');

    // A fresh instance proves the draft came from the document, not memory.
    final reopened = buildRepository();
    final loaded = await reopened.loadSchedules(uid, batch.id);
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'schedule-test');
    expect(loaded.single.entries.single.startMinutes, 8 * 60);

    final audit = await batchStore().audit.load();
    expect(
      [for (final item in audit.value ?? const []) item.action],
      contains('scheduleSaved'),
    );
  });

  test('updating a draft replaces it instead of adding a duplicate', () async {
    await repository.saveScheduleDraft(uid, batch.id, draftFor());
    final updated = await repository.saveScheduleDraft(
      uid,
      batch.id,
      draftFor(entries: [entry(title: 'علوم')]),
    );

    expect(updated.entries.single.title, 'علوم');
    final loaded = await repository.loadSchedules(uid, batch.id);
    expect(loaded, hasLength(1));
    expect(loaded.single.entries.single.title, 'علوم');
    expect(loaded.single.createdAt, fixed);
  });

  test('loads the newest updated draft first', () async {
    var now = fixed;
    final clocked = buildRepository(clock: () => now);
    await clocked.saveScheduleDraft(uid, batch.id, draftFor(id: 'older'));
    now = fixed.add(const Duration(hours: 1));
    await clocked.saveScheduleDraft(uid, batch.id, draftFor(id: 'newer'));

    final loaded = await clocked.loadSchedules(uid, batch.id);
    expect(
      [for (final draft in loaded) draft.id],
      ['newer', 'older'],
    );
  });

  test('trims stored lines and drops unusable uncertainty labels', () async {
    final saved = await repository.saveScheduleDraft(
      uid,
      batch.id,
      draftFor(
        entries: [
          TimetableEntry(
            id: 'slot-1',
            dayOfWeek: DateTime.saturday,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60,
            title: '  رياضيات  ',
            room: '  قاعة\t2 ',
            uncertainFields: ['  الوقت  ', '', 'x' * 41],
          ),
        ],
        warnings: ['  سطر\nواحد  ', '   '],
      ),
    );

    final entry = saved.entries.single;
    expect(entry.title, 'رياضيات');
    expect(entry.room, 'قاعة 2');
    expect(entry.uncertainFields, ['الوقت']);
    expect(saved.warnings, ['سطر واحد']);
  });

  test('rejects an end before the start', () async {
    await expectLater(
      repository.saveScheduleDraft(
        uid,
        batch.id,
        draftFor(entries: [entry(start: 10 * 60, end: 9 * 60)]),
      ),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.validationFailed)
            .having((f) => f.field, 'field', 'times'),
      ),
    );

    expect(await repository.loadSchedules(uid, batch.id), isEmpty);
  });

  test('rejects a blank title', () async {
    await expectLater(
      repository.saveScheduleDraft(
        uid,
        batch.id,
        draftFor(entries: [entry(title: '   ')]),
      ),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.validationFailed)
            .having((f) => f.field, 'field', 'title'),
      ),
    );
  });

  test('rejects a subject that is not part of the batch', () async {
    await expectLater(
      repository.saveScheduleDraft(
        uid,
        batch.id,
        draftFor(entries: [entry(subjectId: 'subject-missing')]),
      ),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.notFound)
            .having((f) => f.field, 'field', 'subjectId'),
      ),
    );
  });

  test('refuses a draft that names another batch', () async {
    await expectLater(
      repository.saveScheduleDraft(
        uid,
        batch.id,
        draftFor(batchId: 'other-batch'),
      ),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.validationFailed)
            .having((f) => f.field, 'field', 'batchId'),
      ),
    );
  });

  test('refuses a source image path outside the private schedules folder',
      () async {
    await expectLater(
      repository.saveScheduleDraft(
        uid,
        batch.id,
        draftFor(imagePath: 'schedules/../escape.png'),
      ),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.validationFailed)
            .having((f) => f.field, 'field', 'sourceImageFileName'),
      ),
    );
  });

  test('members may read the timetable but not change it', () async {
    await repository.saveScheduleDraft(uid, batch.id, draftFor());
    await demoteToMember();

    expect(await repository.loadSchedules(uid, batch.id), hasLength(1));

    await expectLater(
      repository.saveScheduleDraft(
        uid,
        batch.id,
        draftFor(id: 'member-draft'),
      ),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.notAuthorized),
      ),
    );
    await expectLater(
      repository.publishScheduleDraft(uid, batch.id, 'schedule-test'),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.notAuthorized),
      ),
    );
    await expectLater(
      repository.deleteScheduleDraft(uid, batch.id, 'schedule-test'),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.notAuthorized),
      ),
    );
  });

  test('publishing refuses an unfinished row', () async {
    // End equal to start is what the OCR parser emits when a row has no end.
    await repository.saveScheduleDraft(
      uid,
      batch.id,
      draftFor(entries: [entry(end: 8 * 60)]),
    );

    await expectLater(
      repository.publishScheduleDraft(uid, batch.id, 'schedule-test'),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.validationFailed)
            .having((f) => f.field, 'field', 'entries')
            .having((f) => f.detail, 'detail', 'incomplete rows'),
      ),
    );

    final loaded = await repository.loadSchedules(uid, batch.id);
    expect(loaded.single.status, TimetableDraftStatus.draft);
  });

  test('publishing an empty draft is refused', () async {
    await repository.saveScheduleDraft(
      uid,
      batch.id,
      draftFor(entries: const []),
    );

    await expectLater(
      repository.publishScheduleDraft(uid, batch.id, 'schedule-test'),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.validationFailed)
            .having((f) => f.field, 'field', 'entries'),
      ),
    );
  });

  test('publishes a complete draft and keeps it published', () async {
    await repository.saveScheduleDraft(uid, batch.id, draftFor());

    final published = await repository.publishScheduleDraft(
      uid,
      batch.id,
      'schedule-test',
    );

    expect(published.status, TimetableDraftStatus.published);
    final loaded = await repository.loadSchedules(uid, batch.id);
    expect(loaded.single.status, TimetableDraftStatus.published);
  });

  test('deleting a draft removes its private photo too', () async {
    const relative = 'schedules/schedule-test.png';
    await files.writeBytes(
      uid: uid,
      batchId: batch.id,
      relativePath: relative,
      bytes: const [1, 2, 3, 4],
    );
    await repository.saveScheduleDraft(uid, batch.id, draftFor());

    await repository.deleteScheduleDraft(uid, batch.id, 'schedule-test');

    expect(await repository.loadSchedules(uid, batch.id), isEmpty);
    expect(
      await files.fileExists(
        uid: uid,
        batchId: batch.id,
        relativePath: relative,
      ),
      isFalse,
    );
  });

  test('deleting an unknown draft is reported as missing', () async {
    await expectLater(
      repository.deleteScheduleDraft(uid, batch.id, 'schedule-unknown'),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.notFound)
            .having((f) => f.field, 'field', 'draftId'),
      ),
    );
  });

  test('an unreadable timetable document is reported and kept for diagnosis',
      () async {
    final document = batchStore();
    await document.schedulesFile.parent.create(recursive: true);
    await document.schedulesFile.writeAsString('not json');

    await expectLater(
      repository.loadSchedules(uid, batch.id),
      throwsA(
        isA<BatchFailure>()
            .having((f) => f.code, 'code', BatchFailureCode.corruptStore),
      ),
    );

    // Loading quarantines the bad primary instead of deleting it.
    final quarantined = [
      await for (final entity in document.schedulesFile.parent.list())
        if (entity.path.contains('.corrupt-')) entity,
    ];
    expect(quarantined, hasLength(1));
    expect(await File(quarantined.single.path).readAsString(), 'not json');
    expect(await document.schedulesFile.exists(), isFalse);

    // With the bad document set aside, the next explicit save starts a fresh
    // document and still leaves the quarantined copy untouched.
    final saved = await repository.saveScheduleDraft(uid, batch.id, draftFor());
    expect(saved.id, 'schedule-test');
    expect(await File(quarantined.single.path).readAsString(), 'not json');
  });
}
