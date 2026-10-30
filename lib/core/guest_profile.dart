/// The persistent local guest identity.
///
/// The guest workspace is a real per-uid workspace on this device. Signing out
/// must return to the same one, so the uid is stored separately from the
/// signed-in profile and is only minted when it does not exist yet.
library;

import 'dart:convert';

import 'auth_service.dart';
import 'key_value_store.dart';

/// A guest uid plus the name shown inside its workspaces.
class GuestProfile {
  const GuestProfile({required this.uid, this.displayName = 'ضيف'});

  final String uid;
  final String displayName;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
      };

  factory GuestProfile.fromJson(Map<String, dynamic> json) => GuestProfile(
        uid: json['uid'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'ضيف',
      );
}

/// Reads, creates and migrates the guest profile in [KeyValueStore].
class GuestProfileStore {
  GuestProfileStore(this._store);

  final KeyValueStore _store;

  /// Never contains the account profile; that stays in `auth_user`.
  static const String storageKey = 'auth.guest.v1';

  /// Returns the stored guest profile, creating it if needed.
  ///
  /// [seedUid] and [seedDisplayName] migrate an install from before this key
  /// existed: the anonymous profile that was in `auth_user` becomes the
  /// persistent guest profile instead of being replaced by a fresh uid.
  GuestProfile loadOrCreate({String? seedUid, String? seedDisplayName}) {
    final stored = _read();
    if (stored != null && stored.uid.isNotEmpty) return stored;

    final uid = seedUid != null && seedUid.isNotEmpty ? seedUid : newGuestUid();
    final name = (seedDisplayName ?? '').trim();
    final profile = GuestProfile(
      uid: uid,
      displayName: name.isEmpty ? 'ضيف' : name,
    );
    save(profile);
    return profile;
  }

  /// Replaces the stored profile. Used when the guest renames themselves.
  ///
  /// The write is fire-and-forget because [KeyValueStore.setString] never
  /// throws and the in-memory profile is already the caller's value.
  void save(GuestProfile profile) {
    _store.setString(storageKey, jsonEncode(profile.toJson()));
  }

  GuestProfile? _read() {
    final raw = _store.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return GuestProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
