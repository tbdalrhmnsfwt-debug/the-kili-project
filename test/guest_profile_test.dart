import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/guest_profile.dart';
import 'package:zaker_ai/core/key_value_store.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  late _MemoryStore store;

  setUp(() {
    store = _MemoryStore();
  });

  test('keeps one guest uid across loads', () {
    final first = GuestProfileStore(store).loadOrCreate();
    final second = GuestProfileStore(store).loadOrCreate();

    expect(first.uid, startsWith('guest-'));
    expect(second.uid, first.uid);
    expect(second.displayName, 'ضيف');
  });

  test('adopts the legacy anonymous profile instead of minting a new uid', () {
    final profile = GuestProfileStore(
      store,
    ).loadOrCreate(seedUid: 'guest-legacy', seedDisplayName: '  أحمد  ');

    expect(profile.uid, 'guest-legacy');
    expect(profile.displayName, 'أحمد');

    final stored = jsonDecode(store.values[GuestProfileStore.storageKey]!);
    expect(stored['uid'], 'guest-legacy');
  });

  test('replaces corrupt JSON with a fresh, valid profile', () {
    store.values[GuestProfileStore.storageKey] = '{oops';

    final profile = GuestProfileStore(store).loadOrCreate();

    expect(profile.uid, startsWith('guest-'));
    expect(profile.uid.length, greaterThan('guest-'.length));
    final stored = jsonDecode(store.values[GuestProfileStore.storageKey]!);
    expect(stored['uid'], profile.uid);
  });

  test('ignores a stored profile with an empty uid', () {
    store.values[GuestProfileStore.storageKey] = jsonEncode({
      'uid': '',
      'displayName': 'قديم',
    });

    final profile = GuestProfileStore(store).loadOrCreate(
      seedUid: 'guest-seed',
    );

    expect(profile.uid, 'guest-seed');
  });

  test('saves a renamed guest and reads it back', () {
    final guestStore = GuestProfileStore(store);
    final profile = guestStore.loadOrCreate();
    guestStore.save(GuestProfile(uid: profile.uid, displayName: 'سارة'));

    expect(guestStore.loadOrCreate().displayName, 'سارة');
    expect(guestStore.loadOrCreate().uid, profile.uid);
  });
}
