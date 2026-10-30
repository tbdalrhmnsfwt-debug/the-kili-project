/// When each batch chat was last opened, per account.
///
/// Only timestamps are stored. The marker lets the first new message after a
/// visit show «رسائل جديدة» without inventing any server-side read receipts.
library;

import 'dart:convert';

import '../key_value_store.dart';
import 'batch_failure.dart';

class ChatSeenStore {
  ChatSeenStore(this._store);

  final KeyValueStore _store;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  String _key(String uid) => 'batches.chatSeen.v1.$uid';

  DateTime? seenAt({required String uid, required String batchId}) {
    if (uid.isEmpty || !_idPattern.hasMatch(batchId)) return null;
    final raw = _store.getString(_key(uid));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final value = decoded[batchId];
      return value is String ? DateTime.tryParse(value) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> markSeen({
    required String uid,
    required String batchId,
    required DateTime at,
  }) async {
    if (uid.isEmpty || !_idPattern.hasMatch(batchId)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'batchId',
      );
    }
    final entries = <String, String>{};
    final raw = _store.getString(_key(uid));
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is String && entry.value is String) {
              entries['${entry.key}'] = '${entry.value}';
            }
          }
        }
      } on FormatException {
        // A corrupt marker is replaced by the new timestamp.
      }
    }
    entries[batchId] = at.toUtc().toIso8601String();
    await _store.setString(_key(uid), jsonEncode(entries));
  }
}
