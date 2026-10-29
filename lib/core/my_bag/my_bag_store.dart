/// The bag's storage: one JSON index in [KeyValueStore] and one directory per
/// folder under `<application support>/my_bag/folders`.
///
/// The store owns paths and bytes only; it decides nothing about the bag's
/// contents. Deleting a folder never reaches outside `my_bag/`, so the PDF
/// library's own files stay where they are.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../key_value_store.dart';
import 'my_bag_models.dart';

class MyBagStore {
  MyBagStore({required KeyValueStore kv, required Directory rootDir})
      : _kv = kv,
        _rootDir = rootDir;

  static const String indexKey = 'my_bag_index';
  static const String hiddenSubjectIdsKey = 'my_bag_hidden_subjects';

  final KeyValueStore _kv;
  final Directory _rootDir;

  Directory get bagDir => Directory(p.join(_rootDir.path, 'my_bag'));

  Directory folderDir(String folderId) =>
      Directory(p.join(bagDir.path, 'folders', folderId));

  File voiceFile(String folderId, String fileName) =>
      File(p.join(folderDir(folderId).path, 'voice', fileName));

  File boardFile(String folderId, String fileName) =>
      File(p.join(folderDir(folderId).path, 'boards', fileName));

  File _metaFile(String folderId) =>
      File(p.join(folderDir(folderId).path, 'meta.json'));

  File _linksFile(String folderId) =>
      File(p.join(folderDir(folderId).path, 'links.json'));

  /// The saved index, or an empty one when nothing is stored or the record is
  /// unreadable.
  MyBagIndex loadIndex() {
    final raw = _kv.getString(indexKey);
    if (raw == null || raw.isEmpty) return const MyBagIndex();
    try {
      return MyBagIndex.fromJson(raw);
    } on FormatException {
      return const MyBagIndex();
    }
  }

  Future<void> saveIndex(MyBagIndex index) =>
      _kv.setString(indexKey, jsonEncode(index.toJson()));

  /// Ids of seeded folders the student deleted; seeding skips these so a
  /// deleted subject folder does not come back.
  Set<String> loadHiddenSubjectIds() {
    final raw = _kv.getString(hiddenSubjectIdsKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return {
        for (final value in decoded)
          if (value is String) value,
      };
    } on FormatException {
      return <String>{};
    }
  }

  Future<void> addHiddenSubjectId(String id) async {
    final ids = loadHiddenSubjectIds()..add(id);
    final sorted = ids.toList()..sort();
    await _kv.setString(hiddenSubjectIdsKey, jsonEncode(sorted));
  }

  /// The folder's voice, board and link media; a missing or damaged part
  /// empties only its own pockets.
  MyBagFolderMedia loadMedia(String folderId) => MyBagFolderMedia.fromParts(
        meta: _readPart(_metaFile(folderId)),
        links: _readPart(_linksFile(folderId)),
      );

  Future<void> saveMedia(String folderId, MyBagFolderMedia media) async {
    folderDir(folderId).createSync(recursive: true);
    await _writeJsonAtomic(_metaFile(folderId), media.toMetaJson());
    await _writeJsonAtomic(_linksFile(folderId), media.toLinksJson());
  }

  Future<void> writeVoiceClip(
    String folderId,
    String fileName,
    List<int> bytes,
  ) async {
    final file = voiceFile(folderId, fileName);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> writeBoardImage(
    String folderId,
    String fileName,
    List<int> bytes,
  ) async {
    final file = boardFile(folderId, fileName);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  /// Removes the folder's directory and nothing else; safe to call twice.
  Future<void> deleteFolderDir(String folderId) async {
    final dir = folderDir(folderId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Reads a JSON part as text so [MyBagFolderMedia.fromParts] can report a
  /// damaged file as an empty part rather than throwing here.
  Object? _readPart(File file) {
    if (!file.existsSync()) return null;
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _writeJsonAtomic(File file, Map<String, dynamic> json) async {
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(jsonEncode(json), flush: true);
      await temp.rename(file.path);
    } finally {
      if (temp.existsSync()) {
        try {
          temp.deleteSync();
        } on FileSystemException {
          // A leftover temp file is harmless; the next write replaces it.
        }
      }
    }
  }
}
