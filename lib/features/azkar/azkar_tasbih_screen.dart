/// A tactile tasbih counter built on the azkar data.
///
/// The listed dhikr comes from `assets/data/azkar.json`; the three salat
/// phrases are the feature's own fixed phrases.  Counts are kept per day by
/// [azkarProgressProvider], so leaving the screen never loses the round.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/salat_audio.dart';
import '../../core/theme.dart';
import '../../widgets/tr_text.dart';
import 'azkar_models.dart';
import 'azkar_providers.dart';
import 'azkar_widgets.dart';

class AzkarTasbihScreen extends ConsumerStatefulWidget {
  const AzkarTasbihScreen({super.key});

  @override
  ConsumerState<AzkarTasbihScreen> createState() => _AzkarTasbihScreenState();
}

class _AzkarTasbihScreenState extends ConsumerState<AzkarTasbihScreen> {
  String? _selectedId;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(azkarProgressProvider.notifier).ensureToday();
    });
  }

  List<_TasbihChoice> _choices(AzkarData? data) {
    final choices = <_TasbihChoice>[];
    final entries = data?.morning ?? const <AzkarEntry>[];
    for (final entry in entries.where((entry) => entry.target > 1)) {
      choices.add(
        _TasbihChoice(
          id: 'tasbih_${entry.id}',
          label: _short(entry.content),
          text: entry.content,
          target: entry.target,
        ),
      );
    }
    for (final phrase in kSalatPhrases) {
      choices.add(
        _TasbihChoice(
          id: 'tasbih_${phrase.counterId}',
          label: _short(phrase.text),
          text: phrase.text,
          target: 100,
        ),
      );
    }
    return choices;
  }

  _TasbihChoice? _active(List<_TasbihChoice> choices) {
    if (choices.isEmpty) return null;
    for (final choice in choices) {
      if (choice.id == _selectedId) return choice;
    }
    return choices.first;
  }

  void _increment(_TasbihChoice choice) {
    final progress = ref.read(azkarProgressProvider);
    final count = progress.countFor(choice.id);
    if (count >= choice.target) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.lightImpact();
    ref
        .read(azkarProgressProvider.notifier)
        .increment(choice.id, target: choice.target);
    if (count + 1 >= choice.target) HapticFeedback.mediumImpact();
  }

  Future<void> _resetAll(List<_TasbihChoice> choices) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TrText('تصفير المسبحة؟'),
        content: const TrText('هيتم تصفير كل عدادات المسبحة لليوم الحالي.'),
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
    if (result != true) return;
    ref
        .read(azkarProgressProvider.notifier)
        .resetMany(choices.map((choice) => choice.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataAsync = ref.watch(azkarDataProvider);
    final progress = ref.watch(azkarProgressProvider);
    final choices = _choices(dataAsync.valueOrNull);
    final choice = _active(choices);
    final count = choice == null ? 0 : progress.countFor(choice.id);
    final target = choice?.target ?? 1;
    final ratio = (count / target).clamp(0.0, 1.0);
    final total = progress.counts.entries
        .where((entry) => entry.key.startsWith('tasbih_'))
        .fold<int>(0, (sum, entry) => sum + entry.value);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('المسبحة'),
        actions: [
          if (choices.isNotEmpty)
            IconButton(
              tooltip: 'تصفير المسبحة',
              onPressed: () => _resetAll(choices),
              icon: const Icon(Icons.restart_alt_rounded, size: 23),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          if (dataAsync.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AzkarPlaceholder(
                detail: '${dataAsync.error}',
                compact: true,
              ),
            ),
          AzkarHero(
            eyebrow: 'ذكر وعدّاد',
            title: 'سبّح على راحتك',
            subtitle:
                'لمسة واحدة بعدّاد بيتحفظ، وذكرك بيوصل لـ ${_arabicNumber(total)} تسبيحة النهارده.',
            icon: HugeIcons.strokeRoundedTaskDone01,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          ),
          const SizedBox(height: 18),
          const AzkarSectionHeader(
            title: 'اختار الذكر',
            subtitle: 'من أذكار الصباح والصلاة على النبي',
            icon: HugeIcons.strokeRoundedSparkles,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: choices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = choices[index];
                final active = option.id == choice?.id;
                return ChoiceChip(
                  selected: active,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedId = option.id);
                  },
                  showCheckmark: false,
                  label: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.48),
                  side: BorderSide(
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.55,
                          ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (choice != null)
            AzkarSurface(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedStar,
                        size: 14,
                        color: ZakerColors.accent,
                      ),
                      const SizedBox(width: 6),
                      TrText(
                        'الذكر الحالي',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    choice.text,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ZakerTheme.fontQuran,
                      fontSize: 18,
                      height: 1.8,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Semantics(
              button: true,
              label: 'عدّ التسبيحة',
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                onTap: choice == null ? null : () => _increment(choice),
                child: AnimatedScale(
                  scale: _pressed ? 0.975 : 1,
                  duration: const Duration(milliseconds: 110),
                  child: AzkarProgressDial(
                    progress: ratio,
                    size: 286,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.92,
                                end: 1,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _arabicNumber(count),
                            key: ValueKey<int>(count),
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 56,
                              height: 1,
                              color: theme.colorScheme.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'من ${_arabicNumber(target)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const TrText(
                          'اضغط للتسبيح',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: choice == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(azkarProgressProvider.notifier)
                              .reset(choice.id);
                        },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const TrText('إعادة الجولة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: choice == null ? null : () => _increment(choice),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const TrText('تسبيحة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AzkarSurface(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedClock01,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TrText(
                        'إجمالي النهارده',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_arabicNumber(total)} تسبيحة — بيتحفظوا ويتصقّروا مع يوم جديد.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    ],
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

class _TasbihChoice {
  const _TasbihChoice({
    required this.id,
    required this.label,
    required this.text,
    required this.target,
  });

  final String id;
  final String label;
  final String text;
  final int target;
}

String _short(String text) {
  final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= 26) return singleLine;
  return '${singleLine.substring(0, 26)}…';
}

String _arabicNumber(int value) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return value
      .toString()
      .split('')
      .map((digit) => digits[int.tryParse(digit) ?? 0])
      .join();
}
