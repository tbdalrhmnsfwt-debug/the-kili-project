/// Renders one lesson: its figures (page images plus the narrative that
/// explains them), and the actions the app offers on a lesson (ask the AI,
/// make questions, make a summary, …).
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme.dart';
import '../../models/manhaji.dart';
import '../../widgets/common.dart';

/// Displays a single lesson.
class LessonReaderScreen extends StatelessWidget {
  const LessonReaderScreen({
    super.key,
    required this.gradeId,
    required this.book,
    required this.lesson,
  });

  final String gradeId;
  final Book book;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lesson.title.isEmpty ? 'الدرس ${lesson.number}' : lesson.title,
        ),
        actions: [
          IconButton(
            tooltip: 'اسأل معلم AI',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => _hint(context, 'معلم AI'),
          ),
          IconButton(
            tooltip: 'اعمل أسئلة',
            icon: const Icon(Icons.quiz_outlined),
            onPressed: () => _hint(context, 'بنك الأسئلة'),
          ),
          IconButton(
            tooltip: 'الملخص',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => _hint(context, 'الملخص'),
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
          Text(
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

  void _hint(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what — لسه بيتشغّل')));
  }
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
                    label: Text(label),
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
            Text(
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
