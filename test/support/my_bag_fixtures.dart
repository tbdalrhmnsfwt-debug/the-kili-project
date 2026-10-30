import 'package:zaker_ai/core/key_value_store.dart';

/// An in-memory [KeyValueStore] for tests.
class MemoryKv implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
