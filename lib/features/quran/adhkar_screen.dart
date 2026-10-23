/// The adhkar list, loaded from `assets/data/adhkar.json`.
///
/// Each entry in the shipped file looks like:
/// ```json
/// {
///   "order": 1,
///   "content": "الْحَمْدُ لِلَّهِ وَحْدَهُ، ...",
///   "count": 1,
///   "count_description": "مَرَّةٌ وَاحِدَةٌ",
///   "fadl": "استحباب ابتداء الدعاء بالحمد لله ...",
///   "source": "عن أنس يرفعه: ..."
/// }
/// ```
///
/// The `type` field splits the list into the morning set (`1`), the evening
/// set (`2`) and the adhkar said at both times (`0`).
///
/// Shipped strings this screen is built from:
///   * `الأذكار`
///   * `أذكار الصباح` / `أذكار المساء` / `أذكار النوم`
///   * `أذكار {0}`
///   * `أذكار الصباح والمساء — بعداد يمشي معاك`
///   * `خلّصت أذكار {0} 🤍 تقبل الله`
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart' show ZakerStrings;
import '../../core/theme.dart';
import '../../models/tasbih.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

/// The adhkar screen.
class AdhkarScreen extends ConsumerStatefulWidget {
  const AdhkarScreen({super.key});

  @override
  ConsumerState<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends ConsumerState<AdhkarScreen> {
  /// The adhkar shown, filtered by the selected tab.
  List<Map<String, dynamic>> _entries = const [];

  /// Which set of adhkar is shown.
  AdhkarType _filter = AdhkarType.general;

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
      setState(() => _entries = entries);
    } catch (_) {
      // The empty state explains the failure.
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (_filter == AdhkarType.general) return _entries;
    return _entries
        .where((e) => AdhkarType.fromTag(e['type']) == _filter)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TrText(ZakerStrings.s_f9f8b), // الأذكار
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ZakerSpacing.lg,
              0,
              ZakerSpacing.lg,
              ZakerSpacing.sm,
            ),
            child: ChipStrip(
              items: [
                ZakerStrings.s_85ae2, // تسبيحات
                ZakerStrings.s_6f49f, // أذكار الصباح
                ZakerStrings.s_13ecd, // أذكار المساء
              ],
              selected: _selectedLabel,
              onSelected: _onChip,
            ),
          ),
        ),
      ),
      body: _entries.isEmpty
          ? const LoadingBox()
          : _visible.isEmpty
              ? const EmptyState(
                  icon: Icons.spa_outlined,
                  title: ZakerStrings.s_f9f8b, // الأذكار
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(ZakerSpacing.lg),
                  itemCount: _visible.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: ZakerSpacing.md),
                  itemBuilder: (context, index) =>
                      _AdhkarCard(entry: _visible[index], index: index),
                ),
    );
  }

  String get _selectedLabel {
    switch (_filter) {
      case AdhkarType.morning:
        return ZakerStrings.s_6f49f;
      case AdhkarType.evening:
        return ZakerStrings.s_13ecd;
      case AdhkarType.general:
        return ZakerStrings.s_85ae2;
    }
  }

  void _onChip(String label) {
    setState(() {
      if (label == ZakerStrings.s_6f49f) {
        _filter = AdhkarType.morning;
      } else if (label == ZakerStrings.s_13ecd) {
        _filter = AdhkarType.evening;
      } else {
        _filter = AdhkarType.general;
      }
    });
  }
}

/// One adhkar entry.
class _AdhkarCard extends StatelessWidget {
  const _AdhkarCard({required this.entry, required this.index});

  final Map<String, dynamic> entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = (entry['count'] as num?)?.toInt() ?? 1;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ZakerSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: ZakerColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(ZakerRadius.pill),
                ),
                child: TrText(
                  '${entry['order'] ?? index + 1}',
                  style: const TextStyle(
                    color: ZakerColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Expanded(
                child: TrText(
                  entry['count_description'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TrText(
                '× $count',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZakerSpacing.md),
          TrText(
            entry['content'] as String? ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Amiri',
              fontSize: 20,
              height: 2.0,
            ),
          ),
          if ((entry['fadl'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              entry['fadl'] as String,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
          ],
          if ((entry['source'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: ZakerSpacing.sm),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: TrText(
                ZakerStrings.s_58cd4, // المصدر
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              children: [
                TrText(
                  entry['source'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.8),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
