/// Riverpod state for adhan notifications.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/adhan_voices.dart';
import '../../core/local_store.dart';
import '../../providers/app_providers.dart';
import 'adhan_models.dart';
import 'prayer_models.dart';

const String _adhanSettingsKey = 'adhan_settings';

/// The user's notification choices, persisted in [LocalStore].
final adhanSettingsProvider =
    StateNotifierProvider<AdhanSettingsController, AdhanSettings>((ref) {
      return AdhanSettingsController(ref.watch(localStoreProvider));
    });

class AdhanSettingsController extends StateNotifier<AdhanSettings> {
  AdhanSettingsController(LocalStore store)
    : _store = store,
      super(_read(store));

  final LocalStore _store;

  static AdhanSettings _read(LocalStore store) {
    return AdhanSettings.fromJson(store.getJson(_adhanSettingsKey));
  }

  void _save() {
    _store.setJson(_adhanSettingsKey, state.toJson());
  }

  void setEnabled(bool value) {
    if (state.enabled == value) return;
    state = state.copyWith(enabled: value);
    _save();
  }

  void setPrayerEnabled(PrayerName prayer, bool value) {
    if (state.isPrayerEnabled(prayer) == value) return;
    state = state.copyWith(
      enabledPrayers: {...state.enabledPrayers, prayer: value},
    );
    _save();
  }

  /// Sets the voice for [prayer]; Fajr is stored in its own field.
  void setVoice(PrayerName prayer, String voiceId) {
    final voice = adhanVoiceOrNull(voiceId);
    if (voice == null) return;
    if (prayer == PrayerName.fajr) {
      if (state.fajrVoiceId == voice.id) return;
      state = state.copyWith(fajrVoiceId: voice.id);
    } else {
      if (state.voices[prayer] == voice.id) return;
      state = state.copyWith(voices: {...state.voices, prayer: voice.id});
    }
    _save();
  }

  void setRemindersEnabled(bool value) {
    if (state.remindersEnabled == value) return;
    state = state.copyWith(remindersEnabled: value);
    _save();
  }

  void setReminderMinutes(int minutes) {
    if (!kReminderMinutesOptions.contains(minutes)) return;
    if (state.reminderMinutes == minutes) return;
    state = state.copyWith(reminderMinutes: minutes);
    _save();
  }

  /// Restores the defaults for the five prayers, keeping the master switch.
  void resetVoices() {
    state = state.copyWith(
      enabledPrayers: const <PrayerName, bool>{},
      voices: const <PrayerName, String>{},
      fajrVoiceId: kDefaultFajrVoiceId,
    );
    _save();
  }
}
