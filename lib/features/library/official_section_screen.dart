/// Reads one extracted official lesson with page provenance and study tools.
///
/// Everything on this screen comes from the downloaded PDF: the text, the
/// citations, the flashcards, the quiz and the mind map. The AI explanation is
/// optional and clearly labelled; without a backend the local explanation is
/// still shown, and no answer is invented.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/book_extraction.dart';
import '../../core/grounded_study.dart';
import '../../core/official_study_plan.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/focus.dart';
import '../../models/official_book.dart';
import '../../models/recall.dart';
import '../../models/schedule.dart';
import '../../providers/app_providers.dart';
import '../../providers/official_library_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import '../exam/quiz_screen.dart';
import '../tools/pdf_viewer_screen.dart';

/// One lesson of a downloaded official book.
class OfficialSectionScreen extends ConsumerStatefulWidget {
  const OfficialSectionScreen({
    super.key,
    required this.bookId,
    required this.sectionId,
  });

  final String bookId;
  final String sectionId;

  @override
  ConsumerState<OfficialSectionScreen> createState() =>
      _OfficialSectionScreenState();
}

class _OfficialSectionScreenState extends ConsumerState<OfficialSectionScreen> {
  late final GroundedStudyService _study;

  @override
  void initState() {
    super.initState();
    // The explanation is the assistant's job. Built without a service it can
    // only ever return the local extractive note, which left the AI half of
    // this screen dead while the app had a working backend.
    _study = GroundedStudyService(ai: ref.read(aiServiceProvider));
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(officialBooksProvider).valueOrNull;
    final library = ref.watch(officialLibraryControllerProvider).valueOrNull;
    final extractedAsync = ref.watch(officialExtractedProvider(widget.bookId));
    final book = _findBook(catalog);

    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const TrText('الدرس')),
        body: ref.watch(officialBooksProvider).isLoading
            ? const LoadingBox(label: 'بنقرا بيانات الكتاب…')
            : const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'الكتاب مش موجود',
                message: 'الفهرس الرسمي مفيهوش الكتاب ده.',
              ),
      );
    }

    return extractedAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const TrText('الدرس')),
        body: const LoadingBox(label: 'بنفتح نص الدرس…'),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const TrText('الدرس')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مقدرناش نقرا الدرس',
          message: '$error',
        ),
      ),
      data: (extracted) {
        final section = extracted?.sectionById(widget.sectionId);
        if (extracted == null || section == null) {
          return Scaffold(
            appBar: AppBar(title: const TrText('الدرس')),
            body: const EmptyState(
              icon: Icons.find_in_page_outlined,
              title: 'الدرس مش موجود',
              message:
                  'النسخة المستخرجة من الكتاب مفيهاش الدرس ده. '
                  'ارجع للكتاب واستخرج الدروس تاني.',
            ),
          );
        }
        final passage = OfficialPassage(
          book: book,
          section: section,
          extraction: extracted,
        );
        final row = library?.stateOf(book) ?? book.initialState();
        final doneKey = 'official:${book.id}/${section.id}';
        final done = ref.watch(readLessonsProvider).contains(doneKey);

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrText(
                    section.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TrText(
                    '${book.subject} · ${passage.citationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: done ? 'تم إنهاء الدرس' : 'علّم الدرس كمكتمل',
                  icon: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: done ? ZakerColors.success : null,
                  ),
                  onPressed: () => _toggleDone(doneKey, !done),
                ),
                if (row.hasFile)
                  IconButton(
                    tooltip: 'افتح صفحة الكتاب الأصلية',
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    onPressed: () => context.push(
                      PdfViewerScreen.location(
                        row.filePath,
                        title: book.titleAr,
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                _SourceStrip(
                  passage: passage,
                  isCurrentEdition: passage.isCurrentEdition,
                  fromOcr: section.fromOcr,
                  isFallback: section.isFallback,
                ),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'النص', icon: Icon(Icons.article_outlined, size: 18)),
                    Tab(text: 'الشرح', icon: Icon(Icons.lightbulb_outline_rounded, size: 18)),
                    Tab(text: 'الملخص', icon: Icon(Icons.summarize_outlined, size: 18)),
                    Tab(text: 'الأدوات', icon: Icon(Icons.construction_rounded, size: 18)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PagesTab(passage: passage, language: book.language),
                      _ExplanationTab(passage: passage, study: _study),
                      _SummaryTab(passage: passage, study: _study),
                      _ToolsTab(
                        passage: passage,
                        study: _study,
                        done: done,
                        onToggleDone: () => _toggleDone(doneKey, !done),
                        onAddCards: (cards) => _addCards(cards),
                        onOpenFlashcards: () => context.push(
                          ZakerRoutes.officialFlashcardsPath(
                            book.id,
                            section.id,
                          ),
                        ),
                        onOpenMindMap: () => context.push(
                          ZakerRoutes.officialMindMapPath(
                            book.id,
                            section.id,
                          ),
                        ),
                        onStartQuiz: () => _startQuiz(passage),
                        onBuildPlan: () => _buildPlan(book, passage),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  OfficialBook? _findBook(OfficialBookCatalog? catalog) {
    if (catalog == null) return null;
    for (final book in catalog.books) {
      if (book.id == widget.bookId) return book;
    }
    return null;
  }

  void _toggleDone(String key, bool done) {
    final current = ref.read(readLessonsProvider);
    ref.read(readLessonsProvider.notifier).state = done
        ? {...current, key}
        : ({...current}..remove(key));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(done ? 'الدرس اتعلّم كمكتمل.' : 'الدرس رجع غير مكتمل.'),
      ),
    );
  }

  void _addCards(List<RecallCard> cards) {
    final next = ReviewQueue(
      cards: List<RecallCard>.of(ref.read(reviewQueueProvider).cards),
    );
    final added = next.addAll(cards);
    ref.read(reviewQueueProvider.notifier).state = next;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? 'البطاقات دي موجودة في المراجعة بالفعل.'
              : 'اتضاف $added كارت للمراجعة. كل كارت مربوط بصفحته.',
        ),
        action: SnackBarAction(
          label: 'افتح المراجعة',
          onPressed: () => context.push(ZakerRoutes.recall),
        ),
      ),
    );
  }

  void _startQuiz(OfficialPassage passage) {
    final questions = _study.quiz(passage, limit: 10);
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مفيش نص كفاية لعمل اختبار من الدرس ده.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizRunner(
          questions: questions,
          title: passage.section.title,
          recordResults: false,
        ),
      ),
    );
  }

  Future<void> _buildPlan(OfficialBook book, OfficialPassage passage) async {
    final now = DateTime.now();
    final request = await showDialog<OfficialStudyPlanRequest>(
      context: context,
      builder: (_) => _PlanDialog(
        book: book,
        sections: [passage.section],
        initialStart: now,
        initialTarget: now.add(const Duration(days: 6)),
      ),
    );
    if (request == null || !mounted) return;
    final plan = OfficialStudyPlanBuilder.build(request);
    final current = ref.read(taskListProvider);
    final merged = OfficialStudyPlanBuilder.merge(current.tasks, plan.tasks);
    ref.read(taskListProvider.notifier).state = TaskList(
      title: current.title,
      tasks: merged,
    );

    // The Tasks screen reads the schedule model, not the focus-task list.
    // Mirror the same deterministic ids there so the plan is visible where
    // students actually tick tasks off, and overdue rescheduling sees it.
    var schedule = ref.read(taskScheduleProvider);
    for (final task in plan.tasks) {
      ScheduleEntry? existing;
      for (final entry in schedule.entries) {
        if (entry.id == task.id) {
          existing = entry;
          break;
        }
      }
      if (existing?.done == true) continue;
      schedule = schedule.upsert(
        ScheduleEntry(
          id: task.id,
          title: task.title,
          notes: task.notes,
          important: task.important,
          dueAt: task.dueAt,
          createdAt: task.createdAt,
        ),
      );
    }
    ref.read(taskScheduleProvider.notifier).state = schedule;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('اتضافت ${plan.tasks.length} مهمة للخطة. ${plan.summary}'),
        action: SnackBarAction(
          label: 'افتح المهام',
          onPressed: () => context.push(ZakerRoutes.tasks),
        ),
      ),
    );
  }
}

class _SourceStrip extends StatelessWidget {
  const _SourceStrip({
    required this.passage,
    required this.isCurrentEdition,
    required this.fromOcr,
    required this.isFallback,
  });

  final OfficialPassage passage;
  final bool isCurrentEdition;
  final bool fromOcr;
  final bool isFallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 14, color: theme.colorScheme.primary),
          TrText(
            '«${passage.book.titleAr}» · ${passage.citationLabel}',
            style: theme.textTheme.labelSmall,
          ),
          if (fromOcr)
            _TinyTag(label: 'OCR', color: ZakerColors.accent),
          if (isFallback)
            _TinyTag(label: 'نطاق صفحات', color: ZakerColors.accent),
          if (!isCurrentEdition)
            _TinyTag(label: 'طبعة قديمة', color: ZakerColors.danger),
        ],
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = readableTextColor(color, theme.colorScheme.surface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PagesTab extends StatelessWidget {
  const _PagesTab({required this.passage, required this.language});

  final OfficialPassage passage;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = passage.pages;
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        TrText(
          'النص ده مستخرج من PDF الرسمي. رقم كل صفحة هو رقمها في الملف.',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: ZakerSpacing.md),
        for (final page in pages)
          _PageCard(page: page, language: language),
      ],
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({required this.page, required this.language});

  final PassagePage page;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = page.text.trim().isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'صفحة ${page.pageNumber}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (page.fromOcr) ...[
                  const SizedBox(width: 6),
                  const _TinyTag(label: 'OCR', color: ZakerColors.accent),
                ],
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            if (empty)
              TrText(
                'الصفحة دي مفيهاش نص مستخرج. يمكن تكون صورة أو رسم، '
                'ومحاولناش نخترع محتواها.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              )
            else
              SelectableText(
                page.text,
                textDirection: language == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.8,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationTab extends StatefulWidget {
  const _ExplanationTab({required this.passage, required this.study});

  final OfficialPassage passage;
  final GroundedStudyService study;

  @override
  State<_ExplanationTab> createState() => _ExplanationTabState();
}

class _ExplanationTabState extends State<_ExplanationTab> {
  late final StudyNote _local = widget.study.localExplanation(widget.passage);
  Future<StudyNote>? _aiFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        if (!widget.passage.isCurrentEdition)
          _EditionWarning(edition: widget.passage.edition),
        _NoteCard(note: _local, study: widget.study),
        const SizedBox(height: ZakerSpacing.md),
        if (_aiFuture == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(ZakerSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TrText(
                    'شرح مساعد بالذكاء الاصطناعي',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  TrText(
                    'اختياري. بيشتغل من نص الصفحات دي بس، ولازم يذكر الصفحة. '
                    'لو الخدمة مش متاحة، الشرح المحلي اللي فوق هو اللي هيفضل.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: ZakerSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _aiFuture = widget.study.explanation(widget.passage);
                    }),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: const TrText('اطلب شرح مساعد'),
                  ),
                ],
              ),
            ),
          )
        else
          FutureBuilder<StudyNote>(
            future: _aiFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingBox(label: 'بنطلب شرح من الكتاب…');
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _NoteCard(note: _local, study: widget.study);
              }
              return _NoteCard(note: snapshot.data!, study: widget.study);
            },
          ),
      ],
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab({required this.passage, required this.study});

  final OfficialPassage passage;
  final GroundedStudyService study;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glossary = ref.watch(officialGlossaryProvider).valueOrNull;
    final vocabulary = glossary == null
        ? null
        : study.vocabularyNote(passage, glossary);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        if (!passage.isCurrentEdition) _EditionWarning(edition: passage.edition),
        _NoteCard(note: study.summary(passage), study: study),
        const SizedBox(height: ZakerSpacing.md),
        _NoteCard(note: study.revisionNote(passage), study: study),
        const SizedBox(height: ZakerSpacing.md),
        _NoteCard(note: study.definitionsNote(passage), study: study),
        const SizedBox(height: ZakerSpacing.md),
        _NoteCard(note: study.formulasNote(passage), study: study),
        const SizedBox(height: ZakerSpacing.md),
        _NoteCard(note: study.stepsNote(passage), study: study),
        if (vocabulary != null) ...[
          const SizedBox(height: ZakerSpacing.md),
          _NoteCard(note: vocabulary, study: study),
        ],
        const SizedBox(height: ZakerSpacing.md),
        const _ProvenanceNote(),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.study});

  final StudyNote note;
  final GroundedStudyService study;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  note.isAi
                      ? Icons.auto_awesome_rounded
                      : Icons.verified_outlined,
                  size: 16,
                  color: note.isAi ? ZakerColors.accent : ZakerColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TrText(
                    note.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _TinyTag(
                  label: note.label,
                  color: note.isAi ? ZakerColors.accent : ZakerColors.success,
                ),
                _TinyTag(label: 'طبعة ${note.edition}', color: theme.colorScheme.primary),
              ],
            ),
            if (note.warning.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TrText(
                  note.warning,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: readableTextColor(
                      ZakerColors.accent,
                      theme.colorScheme.surface,
                    ),
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: ZakerSpacing.sm),
            MarkdownBody(
              data: note.body,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
                strong: const TextStyle(fontWeight: FontWeight.w900),
                code: theme.textTheme.bodySmall?.copyWith(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            if (note.citations.isNotEmpty) ...[
              const SizedBox(height: ZakerSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final citation in note.citations.take(8))
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.menu_book_outlined, size: 13),
                      label: Text(citation.label),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: TrText(citation.label),
                          content: SingleChildScrollView(
                            child: TrText(
                              citation.quote,
                              style: const TextStyle(height: 1.7),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const TrText('قفل'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            TrText(
              'اتولد ${_shortDate(note.generatedAt)} من نص الكتاب.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvenanceNote extends StatelessWidget {
  const _ProvenanceNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TrText(
      'الملخص والتعريفات والقوانين والخطوات مستخرجة من نص الكتاب نفسه، '
      'مش مولّدة من غير مصدر. المفردات مترجمة من قاموس التطبيق المضمّن. '
      'الاقتباسات مربوطة برقم الصفحة.',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.6,
      ),
    );
  }
}

class _EditionWarning extends StatelessWidget {
  const _EditionWarning({required this.edition});

  final String edition;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.md),
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: ZakerColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        border: Border.all(color: ZakerColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: ZakerColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TrText(
              'النص مستخرج من طبعة قديمة (metadata $edition). '
              'أعد استخراج الكتاب بعد التحديث عشان الشرح والكروت يبقوا مطابقين.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolsTab extends StatelessWidget {
  const _ToolsTab({
    required this.passage,
    required this.study,
    required this.done,
    required this.onToggleDone,
    required this.onAddCards,
    required this.onOpenFlashcards,
    required this.onOpenMindMap,
    required this.onStartQuiz,
    required this.onBuildPlan,
  });

  final OfficialPassage passage;
  final GroundedStudyService study;
  final bool done;
  final VoidCallback onToggleDone;
  final ValueChanged<List<RecallCard>> onAddCards;
  final VoidCallback onOpenFlashcards;
  final VoidCallback onOpenMindMap;
  final VoidCallback onStartQuiz;
  final VoidCallback onBuildPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = study.flashcards(passage);
    final questions = study.quiz(passage, limit: 10);
    final map = study.mindMap(passage);
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        _CompletionCard(done: done, onToggle: onToggleDone),
        const SizedBox(height: ZakerSpacing.md),
        _ToolCard(
          icon: Icons.style_rounded,
          title: 'بطاقات استرجاع',
          description:
              '${cards.length} كارت من الدرس. اكشف الإجابة بنفسك، '
              'وبعدها اختار «عرفتها / راجعها / صعبة».',
          actions: [
            FilledButton.tonalIcon(
              onPressed: onOpenFlashcards,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const TrText('ادرس البطاقات'),
            ),
            OutlinedButton.icon(
              onPressed: cards.isEmpty ? null : () => onAddCards(cards),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const TrText('ضيفها للمراجعة'),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        _ToolCard(
          icon: Icons.account_tree_outlined,
          title: 'خريطة ذهنية تفاعلية',
          description:
              '${map.nodeCount} عقدة من المفاهيم والقوانين والخطوات. '
              'اسحب وزوّم، وافتح أو اقفل أي فرع.',
          actions: [
            FilledButton.tonalIcon(
              onPressed: onOpenMindMap,
              icon: const Icon(Icons.open_in_full_rounded, size: 18),
              label: const TrText('افتح الخريطة'),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        _ToolCard(
          icon: Icons.quiz_outlined,
          title: 'اختبار من الدرس',
          description:
              '${questions.length} سؤال اختيار وصح/غلط ومقالي. '
              'كل سؤال مربوط بالصفحة اللي جه منها.',
          actions: [
            FilledButton.tonalIcon(
              onPressed: questions.isEmpty ? null : onStartQuiz,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const TrText('ابدأ الاختبار'),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        _ToolCard(
          icon: Icons.event_note_rounded,
          title: 'ضيف لخطة المذاكرة',
          description:
              'اختار تاريخ البدء والهدف والوقت اليومي. الخطة بتضيف '
              'جلسة مذاكرة ومراجعات متباعدة، من غير ما تمسح المهام المكتملة.',
          actions: [
            FilledButton.tonalIcon(
              onPressed: onBuildPlan,
              icon: const Icon(Icons.add_task_rounded, size: 18),
              label: const TrText('ابنِ الخطة'),
            ),
          ],
        ),
        const SizedBox(height: ZakerSpacing.md),
        const _ProvenanceNote(),
        const SizedBox(height: ZakerSpacing.sm),
        TrText(
          'مصدر الدرس: «${passage.book.titleAr}» · ${passage.citationLabel}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.done, required this.onToggle});

  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: (done ? ZakerColors.success : theme.colorScheme.primary)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        border: Border.all(
          color: (done ? ZakerColors.success : theme.colorScheme.primary)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: done ? ZakerColors.success : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TrText(
              done
                  ? 'الدرس مكتمل. تقدر تراجعه في أي وقت.'
                  : 'خلّصت الدرس؟ الإنهاء صريح وبيتحفظ على الجهاز.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
          TextButton(
            onPressed: onToggle,
            child: TrText(done ? 'رجّعه' : 'أتممت'),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                TrText(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TrText(
              description,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Wrap(
              spacing: ZakerSpacing.sm,
              runSpacing: ZakerSpacing.sm,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({
    required this.book,
    required this.sections,
    required this.initialStart,
    required this.initialTarget,
  });

  final OfficialBook book;
  final List<ExtractedSection> sections;
  final DateTime initialStart;
  final DateTime initialTarget;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late DateTime _start = widget.initialStart;
  late DateTime _target = widget.initialTarget;
  double _minutes = 45;
  bool _reviews = true;
  bool _quiz = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const TrText('خطة مذاكرة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              'من ${_date(_start)} إلى ${_date(_target)} · '
              '${_sectionsFor(_minutes)} جلسات في اليوم تقريبًا.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStart,
                    child: TrText('البدء: ${_date(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTarget,
                    child: TrText('الهدف: ${_date(_target)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              'وقت المذاكرة اليومي: ${_minutes.round()} دقيقة',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: _minutes,
              min: 15,
              max: 180,
              divisions: 11,
              label: '${_minutes.round()} دقيقة',
              onChanged: (value) => setState(() => _minutes = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _reviews,
              onChanged: (value) => setState(() => _reviews = value),
              title: const TrText('مراجعات متباعدة'),
              subtitle: const TrText('بعد يوم و3 أيام لكل درس', style: TextStyle(fontSize: 10.5)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _quiz,
              onChanged: (value) => setState(() => _quiz = value),
              title: const TrText('اختبار بعد أسبوع'),
              subtitle: const TrText('اختبار قصير من نفس الدرس', style: TextStyle(fontSize: 10.5)),
            ),
            const SizedBox(height: 4),
            TrText(
              'المهام المكتملة عندك مش هتتغير. إعادة توليد الخطة بتحدّث '
              'مهامها بنفس المعرّفات بدل ما تكررها.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const TrText('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              OfficialStudyPlanRequest(
                book: widget.book,
                sections: widget.sections,
                startDate: _start,
                targetDate: _target,
                dailyMinutes: _minutes.round(),
                includeReviews: _reviews,
                includeQuiz: _quiz,
              ),
            );
          },
          child: const TrText('أنشئ الخطة'),
        ),
      ],
    );
  }

  int _sectionsFor(double minutes) {
    final perDay = minutes.round() ~/ 25;
    if (perDay < 1) return 1;
    if (perDay > widget.sections.length) return widget.sections.length;
    return perDay;
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) {
      setState(() {
        _start = picked;
        if (_target.isBefore(picked)) _target = picked;
      });
    }
  }

  Future<void> _pickTarget() async {
    final last = _start.add(const Duration(days: 730));
    final initial = _target.isBefore(_start)
        ? _start
        : (_target.isAfter(last) ? last : _target);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _start,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _target = picked);
  }
}

String _date(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _shortDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
