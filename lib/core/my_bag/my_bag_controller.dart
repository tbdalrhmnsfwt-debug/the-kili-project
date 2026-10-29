/// The bag's single source of truth: seeding, folder CRUD and every pocket.
///
/// The controller owns the rules (which folders exist, what a pocket holds,
/// what a delete touches); [MyBagStore] owns the paths and bytes.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'my_bag_models.dart';
import 'my_bag_store.dart';

/// The most voice notes one folder holds.
const int kMaxVoiceClips = 100;

/// The most board images one folder holds.
const int kMaxBoardImages = 200;

/// The most links one folder holds.
const int kMaxLinks = 100;

/// One immutable snapshot of the bag.
class MyBagState {
  const MyBagState({required this.index, required this.media});

  final MyBagIndex index;

  /// Media per folder id; a folder with no entry has no media yet.
  final Map<String, MyBagFolderMedia> media;

  MyBagFolder? folderById(String id) => index.folderById(id);

  MyBagFolderMedia mediaOf(String folderId) =>
      media[folderId] ?? const MyBagFolderMedia();

  PocketTotals get totals => PocketTotals.from(index, media);

  PocketTotals totalsFor(String folderId) {
    final folder = folderById(folderId);
    if (folder == null) return const PocketTotals();
    return PocketTotals.from(MyBagIndex(folders: [folder]), media);
  }
}

class MyBagController extends StateNotifier<MyBagState> {
  MyBagController({
    required MyBagStore store,
    DateTime Function()? clock,
    String Function()? newId,
  })  : _store = store,
        _clock = clock ?? DateTime.now,
        _newId = newId ?? _randomId,
        super(_load(store));

  final MyBagStore _store;
  final DateTime Function() _clock;
  final String Function() _newId;

  static MyBagState _load(MyBagStore store) {
    final index = store.loadIndex();
    return MyBagState(
      index: index,
      media: {
        for (final folder in index.folders)
          folder.id: store.loadMedia(folder.id),
      },
    );
  }

  static String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${Random().nextInt(1 << 20).toRadixString(36)}';

  /// Creates the folder of every seed that has none yet, skipping subjects
  /// the student deleted on purpose.
  Future<void> syncSeeds(List<MyBagSubjectSeed> seeds) async {
    final hidden = _store.loadHiddenSubjectIds();
    var index = state.index;
    var added = false;
    for (final seed in seeds) {
      final id = subjectFolderId(seed.gradeId, seed.subjectKey);
      if (index.folderById(id) != null || hidden.contains(id)) continue;
      index = index.upsert(
        MyBagFolder.subject(
          gradeId: seed.gradeId,
          subjectKey: seed.subjectKey,
          name: seed.name,
          colorValue: seed.colorValue,
          createdAt: _clock(),
        ),
      );
      added = true;
    }
    if (!added) return;
    await _apply(index, state.media);
  }

  Future<MyBagFolder> addCustomFolder({
    required String name,
    required int colorValue,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'a folder needs a name');
    }
    final folder = MyBagFolder(
      id: 'custom:${_newId()}',
      name: trimmed,
      gradeId: '',
      subjectKey: '',
      custom: true,
      colorValue: colorValue,
      iconName: 'Folder01',
      pdfIds: const [],
      createdAt: _clock(),
    );
    await _apply(state.index.upsert(folder), {
      ...state.media,
      folder.id: const MyBagFolderMedia(),
    });
    return folder;
  }

  Future<void> renameFolder(String folderId, String name) async {
    final folder = state.index.folderById(folderId);
    final trimmed = name.trim();
    if (folder == null || trimmed.isEmpty) return;
    await _apply(
        state.index.upsert(folder.copyWith(name: trimmed)), state.media);
  }

  Future<void> setFolderColor(String folderId, int colorValue) async {
    final folder = state.index.folderById(folderId);
    if (folder == null) return;
    await _apply(
      state.index.upsert(folder.copyWith(colorValue: colorValue)),
      state.media,
    );
  }

  /// Deletes a folder's own media. Referenced PDFs stay in the library; a
  /// seeded folder is remembered as hidden so seeding does not recreate it.
  Future<void> deleteFolder(String folderId) async {
    final folder = state.index.folderById(folderId);
    if (folder == null) return;
    if (!folder.custom) await _store.addHiddenSubjectId(folderId);
    await _store.deleteFolderDir(folderId);
    final media = {...state.media}..remove(folderId);
    await _apply(state.index.remove(folderId), media);
  }

  Future<void> addPdfRef(String folderId, String pdfId) async {
    final folder = state.index.folderById(folderId);
    if (folder == null || folder.pdfIds.contains(pdfId)) return;
    await _apply(
      state.index.upsert(
        folder.copyWith(pdfIds: [...folder.pdfIds, pdfId]),
      ),
      state.media,
    );
  }

  Future<void> removePdfRef(String folderId, String pdfId) async {
    final folder = state.index.folderById(folderId);
    if (folder == null || !folder.pdfIds.contains(pdfId)) return;
    await _apply(
      state.index.upsert(
        folder.copyWith(
          pdfIds: [
            for (final id in folder.pdfIds)
              if (id != pdfId) id,
          ],
        ),
      ),
      state.media,
    );
  }

  /// Drops references to library documents that no longer exist.
  Future<void> prunePdfRefs(Set<String> knownPdfIds) async {
    final next = state.index.prunePdfRefs(knownPdfIds);
    if (identical(next, state.index)) return;
    await _apply(next, state.media);
  }

  Future<void> addVoiceClip(
    String folderId, {
    required String sourcePath,
    required String title,
    required int durationMs,
    required List<int> waveform,
  }) async {
    final folder = state.index.folderById(folderId);
    if (folder == null) return;
    final current = state.mediaOf(folderId);
    if (current.voice.length >= kMaxVoiceClips) {
      throw StateError('voiceCap');
    }
    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw StateError('emptyVoice');

    final id = _newId();
    final fileName = '$id.m4a';
    await _store.writeVoiceClip(folderId, fileName, bytes);
    final clip = MyBagVoiceClip(
      id: id,
      fileName: fileName,
      title: title,
      durationMs: durationMs,
      sizeBytes: bytes.length,
      createdAtMs: _clock().millisecondsSinceEpoch,
      waveform: waveform,
    );
    await _saveMedia(
      folderId,
      current.copyWith(voice: [...current.voice, clip]),
    );
    try {
      await source.delete();
    } on FileSystemException {
      // The recorder's temp file is best-effort cleanup, not part of the bag.
    }
  }

  Future<void> deleteVoiceClip(String folderId, String clipId) async {
    final current = state.mediaOf(folderId);
    MyBagVoiceClip? clip;
    for (final candidate in current.voice) {
      if (candidate.id == clipId) clip = candidate;
    }
    if (clip == null) return;
    await _saveMedia(
      folderId,
      current.copyWith(
        voice: [
          for (final candidate in current.voice)
            if (candidate.id != clipId) candidate,
        ],
      ),
    );
    final file = _store.voiceFile(folderId, clip.fileName);
    if (file.existsSync()) {
      try {
        await file.delete();
      } on FileSystemException {
        // A stranded file is invisible to the UI; never fail the delete.
      }
    }
  }

  Future<void> addBoardImage(
    String folderId, {
    required List<int> bytes,
    required int width,
    required int height,
    String extension = '.jpg',
  }) async {
    final folder = state.index.folderById(folderId);
    if (folder == null) return;
    final current = state.mediaOf(folderId);
    if (current.boards.length >= kMaxBoardImages) {
      throw StateError('boardCap');
    }
    final id = _newId();
    final fileName = '$id${_safeImageExtension(extension)}';
    await _store.writeBoardImage(folderId, fileName, bytes);
    final image = MyBagBoardImage(
      id: id,
      fileName: fileName,
      width: width,
      height: height,
      createdAtMs: _clock().millisecondsSinceEpoch,
    );
    await _saveMedia(
      folderId,
      current.copyWith(boards: [...current.boards, image]),
    );
  }

  Future<void> reorderBoardImages(String folderId, int from, int to) async {
    final current = state.mediaOf(folderId);
    final reordered = moveItem(current.boards, from, to);
    if (identical(reordered, current.boards)) return;
    var changed = reordered.length != current.boards.length;
    for (var index = 0; index < reordered.length && !changed; index++) {
      if (!identical(reordered[index], current.boards[index])) changed = true;
    }
    if (!changed) return;
    await _saveMedia(folderId, current.copyWith(boards: reordered));
  }

  Future<void> deleteBoardImage(String folderId, String imageId) async {
    final current = state.mediaOf(folderId);
    MyBagBoardImage? image;
    for (final candidate in current.boards) {
      if (candidate.id == imageId) image = candidate;
    }
    if (image == null) return;
    await _saveMedia(
      folderId,
      current.copyWith(
        boards: [
          for (final candidate in current.boards)
            if (candidate.id != imageId) candidate,
        ],
      ),
    );
    final file = _store.boardFile(folderId, image.fileName);
    if (file.existsSync()) {
      try {
        await file.delete();
      } on FileSystemException {
        // Same as a stranded voice clip: nothing to recover.
      }
    }
  }

  Future<void> addLink(
    String folderId, {
    required String title,
    required String url,
  }) async {
    final folder = state.index.folderById(folderId);
    if (folder == null) return;
    final current = state.mediaOf(folderId);
    if (current.links.length >= kMaxLinks) throw StateError('linkCap');
    final error = validateBagLinkUrl(url);
    if (error != null) {
      throw ArgumentError.value(url, 'url', error);
    }
    final trimmedUrl = url.trim();
    final trimmedTitle = title.trim();
    final link = MyBagLink(
      id: _newId(),
      title: trimmedTitle.isEmpty ? bagLinkHost(trimmedUrl) : trimmedTitle,
      url: trimmedUrl,
      createdAtMs: _clock().millisecondsSinceEpoch,
    );
    await _saveMedia(
      folderId,
      current.copyWith(links: [...current.links, link]),
    );
  }

  Future<void> updateLink(
    String folderId,
    String linkId, {
    required String title,
    required String url,
  }) async {
    final current = state.mediaOf(folderId);
    MyBagLink? existing;
    for (final candidate in current.links) {
      if (candidate.id == linkId) existing = candidate;
    }
    if (existing == null) return;
    final error = validateBagLinkUrl(url);
    if (error != null) {
      throw ArgumentError.value(url, 'url', error);
    }
    final trimmedUrl = url.trim();
    final trimmedTitle = title.trim();
    final updated = MyBagLink(
      id: existing.id,
      title: trimmedTitle.isEmpty ? bagLinkHost(trimmedUrl) : trimmedTitle,
      url: trimmedUrl,
      createdAtMs: existing.createdAtMs,
    );
    await _saveMedia(
      folderId,
      current.copyWith(
        links: [
          for (final candidate in current.links)
            if (candidate.id == linkId) updated else candidate,
        ],
      ),
    );
  }

  Future<void> deleteLink(String folderId, String linkId) async {
    final current = state.mediaOf(folderId);
    if (!current.links.any((link) => link.id == linkId)) return;
    await _saveMedia(
      folderId,
      current.copyWith(
        links: [
          for (final link in current.links)
            if (link.id != linkId) link,
        ],
      ),
    );
  }

  Future<void> _apply(
    MyBagIndex index,
    Map<String, MyBagFolderMedia> media,
  ) async {
    if (!mounted) return;
    state = MyBagState(index: index, media: media);
    await _store.saveIndex(index);
  }

  Future<void> _saveMedia(String folderId, MyBagFolderMedia media) async {
    if (!mounted) return;
    state = MyBagState(
        index: state.index, media: {...state.media, folderId: media});
    await _store.saveMedia(folderId, media);
  }

  String _safeImageExtension(String extension) {
    final lower = extension.trim().toLowerCase();
    const allowed = {'.jpg', '.jpeg', '.png', '.webp'};
    return allowed.contains(lower) ? lower : '.jpg';
  }
}
