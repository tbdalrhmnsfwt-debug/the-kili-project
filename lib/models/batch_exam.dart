/// Batch exams, their availability window and one student's attempt.
library;

import 'exam.dart';

/// When the student may see the answer key and score.
enum BatchExamResultsMode { immediately, afterClose }

/// The lifecycle position of an exam at a given instant.
enum BatchExamStatus { draft, scheduled, open, closed }

/// A multiple-choice exam published inside one batch subject.
///
/// Availability is absolute: an absent window bound means "unbounded on that
/// side", never a guessed date. [afterClose] results require [closesAt],
/// because otherwise there is no close instant to wait for.
class BatchExam {
  const BatchExam({
    required this.id,
    required this.batchId,
    required this.subjectId,
    required this.title,
    required this.durationMinutes,
    required this.questions,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.opensAt,
    this.closesAt,
    this.publishedAt,
    this.resultsMode = BatchExamResultsMode.afterClose,
  });

  final String id;
  final String batchId;
  final String subjectId;
  final String title;
  final String description;

  /// Time limit from press-start, in minutes. Zero means no time limit.
  final int durationMinutes;
  final List<ExamQuestion> questions;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final DateTime? publishedAt;
  final BatchExamResultsMode resultsMode;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => publishedAt != null;

  bool get hasValidWindow {
    if (!isPublished) return true;
    if (opensAt != null && closesAt != null && !opensAt!.isBefore(closesAt!)) {
      return false;
    }
    if (resultsMode == BatchExamResultsMode.afterClose && closesAt == null) {
      return false;
    }
    return true;
  }

  bool isOpenAt(DateTime now) =>
      isPublished &&
      hasValidWindow &&
      (opensAt == null || !now.isBefore(opensAt!)) &&
      (closesAt == null || now.isBefore(closesAt!));

  BatchExamStatus statusAt(DateTime now) {
    if (!isPublished) return BatchExamStatus.draft;
    if (!hasValidWindow) return BatchExamStatus.draft;
    if (opensAt != null && now.isBefore(opensAt!)) {
      return BatchExamStatus.scheduled;
    }
    if (closesAt != null && !now.isBefore(closesAt!)) {
      return BatchExamStatus.closed;
    }
    return BatchExamStatus.open;
  }

  /// The instant this attempt must be submitted, capped by the close time.
  DateTime deadlineFor(DateTime startedAt) {
    final limit = durationMinutes > 0
        ? startedAt.add(Duration(minutes: durationMinutes))
        : null;
    if (limit == null) return closesAt ?? startedAt;
    if (closesAt != null && closesAt!.isBefore(limit)) return closesAt!;
    return limit;
  }

  bool resultsVisibleAt(DateTime now) => switch (resultsMode) {
        BatchExamResultsMode.immediately => true,
        BatchExamResultsMode.afterClose =>
          closesAt != null && !now.isBefore(closesAt!),
      };

  BatchExam copyWith({
    String? title,
    String? description,
    int? durationMinutes,
    List<ExamQuestion>? questions,
    DateTime? opensAt,
    DateTime? closesAt,
    DateTime? publishedAt,
    BatchExamResultsMode? resultsMode,
    DateTime? updatedAt,
  }) =>
      BatchExam(
        id: id,
        batchId: batchId,
        subjectId: subjectId,
        title: title ?? this.title,
        description: description ?? this.description,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        questions: questions ?? this.questions,
        opensAt: opensAt ?? this.opensAt,
        closesAt: closesAt ?? this.closesAt,
        publishedAt: publishedAt ?? this.publishedAt,
        resultsMode: resultsMode ?? this.resultsMode,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchId': batchId,
        'subjectId': subjectId,
        'title': title,
        if (description.isNotEmpty) 'description': description,
        'durationMinutes': durationMinutes,
        'questions': [for (final question in questions) question.toJson()],
        if (opensAt != null) 'opensAt': opensAt!.toIso8601String(),
        if (closesAt != null) 'closesAt': closesAt!.toIso8601String(),
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        'resultsMode': resultsMode.name,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BatchExam.fromJson(Map<String, dynamic> json) => BatchExam(
        id: json['id'] as String? ?? '',
        batchId: json['batchId'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        questions: [
          for (final raw in (json['questions'] as List? ?? const []))
            if (raw is Map)
              ExamQuestion.fromJson(Map<String, dynamic>.from(raw)),
        ],
        opensAt: DateTime.tryParse(json['opensAt'] as String? ?? ''),
        closesAt: DateTime.tryParse(json['closesAt'] as String? ?? ''),
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        resultsMode: json['resultsMode'] == 'immediately'
            ? BatchExamResultsMode.immediately
            : BatchExamResultsMode.afterClose,
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// A stored attempt. Submission is idempotent: once [submittedAt] is set the
/// answers and score never change.
class ExamAttempt {
  const ExamAttempt({
    required this.id,
    required this.examId,
    required this.batchId,
    required this.uid,
    required this.startedAt,
    required this.deadlineAt,
    this.submittedAt,
    this.autoSubmitted = false,
    this.answers = const {},
    this.correctCount = 0,
    this.total = 0,
    this.scorePercent = 0,
  });

  final String id;
  final String examId;
  final String batchId;
  final String uid;
  final DateTime startedAt;
  final DateTime deadlineAt;
  final DateTime? submittedAt;
  final bool autoSubmitted;

  /// Question id -> selected option index.
  final Map<String, int> answers;
  final int correctCount;
  final int total;
  final double scorePercent;

  bool get isSubmitted => submittedAt != null;

  bool isExpired(DateTime now) => !now.isBefore(deadlineAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'batchId': batchId,
        'uid': uid,
        'startedAt': startedAt.toIso8601String(),
        'deadlineAt': deadlineAt.toIso8601String(),
        if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
        'autoSubmitted': autoSubmitted,
        'answers': answers,
        'correctCount': correctCount,
        'total': total,
        'scorePercent': scorePercent,
      };

  factory ExamAttempt.fromJson(Map<String, dynamic> json) => ExamAttempt(
        id: json['id'] as String? ?? '',
        examId: json['examId'] as String? ?? '',
        batchId: json['batchId'] as String? ?? '',
        uid: json['uid'] as String? ?? '',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        deadlineAt: DateTime.tryParse(json['deadlineAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
        autoSubmitted: json['autoSubmitted'] as bool? ?? false,
        answers: {
          if (json['answers'] is Map)
            for (final entry in (json['answers'] as Map).entries)
              if (entry.value is num)
                '${entry.key}': (entry.value as num).toInt(),
        },
        correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        scorePercent: (json['scorePercent'] as num?)?.toDouble() ?? 0,
      );
}
