/// The on-device batch repository.
library;

import 'dart:convert';
import 'dart:io';

import '../../models/batch.dart';
import '../../models/batch_chat.dart';
import '../../models/batch_resource.dart';
import '../../models/batch_schedule.dart';
import '../key_value_store.dart';
import 'batch_access.dart';
import 'batch_code_service.dart';
import 'batch_failure.dart';
import 'batch_file_store.dart';
import 'batch_ids.dart';
import 'batch_repository.dart';
import 'batch_resource_paths.dart';
import 'batch_store.dart';
import 'chat_store.dart';
import 'document_store.dart';
import 'schedule_paths.dart';

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

  static const int maxSubjects = 30;
  static const int maxSubjectNameLength = 40;
  static const int maxBatchNameLength = 60;
  static const int maxResourceTitleLength = 120;
  static const int maxNoteChars = 20000;
  static const int auditCap = 200;
  static const int codeLedgerCap = 200;

  static final RegExp _batchIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final RegExp _entityIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

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

  /// Finds the local batch that owns [code] without changing any membership.
  ///
  /// Only the caller's own workspace is scanned, so this can never reveal
  /// another account's batches. A malformed code is a plain miss; callers
  /// distinguish format errors before calling.
  Future<CodeMatch> lookupCode(String uid, String code) async {
    final normalized = BatchCodeService.normalize(code);
    if (normalized == null) return const CodeMatch.none();

    List<String> onDisk;
    try {
      onDisk = await files.listBatchDirectories(uid);
    } on FileSystemException {
      throw const BatchFailure(
        BatchFailureCode.corruptStore,
        detail: 'batch directory listing failed',
      );
    }
    final ordered = <String>[];
    final seen = <String>{};
    for (final id in [..._readIndex(uid), ...onDisk]) {
      if (_batchIdPattern.hasMatch(id) && seen.add(id)) ordered.add(id);
    }

    for (final batchId in ordered) {
      final store = BatchStore(directory: files.batchDir(uid, batchId));
      final load = await store.batch.load();
      if (!load.isUsable) continue;
      final state = load.value!.batch.codeState;
      if (state.code != normalized) continue;
      if (state.isActive) return CodeMatch.active(load.value!);
      return const CodeMatch.revoked();
    }
    return const CodeMatch.none();
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
    BatchSettings settings = const BatchSettings(),
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
      settings: settings,
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
    String subjectId, {
    String? moveToSubjectId,
    bool deleteResources = false,
  }) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.manageSubjects);
    final subjects = snapshot.batch.subjects;
    final index = subjects.indexWhere((item) => item.id == subjectId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'subjectId');
    }
    final affected = snapshot.resources
        .where((item) => item.subjectId == subjectId)
        .toList();
    if (affected.isNotEmpty) {
      if (moveToSubjectId == null && !deleteResources) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'subjectId',
          detail: 'subject still has resources',
        );
      }
      if (moveToSubjectId != null &&
          (moveToSubjectId == subjectId ||
              !subjects.any((item) => item.id == moveToSubjectId))) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'moveToSubjectId',
        );
      }
    }
    final now = _clock();
    final remaining = [...subjects]..removeAt(index);
    final renumbered = <BatchSubject>[
      for (var i = 0; i < remaining.length; i++)
        remaining[i].copyWith(order: i),
    ];
    final resources = moveToSubjectId != null
        ? [
            for (final item in snapshot.resources)
              item.subjectId == subjectId
                  ? item.copyWith(subjectId: moveToSubjectId)
                  : item,
          ]
        : [
            for (final item in snapshot.resources)
              if (item.subjectId != subjectId) item,
          ];
    final updated = snapshot.copyWith(
      batch: snapshot.batch.copyWith(
        subjects: renumbered,
        lastActivityAt: now,
      ),
      resources: resources,
    );
    await _save(uid, batchId, updated);
    if (moveToSubjectId == null) {
      for (final resource in affected) {
        await _deleteResourceFiles(uid, batchId, resource);
      }
    }
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'subjectDeleted',
    );
  }

  @override
  Future<BatchResource> addResource(
    String uid,
    String batchId,
    BatchResource resource,
  ) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.uploadResource);
    final membership = _membershipOf(snapshot, uid);
    if (snapshot.batch.settings.uploadsAdminOnly &&
        membership != null &&
        membership.role != BatchRole.owner &&
        membership.role != BatchRole.admin) {
      throw const BatchFailure(
        BatchFailureCode.notAuthorized,
        detail: 'uploads are limited to admins',
      );
    }
    final clean = _validateResource(snapshot, batchId, resource);
    if (snapshot.resources.any((item) => item.id == clean.id)) {
      throw const BatchFailure(BatchFailureCode.conflict, field: 'id');
    }
    final now = _clock();
    final updated = snapshot.copyWith(
      resources: [...snapshot.resources, clean],
      batch: snapshot.batch.copyWith(lastActivityAt: now),
    );
    await _save(uid, batchId, updated);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'resourceAdded',
    );
    return clean;
  }

  @override
  Future<void> deleteResource(
    String uid,
    String batchId,
    String resourceId,
  ) async {
    final snapshot = await loadBatch(uid, batchId);
    final membership = _membershipOf(snapshot, uid);
    final index =
        snapshot.resources.indexWhere((item) => item.id == resourceId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'resourceId');
    }
    final resource = snapshot.resources[index];
    final action = resource.uploaderUid == uid
        ? BatchAction.deleteOwnResource
        : BatchAction.deleteAnyResource;
    if (membership == null || !BatchAccess.can(membership.role, action)) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    final now = _clock();
    final updated = snapshot.copyWith(
      resources: [...snapshot.resources]..removeAt(index),
      batch: snapshot.batch.copyWith(lastActivityAt: now),
    );
    await _save(uid, batchId, updated);
    await _deleteResourceFiles(uid, batchId, resource);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'resourceDeleted',
    );
  }

  @override
  Future<BatchResource> setStarred(
    String uid,
    String batchId,
    String resourceId,
    bool starred,
  ) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.starResource);
    final index =
        snapshot.resources.indexWhere((item) => item.id == resourceId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'resourceId');
    }
    final resource = snapshot.resources[index];
    final stars = {...resource.starredBy};
    if (starred) {
      stars.add(uid);
    } else {
      stars.remove(uid);
    }
    final updatedResource = resource.copyWith(starredBy: stars);
    final resources = [...snapshot.resources];
    resources[index] = updatedResource;
    await _save(uid, batchId, snapshot.copyWith(resources: resources));
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: starred ? 'resourceStarred' : 'resourceUnstarred',
    );
    return updatedResource;
  }

  // --------------------------------------------------------------- schedules

  static const int maxScheduleEntries = 100;
  static const int maxScheduleWarnings = 20;
  static const int maxScheduleTitleLength = 120;
  static const int maxScheduleNoteLength = 120;
  static const int maxScheduleWarningLength = 200;

  @override
  Future<List<TimetableDraft>> loadSchedules(
    String uid,
    String batchId,
  ) async {
    await _authorize(uid, batchId, BatchAction.viewSchedules);
    final load = await BatchStore(
      directory: files.batchDir(uid, batchId),
    ).schedules.load();
    if (!load.isUsable && !load.isMissing) {
      throw load.failure ??
          const BatchFailure(
            BatchFailureCode.corruptStore,
            detail: 'schedule document unreadable',
          );
    }
    final drafts = [...?load.value]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(drafts);
  }

  @override
  Future<TimetableDraft> saveScheduleDraft(
    String uid,
    String batchId,
    TimetableDraft draft,
  ) async {
    if (draft.batchId != batchId) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'batchId',
      );
    }
    final store = BatchStore(directory: files.batchDir(uid, batchId));
    final load = await store.schedules.load();
    if (!load.isUsable && !load.isMissing) {
      throw load.failure ??
          const BatchFailure(
            BatchFailureCode.corruptStore,
            detail: 'schedule document unreadable',
          );
    }
    final drafts = [...?load.value];
    final index = drafts.indexWhere((item) => item.id == draft.id);
    final snapshot = await _authorize(
      uid,
      batchId,
      index < 0 ? BatchAction.importTimetable : BatchAction.editTimetable,
    );
    final clean = _validateScheduleDraft(snapshot, batchId, draft);
    final now = _clock();
    final createdAt = index < 0
        ? (draft.createdAt.millisecondsSinceEpoch == 0 ? now : draft.createdAt)
        : drafts[index].createdAt;
    final saved = TimetableDraft(
      id: clean.id,
      batchId: clean.batchId,
      sourceImageFileName: clean.sourceImageFileName,
      ocrEngine: clean.ocrEngine,
      status: clean.status,
      createdAt: createdAt,
      updatedAt: now,
      entries: clean.entries,
      warnings: clean.warnings,
    );
    if (index < 0) {
      drafts.add(saved);
    } else {
      drafts[index] = saved;
    }
    await store.schedules.save(drafts);
    await _appendAudit(
      store: store,
      batchId: batchId,
      actorUid: uid,
      action: index < 0 ? 'scheduleSaved' : 'scheduleUpdated',
    );
    return saved;
  }

  @override
  Future<TimetableDraft> publishScheduleDraft(
    String uid,
    String batchId,
    String draftId,
  ) async {
    await _authorize(uid, batchId, BatchAction.editTimetable);
    final store = BatchStore(directory: files.batchDir(uid, batchId));
    final load = await store.schedules.load();
    if (!load.isUsable && !load.isMissing) {
      throw load.failure ??
          const BatchFailure(
            BatchFailureCode.corruptStore,
            detail: 'schedule document unreadable',
          );
    }
    final drafts = [...?load.value];
    final index = drafts.indexWhere((item) => item.id == draftId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'draftId');
    }
    final draft = drafts[index];
    // A published timetable must be usable by a reader without guessing: an
    // unfinished row stays a draft.
    if (draft.entries.isEmpty ||
        draft.entries.any((entry) => !entry.isComplete)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'entries',
        detail: 'incomplete rows',
      );
    }
    final published = draft.copyWith(
      status: TimetableDraftStatus.published,
      updatedAt: _clock(),
    );
    drafts[index] = published;
    await store.schedules.save(drafts);
    await _appendAudit(
      store: store,
      batchId: batchId,
      actorUid: uid,
      action: 'schedulePublished',
    );
    return published;
  }

  @override
  Future<void> deleteScheduleDraft(
    String uid,
    String batchId,
    String draftId,
  ) async {
    await _authorize(uid, batchId, BatchAction.editTimetable);
    final store = BatchStore(directory: files.batchDir(uid, batchId));
    final load = await store.schedules.load();
    if (!load.isUsable && !load.isMissing) {
      throw load.failure ??
          const BatchFailure(
            BatchFailureCode.corruptStore,
            detail: 'schedule document unreadable',
          );
    }
    final drafts = [...?load.value];
    final index = drafts.indexWhere((item) => item.id == draftId);
    if (index < 0) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'draftId');
    }
    final removed = drafts.removeAt(index);
    await store.schedules.save(drafts);
    final imagePath = SchedulePaths.storedImagePath(
      removed.sourceImageFileName,
    );
    if (imagePath != null) {
      try {
        await files.deleteFile(
          uid: uid,
          batchId: batchId,
          relativePath: imagePath,
        );
      } on BatchFailure {
        // The row is gone; an orphan photo is the only cost.
      }
    }
    await _appendAudit(
      store: store,
      batchId: batchId,
      actorUid: uid,
      action: 'scheduleDeleted',
    );
  }

  // -------------------------------------------------------------------- chat

  ChatStore _chatStore(String uid, String batchId) => ChatStore(
        directory: files.batchDir(uid, batchId),
        clock: _clock,
      );

  @override
  Future<ChatPage> loadChat(
    String uid,
    String batchId, {
    ChatCursor? before,
    int limit = 30,
  }) async {
    await _authorize(uid, batchId, BatchAction.viewChat);
    return _chatStore(uid, batchId).page(before: before, limit: limit);
  }

  @override
  Future<ChatMessage> sendChatMessage(
    String uid,
    String batchId,
    ChatMessage message,
  ) async {
    await _authorize(uid, batchId, BatchAction.sendMessage);
    if (message.authorUid != uid || message.batchId != batchId) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    if (message.kind == ChatMessageKind.voice) {
      final exists = await files.fileExists(
        uid: uid,
        batchId: batchId,
        relativePath: ChatStore.voicePath(message.id),
      );
      if (!exists) {
        throw const BatchFailure(
          BatchFailureCode.missingFile,
          field: 'voice',
        );
      }
    }
    final saved = await _chatStore(uid, batchId).append(message);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'chatMessageSent',
    );
    return saved;
  }

  @override
  Future<ChatMessage> editChatMessage(
    String uid,
    String batchId,
    String messageId,
    String text,
  ) async {
    await _authorize(uid, batchId, BatchAction.sendMessage);
    final store = _chatStore(uid, batchId);
    final existing = await store.find(messageId);
    if (existing == null) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    if (existing.authorUid != uid) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    final updated = await store.edit(messageId, text);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'chatMessageEdited',
    );
    return updated;
  }

  @override
  Future<ChatMessage> deleteChatMessage(
    String uid,
    String batchId,
    String messageId,
  ) async {
    final snapshot = await _authorize(uid, batchId, BatchAction.viewChat);
    final membership = _membershipOf(snapshot, uid);
    final store = _chatStore(uid, batchId);
    final existing = await store.find(messageId);
    if (existing == null) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'messageId');
    }
    final action = existing.authorUid == uid
        ? BatchAction.deleteOwnMessage
        : BatchAction.deleteAnyMessage;
    if (membership == null || !BatchAccess.can(membership.role, action)) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    final deleted = await store.delete(messageId);
    if (existing.kind == ChatMessageKind.voice) {
      try {
        await files.deleteFile(
          uid: uid,
          batchId: batchId,
          relativePath: ChatStore.voicePath(existing.id),
        );
      } on BatchFailure {
        // The tombstone stands even when the file was already gone.
      }
    }
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: 'chatMessageDeleted',
    );
    return deleted;
  }

  @override
  Future<ChatMessage> reactToChatMessage(
    String uid,
    String batchId,
    String messageId,
    String emoji,
    bool reacted,
  ) async {
    await _authorize(uid, batchId, BatchAction.react);
    return _chatStore(uid, batchId).react(messageId, emoji, uid, reacted);
  }

  @override
  Future<ChatMessage> pinChatMessage(
    String uid,
    String batchId,
    String messageId,
    bool pinned,
  ) async {
    await _authorize(uid, batchId, BatchAction.pinMessage);
    final updated = await _chatStore(uid, batchId).setPinned(messageId, pinned);
    await _appendAudit(
      store: BatchStore(directory: files.batchDir(uid, batchId)),
      batchId: batchId,
      actorUid: uid,
      action: pinned ? 'chatMessagePinned' : 'chatMessageUnpinned',
    );
    return updated;
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

  /// Moves one batch directory from the guest workspace into an account.
  ///
  /// The directory rename is the atomic part: if the rewritten document cannot
  /// be saved, the whole directory is renamed back. Re-running with the same
  /// ids is safe: an already-claimed target is adopted and both indexes are
  /// repaired.
  Future<void> claimBatch({
    required String guestUid,
    required String accountUid,
    required String batchId,
  }) async {
    if (guestUid.isEmpty || accountUid.isEmpty || guestUid == accountUid) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'uid',
      );
    }
    final source = files.batchDir(guestUid, batchId);
    final target = files.batchDir(accountUid, batchId);
    final targetStore = BatchStore(directory: target);

    if (await target.exists()) {
      final existing = await targetStore.batch.load();
      if (existing.isUsable && existing.value!.batch.ownerUid == accountUid) {
        await _finishClaim(
          guestUid: guestUid,
          accountUid: accountUid,
          batchId: batchId,
          codeState: existing.value!.batch.codeState,
        );
        return;
      }
      throw const BatchFailure(
        BatchFailureCode.conflict,
        detail: 'account already has a batch with this id',
      );
    }

    if (!await source.exists()) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'batchId');
    }
    final sourceLoad = await BatchStore(directory: source).batch.load();
    if (!sourceLoad.isUsable) {
      throw const BatchFailure(
        BatchFailureCode.corruptStore,
        detail: 'claimed batch document unreadable',
      );
    }
    final snapshot = sourceLoad.value!;
    if (snapshot.batch.ownerUid != guestUid) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }
    final membership = _membershipOf(snapshot, guestUid);
    if (membership == null || membership.role != BatchRole.owner) {
      throw const BatchFailure(BatchFailureCode.notAuthorized);
    }

    final now = _clock();
    final claimed = snapshot.copyWith(
      batch: snapshot.batch.copyWith(ownerUid: accountUid, lastActivityAt: now),
      members: [
        for (final member in snapshot.members)
          if (member.uid == guestUid)
            Membership(
              batchId: member.batchId,
              uid: accountUid,
              displayName: member.displayName,
              role: member.role,
              joinedAt: member.joinedAt,
              removedAt: member.removedAt,
            )
          else
            member,
      ],
    );

    try {
      final accountDir = files.userDir(accountUid);
      if (!await accountDir.exists()) {
        await accountDir.create(recursive: true);
      }
      await source.rename(target.path);
    } on FileSystemException {
      throw const BatchFailure(
        BatchFailureCode.claimFailed,
        detail: 'batch directory move failed',
      );
    }

    try {
      await targetStore.batch.save(claimed);
    } catch (error) {
      try {
        await target.rename(source.path);
      } on FileSystemException {
        throw const BatchFailure(
          BatchFailureCode.claimFailed,
          detail: 'claim save and rollback both failed',
        );
      }
      if (error is BatchFailure) rethrow;
      throw const BatchFailure(
        BatchFailureCode.claimFailed,
        detail: 'claim save failed',
      );
    }

    await _rewriteClaimAudit(
      store: targetStore,
      batchId: batchId,
      guestUid: guestUid,
      accountUid: accountUid,
    );
    await _finishClaim(
      guestUid: guestUid,
      accountUid: accountUid,
      batchId: batchId,
      codeState: claimed.batch.codeState,
    );
  }

  Future<void> _finishClaim({
    required String guestUid,
    required String accountUid,
    required String batchId,
    required InviteCodeState codeState,
  }) async {
    await _addToIndex(accountUid, batchId);
    final guestIds = _readIndex(guestUid)..remove(batchId);
    await _writeIndex(guestUid, guestIds);
    if (codeState.isActive) {
      await _rememberCode(accountUid, codeState.code);
    }
  }

  Future<void> _rewriteClaimAudit({
    required BatchStore store,
    required String batchId,
    required String guestUid,
    required String accountUid,
  }) async {
    try {
      final load = await store.audit.load();
      final entries = load.isUsable ? [...load.value!] : <AuditEntry>[];
      final rewritten = <AuditEntry>[
        for (final entry in entries)
          if (entry.actorUid == guestUid)
            AuditEntry(
              id: entry.id,
              batchId: entry.batchId,
              actorUid: accountUid,
              action: entry.action,
              at: entry.at,
              detail: entry.detail,
            )
          else
            entry,
        AuditEntry(
          id: newEntityId('audit'),
          batchId: batchId,
          actorUid: accountUid,
          action: 'batchClaimed',
          at: _clock(),
        ),
      ];
      final capped = rewritten.length > auditCap
          ? rewritten.sublist(rewritten.length - auditCap)
          : rewritten;
      await store.audit.save(capped);
    } on BatchFailure {
      // The move is already atomic and committed; a best-effort audit must not
      // turn it into a reported failure.
    }
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

  /// Validates a timetable draft before it enters `schedules.json`.
  ///
  /// A draft may keep a row whose end time is missing (the parser reports it
  /// as uncertain rather than guessing), but the row's values must still be
  /// addressable and inside a day. Publishing applies the stricter check.
  TimetableDraft _validateScheduleDraft(
    BatchSnapshot snapshot,
    String batchId,
    TimetableDraft draft,
  ) {
    if (draft.batchId != batchId) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'batchId',
      );
    }
    if (!_entityIdPattern.hasMatch(draft.id)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'draftId',
      );
    }
    final source = draft.sourceImageFileName.trim();
    if (source.isNotEmpty && SchedulePaths.storedImagePath(source) == null) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'sourceImageFileName',
      );
    }
    if (draft.entries.length > maxScheduleEntries) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'entries',
      );
    }

    final subjectIds = {
      for (final subject in snapshot.batch.subjects) subject.id,
    };
    final seen = <String>{};
    final entries = <TimetableEntry>[];
    for (final entry in draft.entries) {
      if (!_entityIdPattern.hasMatch(entry.id) || !seen.add(entry.id)) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'entryId',
        );
      }
      if (entry.dayOfWeek < DateTime.monday ||
          entry.dayOfWeek > DateTime.sunday ||
          entry.startMinutes < 0 ||
          entry.startMinutes >= 24 * 60 ||
          entry.endMinutes < 0 ||
          entry.endMinutes > 24 * 60 ||
          entry.endMinutes < entry.startMinutes) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'times',
        );
      }
      final title = _cleanScheduleLine(entry.title);
      if (title.isEmpty ||
          title.runes.length > maxScheduleTitleLength ||
          _hasControl(title)) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'title',
        );
      }
      final room = _cleanScheduleLine(entry.room);
      final teacher = _cleanScheduleLine(entry.teacher);
      if (room.runes.length > maxScheduleNoteLength ||
          teacher.runes.length > maxScheduleNoteLength) {
        throw const BatchFailure(
          BatchFailureCode.validationFailed,
          field: 'details',
        );
      }
      if (entry.subjectId != null && !subjectIds.contains(entry.subjectId)) {
        throw const BatchFailure(BatchFailureCode.notFound, field: 'subjectId');
      }
      final uncertain = <String>[];
      for (final field in entry.uncertainFields) {
        final clean = _cleanScheduleLine(field);
        if (clean.isEmpty || clean.runes.length > 40) continue;
        uncertain.add(clean);
      }
      entries.add(
        entry.copyWith(
          title: title,
          room: room,
          teacher: teacher,
          uncertainFields: List.unmodifiable(uncertain),
        ),
      );
    }

    final warnings = <String>[];
    for (final raw in draft.warnings.take(maxScheduleWarnings)) {
      final clean = _cleanScheduleLine(raw);
      if (clean.isEmpty) continue;
      warnings.add(
        clean.runes.length > maxScheduleWarningLength
            ? String.fromCharCodes(
                clean.runes.take(maxScheduleWarningLength),
              ).trimRight()
            : clean,
      );
    }

    if (draft.status == TimetableDraftStatus.published &&
        entries.any((entry) => !entry.isComplete)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'entries',
        detail: 'incomplete rows',
      );
    }

    return TimetableDraft(
      id: draft.id,
      batchId: draft.batchId,
      sourceImageFileName: source,
      ocrEngine: draft.ocrEngine,
      status: draft.status,
      createdAt: draft.createdAt,
      updatedAt: draft.updatedAt,
      entries: List.unmodifiable(entries),
      warnings: List.unmodifiable(warnings),
    );
  }

  /// Collapses whitespace and drops control characters from one stored line.
  static String _cleanScheduleLine(String raw) => raw
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Validates a resource before it enters the batch document.
  ///
  /// The importer has already copied the file; this re-checks the facts the
  /// document will rely on so a malformed record can never be indexed.
  BatchResource _validateResource(
    BatchSnapshot snapshot,
    String batchId,
    BatchResource resource,
  ) {
    if (resource.batchId != batchId) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'batchId',
      );
    }
    if (!_entityIdPattern.hasMatch(resource.id)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'resourceId',
      );
    }
    if (!snapshot.batch.subjects.any((item) => item.id == resource.subjectId)) {
      throw const BatchFailure(BatchFailureCode.notFound, field: 'subjectId');
    }
    final title = resource.title.trim();
    if (title.isEmpty ||
        title.runes.length > maxResourceTitleLength ||
        _hasControl(title)) {
      throw const BatchFailure(
        BatchFailureCode.validationFailed,
        field: 'title',
      );
    }
    final extension = BatchResourcePaths.extensionOf(resource.fileName);
    switch (resource.kind) {
      case ResourceKind.pdf:
        if (extension != 'pdf' ||
            resource.fileName.length > 255 ||
            resource.sizeBytes <= 0 ||
            resource.sizeBytes > BatchFileStore.maxPdfBytes) {
          throw const BatchFailure(
            BatchFailureCode.validationFailed,
            field: 'file',
          );
        }
        return resource.copyWith(title: title);
      case ResourceKind.audio:
        if (extension == null ||
            !BatchResourcePaths.isAudioExtension(extension) ||
            resource.fileName.length > 255 ||
            resource.sizeBytes <= 0 ||
            resource.sizeBytes > BatchFileStore.maxImportBytes) {
          throw const BatchFailure(
            BatchFailureCode.validationFailed,
            field: 'file',
          );
        }
        return resource.copyWith(title: title);
      case ResourceKind.note:
        final note = resource.note.trim();
        if (note.isEmpty || note.runes.length > maxNoteChars) {
          throw const BatchFailure(
            BatchFailureCode.validationFailed,
            field: 'note',
          );
        }
        return resource.copyWith(title: title, note: note);
    }
  }

  /// Removes the files that belonged to [resource].
  ///
  /// The index entry is already gone, so a failure here leaves an orphan file
  /// rather than a broken card; it is never reported as a failed delete.
  Future<void> _deleteResourceFiles(
    String uid,
    String batchId,
    BatchResource resource,
  ) async {
    final filePath = BatchResourcePaths.filePath(resource);
    final paths = <String>[
      if (filePath != null) filePath,
      BatchResourcePaths.thumbnailPath(resource.id),
      if (resource.sha256.isNotEmpty)
        BatchResourcePaths.textCachePath(resource.sha256),
    ];
    for (final path in paths) {
      try {
        await files.deleteFile(uid: uid, batchId: batchId, relativePath: path);
      } on BatchFailure {
        // Best-effort cleanup; the batch stays consistent without it.
      }
    }
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
    if (subjects.length > maxSubjects) {
      throw const BatchFailure(
        BatchFailureCode.invalidSubject,
        field: 'subjects',
      );
    }
    final seen = <String>{};
    final result = <String>[];
    for (final raw in subjects) {
      final name = _normalizeSubjectName(raw);
      final key = _subjectKey(name);
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
    final key = _subjectKey(name);
    return subjects.any((item) => _subjectKey(item.name) == key);
  }

  /// Subject names are unique regardless of case or spacing.
  static String _subjectKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  bool _hasControl(String value) =>
      value.runes.any((rune) => rune < 0x20 || rune == 0x7F);
}
