/// Small reusable widgets shared across the feature screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'tr_text.dart';
import 'zaker_visuals.dart';

/// A titled section with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: ZakerSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: ZakerSpacing.sm),
          ],
          Expanded(
            child: TrText(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: TrText(actionLabel!)),
        ],
      ),
    );
  }
}

/// A tappable feature tile used on the home screen.
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.color,
    this.art,
    this.gradient,
    this.borderColor,
    this.titleColor,
    this.subtitleColor,
    this.iconOnDark = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  /// Replaces the glyph tile with a custom mark, such as the aurora icon.
  final Widget? art;

  /// An optional dark-glass field. When omitted the tile keeps the classic
  /// themed card, so other screens are untouched.
  final LinearGradient? gradient;
  final Color? borderColor;
  final Color? titleColor;
  final Color? subtitleColor;

  /// Lifts the glyph so the accent stays readable on a dark glass field.
  final bool iconOnDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final glyphAccent =
        iconOnDark ? Color.lerp(accent, Colors.white, 0.35)! : accent;

    return ZakerPressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          borderRadius: ZakerRadius.card,
          child: Container(
            padding: const EdgeInsets.all(ZakerSpacing.md),
            decoration: BoxDecoration(
              color: gradient == null ? theme.cardTheme.color : null,
              gradient: gradient,
              borderRadius: ZakerRadius.card,
              border: Border.all(
                color:
                    borderColor ?? theme.dividerTheme.color ?? Colors.black12,
              ),
              boxShadow: ZakerShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                art ??
                    ZakerGlassGlyph(
                      icon: icon,
                      accent: glyphAccent,
                      size: 38,
                      iconSize: 22,
                      radius: ZakerRadius.sm,
                    ),
                const SizedBox(height: ZakerSpacing.sm),
                TrText(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  TrText(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          subtitleColor ?? theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact statistic chip (count + label).
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.labelColor,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  /// Overrides the label's colour; by default it follows the chip's surface.
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    // A near-white accent is how callers mark a chip painted on a coloured
    // banner. The chip then sits on a dark backdrop, so its text has to stay
    // light instead of being adapted to the light card — the theme's muted
    // label colour used to disappear on navy.
    final onBanner = accent.computeLuminance() > 0.8;
    // Text has to clear the chip's own tint, not the bare card behind it.
    final chipSurface = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      cardSurfaceOf(theme),
    );
    final foreground =
        onBanner ? accent : readableTextColor(accent, chipSurface);
    final mutedLabel = readableTextColor(
      theme.colorScheme.onSurfaceVariant,
      chipSurface,
    );
    final resolvedLabel = labelColor ?? (onBanner ? accent : mutedLabel);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZakerSpacing.md,
        vertical: ZakerSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ZakerRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: ZakerSpacing.xs),
          ],
          TrText(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: ZakerSpacing.xs),
          Flexible(
            child: TrText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: resolvedLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A progress bar with a rounded track.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.background,
  });

  /// Progress in the range 0..1.
  final double value;
  final double height;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: background ?? theme.dividerTheme.color,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Placeholder shown when a list is empty.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZakerSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: ZakerSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A loading indicator sized for use inside cards.
class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZakerSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ZakerSkeleton(height: 16),
          const SizedBox(height: ZakerSpacing.sm),
          const ZakerSkeleton(height: 12),
          const SizedBox(height: ZakerSpacing.sm),
          const ZakerSkeleton(height: 12),
          if (label != null) ...[
            const SizedBox(height: ZakerSpacing.md),
            TrText(
              label!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// A horizontal strip of filter chips.
class ChipStrip extends StatelessWidget {
  const ChipStrip({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: ZakerSpacing.lg),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: ZakerSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item == selected;
          return ChoiceChip(
            label: TrText(item),
            selected: isSelected,
            onSelected: (_) => onSelected(item),
          );
        },
      ),
    );
  }
}
