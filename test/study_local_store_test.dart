import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/study_attempt_store.dart';
import 'package:zaker_ai/core/batches/study_report_store.dart';
import 'package:zaker_ai/models/study_source.dart';

void main() {
  const uid = 'uid_1';
  const batchId = 'batch_1';
  const resourceId = 'pdf_1';
  late Directory root;
  late BatchFileStore files;
  late StudyAttemptStore attempts;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_study_attempt_');
    files = BatchFileStore(root: root);
    attempts = StudyAttemptStore(files: files);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  StudyAttempt attempt({
    String id = resourceId,
    Map<String, int>? answers,
    int correct = 1,
    int total = 2,
  }) =>
      StudyAttempt(
        resourceId: id,
        answers: answers ?? const {'q1': 0, 'q2': 1},
        correct: correct,
        total: total,
        submittedAt: DateTime.utc(2026, 10, 25, 12),
      );

  test('saves and reads the attempt for its resource', () async {
    await attempts.save(uid: uid, batchId: batchId, attempt: attempt());

    final loaded = await attempts.load(
      uid: uid,
      batchId: batchId,
      resourceId: resourceId,
    );

    expect(loaded, isNotNull);
    expect(loaded!.answers, {'q1': 0, 'q2': 1});
    expect(loaded.correct, 1);
    expect(loaded.total, 2);
    expect(loaded.submittedAt.toUtc(), DateTime.utc(2026, 10, 25, 12));
  });

  test('an attempt is private to the account that saved it', () async {
    await attempts.save(uid: uid, batchId: batchId, attempt: attempt());

    expect(
      await attempts.load(
        uid: 'uid_2',
        batchId: batchId,
        resourceId: resourceId,
      ),
      isNull,
    );
  });

  test('a stored attempt that names another resource is not trusted', () async {
    await files.writeBytes(
      uid: uid,
      batchId: batchId,
      relativePath: 'attempts/study-$resourceId.json',
      bytes: utf8.encode(jsonEncode(attempt(id: 'pdf_other').toJson())),
    );

    expect(
      await attempts.load(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
      ),
      isNull,
    );
  });

  test('corrupt attempt JSON reads as absent instead of a score', () async {
    await files.writeBytes(
      uid: uid,
      batchId: batchId,
      relativePath: 'attempts/study-$resourceId.json',
      bytes: utf8.encode('{not json'),
    );

    expect(
      await attempts.load(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
      ),
      isNull,
    );
  });

  test('clamps the score and skips invalid answers when saving', () async {
    await attempts.save(
      uid: uid,
      batchId: batchId,
      attempt: attempt(
        correct: 9,
        answers: const {'q1': 0, '../evil': 1, 'q2': -2},
      ),
    );

    final loaded = await attempts.load(
      uid: uid,
      batchId: batchId,
      resourceId: resourceId,
    );

    expect(loaded!.correct, 2);
    expect(loaded.answers, {'q1': 0});
  });

  test('refuses an empty total, an escaping id and an empty uid', () async {
    Future<void> expectRejected(
      Future<void> Function() save,
      BatchFailureCode code,
    ) async {
      await expectLater(
        save(),
        throwsA(
          isA<BatchFailure>().having(
            (failure) => failure.code,
            'code',
            code,
          ),
        ),
      );
    }

    await expectRejected(
      () => attempts.save(
        uid: uid,
        batchId: batchId,
        attempt: attempt(total: 0),
      ),
      BatchFailureCode.validationFailed,
    );
    await expectRejected(
      () => attempts.save(
        uid: uid,
        batchId: batchId,
        attempt: attempt(id: '../escape'),
      ),
      BatchFailureCode.validationFailed,
    );
    await expectRejected(
      () => attempts.save(uid: '', batchId: batchId, attempt: attempt()),
      BatchFailureCode.notAuthorized,
    );
  });

  group('report store', () {
    late StudyReportStore reports;

    setUp(() {
      reports = StudyReportStore(
        files: files,
        clock: () => DateTime.utc(2026, 10, 25, 9, 30),
      );
    });

    test('keeps the message in the batch private reports folder', () async {
      final path = await reports.save(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
        message: '  السؤال فيه غلط  ',
      );

      expect(path, startsWith('reports/study-'));
      final bytes = await files.readBytes(
        uid: uid,
        batchId: batchId,
        relativePath: path,
      );
      final json = jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>;
      expect(json['message'], 'السؤال فيه غلط');
      expect(json['resource_id'], resourceId);
      expect(json['batch_id'], batchId);
      expect(json['created_at'], '2026-10-25T09:30:00.000Z');
      expect(json.containsKey('answers'), isFalse);
    });

    test('caps a long message instead of refusing it', () async {
      final path = await reports.save(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
        message: 'x' * 2000,
      );

      final bytes = await files.readBytes(
        uid: uid,
        batchId: batchId,
        relativePath: path,
      );
      final json = jsonDecode(utf8.decode(bytes!)) as Map<String, dynamic>;
      expect(
        (json['message'] as String).length,
        StudyReportStore.maxMessageChars,
      );
    });

    test('two reports at the same instant never overwrite each other',
        () async {
      final first = await reports.save(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
        message: 'الأول',
      );
      final second = await reports.save(
        uid: uid,
        batchId: batchId,
        resourceId: resourceId,
        message: 'التاني',
      );

      expect(first, isNot(second));
      expect(
        await files.fileExists(
          uid: uid,
          batchId: batchId,
          relativePath: first,
        ),
        isTrue,
      );
      expect(
        await files.fileExists(
          uid: uid,
          batchId: batchId,
          relativePath: second,
        ),
        isTrue,
      );
    });

    test('refuses an empty message or an id that could escape the batch',
        () async {
      await expectLater(
        reports.save(
          uid: uid,
          batchId: batchId,
          resourceId: resourceId,
          message: '   ',
        ),
        throwsA(isA<BatchFailure>()),
      );
      await expectLater(
        reports.save(
          uid: uid,
          batchId: batchId,
          resourceId: '../x',
          message: 'غلط',
        ),
        throwsA(isA<BatchFailure>()),
      );
    });
  });
}
