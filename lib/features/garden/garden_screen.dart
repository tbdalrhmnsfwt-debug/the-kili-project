/// The garden (`الحديقة`) that grows with each studied day.
///
/// Shipped strings this screen is built from:
///   * `الحديقة`
///   * `الحديقة بتنمو بالأيام — شوفني بكرة 🌙`
///   * `بقعة جديدة مستنياك في الحديقة 🌱`
///   * `الزراعة`
///   * `حديقتك كملت {0} يوم — {1} نقطة، وأطول سلسلة {2} يوم.`
///   * `كل جلسة بتخلصها بتكسبك نقاط وبتزود سلسلة أيامك.`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/leaderboard.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The garden screen.
class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garden = ref.watch(gardenProvider);
    final plots = [...garden.plots]..sort((a, b) => a.day.compareTo(b.day));

    return Scaffold(
      appBar: AppBar(title: const Text('الحديقة')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _GardenHeader(garden: garden),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(title: 'الزراعة', icon: Icons.grass_rounded),
          if (plots.isEmpty)
            const EmptyState(
              icon: Icons.yard_outlined,
              title: 'بقعة جديدة مستنياك في الحديقة 🌱',
              message: 'الحديقة بتنمو بالأيام — شوفني بكرة 🌙',
            )
          else
            for (final plot in plots) _PlotTile(plot: plot),
        ],
      ),
    );
  }
}

/// The header card with the garden's totals.
class _GardenHeader extends StatelessWidget {
  const _GardenHeader({required this.garden});

  final Garden garden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: ZakerRadius.card,
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, ZakerColors.primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حديقتك كملت ${garden.longestStreak} يوم — '
            '${garden.totalPoints} نقطة، وأطول سلسلة ${garden.longestStreak} يوم.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            'كل جلسة بتخلصها بتكسبك نقاط وبتزود سلسلة أيامك.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '${garden.plots.length}',
                label: 'يوم',
                icon: Icons.eco_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${garden.totalPoints}',
                label: 'نقطة',
                icon: Icons.stars_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single planted day.
class _PlotTile extends StatelessWidget {
  const _PlotTile({required this.plot});

  final GardenPlot plot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            Icon(Icons.park_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plot.day.year}/${plot.day.month}/${plot.day.day}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'سلسلة ${plot.streak} يوم',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatChip(
              value: '${plot.points}',
              label: 'نقطة',
              icon: Icons.stars_outlined,
            ),
          ],
        ),
      ),
    );
  }
}
