/// Resolves an invite code against the batches stored on this device.
///
/// A code is discovery, not authentication, and it cannot create a membership
/// in this build: joining another person's batch needs a server. The service
/// therefore reports exactly which local state the code reached.
library;

import 'dart:convert';

import '../../models/batch.dart';
import '../key_value_store.dart';
import 'batch_code_service.dart';
import 'batch_failure.dart';
import 'batch_repository.dart';
import 'batch_store.dart';
import 'local_batch_repository.dart';

/// Every outcome the join screen may show.
enum JoinCodeState {
  invalidFormat,
  cooldown,
  notFound,
  revoked,
  alreadyMember,
  pendingUnsupported,
  storageError,
}

/// One resolution result plus the preview data for a local match.
class JoinCodeResolution {
  const JoinCodeResolution(
    this.state, {
    this.batch,
    this.ownerName = '',
    this.subjectCount = 0,
    this.remaining = Duration.zero,
  });

  final JoinCodeState state;
  final Batch? batch;
  final String ownerName;
  final int subjectCount;

  /// Only meaningful for [JoinCodeState.cooldown].
  final Duration remaining;

  bool get isSuccess => state == JoinCodeState.alreadyMember;
}

/// Resolves codes and persists guess timestamps, never the guesses.
class BatchJoinService {
  BatchJoinService({
    required this.repository,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalBatchRepository repository;
  final KeyValueStore store;
  final DateTime Function() _clock;

  static const int freeAttempts = 5;
  static const Duration failureWindow = Duration(minutes: 10);
  static const Duration baseCooldown = Duration(seconds: 60);
  static const Duration maxCooldown = Duration(minutes: 10);

  Future<JoinCodeResolution> resolve({
    required String uid,
    required String input,
  }) async {
    final normalized = BatchCodeService.normalize(input);
    if (normalized == null) {
      return const JoinCodeResolution(JoinCodeState.invalidFormat);
    }
    if (uid.isEmpty) {
      return const JoinCodeResolution(JoinCodeState.storageError);
    }

    final guard = _loadGuard(uid);
    final now = _clock();
    if (!guard.canAttempt(now)) {
      return JoinCodeResolution(
        JoinCodeState.cooldown,
        remaining: guard.remaining(now),
      );
    }

    try {
      final match = await repository.lookupCode(uid, normalized);
      switch (match.kind) {
        case CodeMatchKind.none:
          guard.recordFailure(now);
          await _save(uid, guard);
          return const JoinCodeResolution(JoinCodeState.notFound);
        case CodeMatchKind.revoked:
          guard.recordFailure(now);
          await _save(uid, guard);
          return const JoinCodeResolution(JoinCodeState.revoked);
        case CodeMatchKind.active:
          final snapshot = match.snapshot!;
          final batch = snapshot.batch;
          final ownerName = _memberName(snapshot, batch.ownerUid);
          final isMember = snapshot.members.any((member) => member.uid == uid);
          guard.reset();
          await _save(uid, guard);
          if (!isMember) {
            return JoinCodeResolution(
              JoinCodeState.pendingUnsupported,
              batch: batch,
              ownerName: ownerName,
              subjectCount: batch.subjects.length,
            );
          }
          return JoinCodeResolution(
            JoinCodeState.alreadyMember,
            batch: batch,
            ownerName: ownerName,
            subjectCount: batch.subjects.length,
          );
      }
    } on BatchFailure {
      return const JoinCodeResolution(JoinCodeState.storageError);
    } catch (_) {
      return const JoinCodeResolution(JoinCodeState.storageError);
    }
  }

  CodeAttemptGuard _loadGuard(String uid) {
    final raw = store.getString(_guardKey(uid));
    if (raw == null || raw.isEmpty) {
      return CodeAttemptGuard(
        clock: _clock,
        freeAttempts: freeAttempts,
        window: failureWindow,
        baseCooldown: baseCooldown,
        maxCooldown: maxCooldown,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('not an object');
      return CodeAttemptGuard.fromJson(
        Map<String, dynamic>.from(decoded),
        clock: _clock,
        freeAttempts: freeAttempts,
        window: failureWindow,
        baseCooldown: baseCooldown,
        maxCooldown: maxCooldown,
      );
    } catch (_) {
      return CodeAttemptGuard(
        clock: _clock,
        freeAttempts: freeAttempts,
        window: failureWindow,
        baseCooldown: baseCooldown,
        maxCooldown: maxCooldown,
      );
    }
  }

  Future<void> _save(String uid, CodeAttemptGuard guard) {
    return store.setString(_guardKey(uid), jsonEncode(guard.toJson()));
  }

  static String _guardKey(String uid) => 'batches.codefails.v1.$uid';

  static String _memberName(BatchSnapshot snapshot, String uid) {
    for (final member in snapshot.members) {
      if (member.uid == uid) return member.displayName;
    }
    return '';
  }
}
