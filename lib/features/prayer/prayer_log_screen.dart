/// "سجل الصلوات": a manual daily check-off for the five prayers, with the
/// current streak and the last week at a glance.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/appearance.dart';
import '../../core/hijri_date.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'prayer_log.dart';
import 'prayer_models.dart';

class PrayerLogScreen extends ConsumerWidget {
  const PrayerLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final log = ref.watch(prayerLogProvider);
    final palette = ZakerTheme.paletteFor(
      ref.watch(appearanceProvider).themeStyle,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final marked = log.countFor(today);
    final complete = marked >= PrayerName.values.length;
    final streak = log.streak(now: now);

    return Scaffold(
      appBar: AppBar(title: const TrText('سجل الصلوات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.sm,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          _LogHero(
            colors: palette.heroGradient,
            marked: marked,
            complete: complete,
            streak: streak,
          ),
          const SizedBox(height: ZakerSpacing.lg),
          _TodayCard(
            date: today,
            log: log,
            onToggle: (prayer) {
              HapticFeedback.selectionClick();
              ref.read(prayerLogProvider.notifier).toggle(today, prayer);
            },
          ),
          const SizedBox(height: ZakerSpacing.lg),
          const TrText(
            'آخر ٧ أيام',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZakerSpacing.sm),
          _WeekStrip(log: log, today: today),
          const SizedBox(height: ZakerSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: TrText(
                  'علّم الصلاة بعد ما تصلّيها بنفسك. السلسلة بتزيد لما تعلّم '
                  'الخمس صلوات في نفس اليوم، وبتفضل محفوظة على جهازك.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogHero extends StatelessWidget {
  const _LogHero({
    required this.colors,
    required this.marked,
    required this.complete,
    required this.streak,
  });

  final List<Color> colors;
  final int marked;
  final bool complete;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(ZakerRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedTaskDone01,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: ZakerSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrText(
                  complete
                      ? 'كمّلت صلوات النهارده'
                      : '$marked من ٥ صلوات النهارده',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                TrText(
                  streak == 0
                      ? 'ابدأ سلسلتك بعلامة النهارده.'
                      : 'سلسلتك $streak ${streak == 1 ? 'يوم' : 'أيام'} متواصلة.',
                  style: const TextStyle(
                    color: Color(0xFFE7F8F6),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.date,
    required this.log,
    required this.onToggle,
  });

  final DateTime date;
  final PrayerLog log;
  final ValueChanged<PrayerName> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hijri = HijriDate.fromGregorian(date);
    return Container(
      padding: const EdgeInsets.all(ZakerSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: ZakerRadius.card,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrText(
            formatGregorianDate(date),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          TrText(
            hijri.formatted,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ZakerSpacing.md),
          for (var index = 0; index < PrayerName.values.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            _PrayerRow(
              prayer: PrayerName.values[index],
              marked: log.isMarked(date, PrayerName.values[index]),
              onTap: () => onToggle(PrayerName.values[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayer,
    required this.marked,
    required this.onTap,
  });

  final PrayerName prayer;
  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      button: true,
      checked: marked,
      label: prayer.invocation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ZakerRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: marked ? accent : Colors.transparent,
                    border: Border.all(
                      color: marked
                          ? accent
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                      width: 1.5,
                    ),
                  ),
                  child: marked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: ZakerSpacing.md),
                Expanded(
                  child: TrText(
                    prayer.invocation,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: marked ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                TrText(
                  marked ? 'تمت' : 'علّم',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: marked ? accent : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.log, required this.today});

  final PrayerLog log;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var offset = 6; offset >= 0; offset--) ...[
          if (offset != 6) const SizedBox(width: 6),
          Expanded(
            child: _DayCell(
              date: DateTime(today.year, today.month, today.day - offset),
              count: log.countFor(
                DateTime(today.year, today.month, today.day - offset),
              ),
              isToday: offset == 0,
              theme: theme,
            ),
          ),
        ],
      ],
    );
  }
}

/// «جمعة»، «سبت» … the compact names used under the week strip.
String _shortWeekday(DateTime date) => switch (date.weekday) {
  DateTime.monday => 'اتنين',
  DateTime.tuesday => 'تلات',
  DateTime.wednesday => 'أربع',
  DateTime.thursday => 'خميس',
  DateTime.friday => 'جمعة',
  DateTime.saturday => 'سبت',
  _ => 'حد',
};

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.count,
    required this.isToday,
    required this.theme,
  });

  final DateTime date;
  final int count;
  final bool isToday;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final total = PrayerName.values.length;
    final fraction = (count / total).clamp(0.0, 1.0);
    final complete = count >= total;
    final accent = complete
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 2.4,
                  backgroundColor: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  color: accent,
                ),
              ),
              if (complete)
                Icon(Icons.check_rounded, size: 15, color: accent)
              else
                Text(
                  '${math.min(count, total)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: count == 0
                        ? theme.colorScheme.onSurfaceVariant
                        : accent,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: TrText(
            _shortWeekday(date),
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isToday
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
