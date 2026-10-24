/// The hifz hub: memorized parts, due reviews, streak and reminder settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notification_service.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';
import 'hifz_models.dart';
import 'hifz_providers.dart';
import 'hifz_session_screen.dart';
import 'hifz_setup_screen.dart';
import 'hifz_style.dart';

/// Lists the student's memorized parts and starts new sessions.
class HifzHomeScreen extends ConsumerWidget {
  const HifzHomeScreen({super.key});

  void _startNew(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HifzSetupScreen()));
  }

  void _review(BuildContext context, HifzPart part) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HifzSessionScreen(
          surahNumber: part.surahNumber,
          surahName: part.surahName,
          startAyah: part.startAyah,
          endAyah: part.endAyah,
          mode: part.hideMode,
          partId: part.id,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HifzPart part,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const TrText('تحذف الجزء ده؟'),
        content: TrText(
          'هيتشال «${part.surahName} — ${hifzRangeLabel(part)}» من قائمة المحفوظات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const TrText('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const TrText('احذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(hifzProvider.notifier).removePart(part.id);
  }

  Future<void> _openReminders(
    BuildContext context,
    WidgetRef ref,
    HifzState state,
  ) async {
    var enabled = state.remindersEnabled;
    var time = TimeOfDay(
      hour: state.reminderHour,
      minute: state.reminderMinute,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            void apply({bool? on, TimeOfDay? at}) {
              final nextOn = on ?? enabled;
              final nextAt = at ?? time;
              enabled = nextOn;
              time = nextAt;
              ref
                  .read(hifzProvider.notifier)
                  .setReminders(
                    enabled: nextOn,
                    hour: nextAt.hour,
                    minute: nextAt.minute,
                  );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZakerSpacing.lg,
                  ZakerSpacing.lg,
                  ZakerSpacing.lg,
                  ZakerSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'تذكير المراجعة',
                      icon: Icons.notifications_active_outlined,
                    ),
                    const SizedBox(height: ZakerSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      title: const TrText('نبّهني بموعد المراجعة'),
                      subtitle: const TrText(
                        'إشعار واحد في أقرب موعد من جدول 1 / 3 / 7 / 14 يوم.',
                      ),
                      onChanged: (value) async {
                        if (value) {
                          final allowed = await NotificationService.instance
                              .requestPermission();
                          if (!allowed) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: TrText(
                                  'الإشعارات مقفولة على الجهاز ده. افتح إعدادات النظام واسمح بيها.',
                                ),
                              ),
                            );
                            return;
                          }
                        }
                        if (!context.mounted) return;
                        setSheet(() => apply(on: value));
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: enabled,
                      leading: const Icon(Icons.schedule_rounded),
                      title: const TrText('وقت التذكير'),
                      trailing: Text(
                        '${time.hour.toString().padLeft(2, '0')}:'
                        '${time.minute.toString().padLeft(2, '0')}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked == null || !context.mounted) return;
                        setSheet(() => apply(at: picked));
                      },
                    ),
                    const SizedBox(height: ZakerSpacing.sm),
                    const TrText(
                      'التذكير بيتبعت في نفس وقت اليوم اللي فيه مراجعة مستحقة، '
                      'وبيتحدّث تلقائيًا بعد كل جلسة.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hifzProvider);
    final now = DateTime.now();
    final parts = [...state.parts]
      ..sort((a, b) {
        final aDue = a.nextReviewAt ?? DateTime(9999);
        final bDue = b.nextReviewAt ?? DateTime(9999);
        return aDue.compareTo(bDue);
      });
    final due = state.dueCount(now);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('حفظ القرآن'),
        actions: [
          IconButton(
            tooltip: 'تذكير المراجعة',
            icon: Icon(
              state.remindersEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
            ),
            onPressed: () => _openReminders(context, ref, state),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.sm,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          _HifzHero(state: state, due: due),
          const SizedBox(height: ZakerSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startNew(context),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const TrText('ابدأ جلسة حفظ'),
            ),
          ),
          const SizedBox(height: ZakerSpacing.xl),
          if (state.isEmpty)
            EmptyState(
              icon: Icons.auto_stories_rounded,
              title: 'لسه ما حفظتش حاجة',
              message: 'اختار سورة ونطاق آيات وابدأ أول جلسة تسميع.',
              action: FilledButton(
                onPressed: () => _startNew(context),
                child: const TrText('اختار سورة'),
              ),
            )
          else ...[
            SectionHeader(
              title: due > 0 ? 'مراجعة مستحقة ($due)' : 'أجزاء محفوظة',
              icon: Icons.menu_book_rounded,
            ),
            for (final part in parts)
              _PartCard(
                part: part,
                now: now,
                onReview: () => _review(context, part),
                onDelete: () => _confirmDelete(context, ref, part),
              ),
          ],
        ],
      ),
    );
  }
}

class _HifzHero extends StatelessWidget {
  const _HifzHero({required this.state, required this.due});

  final HifzState state;
  final int due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF0D4F4A)],
        ),
        boxShadow: [
          BoxShadow(
            color: ZakerColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZakerSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(ZakerRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: ZakerSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrText(
                      'وِردك من الحفظ',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TrText(
                      due > 0
                          ? 'عندك $due مراجعة مستنية النهارده'
                          : 'سمّع لنفسك وثبّت اللي حفظته',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.lg),
          Wrap(
            spacing: ZakerSpacing.sm,
            runSpacing: ZakerSpacing.sm,
            children: [
              _HeroStat(
                value: '${state.parts.length}',
                label: 'جزء محفوظ',
                icon: Icons.bookmark_added_rounded,
              ),
              _HeroStat(
                value: '${state.memorizedAyahs}',
                label: 'آية',
                icon: Icons.format_list_numbered_rounded,
              ),
              _HeroStat(
                value: '${state.streakDays}',
                label: 'يوم متواصل',
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          TrText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          TrText(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.now,
    required this.onReview,
    required this.onDelete,
  });

  final HifzPart part;
  final DateTime now;
  final VoidCallback onReview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final due = part.isDue(now);
    // Amber on a light surface fails WCAG AA for small text, so the due
    // accent darkens in light mode and brightens in dark mode.
    final dueColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final accent = due ? dueColor : ZakerColors.primary;
    final percent = (part.bestScore * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        color: theme.cardTheme.color,
        border: Border.all(
          color: due
              ? accent.withValues(alpha: isDark ? 0.55 : 0.45)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ZakerRadius.lg),
          onTap: onReview,
          child: Padding(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.24 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        due
                            ? Icons.notifications_active_rounded
                            : Icons.menu_book_rounded,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: ZakerSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrText(
                            part.surahName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TrText(
                            '${hifzRangeLabel(part)} · ${part.hideMode.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'احذف الجزء',
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: ProgressBar(
                        value: part.bestScore,
                        height: 5,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TrText(
                        '${hifzDueLabel(part, now)} · ${hifzStageLabel(part)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: due
                              ? accent
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: due ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    TrText(
                      'سمّع',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ZakerColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: ZakerColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
