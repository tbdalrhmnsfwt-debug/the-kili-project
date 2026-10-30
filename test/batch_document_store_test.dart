import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/batches/batch_failure.dart';
import 'package:zaker_ai/core/batches/document_store.dart';

class _Doc {
  const _Doc({required this.name, required this.count});

  final String name;
  final int count;

  Map<String, dynamic> toJson() => {'name': name, 'count': count};

  factory _Doc.fromJson(Map<String, dynamic> json) => _Doc(
        name: json['name'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zaker_doc_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  DocumentStore<_Doc> store({int schema = 1}) => DocumentStore<_Doc>(
        file: File('${root.path}/doc.json'),
        schema: schema,
        encode: (value) => value.toJson(),
        decode: _Doc.fromJson,
      );

  test('a missing document reports missing, not an error', () async {
    final result = await store().load();
    expect(result.status, DocumentLoadStatus.missing);
    expect(result.isUsable, isFalse);
    expect(result.failure, isNull);
  });

  test('saves and loads one document', () async {
    final document = store();
    await document.save(const _Doc(name: 'أول', count: 1));

    final result = await document.load();
    expect(result.status, DocumentLoadStatus.ok);
    expect(result.value!.name, 'أول');
    expect(result.value!.count, 1);
    expect(await document.backupFile.exists(), isFalse);
  });

  test('keeps the previous good document as .bak', () async {
    final document = store();
    await document.save(const _Doc(name: 'first', count: 1));
    await document.save(const _Doc(name: 'second', count: 2));

    expect((await document.load()).value!.name, 'second');
    final backup = jsonDecode(await document.backupFile.readAsString()) as Map;
    expect(backup['name'], 'first');
  });

  test(
    'recovers from the backup and quarantines the corrupt primary',
    () async {
      final document = store();
      await document.save(const _Doc(name: 'first', count: 1));
      await document.save(const _Doc(name: 'second', count: 2));
      await document.file.writeAsString('{not json');

      final result = await document.load();
      expect(result.status, DocumentLoadStatus.recovered);
      expect(result.value!.name, 'first');

      final quarantined = root
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('.corrupt-'))
          .toList();
      expect(quarantined, isNotEmpty);
    },
  );

  test('reports corrupt when both primary and backup fail', () async {
    final document = store();
    await document.save(const _Doc(name: 'first', count: 1));
    await document.save(const _Doc(name: 'second', count: 2));
    await document.file.writeAsString('{broken');
    await document.backupFile.writeAsString('also broken');

    final result = await document.load();
    expect(result.status, DocumentLoadStatus.corrupt);
    expect(result.value, isNull);
    expect(result.failure!.code, BatchFailureCode.corruptStore);
  });

  test('a document without a schema is corrupt', () async {
    final document = store();
    await document.file.writeAsString('{"name":"x","count":1}');
    final result = await document.load();
    expect(result.status, DocumentLoadStatus.corrupt);
  });

  test('a newer schema is refused without downgrading the file', () async {
    final document = store();
    await document.file.parent.create(recursive: true);
    await document.file.writeAsString(
      jsonEncode({'schema': 2, 'name': 'future', 'count': 3}),
    );

    final result = await document.load();
    expect(result.status, DocumentLoadStatus.unsupportedSchema);
    expect(result.failure!.code, BatchFailureCode.migrationUnsupported);
    expect(jsonDecode(await document.file.readAsString())['schema'], 2);
  });

  test('a failed save leaves the previous document intact', () async {
    final document = store();
    await document.save(const _Doc(name: 'good', count: 1));
    // Replace the parent with a file so the next write cannot create paths.
    final blocked = DocumentStore<_Doc>(
      file: File('${root.path}/doc.json/child/doc.json'),
      schema: 1,
      encode: (value) => value.toJson(),
      decode: _Doc.fromJson,
    );
    await expectLater(
      blocked.save(const _Doc(name: 'bad', count: 2)),
      throwsA(isA<BatchFailure>()),
    );
    expect((await document.load()).value!.name, 'good');
  });

  test('delete removes the document and its backup', () async {
    final document = store();
    await document.save(const _Doc(name: 'first', count: 1));
    await document.save(const _Doc(name: 'second', count: 2));
    await document.delete();

    expect(await document.file.exists(), isFalse);
    expect(await document.backupFile.exists(), isFalse);
    expect((await document.load()).status, DocumentLoadStatus.missing);
  });
}
