/// Turns one timetable photo into an unpublished, on-device draft.
///
/// The photo is copied into the batch's private directory, Tesseract reads it
/// locally (`ara+eng` hOCR), and the layout parser produces the rows. The
/// service never publishes and never invents a time: every row keeps the
/// uncertainty the parser reported, and the review screen decides what is
/// saved. A photo whose OCR fails is deleted again, so a failed import cannot
/// leave an orphan file behind.
library;

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

import '../../models/batch_schedule.dart';
import 'batch_failure.dart';
import 'batch_file_store.dart';
import 'batch_ids.dart';
import 'batch_resource_paths.dart';
import 'hocr_parser.dart';
import 'schedule_paths.dart';
import 'timetable_layout_parser.dart';

/// Reads the hOCR text for one image. Tests inject a fake; the app uses
/// Tesseract's bundled Arabic and English data.
typedef HocrReader = Future<String> Function(String imagePath);

enum ScheduleOcrStage {
  queued,
  copying,
  recognising,
  parsing,
  done,
  failed,
  cancelled,
}

/// One photo import, from queued to finished.
class ScheduleOcrJob {
  const ScheduleOcrJob({
    required this.stage,
    required this.message,
    required this.startedAt,
    this.finishedAt,
  });

  final ScheduleOcrStage stage;
  final String message;
  final DateTime startedAt;
  final DateTime? finishedAt;

  bool get isActive => switch (stage) {
        ScheduleOcrStage.queued ||
        ScheduleOcrStage.copying ||
        ScheduleOcrStage.recognising ||
        ScheduleOcrStage.parsing =>
          true,
        ScheduleOcrStage.done ||
        ScheduleOcrStage.failed ||
        ScheduleOcrStage.cancelled =>
          false,
      };

  ScheduleOcrJob copyWith({
    ScheduleOcrStage? stage,
    String? message,
    DateTime? finishedAt,
  }) =>
      ScheduleOcrJob(
        stage: stage ?? this.stage,
        message: message ?? this.message,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
      );
}

class ScheduleOcrService {
  ScheduleOcrService({
    required this.files,
    HocrReader? readHocr,
    this.maxImageBytes = BatchFileStore.maxImageBytes,
    DateTime Function()? clock,
  })  : readHocr = readHocr ?? _readWithTesseract,
        _clock = clock ?? DateTime.now;

  final BatchFileStore files;
  final HocrReader readHocr;
  final int maxImageBytes;
  final DateTime Function() _clock;

  /// Only these Tesseract data files are bundled with the app.
  static const String ocrLanguage = 'ara+eng';

  /// A timetable with more rows than this is not a timetable; the extra rows
  /// are dropped with a warning rather than written into one giant draft.
  static const int maxEntries = 100;

  static const int _maxWarnings = 20;

  ScheduleOcrJob? _lastJob;

  /// The most recent job, completed or not.
  ScheduleOcrJob? get lastJob => _lastJob;

  bool get isBusy => _lastJob?.isActive ?? false;

  /// Copies [sourcePath] privately, recognises it, and returns a draft whose
  /// entries are whatever the image actually printed.
  ///
  /// A second start while one import is active is refused. Cancellation is
  /// checked between stages, because Tesseract itself cannot be interrupted.
  Future<TimetableDraft> extract({
    required String uid,
    required String batchId,
    required String sourcePath,
    bool Function()? isCancelled,
    void Function(ScheduleOcrJob job)? onProgress,
  }) async {
    if (isBusy) {
      throw const BatchFailure(
        BatchFailureCode.conflict,
        detail: 'schedule OCR already running',
      );
    }

    var job = _emit(
      ScheduleOcrJob(
        stage: ScheduleOcrStage.queued,
        message: 'مستنيين صورة الجدول…',
        startedAt: _clock(),
      ),
      onProgress,
    );

    String? copiedPath;
    try {
      final extension = BatchResourcePaths.extensionOf(sourcePath);
      if (extension == null ||
          !SchedulePaths.imageExtensions.contains(extension)) {
        throw const BatchFailure(
          BatchFailureCode.unsupportedFile,
          field: 'image',
        );
      }
      if (isCancelled?.call() ?? false) {
        throw const BatchFailure(BatchFailureCode.cancelled);
      }

      final draftId = newEntityId('schedule');
      final relativePath = SchedulePaths.imagePath(draftId, extension);
      job = _emit(
        job.copyWith(
          stage: ScheduleOcrStage.copying,
          message: 'بنحفظ صورة الجدول على الجهاز…',
        ),
        onProgress,
      );
      await files.copyFile(
        uid: uid,
        batchId: batchId,
        relativePath: relativePath,
        sourcePath: sourcePath,
        maxBytes: maxImageBytes,
      );
      copiedPath = relativePath;

      if (isCancelled?.call() ?? false) {
        throw const BatchFailure(BatchFailureCode.cancelled);
      }

      job = _emit(
        job.copyWith(
          stage: ScheduleOcrStage.recognising,
          message: 'بنقرا صورة الجدول على الجهاز…',
        ),
        onProgress,
      );
      final String html;
      try {
        html = await readHocr(
          files.fileInBatch(uid, batchId, relativePath).path,
        );
      } on BatchFailure {
        rethrow;
      } on Object {
        throw const BatchFailure(BatchFailureCode.ocrFailed);
      }

      if (isCancelled?.call() ?? false) {
        throw const BatchFailure(BatchFailureCode.cancelled);
      }

      job = _emit(
        job.copyWith(
          stage: ScheduleOcrStage.parsing,
          message: 'بنرتّب الحصص اللي اتقريت…',
        ),
        onProgress,
      );
      const parser = HocrParser();
      final document = parser.parse(html);
      final parsed = const TimetableLayoutParser().parse(document);
      final entries = parsed.entries.take(maxEntries).toList(growable: false);
      final warnings = <String>[...parsed.warnings];
      if (parsed.entries.length > maxEntries) {
        warnings.add(
          'الجدول فيه أكتر من $maxEntries حصة؛ '
          'حفظنا أول $maxEntries بس.',
        );
      }

      final now = _clock();
      final draft = TimetableDraft(
        id: draftId,
        batchId: batchId,
        sourceImageFileName: relativePath,
        ocrEngine: 'tesseract-$ocrLanguage',
        createdAt: now,
        updatedAt: now,
        entries: List.unmodifiable(entries),
        warnings: List.unmodifiable(warnings.take(_maxWarnings)),
      );

      _emit(
        job.copyWith(
          stage: ScheduleOcrStage.done,
          message: 'خلصنا قراءة الجدول. راجعه قبل النشر.',
          finishedAt: now,
        ),
        onProgress,
      );
      // The saved draft owns this photo now.
      copiedPath = null;
      return draft;
    } on BatchFailure catch (failure) {
      await _deleteQuietly(uid, batchId, copiedPath);
      _emit(
        job.copyWith(
          stage: failure.code == BatchFailureCode.cancelled
              ? ScheduleOcrStage.cancelled
              : ScheduleOcrStage.failed,
          message: _failureMessage(failure.code),
          finishedAt: _clock(),
        ),
        onProgress,
      );
      rethrow;
    } on Object {
      await _deleteQuietly(uid, batchId, copiedPath);
      _emit(
        job.copyWith(
          stage: ScheduleOcrStage.failed,
          message: _failureMessage(BatchFailureCode.ocrFailed),
          finishedAt: _clock(),
        ),
        onProgress,
      );
      throw const BatchFailure(BatchFailureCode.ocrFailed);
    }
  }

  /// Publishes [job] as the current one and to the caller.
  ///
  /// The field must move with every transition, because [isBusy] blocks a
  /// second import and a stale queued job would block it forever.
  ScheduleOcrJob _emit(
    ScheduleOcrJob job,
    void Function(ScheduleOcrJob job)? onProgress,
  ) {
    _lastJob = job;
    onProgress?.call(job);
    return job;
  }

  Future<void> _deleteQuietly(
    String uid,
    String batchId,
    String? relativePath,
  ) async {
    if (relativePath == null) return;
    try {
      await files.deleteFile(
        uid: uid,
        batchId: batchId,
        relativePath: relativePath,
      );
    } on BatchFailure {
      // The draft was never saved; an orphan photo is the only cost.
    }
  }

  static String _failureMessage(BatchFailureCode code) => switch (code) {
        BatchFailureCode.unsupportedFile =>
          'الصورة مش من نوع مدعوم. اختار صورة JPG أو PNG.',
        BatchFailureCode.fileTooLarge => 'الصورة كبيرة أوي. جرّب صورة أصغر.',
        BatchFailureCode.missingFile => 'مش لاقيين الصورة. اختارها تاني.',
        BatchFailureCode.storageFull => 'مساحة الجهاز خلصت.',
        BatchFailureCode.cancelled => 'اتوقف قراءة الجدول.',
        BatchFailureCode.ocrFailed =>
          'مقدرناش نقرا صورة الجدول. جرّب صورة أوضح.',
        _ => 'حصلت مشكلة وإحنا بنقرا الجدول. جرّب تاني.',
      };

  static Future<String> _readWithTesseract(String imagePath) async {
    return FlutterTesseractOcr.extractHocr(
      imagePath,
      language: ocrLanguage,
      args: {'preserve_interword_spaces': '1'},
    );
  }
}
