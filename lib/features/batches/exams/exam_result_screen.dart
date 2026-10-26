/// One submitted attempt, its score, and the answer key once the exam allows.
///
/// With «بعد الإغلاق» nothing is shown before the close instant, and there is
/// no preview path around the gate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../models/batch_exam.dart';
import '../../../models/exam.dart';
import '../../../providers/exam_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import '../widgets/batch_notice.dart';
import 'exam_support.dart';

class ExamResultScreen extends ConsumerWidget {
  const ExamResultScreen({
    super.key,
    required this.batchId,
    required this.examId,
  });

  final String batchId;
  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examAsync =
        ref.watch(batchExamProvider((batchId: batchId, examId: examId)));
    final attemptsAsync = ref.watch(batchExamAttemptsProvider(batchId));
    final now = ref.watch(examClockProvider)();

    return examAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const TrText('النتيجة')),
        body: const Center(child: LoadingBox(label: 'بنقرا النتيجة…')),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const TrText('النتيجة')),
        body: EmptyState(
          icon: Icons.sync_problem_rounded,
          title: 'مقدرناش نقرا النتيجة',
          message: error is BatchFailure
              ? batchErrorText(error)
              : 'حصل خطأ مش معروف.',
          action: TextButton(
            onPressed: () => context.pop(),
            child: const TrText('رجوع'),
          ),
        ),
      ),
      data: (exam) {
        final attempts = [
          for (final attempt
              in attemptsAsync.valueOrNull ?? const <ExamAttempt>[])
            if (attempt.examId == exam.id && attempt.isSubmitted) attempt,
        ];
        final attempt = attempts.isEmpty ? null : attempts.first;
        return Scaffold(
          appBar: AppBar(title: const TrText('النتيجة')),
          body: attempt == null
              ? EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'مفيش محاولة متسلّمة',
                  message: 'سلّم الامتحان الأول عشان تشوف النتيجة.',
                  action: TextButton(
                    onPressed: () => context.pop(),
                    child: const TrText('رجوع'),
                  ),
                )
              : _result(context, exam, attempt, attempts, now),
        );
      },
    );
  }

  Widget _result(
    BuildContext context,
    BatchExam exam,
    ExamAttempt attempt,
    List<ExamAttempt> attempts,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    final visible = exam.resultsVisibleAt(now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        ZakerSpacing.xl,
      ),
      children: [
        if (attempt.autoSubmitted)
          const BatchNotice(
            icon: Icons.timer_outlined,
            text: 'المحاولة دي اتسلّمت لوحدها لما الوقت خلص.',
          )
        else
          const BatchNotice(
            icon: Icons.phonelink_lock_rounded,
            text: 'التصحيح على الجهاز. مفيش ترتيب مباشر بين الأعضاء.',
          ),
        const SizedBox(height: ZakerSpacing.md),
        if (!visible)
          EmptyState(
            icon: Icons.lock_clock_outlined,
            title: 'النتيجة لسه مقفولة',
            message: exam.closesAt == null
                ? 'النتيجة هتظهر بعد إغلاق الامتحان.'
                : 'النتيجة هتظهر بعد إغلاق الامتحان، '
                    '${formatExamMoment(exam.closesAt!)}.',
            action: TextButton(
              onPressed: () => context.pop(),
              child: const TrText('رجوع'),
            ),
          )
        else ...[
          _ScoreCard(exam: exam, attempt: attempt),
          const SizedBox(height: ZakerSpacing.md),
          Text(
            'المراجعة',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          for (var index = 0; index < exam.questions.length; index++)
            _QuestionReview(
              index: index,
              question: exam.questions[index],
              selected: attempt.answers[exam.questions[index].id],
            ),
        ],
        if (attempts.length > 1) ...[
          const SizedBox(height: ZakerSpacing.md),
          Text(
            'محاولاتك',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final item in attempts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.id == attempt.id
                    ? Icons.radio_button_checked_rounded
                    : Icons.history_rounded,
              ),
              title: TrText(attemptStatusLabel(item.status)),
              subtitle: TrText(
                '${formatExamMoment(item.submittedAt ?? item.startedAt)} · '
                '${arabicDigits(item.correctCount)} من '
                '${arabicDigits(item.total)}',
              ),
              trailing: visible
                  ? TrText('${arabicDigits(item.scorePercent.round())}٪')
                  : const Icon(Icons.lock_outline_rounded, size: 18),
            ),
        ],
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.exam, required this.attempt});

  final BatchExam exam;
  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = attempt.scorePercent.round();
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              exam.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TrText(
                  '${arabicDigits(percent)}٪',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: ZakerSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TrText(
                    '${arabicDigits(attempt.correctCount)} صح من '
                    '${arabicDigits(attempt.total)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              formatExamMoment(attempt.submittedAt ?? attempt.startedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionReview extends StatelessWidget {
  const _QuestionReview({
    required this.index,
    required this.question,
    required this.selected,
  });

  final int index;
  final ExamQuestion question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = question.options;
    final correct = question.correctIndex;
    final answered = selected != null && selected! < options.length;
    final isCorrect = answered && correct != null && selected == correct;
    final selectedText = answered ? options[selected!] : 'من غير إجابة';
    final correctText =
        correct != null && correct < options.length ? options[correct] : '—';
    return Card(
      margin: const EdgeInsets.only(top: ZakerSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 20,
                  color: isCorrect
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: ZakerSpacing.xs),
                Expanded(
                  child: TrText(
                    'سؤال ${arabicDigits(index + 1)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              question.prompt,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              'إجابتك: $selectedText',
              style: theme.textTheme.bodySmall,
            ),
            TrText(
              'الإجابة الصحيحة: $correctText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (question.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                question.explanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (question.sourcePage != null ||
                question.sourceExcerpt.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: ZakerSpacing.xs),
                child: TrText(
                  [
                    if (question.sourcePage != null)
                      'صفحة ${arabicDigits(question.sourcePage!)}',
                    if (question.sourceExcerpt.trim().isNotEmpty)
                      '«${question.sourceExcerpt}»',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
