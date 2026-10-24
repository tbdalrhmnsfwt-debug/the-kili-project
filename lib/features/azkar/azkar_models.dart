/// Data and persisted settings for the azkar feature.
///
/// The morning and evening lists are loaded only from
/// `assets/data/azkar.json`.  Nothing in this file invents azkar text: that
/// asset is a verbatim morning/evening subset of the app's existing
/// `assets/data/adhkar.json`.
library;

import 'package:flutter/foundation.dart';

import '../../core/salat_audio.dart';

/// The two daily azkar periods.
enum AzkarPeriod { morning, evening }

extension AzkarPeriodInfo on AzkarPeriod {
  /// The exact notification title requested for the period.
  String get title => switch (this) {
    AzkarPeriod.morning => 'اذكار الصباح',
    AzkarPeriod.evening => 'اذكار المساء',
  };

  /// A short label for navigation and cards.
  String get label => switch (this) {
    AzkarPeriod.morning => 'أذكار الصباح',
    AzkarPeriod.evening => 'أذكار المساء',
  };

  /// When the reminder is anchored.
  String get anchorLabel => switch (this) {
    AzkarPeriod.morning => 'بعد الفجر',
    AzkarPeriod.evening => 'بعد العصر',
  };

  /// The name stored in notification payloads and settings.
  String get wireName => name;

  static AzkarPeriod fromWire(Object? value) =>
      value == AzkarPeriod.evening.wireName
      ? AzkarPeriod.evening
      : AzkarPeriod.morning;
}

/// One dhikr from `assets/data/azkar.json`.
@immutable
class AzkarEntry {
  const AzkarEntry({
    required this.id,
    required this.period,
    required this.order,
    required this.content,
    required this.target,
    this.countDescription = '',
    this.fadl = '',
    this.source = '',
  });

  final String id;
  final AzkarPeriod period;
  final int order;

  /// The dhikr text, copied verbatim from the bundled asset.
  final String content;

  /// How many times the dhikr is said.  At least 1.
  final int target;

  /// The original count wording, e.g. «ثلاث مرات».
  final String countDescription;

  /// The virtue text from the source asset, when present.
  final String fadl;

  /// The source/reference text from the source asset, when present.
  final String source;

  bool get hasSource => source.trim().isNotEmpty || fadl.trim().isNotEmpty;

  /// Reads one entry.  Returns `null` for an entry without usable text.
  static AzkarEntry? fromJson(Map<String, dynamic> json, AzkarPeriod period) {
    final content = json['content'];
    if (content is! String || content.trim().isEmpty) return null;
    final orderValue = json['order'];
    final order = orderValue is num ? orderValue.toInt() : 0;
    final countValue = json['count'];
    final target = countValue is num && countValue.toInt() > 0
        ? countValue.toInt()
        : 1;
    final id = json['id'];
    return AzkarEntry(
      id: id is String && id.isNotEmpty ? id : '${period.name}_$order',
      period: period,
      order: order,
      content: content,
      target: target,
      countDescription: _string(json['count_description']),
      fadl: _string(json['fadl']),
      source: _string(json['source']),
    );
  }

  static String _string(Object? value) => value is String ? value : '';
}

/// The loaded morning and evening lists.
@immutable
class AzkarData {
  const AzkarData({required this.morning, required this.evening});

  final List<AzkarEntry> morning;
  final List<AzkarEntry> evening;

  List<AzkarEntry> forPeriod(AzkarPeriod period) => switch (period) {
    AzkarPeriod.morning => morning,
    AzkarPeriod.evening => evening,
  };

  /// Every entry id in both lists.
  Set<String> get allIds => <String>{
    for (final entry in [...morning, ...evening]) entry.id,
  };

  /// Parses the top-level `azkar.json` object.  Throws [FormatException] when
  /// the shape is unusable, so the screen can show its explicit placeholder
  /// instead of pretending there is data.
  static AzkarData fromJson(Map<String, dynamic> json) {
    final morning = _parseList(json['morning'], AzkarPeriod.morning);
    final evening = _parseList(json['evening'], AzkarPeriod.evening);
    if (morning.isEmpty && evening.isEmpty) {
      throw const FormatException('azkar.json has no usable entries');
    }
    return AzkarData(
      morning: List<AzkarEntry>.unmodifiable(morning),
      evening: List<AzkarEntry>.unmodifiable(evening),
    );
  }

  static List<AzkarEntry> _parseList(Object? value, AzkarPeriod period) {
    if (value is! List) return const <AzkarEntry>[];
    final entries = <AzkarEntry>[];
    for (final row in value) {
      if (row is! Map) continue;
      final entry = AzkarEntry.fromJson(
        row.map((key, value) => MapEntry('$key', value)),
        period,
      );
      if (entry != null) entries.add(entry);
    }
    entries.sort((a, b) => a.order.compareTo(b.order));
    return entries;
  }
}

/// The interval choices offered for salat reminders.
const List<int> kSalatIntervals = <int>[15, 30, 60];

/// The offset choices offered for the morning/evening notifications.
const List<int> kAzkarOffsetOptions = <int>[0, 10, 15, 30, 45, 60];

/// When salat reminders are allowed to fire.
enum SalatWindow { daytime, allDay, fajrToIsha, custom }

extension SalatWindowInfo on SalatWindow {
  String get label => switch (this) {
    SalatWindow.daytime => 'النهار (٨ ص – ٨ م)',
    SalatWindow.allDay => 'طول اليوم',
    SalatWindow.fajrToIsha => 'من الفجر للعشاء',
    SalatWindow.custom => 'وقت مخصص',
  };

  String get wireName => name;

  static SalatWindow fromWire(Object? value) {
    return switch (value) {
      'allDay' => SalatWindow.allDay,
      'fajrToIsha' => SalatWindow.fajrToIsha,
      'custom' => SalatWindow.custom,
      _ => SalatWindow.daytime,
    };
  }
}

/// Returns «٨:٠٥ ص» for 485 minutes from midnight.
String formatClockMinutes(int minutes) {
  final value = minutes.clamp(0, 24 * 60);
  final hour24 = (value ~/ 60) % 24;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = (value % 60).toString().padLeft(2, '0');
  return '$hour:$minute ${hour24 < 12 ? 'ص' : 'م'}';
}

/// The user's choices for the whole azkar feature.
@immutable
class AzkarSettings {
  const AzkarSettings({
    this.salatEnabled = false,
    this.salatIntervalMinutes = 60,
    this.salatWindow = SalatWindow.daytime,
    this.salatStartMinutes = 8 * 60,
    this.salatEndMinutes = 20 * 60,
    this.selectedPhraseIds = defaultPhraseIds,
    this.phraseSounds = const <String, SalatSoundMode>{},
    this.salatVibration = true,
    this.morningEnabled = false,
    this.morningOffsetMinutes = 15,
    this.eveningEnabled = false,
    this.eveningOffsetMinutes = 15,
    this.kahfEnabled = false,
    this.kahfHour = 10,
    this.kahfMinute = 0,
  });

  static const Set<String> defaultPhraseIds = <String>{
    'asal_ala_muhammad',
    'asal_ala_sayyidina_muhammad',
    'allahumma_salli',
  };

  final bool salatEnabled;

  /// One of [kSalatIntervals].
  final int salatIntervalMinutes;

  final SalatWindow salatWindow;

  /// The custom window start, in minutes from local midnight.
  final int salatStartMinutes;

  /// The custom window end, in minutes from local midnight.
  final int salatEndMinutes;

  /// The selected phrase ids; an empty set means no salat reminders.
  final Set<String> selectedPhraseIds;

  /// The sound choice per phrase; a missing phrase uses the chime.
  final Map<String, SalatSoundMode> phraseSounds;

  final bool salatVibration;

  final bool morningEnabled;
  final int morningOffsetMinutes;

  final bool eveningEnabled;
  final int eveningOffsetMinutes;

  final bool kahfEnabled;
  final int kahfHour;
  final int kahfMinute;

  bool get isAnyEnabled =>
      salatEnabled || morningEnabled || eveningEnabled || kahfEnabled;

  /// The selected phrases in the canonical order of [kSalatPhrases].
  List<SalatPhrase> get selectedPhrases => List<SalatPhrase>.unmodifiable(
    kSalatPhrases.where((phrase) => selectedPhraseIds.contains(phrase.id)),
  );

  bool isPhraseSelected(String id) => selectedPhraseIds.contains(id);

  SalatSoundMode soundFor(String phraseId) =>
      phraseSounds[phraseId] ?? SalatSoundMode.chime;

  AzkarSettings copyWith({
    bool? salatEnabled,
    int? salatIntervalMinutes,
    SalatWindow? salatWindow,
    int? salatStartMinutes,
    int? salatEndMinutes,
    Set<String>? selectedPhraseIds,
    Map<String, SalatSoundMode>? phraseSounds,
    bool? salatVibration,
    bool? morningEnabled,
    int? morningOffsetMinutes,
    bool? eveningEnabled,
    int? eveningOffsetMinutes,
    bool? kahfEnabled,
    int? kahfHour,
    int? kahfMinute,
  }) {
    return AzkarSettings(
      salatEnabled: salatEnabled ?? this.salatEnabled,
      salatIntervalMinutes: salatIntervalMinutes ?? this.salatIntervalMinutes,
      salatWindow: salatWindow ?? this.salatWindow,
      salatStartMinutes: salatStartMinutes ?? this.salatStartMinutes,
      salatEndMinutes: salatEndMinutes ?? this.salatEndMinutes,
      selectedPhraseIds: selectedPhraseIds ?? this.selectedPhraseIds,
      phraseSounds: phraseSounds ?? this.phraseSounds,
      salatVibration: salatVibration ?? this.salatVibration,
      morningEnabled: morningEnabled ?? this.morningEnabled,
      morningOffsetMinutes: morningOffsetMinutes ?? this.morningOffsetMinutes,
      eveningEnabled: eveningEnabled ?? this.eveningEnabled,
      eveningOffsetMinutes: eveningOffsetMinutes ?? this.eveningOffsetMinutes,
      kahfEnabled: kahfEnabled ?? this.kahfEnabled,
      kahfHour: kahfHour ?? this.kahfHour,
      kahfMinute: kahfMinute ?? this.kahfMinute,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'salatEnabled': salatEnabled,
    'salatInterval': salatIntervalMinutes,
    'salatWindow': salatWindow.wireName,
    'salatStart': salatStartMinutes,
    'salatEnd': salatEndMinutes,
    'phrases': selectedPhraseIds.toList(growable: false),
    'sounds': phraseSounds.map((id, mode) => MapEntry(id, mode.wireName)),
    'salatVibration': salatVibration,
    'morningEnabled': morningEnabled,
    'morningOffset': morningOffsetMinutes,
    'eveningEnabled': eveningEnabled,
    'eveningOffset': eveningOffsetMinutes,
    'kahfEnabled': kahfEnabled,
    'kahfHour': kahfHour,
    'kahfMinute': kahfMinute,
  };

  /// Reads persisted settings, discarding values that are no longer valid.
  static AzkarSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AzkarSettings();

    final rawPhrases = json['phrases'];
    final phraseIds = rawPhrases is List
        ? rawPhrases.whereType<String>().where(kSalatPhraseIds.contains).toSet()
        : Set<String>.of(defaultPhraseIds);

    final sounds = <String, SalatSoundMode>{};
    final rawSounds = json['sounds'];
    if (rawSounds is Map) {
      for (final phrase in kSalatPhrases) {
        if (rawSounds.containsKey(phrase.id)) {
          sounds[phrase.id] = SalatSoundMode.fromWire(rawSounds[phrase.id]);
        }
      }
    }

    final interval = _int(json['salatInterval'], 60);
    final start = _int(
      json['salatStart'],
      8 * 60,
    ).clamp(0, 24 * 60 - 1).toInt();
    final end = _int(json['salatEnd'], 20 * 60).clamp(0, 24 * 60).toInt();

    return AzkarSettings(
      salatEnabled: json['salatEnabled'] == true,
      salatIntervalMinutes: kSalatIntervals.contains(interval) ? interval : 60,
      salatWindow: SalatWindowInfo.fromWire(json['salatWindow']),
      salatStartMinutes: start,
      salatEndMinutes: end,
      selectedPhraseIds: Set<String>.unmodifiable(phraseIds),
      phraseSounds: Map<String, SalatSoundMode>.unmodifiable(sounds),
      salatVibration: json['salatVibration'] != false,
      morningEnabled: json['morningEnabled'] == true,
      morningOffsetMinutes: _int(
        json['morningOffset'],
        15,
      ).clamp(0, 120).toInt(),
      eveningEnabled: json['eveningEnabled'] == true,
      eveningOffsetMinutes: _int(
        json['eveningOffset'],
        15,
      ).clamp(0, 120).toInt(),
      kahfEnabled: json['kahfEnabled'] == true,
      kahfHour: _int(json['kahfHour'], 10).clamp(0, 23).toInt(),
      kahfMinute: _int(json['kahfMinute'], 0).clamp(0, 59).toInt(),
    );
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  @override
  bool operator ==(Object other) =>
      other is AzkarSettings &&
      other.salatEnabled == salatEnabled &&
      other.salatIntervalMinutes == salatIntervalMinutes &&
      other.salatWindow == salatWindow &&
      other.salatStartMinutes == salatStartMinutes &&
      other.salatEndMinutes == salatEndMinutes &&
      setEquals(other.selectedPhraseIds, selectedPhraseIds) &&
      mapEquals(other.phraseSounds, phraseSounds) &&
      other.salatVibration == salatVibration &&
      other.morningEnabled == morningEnabled &&
      other.morningOffsetMinutes == morningOffsetMinutes &&
      other.eveningEnabled == eveningEnabled &&
      other.eveningOffsetMinutes == eveningOffsetMinutes &&
      other.kahfEnabled == kahfEnabled &&
      other.kahfHour == kahfHour &&
      other.kahfMinute == kahfMinute;

  @override
  int get hashCode => Object.hash(
    salatEnabled,
    salatIntervalMinutes,
    salatWindow,
    salatStartMinutes,
    salatEndMinutes,
    Object.hashAllUnordered(selectedPhraseIds),
    Object.hashAllUnordered(
      phraseSounds.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    salatVibration,
    morningEnabled,
    morningOffsetMinutes,
    eveningEnabled,
    eveningOffsetMinutes,
    kahfEnabled,
    kahfHour,
    kahfMinute,
  );
}
