/// Renders one lesson: its figures (page images plus the narrative that
/// explains them), and the actions the app offers on a lesson (ask the AI,
/// make questions, make a summary, …).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/quiz_generator.dart';
import '../../core/theme.dart';
import '../../models/exam.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../ai/chat_screen.dart';
import '../exam/quiz_screen.dart';
import '../../widgets/tr_text.dart';

/// Displays a single lesson.
class LessonReaderScreen extends ConsumerWidget {
  const LessonReaderScreen({
    super.key,
    required this.gradeId,
    required this.book,
    required this.lesson,
  });

  final String gradeId;
  final Book book;
  final Lesson lesson;

  String get _title =>
      lesson.title.isEmpty ? 'الدرس ${lesson.number}' : lesson.title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TrText(_title),
        actions: [
          IconButton(
            tooltip: 'اسأل معلم AI',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => _askAi(context),
          ),
          IconButton(
            tooltip: 'اعمل أسئلة',
            icon: const Icon(Icons.quiz_outlined),
            onPressed: () => _makeQuestions(context, ref),
          ),
          IconButton(
            tooltip: 'الملخص',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => _showSummary(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.lg,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          TrText(
            '${book.title} — الدرس ${lesson.number}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          for (final figure in lesson.figures) ...[
            _FigureView(figure: figure, gradeId: gradeId, bookId: book.id),
            const SizedBox(height: ZakerSpacing.md),
          ],
          if (lesson.figures.isEmpty)
            const EmptyState(icon: Icons.article_outlined, title: 'مفيش محتوى'),
        ],
      ),
    );
  }

  /// Opens the AI chat with this lesson as the opening question.
  void _askAi(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          subject: book.subject,
          initialQuestion:
              'اشرحلي «$_title» من كتاب ${book.title} ببساطة، ومعاه مثال.',
        ),
      ),
    );
  }

  /// Builds a question bank from the whole book and starts the quiz.
  Future<void> _makeQuestions(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: TrText('بنجهز الأسئلة…')));
    try {
      final service = ref.read(assetServiceProvider);
      final json = await service.loadBook(book);
      final lessons = service.parseLessons(json);
      final questions = generateClozeQuestions(book: book, lessons: lessons);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();

      if (questions.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: TrText('الكتاب ده مفيهوش نص كفاية لأسئلة.')),
        );
        return;
      }

      ref.read(examSessionProvider.notifier).state = ExamSession(
        id: 'lesson-${DateTime.now().millisecondsSinceEpoch}',
        title: 'بنك أسئلة — ${book.title}',
        questions: questions,
        bookId: book.id,
        subject: book.subject,
        startedAt: DateTime.now(),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QuizScreen()),
      );
      if (context.mounted) {
        ref.read(examSessionProvider.notifier).state = null;
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: TrText('مقدرناش نجهز الأسئلة: $e')));
    }
  }

  /// Shows a short extractive summary of the lesson's narrative.
  void _showSummary(BuildContext context) {
    final points = _lessonText
        .split(RegExp(r'[\n\r]+|[.!؟?]'))
        .map((s) => s.trim())
        .where((s) => s.length > 24)
        .take(8)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: ZakerRadius.sheet),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZakerSpacing.lg,
            0,
            ZakerSpacing.lg,
            ZakerSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrText(
                'ملخص $_title',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ZakerSpacing.md),
              if (points.isEmpty)
                const TrText('الدرس ده مفيهوش نص نلخصه.')
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final point in points)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: ZakerSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: ZakerColors.accent,
                                ),
                                const SizedBox(width: ZakerSpacing.sm),
                                Expanded(
                                  child: TrText(
                                    point,
                                    style: const TextStyle(height: 1.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (points.isNotEmpty) ...[
                const SizedBox(height: ZakerSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final text = points.map((p) => '• $p').join('\n');
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const TrText('انسخ الملخص'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _lessonText => lesson.figures
      .map((f) => f.narrative.trim())
      .where((text) => text.isNotEmpty)
      .join('\n\n');
}

/// Renders one figure: the page image, its anachdit labels and its
/// narrative.
class _FigureView extends StatelessWidget {
  const _FigureView({
    required this.figure,
    required this.gradeId,
    required this.bookId,
  });

  final Figure figure;
  final String gradeId;
  final String bookId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(ZakerRadius.sm),
            child: Image.asset(
              // Figure files are prefixed with their book id in the APK.
              'assets/manhaji/$gradeId/figs/${bookId}_${figure.assetPath}',
              fit: BoxFit.contain,
              errorBuilder: (context, _, __) => Container(
                height: 160,
                alignment: Alignment.center,
                color: theme.dividerTheme.color,
                child: const Icon(Icons.image_outlined, size: 40),
              ),
            ),
          ),
          if (figure.labels.isNotEmpty) ...[
            const SizedBox(height: ZakerSpacing.sm),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.xs,
              children: [
                for (final label in figure.labels)
                  Chip(
                    label: TrText(label),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
          if (figure.narrative.isNotEmpty) ...[
            const SizedBox(height: ZakerSpacing.sm),
            MarkdownBody(
              data: figure.narrative,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyLarge?.copyWith(height: 1.9),
                strong: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          if (figure.page != null) ...[
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              'صفحة ${figure.page}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
