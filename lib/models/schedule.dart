/// The daily study schedule and recurring tasks.
///
/// Shipped strings (`g_tasks`) describe a `قائمة المهام` with per-day tasks
/// and per-day times that drive the reminders:
/// `تذكير المهام`, `أيام التكرار`, `معاد التذكير`.
library;

import 'dart:convert';

/// A single task entry, one of several that makes up [TaskList].
class ScheduleEntry {
  const ScheduleEntry({
    required this.id,
    required this.title,
    this.notes = '',
    this.done = false,
    this.important = false,
    this.dueAt,
    this.dayOfWeek,
    this.createdAt,
  });

  final String id;
  final String title;
  final String notes;
  final bool done;

  /// Surfaced by ZImportantWidget as «المهم».
  final bool important;

  /// ISO date or null for unrestricted.
  final DateTime? dueAt;

  /// A 0..6 day of week (0 = Sunday). null means "any day".
  final int? dayOfWeek;

  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (notes.isNotEmpty) 'notes': notes,
        'done': done,
        'important': important,
        if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
        if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        important: json['important'] as bool? ?? false,
        dueAt: json['dueAt'] == null ? null : DateTime.tryParse(json['dueAt'] as String),
        dayOfWeek: (json['dayOfWeek'] as num?)?.toInt(),
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      );
}

/// The daily task list, grouped by subject and day.
class TaskSchedule {
  TaskSchedule({required this.title, List<ScheduleEntry>? entries})
    : entries = entries ?? <ScheduleEntry>[];

  final String title;
  final List<ScheduleEntry> entries;

  int get total => entries.length;
  int get doneCount => entries.where((e) => e.done).length;
  double get progress => total == 0 ? 0 : doneCount / total;

  /// Today's unscheduled + today-specific entries.
  List<ScheduleEntry> forDay([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return entries
        .where(
          (e) =>
              e.done ||
              e.dueAt == null ||
              (e.dueAt!.year == reference.year &&
                  e.dueAt!.month == reference.month &&
                  e.dueAt!.day == reference.day),
        )
        .toList();
  }

  /// Entries pending review for any day.
  List<ScheduleEntry> pending([DateTime? now]) => forDay(now);
}

String encodeTaskSchedule(TaskSchedule s) =>
    jsonEncode({'entries': s.entries.map((e) => e.toJson()).toList()});

/// Decodes a schedule persisted by [encodeTaskSchedule].
TaskSchedule decodeTaskSchedule(String raw) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return TaskSchedule(
    title: json['title'] as String? ?? '',
    entries: ((json['entries'] as List?) ?? const [])
        .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
