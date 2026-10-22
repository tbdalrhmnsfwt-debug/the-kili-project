/// The weekly report.
///
/// The shipped strings describe what the weekly screen shows:
///   * `تقدمي الأسبوعي` / `تقريري الأسبوعي`
///   * `أسبوعك بالأرقام`
///   * `ملخص أسبوعك: ذاكرت قد إيه، وفين قوي وفين محتاج شغل.`
///   * `وقت المذاكرة مش بتكتبه — بيتقرا من جلسات التركيز اللي عملتها فعلا،
///      ومعاه مقارنة امبارح ومتوسط أسبوعك.`
///   * `متوسط أسبوعك {0} دقيقة`
///   * `سلسلتك نار! 🔥 أسبوع كامل من غير ما تفوت يوم.`
library;

/// One day of the week, with what was studied on it.
class WeekDay {
  const WeekDay({
    required this.date,
    this.focusMinutes = 0,
    this.points = 0,
    this.tasksDone = 0,
    this.tasksTotal = 0,
    this.answersCorrect = 0,
    this.answersWrong = 0,
  });

  /// The day this entry covers.
  final DateTime date;

  /// Minutes of focus time spent.
  final int focusMinutes;

  /// Points earned.
  final int points;

  /// Tasks finished.
  final int tasksDone;

  /// Tasks planned.
  final int tasksTotal;

  /// Questions answered correctly.
  final int answersCorrect;

  /// Questions answered wrongly.
  final int answersWrong;

  /// Whether the day counts toward the streak.
  bool get isActive => focusMinutes > 0 || tasksDone > 0 || points > 0;

  /// The accuracy on this day, in the range 0..1.
  double get accuracy {
    final total = answersCorrect + answersWrong;
    if (total == 0) return 0;
    return answersCorrect / total;
  }
}

/// The subject-by-subject breakdown of a week.
class WeekSubject {
  const WeekSubject({
    required this.subject,
    this.focusMinutes = 0,
    this.points = 0,
  });

  /// The subject (or book) the time went to.
  final String subject;

  /// Minutes spent on it.
  final int focusMinutes;

  /// Points earned on it.
  final int points;

  /// A copy with the given fields replaced.
  WeekSubject copyWith({int? focusMinutes, int? points}) => WeekSubject(
    subject: subject,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    points: points ?? this.points,
  );
}

/// The weekly report.
class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    this.days = const [],
    this.subjects = const [],
    this.streak = 0,
  });

  /// The first day of the week.
  final DateTime weekStart;

  /// The seven days of the week, oldest first.
  final List<WeekDay> days;

  /// How the time was split across subjects.
  final List<WeekSubject> subjects;

  /// How many consecutive days the user has studied.
  final int streak;

  /// Total focus minutes across the week.
  int get totalMinutes {
    var sum = 0;
    for (final d in days) {
      sum += d.focusMinutes;
    }
    return sum;
  }

  /// Total points across the week.
  int get totalPoints {
    var sum = 0;
    for (final d in days) {
      sum += d.points;
    }
    return sum;
  }

  /// Total questions answered across the week.
  int get totalAnswers {
    var sum = 0;
    for (final d in days) {
      sum += d.answersCorrect + d.answersWrong;
    }
    return sum;
  }

  /// The average focus minutes per day.
  double get averageMinutes => days.isEmpty ? 0 : totalMinutes / days.length;

  /// The total questions answered correctly across the week.
  int get totalCorrect {
    var sum = 0;
    for (final d in days) {
      sum += d.answersCorrect;
    }
    return sum;
  }

  /// The accuracy across the week, in the range 0..1.
  double get accuracy {
    if (totalAnswers == 0) return 0;
    return totalCorrect / totalAnswers;
  }

  /// The days with activity, in order.
  List<WeekDay> get activeDays =>
      days.where((d) => d.isActive).toList(growable: false);

  /// How many days in the week had activity.
  int get activeDayCount => activeDays.length;

  /// The subject with the most study time.
  WeekSubject? get topSubject {
    WeekSubject? best;
    for (final s in subjects) {
      if (best == null || s.focusMinutes > best.focusMinutes) best = s;
    }
    return best;
  }

  /// Whether the user studied every day of the week.
  bool get isPerfectWeek => days.isNotEmpty && activeDayCount == days.length;

  /// Builds a report for the week containing [now].
  static WeeklyReport forWeek(DateTime now, {List<WeekDay>? days}) {
    final start = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday % 7),
    );
    return WeeklyReport(weekStart: start, days: days ?? const []);
  }
}
