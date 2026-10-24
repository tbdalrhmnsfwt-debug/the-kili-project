/// "تغيير الشكل": the four palettes and the home-layout selector.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/appearance.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tr_text.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final palette = ZakerTheme.paletteFor(settings.themeStyle);

    return Scaffold(
      appBar: AppBar(title: const TrText('تغيير الشكل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ZakerSpacing.lg,
          ZakerSpacing.sm,
          ZakerSpacing.lg,
          ZakerSpacing.xxl,
        ),
        children: [
          const SectionHeader(
            title: 'ثيم التطبيق',
            icon: Icons.palette_outlined,
          ),
          const TrText(
            'التغيير بيتطبق فورًا على كل الشاشات، وبيتحفظ على الجهاز.',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZakerSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = ZakerSpacing.md;
              final width = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final style in ZakerThemeStyle.values)
                    SizedBox(
                      width: width,
                      child: _ThemeCard(
                        style: style,
                        selected: style == settings.themeStyle,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.setTheme(style);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: ZakerSpacing.xl),
          const SectionHeader(
            title: 'شكل الصفحة الرئيسية',
            icon: Icons.dashboard_customize_outlined,
          ),
          for (final layout in ZakerHomeLayout.values)
            _LayoutTile(
              layout: layout,
              selected: layout == settings.homeLayout,
              onTap: layout.available
                  ? () => controller.setHomeLayout(layout)
                  : null,
            ),
          const SizedBox(height: ZakerSpacing.xl),
          SectionHeader(
            title: 'معاينة مباشرة',
            icon: Icons.visibility_outlined,
            actionLabel: palette.style.label,
          ),
          Container(
            padding: const EdgeInsets.all(ZakerSpacing.lg),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(ZakerRadius.lg),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.accents.islamic.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(ZakerRadius.md),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: palette.accents.islamic,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: ZakerSpacing.md),
                    Expanded(
                      child: TrText(
                        'عنوان تجريبي',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: palette.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZakerSpacing.md),
                TrText(
                  'النص العادي في التطبيق لازم يفضل مقروء في كل الثيمات، '
                  'والألوان كلها جايّة من نفس مكان واحد.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: ZakerSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {},
                    child: const TrText('زر تجريبي'),
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

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final ZakerThemeStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ZakerTheme.paletteFor(style);
    return Semantics(
      selected: selected,
      button: true,
      label: 'ثيم ${style.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZakerRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(ZakerSpacing.sm),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(ZakerRadius.lg),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 62,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(ZakerRadius.md),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    _Swatch(color: palette.primary),
                    const SizedBox(width: 6),
                    _Swatch(color: palette.accents.study),
                    const SizedBox(width: 6),
                    _Swatch(color: palette.accents.azkar),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: palette.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: ZakerSpacing.sm),
              TrText(
                style.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.onSurface,
                ),
              ),
              TrText(
                style.brightness == Brightness.dark ? 'داكن' : 'فاتح',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final ZakerHomeLayout layout;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = layout.available;
    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: Container(
        margin: const EdgeInsets.only(bottom: ZakerSpacing.sm),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: ZakerRadius.card,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerTheme.color ?? Colors.black12,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: ZakerRadius.card,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZakerSpacing.md,
                vertical: ZakerSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    layout == ZakerHomeLayout.calm
                        ? Icons.space_dashboard_outlined
                        : Icons.dashboard_outlined,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: ZakerSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrText(
                          layout.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TrText(
                          layout == ZakerHomeLayout.calm
                              ? 'الشكل الحالي — هادي وواضح'
                              : 'شكل إضافي — لسه مش موجود',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!enabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: BorderRadius.circular(ZakerRadius.pill),
                      ),
                      child: const TrText(
                        'قريبًا',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
