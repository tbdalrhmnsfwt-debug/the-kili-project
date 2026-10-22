/// The challenges screen: the daily challenge, speed runs and the live
/// challenge arena.
///
/// All Arabic text is a [ZakerStrings] constant so it is byte-identical to
/// the shipped app.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/live_service.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/arena.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';

/// The challenges screen.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(challengesProvider);
    final shared =
        ref.watch(liveChallengesProvider).valueOrNull ?? const <Challenge>[];
    final localIds = local.map((c) => c.id).toSet();
    final challenges = <Challenge>[
      ...local,
      for (final c in shared)
        if (!localIds.contains(c.id)) c,
    ];
    final results = ref.watch(challengeResultsProvider);
    final live = challenges.where((c) => !c.over).toList();
    final past = challenges.where((c) => c.over).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('تحديات')),
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          const _DailyChallengeCard(),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_71880, // تحدي السرعة
            icon: Icons.bolt_rounded,
          ),
          Row(
            children: const [
              Expanded(
                child: FeatureTile(
                  title: ZakerStrings.s_dd129, // تحدي ٣٠ ثانية
                  subtitle: ZakerStrings.s_dfb31, // اختيارات وتحديات قصيرة
                  icon: Icons.timer_rounded,
                ),
              ),
              SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: FeatureTile(
                  title: ZakerStrings.s_f628c, // تحدي ٦٠ ثانية
                  subtitle: ZakerStrings.s_dfb31,
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: ZakerStrings.s_1da21, // تحدي مع صحابك
            icon: Icons.groups_rounded,
          ),
          Text(ZakerStrings.s_ffc10), // العب مع صحابك لحظيا…
          const SizedBox(height: ZakerSpacing.md),
          FilledButton.icon(
            onPressed: () => _createDirect(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('اعمل تحدي مباشر'),
          ),
          const SizedBox(height: ZakerSpacing.md),
          if (live.isEmpty)
            const EmptyState(
              icon: Icons.bolt_outlined,
              title: ZakerStrings.s_d2734, // مفيش تحدي مفتوح
              message: ZakerStrings.s_bf817, // التحديات لسه بتتجهز — جرب بعد شوية.
            )
          else
            for (final c in live) _ChallengeTile(challenge: c),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: ZakerStrings.s_3cdfa, // تحديات سابقة
            icon: Icons.history_rounded,
          ),
          if (past.isEmpty && results.isEmpty)
            const EmptyState(
              icon: Icons.flag_outlined,
              title: ZakerStrings.s_bf817,
              message: ZakerStrings.s_671b2, // تحدي يومي قصير يخليك مذاكر كل يوم.
            )
          else
            for (final c in past) _ChallengeTile(challenge: c),
        ],
      ),
    );
  }

  /// Opens a direct challenge: a six-character room code the user can send
  /// to a friend. When live sync is on the challenge is published; otherwise
  /// it stays on this device.
  Future<void> _createDirect(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authUserProvider);
    final now = DateTime.now();
    final challenge = Challenge(
      id: 'direct-${now.millisecondsSinceEpoch}',
      title: 'تحدي مباشر',
      kind: ChallengeKind.direct,
      code: _roomCode(),
      questionCount: 10,
      timeLimitSeconds: 60,
      points: 10,
      hostName: user?.displayName ?? 'لاعب',
      createdAt: now,
    );
    ref.read(challengesProvider.notifier).state = [
      challenge,
      ...ref.read(challengesProvider),
    ];

    final config = ref.read(liveConfigProvider);
    final shared = LiveService.canSync(config)
        ? await ref
              .read(liveServiceProvider)
              .publishChallenge(challenge, config)
        : false;
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحدي مباشر جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ابعت الكود ده لصاحبك عشان ينضم للتحدي:'),
            const SizedBox(height: ZakerSpacing.md),
            SelectableText(
              challenge.code!,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: ZakerSpacing.md),
            Text(
              shared
                  ? 'التحدي اتنشر على السيرفر — أي حد بيدخل بالكود هيلاقيه.'
                  : 'المزامنة المباشرة مقفولة، فالتحدي محفوظ على جهازك بس.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: challenge.code!));
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('انسخ الكود'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  /// A short, unambiguous room code (no 0/O or 1/I).
  static String _roomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

/// The daily challenge card.
class _DailyChallengeCard extends ConsumerWidget {
  const _DailyChallengeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenges = ref.watch(challengesProvider);
    Challenge? daily;
    for (final c in challenges) {
      if (c.kind == ChallengeKind.daily) {
        daily = c;
        break;
      }
    }

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
            ZakerStrings.s_d0b54, // تحدي النهارده
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          Text(
            daily == null
                ? ZakerStrings.s_4f071 // بنجهزلك تحدي النهارده...
                : ZakerStrings.s_00591, // تحدي النهارده جاهز! ⚡
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              StatChip(
                value: '${daily?.questionCount ?? 10}',
                label: 'سؤال',
                icon: Icons.quiz_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              StatChip(
                value: '${daily?.points ?? 8}',
                label: 'نقطة',
                icon: Icons.stars_rounded,
                color: Colors.white,
              ),
            ],
          ),
          if (daily != null) ...[
            const SizedBox(height: ZakerSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
              ),
              onPressed: () => _play(context, ref, daily!),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(ZakerStrings.s_d19ff), // تحدي النهارده مستنيك
            ),
          ],
        ],
      ),
    );
  }

  /// Marks the daily challenge as finished and awards the points.
  void _play(BuildContext context, WidgetRef ref, Challenge challenge) {
    final challenges = ref.read(challengesProvider);
    ref.read(challengesProvider.notifier).state = [
      for (final c in challenges)
        if (c.id == challenge.id)
          Challenge(
            id: c.id,
            title: c.title,
            kind: c.kind,
            status: ChallengeStatus.finished,
            code: c.code,
            questionCount: c.questionCount,
            timeLimitSeconds: c.timeLimitSeconds,
            points: c.points,
            hostName: c.hostName,
            joinedBy: c.joinedBy,
            createdAt: c.createdAt,
            finishedAt: DateTime.now(),
          )
        else
          c,
    ];

    final results = ref.read(challengeResultsProvider);
    ref.read(challengeResultsProvider.notifier).state = [
      ChallengeResult(
        challengeId: challenge.id,
        score: challenge.points,
        total: challenge.questionCount,
        correct: challenge.questionCount,
        finishedAt: DateTime.now(),
      ),
      ...results,
    ];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ZakerStrings.s_8_c721a), // خلصت تحدي النهارده — 8 نقط في رصيدك 🎉
      ),
    );
  }
}

/// A single challenge row.
class _ChallengeTile extends ConsumerWidget {
  const _ChallengeTile({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusLabel = switch (challenge.status) {
      ChallengeStatus.open => ZakerStrings.s_bfd22, // تحدي مباشر مستنيك
      ChallengeStatus.live => ZakerStrings.s_536da, // تحدي مباشر شغال دلوقتي
      ChallengeStatus.finished => ZakerStrings.s_51f4a, // التحدي اتقفل
      ChallengeStatus.closed => ZakerStrings.s_51f4a,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: challenge.over ? null : () => _play(context, ref),
          borderRadius: ZakerRadius.card,
          child: Container(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: ZakerRadius.card,
              border: Border.all(
                color: theme.dividerTheme.color ?? Colors.black12,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (challenge.code != null)
                  StatChip(
                    value: challenge.code!,
                    label: ZakerStrings.s_5413e, // غرفة التحدي
                    icon: Icons.qr_code_rounded,
                  )
                else
                  StatChip(
                    value: '${challenge.points}',
                    label: 'نقطة',
                    icon: Icons.stars_outlined,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Marks the challenge as finished, records the result, and shares both
  /// with the backend when live sync is enabled.
  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authUserProvider);
    final now = DateTime.now();
    final name = user?.displayName ?? 'لاعب';
    final finished = Challenge(
      id: challenge.id,
      title: challenge.title,
      kind: challenge.kind,
      status: ChallengeStatus.finished,
      code: challenge.code,
      questionCount: challenge.questionCount,
      timeLimitSeconds: challenge.timeLimitSeconds,
      points: challenge.points,
      hostName: challenge.hostName,
      joinedBy: name,
      createdAt: challenge.createdAt,
      finishedAt: now,
    );

    final current = ref.read(challengesProvider);
    final replaced = current.any((c) => c.id == challenge.id);
    ref.read(challengesProvider.notifier).state = [
      if (!replaced) finished,
      for (final c in current)
        if (c.id == challenge.id) finished else c,
    ];

    final result = ChallengeResult(
      challengeId: challenge.id,
      score: challenge.points,
      total: challenge.questionCount,
      correct: challenge.questionCount,
      finishedAt: now,
    );
    ref.read(challengeResultsProvider.notifier).state = [
      result,
      ...ref.read(challengeResultsProvider),
    ];

    final config = ref.read(liveConfigProvider);
    if (LiveService.canSync(config)) {
      final service = ref.read(liveServiceProvider);
      await service.joinChallenge(
        challenge.id,
        name: name,
        status: ChallengeStatus.finished,
        config: config,
      );
      if (user != null) {
        await service.publishResult(result, user.uid, config);
        final week = ref.read(leaderboardProvider);
        for (final row in week.rows) {
          if (row.isMe) {
            await service.publishRow(week.weekStart, row, config);
            break;
          }
        }
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('خلصت ${challenge.title} — ${challenge.points} نقطة 🎉'),
      ),
    );
  }
}
