/// Flutter-free models and pure helpers for «شنطتي» (the bag).
///
/// The bag is a tree of folders; each folder owns four pockets: PDF
/// references, voice clips, board images and links. Nothing in this file
/// touches Flutter, `path_provider` or a channel, so it can be tested with
/// plain `dart`.
library;

import 'dart:convert';

/// The four things a folder holds.
enum BagPocketKind { pdfs, voice, boards, links }

/// Parses the route segment that names a pocket; unknown values fall back to
/// the PDFs pocket rather than throwing.
BagPocketKind bagPocketKindFromName(String? name) {
  for (final kind in BagPocketKind.values) {
    if (kind.name == name) return kind;
  }
  return BagPocketKind.pdfs;
}

/// The stable id of the seeded folder for one subject of one grade.
String subjectFolderId(String gradeId, String subjectKey) =>
    'subject:$gradeId:$subjectKey';

/// The key [MyBagSubjectProgress] lookups use for one subject of one grade.
String bagProgressKey(String gradeId, String subjectKey) =>
    '$gradeId|$subjectKey';

/// The HugeIcons selector name shown for a subject, in the order the subject
/// names are checked. Unknown subjects get the plain folder.
String bagIconNameFor(String subjectKey) {
  final key = subjectKey.trim().toLowerCase();
  bool has(String needles) =>
      needles.split('|').any((needle) => key.contains(needle));

  if (has('رياض|جبر|حساب|هندسة')) return 'Math';
  if (has('فيزياء')) return 'Atom01';
  if (has('كيمياء')) return 'Chemistry01';
  if (has('أحياء|احياء|علوم')) return 'Microscope';
  if (has('عربي|عربية')) return 'BookOpen01';
  if (has('إنجليز|انجليز|english')) return 'Translate';
  if (has('فرنس|ألمان|المان|إيطالي|اسباني|إسباني|لغة')) return 'Languages';
  if (has('تاريخ')) return 'History';
  if (has('جغراف')) return 'Earth';
  if (has('فلسفة|نفس|اجتماع')) return 'Brain01';
  if (has('دين|إسلام|اسلام|قرآن|قران')) return 'Quran01';
  if (has('حاسب|كمبيوتر|تكنولوجيا|برمجة')) return 'Computer';
  if (has('فنون|رسم|موسيقى')) return 'Palette';
  if (has('رياضة')) return 'SportShoe';
  return 'Folder01';
}

/// The display host of a saved link, or the raw text when it has none.
String bagLinkHost(String url) {
  final trimmed = url.trim();
  final host = Uri.tryParse(trimmed)?.host ?? '';
  return host.isEmpty ? trimmed : host;
}

/// Why [raw] cannot be saved as a bag link, or null when it can.
///
/// Only `http` and `https` links are ever stored or launched: anything else
/// (a bare host, `javascript:`, `mailto:`, `file:`) is refused with an
/// explanation the dialog shows next to the field.
String? validateBagLinkUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'الرابط فاضي.';
  if (value.contains(RegExp(r'\s'))) return 'الرابط فيه مسافة.';
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return 'الرابط لازم يبدأ بـ http أو https.';
  }
  if (uri.host.isEmpty) return 'الرابط مش كامل.';
  return null;
}

/// Squeezes a recorder's amplitudes into at most [maxSamples] bars on a
/// 0..100 scale, averaging contiguous buckets when there are more samples
/// than bars.
List<int> downsampleWaveform(List<int> amplitudes, {int maxSamples = 96}) {
  if (amplitudes.isEmpty || maxSamples <= 0) return const [];
  if (amplitudes.length <= maxSamples) {
    return [for (final amplitude in amplitudes) _scaledAmplitude(amplitude)];
  }
  final bucket = amplitudes.length / maxSamples;
  final bars = <int>[];
  for (var bar = 0; bar < maxSamples; bar++) {
    final start = (bar * bucket).floor();
    final end = ((bar + 1) * bucket).ceil().clamp(start + 1, amplitudes.length);
    var sum = 0;
    for (var index = start; index < end; index++) {
      sum += amplitudes[index];
    }
    bars.add(_scaledAmplitude((sum / (end - start)).round()));
  }
  return bars;
}

int _scaledAmplitude(int amplitude) =>
    ((amplitude / 32767) * 100).round().clamp(0, 100);

/// Returns [items] with the element at [from] moved to final index [to].
///
/// An out-of-range [from] leaves the list unchanged; [to] is clamped.
List<T> moveItem<T>(List<T> items, int from, int to) {
  final copy = List<T>.of(items);
  if (from < 0 || from >= copy.length) return copy;
  final item = copy.removeAt(from);
  copy.insert(to.clamp(0, copy.length), item);
  return copy;
}

/// One recorded voice note inside a folder.
class MyBagVoiceClip {
  const MyBagVoiceClip({
    required this.id,
    required this.fileName,
    required this.title,
    required this.durationMs,
    required this.sizeBytes,
    required this.createdAtMs,
    this.waveform = const [],
  });

  final String id;
  final String fileName;
  final String title;
  final int durationMs;
  final int sizeBytes;
  final int createdAtMs;

  /// Bars on a 0..100 scale, already downsampled.
  final List<int> waveform;

  Map<String, dynamic> toJson() => {
        'id': id,
        'file': fileName,
        'title': title,
        'durationMs': durationMs,
        'size': sizeBytes,
        'createdAt': createdAtMs,
        'waveform': waveform,
      };

  static MyBagVoiceClip? fromJson(Object? json) {
    final map = _asMap(json);
    if (map == null) return null;
    final id = map['id'];
    final file = map['file'];
    final title = map['title'];
    final duration = _asInt(map['durationMs']);
    final size = _asInt(map['size']);
    final createdAt = _asInt(map['createdAt']);
    if (id is! String ||
        file is! String ||
        title is! String ||
        duration == null ||
        size == null ||
        createdAt == null) {
      return null;
    }
    final rawWaveform = map['waveform'];
    return MyBagVoiceClip(
      id: id,
      fileName: file,
      title: title,
      durationMs: duration,
      sizeBytes: size,
      createdAtMs: createdAt,
      waveform: rawWaveform is List
          ? [
              for (final value in rawWaveform)
                if (_asInt(value) != null) _asInt(value)!,
            ]
          : const [],
    );
  }
}

/// One board photograph inside a folder.
class MyBagBoardImage {
  const MyBagBoardImage({
    required this.id,
    required this.fileName,
    required this.width,
    required this.height,
    required this.createdAtMs,
  });

  final String id;
  final String fileName;
  final int width;
  final int height;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'file': fileName,
        'width': width,
        'height': height,
        'createdAt': createdAtMs,
      };

  static MyBagBoardImage? fromJson(Object? json) {
    final map = _asMap(json);
    if (map == null) return null;
    final id = map['id'];
    final file = map['file'];
    final width = _asInt(map['width']);
    final height = _asInt(map['height']);
    final createdAt = _asInt(map['createdAt']);
    if (id is! String ||
        file is! String ||
        width == null ||
        height == null ||
        createdAt == null) {
      return null;
    }
    return MyBagBoardImage(
      id: id,
      fileName: file,
      width: width,
      height: height,
      createdAtMs: createdAt,
    );
  }
}

/// One saved link inside a folder.
class MyBagLink {
  const MyBagLink({
    required this.id,
    required this.title,
    required this.url,
    required this.createdAtMs,
  });

  final String id;
  final String title;
  final String url;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'createdAt': createdAtMs,
      };

  static MyBagLink? fromJson(Object? json) {
    final map = _asMap(json);
    if (map == null) return null;
    final id = map['id'];
    final title = map['title'];
    final url = map['url'];
    final createdAt = _asInt(map['createdAt']);
    if (id is! String ||
        title is! String ||
        url is! String ||
        createdAt == null) {
      return null;
    }
    return MyBagLink(id: id, title: title, url: url, createdAtMs: createdAt);
  }
}

/// One folder in the bag: a seeded subject folder or a custom one.
class MyBagFolder {
  const MyBagFolder({
    required this.id,
    required this.name,
    required this.gradeId,
    required this.subjectKey,
    required this.custom,
    required this.colorValue,
    required this.iconName,
    required this.pdfIds,
    required this.createdAt,
  });

  /// A folder for one subject of one grade, keyed by
  /// [subjectFolderId] so re-seeding is idempotent.
  factory MyBagFolder.subject({
    required String gradeId,
    required String subjectKey,
    required String name,
    required int colorValue,
    String? iconName,
    required DateTime createdAt,
  }) =>
      MyBagFolder(
        id: subjectFolderId(gradeId, subjectKey),
        name: name,
        gradeId: gradeId,
        subjectKey: subjectKey,
        custom: false,
        colorValue: colorValue,
        iconName: iconName ?? bagIconNameFor(subjectKey),
        pdfIds: const [],
        createdAt: createdAt,
      );

  final String id;
  final String name;

  /// Empty for custom folders, which belong to no grade.
  final String gradeId;
  final String subjectKey;
  final bool custom;
  final int colorValue;

  /// A HugeIcons selector name; `bag_visuals.dart` maps it to an icon.
  final String iconName;

  /// Library document ids this folder references, in display order.
  final List<String> pdfIds;
  final DateTime createdAt;

  MyBagFolder copyWith({
    String? name,
    int? colorValue,
    String? iconName,
    List<String>? pdfIds,
  }) =>
      MyBagFolder(
        id: id,
        name: name ?? this.name,
        gradeId: gradeId,
        subjectKey: subjectKey,
        custom: custom,
        colorValue: colorValue ?? this.colorValue,
        iconName: iconName ?? this.iconName,
        pdfIds: pdfIds ?? this.pdfIds,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gradeId': gradeId,
        'subjectKey': subjectKey,
        'custom': custom,
        'color': colorValue,
        'icon': iconName,
        'pdfIds': pdfIds,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  /// Null when the record is damaged; the index skips it rather than failing.
  static MyBagFolder? fromJson(Object? json) {
    final map = _asMap(json);
    if (map == null) return null;
    final id = map['id'];
    final name = map['name'];
    final gradeId = map['gradeId'];
    final subjectKey = map['subjectKey'];
    final custom = map['custom'];
    final color = map['color'];
    final icon = map['icon'];
    final createdAt = map['createdAt'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        gradeId is! String ||
        subjectKey is! String ||
        custom is! bool ||
        color is! num ||
        icon is! String ||
        icon.isEmpty ||
        createdAt is! String) {
      return null;
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) return null;
    final rawPdfIds = map['pdfIds'];
    return MyBagFolder(
      id: id,
      name: name,
      gradeId: gradeId,
      subjectKey: subjectKey,
      custom: custom,
      colorValue: color.toInt(),
      iconName: icon,
      pdfIds: rawPdfIds is List
          ? [
              for (final value in rawPdfIds)
                if (value is String) value,
            ]
          : const [],
      createdAt: parsedCreatedAt,
    );
  }
}

/// Every folder in the bag, as stored under `my_bag_index`.
class MyBagIndex {
  const MyBagIndex({this.version = 1, this.folders = const []});

  factory MyBagIndex.fromJson(Object? json) {
    final map = _asMap(json);
    if (map == null) return const MyBagIndex();
    final version = _asInt(map['version']) ?? 1;
    final raw = map['folders'];
    final folders = <MyBagFolder>[];
    if (raw is List) {
      for (final item in raw) {
        final folder = MyBagFolder.fromJson(item);
        if (folder != null) folders.add(folder);
      }
    }
    return MyBagIndex(version: version, folders: folders);
  }

  final int version;
  final List<MyBagFolder> folders;

  MyBagFolder? folderById(String id) {
    for (final folder in folders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  MyBagIndex upsert(MyBagFolder folder) {
    final next = <MyBagFolder>[];
    var replaced = false;
    for (final existing in folders) {
      if (existing.id == folder.id) {
        next.add(folder);
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) next.add(folder);
    return MyBagIndex(version: version, folders: next);
  }

  MyBagIndex remove(String id) => MyBagIndex(
        version: version,
        folders: [
          for (final folder in folders)
            if (folder.id != id) folder,
        ],
      );

  /// Drops PDF references the library no longer knows; returns `this` when
  /// nothing changed so callers can skip a write.
  MyBagIndex prunePdfRefs(Set<String> knownPdfIds) {
    var changed = false;
    final next = [
      for (final folder in folders)
        if (folder.pdfIds.every(knownPdfIds.contains))
          folder
        else ...[
          folder.copyWith(
            pdfIds: [
              for (final id in folder.pdfIds)
                if (knownPdfIds.contains(id)) id,
            ],
          ),
        ],
    ];
    for (var index = 0; index < folders.length; index++) {
      if (!identical(next[index], folders[index])) changed = true;
    }
    return changed ? MyBagIndex(version: version, folders: next) : this;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'folders': [for (final folder in folders) folder.toJson()],
      };
}

/// The media a folder owns besides its PDF references.
class MyBagFolderMedia {
  const MyBagFolderMedia({
    this.voice = const [],
    this.boards = const [],
    this.links = const [],
  });

  /// Builds the media from the decoded `meta.json` and `links.json` parts.
  ///
  /// Either part may be null (missing file) or unreadable; a broken part
  /// empties only its own pockets.
  factory MyBagFolderMedia.fromParts({Object? meta, Object? links}) {
    final metaMap = _asMap(meta) ?? const <String, dynamic>{};
    final linksMap = _asMap(links) ?? const <String, dynamic>{};
    return MyBagFolderMedia(
      voice: _decodeList(metaMap['voice'], MyBagVoiceClip.fromJson),
      boards: _decodeList(metaMap['boards'], MyBagBoardImage.fromJson),
      links: _decodeList(linksMap['links'], MyBagLink.fromJson),
    );
  }

  final List<MyBagVoiceClip> voice;
  final List<MyBagBoardImage> boards;
  final List<MyBagLink> links;

  int countFor(BagPocketKind kind) => switch (kind) {
        BagPocketKind.pdfs => 0,
        BagPocketKind.voice => voice.length,
        BagPocketKind.boards => boards.length,
        BagPocketKind.links => links.length,
      };

  /// The newest additions across the three media pockets, newest first.
  List<MyBagRecentItem> recent(int max) {
    final items = <MyBagRecentItem>[
      for (final clip in voice)
        MyBagRecentItem(
          kind: BagPocketKind.voice,
          title: clip.title,
          createdAtMs: clip.createdAtMs,
        ),
      for (final board in boards)
        MyBagRecentItem(
          kind: BagPocketKind.boards,
          title: '',
          createdAtMs: board.createdAtMs,
        ),
      for (final link in links)
        MyBagRecentItem(
          kind: BagPocketKind.links,
          title: link.title,
          createdAtMs: link.createdAtMs,
        ),
    ]..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return items.take(max).toList();
  }

  MyBagFolderMedia copyWith({
    List<MyBagVoiceClip>? voice,
    List<MyBagBoardImage>? boards,
    List<MyBagLink>? links,
  }) =>
      MyBagFolderMedia(
        voice: voice ?? this.voice,
        boards: boards ?? this.boards,
        links: links ?? this.links,
      );

  Map<String, dynamic> toMetaJson() => {
        'voice': [for (final clip in voice) clip.toJson()],
        'boards': [for (final board in boards) board.toJson()],
      };

  Map<String, dynamic> toLinksJson() => {
        'links': [for (final link in links) link.toJson()],
      };
}

/// One entry of a folder's «آخر ما أضفت» list.
class MyBagRecentItem {
  const MyBagRecentItem({
    required this.kind,
    required this.title,
    required this.createdAtMs,
  });

  final BagPocketKind kind;

  /// Empty for board images, which have no name.
  final String title;
  final int createdAtMs;
}

/// How many items each pocket holds across the whole bag.
class PocketTotals {
  const PocketTotals({
    this.pdfs = 0,
    this.voice = 0,
    this.boards = 0,
    this.links = 0,
  });

  factory PocketTotals.from(
    MyBagIndex index,
    Map<String, MyBagFolderMedia> media,
  ) {
    var pdfs = 0;
    var voice = 0;
    var boards = 0;
    var links = 0;
    for (final folder in index.folders) {
      pdfs += folder.pdfIds.length;
      final folderMedia = media[folder.id];
      if (folderMedia == null) continue;
      voice += folderMedia.voice.length;
      boards += folderMedia.boards.length;
      links += folderMedia.links.length;
    }
    return PocketTotals(
      pdfs: pdfs,
      voice: voice,
      boards: boards,
      links: links,
    );
  }

  final int pdfs;
  final int voice;
  final int boards;
  final int links;

  int get total => pdfs + voice + boards + links;

  List<int> get asList => [pdfs, voice, boards, links];
}

/// One subject folder the controller should create for the selected grade.
class MyBagSubjectSeed {
  const MyBagSubjectSeed({
    required this.gradeId,
    required this.subjectKey,
    required this.name,
    required this.colorValue,
  });

  final String gradeId;
  final String subjectKey;
  final String name;
  final int colorValue;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    }
  }
  return null;
}

int? _asInt(Object? value) => value is num ? value.toInt() : null;

List<T> _decodeList<T>(Object? raw, T? Function(Object?) decode) {
  if (raw is! List) return const [];
  final items = <T>[];
  for (final element in raw) {
    final item = decode(element);
    if (item != null) items.add(item);
  }
  return items;
}
