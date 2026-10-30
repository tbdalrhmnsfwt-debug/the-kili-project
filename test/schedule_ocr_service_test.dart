import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/schedule_ocr_service.dart';
import 'package:zaker_ai/models/batch_schedule.dart';

const String _hocr = '''
<div class='ocr_page' title='image "t.png"; bbox 0 0 1000 800'>
  <span class='ocr_line' id='h' title='bbox 100 10 700 50'>
    <span class='ocrx_word' title='bbox 150 10 250 50; x_wconf 95'>السبت</span>
    <span class='ocrx_word' title='bbox 450 10 550 50; x_wconf 95'>الأحد</span>
  </span>
  <span class='ocr_line' id='r1' title='bbox 20 120 700 160'>
    <span class='ocrx_word' title='bbox 20 120 70 160; x_wconf 90'>8:00</span>
    <span class='ocrx_word' title='bbox 80 120 130 160; x_wconf 90'>9:30</span>
    <span class='ocrx_word' title='bbox 150 120 250 160; x_wconf 90'>رياضيات</span>
    <span class='ocrx_word' title='bbox 450 120 550 160; x_wconf 90'>علوم</span>
  </span>
</div>
''';

void main() {
  const uid = 'guest-test';
  const batchId = 'batch-test';
  final fixed = DateTime.utc(2026, 10, 25, 8);

  late Directory root;
  late BatchFileStore files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_schedule_ocr_');
    files = BatchFileStore(root: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> sourceFile(String name) async {
    final file = File('${root.path}/$name');
    await file.writeAsBytes(List<int>.generate(64, (index) => index));
    return file;
  }

  Directory scheduleDirectory() =>
      Directory('${files.batchDir(uid, batchId).path}/schedules');

  List<FileSystemEntity> storedPhotos() {
    final directory = scheduleDirectory();
    if (!directory.existsSync()) return const [];
    return directory.listSync();
  }

  test('imports a photo into an unpublished draft on the private path',
      () async {
    final source = await sourceFile('timetable.png');
    final service = ScheduleOcrService(
      files: files,
      readHocr: (_) async => _hocr,
      clock: () => fixed,
    );

    final draft = await service.extract(
      uid: uid,
      batchId: batchId,
      sourcePath: source.path,
    );

    expect(draft.batchId, batchId);
    expect(draft.id, startsWith('schedule_'));
    expect(draft.status, TimetableDraftStatus.draft);
    expect(draft.sourceImageFileName, 'schedules/${draft.id}.png');
    expect(draft.createdAt, fixed);
    expect(draft.ocrEngine, 'tesseract-ara+eng');
    expect(draft.entries, hasLength(2));
    expect(
      draft.entries.map((entry) => entry.title),
      ['رياضيات', 'علوم'],
    );
    final first = draft.entries.first;
    expect(first.dayOfWeek, DateTime.saturday);
    expect(first.startMinutes, 8 * 60);
    expect(first.endMinutes, 9 * 60 + 30);
    expect(first.recurrence, TimetableRecurrence.weekly);
    expect(first.timeZoneId, isNull);
    expect(
      await files.fileExists(
        uid: uid,
        batchId: batchId,
        relativePath: draft.sourceImageFileName,
      ),
      isTrue,
    );
    expect(service.lastJob?.stage, ScheduleOcrStage.done);
    expect(service.isBusy, isFalse);
  });

  test('recognises the private copy, never the picked path', () async {
    final source = await sourceFile('picked.JPG');
    String? recognisedPath;
    final service = ScheduleOcrService(
      files: files,
      readHocr: (path) async {
        recognisedPath = path;
        return _hocr;
      },
    );

    final draft = await service.extract(
      uid: uid,
      batchId: batchId,
      sourcePath: source.path,
    );

    expect(draft.sourceImageFileName, endsWith('.jpg'));
    expect(
      recognisedPath,
      files.fileInBatch(uid, batchId, draft.sourceImageFileName).path,
    );
    expect(recognisedPath, isNot(source.path));
  });

  test('refuses a file that is not an image before copying anything', () async {
    final source = await sourceFile('notes.pdf');
    final service = ScheduleOcrService(
      files: files,
      readHocr: (_) async => _hocr,
    );

    await expectLater(
      service.extract(uid: uid, batchId: batchId, sourcePath: source.path),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.unsupportedFile,
        ),
      ),
    );

    expect(service.lastJob?.stage, ScheduleOcrStage.failed);
    expect(scheduleDirectory().existsSync(), isFalse);
  });

  test('deletes the copied photo when OCR throws', () async {
    final source = await sourceFile('blurry.png');
    final service = ScheduleOcrService(
      files: files,
      readHocr: (_) async => throw StateError('engine failed'),
    );

    await expectLater(
      service.extract(uid: uid, batchId: batchId, sourcePath: source.path),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.ocrFailed,
        ),
      ),
    );

    expect(service.lastJob?.stage, ScheduleOcrStage.failed);
    expect(scheduleDirectory().existsSync(), isTrue);
    expect(storedPhotos(), isEmpty);
  });

  test('cancelling after recognition cleans up and reports cancelled',
      () async {
    final source = await sourceFile('cancel.png');
    var cancelled = false;
    final service = ScheduleOcrService(
      files: files,
      readHocr: (_) async {
        cancelled = true;
        return _hocr;
      },
    );

    await expectLater(
      service.extract(
        uid: uid,
        batchId: batchId,
        sourcePath: source.path,
        isCancelled: () => cancelled,
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.cancelled,
        ),
      ),
    );

    expect(service.lastJob?.stage, ScheduleOcrStage.cancelled);
    expect(storedPhotos(), isEmpty);
  });

  test('does not start when the caller already cancelled', () async {
    final source = await sourceFile('timetable.png');
    final service = ScheduleOcrService(
      files: files,
      readHocr: (_) async => _hocr,
    );

    await expectLater(
      service.extract(
        uid: uid,
        batchId: batchId,
        sourcePath: source.path,
        isCancelled: () => true,
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.cancelled,
        ),
      ),
    );

    expect(scheduleDirectory().existsSync(), isFalse);
  });

  test('keeps an empty draft with the parser warning instead of failing',
      () async {
    final source = await sourceFile('blank.png');
    final service = ScheduleOcrService(
      files: files,
      readHocr: (_) async => "<div class='ocr_page'></div>",
    );

    final draft = await service.extract(
      uid: uid,
      batchId: batchId,
      sourcePath: source.path,
    );

    expect(draft.entries, isEmpty);
    expect(
      draft.warnings.any((warning) => warning.contains('مفيش كلام')),
      isTrue,
    );
    expect(
      await files.fileExists(
        uid: uid,
        batchId: batchId,
        relativePath: draft.sourceImageFileName,
      ),
      isTrue,
    );
  });

  test('refuses a second import while one is running', () async {
    final source = await sourceFile('timetable.png');
    final gate = Completer<String>();
    final service = ScheduleOcrService(
      files: files,
      readHocr: (_) => gate.future,
    );

    final first = service.extract(
      uid: uid,
      batchId: batchId,
      sourcePath: source.path,
    );
    // The queued job is published synchronously, before the copy starts.
    expect(service.isBusy, isTrue);

    await expectLater(
      service.extract(uid: uid, batchId: batchId, sourcePath: source.path),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.conflict,
        ),
      ),
    );

    gate.complete(_hocr);
    final draft = await first;
    expect(draft.entries, hasLength(2));
    expect(service.isBusy, isFalse);
  });
}
