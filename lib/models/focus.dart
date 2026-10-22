/// Focus-timer and task models.
///
/// The original app registers a `focus_overlay_ui` module under
/// `package:zaker_ai/features/focus/` and a foreground service
/// (`com.zaker.zaker_ai.AiJobService`) plus an overlay service with the
/// subtype `focus_lock_overlay` (see AndroidManifest). The home-screen
/// widgets (`ZToolsWidget`, `ZQuickWidget`, `ZTasksWidget`, `ZImportantWidget`)
/// surface the same task data.
library;

import 'dart:convert';

/// A user task / todo.
class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    this.notes = '',
    this.done = false,
    this.important = false,
    this.dueAt,
    this.subject,
    this.lessonNumber,
    this.createdAt,
  });

  final String id;
  final String title;
  final String notes;
  final bool done;

  /// Marks the task as "المهم" (important) — surfaced by ZImportantWidget.
  final bool important;

  final DateTime? dueAt;
  final String? subject;
  final int? lessonNumber;
  final DateTime? createdAt;

  StudyTask copyWith({
    String? title,
    String? notes,
    bool? done,
    bool? important,
    DateTime? dueAt,
    String? subject,
    int? lessonNumber,
  }) {
    return StudyTask(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      done: done ?? this.done,
      important: important ?? this.important,
      dueAt: dueAt ?? this.dueAt,
      subject: subject ?? this.subject,
      lessonNumber: lessonNumber ?? this.lessonNumber,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (notes.isNotEmpty) 'notes': notes,
    'done': done,
    'important': important,
    if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
    if (subject != null) 'subject': subject,
    if (lessonNumber != null) 'lesson': lessonNumber,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    important: json['important'] as bool? ?? false,
    dueAt: json['dueAt'] == null
        ? null
        : DateTime.tryParse(json['dueAt'] as String),
    subject: json['subject'] as String?,
    lessonNumber: (json['lesson'] as num?)?.toInt(),
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'] as String),
  );
}

/// A task list, grouped as the "قائمة المهام" widget does.
class TaskList {
  TaskList({required this.title, List<StudyTask>? tasks})
    : tasks = tasks ?? <StudyTask>[];

  final String title;
  final List<StudyTask> tasks;

  int get doneCount => tasks.where((t) => t.done).length;
  int get totalCount => tasks.length;
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;
  bool get hasImportant => tasks.any((t) => t.important && !t.done);
}

/// Preset focus durations in minutes.
enum FocusPreset {
  short(25),
  medium(45),
  long(60),
  custom(0);

  const FocusPreset(this.minutes);
  final int minutes;
}

/// The live state of a focus session.
enum FocusPhase { idle, running, paused, finished }

/// A focus (pomodoro-style) session.
class FocusSession {
  FocusSession({
    required this.id,
    required this.preset,
    required this.workMinutes,
    this.breakMinutes = 5,
    this.phase = FocusPhase.idle,
    this.elapsed = Duration.zero,
    this.completedCycles = 0,
    this.startedAt,
    this.taskId,
  });

  final String id;
  final FocusPreset preset;

  /// Length of the work interval.
  final int workMinutes;

  /// Length of the short break between intervals.
  final int breakMinutes;

  FocusPhase phase;
  Duration elapsed;
  int completedCycles;
  DateTime? startedAt;
  String? taskId;

  Duration get totalDuration => Duration(minutes: workMinutes);

  /// Remaining time in the current interval, clamped at zero.
  Duration get remaining {
    final left = totalDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Progress in the range 0..1.
  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0;
    return (elapsed.inMilliseconds / totalDuration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'preset': preset.name,
    'workMinutes': workMinutes,
    'breakMinutes': breakMinutes,
    'phase': phase.name,
    'elapsedMs': elapsed.inMilliseconds,
    'completedCycles': completedCycles,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (taskId != null) 'taskId': taskId,
  };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
    id: json['id'] as String? ?? '',
    preset: FocusPreset.values.firstWhere(
      (p) => p.name == json['preset'],
      orElse: () => FocusPreset.medium,
    ),
    workMinutes: (json['workMinutes'] as num?)?.toInt() ?? 25,
    breakMinutes: (json['breakMinutes'] as num?)?.toInt() ?? 5,
    phase: FocusPhase.values.firstWhere(
      (p) => p.name == json['phase'],
      orElse: () => FocusPhase.idle,
    ),
    elapsed: Duration(milliseconds: (json['elapsedMs'] as num?)?.toInt() ?? 0),
    completedCycles: (json['completedCycles'] as num?)?.toInt() ?? 0,
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.tryParse(json['startedAt'] as String),
    taskId: json['taskId'] as String?,
  );
}

/// A daily focus/streak record.
class FocusDay {
  const FocusDay({required this.date, required this.focusMinutes});

  /// ISO date, `yyyy-MM-dd`.
  final DateTime date;
  final int focusMinutes;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'focusMinutes': focusMinutes,
  };
}

/// A streak of consecutive study days.
class StudyStreak {
  const StudyStreak({
    required this.current,
    required this.best,
    required this.days,
  });

  final int current;
  final int best;

  /// The set of days that count toward the streak, as `yyyy-MM-dd`.
  final Set<String> days;

  bool get isActiveToday => days.contains(_today());

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

/// Encodes a task list for persistence.
String encodeTaskList(TaskList list) => jsonEncode({
  'title': list.title,
  'tasks': list.tasks.map((t) => t.toJson()).toList(),
});

/// Decodes a task list persisted by [encodeTaskList].
TaskList decodeTaskList(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return TaskList(
    title: json['title'] as String? ?? '',
    tasks: ((json['tasks'] as List?) ?? const [])
        .map((e) => StudyTask.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
