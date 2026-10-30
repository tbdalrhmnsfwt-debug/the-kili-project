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
import 'package:go_router/go_router.dart';

import '../../core/live_service.dart';
import '../../core/router.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/arena.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

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
    final orphanResults = _orphanResults(past, results);

    return Scaffold(
      appBar: AppBar(title: const TrText('تحديات')),
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
            children: [
              Expanded(
                child: FeatureTile(
                  title: ZakerStrings.s_dd129, // تحدي ٣٠ ثانية
                  subtitle: ZakerStrings.s_dfb31, // اختيارات وتحديات قصيرة
                  icon: Icons.timer_rounded,
                  onTap: () => _startSpeed(context, ref, 30),
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: FeatureTile(
                  title: ZakerStrings.s_f628c, // تحدي ٦٠ ثانية
                  subtitle: ZakerStrings.s_dfb31,
                  icon: Icons.timer_outlined,
                  onTap: () => _startSpeed(context, ref, 60),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: ZakerStrings.s_1da21, // تحدي مع صحابك
            icon: Icons.groups_rounded,
          ),
          TrText(ZakerStrings.s_ffc10), // العب مع صحابك لحظيا…
          const SizedBox(height: ZakerSpacing.md),
          FilledButton.icon(
            onPressed: () => _createDirect(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const TrText('اعمل تحدي مباشر'),
          ),
          const SizedBox(height: ZakerSpacing.md),
          if (live.isEmpty)
            const EmptyState(
              icon: Icons.bolt_outlined,
              title: ZakerStrings.s_d2734, // مفيش تحدي مفتوح
              message: 'مفيش تحدي مفتوح دلوقتي — اعمل تحدي مباشر وابعت الكود '
                  'لصاحبك.',
            )
          else
            for (final c in live) _ChallengeTile(challenge: c),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: ZakerStrings.s_3cdfa, // تحديات سابقة
            icon: Icons.history_rounded,
          ),
          if (past.isEmpty && orphanResults.isEmpty)
            const EmptyState(
              icon: Icons.flag_outlined,
              title: 'مفيش تحديات سابقة',
              message: ZakerStrings.s_671b2, // تحدي يومي قصير يخليك مذاكر كل يوم.
            )
          else ...[
            for (final c in past) _ChallengeTile(challenge: c),
            for (final result in orphanResults) _ResultTile(result: result),
          ],
        ],
      ),
    );
  }

  /// Results whose challenge is no longer in the local list, e.g. after the
  /// app restarts and only the persisted results remain.
  List<ChallengeResult> _orphanResults(
    List<Challenge> past,
    List<ChallengeResult> results,
  ) {
    final ids = {for (final c in past) c.id};
    return results
        // `quiz-…` ids come from ordinary quiz runs, not challenges.
        .where(
          (r) =>
              !r.challengeId.startsWith('quiz-') &&
              !ids.contains(r.challengeId),
        )
        .take(10)
        .toList(growable: false);
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
        title: const TrText('تحدي مباشر جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrText('ابعت الكود ده لصاحبك عشان ينضم للتحدي:'),
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
            TrText(
              shared
                  ? 'التحدي اتنشر على السيرفر — أي حد بيدخل بالكود هيلاقيه.'
                  : 'المزامنة المباشرة متوقفة، فالتحدي محفوظ على جهازك بس.',
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
            label: const TrText('انسخ الكود'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const TrText('تمام'),
          ),
        ],
      ),
    );
  }

  /// Starts a timed run. The quiz shows the countdown and ends by itself.
  void _startSpeed(BuildContext context, WidgetRef ref, int seconds) {
    ref.read(examSessionProvider.notifier).state = null;
    ref.read(activeChallengeProvider.notifier).state = null;
    ref.read(quizTimeLimitProvider.notifier).state = seconds;
    context.push(ZakerRoutes.quiz);
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
    final results = ref.watch(challengeResultsProvider);
    final dailyId = daily?.id;
    final done =
        daily != null &&
        (daily.over ||
            results.any((r) => r.challengeId == dailyId));

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
            ZakerStrings.s_d0b54, // تحدي النهارده
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            daily == null
                ? 'مفيش تحدي النهارده — اعمل تحدي جديد وابدأ.'
                : done
                ? 'خلصت تحدي النهارده — قابلني بكرة 🌟'
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
                foregroundColor: ZakerColors.navy,
              ),
              onPressed: done ? null : () => _play(context, ref, daily!),
              icon: Icon(
                done ? Icons.task_alt_rounded : Icons.play_arrow_rounded,
              ),
              label: TrText(
                done ? 'تحدي النهارده خلص ✅' : ZakerStrings.s_d19ff,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Runs the challenge as a real, timed quiz. The result is recorded by the
  /// quiz runner from the answers the user actually gives.
  void _play(BuildContext context, WidgetRef ref, Challenge challenge) {
    ref.read(examSessionProvider.notifier).state = null;
    ref.read(activeChallengeProvider.notifier).state = challenge;
    ref.read(quizTimeLimitProvider.notifier).state =
        challenge.timeLimitSeconds > 0 ? challenge.timeLimitSeconds : null;
    context.push(ZakerRoutes.quiz);
  }
}

/// A recorded result, kept for challenges whose local entry is gone (the
/// list is not persisted, but the results are).
class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final ChallengeResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = result.finishedAt;
    final stamp = date == null
        ? ''
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/'
              '${date.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.sm),
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
            Icon(Icons.emoji_events_outlined, color: ZakerColors.accent),
            const SizedBox(width: ZakerSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrText(
                    '${result.correct} من ${result.total} صح',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TrText(
                    stamp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatChip(
              value: '${result.score}',
              label: 'نقطة',
              icon: Icons.stars_outlined,
            ),
          ],
        ),
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
                      TrText(
                        challenge.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TrText(
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

  /// Opens the challenge as a quiz. The quiz runner records the real result
  /// and marks the challenge finished once it is completed.
  void _play(BuildContext context, WidgetRef ref) {
    ref.read(examSessionProvider.notifier).state = null;
    ref.read(activeChallengeProvider.notifier).state = challenge;
    ref.read(quizTimeLimitProvider.notifier).state =
        challenge.timeLimitSeconds > 0 ? challenge.timeLimitSeconds : null;
    context.push(ZakerRoutes.quiz);
  }
}
