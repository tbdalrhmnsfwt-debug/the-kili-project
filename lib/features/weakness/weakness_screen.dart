/// The weak-points review (`نقاط ضعفي`).
///
/// Shipped strings describe the app grouping the user's mistakes by chapter
/// and pulling the weak spots back for review:
///   * `نقاط ضعفي`
///   * `نقاط ضعفي في {0}`
///   * `راجع نقاط ضعفي`
///   * `الفصل محتاج تثبيت: {0} من {1}. هنراجع النقاط الضعيفة بس.`
///   * `غلطاتك متجمعة`
///   * `غلطاتك متجمعة عشان تراجعها`
///   * `اتعلم من الغلط`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/mistakes.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// How the user is doing in one chapter.
class WeakSpot {
  const WeakSpot({
    required this.chapter,
    required this.total,
    required this.wrong,
  });

  /// The chapter / book the mistakes came from.
  final String chapter;

  /// How many questions were seen.
  final int total;

  /// How many were wrong.
  final int wrong;

  /// The error rate in the range 0..1.
  double get rate => total == 0 ? 0 : wrong / total;

  /// Whether this chapter needs more work.
  bool get weak => rate >= 0.5 && wrong > 0;
}

/// The weak-points screen.
class WeaknessScreen extends ConsumerWidget {
  const WeaknessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebook = ref.watch(mistakesProvider);
    final spots = _spots(notebook.entries);

    return Scaffold(
      appBar: AppBar(title: const TrText('نقاط ضعفي')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _HeaderCard(spots: spots),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_c292c, // راجع نقاط ضعفي
            icon: Icons.trending_down_rounded,
          ),
          if (spots.isEmpty)
            EmptyState(
              icon: Icons.trending_up_rounded,
              title: ZakerStrings.s_4f9d4, // غلطاتك متجمعة
              message: 'ابدأ اختبار قصير — كل غلطة بتتسجل هنا وبتوريني '
                  'نقاط ضعفك.',
              action: FilledButton.icon(
                onPressed: () {
                  ref.read(examSessionProvider.notifier).state = null;
                  ref.read(activeChallengeProvider.notifier).state = null;
                  ref.read(quizTimeLimitProvider.notifier).state = null;
                  context.push(ZakerRoutes.quiz);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const TrText('اختبر نفسك'),
              ),
            )
          else
            for (final s in spots) _WeakSpotTile(spot: s),
          const SizedBox(height: ZakerSpacing.lg),
          FeatureTile(
            title: ZakerStrings.s_10f87, // اتعلم من الغلط
            subtitle: ZakerStrings.s_32870, // راجع النقاط الضعيفة
            icon: Icons.school_rounded,
            onTap: () => context.push(ZakerRoutes.mistakes),
          ),
        ],
      ),
    );
  }

  /// Groups the mistakes by chapter, weakest first.
  List<WeakSpot> _spots(List<MistakeEntry> entries) {
    final byChapter = <String, List<MistakeEntry>>{};
    for (final e in entries) {
      byChapter.putIfAbsent(e.bookId, () => <MistakeEntry>[]).add(e);
    }
    final spots = <WeakSpot>[];
    byChapter.forEach((chapter, list) {
      final wrong = list.where((e) => e.timesWrong > 0).length;
      spots.add(WeakSpot(chapter: chapter, total: list.length, wrong: wrong));
    });
    spots.sort((a, b) => b.rate.compareTo(a.rate));
    return spots;
  }
}

/// The summary card at the top.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.spots});

  final List<WeakSpot> spots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weak = spots.where((s) => s.weak).toList();

    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: ZakerColors.navyGradient,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            spots.isEmpty
                ? 'لسه مفيش غلطات متسجلة — ابدأ اختبار وهنرصد نقاط ضعفك.'
                : 'الفصل محتاج تثبيت: ${weak.length} من ${spots.length}. '
                      'هنراجع النقاط الضعيفة بس.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '${spots.length}',
                label: 'فصل',
                icon: Icons.menu_book_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${weak.length}',
                label: 'ضعيف',
                icon: Icons.trending_down_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single chapter's weak spot.
class _WeakSpotTile extends StatelessWidget {
  const _WeakSpotTile({required this.spot});

  final WeakSpot spot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = spot.weak ? ZakerColors.danger : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
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
              children: [
                Expanded(
                  child: TrText(
                    'نقاط ضعفي في ${spot.chapter}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TrText(
                  'ضعيف في',
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: ZakerSpacing.sm),
            ProgressBar(value: spot.rate, height: 8, color: color),
            const SizedBox(height: ZakerSpacing.xs),
            TrText(
              '${spot.wrong} غلطة من ${spot.total}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
