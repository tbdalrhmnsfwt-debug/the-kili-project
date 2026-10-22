/// The daily challenge and the live ("direct") challenge arena.
///
/// Shipped strings describe two distinct things:
///   * `تحدي يومي قصير يخليك مذاكر كل يوم.` — the daily challenge, which
///     awards points and grows a plant in the garden.
///   * `تحدي مباشر` — a live head-to-head challenge shared with a friend by
///     code, with a `غرفة التحدي` (challenge room).
library;

import 'dart:convert';

/// How a challenge is played.
enum ChallengeKind {
  /// The daily challenge: a short mixed set of questions.
  daily,

  /// A timed speed run.
  speed,

  /// A head-to-head challenge against another user.
  direct,
}

/// The lifecycle of a challenge.
enum ChallengeStatus {
  /// Nobody has joined yet.
  open,

  /// Somebody is playing right now.
  live,

  /// Finished and scored.
  finished,

  /// Closed by its owner.
  closed,
}

/// A challenge the user can play.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    this.kind = ChallengeKind.daily,
    this.status = ChallengeStatus.open,
    this.code,
    this.questionCount = 10,
    this.timeLimitSeconds = 60,
    this.points = 0,
    this.hostName = '',
    this.joinedBy = '',
    this.createdAt,
    this.finishedAt,
  });

  final String id;
  final String title;
  final ChallengeKind kind;
  final ChallengeStatus status;

  /// The short code a friend types to join a direct challenge.
  final String? code;

  final int questionCount;
  final int timeLimitSeconds;

  /// The points the challenge is worth.
  final int points;

  /// Who opened the challenge.
  final String hostName;

  /// Who joined it.
  final String joinedBy;

  final DateTime? createdAt;
  final DateTime? finishedAt;

  /// Whether the user can still join this challenge.
  bool get joinable => status == ChallengeStatus.open;

  /// Whether the challenge has ended.
  bool get over => status == ChallengeStatus.finished || status == ChallengeStatus.closed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'status': status.name,
        if (code != null) 'code': code,
        'questionCount': questionCount,
        'timeLimitSeconds': timeLimitSeconds,
        'points': points,
        'hostName': hostName,
        'joinedBy': joinedBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      };

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        kind: _kind(json['kind'] as String?),
        status: _status(json['status'] as String?),
        code: json['code'] as String?,
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 10,
        timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt() ?? 60,
        points: (json['points'] as num?)?.toInt() ?? 0,
        hostName: json['hostName'] as String? ?? '',
        joinedBy: json['joinedBy'] as String? ?? '',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        finishedAt: json['finishedAt'] == null
            ? null
            : DateTime.tryParse(json['finishedAt'] as String),
      );

  static ChallengeKind _kind(String? name) {
    for (final k in ChallengeKind.values) {
      if (k.name == name) return k;
    }
    return ChallengeKind.daily;
  }

  static ChallengeStatus _status(String? name) {
    for (final s in ChallengeStatus.values) {
      if (s.name == name) return s;
    }
    return ChallengeStatus.open;
  }
}

/// A question inside a challenge.
class ChallengeQuestion {
  const ChallengeQuestion({
    required this.id,
    required this.prompt,
    this.options = const [],
    this.correctIndex,
    this.timeLimitSeconds = 30,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int? correctIndex;
  final int timeLimitSeconds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'prompt': prompt,
        if (options.isNotEmpty) 'options': options,
        if (correctIndex != null) 'correctIndex': correctIndex,
        'timeLimitSeconds': timeLimitSeconds,
      };

  factory ChallengeQuestion.fromJson(Map<String, dynamic> json) =>
      ChallengeQuestion(
        id: json['id'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        options: (json['options'] as List?)?.cast<String>() ?? const [],
        correctIndex: (json['correctIndex'] as num?)?.toInt(),
        timeLimitSeconds: (json['timeLimitSeconds'] as num?)?.toInt() ?? 30,
      );
}

/// The result of a finished challenge.
class ChallengeResult {
  const ChallengeResult({
    required this.challengeId,
    required this.score,
    required this.total,
    required this.correct,
    this.wrongQuestionIds = const [],
    this.finishedAt,
  });

  final String challengeId;
  final int score;

  /// The number of questions asked.
  final int total;

  /// How many were answered correctly.
  final int correct;

  /// The questions the user got wrong.
  final List<String> wrongQuestionIds;

  final DateTime? finishedAt;

  /// The score as a percentage.
  int get percent => total == 0 ? 0 : (correct * 100 ~/ total);

  Map<String, dynamic> toJson() => {
        'challengeId': challengeId,
        'score': score,
        'total': total,
        'correct': correct,
        'wrongQuestionIds': wrongQuestionIds,
        if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      };

  factory ChallengeResult.fromJson(Map<String, dynamic> json) => ChallengeResult(
        challengeId: json['challengeId'] as String? ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        wrongQuestionIds: (json['wrongQuestionIds'] as List?)?.cast<String>() ?? const [],
        finishedAt: json['finishedAt'] == null
            ? null
            : DateTime.tryParse(json['finishedAt'] as String),
      );
}

/// Encodes challenges for persistence.
String encodeChallenges(List<Challenge> challenges) => jsonEncode({
      'challenges': challenges.map((c) => c.toJson()).toList(),
    });

/// Decodes challenges persisted by [encodeChallenges].
List<Challenge> decodeChallenges(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ((json['challenges'] as List?) ?? const [])
      .map((e) => Challenge.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// Encodes challenge results for persistence.
String encodeChallengeResults(List<ChallengeResult> results) => jsonEncode({
      'results': results.map((r) => r.toJson()).toList(),
    });

/// Decodes challenge results persisted by [encodeChallengeResults].
List<ChallengeResult> decodeChallengeResults(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ((json['results'] as List?) ?? const [])
      .map((e) => ChallengeResult.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}
