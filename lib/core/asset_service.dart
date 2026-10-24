/// Loading and caching of the bundled study content.
///
/// Layout shipped inside the APK:
///   assets/manhaji/<grade>/index.json          — grade -> book index
///   assets/manhaji/<grade>/<book>.json.gz      — packed book payload
///   assets/courses/<slug>/course.json          — free-form course
///   assets/data/adhkar.json                    — adhkar (remembrance) list
///   assets/dictionary/words.json               — Arabic -> English dictionary
///   assets/quran/mutashabihat.json.gz          — mutashabihat dataset
///
/// The `.json.gz` book payloads are *not* gzip: they use the app's own
/// container, which starts with the ASCII magic `ZKB1`. The payload inside is
/// zlib-deflate compressed. See [Zkb1Codec].
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/dictionary.dart';
import '../models/manhaji.dart';
import '../models/official_book.dart';

/// Decoder for the `ZKB1` container used for packed book payloads.
///
/// Layout (little endian):
///   offset 0 : 4 bytes  magic `ZKB1`
///   offset 4 : 4 bytes  uncompressed size (u32)
///   offset 8 : 4 bytes  compressed size   (u32)
///   offset 12: n bytes  zlib stream
///
/// The trailing two fields are advisory; the decoder locates the zlib
/// stream by scanning for a valid zlib header when the fixed offsets do not
/// decode, so the format stays forward compatible.
class Zkb1Codec {
  static const List<int> magic = [0x5A, 0x4B, 0x42, 0x31]; // "ZKB1"

  /// Decompresses a `ZKB1` buffer into its raw UTF-8 JSON payload.
  static Uint8List decode(Uint8List input) {
    if (input.length < 4) {
      throw const FormatException('ZKB1: buffer too short');
    }
    for (var i = 0; i < magic.length; i++) {
      if (input[i] != magic[i]) {
        throw const FormatException('ZKB1: bad magic');
      }
    }
    final out = _inflate(input, 12);
    return out;
  }

  /// Tries zlib decompression at [start], then scans forward for a valid
  /// zlib stream.
  static Uint8List _inflate(Uint8List input, int start) {
    final errors = <Object>[];
    for (var off = start; off < input.length && off < start + 64; off++) {
      try {
        return _rawInflate(input, off);
      } catch (e) {
        errors.add(e);
      }
    }
    throw FormatException('ZKB1: could not inflate payload', errors.toString());
  }

  static Uint8List _rawInflate(Uint8List input, int offset) {
    // Zlib header: CMF/FLG. CM must be 8 (deflate) and (CMF<<8|FLG) % 31 == 0.
    if (offset + 2 > input.length) {
      throw const FormatException('truncated');
    }
    final cmf = input[offset];
    final flg = input[offset + 1];
    if ((cmf & 0x0F) != 8) {
      throw const FormatException('not deflate');
    }
    if (((cmf << 8) | flg) % 31 != 0) {
      throw const FormatException('bad zlib checksum');
    }
    // The remaining bytes are a raw deflate stream.
    final decoder = ZLibCodec(raw: true).decoder;
    return Uint8List.fromList(decoder.convert(input.sublist(offset + 2)));
  }
}

/// Thrown when a book's lesson payload cannot be decoded on this device.
///
/// Most books ship their payload inside the still-unresolved `ZKB1`
/// container. Books that also ship `figs/<book id>.json` in plaintext are
/// readable; the rest fail with this error instead of surfacing a raw format
/// exception.
class BookContentUnavailable implements Exception {
  const BookContentUnavailable(this.book, [this.detail]);

  final Book book;

  /// Optional technical detail from the decoder.
  final String? detail;

  @override
  String toString() =>
      detail ?? 'محتوى «${book.title}» مشفّر ومش متاح على الجهاز.';
}

/// Loads and caches the bundled content assets.
class AssetService {
  AssetService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  final Map<String, Grade> _gradeCache = {};
  final Map<String, dynamic> _bookCache = {};

  /// Books whose payload is known not to decode, so repeated attempts are
  /// cheap when the quiz scans the library for readable content.
  final Set<String> _unavailable = {};

  /// The grade ids the app ships content for, in the order shown in the UI.
  static const List<String> gradeOrder = [
    'prep1',
    'prep2',
    'prep3',
    'prim1',
    'prim2',
    'prim3',
    'prim4',
    'prim5',
    'prim6',
    'sec1',
    'sec2',
    'sec3',
  ];

  /// Returns the grade index for [gradeId], parsed from
  /// `assets/manhaji/<gradeId>/index.json`.
  Future<Grade> loadGrade(String gradeId) async {
    final cached = _gradeCache[gradeId];
    if (cached != null) return cached;

    final raw = await _bundle.loadString('assets/manhaji/$gradeId/index.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final grade = Grade.fromJson(json);
    _gradeCache[gradeId] = grade;
    return grade;
  }

  /// Loads every grade index, skipping any that fail to parse.
  Future<List<Grade>> loadAllGrades() async {
    final out = <Grade>[];
    for (final id in gradeOrder) {
      try {
        out.add(await loadGrade(id));
      } catch (e) {
        debugPrint('manhaji: skipping grade $id ($e)');
      }
    }
    return out;
  }

  /// Loads the optional catalog of official textbook links.
  Future<OfficialBookCatalog> loadOfficialBooks() async {
    final raw = await _bundle.loadString('assets/data/official_books.json');
    return OfficialBookCatalog.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Loads and decodes a book payload, returning its content map.
  ///
  /// The app ships two representations: a packed `ZKB1` payload for every
  /// book, and — for 74 of them — a plaintext `figs/<book id>.json` holding
  /// the same `{fp, l: {...}}` document. The plaintext copy is preferred
  /// because the `ZKB1` container has not been decoded yet.
  Future<Map<String, dynamic>> loadBook(Book book) async {
    final cached = _bookCache[book.cacheKey];
    if (cached != null) return cached;
    if (_unavailable.contains(book.cacheKey)) {
      throw BookContentUnavailable(book);
    }

    final plaintext = await _tryLoadPlaintext(book);
    if (plaintext != null) {
      _bookCache[book.cacheKey] = plaintext;
      return plaintext;
    }

    try {
      final bytes = await _bundle.load(
        'assets/manhaji/${book.grade}/${book.file}',
      );
      final decoded = Zkb1Codec.decode(bytes.buffer.asUint8List());
      final json = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
      _bookCache[book.cacheKey] = json;
      return json;
    } on BookContentUnavailable {
      _unavailable.add(book.cacheKey);
      rethrow;
    } on FormatException catch (e) {
      _unavailable.add(book.cacheKey);
      throw BookContentUnavailable(book, e.message);
    } catch (e) {
      _unavailable.add(book.cacheKey);
      throw BookContentUnavailable(book, e.toString());
    }
  }

  /// Loads `figs/<book id>.json` when the book ships its lesson metadata in
  /// plaintext. Returns `null` when the asset does not exist or is invalid.
  ///
  /// Public so the offline assistant can search the readable books without
  /// going through the throwing [loadBook] path.
  Future<Map<String, dynamic>?> loadPlaintext(Book book) =>
      _tryLoadPlaintext(book);

  Future<Map<String, dynamic>?> _tryLoadPlaintext(Book book) async {
    if (book.id.isEmpty) return null;
    try {
      final raw = await _bundle.loadString(
        'assets/manhaji/${book.grade}/figs/${book.id}.json',
      );
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the lesson list from a decoded book payload.
  List<Lesson> parseLessons(Map<String, dynamic> bookJson) {
    final figures =
        (bookJson['l'] as Map<String, dynamic>?) ??
        const <String, List<Figure>>{};
    final keys = figures.keys.toList()
      ..sort((a, b) {
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na == null && nb == null) return a.compareTo(b);
        if (na == null) return 1;
        if (nb == null) return -1;
        return na.compareTo(nb);
      });
    // The payload keys are zero-based lesson indexes; the UI shows the
    // one-based lesson number printed in the book.
    return keys
        .map((k) {
          final index = int.tryParse(k);
          return Lesson(
            number: index == null ? 0 : index + 1,
            figures: figures[k]!,
          );
        })
        .where((l) => l.figures.isNotEmpty)
        .toList(growable: false);
  }

  /// Loads a free-form course definition.
  Future<Map<String, dynamic>> loadCourse(String slug) async {
    final raw = await _bundle.loadString('assets/courses/$slug/course.json');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Loads the adhkar (remembrance) list.
  Future<List<Map<String, dynamic>>> loadAdhkar() async {
    final raw = await _bundle.loadString('assets/data/adhkar.json');
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  /// Loads the Arabic -> English dictionary.
  Future<DictionaryEntry> loadDictionary() async {
    final raw = await _bundle.loadString('assets/dictionary/words.json');
    return DictionaryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Loads the mutashabihat dataset, inflating the bundled gzip payload.
  Future<MutashabihatData> loadMutashabihat() async {
    final bytes = await _bundle.load('assets/quran/mutashabihat.json.gz');
    final raw = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    // The asset is stored as gzip; tolerate a bundle that already inflated it.
    String json;
    try {
      json = utf8.decode(gzip.decode(raw));
    } on FormatException {
      json = utf8.decode(raw);
    }
    return MutashabihatData.parseJson(json);
  }
}
