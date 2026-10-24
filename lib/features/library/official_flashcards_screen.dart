/// Flashcards generated from one official lesson.
///
/// The answer stays hidden until the student reveals it. The three ratings
/// feed [RecallCard.graded], so every trip through a card changes its spaced
/// schedule and survives a restart through the shared review queue.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/grounded_study.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/official_book.dart';
import '../../models/recall.dart';
import '../../providers/app_providers.dart';
import '../../providers/official_library_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// Reviews the flashcards of an extracted section.
class OfficialFlashcardsScreen extends ConsumerWidget {
  const OfficialFlashcardsScreen({
    super.key,
    required this.bookId,
    required this.sectionId,
  });

  final String bookId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(officialBooksProvider).valueOrNull;
    final extractedAsync = ref.watch(officialExtractedProvider(bookId));
    final book = _findBook(catalog);
    if (book == null) {
      return Scaffold(
        appBar: AppBar(title: const TrText('بطاقات الدرس')),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'الكتاب مش موجود',
          message: 'ارجع للمكتبة الرسمية وافتح الكتاب تاني.',
        ),
      );
    }
    return extractedAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const TrText('بطاقات الدرس')),
        body: const LoadingBox(label: 'بنجهز البطاقات…'),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const TrText('بطاقات الدرس')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'مقدرناش نفتح الدرس',
          message: '$error',
        ),
      ),
      data: (extracted) {
        final section = extracted?.sectionById(sectionId);
        if (extracted == null || section == null) {
          return Scaffold(
            appBar: AppBar(title: const TrText('بطاقات الدرس')),
            body: const EmptyState(
              icon: Icons.style_outlined,
              title: 'مفيش بطاقات',
              message: 'الدرس مش متاح في النسخة المستخرجة. أعد استخراج الكتاب.',
            ),
          );
        }
        final passage = OfficialPassage(
          book: book,
          section: section,
          extraction: extracted,
        );
        final generated = GroundedStudyService().flashcards(passage);
        return _DeckScaffold(
          passage: passage,
          generated: generated,
        );
      },
    );
  }

  OfficialBook? _findBook(OfficialBookCatalog? catalog) {
    if (catalog == null) return null;
    for (final book in catalog.books) {
      if (book.id == bookId) return book;
    }
    return null;
  }
}

class _DeckScaffold extends ConsumerStatefulWidget {
  const _DeckScaffold({required this.passage, required this.generated});

  final OfficialPassage passage;
  final List<RecallCard> generated;

  @override
  ConsumerState<_DeckScaffold> createState() => _DeckScaffoldState();
}

enum _DeckFilter { all, due, fresh }

class _DeckScaffoldState extends ConsumerState<_DeckScaffold> {
  late List<RecallCard> _cards;
  _DeckFilter _filter = _DeckFilter.all;
  int _index = 0;
  bool _revealed = false;
  bool _queued = false;
  final Map<ReviewGrade, int> _session = {
    ReviewGrade.knew: 0,
    ReviewGrade.again: 0,
    ReviewGrade.difficult: 0,
  };

  @override
  void initState() {
    super.initState();
    final existing = ref
        .read(reviewQueueProvider)
        .forSection(widget.passage.section.id);
    _cards = existing.isEmpty
        ? List<RecallCard>.of(widget.generated)
        : List<RecallCard>.of(existing);
    if (existing.isEmpty && widget.generated.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _addGeneratedToQueue();
      });
    }
  }

  void _addGeneratedToQueue() {
    if (_queued) return;
    _queued = true;
    final queue = ReviewQueue(
      cards: List<RecallCard>.of(ref.read(reviewQueueProvider).cards),
    );
    queue.addAll(widget.generated);
    ref.read(reviewQueueProvider.notifier).state = queue;
  }

  List<RecallCard> get _visible {
    final now = DateTime.now();
    return switch (_filter) {
      _DeckFilter.all => _cards,
      _DeckFilter.due => _cards.where((card) => card.isDue(now)).toList(),
      _DeckFilter.fresh => _cards.where((card) => card.reviews == 0).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;
    final total = _cards.length;
    if (total == 0) {
      return Scaffold(
        appBar: AppBar(title: const TrText('بطاقات الدرس')),
        body: const EmptyState(
          icon: Icons.style_outlined,
          title: 'مفيش بطاقات كفاية',
          message:
              'الدرس مفيهوش مصطلحات أو جمل واضحة نبني منها بطاقات. '
              'افتح النص الأصلي وذاكر منه.',
        ),
      );
    }
    if (visible.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const TrText('بطاقات الدرس')),
        body: Column(
          children: [
            _FilterBar(
              filter: _filter,
              counts: _counts(),
              onChanged: (value) => setState(() {
                _filter = value;
                _index = 0;
                _revealed = false;
              }),
            ),
            Expanded(
              child: EmptyState(
                icon: Icons.event_available_rounded,
                title: 'مفيش بطاقات مستحقة دلوقتي',
                message:
                    'كل بطاقات الفلتر ده اتراجعت ومواعيدها جاية. '
                    'تقدر تشوف كل البطاقات أو ترجع للدرس.',
                action: FilledButton.tonal(
                  onPressed: () => setState(() => _filter = _DeckFilter.all),
                  child: const TrText('كل البطاقات'),
                ),
              ),
            ),
          ],
        ),
      );
    }
    _index = _index.clamp(0, visible.length - 1);
    final card = visible[_index];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrText(
              'بطاقات الدرس',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            TrText(
              '${_index + 1} من ${visible.length} · ${widget.passage.citationLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _FilterBar(
            filter: _filter,
            counts: _counts(),
            onChanged: (value) => setState(() {
              _filter = value;
              _index = 0;
              _revealed = false;
            }),
          ),
          if (!widget.passage.isCurrentEdition)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
              child: TrText(
                'البطاقات دي من طبعة قديمة. أعد الاستخراج بعد تحديث الكتاب.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ZakerColors.danger,
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                ZakerSpacing.sm,
                ZakerSpacing.lg,
                ZakerSpacing.sm,
              ),
              child: _Flashcard(card: card, revealed: _revealed),
            ),
          ),
          if (_revealed)
            _GradeBar(onGrade: _grade)
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZakerSpacing.lg,
                0,
                ZakerSpacing.lg,
                ZakerSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _revealed = true),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const TrText('اكشف الإجابة'),
                ),
              ),
            ),
          _SourceRow(
            passage: widget.passage,
            card: card,
            onOpen: () => context.push(
              ZakerRoutes.officialSectionPath(
                widget.passage.book.id,
                widget.passage.section.id,
              ),
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
        ],
      ),
    );
  }

  Map<_DeckFilter, int> _counts() => {
    _DeckFilter.all: _cards.length,
    _DeckFilter.due: _cards.where((card) => card.isDue()).length,
    _DeckFilter.fresh: _cards.where((card) => card.reviews == 0).length,
  };

  void _grade(ReviewGrade grade) {
    final visible = _visible;
    if (visible.isEmpty) return;
    final card = visible[_index.clamp(0, visible.length - 1)];
    final updated = card.graded(grade);
    final index = _cards.indexWhere((item) => item.id == updated.id);
    if (index >= 0) _cards[index] = updated;

    final queue = ReviewQueue(
      cards: List<RecallCard>.of(ref.read(reviewQueueProvider).cards),
    );
    final queueIndex = queue.cards.indexWhere((item) => item.id == updated.id);
    if (queueIndex >= 0) {
      queue.cards[queueIndex] = updated;
    } else {
      queue.cards.add(updated);
    }
    ref.read(reviewQueueProvider.notifier).state = queue;

    setState(() {
      _session[grade] = (_session[grade] ?? 0) + 1;
      _revealed = false;
      final nextVisible = _visible;
      if (nextVisible.isEmpty) {
        _index = 0;
      } else if (_filter == _DeckFilter.all) {
        _index = (_index + 1) % nextVisible.length;
      } else {
        _index = _index.clamp(0, nextVisible.length - 1);
      }
    });
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  final _DeckFilter filter;
  final Map<_DeckFilter, int> counts;
  final ValueChanged<_DeckFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: ZakerSpacing.lg,
        vertical: ZakerSpacing.sm,
      ),
      child: Row(
        children: [
          _chip('كل البطاقات', _DeckFilter.all),
          const SizedBox(width: 6),
          _chip('مستحقة', _DeckFilter.due),
          const SizedBox(width: 6),
          _chip('جديدة', _DeckFilter.fresh),
        ],
      ),
    );
  }

  Widget _chip(String label, _DeckFilter value) => ChoiceChip(
    label: Text('$label · ${counts[value] ?? 0}'),
    selected: filter == value,
    onSelected: (_) => onChanged(value),
  );
}

class _Flashcard extends StatelessWidget {
  const _Flashcard({required this.card, required this.revealed});

  final RecallCard card;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey('${card.id}-$revealed'),
        width: double.infinity,
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZakerRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: revealed
                ? [
                    ZakerColors.success.withValues(alpha: 0.12),
                    theme.colorScheme.surface,
                  ]
                : [
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                    theme.colorScheme.surface,
                  ],
          ),
          border: Border.all(
            color: (revealed
                    ? ZakerColors.success
                    : theme.colorScheme.primary)
                .withValues(alpha: 0.25),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    revealed
                        ? Icons.check_circle_outline_rounded
                        : Icons.help_outline_rounded,
                    size: 16,
                    color: revealed
                        ? ZakerColors.success
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  TrText(
                    revealed ? 'الإجابة' : 'السؤال',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TrText(
                    '${card.reviews} مراجعة',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZakerSpacing.md),
              TrText(
                revealed ? (card.back?.text ?? '') : card.front.text,
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!revealed && card.front.hint.isNotEmpty) ...[
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  card.front.hint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              if (revealed && card.sourcePage != null) ...[
                const SizedBox(height: ZakerSpacing.md),
                _TinySource(page: card.sourcePage!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TinySource extends StatelessWidget {
  const _TinySource({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 12),
          const SizedBox(width: 4),
          TrText(
            'من صفحة $page',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _GradeBar extends StatelessWidget {
  const _GradeBar({required this.onGrade});

  final ValueChanged<ReviewGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _GradeButton(
              label: 'راجعها',
              icon: Icons.replay_rounded,
              color: ZakerColors.danger,
              onPressed: () => onGrade(ReviewGrade.again),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _GradeButton(
              label: 'صعبة',
              icon: Icons.sentiment_dissatisfied_outlined,
              color: ZakerColors.accent,
              onPressed: () => onGrade(ReviewGrade.difficult),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _GradeButton(
              label: 'عرفتها',
              icon: Icons.check_rounded,
              color: ZakerColors.success,
              onPressed: () => onGrade(ReviewGrade.knew),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readable = readableTextColor(color, theme.colorScheme.surface);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: readable,
        side: BorderSide(color: readable.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.passage,
    required this.card,
    required this.onOpen,
  });

  final OfficialPassage passage;
  final RecallCard card;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: TrText(
              'المصدر: «${passage.book.titleAr}» · '
              '${card.sourcePage == null ? passage.citationLabel : 'صفحة ${card.sourcePage}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.menu_book_outlined, size: 15),
            label: const TrText('افتح الدرس'),
          ),
        ],
      ),
    );
  }
}
