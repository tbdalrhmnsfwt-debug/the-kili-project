/// Planner, goal and achievement models.
///
/// The shipped strings show the exact vocabulary this screen uses:
///   * `أهداف اليوم`
///   * `إنجاز اليوم من عشرة محسوب مش مكتوب: الوقت أربع نقاط، أهدافك تلاتة،
///     البنود نقطتين، واليومية نقطة. وكل نقطة بتقولك جات منين.`
///   * `الإنجاز`
///   * `شارة التوثيق الزرقاء`
///   * `مشاركة الدعوة`
library;

import 'dart:convert';

import 'package:flutter/material.dart' show IconData, Icons, TimeOfDay;

/// The badge icons the app can attach to an achievement.
///
/// Achievements are persisted, so they store an icon *key* rather than an
/// [IconData]: `IconData` code points are `@mustBeConst` and therefore cannot
/// be rebuilt from JSON at runtime.
const Map<String, IconData> achievementIcons = <String, IconData>{
  'verified': Icons.verified_rounded,
  'streak7': Icons.workspace_premium_rounded,
  'streak30': Icons.military_tech_rounded,
  'reciter': Icons.auto_stories_rounded,
  'focus': Icons.local_fire_department_rounded,
};

/// A single-subject study plan ("مادة واحدة بالتفصيل" in the strings).
class StudyPlan {
  const StudyPlan({
    required this.id,
    required this.title,
    this.days = const [],
    this.aiGenerated = false,
    this.daysCount = 7,
    this.createdAt,
  });

  final String id;
  final String title;

  /// The days the plan spans.
  final List<StudyDay> days;

  /// True when this plan was produced by the on-device LLM.
  final bool aiGenerated;

  /// Number of days the schedule spans.
  final int daysCount;

  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'aiGenerated': aiGenerated,
    'daysCount': daysCount,
    'days': days
        .map(
          (d) => {
            'date': d.date.toIso8601String().substring(0, 10),
            'slots': d.slots
                .map(
                  (s) => {
                    'start': s.start,
                    'end': s.end,
                    if (s.subject != null) 'subject': s.subject,
                  },
                )
                .toList(),
          },
        )
        .toList(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    aiGenerated: json['aiGenerated'] as bool? ?? false,
    daysCount: (json['daysCount'] as num?)?.toInt() ?? 7,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
    days: ((json['days'] as List?) ?? const [])
        .map((e) => StudyDay.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A single day's schedule.
class StudyDay {
  const StudyDay({required this.date, this.slots = const []});

  /// ISO date, `yyyy-MM-dd`.
  final DateTime date;

  /// Ordered free time blocks the user fills in.
  final List<ScheduleSlot> slots;

  factory StudyDay.fromJson(Map<String, dynamic> json) => StudyDay(
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    slots: ((json['slots'] as List?) ?? const [])
        .map((e) => ScheduleSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// A scheduled slot, e.g. "08:00–09:30 · اللغة العربية".
class ScheduleSlot {
  const ScheduleSlot({required this.start, required this.end, this.subject});

  final TimeOfDay start;
  final TimeOfDay end;
  final String? subject;

  /// Total length of the slot.
  Duration get duration => Duration(
    hours: end.hour - start.hour,
    minutes: end.minute - start.minute,
  );

  /// Renders the slot as `08:00 – 09:30`.
  String get label =>
      '${_two(start.hour)}:${_two(start.minute)} – ${_two(end.hour)}:${_two(end.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    if (subject != null) 'subject': subject,
  };

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) => ScheduleSlot(
    start: _parseTime(json['start'] as String?),
    end: _parseTime(json['end'] as String?),
    subject: json['subject'] as String?,
  );

  static TimeOfDay _parseTime(String? raw) {
    if (raw == null) return const TimeOfDay(hour: 0, minute: 0);
    final parts = raw.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 0, minute: 0);
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }
}

/// An achievable daily goal.
class Goal {
  const Goal({
    required this.id,
    required this.title,
    this.minutes = 60,
    this.completedMinutes = 0,
    this.createdAt,
    this.sourceKey,
  });

  final String id;
  final String title;

  /// Target duration in minutes.
  final int minutes;

  /// Progress accumulated so far.
  final int completedMinutes;

  final DateTime? createdAt;

  /// Optional link back to a focus session or lesson that counts.
  final String? sourceKey;

  /// Progress in the range 0..1.
  double get progress => minutes == 0 ? 0 : completedMinutes / minutes;

  bool get isComplete => completedMinutes >= minutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (minutes != 60) 'minutes': minutes,
    'completedMinutes': completedMinutes,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (sourceKey != null) 'source': sourceKey,
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    minutes: (json['minutes'] as num?)?.toInt() ?? 60,
    completedMinutes: (json['completedMinutes'] as num?)?.toInt() ?? 0,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
    sourceKey: json['source'] as String?,
  );
}

/// A tracked achievement (`{0} فتحت إنجاز: {1}` in the strings).
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    this.unlocked = false,
    this.unlocks = 0,
    this.iconKey,
    this.description = '',
  });

  final String id;

  /// Arabic display name, e.g. `شارة التوثيق الزرقاء`.
  final String name;

  final bool unlocked;

  /// How many times the achievement must be earned to unlock it.
  final int unlocks;

  /// Key into [achievementIcons], e.g. `verified`.
  final String? iconKey;
  final String description;

  /// The badge icon, when this achievement has one.
  IconData? get icon => iconKey == null ? null : achievementIcons[iconKey];

  /// How close the user is to unlocking, in the range 0..1.
  double get progress => unlocks == 0 ? 0 : (unlocked ? 1 : 0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unlocked': unlocked,
    'unlocks': unlocks,
    if (iconKey != null) 'icon': iconKey,
    if (description.isNotEmpty) 'description': description,
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    unlocked: json['unlocked'] as bool? ?? false,
    unlocks: (json['unlocks'] as num?)?.toInt() ?? 1,
    iconKey: json['icon'] as String?,
    description: json['description'] as String? ?? '',
  );
}

/// The status of a referral.
enum ReferralStatus { pending, approved, rejected }

/// A referral record (`كود دعوة (اختياري)` / `دعوة من {0} ✅`).
class Referral {
  const Referral({
    required this.code,
    required this.inviterId,
    this.status = ReferralStatus.pending,
    this.friendCount = 0,
  });

  final String code;

  /// The user who shared the code.
  final String inviterId;
  final ReferralStatus status;

  /// How many friends have signed up with the code.
  final int friendCount;

  /// The blue verified badge needs ten friends, per the shipped string
  /// `دعوة 10 أصدقاء`.
  static const int verifiedBadgeThreshold = 10;

  /// Whether the blue verified badge has been earned.
  bool get isVerified => friendCount >= verifiedBadgeThreshold;

  Map<String, dynamic> toJson() => {
    'code': code,
    'inviterId': inviterId,
    'status': status.name,
    'friendCount': friendCount,
  };

  factory Referral.fromJson(Map<String, dynamic> json) => Referral(
    code: json['code'] as String? ?? '',
    inviterId: json['inviterId'] as String? ?? '',
    status: ReferralStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => ReferralStatus.pending,
    ),
    friendCount: (json['friendCount'] as num?)?.toInt() ?? 0,
  );
}

/// A leaderboard row.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.score = 0,
    this.focusSeconds = 0,
    this.completedTasks = 0,
    this.rank = 0,
  });

  final String userId;
  final String displayName;
  final double score;

  /// Focus-session seconds, which count toward the leaderboard per the
  /// shipped note `الدقايق دي من جلسات التركيز، وبتحسبلك في المتصدرين`.
  final int focusSeconds;
  final int completedTasks;

  /// The leaderboard position, 1-based. Zero means "not ranked yet".
  final int rank;

  /// Sort key used for ranking.
  double get sortKey => score + focusSeconds / 1000 + completedTasks;
}

/// Encodes a list of goals for persistence.
String encodeGoals(List<Goal> goals) =>
    jsonEncode({'goals': goals.map((g) => g.toJson()).toList()});

/// Decodes goals persisted by [encodeGoals].
List<Goal> decodeGoals(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ((json['goals'] as List?) ?? const [])
      .map((e) => Goal.fromJson(e as Map<String, dynamic>))
      .toList();
}
