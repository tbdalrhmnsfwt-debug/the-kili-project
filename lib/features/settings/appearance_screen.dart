/// "تغيير الشكل": the four palettes and a live preview.
///
/// The home-layout selector is not shown while only one layout exists in code
/// — see `ZakerHomeLayout`; it returns with the second layout.
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
