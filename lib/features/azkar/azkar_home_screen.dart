/// The azkar hub: morning/evening lists, the counters, Friday Kahf and the
/// notification settings in one place.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/router.dart';
import '../../core/salat_audio.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';
import 'azkar_widgets.dart';

class AzkarHomeScreen extends ConsumerStatefulWidget {
  const AzkarHomeScreen({super.key});

  @override
  ConsumerState<AzkarHomeScreen> createState() => _AzkarHomeScreenState();
}

class _AzkarHomeScreenState extends ConsumerState<AzkarHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(azkarProgressProvider.notifier).ensureToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataAsync = ref.watch(azkarDataProvider);
    final data = dataAsync.valueOrNull;
    final progress = ref.watch(azkarProgressProvider);
    final settings = ref.watch(azkarSettingsProvider);

    final salatCount = kSalatPhrases.fold<int>(
      0,
      (sum, phrase) => sum + progress.countFor(phrase.counterId),
    );
    final tasbihCount = progress.counts.entries
        .where((entry) => entry.key.startsWith('tasbih_'))
        .fold<int>(0, (sum, entry) => sum + entry.value);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('الأذكار والتنبيهات'),
        actions: [
          IconButton(
            tooltip: 'إعدادات التنبيهات',
            onPressed: () => context.push(ZakerRoutes.azkarSettings),
            icon: const Icon(Icons.tune_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(azkarDataProvider);
          await ref.read(azkarDataProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            AzkarHero(
              eyebrow: 'وردك اليومي',
              title: 'سكينة في يومك',
              subtitle: 'صباح ومساء بعدّاد بيتحفظ، وتذكيرات على وقت الصلاة.',
              icon: HugeIcons.strokeRoundedMoon02,
              footer: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const AzkarPill(
                    label: 'العداد محفوظ',
                    icon: HugeIcons.strokeRoundedTaskDone01,
                  ),
                  AzkarPill(
                    label: settings.isAnyEnabled
                        ? 'التنبيهات شغالة'
                        : 'التنبيهات متوقفة',
                    icon: settings.isAnyEnabled
                        ? HugeIcons.strokeRoundedNotification01
                        : HugeIcons.strokeRoundedNotificationSnooze01,
                    color: settings.isAnyEnabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const AzkarSectionHeader(
              title: 'أذكار النهار والليل',
              subtitle: 'اقرأ وعدّ بلمسة — العداد بيتصفر كل يوم',
              icon: HugeIcons.strokeRoundedBookOpen01,
            ),
            const SizedBox(height: 12),
            if (dataAsync.hasError)
              AzkarPlaceholder(detail: '${dataAsync.error}')
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PeriodCard(
                      period: AzkarPeriod.morning,
                      entries: data?.morning,
                      progress: progress,
                      loading: dataAsync.isLoading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PeriodCard(
                      period: AzkarPeriod.evening,
                      entries: data?.evening,
                      progress: progress,
                      loading: dataAsync.isLoading,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 22),
            const AzkarSectionHeader(
              title: 'عدادات سريعة',
              subtitle: 'كمّل وردك من غير ما تفتح قايمة طويلة',
              icon: HugeIcons.strokeRoundedTimer01,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    title: 'المسبحة',
                    value: _arabicNumber(tasbihCount),
                    caption: 'تسبيحة النهارده',
                    icon: HugeIcons.strokeRoundedTaskDone01,
                    accent: theme.colorScheme.primary,
                    onTap: () => context.push(ZakerRoutes.azkarTasbih),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCard(
                    title: 'الصلاة على النبي',
                    value: _arabicNumber(salatCount),
                    caption: 'مرة النهارده',
                    icon: HugeIcons.strokeRoundedStar,
                    accent: ZakerColors.accent,
                    onTap: () => context.push(ZakerRoutes.azkarSalat),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            AzkarSurface(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: theme.brightness == Brightness.dark
                    ? const <Color>[Color(0xFF1B2E2B), Color(0xFF1E293B)]
                    : const <Color>[Color(0xFFFFF7E8), Color(0xFFFFFDF8)],
              ),
              borderColor: ZakerColors.accent.withValues(alpha: 0.22),
              onTap: () => context.push(ZakerRoutes.azkarKahf),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ZakerColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedBookOpen01,
                        size: 24,
                        color: ZakerColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TrText(
                          'سورة الكهف',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        TrText(
                          settings.kahfEnabled
                              ? 'تذكير كل جمعة الساعة ${formatClockMinutes(settings.kahfHour * 60 + settings.kahfMinute)}'
                              : 'افتح السورة أو فعّل تذكير الجمعة',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, size: 22),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AzkarSurface(
              onTap: () => context.push(ZakerRoutes.azkarSettings),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedNotification01,
                        size: 23,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TrText(
                          'تنبيهات الأذكار والصلاة على النبي',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        TrText(
                          'فاصل الصلاة على النبي، وقت أذكار الصباح والمساء، وتذكير الجمعة.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: TrText(
                    'كل حاجة بتتحفظ على جهازك — العداد بيتصفر مع يوم جديد.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9,
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
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.entries,
    required this.progress,
    required this.loading,
  });

  final AzkarPeriod period;
  final List<AzkarEntry>? entries;
  final AzkarProgress progress;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final morning = period == AzkarPeriod.morning;
    final accent = morning ? primary : ZakerColors.accent;
    final list = entries ?? const <AzkarEntry>[];
    final completed = progress.completed(list);
    final ratio = list.isEmpty ? 0.0 : completed / list.length;
    final gradient = morning
        ? (isDark
              ? const <Color>[Color(0xFF123B37), Color(0xFF1E293B)]
              : const <Color>[Color(0xFFE8F8F1), Color(0xFFFFFFFF)])
        : (isDark
              ? const <Color>[Color(0xFF3A2E1C), Color(0xFF1E293B)]
              : const <Color>[Color(0xFFFFF7E8), Color(0xFFFFFFFF)]);

    return AzkarSurface(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: gradient,
      ),
      borderColor: accent.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(
        morning ? ZakerRoutes.azkarMorning : ZakerRoutes.azkarEvening,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: morning
                        ? HugeIcons.strokeRoundedSunrise
                        : HugeIcons.strokeRoundedMoon02,
                    size: 20,
                    color: cardAccentOf(accent, theme),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 16,
                color: cardAccentOf(accent, theme).withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 13),
          TrText(
            period.label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          TrText(
            period.anchorLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: accent.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            loading
                ? '—'
                : list.isEmpty
                ? 'مفيش بيانات'
                : '$completed من ${list.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String value;
  final String caption;
  final List<List<dynamic>> icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AzkarSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, size: 18, color: accent),
              const Spacer(),
              Icon(
                Icons.add_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 27,
              color: accent,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          TrText(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 9),
          TrText(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

String _arabicNumber(int value) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return value
      .toString()
      .split('')
      .map((digit) => digits[int.tryParse(digit) ?? 0])
      .join();
}
