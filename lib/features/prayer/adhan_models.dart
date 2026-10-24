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
    this.enabledPrayers = const <PrayerName, bool>{},
    this.voices = const <PrayerName, String>{},
    this.fajrVoiceId = kDefaultFajrVoiceId,
    this.remindersEnabled = false,
    this.reminderMinutes = 10,
  });

  /// Master switch.  When off, all scheduled prayer notifications are
  /// cancelled — the per-prayer choices are kept for next time.
  final bool enabled;

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
    Map<PrayerName, bool>? enabledPrayers,
    Map<PrayerName, String>? voices,
    String? fajrVoiceId,
    bool? remindersEnabled,
    int? reminderMinutes,
  }) {
    return AdhanSettings(
      enabled: enabled ?? this.enabled,
      enabledPrayers: enabledPrayers ?? this.enabledPrayers,
      voices: voices ?? this.voices,
      fajrVoiceId: fajrVoiceId ?? this.fajrVoiceId,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'prayers': {
      for (final entry in enabledPrayers.entries) entry.key.name: entry.value,
    },
    'voices': {for (final entry in voices.entries) entry.key.name: entry.value},
    'fajrVoice': fajrVoiceId,
    'reminders': remindersEnabled,
    'reminderMinutes': reminderMinutes,
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
      enabledPrayers: prayers,
      voices: voices,
      fajrVoiceId: fajrVoice?.id ?? kDefaultFajrVoiceId,
      remindersEnabled: json['reminders'] == true,
      reminderMinutes: minutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdhanSettings &&
      other.enabled == enabled &&
      mapEquals(other.enabledPrayers, enabledPrayers) &&
      mapEquals(other.voices, voices) &&
      other.fajrVoiceId == fajrVoiceId &&
      other.remindersEnabled == remindersEnabled &&
      other.reminderMinutes == reminderMinutes;

  @override
  int get hashCode => Object.hash(
    enabled,
    fajrVoiceId,
    remindersEnabled,
    reminderMinutes,
    Object.hashAll(
      enabledPrayers.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(voices.entries.map((e) => Object.hash(e.key, e.value))),
  );
}
