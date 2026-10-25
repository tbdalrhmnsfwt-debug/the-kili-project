/// Study-tool state: the local extractor, the generated artifacts and the
/// per-resource controller the hub drives.
///
/// Nothing here contacts a server. The remote-AI path is represented by
/// `BlockedCapability.remoteAi` and is never called.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/batches/batch_failure.dart';
import '../core/batches/evidence_validator.dart';
import '../core/batches/study_attempt_store.dart';
import '../core/batches/study_report_store.dart';
import '../core/batches/study_source_extractor.dart';
import '../core/batches/study_tools_engine.dart';
import '../models/batch_resource.dart';
import '../models/study_source.dart';
import 'app_providers.dart';
import 'batch_providers.dart';

/// The batch and PDF a study screen is about.
typedef StudyResourceArgs = ({String batchId, String resourceId});

String _currentUid(Ref ref) => ref.watch(authUserProvider)?.uid ?? '';

final studyExtractorProvider = Provider<StudySourceExtractor>((ref) {
  return StudySourceExtractor(files: ref.watch(batchFileStoreProvider));
});

final studyAttemptStoreProvider = Provider<StudyAttemptStore>((ref) {
  return StudyAttemptStore(files: ref.watch(batchFileStoreProvider));
});

final studyReportStoreProvider = Provider<StudyReportStore>((ref) {
  return StudyReportStore(files: ref.watch(batchFileStoreProvider));
});

final studyEngineProvider = Provider<StudyToolsEngine>((ref) {
  return const StudyToolsEngine();
});

/// The PDF a study screen may open, after the batch repository's access check.
final studyResourceProvider = FutureProvider.autoDispose
    .family<BatchResource, StudyResourceArgs>((ref, args) async {
  final snapshot = await ref.watch(batchDetailProvider(args.batchId).future);
  for (final resource in snapshot.resources) {
    if (resource.id != args.resourceId) continue;
    if (resource.kind != ResourceKind.pdf) {
      throw const BatchFailure(BatchFailureCode.unsupportedFile);
    }
    return resource;
  }
  throw const BatchFailure(BatchFailureCode.notFound);
});

/// The cached source text, or null when this PDF was never extracted.
final studyDocumentProvider = FutureProvider.autoDispose
    .family<SourceDocument?, StudyResourceArgs>((ref, args) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return null;
  final extractor = ref.watch(studyExtractorProvider);
  final resource = await ref.watch(studyResourceProvider(args).future);
  return extractor.cached(uid: uid, resource: resource);
});

/// Deterministic local test questions for one extracted PDF.
final studyTestProvider = FutureProvider.autoDispose
    .family<List<StudyQuestion>, StudyResourceArgs>((ref, args) async {
  final document = await ref.watch(studyDocumentProvider(args).future);
  if (document == null || !document.hasUsableText) return const [];
  return ref.watch(studyEngineProvider).test(document);
});

/// Definitions, dates, numbers and steps, each with its page.
final studyBankProvider = FutureProvider.autoDispose
    .family<StudyBank?, StudyResourceArgs>((ref, args) async {
  final document = await ref.watch(studyDocumentProvider(args).future);
  if (document == null || !document.hasUsableText) return null;
  return ref.watch(studyEngineProvider).bank(document);
});

/// The heading/term hierarchy with page references.
final studyMindMapProvider = FutureProvider.autoDispose
    .family<StudyMindMap?, StudyResourceArgs>((ref, args) async {
  final document = await ref.watch(studyDocumentProvider(args).future);
  if (document == null || !document.hasUsableText) return null;
  return ref.watch(studyEngineProvider).mindMap(document);
});

/// The saved attempt for one PDF, shown above the test when present.
final studyAttemptProvider = FutureProvider.autoDispose
    .family<StudyAttempt?, StudyResourceArgs>((ref, args) async {
  final uid = _currentUid(ref);
  if (uid.isEmpty) return null;
  return ref.watch(studyAttemptStoreProvider).load(
        uid: uid,
        batchId: args.batchId,
        resourceId: args.resourceId,
      );
});

/// The cached document plus the job and failure the hub renders.
class StudyToolsState {
  const StudyToolsState({
    this.document,
    this.job,
    this.loading = false,
    this.failure,
  });

  final SourceDocument? document;
  final StudyJob? job;
  final bool loading;
  final BatchFailure? failure;

  bool get isExtracting => job?.isActive ?? false;

  bool get hasDocument => document != null;

  StudyToolsState copyWith({
    SourceDocument? document,
    StudyJob? job,
    bool? loading,
    BatchFailure? failure,
    bool clearFailure = false,
  }) =>
      StudyToolsState(
        document: document ?? this.document,
        job: job ?? this.job,
        loading: loading ?? this.loading,
        failure: clearFailure ? null : failure ?? this.failure,
      );
}

/// Drives extraction for one PDF. The screen owns the lifetime: leaving the
/// hub disposes the controller and cancels the job between pages.
class StudyToolsController extends StateNotifier<StudyToolsState> {
  StudyToolsController({
    required this.extractor,
    required this.uid,
    required this.args,
    required this.loadResource,
    required this.onDocumentChanged,
  }) : super(const StudyToolsState());

  final StudySourceExtractor extractor;
  final String uid;
  final StudyResourceArgs args;
  final Future<BatchResource> Function() loadResource;
  final void Function() onDocumentChanged;

  bool _cancelled = false;
  bool _running = false;

  /// Reads the cache once when the hub opens; never starts extraction.
  Future<void> load() async {
    if (state.loading || state.isExtracting) return;
    state = state.copyWith(loading: true, clearFailure: true);
    try {
      final resource = await loadResource();
      if (uid.isEmpty) {
        throw const BatchFailure(BatchFailureCode.notAuthorized);
      }
      final cached = await extractor.cached(uid: uid, resource: resource);
      if (!mounted) return;
      state = state.copyWith(loading: false, document: cached);
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      state = state.copyWith(loading: false, failure: failure);
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        failure: const BatchFailure(BatchFailureCode.extractionFailed),
      );
    }
  }

  /// Extracts the PDF, or returns its cached text unless [force] is set.
  Future<void> extract({bool force = false}) async {
    if (_running || state.isExtracting) return;
    _running = true;
    _cancelled = false;
    state = state.copyWith(loading: false, clearFailure: true);
    try {
      final resource = await loadResource();
      if (uid.isEmpty) {
        throw const BatchFailure(BatchFailureCode.notAuthorized);
      }
      final document = await extractor.extract(
        uid: uid,
        resource: resource,
        force: force,
        isCancelled: () => _cancelled,
        onProgress: (job) {
          if (!mounted) return;
          state = state.copyWith(job: job);
        },
      );
      if (!mounted) return;
      state = state.copyWith(
        document: document,
        job: extractor.lastJob,
        clearFailure: true,
      );
      onDocumentChanged();
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      state = state.copyWith(job: extractor.lastJob, failure: failure);
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        job: extractor.lastJob,
        failure: const BatchFailure(BatchFailureCode.extractionFailed),
      );
    } finally {
      _running = false;
    }
  }

  /// Asks the reader to stop between pages. The UI keeps saying «بيتوقف…»
  /// until the extractor reports the job as cancelled.
  void cancel() {
    if (!state.isExtracting) return;
    _cancelled = true;
    state = state.copyWith(
      job: state.job?.copyWith(message: 'بيتوقف بعد الصفحة الحالية…'),
    );
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }
}

final studyToolsControllerProvider = StateNotifierProvider.autoDispose
    .family<StudyToolsController, StudyToolsState, StudyResourceArgs>(
  (ref, args) {
    final controller = StudyToolsController(
      extractor: ref.watch(studyExtractorProvider),
      uid: _currentUid(ref),
      args: args,
      loadResource: () => ref.read(studyResourceProvider(args).future),
      onDocumentChanged: () {
        ref.invalidate(studyDocumentProvider(args));
        ref.invalidate(studyTestProvider(args));
        ref.invalidate(studyBankProvider(args));
        ref.invalidate(studyMindMapProvider(args));
      },
    );
    unawaited(controller.load());
    return controller;
  },
);

/// The normalizer the information-bank search uses. Exposed so the screen and
/// its tests agree on one folding rule.
String Function(String) get studySearchNormalizer =>
    EvidenceValidator.normalize;
