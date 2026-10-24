/// Persisted settings, daily counters and the loader for the azkar feature.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_store.dart';
import '../../providers/app_providers.dart';
import 'azkar_models.dart';

const String _settingsKey = 'azkar_settings';
const String _progressKey = 'azkar_progress';

/// Loads only `assets/data/azkar.json`.
///
/// A missing or malformed asset becomes an error, which the screens render as
/// a clearly labelled placeholder.  No azkar text is generated as a fallback.
final azkarDataProvider = FutureProvider<AzkarData>((ref) async {
  try {
    final raw = await rootBundle.loadString('assets/data/azkar.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('top-level value is not an object');
    }
    return AzkarData.fromJson(decoded);
  } catch (error, stackTrace) {
    debugPrint('azkar: could not load assets/data/azkar.json ($error)');
    Error.throwWithStackTrace(
      const AzkarDataException(
        'تعذر تحميل بيانات الأذكار من assets/data/azkar.json. '
        'التطبيق مش هيعرض نص من عند نفسه.',
      ),
      stackTrace,
    );
  }
});

/// A failure to read the bundled azkar asset.
class AzkarDataException implements Exception {
  const AzkarDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The live settings for salat reminders, morning/evening azkar and Kahf.
final azkarSettingsProvider =
    StateNotifierProvider<AzkarSettingsController, AzkarSettings>((ref) {
      return AzkarSettingsController(ref.watch(localStoreProvider));
    });

/// Today's tap counts for azkar, tasbih and salat.
final azkarProgressProvider =
    StateNotifierProvider<AzkarProgressController, AzkarProgress>((ref) {
      return AzkarProgressController(ref.watch(localStoreProvider));
    });

class AzkarSettingsController extends StateNotifier<AzkarSettings> {
  AzkarSettingsController(this._store) : super(_read(_store));

  final LocalStore _store;

  static AzkarSettings _read(LocalStore store) =>
      AzkarSettings.fromJson(store.getJson(_settingsKey));

  /// Replaces the settings and persists them.  Ignored when nothing changed.
  void update(AzkarSettings next) {
    if (next == state) return;
    state = next;
    _store.setJson(_settingsKey, next.toJson());
  }
}

/// The local calendar-day key used by the counters, e.g. `2026-10-24`.
String azkarDayKey(DateTime now) {
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

/// One day of tap counts.  Counts reset when the calendar day changes.
@immutable
class AzkarProgress {
  const AzkarProgress({required this.day, this.counts = const <String, int>{}});

  factory AzkarProgress.today([DateTime? now]) =>
      AzkarProgress(day: azkarDayKey(now ?? DateTime.now()));

  final String day;

  /// Counts keyed by azkar entry id, `tasbih_*` or `salat_*`.
  final Map<String, int> counts;

  int countFor(String id) => counts[id] ?? 0;

  bool isComplete(String id, int target) =>
      target > 0 && countFor(id) >= target;

  int completed(Iterable<AzkarEntry> entries) =>
      entries.where((entry) => isComplete(entry.id, entry.target)).length;

  /// Adds one tap.  With [target], the count stops at that target; without
  /// one (the salat counter), it keeps counting.
  AzkarProgress increment(String id, {int? target}) {
    final current = countFor(id);
    if (target != null && current >= target) return this;
    return AzkarProgress(
      day: day,
      counts: Map<String, int>.unmodifiable({...counts, id: current + 1}),
    );
  }

  AzkarProgress reset(String id) {
    if (!counts.containsKey(id)) return this;
    final next = Map<String, int>.of(counts)..remove(id);
    return AzkarProgress(day: day, counts: Map<String, int>.unmodifiable(next));
  }

  AzkarProgress resetMany(Iterable<String> ids) {
    final next = Map<String, int>.of(counts);
    var changed = false;
    for (final id in ids) {
      changed = next.remove(id) != null || changed;
    }
    if (!changed) return this;
    return AzkarProgress(day: day, counts: Map<String, int>.unmodifiable(next));
  }

  AzkarProgress get cleared =>
      AzkarProgress(day: day, counts: const <String, int>{});

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': day,
    'counts': counts,
  };

  static AzkarProgress fromJson(Map<String, dynamic>? json) {
    if (json == null) return AzkarProgress.today();
    final day = json['day'];
    if (day is! String || day != azkarDayKey(DateTime.now())) {
      return AzkarProgress.today();
    }
    final raw = json['counts'];
    final counts = <String, int>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is num && value.toInt() > 0) {
          counts['${entry.key}'] = value.toInt();
        }
      }
    }
    return AzkarProgress(
      day: day,
      counts: Map<String, int>.unmodifiable(counts),
    );
  }
}

class AzkarProgressController extends StateNotifier<AzkarProgress> {
  AzkarProgressController(this._store) : super(_read(_store));

  final LocalStore _store;

  static AzkarProgress _read(LocalStore store) =>
      AzkarProgress.fromJson(store.getJson(_progressKey));

  void _commit(AzkarProgress next) {
    if (identical(next, state)) return;
    state = next;
    _store.setJson(_progressKey, next.toJson());
  }

  /// Rolls the counters over when the app stays open past midnight.
  void ensureToday() {
    final today = azkarDayKey(DateTime.now());
    if (state.day == today) return;
    _commit(AzkarProgress.today());
  }

  void increment(String id, {int? target}) {
    ensureToday();
    _commit(state.increment(id, target: target));
  }

  void reset(String id) {
    ensureToday();
    _commit(state.reset(id));
  }

  void resetMany(Iterable<String> ids) {
    ensureToday();
    _commit(state.resetMany(ids));
  }

  void resetAll() {
    _commit(AzkarProgress.today());
  }
}
