import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../widgets/tr_text.dart';
import 'home_style.dart';

/// The six primary study features, presented as a rounded card grid.
///
/// The section deliberately uses the brand's navy and gold rather than six
/// different accents: the three pastel action cards above are the colourful
/// moment on the page, and these cards are the calm, readable tool shelf.
class CoreFeaturesGrid extends StatelessWidget {
  const CoreFeaturesGrid({super.key});

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle _subtitleStyle = TextStyle(
    fontSize: 11.5,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final features = <({
      String id,
      IconData icon,
      String title,
      String subtitle,
      String route,
      Color accent,
    })>[
      (
        id: 'textbooks',
        icon: Icons.menu_book_rounded,
        title: 'الكتب الدراسية الرقمية',
        subtitle: 'منهجك ومراجعك',
        route: ZakerRoutes.courses,
        accent: HomePalette.emerald,
      ),
      (
        id: 'pdf-reader',
        icon: Icons.picture_as_pdf_rounded,
        title: 'قارئ PDF التفاعلي',
        subtitle: 'مع أدوات التحديد',
        route: ZakerRoutes.pdfLibrary,
        accent: HomePalette.champagne,
      ),
      (
        id: 'calculator',
        icon: Icons.calculate_rounded,
        title: 'الآلة الحاسبة العلمية',
        subtitle: 'دوال ورسم بياني',
        route: ZakerRoutes.calculator,
        accent: HomePalette.coral,
      ),
      (
        id: 'notebooks',
        icon: Icons.edit_note_rounded,
        title: 'دفاتر الملاحظات',
        subtitle: 'نظّم أفكارك',
        route: ZakerRoutes.notebooks,
        accent: HomePalette.amber,
      ),
      (
        id: 'mind-maps',
        icon: Icons.account_tree_rounded,
        title: 'الخرائط الذهنية',
        subtitle: 'اربط المفاهيم',
        route: ZakerRoutes.mindMap,
        accent: HomePalette.emeraldLight,
      ),
      (
        id: 'ai-explanations',
        icon: Icons.auto_awesome_rounded,
        title: 'الشروحات بمساعدة الذكاء الاصطناعي',
        subtitle: 'شرح خطوة بخطوة',
        route: ZakerRoutes.chat,
        accent: HomePalette.champagneLight,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final scale = scaler.scale(1);
        // Large text needs wider cards: a single column on phones, and two
        // instead of three on tablets. The AI title is four Arabic words and
        // cannot fit three narrow columns at 2.0x.
        final columns = constraints.maxWidth >= 720
            ? (scale >= 1.75 ? 2 : 3)
            : (scale >= 1.5 ? 1 : 2);
        // The long AI title is four Arabic words. At 2.0x each word needs its
        // own line even on a full-width phone card, so reserve four lines for
        // every layout and let the tighter columns use the same reserve.
        const titleLines = 4;
        final titleLine =
            scaler.scale(_titleStyle.fontSize!) * _titleStyle.height!;
        final subtitleLine =
            scaler.scale(_subtitleStyle.fontSize!) * _subtitleStyle.height!;
        // Padding, icon badge, the gap above the text block, the two text
        // blocks, and a little slack for line-box rounding.
        final extent = 16 * 2 +
            44 +
            12 +
            titleLine * titleLines +
            4 +
            subtitleLine * 2 +
            10;

        final spacing = 12.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          key: const Key('home-feature-grid'),
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final feature in features)
              SizedBox(
                width: tileWidth,
                height: extent,
                child: _FeatureCard(
                  key: Key('home-feature-${feature.id}'),
                  icon: feature.icon,
                  title: feature.title,
                  subtitle: feature.subtitle,
                  route: feature.route,
                  accent: feature.accent,
                  maxTitleLines: titleLines,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.accent,
    required this.maxTitleLines,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color accent;
  final int maxTitleLines;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final glyph = Color.lerp(accent, Colors.white, 0.22)!;

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topEnd,
              end: AlignmentDirectional.bottomStart,
              colors: HomePalette.tintedCardGradient(accent),
            ),
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: 0.26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () => context.push(route),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(icon, size: 23, color: glyph),
                      ),
                      const Spacer(),
                      Icon(
                        // Material mirrors this in RTL, so it still points
                        // forward (left in Arabic) on the card.
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: HomePalette.champagne,
                      ),
                    ],
                  ),
                  const Spacer(),
                  TrText(
                    title,
                    maxLines: maxTitleLines,
                    overflow: TextOverflow.ellipsis,
                    style: CoreFeaturesGrid._titleStyle.copyWith(
                      color: HomePalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TrText(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CoreFeaturesGrid._subtitleStyle.copyWith(
                      color: HomePalette.textSecondary,
                    ),
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
