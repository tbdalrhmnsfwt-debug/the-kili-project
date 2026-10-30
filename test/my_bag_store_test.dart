import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';
import 'package:zaker_ai/core/my_bag/my_bag_store.dart';

import 'support/my_bag_fixtures.dart';

void main() {
  late Directory root;
  late MemoryKv kv;
  late MyBagStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('zaker_bag_');
    kv = MemoryKv();
    store = MyBagStore(kv: kv, rootDir: root);
  });

  tearDown(() => root.deleteSync(recursive: true));

  MyBagFolder folder() => MyBagFolder.subject(
        gradeId: 'sec1',
        subjectKey: 'الرياضيات',
        name: 'الرياضيات',
        colorValue: 0xFF2F5EA8,
        createdAt: DateTime.utc(2026, 10, 1),
      );

  test('the index survives a new store instance', () async {
    final original = const MyBagIndex().upsert(folder());
    await store.saveIndex(original);

    final again = MyBagStore(kv: kv, rootDir: root).loadIndex();
    expect(again.folders.single.id, original.folders.single.id);
    expect(kv.getString(MyBagStore.indexKey), isNotNull);
  });

  test('a corrupt index loads empty instead of throwing', () {
    kv.values[MyBagStore.indexKey] = '{not json';
    expect(store.loadIndex().folders, isEmpty);
  });

  test('media round-trips through meta.json and links.json', () async {
    const media = MyBagFolderMedia(
      voice: [
        MyBagVoiceClip(
          id: 'v1',
          fileName: 'v1.m4a',
          title: 'ملاحظة',
          durationMs: 10,
          sizeBytes: 2,
          createdAtMs: 1,
          waveform: [40],
        ),
      ],
      links: [
        MyBagLink(
          id: 'l1',
          title: 'درس',
          url: 'https://example.com',
          createdAtMs: 2,
        ),
      ],
    );
    await store.saveMedia('f1', media);

    expect(
      File('${store.folderDir('f1').path}/meta.json').existsSync(),
      isTrue,
    );
    expect(
        File('${store.folderDir('f1').path}/links.json').existsSync(), isTrue);
    final again = store.loadMedia('f1');
    expect(again.voice.single.title, 'ملاحظة');
    expect(again.links.single.url, 'https://example.com');
    expect(
      store.folderDir('f1').listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('concurrent saves to one folder do not collide', () async {
    // A delete can land while an edit is still saving, and both write the
    // same meta.json/links.json. A shared `<file>.tmp` lets one write's
    // rename or cleanup take the other's temp file mid-write.
    await Future.wait([
      for (var i = 0; i < 20; i++)
        store.saveMedia(
          'f1',
          MyBagFolderMedia(
            links: [
              MyBagLink(
                id: 'l$i',
                title: 'درس $i',
                url: 'https://example.com/$i',
                createdAtMs: i,
              ),
            ],
          ),
        ),
    ]);

    expect(store.loadMedia('f1').links, isNotEmpty);
    expect(
      store.folderDir('f1').listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('the last save wins when two saves overlap', () async {
    // An edit whose write is still in flight, then a delete: the disk must
    // end up holding the second save, not whichever write finished last.
    final first = store.saveMedia(
      'f1',
      const MyBagFolderMedia(
        links: [
          MyBagLink(
              id: 'l1', title: 'درس', url: 'https://e.com', createdAtMs: 1),
        ],
      ),
    );
    final second = store.saveMedia('f1', const MyBagFolderMedia());
    await Future.wait([first, second]);

    expect(store.loadMedia('f1').links, isEmpty);
  });

  test('a corrupt meta.json keeps the links readable', () async {
    final dir = store.folderDir('f1')..createSync(recursive: true);
    File('${dir.path}/meta.json').writeAsStringSync('{oops');
    File('${dir.path}/links.json').writeAsStringSync(
      jsonEncode({
        'links': [
          const MyBagLink(
            id: 'l1',
            title: 'درس',
            url: 'https://example.com',
            createdAtMs: 2,
          ).toJson(),
        ],
      }),
    );

    final media = store.loadMedia('f1');
    expect(media.voice, isEmpty);
    expect(media.links.single.title, 'درس');
  });

  test('a voice clip is written under its folder voice directory', () async {
    await store.writeVoiceClip('f1', 'v1.m4a', const [1, 2, 3]);

    final file = store.voiceFile('f1', 'v1.m4a');
    expect(file.existsSync(), isTrue);
    expect(file.readAsBytesSync(), [1, 2, 3]);
    expect(file.parent.path, endsWith('/my_bag/folders/f1/voice'));
  });

  test('deleting a folder removes only its own directory', () async {
    await store.writeVoiceClip('f1', 'v1.m4a', const [1]);
    final pdf = File('${root.path}/pdf_library/p1.pdf')
      ..createSync(recursive: true);
    pdf.writeAsStringSync('%PDF-1.7');

    await store.deleteFolderDir('f1');
    expect(store.folderDir('f1').existsSync(), isFalse);
    expect(pdf.existsSync(), isTrue);
    await store.deleteFolderDir('f1'); // idempotent
  });

  test('hidden subject ids round-trip without duplicates', () async {
    await store.addHiddenSubjectId('subject:sec1:الرياضيات');
    await store.addHiddenSubjectId('subject:sec1:الرياضيات');
    expect(store.loadHiddenSubjectIds(), {'subject:sec1:الرياضيات'});
  });
}
