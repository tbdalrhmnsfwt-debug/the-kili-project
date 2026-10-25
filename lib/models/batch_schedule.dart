/// Timetable OCR results, drafts and published entries.
library;

/// One recognised word with its pixel box.
class OcrWord {
  const OcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.confidence,
    required this.lineId,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// 0–100, as Tesseract reports `x_wconf`.
  final double confidence;
  final String lineId;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  Map<String, dynamic> toJson() => {
        'text': text,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'confidence': confidence,
        'lineId': lineId,
      };

  factory OcrWord.fromJson(Map<String, dynamic> json) => OcrWord(
        text: json['text'] as String? ?? '',
        left: (json['left'] as num?)?.toDouble() ?? 0,
        top: (json['top'] as num?)?.toDouble() ?? 0,
        right: (json['right'] as num?)?.toDouble() ?? 0,
        bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        lineId: json['lineId'] as String? ?? '',
      );
}

/// A recognised line, with words kept in reading order.
class OcrLine {
  const OcrLine({required this.id, required this.words});

  final String id;
  final List<OcrWord> words;

  String get text => words.map((word) => word.text).join(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'words': [for (final word in words) word.toJson()],
      };

  factory OcrLine.fromJson(Map<String, dynamic> json) => OcrLine(
        id: json['id'] as String? ?? '',
        words: [
          for (final raw in (json['words'] as List? ?? const []))
            if (raw is Map) OcrWord.fromJson(Map<String, dynamic>.from(raw)),
        ],
      );
}

/// The complete OCR result for one image.
class OcrDocument {
  const OcrDocument({
    required this.width,
    required this.height,
    required this.lines,
    this.engine = 'tesseract-ara+eng',
  });

  final double width;
  final double height;
  final List<OcrLine> lines;
  final String engine;

  List<OcrWord> get words => [for (final line in lines) ...line.words];

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'lines': [for (final line in lines) line.toJson()],
        'engine': engine,
      };

  factory OcrDocument.fromJson(Map<String, dynamic> json) => OcrDocument(
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
        lines: [
          for (final raw in (json['lines'] as List? ?? const []))
            if (raw is Map) OcrLine.fromJson(Map<String, dynamic>.from(raw)),
        ],
        engine: json['engine'] as String? ?? 'tesseract-ara+eng',
      );
}

/// How often a timetable row repeats.
enum TimetableRecurrence { none, weekly }

/// Whether a draft is still being edited or has been published.
enum TimetableDraftStatus { draft, published }

/// One editable timetable row. Times are minutes from midnight.
class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    this.subjectId,
    this.room = '',
    this.teacher = '',
    this.confidence = 0,
    this.uncertainFields = const [],
    this.recurrence = TimetableRecurrence.none,
    this.weekAnchorDate,
    this.timeZoneId,
    this.reminderEnabled = false,
    this.allDay = false,
  });

  final String id;

  /// 1 = Monday ... 7 = Sunday, matching `DateTime.weekday`.
  final int dayOfWeek;
  final int startMinutes;
  final int endMinutes;
  final String title;
  final String? subjectId;
  final String room;
  final String teacher;
  final double confidence;
  final List<String> uncertainFields;
  final TimetableRecurrence recurrence;
  final DateTime? weekAnchorDate;
  final String? timeZoneId;
  final bool reminderEnabled;
  final bool allDay;

  bool get isComplete =>
      dayOfWeek >= 1 &&
      dayOfWeek <= 7 &&
      startMinutes >= 0 &&
      endMinutes > startMinutes &&
      title.trim().isNotEmpty;

  bool get hasTimeBasis =>
      timeZoneId != null &&
      timeZoneId!.isNotEmpty &&
      (recurrence == TimetableRecurrence.weekly || weekAnchorDate != null);

  TimetableEntry copyWith({
    int? dayOfWeek,
    int? startMinutes,
    int? endMinutes,
    String? title,
    String? subjectId,
    String? room,
    String? teacher,
    double? confidence,
    List<String>? uncertainFields,
    TimetableRecurrence? recurrence,
    DateTime? weekAnchorDate,
    String? timeZoneId,
    bool? reminderEnabled,
    bool? allDay,
  }) =>
      TimetableEntry(
        id: id,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        title: title ?? this.title,
        subjectId: subjectId ?? this.subjectId,
        room: room ?? this.room,
        teacher: teacher ?? this.teacher,
        confidence: confidence ?? this.confidence,
        uncertainFields: uncertainFields ?? this.uncertainFields,
        recurrence: recurrence ?? this.recurrence,
        weekAnchorDate: weekAnchorDate ?? this.weekAnchorDate,
        timeZoneId: timeZoneId ?? this.timeZoneId,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        allDay: allDay ?? this.allDay,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayOfWeek': dayOfWeek,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'title': title,
        if (subjectId != null) 'subjectId': subjectId,
        if (room.isNotEmpty) 'room': room,
        if (teacher.isNotEmpty) 'teacher': teacher,
        'confidence': confidence,
        if (uncertainFields.isNotEmpty) 'uncertainFields': uncertainFields,
        'recurrence': recurrence.name,
        if (weekAnchorDate != null)
          'weekAnchorDate': weekAnchorDate!.toIso8601String(),
        if (timeZoneId != null) 'timeZoneId': timeZoneId,
        'reminderEnabled': reminderEnabled,
        'allDay': allDay,
      };

  factory TimetableEntry.fromJson(Map<String, dynamic> json) => TimetableEntry(
        id: json['id'] as String? ?? '',
        dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
        startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 0,
        endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        subjectId: json['subjectId'] as String?,
        room: json['room'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        uncertainFields: [
          ...?(json['uncertainFields'] as List?)?.whereType<String>(),
        ],
        recurrence: json['recurrence'] == 'weekly'
            ? TimetableRecurrence.weekly
            : TimetableRecurrence.none,
        weekAnchorDate:
            DateTime.tryParse(json['weekAnchorDate'] as String? ?? ''),
        timeZoneId: json['timeZoneId'] as String?,
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        allDay: json['allDay'] as bool? ?? false,
      );
}

/// A timetable import, from OCR draft through publication.
class TimetableDraft {
  const TimetableDraft({
    required this.id,
    required this.batchId,
    required this.sourceImageFileName,
    required this.createdAt,
    required this.updatedAt,
    this.ocrEngine = 'tesseract-ara+eng',
    this.status = TimetableDraftStatus.draft,
    this.entries = const [],
    this.warnings = const [],
  });

  final String id;
  final String batchId;
  final String sourceImageFileName;
  final String ocrEngine;
  final TimetableDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TimetableEntry> entries;
  final List<String> warnings;

  TimetableDraft copyWith({
    TimetableDraftStatus? status,
    List<TimetableEntry>? entries,
    List<String>? warnings,
    DateTime? updatedAt,
  }) =>
      TimetableDraft(
        id: id,
        batchId: batchId,
        sourceImageFileName: sourceImageFileName,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        ocrEngine: ocrEngine,
        status: status ?? this.status,
        entries: entries ?? this.entries,
        warnings: warnings ?? this.warnings,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'sourceImageFileName': sourceImageFileName,
        'ocrEngine': ocrEngine,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'entries': [for (final entry in entries) entry.toJson()],
        if (warnings.isNotEmpty) 'warnings': warnings,
      };

  factory TimetableDraft.fromJson(Map<String, dynamic> json) => TimetableDraft(
        id: json['id'] as String? ?? '',
        batchId: json['batchId'] as String? ?? '',
        sourceImageFileName: json['sourceImageFileName'] as String? ?? '',
        ocrEngine: json['ocrEngine'] as String? ?? 'tesseract-ara+eng',
        status: json['status'] == 'published'
            ? TimetableDraftStatus.published
            : TimetableDraftStatus.draft,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        entries: [
          for (final raw in (json['entries'] as List? ?? const []))
            if (raw is Map)
              TimetableEntry.fromJson(Map<String, dynamic>.from(raw)),
        ],
        warnings: [...?(json['warnings'] as List?)?.whereType<String>()],
      );
}
