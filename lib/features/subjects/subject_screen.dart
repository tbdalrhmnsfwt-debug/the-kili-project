/// A single subject inside the secondary curriculum.
///
/// The screen groups everything a student needs for one subject: the textbook
/// PDFs (built on-device from the bundled lessons and opened in the embedded
/// viewer), summaries and AI explanations, video search, and a question bank
/// generated from the subject's own books.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/curriculum.dart';
import '../../core/pdf_documents.dart';
import '../../core/quiz_generator.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/exam.dart';
import '../../models/manhaji.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../tools/pdf_viewer_screen.dart';

/// The subject screen.
class SubjectScreen extends ConsumerStatefulWidget {
  const SubjectScreen({
    super.key,
    required this.gradeId,
    required this.subjectId,
    this.trackId,
  });

  final String gradeId;
  final String subjectId;
  final String? trackId;

  @override
  ConsumerState<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends ConsumerState<SubjectScreen> {
  String? _busyBookId;
  bool _generating = false;

  CurriculumSubject? get _subject =>
      curriculumSubject(widget.gradeId, widget.subjectId);

  CurriculumTrack? get _track =>
      curriculumTrack(widget.gradeId, widget.trackId) ??
      // A subject shared by every branch still shows the grade's default
      // branch, so its book list stays focused.
      curriculumForGrade(widget.gradeId)?.defaultTrack;

  @override
  Widget build(BuildContext context) {
    final subject = _subject;
    final curriculum = curriculumForGrade(widget.gradeId);
    if (subject == null || curriculum == null) {
      return Scaffold(
        appBar: AppBar(title: const TrText('المادة')),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'المادة مش موجودة',
          message: 'ارجع لقسم المواد واختار مادة تانية.',
        ),
      );
    }

    final gradeAsync = ref.watch(gradeProvider(widget.gradeId));
    return Scaffold(
      appBar: AppBar(title: TrText(subject.title)),
      body: gradeAsync.when(
        loading: () => const LoadingBox(label: 'بنفتح المادة…'),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مش قادرين نحمّل المادة',
          message: '$error',
        ),
        data: (grade) => _buildBody(context, ref, grade, curriculum, subject),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Grade grade,
    CurriculumGrade curriculum,
    CurriculumSubject subject,
  ) {
    final theme = Theme.of(context);
    final track = _track;
    final books = curriculumBooks(grade: grade, subject: subject, track: track);
    final read = ref.watch(readLessonsProvider);
    final lessons = subjectLessonCount(
      subject: subject,
      grade: grade,
      track: track,
    );
    final progress = subjectProgress(
      curriculum: curriculum,
      subject: subject,
      grade: grade,
      readLessons: read,
      track: track,
    );
    var readCount = 0;
    for (final book in books) {
      for (var lesson = 1; lesson <= book.lessons; lesson++) {
        if (read.contains('${grade.id}/${book.id}/$lesson')) readCount++;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.sm,
        ZakerSpacing.lg,
        ZakerSpacing.xxl,
      ),
      children: [
        _SubjectHeader(
          subject: subject,
          curriculum: curriculum,
          track: track,
          books: books.length,
          lessons: lessons,
          progress: progress,
        ),
        if (subject.note != null) ...[
          const SizedBox(height: ZakerSpacing.md),
          _NoteCard(text: subject.note!, color: subject.color),
        ],
        const SizedBox(height: ZakerSpacing.xl),
        const SectionHeader(
          title: 'أدوات المادة',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: ZakerSpacing.md),
        _ToolGrid(
          onExplain: () => _openChat(context, curriculum, subject),
          onVideos: () => _openVideos(context, curriculum, subject),
          onQuestions: () => _startQuiz(context, ref, grade, subject, track),
          onNotes: () => context.push(ZakerRoutes.notebooks),
        ),
        const SizedBox(height: ZakerSpacing.xl),
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'الكتاب المدرسي',
                icon: Icons.menu_book_rounded,
              ),
            ),
            if (books.isNotEmpty)
              StatChip(
                value: '${books.length}',
                label: 'كتاب',
                icon: Icons.library_books_outlined,
              ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        if (books.isEmpty)
          EmptyState(
            icon: subject.icon,
            title: 'محتوى ${subject.title} هيتضاف قريب',
            message: subject.note ??
                'المكتبة مش فيها كتاب للمادة دي لسه. تقدر تسأل المعلم الذكي '
                    'أو تراجع مادة قريبة منها.',
            action: FilledButton.icon(
              onPressed: () => _openChat(context, curriculum, subject),
              icon: const Icon(Icons.smart_toy_outlined),
              label: const TrText('اسأل المعلم الذكي'),
            ),
          )
        else
          for (final book in books)
            Padding(
              padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
              child: _BookCard(
                book: book,
                subject: subject,
                readLessons: read,
                busy: _busyBookId == book.id,
                onLessons: () => context.push(ZakerRoutes.lessonPath(book)),
                onPdf: () => _openBookPdf(book),
              ),
            ),
        if (books.isNotEmpty) ...[
          const SizedBox(height: ZakerSpacing.sm),
          _QuickReview(
            onQuiz: () => _startQuiz(context, ref, grade, subject, track),
            onRecall: () => context.push(ZakerRoutes.recall),
            onMindMap: () => context.push(
              '${ZakerRoutes.mindMap}?title=${Uri.encodeQueryComponent(subject.title)}',
            ),
          ),
        ],
        const SizedBox(height: ZakerSpacing.xl),
        TrText(
          'نسبة إنجاز ${subject.title}: ${(progress * 100).round()}% — '
          '${readCount} درس مقروء على جهازك.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- actions

  void _openChat(
    BuildContext context,
    CurriculumGrade curriculum,
    CurriculumSubject subject,
  ) {
    final question =
        'اشرحلي أهم نقاط منهج ${subject.title} — ${curriculum.label} ببساطة، '
        'ومعاك أمثلة وتمارين.';
    context.push(
      '${ZakerRoutes.chat}?subject=${Uri.encodeQueryComponent(subject.title)}'
      '&q=${Uri.encodeQueryComponent(question)}',
    );
  }

  Future<void> _openVideos(
    BuildContext context,
    CurriculumGrade curriculum,
    CurriculumSubject subject,
  ) async {
    final query = Uri.encodeQueryComponent(
      '${subject.title} ${curriculum.label} شرح',
    );
    final uri = Uri.parse('https://www.youtube.com/results?search_query=$query');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText('مش قادرين نفتح يوتيوب على الجهاز ده.'),
        ),
      );
    }
  }

  Future<void> _startQuiz(
    BuildContext context,
    WidgetRef ref,
    Grade grade,
    CurriculumSubject subject,
    CurriculumTrack? track,
  ) async {
    if (_generating) return;
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: ZakerSpacing.lg),
              Expanded(
                child: TrText('بنجهز أسئلة من كتب ${subject.title}…'),
              ),
            ],
          ),
        ),
      ),
    );

    final selected = <ExamQuestion>[];
    try {
      final service = ref.read(assetServiceProvider);
      final books = curriculumBooks(
        grade: grade,
        subject: subject,
        track: track,
      ).take(3);
      for (final book in books) {
        try {
          final json = await service.loadBook(book);
          final lessons = service.parseLessons(json);
          selected.addAll(
            generateClozeQuestions(
              book: book,
              lessons: lessons,
              maxQuestions: 8,
            ),
          );
        } catch (_) {
          // Encrypted or unreadable book: try the next one.
        }
        if (selected.length >= 14) break;
      }
    } finally {
      if (mounted) navigator.pop();
    }

    if (!mounted) return;
    setState(() => _generating = false);
    final questions = selected.take(12).toList(growable: false);
    if (questions.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: TrText(
            'الكتب دي مفيهاش نص كفاية لأسئلة — جرّب مادة تانية أو افتح الكتاب.',
          ),
        ),
      );
      return;
    }

    ref.read(examSessionProvider.notifier).state = ExamSession(
      id: 'exam-${subject.id}-${DateTime.now().millisecondsSinceEpoch}',
      title: 'بنك أسئلة — ${subject.title}',
      questions: questions,
      subject: subject.title,
      startedAt: DateTime.now(),
    );
    ref.read(activeChallengeProvider.notifier).state = null;
    ref.read(quizTimeLimitProvider.notifier).state = null;
    context.push(ZakerRoutes.quiz);
  }

  Future<void> _openBookPdf(Book book) async {
    if (_busyBookId != null) return;
    setState(() => _busyBookId = book.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(assetServiceProvider);
      final json = await service.loadBook(book);
      final lessons = service.parseLessons(json);
      final bytes = await buildBookPdf(book: book, lessons: lessons);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfViewerScreen(
            bytes: bytes,
            title: book.title,
            fileName: '${book.id}.pdf',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: TrText(
              'الكتاب ده محمي أو مش متاح للعرض دلوقتي — جرّب كتاب تاني.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyBookId = null);
    }
  }
}

// ------------------------------------------------------------------ header

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({
    required this.subject,
    required this.curriculum,
    required this.track,
    required this.books,
    required this.lessons,
    required this.progress,
  });

  final CurriculumSubject subject;
  final CurriculumGrade curriculum;
  final CurriculumTrack? track;
  final int books;
  final int lessons;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deep = Color.lerp(subject.color, Colors.black, 0.30) ?? subject.color;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [subject.color, deep],
        ),
        boxShadow: [
          BoxShadow(
            color: subject.color.withValues(alpha: 0.36),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            top: -30,
            child: Icon(
              subject.icon,
              size: 160,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZakerSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(ZakerSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(ZakerRadius.md),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(subject.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: ZakerSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            subject.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TrText(
                            [
                              curriculum.label,
                              if (track != null) track!.label,
                            ].join(' · '),
                            maxLines: 2,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.lg),
                Row(
                  children: [
                    _GlassStat(
                      value: '$books',
                      label: 'كتاب',
                      icon: Icons.library_books_outlined,
                    ),
                    const SizedBox(width: ZakerSpacing.sm),
                    _GlassStat(
                      value: '$lessons',
                      label: 'درس',
                      icon: Icons.play_lesson_outlined,
                    ),
                    const SizedBox(width: ZakerSpacing.sm),
                    _GlassStat(
                      value: '${(progress * 100).round()}%',
                      label: 'إنجاز',
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(ZakerRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.22),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A translucent stat pill for use on top of the coloured header gradient.
class _GlassStat extends StatelessWidget {
  const _GlassStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          TrText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          TrText(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: ZakerRadius.card,
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: color),
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: TrText(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- tool grid

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.onExplain,
    required this.onVideos,
    required this.onQuestions,
    required this.onNotes,
  });

  final VoidCallback onExplain;
  final VoidCallback onVideos;
  final VoidCallback onQuestions;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(String, String, IconData, Color, VoidCallback)>[
      (
        'شرح وملخص ذكي',
        'المعلم يشرحلك ببساطة',
        Icons.auto_awesome_rounded,
        ZakerColors.primary,
        onExplain,
      ),
      (
        'شرح بالفيديو',
        'دروس على يوتيوب',
        Icons.ondemand_video_rounded,
        const Color(0xFFDC2626),
        onVideos,
      ),
      (
        'بنك الأسئلة',
        'أسئلة من كتب المادة',
        Icons.quiz_rounded,
        const Color(0xFF7C3AED),
        onQuestions,
      ),
      (
        'ملاحظاتي',
        'دفاتر وملخصات',
        Icons.edit_note_rounded,
        const Color(0xFF0891B2),
        onNotes,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        const spacing = ZakerSpacing.md;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final (title, subtitle, icon, color, onTap) in items)
              SizedBox(
                width: width,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ZakerRadius.md),
                    onTap: onTap,
                    child: Ink(
                      padding: const EdgeInsets.all(ZakerSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(ZakerRadius.md),
                        border: Border.all(
                          color: theme.dividerTheme.color ?? Colors.black12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(height: ZakerSpacing.sm),
                          TrText(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          TrText(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------- books

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.subject,
    required this.readLessons,
    required this.busy,
    required this.onLessons,
    required this.onPdf,
  });

  final Book book;
  final CurriculumSubject subject;
  final Set<String> readLessons;
  final bool busy;
  final VoidCallback onLessons;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final read = readLessons
        .where((key) => key.startsWith('${book.grade}/${book.id}/'))
        .length
        .clamp(0, book.lessons);
    final progress = book.lessons == 0 ? 0.0 : read / book.lessons;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: subject.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: subject.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (book.variant.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: TrText(
                          book.variant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: 4,
            children: [
              _Meta(
                icon: Icons.menu_book_outlined,
                text: '${book.lessons} درس',
              ),
              _Meta(
                icon: Icons.description_outlined,
                text: '${book.pages} صفحة',
              ),
              _Meta(
                icon: Icons.task_alt_rounded,
                text: '$read مقروء',
                color: ZakerColors.success,
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZakerRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: subject.color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(subject.color),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onLessons,
                  icon: const Icon(Icons.play_lesson_rounded, size: 18),
                  label: const TrText('الدروس'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPdf,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: TrText(busy ? 'بنجهز…' : 'PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tint),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: tint,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _QuickReview extends StatelessWidget {
  const _QuickReview({
    required this.onQuiz,
    required this.onRecall,
    required this.onMindMap,
  });

  final VoidCallback onQuiz;
  final VoidCallback onRecall;
  final VoidCallback onMindMap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ZakerSpacing.sm,
      runSpacing: ZakerSpacing.sm,
      children: [
        ActionChip(
          avatar: const Icon(Icons.quiz_outlined, size: 16),
          label: const TrText('امتحان سريع'),
          onPressed: onQuiz,
        ),
        ActionChip(
          avatar: const Icon(Icons.style_outlined, size: 16),
          label: const TrText('بطاقات مراجعة'),
          onPressed: onRecall,
        ),
        ActionChip(
          avatar: const Icon(Icons.account_tree_outlined, size: 16),
          label: const TrText('خريطة ذهنية'),
          onPressed: onMindMap,
        ),
      ],
    );
  }
}
