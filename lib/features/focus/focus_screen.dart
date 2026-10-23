/// The focus timer.
///
/// The original app runs a foreground service (`com.zaker.zaker_ai.AiJobService`)
/// and shows a system overlay (`focus_lock_overlay`) so the timer stays
/// visible over other apps.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/focus.dart';
import '../../models/leaderboard.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The focus screen.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _ticker;

  /// Sessions whose minutes have already been added to the study stats, so a
  /// finished session is never counted twice.
  final Set<String> _recorded = <String>{};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final session = ref.read(focusSessionProvider);
    if (session == null || session.phase != FocusPhase.running) return;
    if (session.elapsed >= session.totalDuration) {
      setState(() {
        session.phase = FocusPhase.finished;
        session.completedCycles++;
      });
      _recordStudy(session, session.workMinutes);
      return;
    }
    setState(() {
      session.elapsed += const Duration(seconds: 1);
    });
  }

  /// Adds [minutes] to today's study stats and plants points in the garden.
  void _recordStudy(FocusSession session, int minutes) {
    if (minutes <= 0 || !_recorded.add(session.id)) return;

    final stats = ref.read(studyStatsProvider).recordMinutes(minutes);
    ref.read(studyStatsProvider.notifier).state = stats;

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final garden = ref.read(gardenProvider);
    final plots = [...garden.plots];
    final index = plots.indexWhere(
      (p) =>
          p.day.year == day.year &&
          p.day.month == day.month &&
          p.day.day == day.day,
    );
    final points = minutes * 2;
    if (index >= 0) {
      final plot = plots[index];
      plots[index] = GardenPlot(
        day: plot.day,
        points: plot.points + points,
        streak: stats.streakDays,
      );
    } else {
      plots.add(
        GardenPlot(day: day, points: points, streak: stats.streakDays),
      );
    }
    ref.read(gardenProvider.notifier).state = Garden(
      plots: plots,
      season: garden.season,
    );
  }

  void _start(FocusPreset preset) {
    // A custom session asks for its length instead of silently using 30.
    if (preset == FocusPreset.custom) {
      _pickCustomDuration();
      return;
    }
    _begin(preset, preset.minutes);
  }

  Future<void> _pickCustomDuration() async {
    final controller = TextEditingController(text: '30');
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('مدة مخصصة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'المدة بالدقايق',
            suffixText: 'دقيقة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim()) ?? 30;
              Navigator.of(dialogContext).pop(value.clamp(1, 240));
            },
            child: const TrText('ابدأ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (minutes == null || !mounted) return;
    _begin(FocusPreset.custom, minutes);
  }

  void _begin(FocusPreset preset, int minutes) {
    ref.read(focusSessionProvider.notifier).state = FocusSession(
      id: 'focus-${DateTime.now().millisecondsSinceEpoch}',
      preset: preset,
      workMinutes: minutes,
      phase: FocusPhase.running,
      startedAt: DateTime.now(),
    );
  }

  void _toggle() {
    final session = ref.read(focusSessionProvider);
    if (session == null) return;
    setState(() {
      session.phase = session.phase == FocusPhase.running
          ? FocusPhase.paused
          : FocusPhase.running;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(focusSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const TrText('تركيز')),
      body: session == null
          ? _PresetPicker(onPick: _start)
          : Padding(
              padding: const EdgeInsets.all(ZakerSpacing.xl),
              child: Column(
                children: [
                  const Spacer(),
                  TrText(
                    _format(session.remaining),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: ZakerSpacing.sm),
                  TrText(
                    session.phase == FocusPhase.running
                        ? 'التركيز شغال'
                        : session.phase == FocusPhase.paused
                        ? 'متوقف'
                        : 'خلصت',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: ZakerSpacing.xl),
                  ProgressBar(value: session.progress, height: 10),
                  const SizedBox(height: ZakerSpacing.xl),
                  Wrap(
                    spacing: ZakerSpacing.sm,
                    runSpacing: ZakerSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      StatChip(
                        value: '${session.completedCycles}',
                        label: 'دورة',
                        icon: Icons.loop_rounded,
                      ),
                      StatChip(
                        value: '${session.workMinutes}',
                        label: 'دقيقة',
                        icon: Icons.schedule_rounded,
                        color: ZakerColors.accent,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Count the part of the session actually studied.
                            _recordStudy(session, session.elapsed.inMinutes);
                            ref.read(focusSessionProvider.notifier).state =
                                null;
                          },
                          child: const TrText('إنهاء'),
                        ),
                      ),
                      const SizedBox(width: ZakerSpacing.md),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: session.phase == FocusPhase.finished
                              ? null
                              : _toggle,
                          icon: Icon(
                            session.phase == FocusPhase.running
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: TrText(
                            session.phase == FocusPhase.running
                                ? 'إيقاف'
                                : 'كمّل',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// The preset picker shown before a session starts.
class _PresetPicker extends StatelessWidget {
  const _PresetPicker({required this.onPick});

  final ValueChanged<FocusPreset> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      children: [
        const SectionHeader(
          title: 'اختار مدة الجلسة',
          icon: Icons.timer_rounded,
        ),
        for (final preset in FocusPreset.values)
          Padding(
            padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZakerRadius.md),
              ),
              tileColor: Theme.of(context).cardTheme.color,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.12),
                child: TrText(
                  preset == FocusPreset.custom ? '∞' : '${preset.minutes}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: TrText(switch (preset) {
                FocusPreset.short => 'جلسة قصيرة',
                FocusPreset.medium => 'جلسة متوسطة',
                FocusPreset.long => 'جلسة طويلة',
                FocusPreset.custom => 'مدة مخصصة',
              }, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: preset == FocusPreset.custom
                  ? const TrText('اكتب المدة بنفسك')
                  : TrText('${preset.minutes} دقيقة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => onPick(preset),
            ),
          ),
      ],
    );
  }
}
