/// The exams tab of one batch.
///
/// Everything here is local: the device clock is authoritative, and the live
/// ranking and live challenge say they need a server instead of pretending.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/batches/batch_store.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../models/batch_exam.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/batch_providers.dart';
import '../../../providers/exam_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import '../widgets/batch_notice.dart';
import 'exam_access.dart';
import 'exam_support.dart';

class BatchExamsScreen extends ConsumerWidget {
  const BatchExamsScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final exams = ref.watch(batchExamsProvider(batchId));
    final attempts = ref.watch(batchExamAttemptsProvider(batchId));
    final now = ref.watch(examClockProvider)();
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final snapshot = detail.valueOrNull;
    final canAuthor = snapshot != null && canAuthorExams(snapshot, uid);

    return Scaffold(
      appBar: AppBar(title: const TrText('الامتحانات')),
      floatingActionButton: canAuthor
          ? FloatingActionButton.extended(
              onPressed: () => context.push(ZakerRoutes.batchExamNew(batchId)),
              icon: const Icon(Icons.quiz_outlined),
              label: const TrText('امتحان جديد'),
            )
          : null,
      body: exams.when(
        loading: () => const Center(
          child: LoadingBox(label: 'بنقرا الامتحانات…'),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.sync_problem_rounded,
          title: 'مقدرناش نقرا الامتحانات',
          message: error is BatchFailure
              ? batchErrorText(error)
              : 'حصل خطأ مش معروف. جرّب تفتح الصفحة تاني.',
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(batchExamsProvider(batchId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const TrText('جرّب تاني'),
          ),
        ),
        data: (items) => _list(
          context,
          snapshot,
          items,
          attempts.valueOrNull ?? const [],
          uid,
          canAuthor,
          now,
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    BatchSnapshot? snapshot,
    List<BatchExam> exams,
    List<ExamAttempt> attempts,
    String uid,
    bool canAuthor,
    DateTime now,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        96,
      ),
      children: [
        const BatchNotice(
          icon: Icons.timer_outlined,
          text: 'امتحانات الدفعة بتتخزن على الجهاز، والوقت والتصحيح على '
              'ساعة الجهاز. الترتيب المباشر والتحدي محتاجين سيرفر.',
        ),
        const SizedBox(height: ZakerSpacing.md),
        _RankingCard(attempts: attempts, exams: exams, now: now),
        const SizedBox(height: ZakerSpacing.sm),
        if (exams.isEmpty)
          EmptyState(
            icon: Icons.quiz_outlined,
            title: 'مفيش امتحانات لسه',
            message: canAuthor
                ? 'اعمل امتحان اختيار من متعدد وحدد ميعاده ووقته. '
                    'مش هيتنشر غير لما تراجعه وتضغط نشر.'
                : 'المسؤول لسه مانشرش امتحانات. لما ينشرها هتلاقيها هنا.',
            action: canAuthor
                ? FilledButton.icon(
                    onPressed: () =>
                        context.push(ZakerRoutes.batchExamNew(batchId)),
                    icon: const Icon(Icons.quiz_outlined),
                    label: const TrText('اعمل امتحان'),
                  )
                : null,
          )
        else
          for (final exam in exams)
            _ExamCard(
              exam: exam,
              subjectName: _subjectName(snapshot, exam.subjectId),
              attempts: [
                for (final attempt in attempts)
                  if (attempt.examId == exam.id) attempt,
              ],
              now: now,
              onTap: () {
                if (!exam.isPublished && canAuthor) {
                  context.push(
                    ZakerRoutes.batchExamEdit(batchId, exam.id),
                    extra: exam,
                  );
                } else {
                  context.push(ZakerRoutes.batchExam(batchId, exam.id));
                }
              },
            ),
        const SizedBox(height: ZakerSpacing.md),
        const _LiveChallengeCard(),
      ],
    );
  }

  String? _subjectName(BatchSnapshot? snapshot, String subjectId) {
    if (snapshot == null || subjectId.isEmpty) return null;
    for (final subject in snapshot.batch.subjects) {
      if (subject.id == subjectId) return subject.name;
    }
    return null;
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.subjectName,
    required this.attempts,
    required this.now,
    required this.onTap,
  });

  final BatchExam exam;
  final String? subjectName;
  final List<ExamAttempt> attempts;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = attempts.where((item) => item.isActive).firstOrNull;
    final submitted =
        attempts.where((item) => item.isSubmitted).toList(growable: false);
    final visible = exam.resultsVisibleAt(now);
    final meta = [
      if (subjectName != null) subjectName!,
      '${arabicDigits(exam.questions.length)} سؤال',
      examDurationLabel(exam.durationMinutes),
      examPolicyLabel(exam),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TrText(
                      exam.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZakerSpacing.sm),
                  _StatusChip(exam: exam, now: now),
                ],
              ),
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                meta.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: ZakerSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: ZakerSpacing.xs),
                  Expanded(
                    child: TrText(
                      examWindowText(exam),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (active != null || submitted.isNotEmpty) ...[
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  _attemptLine(active, submitted, visible),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _attemptLine(
    ExamAttempt? active,
    List<ExamAttempt> submitted,
    bool visible,
  ) {
    if (active != null) {
      return 'محاولة شغالة — افتحها وكمّل.';
    }
    final latest = submitted.isEmpty ? null : submitted.first;
    final count = '${arabicDigits(submitted.length)} محاولة';
    if (latest == null) return count;
    if (!visible) return '$count · النتيجة بتظهر بعد الإغلاق.';
    return '$count · آخر نتيجة ${arabicDigits(latest.scorePercent.round())}٪';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.exam, required this.now});

  final BatchExam exam;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = exam.statusAt(now);
    final (background, foreground) = switch (status) {
      BatchExamStatus.draft => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
      BatchExamStatus.scheduled => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      BatchExamStatus.open => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      BatchExamStatus.closed => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZakerSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: TrText(
        examStatusLabel(exam, now),
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The current account's scores, with the cross-member ranking blocked.
class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.attempts,
    required this.exams,
    required this.now,
  });

  final List<ExamAttempt> attempts;
  final List<BatchExam> exams;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = <String, double>{
      for (final exam in exams)
        if (exam.resultsVisibleAt(now))
          for (final attempt in attempts)
            if (attempt.examId == exam.id && attempt.isSubmitted)
              exam.title: attempt.scorePercent,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.leaderboard_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: ZakerSpacing.sm),
                const Expanded(
                  child: TrText(
                    'نتايجك',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.xs),
            if (scores.isEmpty)
              TrText(
                'لسه مفيش نتايج ظاهرة لك.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final entry in scores.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TrText(
                    '${entry.key} · '
                    '${arabicDigits(entry.value.round())}٪',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            const SizedBox(height: ZakerSpacing.sm),
            TrText(
              'ترتيب باقي الأعضاء محتاج سيرفر.',
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

class _LiveChallengeCard extends StatelessWidget {
  const _LiveChallengeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: ZakerSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TrText(
                    'التحدي المباشر',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: ZakerSpacing.xs),
                  TrText(
                    'مفيش تحدي مباشر في النسخة دي. لما يبقى فيه سيرفر، '
                    'الترتيب هيبقى بالأدق أولًا وبونص سرعة محدود، ووقت '
                    'السيرفر هو المرجع. مفيش زر بداية وهمي هنا.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
