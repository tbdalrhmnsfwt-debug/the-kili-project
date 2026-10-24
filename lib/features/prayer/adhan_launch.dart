/// Routes a notification payload to the screen it belongs to.
///
/// Study reminders and prayer reminders keep their simple string payloads,
/// while an adhan carries a JSON object with the prayer, time, city, voice and
/// notification id, so the full-screen player can be rebuilt after the app
/// process was killed.
library;

import 'dart:convert';

import '../../core/router.dart';

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
