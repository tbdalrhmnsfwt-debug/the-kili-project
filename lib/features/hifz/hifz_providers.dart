/// Persists the memorization state through the app's [LocalStore].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_store.dart';
import '../../providers/app_providers.dart';
import 'hifz_models.dart';

/// Store key for parts, streak and reminder settings.
const String kHifzStoreKey = 'hifz_state';

final hifzProvider = StateNotifierProvider<HifzController, HifzState>((ref) {
  return HifzController(ref.watch(localStoreProvider));
});

class HifzController extends StateNotifier<HifzState> {
  HifzController(this._store)
    : super(HifzState.fromJson(_store.getJson(kHifzStoreKey)));

  final LocalStore _store;

  void _commit(HifzState next) {
    if (identical(next, state)) return;
    state = next;
    _store.setJson(kHifzStoreKey, next.toJson());
  }

  /// Adds the part, or replaces the part with the same id.
  void savePart(HifzPart part) => _commit(state.upsertPart(part));

  void removePart(String id) => _commit(state.removePart(id));

  /// Applies a finished session and updates the daily streak.
  void recordSession(
    String partId,
    HifzSessionResult result, {
    DateTime? now,
    bool firstSession = false,
  }) {
    _commit(
      state.recordSession(partId, result, now: now, firstSession: firstSession),
    );
  }

  void setReminders({required bool enabled, int? hour, int? minute}) {
    _commit(
      state.copyWith(
        remindersEnabled: enabled,
        reminderHour: hour,
        reminderMinute: minute,
      ),
    );
  }
}

/// A stable id for a new memorized range.
String newHifzPartId(int surahNumber, int startAyah, int endAyah, DateTime at) {
  return 'hifz_${surahNumber}_${startAyah}_$endAyah'
      '_${at.millisecondsSinceEpoch}';
}
