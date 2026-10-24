/// The morning or evening azkar list, with a tap counter on each card.
///
/// The dhikr text is rendered exactly as it comes from
/// `assets/data/azkar.json`; the only additions are the count wording and the
/// source/فضل panel, both read from that same file.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';
import 'azkar_widgets.dart';

class AzkarListScreen extends ConsumerStatefulWidget {
  const AzkarListScreen({super.key, required this.period});

  final AzkarPeriod period;

  @override
  ConsumerState<AzkarListScreen> createState() => _AzkarListScreenState();
}

class _AzkarListScreenState extends ConsumerState<AzkarListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(azkarProgressProvider.notifier).ensureToday();
    });
  }

  Future<bool> _confirmReset(List<AzkarEntry> entries) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('تصفير عدّاد الأذكار؟'),
        content: const TrText(
          'هيتم تصفير عدّاد كل أذكار الفترة دي لليوم الحالي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const TrText('صفّر'),
          ),
        ],
      ),
    );
    if (result != true) return false;
    ref
        .read(azkarProgressProvider.notifier)
        .resetMany(entries.map((entry) => entry.id));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataAsync = ref.watch(azkarDataProvider);
    final progress = ref.watch(azkarProgressProvider);
    final entries = dataAsync.valueOrNull?.forPeriod(widget.period);
    final completed = entries == null ? 0 : progress.completed(entries);
    final ratio = entries == null || entries.isEmpty
        ? 0.0
        : completed / entries.length;
    final morning = widget.period == AzkarPeriod.morning;

    return Scaffold(
      appBar: AppBar(
        title: TrText(widget.period.label),
        actions: [
          if (entries != null && entries.isNotEmpty)
            IconButton(
              tooltip: 'تصفير عدّاد الفترة',
              onPressed: () => _confirmReset(entries),
              icon: const Icon(Icons.restart_alt_rounded, size: 23),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            AzkarHero(
              eyebrow: widget.period.anchorLabel,
              title: widget.period.label,
              subtitle: 'القايمة بتتحمّل من ملف الأذكار المرفق مع التطبيق.',
              icon: morning
                  ? HugeIcons.strokeRoundedSunrise
                  : HugeIcons.strokeRoundedMoon02,
            ),
            const SizedBox(height: 16),
            AzkarPlaceholder(detail: '$error'),
          ],
        ),
        data: (data) {
          final list = data.forPeriod(widget.period);
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                AzkarHero(
                  eyebrow: widget.period.anchorLabel,
                  title: widget.period.label,
                  subtitle: 'مفيش أذكار متسجلة للفترة دي في ملف البيانات.',
                  icon: morning
                      ? HugeIcons.strokeRoundedSunrise
                      : HugeIcons.strokeRoundedMoon02,
                ),
                const SizedBox(height: 16),
                const AzkarPlaceholder(
                  detail: 'assets/data/azkar.json',
                  compact: true,
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(azkarDataProvider);
              await ref.read(azkarDataProvider.future);
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              itemCount: list.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AzkarHero(
                      eyebrow: widget.period.anchorLabel,
                      title: widget.period.label,
                      subtitle: completed == list.length
                          ? 'خلصت ورد الفترة دي — تقبل الله.'
                          : 'اقرأ كل ذكر واضغط عليه عشان تعدّه. العداد بيتحفظ لليوم.',
                      icon: morning
                          ? HugeIcons.strokeRoundedSunrise
                          : HugeIcons.strokeRoundedMoon02,
                      footer: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.10),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$completed / ${list.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (index == list.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.65,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: TrText(
                            'العداد بيتحفظ على جهازك ويتصفر مع يوم جديد.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final entry = list[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AzkarCard(
                    entry: entry,
                    count: progress.countFor(entry.id),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AzkarCard extends ConsumerWidget {
  const _AzkarCard({required this.entry, required this.count});

  final AzkarEntry entry;
  final int count;

  bool get _complete => count >= entry.target;

  void _tap(BuildContext context, WidgetRef ref) {
    if (_complete) {
      HapticFeedback.selectionClick();
      return;
    }
    final notifier = ref.read(azkarProgressProvider.notifier);
    HapticFeedback.lightImpact();
    notifier.increment(entry.id, target: entry.target);
    if (count + 1 >= entry.target) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _showSource(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SourceSheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final ratio = entry.target <= 0 ? 0.0 : count / entry.target;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      decoration: BoxDecoration(
        color: _complete
            ? (isDark ? const Color(0xFF143832) : const Color(0xFFF0FBF6))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _complete
              ? primary.withValues(alpha: 0.32)
              : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.07)),
          width: _complete ? 1.3 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _arabicNumber(entry.order),
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                if (entry.countDescription.trim().isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: muted.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.countDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    '${_arabicNumber(entry.target)} مرة',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      fontSize: 9,
                    ),
                  ),
                const Spacer(),
                if (_complete)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: ZakerColors.success,
                    size: 21,
                  )
                else
                  const SizedBox(width: 6),
              ],
            ),
          ),
          InkWell(
            onTap: () => _tap(context, ref),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 9, 17, 15),
              child: Text(
                entry.content,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: ZakerTheme.fontQuran,
                  fontSize: 18,
                  height: 1.95,
                  color: _complete
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.78)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: primary.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _complete ? ZakerColors.success : primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_arabicNumber(count)} / ${_arabicNumber(entry.target)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _complete ? ZakerColors.success : muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (entry.hasSource)
                  IconButton(
                    tooltip: 'المصدر',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showSource(context),
                    icon: Icon(
                      Icons.menu_book_rounded,
                      size: 17,
                      color: muted.withValues(alpha: 0.75),
                    ),
                  ),
                if (count > 0)
                  IconButton(
                    tooltip: 'تصفير الذكر',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(azkarProgressProvider.notifier).reset(entry.id);
                    },
                    icon: Icon(
                      Icons.restart_alt_rounded,
                      size: 18,
                      color: muted.withValues(alpha: 0.75),
                    ),
                  ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: () => _tap(context, ref),
                  tooltip: _complete ? 'تم العد' : 'عدّ',
                  style: IconButton.styleFrom(
                    fixedSize: const Size(38, 38),
                    minimumSize: const Size(38, 38),
                    padding: EdgeInsets.zero,
                    backgroundColor: _complete
                        ? ZakerColors.success.withValues(alpha: 0.16)
                        : primary,
                    foregroundColor: _complete
                        ? ZakerColors.success
                        : Colors.white,
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(
                    _complete ? Icons.check_rounded : Icons.add_rounded,
                    size: 20,
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

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.entry});

  final AzkarEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedBookOpen01,
                        size: 19,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: TrText(
                      'المصدر والفضل',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (entry.fadl.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const TrText(
                  'الفضل',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.fadl,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.8,
                    fontSize: 13,
                    color: muted,
                  ),
                ),
              ],
              if (entry.source.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const TrText(
                  'المصدر',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.source,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.8,
                    fontSize: 13,
                    color: muted,
                  ),
                ),
              ],
            ],
          ),
        ),
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
