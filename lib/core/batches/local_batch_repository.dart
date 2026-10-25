/// The on-device batch repository.
library;

import 'dart:convert';

import '../../models/batch.dart';
import '../key_value_store.dart';
import 'batch_access.dart';
import 'batch_code_service.dart';
import 'batch_failure.dart';
import 'batch_file_store.dart';
import 'batch_ids.dart';
import 'batch_repository.dart';
import 'batch_store.dart';
import 'document_store.dart';

class LocalBatchRepository implements BatchRepository {
  LocalBatchRepository({
    required this.files,
    required this.store,
    BatchCodeService? codes,
    DateTime Function()? clock,
  })  : _codes = codes ?? BatchCodeService(),
        _clock = clock ?? DateTime.now;

  final BatchFileStore files;
  final KeyValueStore store;
  final BatchCodeService _codes;
  final DateTime Function() _clock;

  static const int maxSubjects = 20;
  static const int maxSubjectNameLength = 40;
  static const int maxBatchNameLength = 60;
  static const int auditCap = 200;
  static const int codeLedgerCap = 200;

  static final RegExp _batchIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  // ------------------------------------------------------------------- reads

  @override
  Future<List<BatchSummary>> listBatches(String uid) async {
    final indexed = _readIndex(uid);
    final onDisk = await files.listBatchDirectories(uid);
    final ordered = <String>[];
    final seen = <String>{};
    for (final id in [...indexed, ...onDisk]) {
      if (!_batchIdPattern.hasMatch(id) || !seen.add(id)) continue;
      ordered.add(id);
    }

    final summaries = <BatchSummary>[];
    final keep = <String>[];
    for (final batchId in ordered) {
      final store = BatchStore(directory: files.batchDir(uid, batchId));
      final load = await store.batch.load();
      if (load.isMissing) {
        // A stale index entry, or a directory left by an interrupted create.
        continue;
      }
      if (!load.isUsable) {
        summaries.add(BatchSummary(batchId: batchId, failure: load.failure));
        keep.add(batchId);
        continue;
      }
      final snapshot = load.value!;
      final membership = _membershipOf(snapshot, uid);
      if (membership == null || !BatchAccess.isReader(membership.role)) {
        // Another account's directory is never listed.
        continue;
      }
      final updates = await store.updates.load();
      final unread = updates.isUsable
          ? updates.value!.where((item) => !item.isReadBy(uid)).length
          : 0;
      summaries.add(
        BatchSummary(
          batchId: batchId,
          batch: snapshot.batch,
          resourceCount: snapshot.resources.length,
          unreadUpdates: unread,
        ),
      );
      keep.add(batchId);
    }

    if (!_sameIds(indexed, keep)) {
      await _writeIndex(uid, keep);
    }
    summaries.sort((a, b) {
      if (a.isAvailable != b.isAvailable) return a.isAvailable ? -1 : 1;
      return b.lastActivityAt.compareTo(a.lastActivityAt);
    });
    return summaries;
  }

  @override
  Future<BatchSnapshot> loadBatch(String uid, String batchId) async {
    final store = BatchStore(directory: files.batchDir(uid, batchId));
    final load = await store.batch.load();
    switch (load.status) {
      case DocumentLoadStatus.missing:
        throw const BatchFailure(BatchFailureCode.notFound);
      case DocumentLoadStatus.corrupt:
        throw const BatchFailure(
          BatchFailureCode.corruptStore,
          detail: 'batch document unreadable',
        );
      case DocumentLoadStatus.unsupportedSchema:
        throw const BatchFailure(
          BatchFailureCode.migrationUnsupported,
          detail: 'batch document from a newer build',
        );
      case DocumentLoadStatus.ok:
      case DocumentLoadStatus.recovered:
        break;
    }
    final snapshot = load.value!;
    final membership = _membershipOf(snapshot, uid);
    if (membership == null || !BatchAccess.isReader(membership.role)) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    return snapshot;
  }

  @override
  Future<int> storageUsed(String uid, String batchId) =>
      files.storageUsed(uid: uid, batchId: batchId);

  // ------------------------------------------------------------------ writes

  @override
  Future<Batch> createBatch({
    required String uid,
    required String displayName,
    required String name,
    required List<String> subjects,
  }) async {
    final cleanName = _normalizeBatchName(name);
    final cleanSubjects = _normalizeSubjects(subjects);
    final cleanDisplay =
        displayName.trim().isEmpty ? 'أنت' : displayName.trim();
    final now = _clock();
    final batchId = newBatchId();
    final code = _newCode(uid);
    final models = <BatchSubject>[
      for (var i = 0; i < cleanSubjects.length; i++)
        BatchSubject(
          id: newEntityId('sub'),
          name: cleanSubjects[i],
          order: i,
          createdAt: now,
        ),
    ];
    final batch = Batch(
      id: batchId,
      name: cleanName,
      ownerUid: uid,
      createdAt: now,
      settings: const BatchSettings(),
      subjects: models,
      codeState: InviteCodeState(code: code, createdAt: now),
      lastActivityAt: now,
    );
    final snapshot = BatchSnapshot(
      batch: batch,
      members: [
        Membership(
          batchId: batchId,
          uid: uid,
          displayName: cleanDisplay,
          role: BatchRole.owner,
          joinedAt: now,
        ),
      ],
    );

    final store = BatchStore(directory: files.batchDir(uid, batchId));
    await files.ensureBatchDir(uid, batchId);
    try {
      await store.batch.save(snapshot);
    } catch (_) {
      // A create is all-or-nothing: remove the half-made directory.
      try {
        await files.deleteBatch(uid: uid, batchId: batchId);
      } on BatchFailure {
        // The original failure is more useful than the rollback failure.
      }
      rethrow;
    }
    await _rememberCode(uid, code);
    await _addToIndex(uid, batchId);
    await _appendAudit(
      store: store,
      batchId: batchId,
      actorUid: uid,
      action: 'batchCreated',
    );
    return batch;
  }

  @override
  Future<Batch> updateSettings(
    String uid,
    String batchId,
    BatchSettings settings,
  ) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.manageSettings);
    final now = _clock();
    final updated = snapshot.copyWith(
      batch: snapshot.batch.copyWith(settings: settings, lastActivityAt: now),
    );
    await _save(uid, batchId, updated);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'settingsUpdated',
    );
    return updated.batch;
  }

  @override
  Future<BatchSubject> addSubject(
    String uid,
    String batchId,
    String name,
  ) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.manageSubjects);
    final cleanName = _normalizeSubjectName(name);
    final subjects = snapshot.batch.subjects;
    if (subjects.length >= maxSubjects) {
      throw const BatchFailure(
        BatchFailureCode.invalidSubject,
        field: 'name',
        detail: 'subject limit',
      );
    }
    if (_hasSubjectNamed(subjects, cleanName)) {
      throw const BatchFailure(
        BatchFailureCode.invalidSubject,
        field: 'name',
        detail: 'duplicate subject',
      );
    }
    final now = _clock();
    final subject = BatchSubject(
      id: newEntityId('sub'),
      name: cleanName,
      order: subjects.isEmpty
          ? 0
          : subjects.map((item) => item.order).reduce((a, b) => a > b ? a : b) +
              1,
      createdAt: now,
    );
    final updated = snapshot.copyWith(
      batch: snapshot.batch.copyWith(
        subjects: [...subjects, subject],
        lastActivityAt: now,
      ),
    );
    await _save(uid, batchId, updated);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'subjectAdded',
    );
    return subject;
  }

  @override
  Future<void> renameSubject(
    String uid,
    String batchId,
    String subjectId,
    String name,
  ) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.manageSubjects);
    final cleanName = _normalizeSubjectName(name);
    final subjects = snapshot.batch.subjects;
    final index = subjects.indexWhere((item) => item.id == subjectId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'subjectId');
    }
    final others = [...subjects]..removeAt(index);
    if (_hasSubjectNamed(others, cleanName)) {
      throw const BatchFailure(
        BatchFailureCode.invalidSubject,
        field: 'name',
        detail: 'duplicate subject',
      );
    }
    final now = _clock();
    final renamed = [...subjects];
    renamed[index] = subjects[index].copyWith(name: cleanName);
    final updated = snapshot.copyWith(
      batch: snapshot.batch.copyWith(subjects: renamed, lastActivityAt: now),
    );
    await _save(uid, batchId, updated);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'subjectRenamed',
    );
  }

  @override
  Future<void> deleteSubject(
    String uid,
    String batchId,
    String subjectId,
  ) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.manageSubjects);
    final subjects = snapshot.batch.subjects;
    final index = subjects.indexWhere((item) => item.id == subjectId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'subjectId');
    }
    if (snapshot.resources.any((item) => item.subjectId == subjectId)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'subjectId',
        detail: 'subject still has resources',
      );
    }
    final now = _clock();
    final remaining = [...subjects]..removeAt(index);
    final renumbered = <BatchSubject>[
      for (var i = 0; i < remaining.length; i++)
        remaining[i].copyWith(order: i),
    ];
    final updated = snapshot.copyWith(
      batch: snapshot.batch.copyWith(subjects: renumbered, lastActivityAt: now),
    );
    await _save(uid, batchId, updated);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'subjectDeleted',
    );
  }

  @override
  Future<InviteCodeState> rotateCode(String uid, String batchId) async {
    final snapshot = await _authorize(
      uid,
      batchId,
      BatchAction.rotateInviteCode,
    );
    final now = _clock();
    final code = _newCode(uid);
    final state = InviteCodeState(
      code: code,
      createdAt: now,
      rotatedAt: now,
      rotationCount: snapshot.batch.codeState.rotationCount + 1,
    );
    final updated = snapshot.copyWith(
      batch: snapshot.batch.copyWith(codeState: state, lastActivityAt: now),
    );
    await _save(uid, batchId, updated);
    await _rememberCode(uid, code);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'codeRotated',
    );
    return state;
  }

  @override
  Future<InviteCodeState> revokeCode(String uid, String batchId) async {
    final snapshot = await _authorize(
      uid,
      batchId,
      BatchAction.revokeInviteCode,
    );
    final current = snapshot.batch.codeState;
    if (!current.isActive) return current;
    final now = _clock();
    final state = InviteCodeState(
      code: current.code,
      createdAt: current.createdAt,
      rotatedAt: current.rotatedAt,
      revokedAt: now,
      rotationCount: current.rotationCount,
    );
    final updated = snapshot.copyWith(
      batch: snapshot.batch.copyWith(codeState: state, lastActivityAt: now),
    );
    await _save(uid, batchId, updated);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'codeRevoked',
    );
    return state;
  }

  @override
  Future<void> deleteBatch(String uid, String batchId) async {
    // Building the directory validates both segments.
    files.batchDir(uid, batchId);
    final store = BatchStore(directory: files.batchDir(uid, batchId));
    final load = await store.batch.load();
    if (load.isUsable) {
      final membership = _membershipOf(load.value!, uid);
      if (membership == null ||
          !BatchAccess.can(membership.role, BatchAction.deleteBatch)) {
        throw const BatchFailure(BatchFailureCode.notAuthorized);
      }
    } else if (load.status == DocumentLoadStatus.missing &&
        !await files.batchDir(uid, batchId).exists()) {
      // Nothing to delete, but keep the index consistent.
      final ids = _readIndex(uid)..remove(batchId);
      await _writeIndex(uid, ids);
      throw const BatchFailure(BatchFailureCode.notFound);
    }
    // A corrupt or newer-schema batch is still deletable by the account that
    // owns the directory; the card offers that recovery path.
    await files.deleteBatch(uid: uid, batchId: batchId);
    final ids = _readIndex(uid)..remove(batchId);
    await _writeIndex(uid, ids);
  }

  // ----------------------------------------------------------------- helpers

  Future<BatchSnapshot> _authorize(
    String uid,
    String batchId,
    BatchAction action,
  ) async {
    final snapshot = await loadBatch(uid, batchId);
    final membership = _membershipOf(snapshot, uid);
    if (membership == null || !BatchAccess.can(membership.role, action)) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    return snapshot;
  }

  Future<void> _save(String uid, String batchId, BatchSnapshot snapshot) async {
    final store = BatchStore(directory: files.batchDir(uid, batchId));
    await store.batch.save(snapshot);
  }

  Membership? _membershipOf(BatchSnapshot snapshot, String uid) {
    for (final member in snapshot.members) {
      if (member.uid == uid) return member;
    }
    return null;
  }

  Future<void> _appendAudit({
    required BatchStore store,
    required String batchId,
    required String actorUid,
    required String action,
  }) async {
    try {
      final load = await store.audit.load();
      final entries = load.isUsable ? [...load.value!] : <AuditEntry>[];
      entries.add(
        AuditEntry(
          id: newEntityId('audit'),
          batchId: batchId,
          actorUid: actorUid,
          action: action,
          at: _clock(),
        ),
      );
      final capped = entries.length > auditCap
          ? entries.sublist(entries.length - auditCap)
          : entries;
      await store.audit.save(capped);
    } on BatchFailure {
      // The audit trail is best-effort; failing it must not undo a command
      // that already succeeded.
    }
  }

  String _newCode(String uid) {
    final hashes = _readCodeHashes(uid).toSet();
    return _codes.generateUniqueWhere(
      isTaken: (code) => hashes.contains(BatchCodeService.codeHash(code)),
    );
  }

  Future<void> _rememberCode(String uid, String code) async {
    final hashes = _readCodeHashes(uid);
    final hash = BatchCodeService.codeHash(code);
    if (!hashes.contains(hash)) hashes.add(hash);
    final capped = hashes.length > codeLedgerCap
        ? hashes.sublist(hashes.length - codeLedgerCap)
        : hashes;
    await store.setString(_codeLedgerKey(uid), jsonEncode({'hashes': capped}));
  }

  List<String> _readCodeHashes(String uid) {
    final raw = store.getString(_codeLedgerKey(uid));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      final list = decoded['hashes'];
      if (list is! List) return [];
      return [...list.whereType<String>()];
    } catch (_) {
      return [];
    }
  }

  Future<void> _addToIndex(String uid, String batchId) async {
    final ids = _readIndex(uid);
    if (!ids.contains(batchId)) ids.add(batchId);
    await _writeIndex(uid, ids);
  }

  List<String> _readIndex(String uid) {
    final raw = store.getString(_indexKey(uid));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      final list = decoded['ids'];
      if (list is! List) return [];
      final ids = <String>[];
      for (final value in list.whereType<String>()) {
        if (_batchIdPattern.hasMatch(value) && !ids.contains(value)) {
          ids.add(value);
        }
      }
      return ids;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeIndex(String uid, List<String> ids) {
    return store.setString(_indexKey(uid), jsonEncode({'ids': ids}));
  }

  String _indexKey(String uid) => 'batches.index.v1.$uid';
  String _codeLedgerKey(String uid) => 'batches.codes.v1.$uid';

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _normalizeBatchName(String name) {
    final trimmed = name.trim();
    if (trimmed.runes.length < 2 ||
        trimmed.runes.length > maxBatchNameLength ||
        _hasControl(trimmed)) {
      throw const BatchFailure(BatchFailureCode.invalidName, field: 'name');
    }
    return trimmed;
  }

  String _normalizeSubjectName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed.runes.length > maxSubjectNameLength ||
        _hasControl(trimmed)) {
      throw const BatchFailure(BatchFailureCode.invalidSubject, field: 'name');
    }
    return trimmed;
  }

  List<String> _normalizeSubjects(List<String> subjects) {
    if (subjects.isEmpty || subjects.length > maxSubjects) {
      throw const BatchFailure(
        BatchFailureCode.invalidSubject,
        field: 'subjects',
      );
    }
    final seen = <String>{};
    final result = <String>[];
    for (final raw in subjects) {
      final name = _normalizeSubjectName(raw);
      final key = name.toLowerCase();
      if (!seen.add(key)) {
        throw const BatchFailure(
          BatchFailureCode.invalidSubject,
          field: 'subjects',
          detail: 'duplicate subject',
        );
      }
      result.add(name);
    }
    return result;
  }

  bool _hasSubjectNamed(List<BatchSubject> subjects, String name) {
    final key = name.toLowerCase();
    return subjects.any((item) => item.name.toLowerCase() == key);
  }

  bool _hasControl(String value) =>
      value.runes.any((rune) => rune < 0x20 || rune == 0x7F);
}
