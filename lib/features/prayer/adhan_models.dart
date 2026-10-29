/// Persisted notification choices for the prayer feature.
library;

import 'package:flutter/foundation.dart';

import '../../core/adhan_voices.dart';
import 'prayer_models.dart';

/// The lead times offered in the reminder section, in minutes.
const List<int> kReminderMinutesOptions = <int>[5, 10, 15, 20, 30];

/// Which prayers notify, which voice each one uses, and whether a reminder
/// precedes the adhan.
@immutable
class AdhanSettings {
  const AdhanSettings({
    this.enabled = false,
    this.statusBarEnabled = true,
    this.enabledPrayers = const <PrayerName, bool>{},
    this.voices = const <PrayerName, String>{},
    this.fajrVoiceId = kDefaultFajrVoiceId,
    this.remindersEnabled = false,
    this.reminderMinutes = 10,
    this.silenceOnHardware = true,
  });

  /// Master switch.  When off, all scheduled prayer notifications are
  /// cancelled — the per-prayer choices are kept for next time.
  final bool enabled;

  /// Whether the ongoing prayer bar is shown.  It still needs the master
  /// switch, a saved location and the notification permission.
  final bool statusBarEnabled;

  /// Per-prayer switches; a missing entry means enabled.
  final Map<PrayerName, bool> enabledPrayers;

  /// Per-prayer voice ids for Dhuhr … Isha.  Fajr has its own field so the
  /// user can always give it a different recording.
  final Map<PrayerName, String> voices;

  /// The Fajr-specific voice.
  final String fajrVoiceId;

  /// Whether a separate reminder is scheduled before the adhan.
  final bool remindersEnabled;

  /// How many minutes before the prayer the reminder fires.
  final int reminderMinutes;

  /// Whether the phone's own hardware silences a playing adhan: the volume
  /// keys while the screen is in front, the screen turning off, and a change
  /// to the alarm volume while another app is in front.
  final bool silenceOnHardware;

  bool isPrayerEnabled(PrayerName prayer) => enabledPrayers[prayer] ?? true;

  /// The validated voice id for [prayer].
  String voiceIdFor(PrayerName prayer) {
    if (prayer == PrayerName.fajr) {
      return adhanVoiceOrNull(fajrVoiceId)?.id ?? kDefaultFajrVoiceId;
    }
    final id = voices[prayer];
    return adhanVoiceOrNull(id)?.id ?? kDefaultAdhanVoiceId;
  }

  AdhanSettings copyWith({
    bool? enabled,
    bool? statusBarEnabled,
    Map<PrayerName, bool>? enabledPrayers,
    Map<PrayerName, String>? voices,
    String? fajrVoiceId,
    bool? remindersEnabled,
    int? reminderMinutes,
    bool? silenceOnHardware,
  }) {
    return AdhanSettings(
      enabled: enabled ?? this.enabled,
      statusBarEnabled: statusBarEnabled ?? this.statusBarEnabled,
      enabledPrayers: enabledPrayers ?? this.enabledPrayers,
      voices: voices ?? this.voices,
      fajrVoiceId: fajrVoiceId ?? this.fajrVoiceId,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      silenceOnHardware: silenceOnHardware ?? this.silenceOnHardware,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'statusBar': statusBarEnabled,
        'prayers': {
          for (final entry in enabledPrayers.entries)
            entry.key.name: entry.value,
        },
        'voices': {
          for (final entry in voices.entries) entry.key.name: entry.value
        },
        'fajrVoice': fajrVoiceId,
        'reminders': remindersEnabled,
        'reminderMinutes': reminderMinutes,
        'silenceOnHardware': silenceOnHardware,
      };

  /// Reads persisted settings, dropping unknown voice ids and invalid values.
  static AdhanSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdhanSettings();

    final prayers = <PrayerName, bool>{};
    final rawPrayers = json['prayers'];
    if (rawPrayers is Map) {
      for (final prayer in PrayerName.values) {
        final value = rawPrayers[prayer.name];
        if (value is bool) prayers[prayer] = value;
      }
    }

    final voices = <PrayerName, String>{};
    final rawVoices = json['voices'];
    if (rawVoices is Map) {
      for (final prayer in PrayerName.values) {
        if (prayer == PrayerName.fajr) continue;
        final value = rawVoices[prayer.name];
        final voice = adhanVoiceOrNull(value is String ? value : null);
        if (voice != null) voices[prayer] = voice.id;
      }
    }

    final rawFajr = json['fajrVoice'];
    final fajrVoice = adhanVoiceOrNull(rawFajr is String ? rawFajr : null);
    final rawMinutes = json['reminderMinutes'];
    final minutes =
        rawMinutes is int && kReminderMinutesOptions.contains(rawMinutes)
            ? rawMinutes
            : 10;

    return AdhanSettings(
      enabled: json['enabled'] == true,
      statusBarEnabled: json['statusBar'] != false,
      enabledPrayers: prayers,
      voices: voices,
      fajrVoiceId: fajrVoice?.id ?? kDefaultFajrVoiceId,
      remindersEnabled: json['reminders'] == true,
      reminderMinutes: minutes,
      silenceOnHardware: json['silenceOnHardware'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdhanSettings &&
      other.enabled == enabled &&
      other.statusBarEnabled == statusBarEnabled &&
      mapEquals(other.enabledPrayers, enabledPrayers) &&
      mapEquals(other.voices, voices) &&
      other.fajrVoiceId == fajrVoiceId &&
      other.remindersEnabled == remindersEnabled &&
      other.reminderMinutes == reminderMinutes &&
      other.silenceOnHardware == silenceOnHardware;

  @override
  int get hashCode => Object.hash(
        enabled,
        statusBarEnabled,
        fajrVoiceId,
        remindersEnabled,
        reminderMinutes,
        silenceOnHardware,
        Object.hashAll(
          enabledPrayers.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAll(voices.entries.map((e) => Object.hash(e.key, e.value))),
      );
}
