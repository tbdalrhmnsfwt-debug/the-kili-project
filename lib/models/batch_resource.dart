/// Resources attached to a batch subject, and their per-user playback state.
library;

/// What kind of resource a card represents.
enum ResourceKind { pdf, audio, note }

/// The state of the on-device text/OCR extraction for a PDF.
enum ResourceProcessingState { none, extracting, ready, failed, blocked }

/// Transcription is unavailable in this build; the other values exist so a
/// future provider can record real job state without a schema break.
enum TranscriptionState { unavailable, queued, processing, completed, failed }

/// A week/day label inside a subject. This is not a calendar date.
class WeekDay {
  const WeekDay({required this.week, required this.day});

  final int week;
  final int day;

  Map<String, dynamic> toJson() => {'week': week, 'day': day};

  factory WeekDay.fromJson(Map<String, dynamic> json) => WeekDay(
        week: (json['week'] as num?)?.toInt() ?? 1,
        day: (json['day'] as num?)?.toInt() ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is WeekDay && other.week == week && other.day == day;

  @override
  int get hashCode => Object.hash(week, day);
}

/// A file or note inside a batch.
class BatchResource {
  const BatchResource({
    required this.id,
    required this.batchId,
    required this.subjectId,
    required this.kind,
    required this.title,
    required this.uploaderUid,
    required this.createdAt,
    this.weekDay,
    this.fileName = '',
    this.mime = '',
    this.sizeBytes = 0,
    this.durationMs,
    this.starredBy = const {},
    this.sha256 = '',
    this.processingState = ResourceProcessingState.none,
    this.transcriptionState = TranscriptionState.unavailable,
    this.note = '',
  });

  final String id;
  final String batchId;
  final String subjectId;
  final WeekDay? weekDay;
  final ResourceKind kind;
  final String title;
  final String fileName;
  final String mime;
  final int sizeBytes;
  final int? durationMs;
  final String uploaderUid;
  final DateTime createdAt;
  final Set<String> starredBy;
  final String sha256;
  final ResourceProcessingState processingState;
  final TranscriptionState transcriptionState;
  final String note;

  BatchResource copyWith({
    String? subjectId,
    String? title,
    String? fileName,
    String? mime,
    int? sizeBytes,
    int? durationMs,
    Set<String>? starredBy,
    String? sha256,
    ResourceProcessingState? processingState,
    TranscriptionState? transcriptionState,
    String? note,
    WeekDay? weekDay,
  }) =>
      BatchResource(
        id: id,
        batchId: batchId,
        subjectId: subjectId ?? this.subjectId,
        kind: kind,
        title: title ?? this.title,
        uploaderUid: uploaderUid,
        createdAt: createdAt,
        weekDay: weekDay ?? this.weekDay,
        fileName: fileName ?? this.fileName,
        mime: mime ?? this.mime,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        durationMs: durationMs ?? this.durationMs,
        starredBy: starredBy ?? this.starredBy,
        sha256: sha256 ?? this.sha256,
        processingState: processingState ?? this.processingState,
        transcriptionState: transcriptionState ?? this.transcriptionState,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'subjectId': subjectId,
        if (weekDay != null) 'weekDay': weekDay!.toJson(),
        'kind': kind.name,
        'title': title,
        if (fileName.isNotEmpty) 'fileName': fileName,
        if (mime.isNotEmpty) 'mime': mime,
        'sizeBytes': sizeBytes,
        if (durationMs != null) 'durationMs': durationMs,
        'uploaderUid': uploaderUid,
        'createdAt': createdAt.toIso8601String(),
        if (starredBy.isNotEmpty) 'starredBy': starredBy.toList(),
        if (sha256.isNotEmpty) 'sha256': sha256,
        'processingState': processingState.name,
        'transcriptionState': transcriptionState.name,
        if (note.isNotEmpty) 'note': note,
      };

  factory BatchResource.fromJson(Map<String, dynamic> json) => BatchResource(
        id: json['id'] as String? ?? '',
        batchId: json['batchId'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        kind: switch (json['kind'] as String?) {
          'audio' => ResourceKind.audio,
          'note' => ResourceKind.note,
          _ => ResourceKind.pdf,
        },
        title: json['title'] as String? ?? '',
        uploaderUid: json['uploaderUid'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        weekDay: json['weekDay'] is Map
            ? WeekDay.fromJson(
                Map<String, dynamic>.from(json['weekDay'] as Map))
            : null,
        fileName: json['fileName'] as String? ?? '',
        mime: json['mime'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt(),
        starredBy: {...?(json['starredBy'] as List?)?.whereType<String>()},
        sha256: json['sha256'] as String? ?? '',
        processingState: switch (json['processingState'] as String?) {
          'extracting' => ResourceProcessingState.extracting,
          'ready' => ResourceProcessingState.ready,
          'failed' => ResourceProcessingState.failed,
          'blocked' => ResourceProcessingState.blocked,
          _ => ResourceProcessingState.none,
        },
        transcriptionState: switch (json['transcriptionState'] as String?) {
          'queued' => TranscriptionState.queued,
          'processing' => TranscriptionState.processing,
          'completed' => TranscriptionState.completed,
          'failed' => TranscriptionState.failed,
          _ => TranscriptionState.unavailable,
        },
        note: json['note'] as String? ?? '',
      );
}

/// Where playback resumes for one user and one resource.
class PlaybackPosition {
  const PlaybackPosition({
    required this.uid,
    required this.resourceId,
    required this.positionMs,
    required this.updatedAt,
  });

  final String uid;
  final String resourceId;
  final int positionMs;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'resourceId': resourceId,
        'positionMs': positionMs,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PlaybackPosition.fromJson(Map<String, dynamic> json) =>
      PlaybackPosition(
        uid: json['uid'] as String? ?? '',
        resourceId: json['resourceId'] as String? ?? '',
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
