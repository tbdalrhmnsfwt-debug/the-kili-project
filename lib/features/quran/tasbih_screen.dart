/// The tasbih (مسبحة) counter screen.
///
/// The screen is a big round counter the user taps, plus a voice mode where
/// the phone listens and counts on its own.
///
/// Shipped strings this screen is built from:
///   * `المسبحة`
///   * `وِرد التسبيح`
///   * `سبح بإيدك أو بصوتك — وإحنا نعد`
///   * `سبح بصوتك`
///   * `دوس «ابدأ السمع» وسبح طبيعي`
///   * `سامعك… سبح وإحنا نعد`
///   * `مسمعتش حاجة — اكتب بإيدك.`
///   * `تسبيح النهارده`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/tasbih.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The tasbih counter.
class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen> {
  final TasbihState _state = TasbihState();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(assetServiceProvider);
    try {
      final entries = await service.loadAdhkar();
      if (!mounted) return;
      setState(() {
        _state.items
          ..clear()
          ..addAll(TasbihState.countableFrom(entries));
      });
    } catch (_) {
      // The counter stays empty; the empty state explains it.
    }
  }

  void _tap() {
    setState(_state.tap);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TrText(ZakerStrings.s_265c6), // المسبحة
        actions: [
          IconButton(
            tooltip: ZakerStrings.s_fe493, // التسبيح
            onPressed: _state.items.isEmpty
                ? null
                : () => setState(_state.resetAll),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: _state.items.isEmpty
          ? const EmptyState(
              icon: Icons.spa_outlined,
              title: ZakerStrings.s_75607, // وِرد التسبيح
              message: ZakerStrings.s_3d0df, // مسمعتش حاجة — اكتب بإيدك.
            )
          : ListView(
              padding: const EdgeInsets.all(ZakerSpacing.lg),
              children: [
                const SectionHeader(
                  title: ZakerStrings.s_75607, // وِرد التسبيح
                  icon: Icons.auto_awesome_rounded,
                ),
                _PhraseStrip(
                  state: _state,
                  onSelected: (i) => setState(() => _state.select(i)),
                ),
                const SizedBox(height: ZakerSpacing.lg),
                _CounterDial(state: _state, onTap: _tap),
                const SizedBox(height: ZakerSpacing.lg),
                _VoicePanel(
                  listening: _state.listening,
                  onToggle: () =>
                      setState(() => _state.setListening(!_state.listening)),
                ),
                const SizedBox(height: ZakerSpacing.lg),
                _TodayCard(state: _state),
              ],
            ),
    );
  }
}

/// The horizontal strip of phrases.
class _PhraseStrip extends StatelessWidget {
  const _PhraseStrip({required this.state, required this.onSelected});

  final TasbihState state;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: ZakerSpacing.sm),
        itemBuilder: (context, index) {
          final item = state.items[index];
          final isSelected = index == state.index;
          return ChoiceChip(
            label: TrText(
              item.content,
              style: const TextStyle(fontFamily: 'Amiri', fontSize: 15),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(index),
          );
        },
      ),
    );
  }
}

/// The big round counter.
class _CounterDial extends StatelessWidget {
  const _CounterDial({required this.state, required this.onTap});

  final TasbihState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = state.current;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              ZakerColors.primaryLight,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrText(
              '${item.count}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            TrText(
              '/ ${item.target}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: ZakerSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZakerSpacing.lg,
              ),
              child: TrText(
                item.content,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Amiri',
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The voice-counting panel.
class _VoicePanel extends StatelessWidget {
  const _VoicePanel({required this.listening, required this.onToggle});

  final bool listening;
  final VoidCallback onToggle;

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
            ZakerStrings.s_a3267, // سبح بإيدك أو بصوتك — وإحنا نعد
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.xs),
          TrText(
            listening
                ? ZakerStrings.s_0aced // سامعك… سبح وإحنا نعد
                : ZakerStrings.s_374b7, // دوس «ابدأ السمع» وسبح طبيعي
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          FilledButton.icon(
            onPressed: onToggle,
            icon: Icon(
              listening ? Icons.stop_rounded : Icons.mic_rounded,
            ),
            label: TrText(
              listening
                  ? ZakerStrings.s_6c784 // سبح بصوتك
                  : ZakerStrings.s_67cdf, // ابدأ السمع
            ),
          ),
        ],
      ),
    );
  }
}

/// The "today's tasbih" summary.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state});

  final TasbihState state;

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
            ZakerStrings.s_d5c6c, // تسبيح النهارده
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatChip(
                  value: '${state.total}',
                  label: ZakerStrings.s_85ae2, // تسبيحات
                  icon: Icons.repeat_rounded,
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: StatChip(
                  value: '${state.completedCount}',
                  label: ZakerStrings.s_80cc2, // تسبيحة
                  icon: Icons.check_circle_outline_rounded,
                  color: ZakerColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          ProgressBar(value: state.current.progress, height: 6),
        ],
      ),
    );
  }
}
