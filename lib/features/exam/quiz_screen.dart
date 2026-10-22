/// The quiz runner: one question at a time, instant grading, and a results
/// screen with the score.
///
/// Questions come from [quizQuestionsProvider]: the active exam session when
/// one exists, otherwise cloze questions derived from a readable textbook.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/exam.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// A question's four answer kinds, as listed in the app's UI strings:
/// "اختيار من متعدد، صح وخطأ، أكمل، وع…".
enum QuizQuestionType { multipleChoice, trueFalse, fillBlank, written }

/// Loads the questions, then hands off to the stateful runner.
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(quizQuestionsProvider);
    return questions.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('الاختبار')),
        body: const LoadingBox(label: 'بنجهز الأسئلة…'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('الاختبار')),
        body: EmptyState(
          icon: Icons.quiz_outlined,
          title: 'مش قادرين نجهز الأسئلة',
          message: '$e',
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('الاختبار')),
            body: const EmptyState(
              icon: Icons.quiz_outlined,
              title: 'مفيش أسئلة متاحة',
              message: 'افتح كتاب فيه محتوى وابدأ منه.',
            ),
          );
        }
        return _QuizRunner(questions: list);
      },
    );
  }
}

class _QuizRunner extends ConsumerStatefulWidget {
  const _QuizRunner({required this.questions});

  final List<ExamQuestion> questions;

  @override
  ConsumerState<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends ConsumerState<_QuizRunner> {
  int _index = 0;
  final Map<String, AnswerResult> _results = {};
  bool _revealed = false;

  List<ExamQuestion> get _questions => widget.questions;
  ExamQuestion get _current => _questions[_index];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = _current;

    return Scaffold(
      appBar: AppBar(
        title: Text('سؤال ${_index + 1} من ${_questions.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: ProgressBar(
            value: (_index + 1) / _questions.length,
            height: 6,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          Text(
            question.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              height: 1.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          for (var i = 0; i < question.options.length; i++) ...[
            _OptionTile(
              label: question.options[i],
              index: i,
              state: _optionState(i),
              onTap: _revealed ? null : () => _answer(i),
            ),
            const SizedBox(height: ZakerSpacing.sm),
          ],
          if (_revealed) ...[
            const SizedBox(height: ZakerSpacing.md),
            _FeedbackCard(result: _results[question.id]),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ZakerSpacing.lg),
          child: Row(
            children: [
              if (_index > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _index--;
                      _revealed = false;
                    }),
                    child: const Text('السابق'),
                  ),
                ),
              if (_index > 0) const SizedBox(width: ZakerSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _revealed ? _next : null,
                  child: Text(
                    _revealed
                        ? (_index == _questions.length - 1
                              ? 'شوف النتيجة'
                              : 'التالي')
                        : 'اختار إجابة',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _OptionState _optionState(int index) {
    if (!_revealed) return _OptionState.idle;
    final correct = _current.correctIndex;
    if (correct == null) return _OptionState.idle;
    if (index == correct) return _OptionState.correct;
    final result = _results[_current.id];
    if (result != null &&
        !result.isCorrect &&
        result.givenAnswer == index.toString()) {
      return _OptionState.wrong;
    }
    return _OptionState.idle;
  }

  void _answer(int index) {
    final correct = _current.correctIndex;
    final isCorrect = correct == null || correct == index;
    if (ref.read(soundsEnabledProvider)) {
      SystemSound.play(
        isCorrect ? SystemSoundType.click : SystemSoundType.alert,
      );
    }
    setState(() {
      _revealed = true;
      _results[_current.id] = AnswerResult(
        questionId: _current.id,
        isCorrect: isCorrect,
        givenAnswer: index.toString(),
        correctAnswer: correct?.toString() ?? '',
        feedback: isCorrect
            ? 'برافو — إجابة صحيحة'
            : 'الإجابة الصحيحة: ${_current.options[correct]}',
      );
    });
  }

  void _next() {
    if (_index == _questions.length - 1) {
      _showResults();
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  void _showResults() {
    final correct = _results.values.where((r) => r.isCorrect).length;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration_rounded,
              size: 48,
              color: ZakerColors.accent,
            ),
            const SizedBox(height: ZakerSpacing.md),
            Text(
              'النتيجة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Text(
              '$correct من ${_questions.length}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ZakerSpacing.xl),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).maybePop();
              },
              child: const Text('خلاص'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual state of an answer option.
enum _OptionState { idle, correct, wrong }

/// One tappable answer option.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.index,
    required this.state,
    this.onTap,
  });

  final String label;
  final int index;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color border, IconData? icon) = switch (state) {
      _OptionState.correct => (
        ZakerColors.success.withValues(alpha: 0.12),
        ZakerColors.success,
        Icons.check_circle_rounded,
      ),
      _OptionState.wrong => (
        ZakerColors.danger.withValues(alpha: 0.12),
        ZakerColors.danger,
        Icons.cancel_rounded,
      ),
      _OptionState.idle => (
        theme.cardTheme.color ?? Colors.white,
        theme.dividerTheme.color ?? Colors.black12,
        null,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: ZakerRadius.card,
            border: Border.all(
              color: border,
              width: state == _OptionState.idle ? 1 : 1.6,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  String.fromCharCode(0x0623 + index),
                  style: TextStyle(
                    color: border,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              if (icon != null) Icon(icon, color: border, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the explanation after answering.
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.result});

  final AnswerResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final isCorrect = r?.isCorrect ?? false;
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: (isCorrect ? ZakerColors.success : ZakerColors.danger)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZakerRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
            color: isCorrect ? ZakerColors.success : ZakerColors.danger,
            size: 20,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: Text(r?.feedback ?? '', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
