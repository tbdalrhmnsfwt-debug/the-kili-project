import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';

void main() {
  const color = 0xFF2F5EA8;

  MyBagFolder subjectFolder({
    String gradeId = 'sec1',
    String subjectKey = 'الرياضيات',
    String name = 'الرياضيات',
  }) =>
      MyBagFolder.subject(
        gradeId: gradeId,
        subjectKey: subjectKey,
        name: name,
        colorValue: color,
        createdAt: DateTime.utc(2026, 10, 1),
      );

  test('a subject folder derives a stable id and icon', () {
    final folder = subjectFolder();
    expect(folder.id, 'subject:sec1:الرياضيات');
    expect(folder.custom, isFalse);
    expect(folder.gradeId, 'sec1');
    expect(folder.iconName, 'Math');
    expect(bagIconNameFor('كيمياء'), 'Chemistry01');
    expect(bagIconNameFor('مادة غريبة'), 'Folder01');
    expect(bagProgressKey('sec1', 'الرياضيات'), 'sec1|الرياضيات');
  });

  test('a folder round-trips through JSON', () {
    final folder = subjectFolder().copyWith(pdfIds: const ['p1', 'p2']);
    final again = MyBagFolder.fromJson(folder.toJson())!;
    expect(again.id, folder.id);
    expect(again.name, folder.name);
    expect(again.pdfIds, ['p1', 'p2']);
    expect(again.colorValue, color);
    expect(again.iconName, 'Math');
    expect(again.createdAt, folder.createdAt);
  });

  test('a damaged folder or index is skipped, not fatal', () {
    expect(MyBagFolder.fromJson(null), isNull);
    expect(MyBagFolder.fromJson(const {}), isNull);
    expect(MyBagFolder.fromJson(const {'id': 'x'}), isNull);
    expect(MyBagIndex.fromJson(null).folders, isEmpty);
    expect(
      MyBagIndex.fromJson({
        'version': 1,
        'folders': [
          subjectFolder().toJson(),
          const {'id': 'broken'}
        ],
      }).folders,
      hasLength(1),
    );
  });

  test('upsert replaces, remove drops, and pruning keeps known ids', () {
    final a = subjectFolder();
    final b = subjectFolder(
      gradeId: 'prep1',
      subjectKey: 'العلوم',
      name: 'العلوم',
    );
    var index = const MyBagIndex().upsert(a).upsert(b);
    expect(index.folders, hasLength(2));

    index = index.upsert(a.copyWith(name: 'رياضيات ١', pdfIds: ['p1', 'gone']));
    expect(index.folderById(a.id)!.name, 'رياضيات ١');

    final pruned = index.prunePdfRefs({'p1'});
    expect(pruned.folderById(a.id)!.pdfIds, ['p1']);
    expect(pruned.folderById(b.id)!.pdfIds, isEmpty);
    expect(index.remove(a.id).folderById(a.id), isNull);
  });

  test('media splits into meta and links JSON and counts each pocket', () {
    final media = MyBagFolderMedia(
      voice: const [
        MyBagVoiceClip(
          id: 'v1',
          fileName: 'v1.m4a',
          title: 'ملاحظة',
          durationMs: 1200,
          sizeBytes: 100,
          createdAtMs: 5,
          waveform: [50, 80],
        ),
      ],
      boards: const [
        MyBagBoardImage(
          id: 'b1',
          fileName: 'b1.jpg',
          width: 100,
          height: 80,
          createdAtMs: 7,
        ),
      ],
      links: const [
        MyBagLink(
          id: 'l1',
          title: 'درس',
          url: 'https://example.com',
          createdAtMs: 9,
        ),
      ],
    );
    final meta = media.toMetaJson();
    final links = media.toLinksJson();
    expect(meta.containsKey('links'), isFalse);
    expect(links['links'], hasLength(1));

    final again = MyBagFolderMedia.fromParts(meta: meta, links: links);
    expect(again.countFor(BagPocketKind.voice), 1);
    expect(again.countFor(BagPocketKind.boards), 1);
    expect(again.countFor(BagPocketKind.links), 1);
    expect(again.countFor(BagPocketKind.pdfs), 0);
    expect(again.voice.single.waveform, [50, 80]);

    // One corrupt file must not take the other pocket down.
    final partly = MyBagFolderMedia.fromParts(meta: '{oops', links: links);
    expect(partly.voice, isEmpty);
    expect(partly.links, hasLength(1));
  });

  test('recent merges voice, boards and links, newest first', () {
    final media = MyBagFolderMedia(
      voice: const [
        MyBagVoiceClip(
          id: 'v',
          fileName: 'v.m4a',
          title: 'صوت',
          durationMs: 1,
          sizeBytes: 1,
          createdAtMs: 10,
        ),
      ],
      boards: const [
        MyBagBoardImage(
          id: 'b',
          fileName: 'b.jpg',
          width: 1,
          height: 1,
          createdAtMs: 30,
        ),
      ],
      links: const [
        MyBagLink(
            id: 'l', title: 'رابط', url: 'https://e.com', createdAtMs: 20),
      ],
    );
    final recent = media.recent(2);
    expect(recent.map((item) => item.kind), [
      BagPocketKind.boards,
      BagPocketKind.links,
    ]);
    expect(recent.first.title, isEmpty);
    expect(media.recent(10), hasLength(3));
  });

  test('totals count every folder and pocket', () {
    final index = const MyBagIndex().upsert(
      subjectFolder().copyWith(pdfIds: const ['p1']),
    );
    final totals = PocketTotals.from(index, {
      'subject:sec1:الرياضيات': const MyBagFolderMedia(),
    });
    expect(totals.pdfs, 1);
    expect(totals.total, 1);
    expect(totals.asList, [1, 0, 0, 0]);
  });

  test('the waveform is capped at 96 samples and scaled to 0..100', () {
    expect(downsampleWaveform(const []), isEmpty);
    expect(downsampleWaveform(const [0, 32767]), [0, 100]);
    final dense = downsampleWaveform(List<int>.filled(300, 32767));
    expect(dense, hasLength(96));
    expect(dense.every((value) => value == 100), isTrue);
    expect(downsampleWaveform(List<int>.filled(5, 0)), everyElement(0));
  });

  test('only http and https links pass validation', () {
    expect(validateBagLinkUrl('https://example.com/lesson'), isNull);
    expect(validateBagLinkUrl('  http://example.com  '), isNull);
    for (final bad in [
      '',
      'example.com',
      'javascript:alert(1)',
      'mailto:student@example.com',
      'file:///sdcard/secret.pdf',
      'https://exa mple.com',
      'https://',
    ]) {
      expect(validateBagLinkUrl(bad), isNotNull, reason: bad);
    }
    expect(bagLinkHost('https://www.example.com/x'), 'www.example.com');
    expect(bagLinkHost('not a url'), 'not a url');
  });

  test('moveItem moves to the final index', () {
    expect(moveItem(const ['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    expect(moveItem(const ['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(moveItem(const ['a'], 5, 0), ['a']);
  });
}
