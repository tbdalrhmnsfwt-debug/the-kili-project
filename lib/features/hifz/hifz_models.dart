/// Pure data for the hifz (memorization) mode: parts, sessions and the
/// spaced-repetition ladder. No Flutter imports, so the logic is unit-testable.
library;

/// How much of an ayah the session hides before the student recites.
enum HifzHideMode { none, lastWords, alternateWords, wholeAyah, randomWords }

/// The review ladder in days: review after 1, 3, 7, then every 14 days.
const List<int> kHifzReviewDays = [1, 3, 7, 14];

/// The review date [stage] steps into, anchored to the start of [from]'s day.
DateTime hifzNextReview({required int stage, required DateTime from}) {
  final step = kHifzReviewDays[stage.clamp(0, kHifzReviewDays.length - 1)];
  return DateTime(from.year, from.month, from.day).add(Duration(days: step));
}

/// One ayah's self-check verdict inside a session.
class HifzAyahMark {
  const HifzAyahMark({required this.ayahNumber, required this.correct});

  final int ayahNumber;
  final bool correct;
}

/// The marks a finished session produced.
class HifzSessionResult {
  const HifzSessionResult({required this.marks});

  final List<HifzAyahMark> marks;

  int get total => marks.length;

  int get correct => marks.where((mark) => mark.correct).length;

  int get needsReview => total - correct;

  double get score => total == 0 ? 0 : correct / total;

  bool get perfect => needsReview == 0;

  /// The longest run of consecutive correct marks in the order recited.
  int get bestStreak {
    var best = 0;
    var run = 0;
    for (final mark in marks) {
      run = mark.correct ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }
}

/// A memorized range of ayahs in one surah, plus its review schedule.
class HifzPart {
  const HifzPart({
    required this.id,
    required this.surahNumber,
    required this.surahName,
    required this.startAyah,
    required this.endAyah,
    required this.hideMode,
    required this.createdAt,
    this.stage = 0,
    this.bestScore = 0,
    this.reviewCount = 0,
    this.nextReviewAt,
  });

  final String id;
  final int surahNumber;
  final String surahName;
  final int startAyah;
  final int endAyah;
  final HifzHideMode hideMode;
  final DateTime createdAt;

  /// Index into [kHifzReviewDays].
  final int stage;

  /// Best session score seen for this part, 0..1.
  final double bestScore;

  /// How many sessions were recorded.
  final int reviewCount;

  /// When the next review is due; null until the first review is scheduled.
  final DateTime? nextReviewAt;

  int get ayahCount => endAyah - startAyah + 1;

  bool isDue(DateTime now) {
    final due = nextReviewAt;
    return due != null && !due.isAfter(now);
  }

  HifzPart copyWith({
    HifzHideMode? hideMode,
    int? stage,
    double? bestScore,
    int? reviewCount,
    DateTime? nextReviewAt,
  }) {
    return HifzPart(
      id: id,
      surahNumber: surahNumber,
      surahName: surahName,
      startAyah: startAyah,
      endAyah: endAyah,
      hideMode: hideMode ?? this.hideMode,
      createdAt: createdAt,
      stage: stage ?? this.stage,
      bestScore: bestScore ?? this.bestScore,
      reviewCount: reviewCount ?? this.reviewCount,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'surah': surahNumber,
    'surahName': surahName,
    'start': startAyah,
    'end': endAyah,
    'mode': hideMode.name,
    'createdAt': createdAt.toIso8601String(),
    'stage': stage,
    'bestScore': bestScore,
    'reviews': reviewCount,
    'nextReviewAt': nextReviewAt?.toIso8601String(),
  };

  factory HifzPart.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse('${json['createdAt'] ?? ''}');
    final next = DateTime.tryParse('${json['nextReviewAt'] ?? ''}');
    return HifzPart(
      id: '${json['id'] ?? ''}',
      surahNumber: (json['surah'] as num?)?.toInt() ?? 1,
      surahName: '${json['surahName'] ?? ''}',
      startAyah: (json['start'] as num?)?.toInt() ?? 1,
      endAyah: (json['end'] as num?)?.toInt() ?? 1,
      hideMode: _hideModeFromName('${json['mode'] ?? ''}'),
      createdAt: created ?? DateTime.now(),
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      bestScore: (json['bestScore'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviews'] as num?)?.toInt() ?? 0,
      nextReviewAt: next,
    );
  }
}

HifzHideMode _hideModeFromName(String name) {
  for (final mode in HifzHideMode.values) {
    if (mode.name == name) return mode;
  }
  return HifzHideMode.lastWords;
}

/// Applies a finished session to [part].
///
/// A perfect recitation moves one step down the ladder; any mark that needs
/// review drops the part back to the first step. The best score is kept.
HifzPart hifzApplySession(
  HifzPart part,
  HifzSessionResult result, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final stage = result.perfect
      ? (part.stage + 1).clamp(0, kHifzReviewDays.length - 1)
      : 0;
  final best = result.score > part.bestScore ? result.score : part.bestScore;
  return part.copyWith(
    stage: stage,
    bestScore: best,
    reviewCount: part.reviewCount + 1,
    nextReviewAt: hifzNextReview(stage: stage, from: reference),
  );
}

/// The persisted hifz state: memorized parts, reminder settings and streak.
class HifzState {
  const HifzState({
    this.parts = const [],
    this.remindersEnabled = false,
    this.reminderHour = defaultReminderHour,
    this.reminderMinute = defaultReminderMinute,
    this.streakDays = 0,
    this.lastSessionDay = '',
  });

  static const int defaultReminderHour = 20;
  static const int defaultReminderMinute = 0;

  final List<HifzPart> parts;
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final int streakDays;

  /// `yyyy-MM-dd` of the last recorded session, or empty.
  final String lastSessionDay;

  int get memorizedAyahs =>
      parts.fold<int>(0, (sum, part) => sum + part.ayahCount);

  bool get isEmpty => parts.isEmpty;

  HifzPart? nextDue(DateTime now) {
    HifzPart? best;
    for (final part in parts) {
      if (!part.isDue(now)) continue;
      if (best == null ||
          part.nextReviewAt!.isBefore(best.nextReviewAt ?? part.nextReviewAt!)) {
        best = part;
      }
    }
    return best;
  }

  int dueCount(DateTime now) =>
      parts.where((part) => part.isDue(now)).length;

  HifzState upsertPart(HifzPart part) {
    final next = [
      for (final existing in parts)
        if (existing.id == part.id) part else existing,
    ];
    if (!next.any((existing) => existing.id == part.id)) next.add(part);
    return copyWith(parts: next);
  }

  HifzState removePart(String id) {
    return copyWith(
      parts: parts.where((part) => part.id != id).toList(growable: false),
    );
  }

  HifzState recordSession(
    String partId,
    HifzSessionResult result, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final index = parts.indexWhere((part) => part.id == partId);
    var nextParts = parts;
    if (index >= 0) {
      nextParts = [...parts];
      nextParts[index] = hifzApplySession(parts[index], result, now: reference);
    }
    return copyWith(
      parts: List.unmodifiable(nextParts),
      streakDays: _streakFor(reference),
      lastSessionDay: _dayKey(reference),
    );
  }

  HifzState copyWith({
    List<HifzPart>? parts,
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? streakDays,
    String? lastSessionDay,
  }) {
    return HifzState(
      parts: parts ?? this.parts,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      streakDays: streakDays ?? this.streakDays,
      lastSessionDay: lastSessionDay ?? this.lastSessionDay,
    );
  }

  /// Streak in consecutive calendar days with a recorded session.
  int _streakFor(DateTime now) {
    final today = _dayKey(now);
    if (lastSessionDay == today) return streakDays;
    final yesterday = _dayKey(
      DateTime(now.year, now.month, now.day - 1),
    );
    return lastSessionDay == yesterday ? streakDays + 1 : 1;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'parts': [for (final part in parts) part.toJson()],
    'reminders': remindersEnabled,
    'hour': reminderHour,
    'minute': reminderMinute,
    'streak': streakDays,
    'lastDay': lastSessionDay,
  };

  factory HifzState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HifzState();
    final rawParts = json['parts'];
    final parts = <HifzPart>[];
    if (rawParts is List) {
      for (final raw in rawParts) {
        if (raw is Map<String, dynamic>) {
          final part = HifzPart.fromJson(raw);
          if (part.id.isNotEmpty) parts.add(part);
        }
      }
    }
    return HifzState(
      parts: List.unmodifiable(parts),
      remindersEnabled: json['reminders'] == true,
      reminderHour: (json['hour'] as num?)?.toInt() ?? defaultReminderHour,
      reminderMinute: (json['minute'] as num?)?.toInt() ?? defaultReminderMinute,
      streakDays: (json['streak'] as num?)?.toInt() ?? 0,
      lastSessionDay: '${json['lastDay'] ?? ''}',
    );
  }
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
