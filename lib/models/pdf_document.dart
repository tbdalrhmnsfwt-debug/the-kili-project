/// One PDF in the app's private library.
///
/// This model is deliberately Flutter-free so the library index can be
/// verified with plain Dart. Colours and dates stay primitive; the UI layer
/// converts where it needs to.
library;

/// Where a library document came from.
enum PdfDocumentSource {
  /// Copied in from the device through the document picker.
  imported,

  /// Produced by one of the app's PDF tools.
  generated,
}

/// What is known about a document's encryption.
enum PdfEncryptionState {
  /// Not determined yet (for example, an encrypted import).
  unknown,

  /// The document opens without a password.
  no,

  /// The document needs a password before it can be read.
  yes,
}

const Object _unset = Object();

/// A document recorded in «ملفاتي».
class PdfDocumentEntry {
  const PdfDocumentEntry({
    required this.id,
    required this.displayName,
    required this.baseFileName,
    this.originalName,
    required this.sizeBytes,
    this.pageCount,
    required this.addedAt,
    this.lastOpenedAt,
    this.lastPage = 1,
    this.lastZoom = 1,
    this.lastQuarterTurns = 0,
    this.favorite = false,
    this.thumbnailFileName,
    this.annotationCount = 0,
    this.source = PdfDocumentSource.imported,
    this.encryption = PdfEncryptionState.unknown,
    this.exportedAt,
    this.gradeId = '',
    this.subjectKey = '',
    this.sourceDocId = '',
  });

  /// Stable identifier used for filenames and routes.
  final String id;

  /// The name shown in the catalog (renameable without touching the file).
  final String displayName;

  /// The app-private copy the reader opens.
  final String baseFileName;

  /// The name the file had where the user picked it.
  final String? originalName;

  final int sizeBytes;

  /// Null until the file has been opened successfully.
  final int? pageCount;

  final DateTime addedAt;
  final DateTime? lastOpenedAt;

  /// One-based page to restore when the document is reopened.
  final int lastPage;

  /// Pinch-zoom scale to restore when the document is reopened, 1–5.
  final double lastZoom;

  /// Clockwise quarter turns to restore when the document is reopened, 0–3.
  final int lastQuarterTurns;

  final bool favorite;
  final String? thumbnailFileName;
  final int annotationCount;
  final PdfDocumentSource source;
  final PdfEncryptionState encryption;
  final DateTime? exportedAt;

  /// The grade a bag folder tagged this document with; empty when untagged.
  final String gradeId;

  /// The subject the bag folder tagged this document with; empty when untagged.
  final String subjectKey;

  /// The generated document this PDF came from, when a tool made it.
  final String sourceDocId;

  PdfDocumentEntry copyWith({
    String? id,
    String? displayName,
    String? baseFileName,
    Object? originalName = _unset,
    int? sizeBytes,
    Object? pageCount = _unset,
    DateTime? addedAt,
    Object? lastOpenedAt = _unset,
    int? lastPage,
    double? lastZoom,
    int? lastQuarterTurns,
    bool? favorite,
    Object? thumbnailFileName = _unset,
    int? annotationCount,
    PdfDocumentSource? source,
    PdfEncryptionState? encryption,
    Object? exportedAt = _unset,
    String? gradeId,
    String? subjectKey,
    String? sourceDocId,
  }) {
    return PdfDocumentEntry(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      baseFileName: baseFileName ?? this.baseFileName,
      originalName: identical(originalName, _unset)
          ? this.originalName
          : originalName as String?,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pageCount:
          identical(pageCount, _unset) ? this.pageCount : pageCount as int?,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: identical(lastOpenedAt, _unset)
          ? this.lastOpenedAt
          : lastOpenedAt as DateTime?,
      lastPage: lastPage ?? this.lastPage,
      lastZoom: lastZoom ?? this.lastZoom,
      lastQuarterTurns: lastQuarterTurns ?? this.lastQuarterTurns,
      favorite: favorite ?? this.favorite,
      thumbnailFileName: identical(thumbnailFileName, _unset)
          ? this.thumbnailFileName
          : thumbnailFileName as String?,
      annotationCount: annotationCount ?? this.annotationCount,
      source: source ?? this.source,
      encryption: encryption ?? this.encryption,
      exportedAt: identical(exportedAt, _unset)
          ? this.exportedAt
          : exportedAt as DateTime?,
      gradeId: gradeId ?? this.gradeId,
      subjectKey: subjectKey ?? this.subjectKey,
      sourceDocId: sourceDocId ?? this.sourceDocId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': displayName,
        'base': baseFileName,
        if (originalName != null) 'originalName': originalName,
        'size': sizeBytes,
        if (pageCount != null) 'pages': pageCount,
        'addedAt': addedAt.toUtc().toIso8601String(),
        if (lastOpenedAt != null)
          'lastOpenedAt': lastOpenedAt!.toUtc().toIso8601String(),
        'lastPage': lastPage,
        'lastZoom': lastZoom,
        'lastQuarterTurns': lastQuarterTurns,
        'favorite': favorite,
        if (thumbnailFileName != null) 'thumb': thumbnailFileName,
        'annotations': annotationCount,
        'source': source.name,
        'encryption': encryption.name,
        if (exportedAt != null)
          'exportedAt': exportedAt!.toUtc().toIso8601String(),
        if (gradeId.isNotEmpty) 'gradeId': gradeId,
        if (subjectKey.isNotEmpty) 'subjectKey': subjectKey,
        if (sourceDocId.isNotEmpty) 'sourceDocId': sourceDocId,
      };

  factory PdfDocumentEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final base = json['base'];
    final size = json['size'];
    final added = json['addedAt'];
    if (id is! String || name is! String || base is! String) {
      throw const FormatException('invalid pdf document entry');
    }
    if (size is! num || added is! String) {
      throw const FormatException('invalid pdf document entry');
    }
    final addedAt = DateTime.tryParse(added);
    if (addedAt == null) {
      throw const FormatException('invalid pdf document entry');
    }
    return PdfDocumentEntry(
      id: id,
      displayName: name,
      baseFileName: base,
      originalName: json['originalName'] as String?,
      sizeBytes: size.toInt(),
      pageCount: (json['pages'] as num?)?.toInt(),
      addedAt: addedAt,
      lastOpenedAt: _date(json['lastOpenedAt']),
      lastPage: (json['lastPage'] as num?)?.toInt() ?? 1,
      lastZoom: ((json['lastZoom'] as num?)?.toDouble() ?? 1)
          .clamp(1.0, 5.0)
          .toDouble(),
      // `%` on a negative int also lands in 0–3, so corrupt data is harmless.
      lastQuarterTurns: ((json['lastQuarterTurns'] as num?)?.toInt() ?? 0) % 4,
      favorite: json['favorite'] as bool? ?? false,
      thumbnailFileName: json['thumb'] as String?,
      annotationCount: (json['annotations'] as num?)?.toInt() ?? 0,
      source: _source(json['source']),
      encryption: _encryption(json['encryption']),
      exportedAt: _date(json['exportedAt']),
      gradeId: json['gradeId'] as String? ?? '',
      subjectKey: json['subjectKey'] as String? ?? '',
      sourceDocId: json['sourceDocId'] as String? ?? '',
    );
  }

  static DateTime? _date(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  static PdfDocumentSource _source(Object? raw) {
    for (final value in PdfDocumentSource.values) {
      if (value.name == raw) return value;
    }
    return PdfDocumentSource.imported;
  }

  static PdfEncryptionState _encryption(Object? raw) {
    for (final value in PdfEncryptionState.values) {
      if (value.name == raw) return value;
    }
    return PdfEncryptionState.unknown;
  }
}
