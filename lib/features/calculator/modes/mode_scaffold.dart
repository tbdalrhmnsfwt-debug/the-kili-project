/// Shared shell for calculator mode pages.
library;

import 'package:flutter/material.dart';

import '../ui/calc_palette.dart';
import '../ui/calc_widgets.dart';

class CalcModePage extends StatelessWidget {
  const CalcModePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 14),
    this.refresh,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final Future<void> Function()? refresh;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: scrollable
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: child,
            )
          : child,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CalcSectionTitle(title: title, subtitle: subtitle),
              ),
              if (trailing != null || refresh != null) ...[
                const SizedBox(width: 8),
                if (refresh != null)
                  IconButton(
                    tooltip: 'تحديث',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => refresh!(),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                if (trailing != null) trailing!,
              ],
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

class CalcModeCard extends StatelessWidget {
  const CalcModeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: CalcPanel(padding: padding, child: child),
    );
  }
}

class CalcFieldRow extends StatelessWidget {
  const CalcFieldRow({
    super.key,
    required this.children,
    this.spacing = 8,
    this.minFieldWidth = 120,
  });

  final List<Widget> children;
  final double spacing;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width < minFieldWidth * 2 + spacing ? 1 : children.length;
        if (count == 1) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class CalcActionGrid extends StatelessWidget {
  const CalcActionGrid({
    super.key,
    required this.actions,
    this.minWidth = 112,
  });

  final List<Widget> actions;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 4);
        final rows = (actions.length / columns).ceil();
        return Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: 7),
              Row(
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 7),
                    Expanded(
                      child: (row * columns + column) < actions.length
                          ? actions[row * columns + column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class CalcMetric extends StatelessWidget {
  const CalcMetric({
    super.key,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CalcTypography.label(palette, size: 9.5).copyWith(
              color: palette.mathMuted,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CalcTypography.math(
              palette,
              size: 15,
              color: accent ? palette.accent : palette.math,
            ).copyWith(fontWeight: FontWeight.w700),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}

class CalcNote extends StatelessWidget {
  const CalcNote(
      {super.key, required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: palette.mathMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: CalcTypography.label(palette, size: 10).copyWith(
              color: palette.mathMuted,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    );
  }
}
