/// Achievements, badges and the referral code.
///
/// Shipped strings this screen is built from:
///   * `إنجازاتي`
///   * `{0} فتحت إنجاز: {1}`
///   * `فتحت إنجاز جديد 🏅`
///   * `شارة التوثيق الزرقاء`
///   * `عندك كود دعوة؟` / `كود دعوة (اختياري)`
///   * `مشاركة الدعوة`
///   * `لإتمام توثيق حسابك، كل ما عليك هو دعوة 10 أصدقاء`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../models/planner.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The achievements screen.
class AchievementScreen extends ConsumerWidget {
  const AchievementScreen({super.key});

  /// The catalogue of badges the app can award.
  static const _catalogue =
      <({String id, String name, IconData icon, String desc})>[
        (
          id: 'verified',
          name: 'شارة التوثيق الزرقاء',
          icon: Icons.verified_rounded,
          desc: 'ادعُ 10 أصدقاء يسجّلوا بكودك — الشارة الزرقاء تظهر جنب حسابك.',
        ),
        (
          id: 'streak7',
          name: 'شارع برونزية',
          icon: Icons.workspace_premium_rounded,
          desc: 'ذاكر 7 أيام متتالية.',
        ),
        (
          id: 'streak30',
          name: 'شارع ذهبية',
          icon: Icons.military_tech_rounded,
          desc: 'ذاكر 30 يوم متتالي.',
        ),
        (
          id: 'reciter',
          name: 'شارع القارئ',
          icon: Icons.auto_stories_rounded,
          desc: 'خلصت 10 كتب.',
        ),
        (
          id: 'focus',
          name: 'الإنجاز',
          icon: Icons.local_fire_department_rounded,
          desc: '500 دقيقة تركيز.',
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(studyStatsProvider);
    final unlocked = <String>{
      for (final achievement in ref.watch(achievementsProvider))
        achievement.id,
      if (stats.streakDays >= 7) 'streak7',
      if (stats.streakDays >= 30) 'streak30',
      if (stats.totalMinutes >= 500) 'focus',
    };
    final referral = ref.watch(referralProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إنجازاتي')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          if (referral != null) _ReferralCard(referral: referral),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: 'الشارات',
            icon: Icons.workspace_premium_rounded,
          ),
          for (final badge in _catalogue)
            _BadgeTile(
              name: badge.name,
              description: badge.desc,
              icon: badge.icon,
              unlocked: unlocked.contains(badge.id),
            ),
        ],
      ),
    );
  }
}

/// A single badge row.
class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.name,
    required this.description,
    required this.icon,
    required this.unlocked,
  });

  final String name;
  final String description;
  final IconData icon;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = unlocked
        ? ZakerColors.accent
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(ZakerSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(
            color: unlocked
                ? ZakerColors.accent.withValues(alpha: 0.4)
                : (theme.dividerTheme.color ?? Colors.black12),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              unlocked
                  ? Icons.check_circle_rounded
                  : Icons.lock_outline_rounded,
              color: accent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// The referral card with the invite code.
class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.referral});

  final Referral referral;

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
            'عندك كود دعوة؟',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            'شارك كودك مع أصحابك — كل تسجيل جديد بيقرّبك خطوة من الشارة الزرقاء.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ZakerSpacing.lg,
              vertical: ZakerSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(ZakerRadius.md),
            ),
            child: Center(
              child: Text(
                referral.code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          ProgressBar(
            value: referral.friendCount / Referral.verifiedBadgeThreshold,
            height: 6,
            color: Colors.white,
            background: Colors.white24,
          ),
          const SizedBox(height: ZakerSpacing.sm),
          Text(
            '${referral.friendCount} من ${Referral.verifiedBadgeThreshold} أصدقاء',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.colorScheme.primary,
            ),
            onPressed: () => Share.share(
              'جرّب «ذاكرلي» — تطبيق مذاكرة بالذكاء الاصطناعي 📚\n\n'
              'استخدم كود الدعوة بتاعي وإنت بتعمل حساب:\n'
              '${referral.code}',
            ),
            icon: const Icon(Icons.share_rounded),
            label: const Text('مشاركة الدعوة'),
          ),
        ],
      ),
    );
  }
}
