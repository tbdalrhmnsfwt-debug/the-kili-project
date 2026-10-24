/// Riverpod state for the prayer feature.
///
/// * [prayerSettingsProvider] — calculation method, Asr madhab and whether the
///   first-run explanation has been seen.
/// * [prayerLocationProvider] — the last chosen location (GPS, city or manual
///   coordinates).
/// * [prayerClockProvider] — a shared one-second clock.  A single stream feeds
///   both the home card and the full screen, so the countdown stays in step.
/// * [prayerTimesTodayProvider] — the expensive astronomical calculation.  It
///   only recomputes when the day, the location or the settings change.
/// * [prayerDayProvider] — a cheap per-second view over those times.
library;

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hijri_date.dart';
import '../../core/local_store.dart';
import '../../core/prayer_methods.dart';
import '../../providers/app_providers.dart';
import 'prayer_models.dart';

const String _methodKey = 'prayer_method';
const String _madhabKey = 'prayer_madhab';
const String _onboardedKey = 'prayer_onboarded';
const String _locationKey = 'prayer_location';

/// The user's calculation choices.
final prayerSettingsProvider =
    StateNotifierProvider<PrayerSettingsController, PrayerSettings>((ref) {
      return PrayerSettingsController(ref.watch(localStoreProvider));
    });

/// The saved location, or `null` until the user picks one.
final prayerLocationProvider =
    StateNotifierProvider<PrayerLocationController, PrayerLocation?>((ref) {
      return PrayerLocationController(ref.watch(localStoreProvider));
    });

/// A clock that emits once per second, aligned to the second boundary.
final prayerClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  while (true) {
    final now = DateTime.now();
    final nextTick = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ).add(const Duration(seconds: 1));
    await Future<void>.delayed(nextTick.difference(now));
    yield DateTime.now();
  }
});

/// Today's prayer times, or `null` when no location is set or the calculation
/// fails.
///
/// The dependency on the clock is narrowed to the calendar day, so this
/// provider does not rebuild every second.
final prayerTimesTodayProvider = Provider.autoDispose<PrayerTimes?>((ref) {
  final location = ref.watch(prayerLocationProvider);
  final settings = ref.watch(prayerSettingsProvider);
  final today = ref.watch(
    prayerClockProvider.select((clock) {
      final now = clock.valueOrNull ?? DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }),
  );
  if (location == null) return null;

  try {
    return PrayerTimes(
      date: today,
      coordinates: Coordinates(location.latitude, location.longitude),
      calculationParameters: prayerParameters(
        methodId: settings.methodId,
        madhabId: settings.madhabId,
      ),
    );
  } catch (error) {
    debugPrint('prayer: could not compute times ($error)');
    return null;
  }
});

/// The live state of today's five prayers, refreshed every second.
final prayerDayProvider = Provider.autoDispose<PrayerDay?>((ref) {
  final times = ref.watch(prayerTimesTodayProvider);
  final location = ref.watch(prayerLocationProvider);
  // The stream is loading only for the first frame; using `now` avoids a
  // loading flash before the first tick arrives.
  final now = ref.watch(prayerClockProvider).valueOrNull ?? DateTime.now();
  if (times == null || location == null) return null;
  return PrayerDay.fromTimes(times: times, location: location, now: now);
});

/// Today's Hijri date, recomputed once per calendar day rather than once per
/// second (the home card rebuilds with the countdown).
final prayerHijriProvider = Provider.autoDispose<HijriDate>((ref) {
  final today = ref.watch(
    prayerClockProvider.select((clock) {
      final now = clock.valueOrNull ?? DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }),
  );
  return HijriDate.fromGregorian(today);
});

/// Persists the settings and exposes small update methods.
class PrayerSettingsController extends StateNotifier<PrayerSettings> {
  PrayerSettingsController(LocalStore store)
    : _store = store,
      super(_read(store));

  final LocalStore _store;

  static PrayerSettings _read(LocalStore store) {
    final method = store.getString(_methodKey);
    final madhab = store.getString(_madhabKey);
    final knownMethod = kPrayerMethods.any((option) => option.id == method);
    return PrayerSettings(
      methodId: knownMethod ? method! : 'egyptian',
      madhabId: madhab == 'hanafi' ? 'hanafi' : 'shafi',
      onboarded: store.getBool(_onboardedKey) ?? false,
    );
  }

  void setMethod(String id) {
    if (state.methodId == id) return;
    if (!kPrayerMethods.any((option) => option.id == id)) return;
    state = state.copyWith(methodId: id);
    _store.setString(_methodKey, id);
  }

  void setMadhab(String id) {
    final next = id == 'hanafi' ? 'hanafi' : 'shafi';
    if (state.madhabId == next) return;
    state = state.copyWith(madhabId: next);
    _store.setString(_madhabKey, next);
  }

  void markOnboarded() {
    if (state.onboarded) return;
    state = state.copyWith(onboarded: true);
    _store.setBool(_onboardedKey, true);
  }
}

/// Persists the chosen location.
class PrayerLocationController extends StateNotifier<PrayerLocation?> {
  PrayerLocationController(LocalStore store)
    : _store = store,
      super(_read(store));

  final LocalStore _store;

  static PrayerLocation? _read(LocalStore store) {
    return PrayerLocation.fromJson(store.getJson(_locationKey));
  }

  /// Saves [location] and immediately updates every listener.
  Future<void> save(PrayerLocation location) async {
    state = location;
    await _store.setJson(_locationKey, location.toJson());
  }

  /// Forgets the saved location (the user can pick another one).
  Future<void> clear() async {
    state = null;
    await _store.remove(_locationKey);
  }
}
