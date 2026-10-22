/// The mistakes notebook (`دفتر أخطائي`).
///
/// Shipped strings this screen is built from:
///   * `دفتر أخطائي`
///   * `افتح دفتر أخطائي`
///   * `الأسئلة اللي غلط فيها:`
///   * `مافيش حاجة بتغلط فيها`
///   * `الدفتر فاضي دلوقتي 🎉 كل غلطة جديدة هتتسجل هنا لوحدها.`
///   * `«متأكد وغلط» أخطر خانة — بترجعلك أول حاجة تاني يوم.`
///   * `مراجعة من دفتر أخطائي`
///   * `راجع غلطاتك قبل ما تراجع المنهج — هي دي الدرجات الضايعة.`
///   * `الكلمات اللي غلطت فيها هترجع لك بدري، واللي عرفتها فورًا هتغيب أكتر.`
///   * `رقمك القياسي {0} — غلط {1}`
///   * `بـ{0} غلطة`
///   * `اتقنته — جاوبته صح ٣ مرات وخرج من الدفتر 🏆`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/mistakes.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The mistakes notebook screen.
class MistakesScreen extends ConsumerWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(mistakesProvider);
    final due = notebook.due();
    final confident = notebook.entries.where((e) => e.confident && !e.mastered).toList();

    return Scaffold(
      appBar: AppBar(
        title: const TrText('دفتر أخطائي'),
        actions: [
          if (due.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'مراجعة من دفتر أخطائي',
              onPressed: () => _review(context, ref, due),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _SummaryCard(notebook: notebook),
          if (confident.isNotEmpty) ...[
            const SizedBox(height: ZakerSpacing.lg),
            const SectionHeader(
              title: '«متأكد وغلط» أخطر خانة',
              icon: Icons.warning_amber_rounded,
            ),
            const TrText(
              '«متأكد وغلط» أخطر خانة — بترجعلك أول حاجة تاني يوم.',
            ),
            const SizedBox(height: ZakerSpacing.md),
            for (final e in confident) _MistakeTile(entry: e),
          ],
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: 'الأسئلة اللي غلط فيها:',
            icon: Icons.error_outline_rounded,
          ),
          if (notebook.entries.isEmpty)
            const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'مافيش حاجة بتغلط فيها',
              message: 'الدفتر فاضي دلوقتي 🎉 كل غلطة جديدة هتتسجل هنا لوحدها.',
            )
          else
            for (final e in notebook.entries) _MistakeTile(entry: e),
        ],
      ),
    );
  }

  /// Marks a due entry as answered correctly and advances it up the ladder.
  void _review(BuildContext context, WidgetRef ref, List<MistakeEntry> due) {
    final notebook = ref.read(mistakesProvider);
    final entry = due.first;
    final updated = entry.passed();

    ref.read(mistakesProvider.notifier).state = MistakeNotebook(
      entries: [
        for (final e in notebook.entries)
          if (e.id == entry.id) updated else e,
      ],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TrText(
          updated.mastered
              ? 'اتقنته — جاوبته صح ٣ مرات وخرج من الدفتر 🏆'
              : 'كويس. بص على السؤال اللي غلطت فيه تاني وانت هتثبته.',
        ),
      ),
    );
  }
}

/// The notebook summary card.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.notebook});

  final MistakeNotebook notebook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            'بـ${notebook.open} غلطة',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            'راجع غلطاتك قبل ما تراجع المنهج — هي دي الدرجات الضايعة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '${notebook.open}',
                label: 'لسه',
                icon: Icons.error_outline_rounded,
                color: ZakerColors.danger,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${notebook.confidentCount}',
                label: 'متأكد وغلط',
                icon: Icons.warning_amber_rounded,
                color: ZakerColors.accent,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${notebook.total - notebook.open}',
                label: 'اتقنها',
                icon: Icons.emoji_events_rounded,
                color: ZakerColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single mistake entry.
class _MistakeTile extends StatelessWidget {
  const _MistakeTile({required this.entry});

  final MistakeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = entry.isDue();

    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(
            color: entry.confident
                ? ZakerColors.accent
                : theme.dividerTheme.color ?? Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.mastered
                      ? Icons.emoji_events_rounded
                      : Icons.help_outline_rounded,
                  size: 20,
                  color: entry.mastered
                      ? ZakerColors.success
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: ZakerSpacing.sm),
                Expanded(
                  child: TrText(
                    entry.prompt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            Row(
              children: [
                StatChip(
                  value: '${entry.timesWrong}',
                  label: 'غلطة',
                  icon: Icons.close_rounded,
                  color: ZakerColors.danger,
                ),
                const SizedBox(width: ZakerSpacing.sm),
                StatChip(
                  value: '${entry.timesCorrect}/3',
                  label: 'صح',
                  icon: Icons.check_rounded,
                  color: ZakerColors.success,
                ),
                const SizedBox(width: ZakerSpacing.sm),
                if (entry.confident)
                  const StatChip(
                    value: 'متأكد وغلط',
                    label: '',
                    icon: Icons.priority_high_rounded,
                    color: ZakerColors.accent,
                  ),
              ],
            ),
            if (entry.correctAnswer.isNotEmpty) ...[
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                'غلط — الصح: ${entry.correctAnswer}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZakerColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (!entry.mastered) ...[
              const SizedBox(height: ZakerSpacing.xs),
              TrText(
                due
                    ? 'موعد المراجعة جه — راجعها دلوقتي.'
                    : 'ترجعلك ${_dueLabel(entry.dueAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A human label for when the entry comes back.
  static String _dueLabel(DateTime? dueAt) {
    if (dueAt == null) return 'بعدين.';
    final days = dueAt.difference(DateTime.now()).inDays;
    if (days <= 0) return 'النهارده.';
    if (days == 1) return 'بكرة.';
    return 'بعد $days يوم.';
  }
}
