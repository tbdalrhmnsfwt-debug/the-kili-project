/// Labels and formatters shared by the exam screens.
library;

import '../../../models/batch_exam.dart';
import '../widgets/batch_labels.dart';

/// `٢٥/١٠/٢٠٢٦ · ٨:٠٠ ص`
String formatExamMoment(DateTime value) {
  final local = value.toLocal();
  return '${formatBatchDate(local)} · '
      '${formatScheduleTime(local.hour * 60 + local.minute)}';
}

/// The lifecycle label of [exam] at [now].
String examStatusLabel(BatchExam exam, DateTime now) {
  return switch (exam.statusAt(now)) {
    BatchExamStatus.draft => 'مسودة',
    BatchExamStatus.scheduled =>
      'يفتح ${formatExamMoment(exam.opensAt ?? now)}',
    BatchExamStatus.open => 'مفتوح',
    BatchExamStatus.closed => 'اتقفل',
  };
}

/// The availability window in plain words, never a guessed one.
String examWindowText(BatchExam exam) {
  final opens = exam.opensAt;
  final closes = exam.closesAt;
  if (opens == null && closes == null) return 'من غير ميعاد محدد';
  if (opens != null && closes != null) {
    return 'من ${formatExamMoment(opens)} لحد ${formatExamMoment(closes)}';
  }
  if (opens != null) return 'يفتح ${formatExamMoment(opens)}';
  return 'يقفل ${formatExamMoment(closes!)}';
}

String examDurationLabel(int minutes) =>
    minutes <= 0 ? 'من غير وقت محدد' : '${arabicDigits(minutes)} دقيقة';

String examPolicyLabel(BatchExam exam) => switch (exam.attemptPolicy) {
      BatchExamAttemptPolicy.single => 'محاولة واحدة',
      BatchExamAttemptPolicy.limited =>
        'لحد ${arabicDigits(exam.maxAttempts)} محاولات',
      BatchExamAttemptPolicy.unlimited => 'محاولات مفتوحة',
    };

String examResultsModeLabel(BatchExamResultsMode mode) => switch (mode) {
      BatchExamResultsMode.immediately => 'النتيجة فور التسليم',
      BatchExamResultsMode.afterClose => 'النتيجة بعد إغلاق الامتحان',
    };

String attemptStatusLabel(ExamAttemptStatus status) => switch (status) {
      ExamAttemptStatus.active => 'شغال',
      ExamAttemptStatus.submitted => 'اتسلّم',
      ExamAttemptStatus.expired => 'انتهى وقته من غير إجابة',
    };

/// `mm:ss`, or `h:mm:ss` for a long attempt.
String formatExamRemaining(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 359999);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  final paddedRest = rest < 10 ? '٠${arabicDigits(rest)}' : arabicDigits(rest);
  if (hours > 0) {
    final paddedMinutes =
        minutes < 10 ? '٠${arabicDigits(minutes)}' : arabicDigits(minutes);
    return '${arabicDigits(hours)}:$paddedMinutes:$paddedRest';
  }
  final paddedMinutes =
      minutes < 10 ? '٠${arabicDigits(minutes)}' : arabicDigits(minutes);
  return '$paddedMinutes:$paddedRest';
}
