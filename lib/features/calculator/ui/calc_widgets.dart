/// Reusable instrument-style widgets for every calculator mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calc_palette.dart';

final RegExp _arabicPattern = RegExp(r'[؀-ۿ]');

bool _containsArabic(String text) => _arabicPattern.hasMatch(text);

enum CalcKeyTone {
  basic,
  operation,
  utility,
  shift,
  alpha,
  delete,
  clear,
  equals,
}

class CalcPanel extends StatelessWidget {
  const CalcPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Container(
      padding: padding,
      decoration: calcPanelDecoration(
        palette,
        radius: radius,
        color: color,
        elevated: elevated,
      ),
      child: child,
    );
  }
}

class CalcSectionTitle extends StatelessWidget {
  const CalcSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CalcTypography.title(palette, size: 15),
                textDirection: TextDirection.rtl,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: CalcTypography.label(palette, size: 11).copyWith(
                    color: palette.mathMuted,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class CalcPill extends StatelessWidget {
  const CalcPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
    this.active = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final tint = color ?? palette.accent;
    final foreground = active
        ? (ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
              ? Colors.white
              : Colors.black)
        : tint;
    final background = active
        ? tint
        : (palette.isDark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.black.withValues(alpha: 0.045));
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: active ? 0.9 : 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 10 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class CalcSoftButton extends StatelessWidget {  const CalcSoftButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.active = false,
    this.color,
    this.expanded = false,
    this.compact = false,
    this.height,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool active;
  final Color? color;
  final bool expanded;
  final bool compact;

  /// When set, the hit area fills this height instead of hugging the label.
  ///
  /// The modifier strip uses it so small labels still get a comfortable
  /// touch target.
  final double? height;

  /// Screen-reader label when the visible text is a symbol.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final tint = color ?? palette.accent;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      height: height,
      alignment: height == null ? null : Alignment.center,
      // Small symbol buttons would otherwise have a tiny hit area.
      constraints: compact
          ? BoxConstraints(minWidth: 44, minHeight: height ?? 40)
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: active
            ? tint.withValues(alpha: 0.2)
            : (palette.isDark
                ? Colors.white.withValues(alpha: 0.045)
                : Colors.white.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? tint.withValues(alpha: 0.8) : palette.border,
        ),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compact ? 14 : 16,
              color: onPressed == null
                  ? palette.mathMuted.withValues(alpha: 0.5)
                  : (active ? tint : palette.label),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onPressed == null
                    ? palette.mathMuted.withValues(alpha: 0.5)
                    : (active ? tint : palette.label),
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w700,
              ),
              textDirection: _containsArabic(label)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

class CalcSegmented<T> extends StatelessWidget {
  const CalcSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
    this.compact = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.black.withValues(alpha: 0.24)
            : Colors.black.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(value);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      vertical: compact ? 5 : 7,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: value == selected
                          ? palette.accent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      border: Border.all(
                        color: value == selected
                            ? palette.accent.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      labelFor(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: value == selected
                            ? palette.accent
                            : palette.mathMuted,
                        fontSize: compact ? 10.5 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CalcLabeledField extends StatelessWidget {
  const CalcLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.ltr = true,
    this.suffix,
    this.focusNode,
    this.autofocus = false,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool ltr;
  final Widget? suffix;
  final FocusNode? focusNode;
  final bool autofocus;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CalcTypography.label(palette, size: 10.5),
          textDirection: TextDirection.rtl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
          textAlign: TextAlign.left,
          style: CalcTypography.math(palette, size: 15).copyWith(
            fontWeight: FontWeight.w600,
          ),
          cursorColor: palette.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintTextDirection: TextDirection.ltr,
            hintStyle: TextStyle(
              color: palette.mathMuted.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            suffixIcon: suffix,
            isDense: true,
            filled: true,
            fillColor: palette.isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.62),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: palette.accent, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class CalcKeySpec {
  const CalcKeySpec({
    required this.label,
    this.shiftLabel,
    this.alphaLabel,
    this.onTap,
    this.tone = CalcKeyTone.basic,
    this.active = false,
    this.semanticLabel,
  });

  final String label;
  final String? shiftLabel;
  final String? alphaLabel;
  final VoidCallback? onTap;
  final CalcKeyTone tone;
  final bool active;
  final String? semanticLabel;
}

class CalcKeyButton extends StatefulWidget {
  const CalcKeyButton({
    super.key,
    required this.spec,
    this.haptics = true,
    this.fontScale = 1,
  });

  final CalcKeySpec spec;
  final bool haptics;
  final double fontScale;

  @override
  State<CalcKeyButton> createState() => _CalcKeyButtonState();
}

class _CalcKeyButtonState extends State<CalcKeyButton> {
  bool _pressed = false;

  void _down(TapDownDetails _) {
    if (widget.spec.onTap == null) return;
    setState(() => _pressed = true);
    if (widget.haptics) HapticFeedback.selectionClick();
  }

  void _cancel() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    final spec = widget.spec;
    final (Color base, Color top, Color text) = switch (spec.tone) {
      CalcKeyTone.basic => (palette.basicKey, palette.basicKeyTop, palette.keyText),
      CalcKeyTone.operation => (
          palette.operationKey,
          palette.operationKeyTop,
          palette.operationText,
        ),
      CalcKeyTone.utility => (
          palette.utilityKey,
          palette.utilityKeyTop,
          palette.label,
        ),
      CalcKeyTone.shift => (
          palette.shift,
          Color.lerp(palette.shift, Colors.white, 0.22)!,
          const Color(0xFF1C1608),
        ),
      CalcKeyTone.alpha => (
          palette.alpha,
          Color.lerp(palette.alpha, Colors.white, 0.16)!,
          Colors.white,
        ),
      CalcKeyTone.delete => (
          palette.deleteKey,
          Color.lerp(palette.deleteKey, Colors.white, 0.18)!,
          Colors.white,
        ),
      CalcKeyTone.clear => (
          palette.clearKey,
          Color.lerp(palette.clearKey, Colors.white, 0.14)!,
          Colors.white,
        ),
      CalcKeyTone.equals => (
          palette.equalsKey,
          Color.lerp(palette.equalsKey, Colors.white, 0.25)!,
          palette.equalsText,
        ),
    };
    final active = spec.active;
    final scale = _pressed ? 0.955 : 1.0;
    return Semantics(
      button: true,
      label: spec.semanticLabel ?? spec.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapCancel: _cancel,
        onTapUp: (_) => _cancel(),
        onTap: spec.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? Color.lerp(base, Colors.white, 0.55)!
                    : Colors.white.withValues(alpha: palette.isDark ? 0.09 : 0.55),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[top, base],
              ),
              boxShadow: _pressed
                  ? <BoxShadow>[
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : <BoxShadow>[
                      BoxShadow(
                        color: palette.shadow.withValues(
                          alpha: palette.isDark ? 0.62 : 0.22,
                        ),
                        blurRadius: 7,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(
                          alpha: palette.isDark ? 0.07 : 0.7,
                        ),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                // Specular highlight across the upper bevel.
                Positioned(
                  left: 5,
                  right: 5,
                  top: 1,
                  height: 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(
                            alpha: spec.tone == CalcKeyTone.basic ? 0.24 : 0.4,
                          ),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (spec.shiftLabel != null && spec.shiftLabel!.isNotEmpty)
                  Positioned(
                    left: 6,
                    top: 2.5,
                    child: Text(
                      spec.shiftLabel!,
                      maxLines: 1,
                      style: TextStyle(
                        color: palette.shiftText,
                        fontSize: 7.5 * widget.fontScale,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                if (spec.alphaLabel != null && spec.alphaLabel!.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 2.5,
                    child: Text(
                      spec.alphaLabel!,
                      maxLines: 1,
                      style: TextStyle(
                        color: palette.alpha,
                        fontSize: 7.5 * widget.fontScale,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: (spec.shiftLabel != null || spec.alphaLabel != null)
                          ? 5
                          : 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        spec.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: text,
                          fontSize: 15.5 * widget.fontScale,
                          fontWeight: spec.tone == CalcKeyTone.equals
                              ? FontWeight.w900
                              : FontWeight.w700,
                          height: 1.05,
                          letterSpacing: -0.2,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
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

class CalcDpad extends StatelessWidget {
  const CalcDpad({
    super.key,
    required this.onLeft,
    required this.onRight,
    required this.onUp,
    required this.onDown,
    this.enabled = true,
  });

  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    Widget button(IconData icon, VoidCallback onTap, String label) {
      return Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 42,
            child: Icon(
              icon,
              size: 19,
              color: enabled
                  ? palette.label
                  : palette.mathMuted.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.border),
      ),
      child: Directionality(
        // Cursor arrows move an LTR math caret, so they must not mirror with
        // the Arabic interface.
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(Icons.chevron_left_rounded, onLeft, 'يسار'),
            button(Icons.keyboard_arrow_up_rounded, onUp, 'أعلى'),
            button(Icons.keyboard_arrow_down_rounded, onDown, 'أسفل'),
            button(Icons.chevron_right_rounded, onRight, 'يمين'),
          ],
        ),
      ),
    );
  }
}

class CalcEmptyState extends StatelessWidget {
  const CalcEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accentSoft,
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(icon, color: palette.accent, size: 27),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: CalcTypography.title(palette, size: 15),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              message,
              style: CalcTypography.label(palette, size: 11.5).copyWith(
                color: palette.mathMuted,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CalcResultBanner extends StatelessWidget {
  const CalcResultBanner({
    super.key,
    required this.child,
    this.isError = false,
    this.note,
  });

  final Widget child;
  final bool isError;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final palette = CalcPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? palette.dangerSoft : palette.accentSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isError ? palette.danger : palette.accent).withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DefaultTextStyle.merge(
            style: TextStyle(
              color: isError ? palette.danger : palette.math,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
          if (note != null) ...[
            const SizedBox(height: 5),
            Text(
              note!,
              style: TextStyle(
                color: isError ? palette.danger : palette.mathMuted,
                fontSize: 10.5,
                height: 1.4,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ],
      ),
    );
  }
}
