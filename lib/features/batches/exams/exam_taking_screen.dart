/// Taking one local exam.
///
/// The countdown is derived from the persisted attempt deadline, never from a
/// decrementing counter, so backgrounding or restarting does not reset it.
/// When the deadline or the availability window ends, the saved answers are
/// submitted exactly once.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
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

class ExamTakingScreen extends ConsumerStatefulWidget {
  const ExamTakingScreen({
    super.key,
    required this.batchId,
    required this.examId,
  });

  final String batchId;
  final String examId;

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen> {
  ExamAttempt? _attempt;
  final Map<String, int> _answers = {};
  int _index = 0;
  DateTime _now = DateTime.now();
  Timer? _timer;
  Future<void> _saveTail = Future.value();
  bool _adopted = false;
  bool _startBusy = false;
  bool _submitting = false;
  bool _autoSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _now = ref.read(examClockProvider)();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examAsync = ref.watch(
        batchExamProvider((batchId: widget.batchId, examId: widget.examId)));
    final attemptsAsync = ref.watch(batchExamAttemptsProvider(widget.batchId));
    final detail = ref.watch(batchDetailProvider(widget.batchId));
    final uid = ref.watch(authUserProvider)?.uid ?? '';
    final snapshot = detail.valueOrNull;
    final canTake = snapshot != null && canTakeExams(snapshot, uid);

    return examAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const TrText('الامتحان')),
        body: const Center(child: LoadingBox(label: 'بنقرا الامتحان…')),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const TrText('الامتحان')),
        body: EmptyState(
          icon: Icons.sync_problem_rounded,
          title: 'مقدرناش نقرا الامتحان',
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
            if (attempt.examId == exam.id) attempt,
        ];
        final active = _attempt == null
            ? attempts.where((item) => item.isActive).firstOrNull
            : null;
        if (active != null && !_adopted) {
          _adopt(exam, active);
        }
        final attempt = _attempt;
        return Scaffold(
          appBar: AppBar(
            title: TrText(exam.title),
            actions: [
              if (attempt != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: ZakerSpacing.lg,
                  ),
                  child: Center(
                    child: _Countdown(
                      label: _deadlineLabel(exam, attempt),
                      remaining: _remaining(exam, attempt),
                    ),
                  ),
                ),
            ],
          ),
          body: attempt != null
              ? _taking(context, exam, attempt)
              : _intro(context, exam, attempts, canTake),
        );
      },
    );
  }

  DateTime? _deadline(BatchExam exam, ExamAttempt attempt) {
    final deadline = attempt.deadlineAt;
    final closes = exam.closesAt;
    if (deadline == null) return closes;
    if (closes != null && closes.isBefore(deadline)) return closes;
    return deadline;
  }

  Duration? _remaining(BatchExam exam, ExamAttempt attempt) {
    final deadline = _deadline(exam, attempt);
    if (deadline == null) return null;
    return deadline.difference(_now);
  }

  String _deadlineLabel(BatchExam exam, ExamAttempt attempt) {
    final deadline = _deadline(exam, attempt);
    if (deadline == null) return 'من غير وقت';
    return attempt.deadlineAt != null && attempt.deadlineAt == deadline
        ? 'وقت المحاولة'
        : 'لحد إغلاق الامتحان';
  }

  void _adopt(BatchExam exam, ExamAttempt attempt) {
    _adopted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _answers
          ..clear()
          ..addAll(attempt.answers);
        _index = 0;
        _now = ref.read(examClockProvider)();
      });
      _startTimer();
      _checkDeadline();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = ref.read(examClockProvider)());
      _checkDeadline();
    });
  }

  void _checkDeadline() {
    final attempt = _attempt;
    if (attempt == null || _autoSent || _submitting) return;
    final examAsync = ref.read(
      batchExamProvider((batchId: widget.batchId, examId: widget.examId)),
    );
    final exam = examAsync.valueOrNull;
    if (exam == null) return;
    final deadline = _deadline(exam, attempt);
    if (deadline != null && !_now.isBefore(deadline)) {
      _autoSent = true;
      _submit(exam, attempt, auto: true);
    }
  }

  Widget _intro(
    BuildContext context,
    BatchExam exam,
    List<ExamAttempt> attempts,
    bool canTake,
  ) {
    final theme = Theme.of(context);
    final now = _now;
    final status = exam.statusAt(now);
    final submitted = attempts.where((item) => item.isSubmitted).toList();
    final used = submitted.length;
    final cap = exam.attemptCap;
    final canStart =
        canTake && status == BatchExamStatus.open && (cap == 0 || used < cap);
    final latest = submitted.isEmpty ? null : submitted.first;
    final visible = exam.resultsVisibleAt(now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        ZakerSpacing.xl,
      ),
      children: [
        const BatchNotice(
          icon: Icons.timer_outlined,
          text: 'الوقت والتقييم على ساعة الجهاز. اقفل التطبيق وارجع، الوقت '
              'بيكمل من نفس النقطة.',
        ),
        const SizedBox(height: ZakerSpacing.md),
        Text(
          examStatusLabel(exam, now),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ZakerSpacing.xs),
        Text(
          examWindowText(exam),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZakerSpacing.xs),
        Text(
          '${arabicDigits(exam.questions.length)} سؤال · '
          '${examDurationLabel(exam.durationMinutes)} · ${examPolicyLabel(exam)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (exam.description.trim().isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.md),
          TrText(exam.description, style: theme.textTheme.bodyMedium),
        ],
        if (_error != null) ...[
          const SizedBox(height: ZakerSpacing.md),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: ZakerSpacing.xl),
        if (status == BatchExamStatus.draft)
          EmptyState(
            icon: Icons.edit_note_rounded,
            title: 'الامتحان مسودة',
            message: 'الامتحان لسه متنشرش. راجعه وانشره الأول.',
          )
        else if (status == BatchExamStatus.scheduled)
          EmptyState(
            icon: Icons.event_outlined,
            title: 'الامتحان لسه مفتحش',
            message: exam.opensAt == null
                ? 'الامتحان لسه مفتحش.'
                : 'بيفتح ${formatExamMoment(exam.opensAt!)}.',
          )
        else if (status == BatchExamStatus.closed && latest == null)
          const EmptyState(
            icon: Icons.lock_clock_outlined,
            title: 'الامتحان قفل',
            message: 'الوقت خلص ومفيش محاولة اتسلّمت.',
          )
        else if (latest != null && (cap != 0 && used >= cap)) ...[
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const TrText('خلصت محاولاتك'),
              subtitle: TrText(
                visible
                    ? 'آخر نتيجة ${arabicDigits(latest.scorePercent.round())}٪'
                    : 'النتيجة هتظهر بعد إغلاق الامتحان.',
              ),
              trailing: TextButton(
                onPressed: () => context.push(
                  ZakerRoutes.batchExamResult(widget.batchId, exam.id),
                ),
                child: const TrText('النتيجة'),
              ),
            ),
          ),
        ] else ...[
          if (submitted.isNotEmpty) ...[
            Text(
              'محاولات مستخدمة: ${arabicDigits(used)}'
              '${cap == 0 ? '' : ' من ${arabicDigits(cap)}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
          ],
          FilledButton.icon(
            onPressed: canStart && !_startBusy ? () => _start(exam) : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: TrText(
              _startBusy
                  ? 'بنبدأ…'
                  : latest == null
                      ? 'ابدأ الامتحان'
                      : 'ابدأ محاولة جديدة',
            ),
          ),
          if (!canTake)
            Padding(
              padding: const EdgeInsets.only(top: ZakerSpacing.sm),
              child: Text(
                'مش مسموح لك تبدأ محاولة في الدفعة دي.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        if (submitted.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.xl),
          Text(
            'محاولاتك',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final item in submitted)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded),
              title: TrText(attemptStatusLabel(item.status)),
              subtitle: TrText(
                '${formatExamMoment(item.submittedAt ?? item.startedAt)} · '
                '${arabicDigits(item.correctCount)} من '
                '${arabicDigits(item.total)}',
              ),
              trailing: visible
                  ? TrText(
                      '${arabicDigits(item.scorePercent.round())}٪',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : const Icon(Icons.lock_outline_rounded, size: 18),
            ),
        ],
      ],
    );
  }

  Widget _taking(BuildContext context, BatchExam exam, ExamAttempt attempt) {
    final theme = Theme.of(context);
    final question = exam.questions[_index.clamp(0, exam.questions.length - 1)];
    final selected = _answers[question.id];
    final remaining = _remaining(exam, attempt);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        ZakerSpacing.xl,
      ),
      children: [
        Wrap(
          spacing: ZakerSpacing.xs,
          runSpacing: ZakerSpacing.xs,
          children: [
            for (var index = 0; index < exam.questions.length; index++)
              ChoiceChip(
                label: TrText(arabicDigits(index + 1)),
                selected: index == _index,
                onSelected: (_) => setState(() => _index = index),
                avatar: _answers.containsKey(exam.questions[index].id)
                    ? const Icon(Icons.check_rounded, size: 16)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        if (remaining != null && remaining.inSeconds <= 30)
          Padding(
            padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
            child: Text(
              'الوقت قرّب يخلص. الإجابات المحفوظة هتتسلّم لوحدها.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'سؤال ${arabicDigits(_index + 1)} من '
                  '${arabicDigits(exam.questions.length)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  question.prompt,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.sm),
                RadioGroup<int>(
                  groupValue: selected,
                  onChanged: (value) => _answer(question.id, value),
                  child: Column(
                    children: [
                      for (var option = 0;
                          option < question.options.length;
                          option++)
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          value: option,
                          title: TrText(question.options[option]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _index <= 0 ? null : () => setState(() => _index -= 1),
              icon: const Icon(Icons.chevron_right_rounded),
              label: const TrText('السابق'),
            ),
            const SizedBox(width: ZakerSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _index >= exam.questions.length - 1
                    ? null
                    : () => setState(() => _index += 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: const TrText('التالي'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.lg),
        FilledButton.icon(
          onPressed: _submitting ? null : () => _reviewAndSubmit(exam, attempt),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(
            'راجع وسلّم · ${arabicDigits(_answers.length)} من '
            '${arabicDigits(exam.questions.length)}',
          ),
        ),
      ],
    );
  }

  void _answer(String questionId, int? value) {
    if (value == null) return;
    setState(() => _answers[questionId] = value);
    final attempt = _attempt;
    if (attempt == null) return;
    _saveTail = _saveTail.then((_) async {
      try {
        await ref.read(batchExamsControllerProvider).saveAnswers(
              widget.batchId,
              widget.examId,
              attempt.id,
              Map.of(_answers),
            );
      } on BatchFailure catch (failure) {
        if (!mounted) return;
        if (failure.code == BatchFailureCode.examClosed) {
          _checkDeadline();
        }
      } on Object {
        // The next selection retries; submit still sends the answers.
      }
    });
  }

  Future<void> _start(BatchExam exam) async {
    setState(() {
      _startBusy = true;
      _error = null;
    });
    try {
      final attempt = await ref
          .read(batchExamsControllerProvider)
          .start(widget.batchId, widget.examId);
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _answers
          ..clear()
          ..addAll(attempt.answers);
        _index = 0;
        _now = ref.read(examClockProvider)();
      });
      _startTimer();
      _checkDeadline();
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = switch (failure.code) {
          BatchFailureCode.examNotOpen => exam.opensAt == null
              ? 'الامتحان لسه مفتحش.'
              : 'الامتحان لسه مفتحش. بيفتح ${formatExamMoment(exam.opensAt!)}.',
          BatchFailureCode.examClosed => 'الامتحان قفل.',
          BatchFailureCode.conflict => 'خلصت عدد المحاولات المسموح.',
          _ => batchErrorText(failure),
        };
      });
    } on Object {
      if (mounted) setState(() => _error = 'البداية ما نجحتش. جرّب تاني.');
    } finally {
      if (mounted) setState(() => _startBusy = false);
    }
  }

  Future<void> _reviewAndSubmit(BatchExam exam, ExamAttempt attempt) async {
    final unanswered = exam.questions
        .where((question) => !_answers.containsKey(question.id))
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('تسليم الامتحان؟'),
        content: TrText(
          unanswered == 0
              ? 'جاوبت كل الأسئلة. بعد التسليم مش هينفع تعدل.'
              : 'فيه ${arabicDigits(unanswered)} سؤال من غير إجابة. '
                  'بعد التسليم مش هينفع تعدل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('لسه'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('سلّم'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submit(exam, attempt, auto: false);
  }

  Future<void> _submit(
    BatchExam exam,
    ExamAttempt attempt, {
    required bool auto,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(batchExamsControllerProvider).submit(
            widget.batchId,
            widget.examId,
            attempt.id,
            Map.of(_answers),
            auto: auto,
          );
      if (!mounted) return;
      _timer?.cancel();
      context.pushReplacement(
        ZakerRoutes.batchExamResult(widget.batchId, exam.id),
      );
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = batchErrorText(failure);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'التسليم ما تمّش. جرّب تاني.';
      });
    }
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.label, required this.remaining});

  final String label;
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = remaining == null ? '—' : formatExamRemaining(remaining!);
    final urgent = remaining != null && remaining!.inSeconds <= 60;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TrText(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: urgent ? theme.colorScheme.error : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        TrText(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
