import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/batch_file_store.dart';
import 'package:zaker_ai/core/batches/batch_resource_paths.dart';
import 'package:zaker_ai/core/batches/study_source_extractor.dart';
import 'package:zaker_ai/core/book_extraction.dart';
import 'package:zaker_ai/models/batch_resource.dart';
import 'package:zaker_ai/models/study_source.dart';

const _textOne = 'الطاقة الحركية تساوي نصف الكتلة مضروبة في مربع السرعة.';
const _textTwo = 'القوة مؤثر يغير من حالة حركة الجسم أو شكله في الاتجاه.';

class _FakePageSource implements PdfPageSource {
  _FakePageSource(this.pages, {this.gate});

  final List<String> pages;
  final Future<void>? gate;
  int readCount = 0;
  bool closed = false;

  @override
  int get pageCount => pages.length;

  @override
  Future<String> readPage(int pageIndex) async {
    final pending = gate;
    if (pending != null) await pending;
    readCount++;
    return pages[pageIndex];
  }

  @override
  void close() => closed = true;
}

class _FakeOcr implements PageOcrEngine {
  _FakeOcr(this.text);

  final String text;
  int calls = 0;

  @override
  String? languageTag(String bookLanguage) => 'ara+eng';

  @override
  Future<String> recognizePage(
    File pdf,
    int pageIndex,
    String tesseractLanguage,
  ) async {
    calls++;
    return text;
  }
}

void main() {
  const uid = 'uid_1';
  const batchId = 'batch_1';
  late Directory root;
  late BatchFileStore files;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_study_');
    files = BatchFileStore(root: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  BatchResource resource({
    String id = 'res_1',
    String sha = 'sha-1234567890abcdef',
  }) =>
      BatchResource(
        id: id,
        batchId: batchId,
        subjectId: 'sub_1',
        kind: ResourceKind.pdf,
        title: 'ملزمة الفيزياء',
        fileName: 'physics.pdf',
        sizeBytes: 32,
        uploaderUid: uid,
        createdAt: DateTime.utc(2026, 10, 25),
        sha256: sha,
      );

  Future<void> writePdf(BatchResource item, {String body = '%PDF-1.7'}) {
    return files.writeBytes(
      uid: uid,
      batchId: batchId,
      relativePath: BatchResourcePaths.filePath(item)!,
      bytes: utf8.encode(body),
    );
  }

  StudySourceExtractor build({
    PdfPageSourceFactory? openPdf,
    PageOcrEngine? ocr,
    Future<bool> Function(File)? isEncrypted,
    int maxOcrPages = 50,
    int maxPages = 500,
    int maxBytes = 100 * 1024 * 1024,
  }) {
    return StudySourceExtractor(
      files: files,
      openPdf: openPdf,
      ocr: ocr,
      isEncrypted: isEncrypted ?? (_) async => false,
      maxOcrPages: maxOcrPages,
      maxPages: maxPages,
      maxBytes: maxBytes,
      clock: () => DateTime.utc(2026, 10, 25, 9, 30),
    );
  }

  Future<bool> cacheExists(BatchResource item) {
    return files.fileExists(
      uid: uid,
      batchId: batchId,
      relativePath: BatchResourcePaths.textCachePath(item.sha256),
    );
  }

  test('extracts page text, closes the reader and caches by sha', () async {
    final item = resource();
    await writePdf(item);
    final source = _FakePageSource([_textOne]);
    var opens = 0;
    final study = build(
      openPdf: (file) async {
        opens++;
        return source;
      },
    );

    final document = await study.extract(uid: uid, resource: item);

    expect(document.resourceId, item.id);
    expect(document.batchId, batchId);
    expect(document.title, item.title);
    expect(document.sha256, item.sha256);
    expect(document.pages.single.text, _textOne);
    expect(document.pages.single.fromOcr, isFalse);
    expect(document.fromCache, isFalse);
    expect(document.pageCount, 1);
    expect(source.closed, isTrue);
    expect(await cacheExists(item), isTrue);
    expect(opens, 1);

    final again = await study.extract(uid: uid, resource: item);

    expect(again.fromCache, isTrue);
    expect(again.pages.single.text, _textOne);
    expect(opens, 1);
  });

  test("a different sha never reuses another file's cache", () async {
    final first = resource(sha: 'sha-1111111111111111');
    await writePdf(first);
    final study = build(openPdf: (_) async => _FakePageSource([_textOne]));
    await study.extract(uid: uid, resource: first);

    final second = resource(sha: 'sha-2222222222222222');
    var opens = 0;
    final other = build(
      openPdf: (_) async {
        opens++;
        return _FakePageSource([_textTwo]);
      },
    );
    final document = await other.extract(uid: uid, resource: second);

    expect(opens, 1);
    expect(document.fromCache, isFalse);
    expect(document.pages.single.text, _textTwo);
  });

  test('OCRs only pages without a text layer', () async {
    final item = resource();
    await writePdf(item);
    final ocr = _FakeOcr(_textTwo);
    final study = build(
      openPdf: (_) async => _FakePageSource([_textOne, '']),
      ocr: ocr,
    );

    final document = await study.extract(uid: uid, resource: item);

    expect(ocr.calls, 1);
    expect(document.pages[0].fromOcr, isFalse);
    expect(document.pages[1].fromOcr, isTrue);
    expect(document.pages[1].text, _textTwo);
    expect(document.ocrPageCount, 1);
    expect(document.warnings, isEmpty);
  });

  test('caps OCR pages and warns instead of running for hours', () async {
    final item = resource();
    await writePdf(item);
    final ocr = _FakeOcr(_textTwo);
    final study = build(
      openPdf: (_) async => _FakePageSource(['', '']),
      ocr: ocr,
      maxOcrPages: 1,
    );

    final document = await study.extract(uid: uid, resource: item);

    expect(ocr.calls, 1);
    expect(document.ocrPageCount, 1);
    expect(document.pages[1].text, isEmpty);
    expect(
      document.warnings.any((warning) => warning.contains('OCR')),
      isTrue,
    );
  });

  test('cancels between pages, closes the reader and writes no cache',
      () async {
    final item = resource();
    await writePdf(item);
    final source = _FakePageSource([_textOne, _textTwo]);
    final study = build(openPdf: (_) async => source);

    await expectLater(
      study.extract(
        uid: uid,
        resource: item,
        isCancelled: () => source.readCount >= 1,
      ),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.cancelled,
        ),
      ),
    );

    expect(source.closed, isTrue);
    expect(source.readCount, 1);
    expect(await cacheExists(item), isFalse);
    expect(study.lastJob?.state, StudyJobState.cancelled);
  });

  test('refuses an encrypted pdf without opening it', () async {
    final item = resource();
    await writePdf(item);
    var opens = 0;
    final study = build(
      openPdf: (_) async {
        opens++;
        return _FakePageSource([_textOne]);
      },
      isEncrypted: (_) async => true,
    );

    await expectLater(
      study.extract(uid: uid, resource: item),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.encryptedSource,
        ),
      ),
    );

    expect(opens, 0);
    expect(study.lastJob?.state, StudyJobState.failed);
  });

  test('detects /Encrypt in the trailer of a real file', () async {
    final item = resource();
    await writePdf(
      item,
      body: '%PDF-1.7\n1 0 obj\n<< >>\nendobj\n'
          'trailer\n<< /Encrypt 2 0 R >>\n%%EOF',
    );
    var opens = 0;
    final study = StudySourceExtractor(
      files: files,
      openPdf: (_) async {
        opens++;
        return _FakePageSource([_textOne]);
      },
      ocr: _FakeOcr(''),
    );

    await expectLater(
      study.extract(uid: uid, resource: item),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.encryptedSource,
        ),
      ),
    );
    expect(opens, 0);
  });

  test('refuses more pages than the study tools accept', () async {
    final item = resource();
    await writePdf(item);
    final source = _FakePageSource([_textOne, _textTwo]);
    final study = build(openPdf: (_) async => source, maxPages: 1);

    await expectLater(
      study.extract(uid: uid, resource: item),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.tooManyPages,
        ),
      ),
    );
    expect(source.closed, isTrue);
  });

  test('refuses a file over the size limit before reading it', () async {
    final item = resource();
    await writePdf(item);
    final study = build(
      openPdf: (_) async => _FakePageSource([_textOne]),
      maxBytes: 1,
    );

    await expectLater(
      study.extract(uid: uid, resource: item),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.fileTooLarge,
        ),
      ),
    );
  });

  test('reports a missing private file', () async {
    final item = resource();
    final study = build(openPdf: (_) async => _FakePageSource([_textOne]));

    await expectLater(
      study.extract(uid: uid, resource: item),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.missingFile,
        ),
      ),
    );
  });

  test('refuses a duplicate start while a job is running', () async {
    final item = resource();
    await writePdf(item);
    final gate = Completer<void>();
    final source = _FakePageSource([_textOne], gate: gate.future);
    final study = build(openPdf: (_) async => source);

    final first = study.extract(uid: uid, resource: item);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      study.extract(uid: uid, resource: item),
      throwsA(
        isA<BatchFailure>().having(
          (failure) => failure.code,
          'code',
          BatchFailureCode.conflict,
        ),
      ),
    );

    gate.complete();
    final document = await first;

    expect(document.pages.single.text, _textOne);
    expect(study.isBusy, isFalse);
    expect(study.lastJob?.state, StudyJobState.completed);
  });

  test('reports queued, processing and completed in order', () async {
    final item = resource();
    await writePdf(item);
    final study = build(
      openPdf: (_) async => _FakePageSource([_textOne, _textTwo]),
    );
    final states = <StudyJobState>[];
    StudyJob? last;

    await study.extract(
      uid: uid,
      resource: item,
      onProgress: (job) {
        states.add(job.state);
        last = job;
      },
    );

    expect(states.first, StudyJobState.queued);
    expect(states, contains(StudyJobState.processing));
    expect(states.last, StudyJobState.completed);
    expect(last?.done, 2);
    expect(last?.total, 2);
    expect(last?.finishedAt, isNotNull);
  });

  test('cached documents keep their OCR flags', () async {
    final item = resource();
    await writePdf(item);
    final first = build(
      openPdf: (_) async => _FakePageSource([_textOne, '']),
      ocr: _FakeOcr(_textTwo),
    );
    await first.extract(uid: uid, resource: item);

    final cached = await StudySourceExtractor(
      files: files,
      openPdf: (_) async => throw StateError('must not open'),
      ocr: _FakeOcr(''),
      isEncrypted: (_) async => false,
    ).extract(uid: uid, resource: item);

    expect(cached.fromCache, isTrue);
    expect(cached.pages[1].fromOcr, isTrue);
    expect(cached.pages[1].text, _textTwo);
  });
}
