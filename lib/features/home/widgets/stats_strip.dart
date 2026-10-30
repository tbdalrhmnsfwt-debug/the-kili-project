import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';
import 'home_light_style.dart';

/// The three live stat chips under the search field.
///
/// A [Wrap], not a [Row]: at 320 dp with 2.0x text the chips reflow onto a
/// second line instead of overflowing. Each chip is a white card with one
/// functional accent — orange for momentum, cyan for study minutes, purple for
/// the work still waiting.
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
        _StatChip(
          icon: HugeIcons.strokeRoundedFire,
          value: '$streakDays',
          label: 'يوم متواصل',
          accent: HomeLight.orange,
        ),
        _StatChip(
          icon: HugeIcons.strokeRoundedTimer01,
          value: '$minutesToday',
          label: 'دقيقة النهاردة',
          accent: HomeLight.cyan,
        ),
        _StatChip(
          icon: HugeIcons.strokeRoundedTaskDaily01,
          value: '$pendingCount',
          label: 'مهمة مستنية',
          accent: HomeLight.purple,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final List<List<dynamic>> icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.only(
            start: 8,
            end: 12,
            top: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: HomeLight.surface,
            borderRadius: BorderRadius.circular(ZakerRadius.md + 2),
            border: Border.all(color: HomeLight.border),
            boxShadow: HomeLight.shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: HugeIcon(icon: icon, size: 14, color: accent),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Text(
                value,
                style: const TextStyle(
                  color: HomeLight.ink,
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: ZakerSpacing.xs),
              Flexible(
                child: TrText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomeLight.muted,
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
