/// Resume positions for audio resources, per account, batch and resource.
///
/// Only positions are stored — never file paths, titles or other content — in
/// the small per-uid key-value index. The oldest entries are evicted once the
/// cap is reached, so listening to many files cannot grow this without bound.
library;

import 'dart:convert';

import '../key_value_store.dart';
import 'batch_failure.dart';

class PlaybackPositionStore {
  PlaybackPositionStore(
    this._store, {
    DateTime Function()? clock,
    this.maxEntries = 200,
  }) : _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _clock;

  /// Newest positions kept per account.
  final int maxEntries;

  static const int maxPositionMs = 24 * 60 * 60 * 1000;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  String _key(String uid) => 'batches.playback.v1.$uid';

  /// Saves the clamped position for one resource.
  ///
  /// An unknown duration is not stored: seeking on reopen needs a real total,
  /// and a made-up one would look like a correctly remembered position.
  Future<void> save({
    required String uid,
    required String batchId,
    required String resourceId,
    required int positionMs,
    required int durationMs,
  }) async {
    _requireIds(uid, batchId, resourceId);
    if (durationMs <= 0) return;
    final clamped = positionMs.clamp(0, durationMs).toInt();
    if (clamped <= 0) {
      await remove(uid: uid, batchId: batchId, resourceId: resourceId);
      return;
    }
    final entries = _read(uid);
    entries[_entryKey(batchId, resourceId)] = _Entry(
      positionMs: clamped.clamp(0, maxPositionMs).toInt(),
      at: _clock(),
    );
    _evict(entries);
    await _write(uid, entries);
  }

  /// The remembered position, or null when there is none.
  int? positionFor({
    required String uid,
    required String batchId,
    required String resourceId,
  }) {
    if (!_valid(uid, batchId, resourceId)) return null;
    final entry = _read(uid)[_entryKey(batchId, resourceId)];
    if (entry == null || entry.positionMs <= 0) return null;
    return entry.positionMs;
  }

  Future<void> remove({
    required String uid,
    required String batchId,
    required String resourceId,
  }) async {
    _requireIds(uid, batchId, resourceId);
    final entries = _read(uid);
    if (entries.remove(_entryKey(batchId, resourceId)) == null) return;
    await _write(uid, entries);
  }

  /// Drops every remembered position inside one batch.
  Future<void> clearBatch({
    required String uid,
    required String batchId,
  }) async {
    _requireIds(uid, batchId, batchId);
    final prefix = '$batchId/';
    final entries = _read(uid);
    final before = entries.length;
    entries.removeWhere((key, _) => key.startsWith(prefix));
    if (entries.length == before) return;
    await _write(uid, entries);
  }

  String _entryKey(String batchId, String resourceId) =>
      '$batchId/$resourceId';

  Map<String, _Entry> _read(String uid) {
    final raw = _store.getString(_key(uid));
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final entries = decoded['entries'];
      if (entries is! Map) return {};
      final result = <String, _Entry>{};
      for (final entry in entries.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final position = value['ms'];
        final atRaw = value['at'];
        final at = atRaw is String ? DateTime.tryParse(atRaw) : null;
        if (position is! num ||
            position <= 0 ||
            position > maxPositionMs ||
            at == null) {
          continue;
        }
        result['${entry.key}'] = _Entry(
          positionMs: position.toInt(),
          at: at,
        );
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<void> _write(String uid, Map<String, _Entry> entries) {
    final body = <String, dynamic>{
      'entries': {
        for (final entry in entries.entries)
          entry.key: {
            'ms': entry.value.positionMs,
            'at': entry.value.at.toUtc().toIso8601String(),
          },
      },
    };
    return _store.setString(_key(uid), jsonEncode(body));
  }

  void _evict(Map<String, _Entry> entries) {
    if (entries.length <= maxEntries) return;
    final ordered = entries.entries.toList()
      ..sort((a, b) => a.value.at.compareTo(b.value.at));
    for (final entry in ordered.take(entries.length - maxEntries)) {
      entries.remove(entry.key);
    }
  }

  bool _valid(String uid, String batchId, String resourceId) =>
      uid.isNotEmpty &&
      _idPattern.hasMatch(batchId) &&
      _idPattern.hasMatch(resourceId);

  void _requireIds(String uid, String batchId, String resourceId) {
    if (uid.isEmpty) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'uid',
      );
    }
    if (!_idPattern.hasMatch(batchId) || !_idPattern.hasMatch(resourceId)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'id',
      );
    }
  }
}

class _Entry {
  const _Entry({required this.positionMs, required this.at});

  final int positionMs;
  final DateTime at;
}
