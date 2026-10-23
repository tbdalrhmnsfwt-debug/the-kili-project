/// The study games: the adventure map and the game runner.
///
/// Shipped strings this screen is built from:
///   * `ألعاب المذاكرة`
///   * `خريطة مغامرة فيها عشر ألعاب كلها بتاكل من أسئلة مادتك: بنك الحظ،
///      السباق، معركة الوحش، الصندوق، القنبلة…`
///   * `كل لعبة بتديك نجوم وعملات، والعملات بتطلعك مستويات.`
///   * `كل إجابة صح بتقلل طاقة الوحش لحد ما تهزمه`
///   * `مذاكرة على شكل لعبة — تجاوب صح تتقدم وتكسب.`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/question_bank_builder.dart';
import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/exam.dart';
import '../../models/games.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// Option bullets: Arabic ordinal letters, not consecutive Unicode letters.
const List<String> _optionLetters = ['أ', 'ب', 'ج', 'د', 'هـ', 'و'];

/// The games map: pick a game, play it, collect stars and coins.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(gameProfileProvider);
    final banks = ref.watch(questionBanksProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText(ZakerStrings.s_97497)), // ألعاب المذاكرة
      body: ListView(
        padding: const EdgeInsets.all(ZakerSpacing.lg),
        children: [
          _ProfileCard(profile: profile),
          const SizedBox(height: ZakerSpacing.lg),
          const SectionHeader(
            title: ZakerStrings.s_e07ea, // ألعاب وتحديات
            icon: Icons.map_rounded,
          ),
          TrText(
            ZakerStrings.s_9fc53, // خريطة مغامرة فيها عشر ألعاب…
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          if (banks.isEmpty) ...[
            _PrepareBankCard(
              onPrepare: () => _prepareBanks(context, ref),
            ),
            const SizedBox(height: ZakerSpacing.md),
          ],
          for (final stop in GameStop.all) ...[
            _GameStopTile(stop: stop, hasBank: banks.isNotEmpty),
            const SizedBox(height: ZakerSpacing.sm),
          ],
        ],
      ),
    );
  }

  /// Builds banks from the library so the map is playable on a fresh install.
  Future<void> _prepareBanks(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: TrText('بنجهز أسئلة من كتبك…')),
      );
    try {
      final service = ref.read(assetServiceProvider);
      final grades = await ref.read(gradesProvider.future);
      final prepared = await buildQuestionBanks(
        service: service,
        grades: grades,
      );
      ref.read(questionBanksProvider.notifier).state = prepared;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: TrText(
              prepared.isEmpty
                  ? 'مفيش كتب مقروءة على الجهاز — افتح مكتبتك وجرّب تاني.'
                  : 'جهزنا ${prepared.length} بنوك أسئلة ✅',
            ),
          ),
        );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: TrText('مش قادر أجهز البنك دلوقتي.')),
        );
    }
  }
}

/// The prompt shown when no question bank exists yet.
class _PrepareBankCard extends StatelessWidget {
  const _PrepareBankCard({required this.onPrepare});

  final VoidCallback onPrepare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: ZakerSpacing.sm),
          const Expanded(
            child: TrText(
              'جهّز بنك أسئلة من كتبك الأول عشان الألعاب تشتغل.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(width: ZakerSpacing.sm),
          FilledButton(
            onPressed: onPrepare,
            child: const TrText('جهّز'),
          ),
        ],
      ),
    );
  }
}

/// The stars / coins / level card at the top of the games screen.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final GameProfile profile;

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
          TrText(
            ZakerStrings.s_3627c, // كل لعبة بتديك نجوم وعملات…
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              StatChip(
                value: '${profile.stars}',
                label: 'نجومك',
                icon: Icons.star_rounded,
                color: Colors.white,
              ),
              StatChip(
                value: '${profile.coins}',
                label: 'عملاتك',
                icon: Icons.monetization_on_rounded,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              TrText(
                '${ZakerStrings.s_83825} ${profile.level}', // المستوى
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: ProgressBar(
                  value: profile.levelProgress,
                  height: 8,
                  color: Colors.white,
                  background: Colors.white24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One game on the map.
class _GameStopTile extends StatelessWidget {
  const _GameStopTile({required this.stop, required this.hasBank});

  final GameStop stop;
  final bool hasBank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: hasBank ? 1 : 0.62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: ZakerRadius.card,
          onTap: hasBank
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GamePlayScreen(kind: stop.kind, title: stop.title),
                  ),
                )
              : () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: TrText(
                          'اللعبة محتاجة بنك أسئلة — دوس على «جهّز» فوق الأول.',
                        ),
                      ),
                    );
                },
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
                Container(
                  padding: const EdgeInsets.all(ZakerSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(ZakerRadius.sm),
                  ),
                  child: Icon(
                    _iconFor(stop.kind),
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        stop.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TrText(
                        hasBank
                            ? stop.subtitle
                            : 'محتاج بنك أسئلة — دوس «جهّز» فوق',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasBank
                      ? Icons.play_arrow_rounded
                      : Icons.lock_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(GameKind kind) => switch (kind) {
    GameKind.fortune => Icons.casino_rounded,
    GameKind.race => Icons.directions_run_rounded,
    GameKind.monster => Icons.shield_rounded,
    GameKind.chest => Icons.card_giftcard_rounded,
    GameKind.bomb => Icons.bolt_rounded,
    GameKind.memory => Icons.grid_view_rounded,
  };
}

/// Runs one game from the map.
class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key, required this.kind, required this.title});

  /// Which game to run.
  final GameKind kind;

  /// The game's display name.
  final String title;

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  GameSession? _session;
  int? _picked;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: TrText(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(ZakerSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sports_esports_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: ZakerSpacing.md),
                TrText(
                  widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  ZakerStrings.s_928ae, // مذاكرة على شكل لعبة…
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.xl),
                FilledButton(
                  onPressed: _start,
                  child: const TrText(ZakerStrings.s_617aa), // العب دلوقتي
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = session.current;

    return Scaffold(
      appBar: AppBar(
        title: TrText(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: ProgressBar(value: session.progress, height: 6),
        ),
      ),
      body: question == null
          ? _Results(session: session)
          : ListView(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              children: [
                _HudBar(session: session),
                const SizedBox(height: ZakerSpacing.lg),
                TrText(
                  question.prompt,
                  style: theme.textTheme.titleMedium?.copyWith(
                    height: 1.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.xl),
                for (var i = 0; i < question.options.length; i++) ...[
                  _OptionTile(
                    label: question.options[i],
                    index: i,
                    state: _optionState(i),
                    onTap: _revealed ? null : () => _pick(i),
                  ),
                  const SizedBox(height: ZakerSpacing.sm),
                ],
                const SizedBox(height: ZakerSpacing.md),
                if (_revealed)
                  FilledButton(
                    onPressed: _next,
                    child: TrText(
                      session.index >= session.questions.length
                          ? ZakerStrings.s_617aa
                          : ZakerStrings.s_0a2f4_x1, // العب
                    ),
                  ),
              ],
            ),
    );
  }

  void _start() {
    final banks = ref.read(questionBanksProvider);
    final questions = <ExamQuestion>[];
    for (final bank in banks) {
      questions.addAll(bank.questions);
    }
    setState(() {
      _session = GameSession(
        kind: widget.kind,
        title: widget.title,
        questions: questions,
      );
    });
  }

  _OptionState _optionState(int index) {
    if (!_revealed) return _OptionState.idle;
    final correct = _session?.current?.correctIndex;
    if (correct == null) return _OptionState.idle;
    if (index == correct) return _OptionState.correct;
    if (index == _picked) return _OptionState.wrong;
    return _OptionState.idle;
  }

  void _pick(int index) {
    setState(() {
      _picked = index;
      _revealed = true;
    });
  }

  void _next() {
    final session = _session;
    final question = session?.current;
    if (session == null || question == null) return;

    final correct = question.correctIndex;
    final isCorrect = correct == null || correct == _picked;

    setState(() {
      _session = session.answer(
        correct: isCorrect,
        rewardCoins: widget.kind == GameKind.chest,
      );
      _picked = null;
      _revealed = false;
    });

    if (_session?.finished ?? false) {
      final profile = ref.read(gameProfileProvider);
      ref.read(gameProfileProvider.notifier).state =
          profile.reward(_session!);
    }
  }
}

/// Visual state of an answer option.
enum _OptionState { idle, correct, wrong }

/// The stars / lives / energy read-out above the question.
class _HudBar extends StatelessWidget {
  const _HudBar({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatChip(
          value: '${session.stars}',
          label: ZakerStrings.s_cc68d, // شاراتك ونجومك
          icon: Icons.star_rounded,
        ),
        const SizedBox(width: ZakerSpacing.sm),
        StatChip(
          value: '${session.lives}',
          label: ZakerStrings.s_3ea13, // الوحش
          icon: Icons.favorite_rounded,
          color: ZakerColors.danger,
        ),
        if (session.kind == GameKind.monster) ...[
          const SizedBox(width: ZakerSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  '${ZakerStrings.s_0_a2129} ${session.monsterEnergy}',
                  // طاقة الوحش {0}
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: ZakerSpacing.xs),
                ProgressBar(
                  value: session.monsterEnergy / 100,
                  height: 6,
                  color: ZakerColors.danger,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One tappable answer option.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.index,
    required this.state,
    this.onTap,
  });

  final String label;
  final int index;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color border, IconData? icon) = switch (state) {
      _OptionState.correct => (
        ZakerColors.success.withValues(alpha: 0.12),
        ZakerColors.success,
        Icons.check_circle_rounded,
      ),
      _OptionState.wrong => (
        ZakerColors.danger.withValues(alpha: 0.12),
        ZakerColors.danger,
        Icons.cancel_rounded,
      ),
      _OptionState.idle => (
        theme.cardTheme.color ?? Colors.white,
        theme.dividerTheme.color ?? Colors.black12,
        null,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.md),
        child: Container(
          padding: const EdgeInsets.all(ZakerSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: ZakerRadius.card,
            border: Border.all(color: border, width: state == _OptionState.idle ? 1 : 1.6),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: border.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: TrText(
                  _optionLetters[index % _optionLetters.length],
                  style: TextStyle(
                    color: border,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(child: TrText(label, style: theme.textTheme.bodyLarge)),
              if (icon != null) Icon(icon, color: border, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the session is over.
class _Results extends StatelessWidget {
  const _Results({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final won = session.monsterDefeated;

    return Padding(
      padding: const EdgeInsets.all(ZakerSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            won ? Icons.emoji_events_rounded : Icons.celebration_rounded,
            size: 64,
            color: ZakerColors.accent,
          ),
          const SizedBox(height: ZakerSpacing.md),
          TrText(
            won
                ? ZakerStrings.s_2e0d9 // هزمت الوحش! 🏆
                : ZakerStrings.s_6a3a6, // كسبت السباق! 🏁
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ZakerSpacing.lg),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              StatChip(
                value: '${session.stars}',
                label: 'نجوم',
                icon: Icons.star_rounded,
              ),
              StatChip(
                value: '${session.coins}',
                label: 'عملات',
                icon: Icons.monetization_on_rounded,
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const TrText(ZakerStrings.s_65e22), // أعِد الجولة من الأول
          ),
        ],
      ),
    );
  }
}
