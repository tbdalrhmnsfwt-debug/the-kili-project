/// Routes a notification payload to the screen it belongs to.
///
/// Study reminders and prayer reminders keep their simple string payloads,
/// while an adhan carries a JSON object with the prayer, time, city, voice and
/// notification id, so the full-screen player can be rebuilt after the app
/// process was killed.
library;

import 'dart:convert';

import '../../core/router.dart';

final RegExp _batchIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// The timetable location a batch reminder opens, or null for any other
/// payload.
///
/// A batch reminder carries only ids. The class title, room and the private
/// photo path never appear in the notification, so nothing here can leak them.
String? batchScheduleLocation(Map<String, dynamic> data) {
  if (data['type'] != 'batch_schedule') return null;
  final batchId = data['batchId'];
  if (batchId is! String || !_batchIdPattern.hasMatch(batchId)) return null;
  return ZakerRoutes.batchSchedules(batchId);
}

void handleNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;
  if (payload == 'tasks') {
    appRouter.go(ZakerRoutes.tasks);
    return;
  }
  if (payload == 'prayer') {
    appRouter.go(ZakerRoutes.prayer);
    return;
  }

  final data = _decode(payload);
  if (data == null) return;

  final scheduleLocation = batchScheduleLocation(data);
  if (scheduleLocation != null) {
    appRouter.go(scheduleLocation);
    return;
  }

  switch (data['type']) {
    case 'salat':
      final phrase = data['phrase'];
      appRouter.go(
        Uri(
          path: ZakerRoutes.azkarSalat,
          queryParameters: phrase is String && phrase.isNotEmpty
              ? <String, String>{'phrase': phrase}
              : null,
        ).toString(),
      );
      return;
    case 'azkar':
      final evening = data['period'] == 'evening';
      appRouter.go(
        evening ? ZakerRoutes.azkarEvening : ZakerRoutes.azkarMorning,
      );
      return;
    case 'kahf':
      appRouter.go(ZakerRoutes.azkarKahf);
      return;
    case 'hifz':
      appRouter.go(ZakerRoutes.hifz);
      return;
  }

  if (data['type'] != 'adhan') return;

  final query = <String, String>{};
  void add(String key) {
    final value = data[key];
    if (value is String && value.isNotEmpty) query[key] = value;
  }

  add('prayer');
  add('time');
  add('city');
  add('voice');
  final id = data['id'];
  if (id is int) query['id'] = '$id';

  appRouter.push(
    Uri(path: ZakerRoutes.adhanPlayback, queryParameters: query).toString(),
  );
}

Map<String, dynamic>? _decode(String payload) {
  try {
    final value = jsonDecode(payload);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}
