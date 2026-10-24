/// Active recall: the flashcard review screen.
///
/// Shipped strings this screen is built from:
///   * `استرجاع نشط`
///   * `القراية بتضحك عليك — الاسترجاع بيكشفك`
///   * `{0} كارت · {1} مستنيين مراجعة`
///   * `{0} كارت — {1}٪ صح`
///   * `{0} كارت · مفيش مراجعة دلوقتي`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/recall_card_builder.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/recall.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The active-recall screen.
class ActiveRecallScreen extends ConsumerStatefulWidget {
  const ActiveRecallScreen({super.key});

  @override
  ConsumerState<ActiveRecallScreen> createState() => _ActiveRecallScreenState();
}

class _ActiveRecallScreenState extends ConsumerState<ActiveRecallScreen> {
  int _index = 0;
  bool _revealed = false;
  ReviewGrade? _lastGrade;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(reviewQueueProvider);
    final due = queue.due();
    final current = due.isEmpty ? null : due[_index.clamp(0, due.length - 1)];
    final sourceBook = current?.bookId;
    final sourceSection = current?.sourceSectionId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const TrText('استرجاع نشط'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: ZakerSpacing.lg),
            child: Center(
              child: StatChip(
                value: '${queue.total}',
                label: 'كارت',
                icon: Icons.style_rounded,
              ),
            ),
          ),
        ],
      ),
      body: due.isEmpty
          ? _NoCards(queue: queue)
          : Column(
              children: [
                _Header(queue: queue, due: due.length, index: _index),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(ZakerSpacing.lg),
                    child: _Card(
                      card: current!,
                      revealed: _revealed,
                      onReveal: () => setState(() => _revealed = true),
                      onOpenSource:
                          sourceBook != null &&
                              sourceBook.isNotEmpty &&
                              sourceSection.isNotEmpty
                          ? () => context.push(
                              ZakerRoutes.officialSectionPath(
                                sourceBook,
                                sourceSection,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                if (_revealed)
                  _GradingBar(onGrade: _grade, lastGrade: _lastGrade)
                else
                  Padding(
                    padding: const EdgeInsets.all(ZakerSpacing.lg),
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _revealed = true),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const TrText('اكشف الإجابة'),
                    ),
                  ),
                const SizedBox(height: ZakerSpacing.md),
              ],
            ),
    );
  }

  void _grade(ReviewGrade grade) {
    final queue = ref.read(reviewQueueProvider);
    final due = queue.due();
    if (due.isEmpty) return;
    final card = due[_index.clamp(0, due.length - 1)];

    final updated = card.graded(grade);
    final cards = [
      for (final c in queue.cards)
        if (c.id == updated.id) updated else c,
    ];

    setState(() {
      ref.read(reviewQueueProvider.notifier).state = ReviewQueue(cards: cards);
      _revealed = false;
      _lastGrade = grade;
      final nextDue = ref.read(reviewQueueProvider).due();
      if (_index >= nextDue.length) _index = 0;
    });
  }
}

/// The header showing queue stats and progress.
class _Header extends StatelessWidget {
  const _Header({required this.queue, required this.due, required this.index});

  final ReviewQueue queue;
  final int due;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracyPercent = (queue.accuracy * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZakerSpacing.lg,
        ZakerSpacing.md,
        ZakerSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            due == 0 ? 'مفيش مراجعة دلوقتي' : '$due كارت · مستنيين مراجعة',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          ProgressBar(value: due == 0 ? 0 : (index + 1) / due, height: 6),
          const SizedBox(height: ZakerSpacing.md),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              StatChip(
                value: '$accuracyPercent٪',
                label: 'صح',
                icon: Icons.check_circle_outline_rounded,
                color: ZakerColors.success,
              ),
              StatChip(
                value: '${queue.cards.where((c) => c.reviews > 0).length}',
                label: 'اتراجعوا',
                icon: Icons.history_rounded,
                color: ZakerColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The flashcard itself.
class _Card extends StatelessWidget {
  const _Card({
    required this.card,
    required this.revealed,
    required this.onReveal,
    this.onOpenSource,
  });

  final RecallCard card;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: revealed ? null : onReveal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            Center(
              child: Chip(
                label: TrText(card.kind.arabicLabel),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: ZakerSpacing.lg),
            TrText(
              card.front.text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.7,
                fontFamily: card.kind == CardKind.written ? 'Amiri' : 'Cairo',
              ),
            ),
            if (card.front.hint.isNotEmpty) ...[
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                card.front.hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (revealed) ...[
              const SizedBox(height: ZakerSpacing.xl),
              const Divider(),
              const SizedBox(height: ZakerSpacing.lg),
              TrText(
                card.back?.text ?? '',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  height: 1.7,
                ),
              ),
              if ((card.back?.hint ?? '').isNotEmpty) ...[
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  card.back!.hint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (card.sourcePage != null) ...[
                const SizedBox(height: ZakerSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: TrText(
                        card.sourceBookTitle.isEmpty
                            ? 'صفحة ${card.sourcePage}'
                            : 'صفحة ${card.sourcePage} · ${card.sourceBookTitle}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (onOpenSource != null) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: onOpenSource,
                        child: const TrText('افتح الدرس'),
                      ),
                    ],
                  ],
                ),
              ],
            ] else ...[
              const SizedBox(height: ZakerSpacing.xl),
              TrText(
                'دوس على الكارت عشان تشوف الإجابة',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three-way rating bar shared with the official flashcard screen.
class _GradingBar extends StatelessWidget {
  const _GradingBar({required this.onGrade, this.lastGrade});

  final ValueChanged<ReviewGrade> onGrade;
  final ReviewGrade? lastGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
      child: Column(
        children: [
          if (lastGrade != null)
            Padding(
              padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
              child: TrText(
                switch (lastGrade!) {
                  ReviewGrade.knew => 'تمام 👌 هترجع في موعد أبعد',
                  ReviewGrade.difficult => 'هترجع بكره عشان تثبت',
                  ReviewGrade.again => 'هترجع بعد شوية — الإجابة فوق',
                },
                style: theme.textTheme.bodySmall?.copyWith(
                  color: lastGrade == ReviewGrade.knew
                      ? ZakerColors.success
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onGrade(ReviewGrade.again),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZakerColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_rounded, size: 18),
                      SizedBox(height: 2),
                      TrText('راجعها', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onGrade(ReviewGrade.difficult),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: readableTextColor(
                      ZakerColors.accent,
                      theme.colorScheme.surface,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sentiment_dissatisfied_outlined, size: 18),
                      SizedBox(height: 2),
                      TrText('صعبة', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  onPressed: () => onGrade(ReviewGrade.knew),
                  style: FilledButton.styleFrom(
                    backgroundColor: readableTextColor(
                      ZakerColors.success,
                      Colors.white,
                    ),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 18),
                      SizedBox(height: 2),
                      TrText('عرفتها', style: TextStyle(fontSize: 11)),
                    ],
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

/// The empty state, with an action that builds cards from the library.
class _NoCards extends ConsumerStatefulWidget {
  const _NoCards({required this.queue});

  final ReviewQueue queue;

  @override
  ConsumerState<_NoCards> createState() => _NoCardsState();
}

class _NoCardsState extends ConsumerState<_NoCards> {
  bool _working = false;

  /// Builds recall cards on-device from the readable textbooks.
  Future<void> _build() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final cards = await buildRecallCards(
        service: ref.read(assetServiceProvider),
        grades: await ref.read(gradesProvider.future),
      );
      if (!mounted) return;
      ref.read(reviewQueueProvider.notifier).state = ReviewQueue(cards: cards);
      if (cards.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: TrText('مفيش كتب مقروءة على الجهاز — افتح مكتبتك الأول.'),
            ),
          );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: TrText('مش قادر أجهز الكروت دلوقتي.')),
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    if (queue.cards.isEmpty) {
      return EmptyState(
        icon: Icons.style_outlined,
        title: 'مفيش كروت لسه',
        message: 'جهّز كروت من كتبك — هنحوّل كل فقرة لسؤال مراجعة.',
        action: FilledButton.icon(
          onPressed: _working ? null : _build,
          icon: _working
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: TrText(_working ? 'بنجهز الكروت…' : 'جهّز كروت من كتبك'),
        ),
      );
    }
    return EmptyState(
      icon: Icons.check_circle_outline_rounded,
      title: 'مفيش مراجعة دلوقتي',
      message: 'كل الكروت مستنية دورتها. تقدر تراجعها بدري لو عايز.',
      action: FilledButton(
        onPressed: () {
          final now = DateTime.now();
          ref.read(reviewQueueProvider.notifier).state = ReviewQueue(
            cards: [
              for (final card in queue.cards) card.copyWith(dueAt: now),
            ],
          );
        },
        child: TrText('راجع الـ ${queue.total} كارت'),
      ),
    );
  }
}
