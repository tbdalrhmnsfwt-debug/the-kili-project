import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/my_bag/my_bag_controller.dart';
import 'package:zaker_ai/core/my_bag/my_bag_models.dart';
import 'package:zaker_ai/core/my_bag/my_bag_store.dart';

import 'support/my_bag_fixtures.dart';

void main() {
  late Directory root;
  late MyBagStore store;
  late int ids;

  setUp(() {
    root = Directory.systemTemp.createTempSync('zaker_bag_ctl_');
    store = MyBagStore(kv: MemoryKv(), rootDir: root);
    ids = 0;
  });

  tearDown(() => root.deleteSync(recursive: true));

  MyBagController controller() => MyBagController(
        store: store,
        newId: () => 'n${++ids}',
        clock: () => DateTime.utc(2026, 10, 28),
      );

  const math = MyBagSubjectSeed(
    gradeId: 'sec1',
    subjectKey: 'الرياضيات',
    name: 'الرياضيات',
    colorValue: 0xFF2F5EA8,
  );
  const science = MyBagSubjectSeed(
    gradeId: 'sec1',
    subjectKey: 'العلوم',
    name: 'العلوم',
    colorValue: 0xFF3B8A5A,
  );
  const mathId = 'subject:sec1:الرياضيات';

  test('seeding is per subject and idempotent', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);
    expect(bag.state.index.folders.single.id, mathId);

    await bag.syncSeeds(const [math, science]);
    expect(bag.state.index.folders, hasLength(2));

    final reopened = controller();
    await reopened.syncSeeds(const [math, science]);
    expect(reopened.state.index.folders, hasLength(2));
  });

  test('a deleted seeded folder stays deleted', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);
    await bag.deleteFolder(mathId);
    expect(bag.state.index.folders, isEmpty);

    await bag.syncSeeds(const [math]);
    expect(bag.state.index.folders, isEmpty);
    expect(store.loadHiddenSubjectIds(), contains(mathId));

    final reopened = controller();
    await reopened.syncSeeds(const [math]);
    expect(reopened.state.index.folders, isEmpty);
  });

  test('a new subject appears on the next seed pass', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);
    await bag.syncSeeds(const [math, science]);
    expect(
      bag.state.index.folders.map((folder) => folder.subjectKey),
      containsAll(['الرياضيات', 'العلوم']),
    );
  });

  test('a custom folder can be renamed and recoloured', () async {
    final bag = controller();
    final folder = await bag.addCustomFolder(
      name: 'أوراقي',
      colorValue: 0xFF112233,
    );
    expect(folder.id, startsWith('custom:'));
    expect(folder.gradeId, isEmpty);
    expect(bag.state.folderById(folder.id)!.name, 'أوراقي');

    await bag.renameFolder(folder.id, 'أوراق الإنجليزي');
    await bag.setFolderColor(folder.id, 0xFF445566);
    final updated = bag.state.folderById(folder.id)!;
    expect(updated.name, 'أوراق الإنجليزي');
    expect(updated.colorValue, 0xFF445566);
    expect(store.loadIndex().folderById(folder.id)!.name, 'أوراق الإنجليزي');
  });

  test('deleting a folder removes its media but never a PDF', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);
    final pdf = File('${root.path}/pdf_library/p1.pdf')
      ..createSync(recursive: true);
    pdf.writeAsStringSync('%PDF-1.7');
    await bag.addPdfRef(mathId, 'p1');
    await bag.addLink(mathId, title: 'درس', url: 'https://example.com');

    await bag.deleteFolder(mathId);
    expect(bag.state.index.folderById(mathId), isNull);
    expect(bag.state.mediaOf(mathId).links, isEmpty);
    expect(store.folderDir(mathId).existsSync(), isFalse);
    expect(pdf.existsSync(), isTrue);
  });

  test('a voice clip is copied into the folder with its waveform', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);
    final source = File('${root.path}/tmp.m4a')
      ..writeAsBytesSync(const [9, 8, 7]);

    await bag.addVoiceClip(
      mathId,
      sourcePath: source.path,
      title: 'شرح',
      durationMs: 1200,
      waveform: const [10, 90],
    );
    final clip = bag.state.mediaOf(mathId).voice.single;
    expect(clip.title, 'شرح');
    expect(clip.durationMs, 1200);
    expect(clip.sizeBytes, 3);
    expect(clip.waveform, [10, 90]);
    expect(
      clip.createdAtMs,
      DateTime.utc(2026, 10, 28).millisecondsSinceEpoch,
    );
    expect(store.voiceFile(mathId, clip.fileName).readAsBytesSync(), [9, 8, 7]);
    expect(store.loadMedia(mathId).voice.single.id, clip.id);

    await bag.deleteVoiceClip(mathId, clip.id);
    expect(bag.state.mediaOf(mathId).voice, isEmpty);
    expect(store.voiceFile(mathId, clip.fileName).existsSync(), isFalse);
  });

  test('board images import, reorder and delete', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);

    await bag.addBoardImage(
      mathId,
      bytes: const [1],
      width: 10,
      height: 20,
      extension: '.png',
    );
    await bag.addBoardImage(mathId, bytes: const [2], width: 10, height: 20);
    final first = bag.state.mediaOf(mathId).boards[0];
    final second = bag.state.mediaOf(mathId).boards[1];
    expect(second.fileName, endsWith('.jpg'));

    await bag.reorderBoardImages(mathId, 0, 1);
    expect(
      bag.state.mediaOf(mathId).boards.map((board) => board.id),
      [second.id, first.id],
    );

    await bag.deleteBoardImage(mathId, first.id);
    expect(bag.state.mediaOf(mathId).boards.single.id, second.id);
    expect(store.boardFile(mathId, first.fileName).existsSync(), isFalse);
  });

  test('a link is validated before it is stored', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);

    await expectLater(
      bag.addLink(mathId, title: 'خطر', url: 'javascript:alert(1)'),
      throwsArgumentError,
    );
    expect(bag.state.mediaOf(mathId).links, isEmpty);

    await bag.addLink(mathId, title: 'درس', url: 'https://example.com');
    final link = bag.state.mediaOf(mathId).links.single;
    expect(link.url, 'https://example.com');

    await bag.updateLink(
      mathId,
      link.id,
      title: 'درس ٢',
      url: 'http://example.com',
    );
    expect(bag.state.mediaOf(mathId).links.single.title, 'درس ٢');

    await bag.deleteLink(mathId, link.id);
    expect(bag.state.mediaOf(mathId).links, isEmpty);
  });

  test('missing PDF references are pruned, known ones are kept', () async {
    final bag = controller();
    await bag.syncSeeds(const [math]);
    await bag.addPdfRef(mathId, 'p1');
    await bag.addPdfRef(mathId, 'gone');

    await bag.prunePdfRefs({'p1'});
    expect(bag.state.folderById(mathId)!.pdfIds, ['p1']);
    expect(store.loadIndex().folderById(mathId)!.pdfIds, ['p1']);
  });
}
