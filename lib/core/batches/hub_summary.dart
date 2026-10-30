/// The counts and latest items the hub shows for each section.
///
/// Every collection is read independently: a corrupt `updates.json` leaves the
/// exam card and the rest of the hub usable, and only that card says it could
/// not be read.
library;

import '../../models/batch_chat.dart';
import '../../models/batch_exam.dart';
import '../../models/batch_schedule.dart';
import '../../models/batch_update.dart';
import 'batch_store.dart';

class BatchHubData {
  const BatchHubData({
    required this.updates,
    required this.updatesAvailable,
    required this.exams,
    required this.examsAvailable,
    required this.schedules,
    required this.schedulesAvailable,
    required this.lastMessage,
    required this.chatAvailable,
  });

  final List<BatchUpdate> updates;
  final bool updatesAvailable;
  final List<BatchExam> exams;
  final bool examsAvailable;
  final List<TimetableDraft> schedules;
  final bool schedulesAvailable;
  final ChatMessage? lastMessage;
  final bool chatAvailable;

  static Future<BatchHubData> load({required BatchStore store}) async {
    final updates = await store.updates.load();
    final exams = await store.exams.load();
    final schedules = await store.schedules.load();
    final chat = await store.chat.load();
    return BatchHubData(
      updates: updates.value ?? const [],
      updatesAvailable: updates.isUsable || updates.isMissing,
      exams: exams.value ?? const [],
      examsAvailable: exams.isUsable || exams.isMissing,
      schedules: schedules.value ?? const [],
      schedulesAvailable: schedules.isUsable || schedules.isMissing,
      lastMessage: _lastMessage(chat.value),
      chatAvailable: chat.isUsable || chat.isMissing,
    );
  }

  int unreadUpdates(String uid) =>
      updates.where((item) => !item.isReadBy(uid)).length;

  BatchUpdate? get latestUpdate {
    BatchUpdate? latest;
    for (final item in updates) {
      if (latest == null || item.createdAt.isAfter(latest.createdAt)) {
        latest = item;
      }
    }
    return latest;
  }

  /// Published timetable entries; drafts are not counted as a schedule.
  int get scheduleEntryCount => schedules
      .where((draft) => draft.status == TimetableDraftStatus.published)
      .fold(0, (sum, draft) => sum + draft.entries.length);

  BatchExam? get latestExam {
    BatchExam? latest;
    for (final item in exams) {
      if (latest == null || item.updatedAt.isAfter(latest.updatedAt)) {
        latest = item;
      }
    }
    return latest;
  }

  static ChatMessage? _lastMessage(List<ChatMessage>? messages) {
    if (messages == null || messages.isEmpty) return null;
    var latest = messages.first;
    for (final item in messages) {
      if (item.createdAt.isAfter(latest.createdAt)) latest = item;
    }
    return latest;
  }
}
