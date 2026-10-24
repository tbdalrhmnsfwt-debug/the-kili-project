/// The minimal key-value surface used by persistence code that must stay
/// testable without Flutter.
///
/// [LocalStore] implements this over `SharedPreferences`; tests can supply an
/// in-memory implementation and exercise migrations, backups and recovery on
/// plain Dart.
library;

abstract interface class KeyValueStore {
  /// Reads a raw string, or `null` when it was never written.
  String? getString(String key);

  /// Writes a raw string. Implementations never throw on failure.
  Future<void> setString(String key, String value);
}
