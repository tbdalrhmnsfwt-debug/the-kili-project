/// Batch exams, their availability window and one student's attempt.
library;

import 'exam.dart';

/// When the student may see the answer key and score.
enum BatchExamResultsMode { immediately, afterClose }

/// How many times one student may submit an exam.
enum BatchExamAttemptPolicy { single, limited, unlimited }

/// The lifecycle position of an exam at a given instant.
enum BatchExamStatus { draft, scheduled, open, closed }

/// Where a stored attempt sits: still running, submitted, or closed with no
/// answer at all.
enum ExamAttemptStatus { active, submitted, expired }

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
    this.attemptPolicy = BatchExamAttemptPolicy.single,
    this.maxAttempts = 1,
    this.sourceResourceId = '',
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
  final BatchExamAttemptPolicy attemptPolicy;

  /// Used only by [BatchExamAttemptPolicy.limited]; zero otherwise.
  final int maxAttempts;

  /// The PDF this exam was generated from, when it was.
  final String sourceResourceId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => publishedAt != null;

  /// The number of submissions allowed, or zero for unlimited.
  int get attemptCap => switch (attemptPolicy) {
        BatchExamAttemptPolicy.single => 1,
        BatchExamAttemptPolicy.limited => maxAttempts,
        BatchExamAttemptPolicy.unlimited => 0,
      };

  bool get hasValidAttemptPolicy =>
      attemptPolicy != BatchExamAttemptPolicy.limited ||
      (maxAttempts >= 1 && maxAttempts <= 10);

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
  ///
  /// Null when neither a time limit nor a close time bounds the attempt.
  DateTime? deadlineFor(DateTime startedAt) {
    final limit = durationMinutes > 0
        ? startedAt.add(Duration(minutes: durationMinutes))
        : null;
    if (limit == null) return closesAt;
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
    bool clearOpensAt = false,
    DateTime? closesAt,
    bool clearClosesAt = false,
    DateTime? publishedAt,
    BatchExamResultsMode? resultsMode,
    BatchExamAttemptPolicy? attemptPolicy,
    int? maxAttempts,
    String? sourceResourceId,
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
        opensAt: clearOpensAt ? null : opensAt ?? this.opensAt,
        closesAt: clearClosesAt ? null : closesAt ?? this.closesAt,
        publishedAt: publishedAt ?? this.publishedAt,
        resultsMode: resultsMode ?? this.resultsMode,
        attemptPolicy: attemptPolicy ?? this.attemptPolicy,
        maxAttempts: maxAttempts ?? this.maxAttempts,
        sourceResourceId: sourceResourceId ?? this.sourceResourceId,
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
        'attemptPolicy': attemptPolicy.name,
        'maxAttempts': maxAttempts,
        if (sourceResourceId.isNotEmpty) 'sourceResourceId': sourceResourceId,
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
        attemptPolicy: BatchExamAttemptPolicy.values.firstWhere(
          (policy) => policy.name == json['attemptPolicy'],
          orElse: () => BatchExamAttemptPolicy.single,
        ),
        maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 1,
        sourceResourceId: json['sourceResourceId'] as String? ?? '',
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
    this.deadlineAt,
    this.submittedAt,
    this.autoSubmitted = false,
    this.answers = const {},
    this.correctCount = 0,
    this.total = 0,
    this.scorePercent = 0,
    this.status = ExamAttemptStatus.active,
    this.clientKey = '',
  });

  final String id;
  final String examId;
  final String batchId;
  final String uid;
  final DateTime startedAt;

  /// The instant this attempt must be submitted, or null when unbounded.
  final DateTime? deadlineAt;
  final DateTime? submittedAt;
  final bool autoSubmitted;

  /// Question id -> selected option index.
  final Map<String, int> answers;
  final int correctCount;
  final int total;
  final double scorePercent;
  final ExamAttemptStatus status;

  /// The submit call this attempt belongs to. A retry with the same key is a
  /// no-op.
  final String clientKey;

  bool get isSubmitted => submittedAt != null;

  bool get isActive => !isSubmitted;

  bool isExpired(DateTime now) =>
      deadlineAt != null && !now.isBefore(deadlineAt!);

  ExamAttempt copyWith({
    Map<String, int>? answers,
    DateTime? submittedAt,
    bool? autoSubmitted,
    int? correctCount,
    int? total,
    double? scorePercent,
    ExamAttemptStatus? status,
    String? clientKey,
  }) =>
      ExamAttempt(
        id: id,
        examId: examId,
        batchId: batchId,
        uid: uid,
        startedAt: startedAt,
        deadlineAt: deadlineAt,
        submittedAt: submittedAt ?? this.submittedAt,
        autoSubmitted: autoSubmitted ?? this.autoSubmitted,
        answers: answers ?? this.answers,
        correctCount: correctCount ?? this.correctCount,
        total: total ?? this.total,
        scorePercent: scorePercent ?? this.scorePercent,
        status: status ?? this.status,
        clientKey: clientKey ?? this.clientKey,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'batchId': batchId,
        'uid': uid,
        'startedAt': startedAt.toIso8601String(),
        if (deadlineAt != null) 'deadlineAt': deadlineAt!.toIso8601String(),
        if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
        'autoSubmitted': autoSubmitted,
        'answers': answers,
        'correctCount': correctCount,
        'total': total,
        'scorePercent': scorePercent,
        'status': status.name,
        if (clientKey.isNotEmpty) 'clientKey': clientKey,
      };

  factory ExamAttempt.fromJson(Map<String, dynamic> json) {
    final submittedAt = DateTime.tryParse(json['submittedAt'] as String? ?? '');
    final answers = {
      if (json['answers'] is Map)
        for (final entry in (json['answers'] as Map).entries)
          if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
    };
    final autoSubmitted = json['autoSubmitted'] as bool? ?? false;
    final status = ExamAttemptStatus.values.firstWhere(
      (item) => item.name == json['status'],
      orElse: () {
        if (submittedAt == null) return ExamAttemptStatus.active;
        return autoSubmitted && answers.isEmpty
            ? ExamAttemptStatus.expired
            : ExamAttemptStatus.submitted;
      },
    );
    return ExamAttempt(
      id: json['id'] as String? ?? '',
      examId: json['examId'] as String? ?? '',
      batchId: json['batchId'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deadlineAt: DateTime.tryParse(json['deadlineAt'] as String? ?? ''),
      submittedAt: submittedAt,
      autoSubmitted: autoSubmitted,
      answers: answers,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      scorePercent: (json['scorePercent'] as num?)?.toDouble() ?? 0,
      status: status,
      clientKey: json['clientKey'] as String? ?? '',
    );
  }
}
