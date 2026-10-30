/// Timetable state: imported drafts, the photo importer and its commands.
///
/// OCR and every draft stay on this device. A screen chooses a photo, this
/// controller copies it into the batch's private directory, recognises it,
/// and saves the result through the repository's access check.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/batches/batch_failure.dart';
import '../core/batches/batch_repository.dart';
import '../core/batches/schedule_notification_sink.dart';
import '../core/batches/schedule_ocr_service.dart';
import '../core/batches/schedule_reminder_service.dart';
import '../core/notification_service.dart';
import '../models/batch_schedule.dart';
import 'app_providers.dart';
import 'batch_providers.dart';

String _currentUid(Ref ref) => ref.watch(authUserProvider)?.uid ?? '';

final scheduleOcrServiceProvider = Provider<ScheduleOcrService>((ref) {
  return ScheduleOcrService(files: ref.watch(batchFileStoreProvider));
});

/// Where timetable reminders are handed to the operating system.
final scheduleReminderSinkProvider = Provider<ScheduleReminderSink>((ref) {
  return NotificationServiceScheduleSink(NotificationService.instance);
});

final scheduleReminderServiceProvider = Provider<ScheduleReminderService>((
  ref,
) {
  return ScheduleReminderService(
    repository: ref.watch(batchRepositoryProvider),
    notifications: ref.watch(scheduleReminderSinkProvider),
  );
});

/// Every draft and published timetable the reader may see, newest first.
final scheduleDraftsProvider = FutureProvider.autoDispose
    .family<List<TimetableDraft>, String>((ref, batchId) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return const [];
  return ref.watch(batchRepositoryProvider).loadSchedules(uid, batchId);
});

/// One photo import, from the queued job to the saved draft or the failure.
class ScheduleImportState {
  const ScheduleImportState({
    this.job,
    this.busy = false,
    this.failure,
    this.savedDraftId,
  });

  final ScheduleOcrJob? job;
  final bool busy;
  final BatchFailure? failure;

  /// Set once the draft is saved; the list refreshes on its own.
  final String? savedDraftId;

  bool get isWorking => busy || (job?.isActive ?? false);

  ScheduleImportState copyWith({
    ScheduleOcrJob? job,
    bool? busy,
    BatchFailure? failure,
    String? savedDraftId,
  }) =>
      ScheduleImportState(
        job: job ?? this.job,
        busy: busy ?? this.busy,
        failure: failure ?? this.failure,
        savedDraftId: savedDraftId ?? this.savedDraftId,
      );
}

/// Runs one import at a time. Leaving the screen cancels between stages.
class ScheduleImportController extends StateNotifier<ScheduleImportState> {
  ScheduleImportController({
    required this.service,
    required this.repository,
    required this.uid,
    required this.batchId,
    required this.onSaved,
  }) : super(const ScheduleImportState());

  final ScheduleOcrService service;
  final BatchRepository repository;
  final String uid;
  final String batchId;
  final void Function() onSaved;

  bool _cancelled = false;
  bool _running = false;

  /// Returns the saved draft, or null when the import failed or was refused.
  Future<TimetableDraft?> importPhoto(String sourcePath) async {
    if (_running || state.isWorking) return null;
    _running = true;
    _cancelled = false;
    state = const ScheduleImportState(busy: true);
    try {
      if (uid.isEmpty) {
        throw const BatchFailure(BatchFailureCode.notAuthorized);
      }
      final draft = await service.extract(
        uid: uid,
        batchId: batchId,
        sourcePath: sourcePath,
        isCancelled: () => _cancelled,
        onProgress: (job) {
          if (!mounted) return;
          state = state.copyWith(job: job);
        },
      );
      final saved = await repository.saveScheduleDraft(uid, batchId, draft);
      if (!mounted) return saved;
      state = ScheduleImportState(
        job: service.lastJob,
        savedDraftId: saved.id,
      );
      onSaved();
      return saved;
    } on BatchFailure catch (failure) {
      if (!mounted) return null;
      state = ScheduleImportState(
        job: service.lastJob,
        failure: failure,
      );
      return null;
    } on Object {
      if (!mounted) return null;
      state = const ScheduleImportState(
        failure: BatchFailure(BatchFailureCode.ocrFailed),
      );
      return null;
    } finally {
      _running = false;
    }
  }

  /// Asks the service to stop at its next stage boundary. Tesseract itself
  /// cannot be interrupted mid-image, so the message says what happens next.
  void cancel() {
    if (!state.isWorking) return;
    _cancelled = true;
    state = state.copyWith(
      job: state.job?.copyWith(
        message: 'بيتوقف بعد ما يخلص الخطوة الحالية…',
      ),
    );
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }
}

final scheduleImportControllerProvider = StateNotifierProvider.autoDispose
    .family<ScheduleImportController, ScheduleImportState, String>((
  ref,
  batchId,
) {
  return ScheduleImportController(
    service: ref.watch(scheduleOcrServiceProvider),
    repository: ref.watch(batchRepositoryProvider),
    uid: _currentUid(ref),
    batchId: batchId,
    onSaved: () {
      ref.invalidate(scheduleDraftsProvider(batchId));
      ref.invalidate(batchHubDataProvider(batchId));
    },
  );
});

/// Publishing and deleting, each refreshing the schedule list and the hub.
class ScheduleController {
  ScheduleController(this._ref);

  final Ref _ref;

  BatchRepository get _repository => _ref.read(batchRepositoryProvider);

  String get _uid {
    final uid = _ref.read(authUserProvider)?.uid ?? '';
    if (uid.isEmpty) throw StateError('no active account');
    return uid;
  }

  Future<TimetableDraft> saveDraft(
    String batchId,
    TimetableDraft draft,
  ) async {
    final saved = await _repository.saveScheduleDraft(_uid, batchId, draft);
    _refresh(batchId);
    return saved;
  }

  Future<TimetableDraft> publish(String batchId, String draftId) async {
    final published = await _repository.publishScheduleDraft(
      _uid,
      batchId,
      draftId,
    );
    _refresh(batchId);
    return published;
  }

  Future<void> delete(String batchId, String draftId) async {
    await _repository.deleteScheduleDraft(_uid, batchId, draftId);
    _refresh(batchId);
  }

  /// Rebuilds the device's timetable reminder queue after a change.
  Future<ScheduleReminderSyncResult> syncReminders(String batchId) {
    return _ref
        .read(scheduleReminderServiceProvider)
        .sync(uid: _uid, batchId: batchId);
  }

  void _refresh(String batchId) {
    _ref.invalidate(scheduleDraftsProvider(batchId));
    _ref.invalidate(batchHubDataProvider(batchId));
  }
}

final scheduleControllerProvider = Provider(ScheduleController.new);
