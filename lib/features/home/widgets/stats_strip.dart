import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// The three quiet stat chips under the welcome card.
///
/// A [Wrap], not a [Row]: at 320 dp with 2.0x text the chips reflow onto a
/// second line instead of overflowing.
class HomeStatsStrip extends StatelessWidget {
  const HomeStatsStrip({
    super.key,
    required this.streakDays,
    required this.minutesToday,
    required this.pendingCount,
  });

  final int streakDays;
  final int minutesToday;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('home-stats'),
      spacing: ZakerSpacing.sm,
      runSpacing: ZakerSpacing.sm,
      children: [
        _StatChip(value: '$streakDays', label: 'يوم متواصل'),
        _StatChip(value: '$minutesToday', label: 'دقيقة النهاردة'),
        _StatChip(value: '$pendingCount', label: 'مهمة مستنية'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: cardSurfaceOf(theme),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
        border: Border.all(color: ZakerColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: ZakerSpacing.xs),
          Flexible(
            child: TrText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
