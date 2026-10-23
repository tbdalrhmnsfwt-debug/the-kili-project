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

import '../../core/recall_card_builder.dart';
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
  bool? _lastCorrect;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(reviewQueueProvider);
    final due = queue.due();

    return Scaffold(
      appBar: AppBar(
        title: const TrText('استرجاع نشط'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: ZakerSpacing.lg),
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
                      card: due[_index.clamp(0, due.length - 1)],
                      revealed: _revealed,
                      onReveal: () => setState(() => _revealed = true),
                    ),
                  ),
                ),
                if (_revealed)
                  _GradingBar(onGrade: _grade, lastCorrect: _lastCorrect)
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

  void _grade(bool correct) {
    final queue = ref.read(reviewQueueProvider);
    final due = queue.due();
    if (due.isEmpty) return;
    final card = due[_index.clamp(0, due.length - 1)];

    final updated = card.reviewed(wasCorrect: correct);
    final cards = [
      for (final c in queue.cards)
        if (c.id == updated.id) updated else c,
    ];

    setState(() {
      ref.read(reviewQueueProvider.notifier).state = ReviewQueue(cards: cards);
      _revealed = false;
      _lastCorrect = correct;
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
  });

  final RecallCard card;
  final bool revealed;
  final VoidCallback onReveal;

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

/// The "صح / خطأ" grading bar.
class _GradingBar extends StatelessWidget {
  const _GradingBar({required this.onGrade, this.lastCorrect});

  final ValueChanged<bool> onGrade;
  final bool? lastCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
      child: Column(
        children: [
          if (lastCorrect != null)
            Padding(
              padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
              child: TrText(
                lastCorrect! ? 'مظبوط 👌' : 'الإجابة الصح فوق',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: lastCorrect!
                      ? ZakerColors.success
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onGrade(false),
                  icon: const Icon(Icons.close_rounded),
                  label: const TrText('غلط'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZakerColors.danger,
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onGrade(true),
                  icon: const Icon(Icons.check_rounded),
                  label: const TrText('صح'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ZakerColors.success,
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
