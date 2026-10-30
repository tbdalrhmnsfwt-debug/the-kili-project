/// Durable on-device state for the official book library.
///
/// The state lives in SharedPreferences as JSON (the app deliberately has no
/// SQL dependency). This store adds what plain JSON storage lacks:
///
///   * a schema version and forward-only migrations;
///   * a last-known-good backup that is used when the primary value is
///     corrupt, so one bad write never loses a student's whole library;
///   * recovery of interrupted downloads/extractions after a crash;
///   * export/import that never deletes an existing verified file.
///
/// The store itself never throws. Corrupt data is reported through
/// [OfficialLibraryLoad.corrupt] and the raw string is retained under
/// [corruptKey] for diagnostics rather than being silently discarded.
library;

import 'dart:convert';

import '../models/official_book.dart';
import 'key_value_store.dart';

/// The current persisted schema. Increment when the JSON shape changes and
/// add a migration in [_migrate].
const int kOfficialLibrarySchemaVersion = 1;

/// The state key (the [LocalStore] adds the `zaker.` prefix).
const String kOfficialLibraryKey = 'official_library.state';
const String kOfficialLibraryBackupKey = 'official_library.state.backup';
const String kOfficialLibraryCorruptKey = 'official_library.state.corrupt';

/// Everything the app remembers about the official library on this device.
class OfficialLibraryState {
  const OfficialLibraryState({
    this.schemaVersion = kOfficialLibrarySchemaVersion,
    this.books = const {},
    this.queue = const [],
    this.catalogVersion = 0,
    this.lastCatalogCheck,
    this.updatedAt,
  });

  final int schemaVersion;

  /// Download/extraction state keyed by [OfficialBook.id].
  final Map<String, BookLocalState> books;

  /// Books the student asked to download, in order. Persisted so a restart
  /// resumes work instead of forgetting it.
  final List<String> queue;

  final int catalogVersion;
  final DateTime? lastCatalogCheck;
  final DateTime? updatedAt;

  bool get isEmpty => books.isEmpty && queue.isEmpty;

  BookLocalState? stateFor(String bookId) => books[bookId];

  OfficialLibraryState copyWith({
    int? schemaVersion,
    Map<String, BookLocalState>? books,
    List<String>? queue,
    int? catalogVersion,
    DateTime? lastCatalogCheck,
    DateTime? updatedAt,
  }) => OfficialLibraryState(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    books: books ?? this.books,
    queue: queue ?? this.queue,
    catalogVersion: catalogVersion ?? this.catalogVersion,
    lastCatalogCheck: lastCatalogCheck ?? this.lastCatalogCheck,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Updates one book's state, preserving the rest.
  OfficialLibraryState withBook(BookLocalState value) => copyWith(
    books: {...books, value.bookId: value},
    updatedAt: DateTime.now(),
  );

  /// Removes a state row but never touches the PDF on disk.
  OfficialLibraryState withoutBook(String bookId) {
    final next = Map<String, BookLocalState>.from(books)..remove(bookId);
    return copyWith(
      books: next,
      queue: queue.where((id) => id != bookId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'catalog_version': catalogVersion,
    if (lastCatalogCheck != null)
      'last_catalog_check': lastCatalogCheck!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    'queue': queue,
    'books': {
      for (final entry in books.entries) entry.key: entry.value.toJson(),
    },
  };

  factory OfficialLibraryState.fromJson(Map<String, dynamic> json) {
    final rawBooks = json['books'];
    final books = <String, BookLocalState>{};
    if (rawBooks is Map) {
      for (final entry in rawBooks.entries) {
        if (entry.value is! Map) continue;
        final row = BookLocalState.fromJson(
          (entry.value as Map).cast<String, dynamic>(),
        );
        final id = row.bookId.isNotEmpty ? row.bookId : '${entry.key}';
        if (id.isEmpty) continue;
        books[id] = BookLocalState.fromJson({
          ...(entry.value as Map).cast<String, dynamic>(),
          'book_id': id,
        });
      }
    } else if (rawBooks is List) {
      // Older formats stored a list of rows.
      for (final value in rawBooks) {
        if (value is! Map) continue;
        final row = BookLocalState.fromJson(value.cast<String, dynamic>());
        if (row.bookId.isNotEmpty) books[row.bookId] = row;
      }
    }
    final queue = <String>[];
    for (final value in (json['queue'] as List?) ?? const []) {
      final id = '$value';
      if (id.isNotEmpty && !queue.contains(id)) queue.add(id);
    }
    return OfficialLibraryState(
      schemaVersion: _int(json['schema_version']) ?? 0,
      books: books,
      queue: queue,
      catalogVersion: _int(json['catalog_version']) ?? 0,
      lastCatalogCheck: _date(json['last_catalog_check']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

/// The result of reading persisted state.
class OfficialLibraryLoad {
  const OfficialLibraryLoad({
    required this.state,
    this.corrupt = false,
    this.recoveredFromBackup = false,
    this.migratedFrom = 0,
    this.message = '',
  });

  final OfficialLibraryState state;
  final bool corrupt;
  final bool recoveredFromBackup;

  /// The schema version read from disk before migration; 0 when unversioned.
  final int migratedFrom;
  final String message;
}

/// The result of importing an exported library.
class OfficialLibraryImport {
  const OfficialLibraryImport({
    required this.imported,
    required this.skipped,
    required this.conflicts,
    this.error = '',
  });

  final int imported;
  final int skipped;
  final int conflicts;
  final String error;

  bool get ok => error.isEmpty;
}

/// JSON persistence for [OfficialLibraryState].
class OfficialLibraryStore {
  const OfficialLibraryStore(this._prefs);

  final KeyValueStore _prefs;

  /// Reads, migrates and repairs the persisted state.
  OfficialLibraryLoad load() {
    final raw = _prefs.getString(kOfficialLibraryKey);
    if (raw != null) {
      final parsed = _decode(raw);
      if (parsed != null) {
        return _finish(parsed, fromBackup: false);
      }
      _keepCorrupt(raw);
    }

    final backupRaw = _prefs.getString(kOfficialLibraryBackupKey);
    if (backupRaw != null) {
      final parsed = _decode(backupRaw);
      if (parsed != null) {
        return _finish(
          parsed,
          fromBackup: true,
          message:
              'اتصلح ملف المكتبة من النسخة الاحتياطية الأخيرة. '
              'حالة تحميل واحدة على الأكثر هي اللي ممكن تكون اتأثرت.',
        );
      }
    }

    if (raw == null && backupRaw == null) {
      return const OfficialLibraryLoad(state: OfficialLibraryState());
    }
    return OfficialLibraryLoad(
      state: const OfficialLibraryState(),
      corrupt: true,
      message:
          'ملف مكتبة الكتب كان تالف ومقدرناش نقراه. '
          'الكتب المنزّلة على الجهاز ما اتمسحتش، وتقدر تعيد فحصها من المكتبة.',
    );
  }

  /// Writes the state. The previous good copy becomes the backup.
  Future<void> save(OfficialLibraryState state) async {
    final encoded = jsonEncode({
      ...state.toJson(),
      'schema_version': kOfficialLibrarySchemaVersion,
      'updated_at': DateTime.now().toIso8601String(),
    });
    final previous = _prefs.getString(kOfficialLibraryKey);
    if (previous != null) {
      await _prefs.setString(kOfficialLibraryBackupKey, previous);
    }
    await _prefs.setString(kOfficialLibraryKey, encoded);
  }

  /// A shareable export. Contains no credentials — only book ids, statuses
  /// and hashes. Local absolute paths are omitted so an export can move
  /// between devices.
  Map<String, dynamic> export() {
    final state = load().state;
    return {
      'kind': 'thakir_official_library',
      'schema_version': kOfficialLibrarySchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'books': state.books.map(
        (id, value) => MapEntry(id, {
          ...value.toJson(),
          'file_path': '',
          'extracted_path': '',
        }),
      ),
    };
  }

  /// Merges an exported payload into the current state.
  ///
  /// Conflict rule: a row that is downloaded with a hash on this device wins
  /// over an imported row with a different hash. Nothing is deleted.
  Future<OfficialLibraryImport> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const OfficialLibraryImport(
        imported: 0,
        skipped: 0,
        conflicts: 0,
        error: 'الملف مش JSON صالح.',
      );
    }
    if (decoded is! Map) {
      return const OfficialLibraryImport(
        imported: 0,
        skipped: 0,
        conflicts: 0,
        error: 'الملف المستورد مش نسخة مكتبة معروفة.',
      );
    }
    final json = decoded.cast<String, dynamic>();
    if (json['kind'] != 'thakir_official_library') {
      return const OfficialLibraryImport(
        imported: 0,
        skipped: 0,
        conflicts: 0,
        error: 'الملف مش نسخة مكتبة رفيق الطالب.',
      );
    }

    final current = load().state;
    final books = Map<String, BookLocalState>.from(current.books);
    var imported = 0;
    var skipped = 0;
    var conflicts = 0;

    final rows = json['books'];
    if (rows is Map) {
      for (final entry in rows.entries) {
        if (entry.value is! Map) {
          skipped++;
          continue;
        }
        final id = '${entry.key}';
        final incoming = BookLocalState.fromJson({
          ...(entry.value as Map).cast<String, dynamic>(),
          'book_id': id,
        });
        final existing = books[id];
        if (existing == null || !existing.hasFile) {
          books[id] = incoming.copyWith(
            filePath: existing?.filePath ?? '',
            extractedPath: existing?.extractedPath ?? '',
          );
          imported++;
          continue;
        }
        if (incoming.hasFile &&
            incoming.sha256.isNotEmpty &&
            existing.sha256.isNotEmpty &&
            incoming.sha256 != existing.sha256) {
          conflicts++;
          continue;
        }
        // Keep the local file path and any newer local extraction.
        books[id] = incoming.copyWith(
          filePath: existing.filePath,
          extractedPath: existing.extractedPath,
        );
        imported++;
      }
    } else {
      return const OfficialLibraryImport(
        imported: 0,
        skipped: 0,
        conflicts: 0,
        error: 'النسخة المستوردة مفيهاش قائمة كتب.',
      );
    }

    await save(
      current.copyWith(
        books: books,
        catalogVersion: current.catalogVersion,
        updatedAt: DateTime.now(),
      ),
    );
    return OfficialLibraryImport(
      imported: imported,
      skipped: skipped,
      conflicts: conflicts,
    );
  }

  /// For diagnostics and tests: the raw corrupt value, if any.
  String? get corruptPayload => _prefs.getString(kOfficialLibraryCorruptKey);

  OfficialLibraryLoad _finish(
    Map<String, dynamic> json, {
    required bool fromBackup,
    String message = '',
  }) {
    final before = _int(json['schema_version']) ?? 0;
    final migrated = _migrate(json, before);
    final state = _recoverInterrupted(OfficialLibraryState.fromJson(migrated));
    return OfficialLibraryLoad(
      state: state.copyWith(schemaVersion: kOfficialLibrarySchemaVersion),
      recoveredFromBackup: fromBackup,
      migratedFrom: before,
      message: message,
    );
  }

  /// Forward-only migrations. Version 1 is the first schema; version 0 means
  /// an unversioned, older payload. Unknown future versions are read
  /// best-effort rather than rejected, so a rollback never wipes the library.
  Map<String, dynamic> _migrate(Map<String, dynamic> json, int from) {
    if (from >= kOfficialLibrarySchemaVersion) return json;
    final next = Map<String, dynamic>.from(json);
    if (from < 1) {
      // Unversioned payloads used `book_id` at the top level of each row and
      // sometimes stored the map as a list. [fromJson] handles both; normalize
      // the queue field name.
      final legacyQueue = next['pending'];
      if (legacyQueue is List && next['queue'] == null) {
        next['queue'] = legacyQueue;
      }
      next.remove('pending');
    }
    next['schema_version'] = kOfficialLibrarySchemaVersion;
    return next;
  }

  /// A crash can leave a row saying `downloading` or `extracting`. The `.part`
  /// file and any finished extraction chunks remain valid, so the rows go
  /// back to the queue instead of being failed or discarded.
  OfficialLibraryState _recoverInterrupted(OfficialLibraryState state) {
    final books = <String, BookLocalState>{};
    final queue = List<String>.from(state.queue);
    var changed = false;
    for (final entry in state.books.entries) {
      final row = entry.value;
      var next = row;
      if (row.downloadStatus == BookDownloadStatus.downloading) {
        next = next.copyWith(
          downloadStatus: BookDownloadStatus.queued,
          error: '',
          updatedAt: DateTime.now(),
        );
        if (!queue.contains(row.bookId)) {
          queue.insert(0, row.bookId);
        }
        changed = true;
      } else if (row.downloadStatus == BookDownloadStatus.queued &&
          !queue.contains(row.bookId)) {
        queue.add(row.bookId);
      }
      if (row.extractionStatus == BookExtractionStatus.extracting ||
          row.extractionStatus == BookExtractionStatus.organizing) {
        next = next.copyWith(
          extractionStatus: BookExtractionStatus.notStarted,
          updatedAt: DateTime.now(),
        );
        changed = true;
      }
      books[entry.key] = next;
    }
    // Queued rows that no longer have a state are dropped.
    queue.removeWhere((id) => !books.containsKey(id));
    if (!changed && books.length == state.books.length) {
      return state.copyWith(queue: queue);
    }
    return state.copyWith(books: books, queue: queue);
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  void _keepCorrupt(String raw) {
    try {
      _prefs.setString(kOfficialLibraryCorruptKey, raw);
    } catch (_) {
      // The store is already unavailable; nothing more to do.
    }
  }
}

int? _int(Object? value) => value is num
    ? value.toInt()
    : int.tryParse('${value ?? ''}');

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
