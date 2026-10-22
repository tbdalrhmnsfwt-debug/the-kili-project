/// Leaderboard, points and garden models.
///
/// The shipped strings describe a weekly leaderboard where focus minutes
/// count toward the score, and a "garden" that grows with each studied day.
library;

import 'dart:convert';

/// A leaderboard row as the app stores it (`zaker.lb.week*` prefs).
class LeaderboardRow {
  const LeaderboardRow({
    required this.userId,
    required this.displayName,
    this.points = 0,
    this.focusSeconds = 0,
    this.solved = 0,
    this.streak = 0,
    this.isMe = false,
  });

  final String userId;
  final String displayName;
  final int points;
  final int focusSeconds;
  final int solved;
  final int streak;
  final bool isMe;

  /// Sort key used for ranking.
  double get sortKey => points + focusSeconds / 1000 + solved;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'points': points,
        'focusSeconds': focusSeconds,
        'solved': solved,
        'streak': streak,
        'isMe': isMe,
      };

  factory LeaderboardRow.fromJson(Map<String, dynamic> json) => LeaderboardRow(
        userId: json['userId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        points: (json['points'] as num?)?.toInt() ?? 0,
        focusSeconds: (json['focusSeconds'] as num?)?.toInt() ?? 0,
        solved: (json['solved'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        isMe: json['isMe'] as bool? ?? false,
      );
}

/// The weekly leaderboard snapshot.
class LeaderboardWeek {
  const LeaderboardWeek({required this.weekStart, required this.rows});

  /// ISO date of the first day of the week.
  final DateTime weekStart;
  final List<LeaderboardRow> rows;

  /// The rows in ranked order (1-based rank implied by index).
  List<LeaderboardRow> get ranked {
    final list = [...rows]..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return list;
  }

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart.toIso8601String(),
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory LeaderboardWeek.fromJson(Map<String, dynamic> json) => LeaderboardWeek(
        weekStart: DateTime.tryParse(json['weekStart'] as String? ?? '') ?? DateTime.now(),
        rows: ((json['rows'] as List?) ?? const [])
            .map((e) => LeaderboardRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// A point in the "garden" that grows with each studied day.
class GardenPlot {
  const GardenPlot({required this.day, required this.points, this.streak = 0});

  /// ISO date.
  final DateTime day;
  final int points;
  final int streak;

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'points': points,
        'streak': streak,
      };

  factory GardenPlot.fromJson(Map<String, dynamic> json) => GardenPlot(
        day: DateTime.tryParse(json['day'] as String? ?? '') ?? DateTime.now(),
        points: (json['points'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
      );
}

/// The garden state: one plot per studied day.
class Garden {
  const Garden({List<GardenPlot>? plots, this.season = 1}) : plots = plots ?? const <GardenPlot>[];

  final List<GardenPlot> plots;
  final int season;

  int get totalPoints => plots.fold<int>(0, (s, p) => s + p.points);

  /// Longest run of consecutive studied days.
  int get longestStreak {
    if (plots.isEmpty) return 0;
    final days = plots.map((p) => _dateKey(p.day)).toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final prev = DateTime.parse(days[i - 1]);
      final cur = DateTime.parse(days[i]);
      if (cur.difference(prev).inDays == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'season': season,
        'plots': plots.map((p) => p.toJson()).toList(),
      };

  factory Garden.fromJson(Map<String, dynamic> json) => Garden(
        season: (json['season'] as num?)?.toInt() ?? 1,
        plots: ((json['plots'] as List?) ?? const [])
            .map((e) => GardenPlot.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// Encodes [Garden] to JSON for round-trip parsing.
String encodeGarden(Garden g) => jsonEncode(g.toJson());

/// Decodes a garden persisted by [encodeGarden].
Garden decodeGarden(String raw) => Garden.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
