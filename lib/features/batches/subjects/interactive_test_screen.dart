/// A self-check test generated on the device from one batch PDF.
///
/// Every question carries the page and the verbatim sentence it came from.
/// The answer is revealed only after the reader confirms a choice, and the
/// finished attempt is stored on this device only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/batches/batch_failure.dart';
import '../../../core/theme.dart';
import '../../../models/study_source.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/study_providers.dart';
import '../../../widgets/common.dart';
import '../../../widgets/tr_text.dart';
import '../batch_error_text.dart';
import '../widgets/batch_labels.dart';
import 'study_widgets.dart';

class InteractiveTestScreen extends ConsumerWidget {
  const InteractiveTestScreen({
    super.key,
    required this.batchId,
    required this.resourceId,
  });

  final String batchId;
  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (batchId: batchId, resourceId: resourceId);
    final document = ref.watch(studyDocumentProvider(args));
    final questions = ref.watch(studyTestProvider(args));

    return Scaffold(
      appBar: AppBar(title: const TrText('اختبار تفاعلي')),
      body: questions.when(
        loading: () => const Center(
          child: LoadingBox(label: 'بنجهّز الأسئلة من نص الملف…'),
        ),
        error: (error, _) => _TestError(
          message: error is BatchFailure
              ? batchErrorText(error)
              : 'مقدرناش نجهّز الأسئلة.',
          onRetry: () {
            ref.invalidate(studyDocumentProvider(args));
            ref.invalidate(studyTestProvider(args));
          },
        ),
        data: (questions) {
          if (document.valueOrNull == null) return const StudyMissingSource();
          if (questions.isEmpty) {
            return EmptyState(
              icon: Icons.quiz_outlined,
              title: 'مفيش نص كفاية لبناء أسئلة',
              message: 'النص المستخرج من الملف قليل أو مش موجود. '
                  'ارجع لصفحة أدوات الدراسة وجرّب استخراج تاني.',
              action: FilledButton.icon(
                onPressed: () {
                  if (context.canPop()) context.pop();
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const TrText('رجوع'),
              ),
            );
          }
          return _TestRunner(args: args, questions: questions);
        },
      ),
    );
  }
}

class _TestRunner extends ConsumerStatefulWidget {
  const _TestRunner({required this.args, required this.questions});

  final StudyResourceArgs args;
  final List<StudyQuestion> questions;

  @override
  ConsumerState<_TestRunner> createState() => _TestRunnerState();
}

class _TestRunnerState extends ConsumerState<_TestRunner> {
  late List<StudyQuestion> _active;
  int _index = 0;
  int? _selected;
  final Map<String, int> _answers = {};
  final Set<String> _revealed = {};
  bool _finished = false;
  bool _retrying = false;
  bool _saving = false;
  StudyAttempt? _saved;

  @override
  void initState() {
    super.initState();
    _active = widget.questions;
  }

  @override
  void didUpdateWidget(covariant _TestRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.questions, widget.questions)) {
      _resetTo(widget.questions);
    }
  }

  StudyQuestion get _question => _active[_index];

  int get _correctCount => _active
      .where((question) => _answers[question.id] == question.correctIndex)
      .length;

  bool get _isLast => _index >= _active.length - 1;

  void _resetTo(List<StudyQuestion> questions) {
    setState(() {
      _active = questions;
      _index = 0;
      _selected = null;
      _finished = false;
      _retrying = false;
      _saving = false;
      _saved = null;
      _answers.clear();
      _revealed.clear();
    });
  }

  void _confirm() {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _answers[_question.id] = selected;
      _revealed.add(_question.id);
    });
  }

  void _next() {
    if (_isLast) {
      setState(() => _finished = true);
      // A review run covers only the missed questions, so storing it would
      // overwrite the full attempt with a score out of the missed count.
      if (!_retrying) _saveAttempt();
      return;
    }
    setState(() {
      _index += 1;
      _selected = null;
    });
  }

  void _retryMissed() {
    final missed = [
      for (final question in _active)
        if (_answers[question.id] != question.correctIndex) question,
    ];
    if (missed.isEmpty) return;
    setState(() {
      for (final question in missed) {
        _answers.remove(question.id);
        _revealed.remove(question.id);
      }
      _active = missed;
      _index = 0;
      _selected = null;
      _finished = false;
      _retrying = true;
      _saved = null;
    });
  }

  Future<void> _saveAttempt() async {
    if (_saving || _active.isEmpty) return;
    final uid = ref.read(authUserProvider)?.uid ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final answers = <String, int>{
      for (final question in _active)
        if (_answers[question.id] != null) question.id: _answers[question.id]!,
    };
    final attempt = StudyAttempt(
      resourceId: widget.args.resourceId,
      answers: answers,
      correct: _correctCount,
      total: _active.length,
      submittedAt: DateTime.now(),
    );
    setState(() => _saving = true);
    try {
      await ref.read(studyAttemptStoreProvider).save(
            uid: uid,
            batchId: widget.args.batchId,
            attempt: attempt,
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = attempt;
      });
      ref.invalidate(studyAttemptProvider(widget.args));
    } on BatchFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: TrText(batchErrorText(failure))),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: TrText('مقدرناش نحفظ المحاولة على الجهاز.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult(context);
    return _buildQuestion(context);
  }

  Widget _buildQuestion(BuildContext context) {
    final theme = Theme.of(context);
    final question = _question;
    final revealed = _revealed.contains(question.id);
    final chosen = _answers[question.id];
    final previous = ref.watch(studyAttemptProvider(widget.args)).valueOrNull;
    final showPrevious =
        previous != null && !revealed && _index == 0 && !_retrying;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_index + 1) / _active.length,
          minHeight: 4,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              ZakerSpacing.md,
              ZakerSpacing.lg,
              ZakerSpacing.xl,
            ),
            children: [
              TrText(
                'سؤال ${arabicDigits(_index + 1)} من '
                '${arabicDigits(_active.length)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ZakerSpacing.xs),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: StudyLocalBadge(compact: true),
              ),
              if (showPrevious) ...[
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  'آخر محاولة: ${arabicDigits(previous.correct)} من '
                  '${arabicDigits(previous.total)} · '
                  '${formatBatchDate(previous.submittedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: ZakerSpacing.md),
              Container(
                padding: const EdgeInsets.all(ZakerSpacing.md),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: ZakerRadius.card,
                  border: Border.all(
                    color: theme.dividerTheme.color ?? Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _kindIcon(question.kind),
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TrText(
                            _kindLabel(question.kind),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StudyPageChip(page: question.page),
                      ],
                    ),
                    const SizedBox(height: ZakerSpacing.sm),
                    TrText(
                      question.prompt,
                      style: theme.textTheme.titleMedium?.copyWith(
                        height: 1.55,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              for (var index = 0; index < question.choices.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
                  child: _ChoiceTile(
                    label: _choiceLabel(index),
                    text: question.choices[index],
                    chosen: chosen == index,
                    correct: index == question.correctIndex,
                    revealed: revealed,
                    selected: _selected == index,
                    onTap: revealed
                        ? null
                        : () => setState(() => _selected = index),
                  ),
                ),
              if (revealed) ...[
                const SizedBox(height: ZakerSpacing.sm),
                StudyEvidenceCard(
                  excerpt: question.evidence,
                  page: question.page,
                ),
                if (question.explanation.trim().isNotEmpty) ...[
                  const SizedBox(height: ZakerSpacing.sm),
                  TrText(
                    question.explanation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: ZakerSpacing.md),
                _FeedbackBanner(
                  correct: chosen == question.correctIndex,
                  answer: question.correctChoice,
                ),
              ],
              const SizedBox(height: ZakerSpacing.lg),
              if (!revealed)
                FilledButton(
                  onPressed: _selected == null ? null : _confirm,
                  child: const TrText('تأكيد الإجابة'),
                )
              else
                FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: TrText(
                    _isLast ? 'خلص الاختبار' : 'السؤال اللي بعده',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final theme = Theme.of(context);
    final correct = _correctCount;
    final total = _active.length;
    final missed = [
      for (final question in _active)
        if (_answers[question.id] != question.correctIndex) question,
    ];
    final message = switch (correct) {
      _ when correct == total => 'كل الإجابات صح. جرّب تحدي نفسك في ملف تاني.',
      _ when total > 0 && correct * 10 >= total * 7 =>
        'كويس. راجع الأسئلة اللي فاتتك، دليلها موجود في النص.',
      _ => 'محتاج مراجعة. اقرا صفحة الدليل قبل ما تجرّب تاني.',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.xl,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        Icon(
          correct == total ? Icons.verified_rounded : Icons.insights_rounded,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: ZakerSpacing.md),
        TrText(
          '${arabicDigits(correct)} من ${arabicDigits(total)} صح',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: ZakerSpacing.sm),
        TrText(
          _retrying ? 'محاولة مراجعة للأسئلة اللي فاتتك.' : message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        const SizedBox(height: ZakerSpacing.md),
        Center(
          child: const StudyLocalBadge(compact: true),
        ),
        const SizedBox(height: ZakerSpacing.lg),
        if (_saving)
          const Center(child: LoadingBox(label: 'بنحفظ المحاولة…'))
        else if (_saved != null)
          TrText(
            'المحاولة اتحفظت على الجهاز بس.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else if (_retrying)
          TrText(
            'محاولة المراجعة مش بتتحفظ لوحدها؛ المحاولة الأصلية هي المحفوظة.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: ZakerRadius.card,
              border: Border.all(
                color: theme.dividerTheme.color ?? Colors.black12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  'اللي فاتك',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final question in missed)
                  Padding(
                    padding: const EdgeInsets.only(top: ZakerSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TrText(
                            question.prompt,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StudyPageChip(page: question.page),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          FilledButton.icon(
            onPressed: _saving ? null : _retryMissed,
            icon: const Icon(Icons.replay_rounded),
            label: const TrText('راجع الأسئلة اللي فاتتك'),
          ),
        ] else ...[
          const SizedBox(height: ZakerSpacing.lg),
          FilledButton.icon(
            onPressed: _saving ? null : () => _resetTo(widget.questions),
            icon: const Icon(Icons.replay_rounded),
            label: const TrText('ابدأ من الأول'),
          ),
        ],
        if (missed.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.sm),
          TextButton(
            onPressed: _saving ? null : () => _resetTo(widget.questions),
            child: const TrText('ابدأ الاختبار من الأول'),
          ),
        ],
        const SizedBox(height: ZakerSpacing.sm),
        TextButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          child: const TrText('رجوع للملف'),
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.text,
    required this.chosen,
    required this.correct,
    required this.revealed,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool chosen;
  final bool correct;
  final bool revealed;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color border;
    final Color background;
    if (revealed && correct) {
      border = theme.colorScheme.primary;
      background = theme.colorScheme.primary.withValues(alpha: 0.10);
    } else if (revealed && chosen && !correct) {
      border = theme.colorScheme.error;
      background = theme.colorScheme.error.withValues(alpha: 0.08);
    } else if (!revealed && selected) {
      border = theme.colorScheme.primary;
      background = theme.colorScheme.primary.withValues(alpha: 0.08);
    } else {
      border = theme.dividerTheme.color ?? Colors.black12;
      background = theme.cardTheme.color ?? theme.colorScheme.surface;
    }
    final IconData icon;
    if (revealed && correct) {
      icon = Icons.check_circle_rounded;
    } else if (revealed && chosen) {
      icon = Icons.cancel_rounded;
    } else if (selected) {
      icon = Icons.radio_button_checked_rounded;
    } else {
      icon = Icons.radio_button_unchecked_rounded;
    }
    final iconColor = revealed && correct
        ? theme.colorScheme.primary
        : revealed && chosen
            ? theme.colorScheme.error
            : selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(ZakerRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZakerRadius.sm),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TrText(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.correct, required this.answer});

  final bool correct;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = correct ? theme.colorScheme.primary : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZakerRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correct ? Icons.check_circle_outline : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              correct
                  ? 'إجابة صح.'
                  : answer.isEmpty
                      ? 'الإجابة الصح مش متاحة في السؤال ده.'
                      : 'الإجابة الصح: $answer',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestError extends StatelessWidget {
  const _TestError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'مقدرناش نجهّز الاختبار',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const TrText('جرّب تاني'),
      ),
    );
  }
}

String _choiceLabel(int index) {
  const letters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];
  return index < letters.length ? letters[index] : arabicDigits(index + 1);
}

String _kindLabel(StudyQuestionKind kind) => switch (kind) {
      StudyQuestionKind.multipleChoice => 'اختيار من متعدد',
      StudyQuestionKind.cloze => 'أكمل الفراغ',
      StudyQuestionKind.trueFalse => 'صح أم خطأ',
    };

IconData _kindIcon(StudyQuestionKind kind) => switch (kind) {
      StudyQuestionKind.multipleChoice => Icons.list_alt_rounded,
      StudyQuestionKind.cloze => Icons.short_text_rounded,
      StudyQuestionKind.trueFalse => Icons.rule_rounded,
    };
