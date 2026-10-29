import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';
import 'home_style.dart';

/// The three live stat chips inside the navy hero.
///
/// A [Wrap], not a [Row]: at 320 dp with 2.0x text the chips reflow onto a
/// second line instead of overflowing. Each chip carries one functional
/// accent — champagne for momentum, emerald teal for study minutes, coral for
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
          accent: HomePalette.champagne,
        ),
        _StatChip(
          icon: HugeIcons.strokeRoundedTimer01,
          value: '$minutesToday',
          label: 'دقيقة النهاردة',
          accent: HomePalette.emeraldLight,
        ),
        _StatChip(
          icon: HugeIcons.strokeRoundedTaskDaily01,
          value: '$pendingCount',
          label: 'مهمة مستنية',
          accent: HomePalette.coral,
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
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.11),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(ZakerRadius.md + 2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.24)),
                ),
                child: Center(
                  child: HugeIcon(icon: icon, size: 14, color: accent),
                ),
              ),
              const SizedBox(width: ZakerSpacing.sm),
              Text(
                value,
                style: const TextStyle(
                  color: HomePalette.textPrimary,
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
                    color: HomePalette.textSecondary,
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
