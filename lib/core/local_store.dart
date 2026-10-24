/// On-device persistence for the user's study data.
///
/// Every value the app keeps between launches (tasks, wallet, notebooks,
/// vocabulary, mistakes, goals, the recall queue, game progress, the daily
/// study statistics) goes through here. The store never throws: when
/// [SharedPreferences] is unavailable — widget tests, previews, a platform
/// channel that failed to register — it silently becomes a no-op so the app
/// still runs, just without remembering anything.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// A thin, failure-tolerant wrapper around [SharedPreferences].
class LocalStore implements KeyValueStore {
  LocalStore._(this._prefs);

  /// A store that keeps nothing, used when the platform store is missing.
  LocalStore.memory() : _prefs = null;

  final SharedPreferences? _prefs;

  /// All keys live under this prefix, matching the `zaker.*` keys the
  /// original app writes.
  static const String keyPrefix = 'zaker.';

  /// Opens the on-device store. Never throws.
  static Future<LocalStore> open() async {
    try {
      return LocalStore._(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('local_store: running without persistence ($e)');
      return LocalStore.memory();
    }
  }

  /// Whether values will actually be written to disk.
  bool get isAvailable => _prefs != null;

  /// Reads a raw string, or `null` when it was never written.
  @override
  String? getString(String key) => _prefs?.getString('$keyPrefix$key');

  /// Reads a boolean, or `null` when it was never written.
  bool? getBool(String key) => _prefs?.getBool('$keyPrefix$key');

  /// Writes a boolean. Failures are logged, never thrown.
  Future<void> setBool(String key, bool value) async {
    try {
      await _prefs?.setBool('$keyPrefix$key', value);
    } catch (e) {
      debugPrint('local_store: could not save $key ($e)');
    }
  }

  /// Writes a raw string. Failures are logged, never thrown.
  @override
  Future<void> setString(String key, String value) async {
    try {
      await _prefs?.setString('$keyPrefix$key', value);
    } catch (e) {
      debugPrint('local_store: could not save $key ($e)');
    }
  }

  /// Removes a stored value.
  Future<void> remove(String key) async {
    try {
      await _prefs?.remove('$keyPrefix$key');
    } catch (e) {
      debugPrint('local_store: could not remove $key ($e)');
    }
  }

  /// Reads and decodes a JSON object, or `null` when missing or corrupt.
  Map<String, dynamic>? getJson(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('local_store: ignoring corrupt $key ($e)');
      return null;
    }
  }

  /// Encodes and writes a JSON object.
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));
}
