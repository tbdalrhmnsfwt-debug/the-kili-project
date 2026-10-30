import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../dashboard/widgets/feature_card_widget.dart';

/// The six primary study features as a two-column pastel card grid.
///
/// The first four open their own routes. The AI card opens the chat, and the
/// last card asks the home to scroll to the all-tools shelf, so no destination
/// is lost in the redesign.
class CoreFeaturesGrid extends StatelessWidget {
  const CoreFeaturesGrid({super.key, this.onMoreTools});

  /// Called by the "المزيد من الأدوات" card. When omitted the card is inert.
  final VoidCallback? onMoreTools;

  @override
  Widget build(BuildContext context) {
    final features = <({
      String id,
      IconData icon,
      String title,
      String subtitle,
      FeatureCardPalette palette,
      VoidCallback onTap,
    })>[
      (
        id: 'textbooks',
        icon: Icons.menu_book_rounded,
        title: 'الكتب الدراسية الرقمية',
        subtitle: 'منهجك ومراجعك',
        palette: FeatureCardPalette.mint,
        onTap: () => context.push(ZakerRoutes.courses),
      ),
      (
        id: 'pdf-reader',
        icon: Icons.picture_as_pdf_rounded,
        title: 'قارئ PDF التفاعلي',
        subtitle: 'مع أدوات التحديد',
        palette: FeatureCardPalette.cyan,
        onTap: () => context.push(ZakerRoutes.pdfLibrary),
      ),
      (
        id: 'calculator',
        icon: Icons.calculate_rounded,
        title: 'الآلة الحاسبة العلمية',
        subtitle: 'دوال ورسم بياني',
        palette: FeatureCardPalette.orange,
        onTap: () => context.push(ZakerRoutes.calculator),
      ),
      (
        id: 'notebooks',
        icon: Icons.edit_note_rounded,
        title: 'دفاتر الملاحظات',
        subtitle: 'نظّم أفكارك',
        palette: FeatureCardPalette.purple,
        onTap: () => context.push(ZakerRoutes.notebooks),
      ),
      (
        id: 'ai',
        icon: Icons.auto_awesome_rounded,
        title: 'الذكاء الاصطناعي',
        subtitle: 'اسأل واشرح',
        palette: FeatureCardPalette.deepBlue,
        onTap: () => context.push(ZakerRoutes.chat),
      ),
      (
        id: 'more-tools',
        icon: Icons.grid_view_rounded,
        title: 'المزيد من الأدوات',
        subtitle: 'كل الأدوات',
        palette: FeatureCardPalette.teal,
        onTap: onMoreTools ?? () {},
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 640
                ? 3
                : 2;
        const spacing = 16.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final extent = featureCardExtent(tileWidth, textScale: scale);

        return GridView.builder(
          key: const Key('home-feature-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: extent,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return FeatureCard(
              key: Key('home-feature-${feature.id}'),
              title: feature.title,
              subtitle: feature.subtitle,
              icon: feature.icon,
              palette: feature.palette,
              onTap: feature.onTap,
            );
          },
        );
      },
    );
  }
}
