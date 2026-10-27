/// The weekly leaderboard: points, streaks and the garden.
///
/// Shipped strings this screen is built from:
///   * `المتصدرين`
///   * `نقاط`
///   * `نقاطك`
///   * `أطول سلسلة`
///   * `شاراتك ونقاطك وسلسلة أيام مذاكرتك.`
///   * `{0} تحدي، {1} نقطة، أطول سلسلة {2}`
///   * `تحدي مباشر`
///   * `تحدي مباشر شغال دلوقتي`
///   * `تحدي مباشر مستنيك`
///   * `ابدأه تحدي مباشر`
///   * `تحدي {0}`
///   * `تحدي مباشر: {0}`
///   * `كل جلسة بتخلصها بتكسبك نقاط وبتزود سلسلة أيامك.`
///   * `ركز في مذاكرتك، وكل جلسة بتخلصها بتكسبك نقاط 🌟`
///   * `الدقايق دي من جلسات التركيز، وبتحسبلك في المتصدرين.`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/leaderboard.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../garden/garden_screen.dart';
import '../../widgets/tr_text.dart';

/// The leaderboard screen.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(leaderboardProvider);
    final live = ref.watch(liveLeaderboardProvider);

    // Local rows win over their server copies: the local row reflects what
    // happened on this device right now, the server copy may lag behind.
    final byUser = <String, LeaderboardRow>{};
    for (final row in live.valueOrNull ?? const <LeaderboardRow>[]) {
      byUser[row.userId] = row;
    }
    for (final row in week.rows) {
      byUser[row.userId] = row;
    }
    final ranked = byUser.values.toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    LeaderboardRow? me;
    for (final r in ranked) {
      if (r.isMe) {
        me = r;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const TrText('المتصدرين'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(liveLeaderboardProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _MyStatsCard(week: week, me: me),
          const SizedBox(height: ZakerSpacing.lg),
          if (ranked.isEmpty)
            const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'مفيش نقاط لسه',
              message: 'ركز في مذاكرتك، وكل جلسة بتخلصها بتكسبك نقاط 🌟',
            )
          else
            for (var i = 0; i < ranked.length; i++)
              _LeaderboardRow(rank: i + 1, row: ranked[i]),
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: 'حديقتك',
            icon: Icons.grain_rounded,
            actionLabel: 'الحديقة',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GardenScreen()),
            ),
          ),
          const _GardenSummary(),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: 'تحدي مباشر',
            icon: Icons.bolt_rounded,
          ),
          FeatureTile(
            title: 'تحدي مباشر',
            subtitle: 'تحدي مباشر شغال دلوقتي',
            icon: Icons.bolt_rounded,
            onTap: () => context.push(ZakerRoutes.challenges),
          ),
        ],
      ),
    );
  }
}

/// The user's own points / streak summary.
class _MyStatsCard extends StatelessWidget {
  const _MyStatsCard({required this.week, required this.me});

  final LeaderboardWeek week;
  final LeaderboardRow? me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = me?.points ?? 0;
    final streak = me?.streak ?? 0;
    final challenges = me?.solved ?? 0;

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
            '$challenges تحدي، $points نقطة، أطول سلسلة $streak',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            'شاراتك ونقاطك وسلسلة أيام مذاكرتك.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '$points',
                label: 'نقاطك',
                icon: Icons.stars_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '$streak',
                label: 'أطول سلسلة',
                icon: Icons.local_fire_department_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single leaderboard row.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.row});

  final int rank;
  final LeaderboardRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = row.focusSeconds ~/ 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(
            color: row.isMe
                ? theme.colorScheme.primary
                : theme.dividerTheme.color ?? Colors.black12,
          ),
        ),
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrText(
                    row.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TrText(
                    '${row.points} نقطة · ${row.solved} تحدي',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatChip(
              value: '$minutes د',
              label: 'تركيز',
              icon: Icons.timer_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

/// The rank number badge (gold / silver / bronze for the top three).
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (rank) {
      1 => const Color(0xFFFFB300),
      2 => const Color(0xFF9CA3AF),
      3 => const Color(0xFFCD7F32),
      _ => theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    };

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: TrText(
        '$rank',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// A short summary of the garden that links to the full garden screen.
class _GardenSummary extends ConsumerWidget {
  const _GardenSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final garden = ref.watch(gardenProvider);

    return Container(
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
            child: TrText(
              'حديقتك كملت ${garden.longestStreak} يوم — '
              '${garden.totalPoints} نقطة، وأطول سلسلة ${garden.longestStreak} يوم.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
