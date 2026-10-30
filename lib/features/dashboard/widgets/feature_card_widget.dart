/// The dashboard's feature card.
///
/// Every card on the home uses the same quiet geometry: a 24 dp pastel field,
/// a white icon circle pinned to the top-left, the title and subtitle at the
/// start edge, and a small coloured arrow button at the bottom-left. The
/// colours are the only thing that changes between features.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/tr_text.dart';
import '../../home/widgets/home_light_style.dart';

/// The colour pair and solid accent for one feature card.
class FeatureCardPalette {
  const FeatureCardPalette({required this.gradient, required this.accent});

  final List<Color> gradient;
  final Color accent;

  static const mint = FeatureCardPalette(
    gradient: HomeLight.mintGradient,
    accent: HomeLight.mint,
  );
  static const cyan = FeatureCardPalette(
    gradient: HomeLight.cyanGradient,
    accent: HomeLight.cyan,
  );
  static const orange = FeatureCardPalette(
    gradient: HomeLight.orangeGradient,
    accent: HomeLight.orange,
  );
  static const purple = FeatureCardPalette(
    gradient: HomeLight.purpleGradient,
    accent: HomeLight.purple,
  );
  static const deepBlue = FeatureCardPalette(
    gradient: HomeLight.deepBlueGradient,
    accent: HomeLight.blue,
  );
  static const teal = FeatureCardPalette(
    gradient: HomeLight.tealGradient,
    accent: HomeLight.teal,
  );

  /// The six pastel fields, repeated down the all-tools shelf.
  static const List<FeatureCardPalette> cycle = [
    mint,
    cyan,
    orange,
    purple,
    deepBlue,
    teal,
  ];
}

/// The height a feature card needs for [width] and the user's text scale.
///
/// The design calls for a 1.1 aspect ratio on a normal phone. That ratio is
/// too short once a reader uses large text, so the card keeps the designed
/// shape where it fits and grows its height where the text needs it.
double featureCardExtent(
  double width, {
  required double textScale,
  bool dense = false,
}) {
  final base = dense
      ? 28 +
          34 +
          6 +
          (13 * 1.2 * 2) * textScale +
          2 +
          (10 * 1.2) * textScale +
          6 +
          28
      : 28 +
          38 +
          6 +
          (13.5 * 1.2 * 2) * textScale +
          2 +
          (10.5 * 1.2) * textScale +
          6 +
          30;
  return math.max(width / 1.1, base + 10);
}

/// One pastel dashboard card with a white icon circle and arrow action.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.title,
    required this.icon,
    required this.palette,
    required this.onTap,
    this.subtitle,
    this.dense = false,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final FeatureCardPalette palette;
  final VoidCallback onTap;
  final bool dense;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HomeLight.cardRadius);
    final iconSize = dense ? 34.0 : 38.0;
    final actionSize = dense ? 28.0 : 30.0;

    return Semantics(
      button: true,
      label: semanticLabel ?? title,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: palette.gradient,
            ),
            borderRadius: radius,
            boxShadow: HomeLight.shadow,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  // A barely visible white orb keeps the pastel field from
                  // reading as a flat swatch without adding another element.
                  PositionedDirectional(
                    top: -26,
                    end: -18,
                    child: IgnorePointer(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.26),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: palette.accent.withValues(alpha: 0.16),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                icon,
                                size: dense ? 18 : 20,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        TrText(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomeLight.ink,
                            fontSize: dense ? 13 : 13.5,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          TrText(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HomeLight.mutedStrong,
                              fontSize: dense ? 10 : 10.5,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: ExcludeSemantics(
                            child: IgnorePointer(
                              child: Container(
                                width: actionSize,
                                height: actionSize,
                                decoration: BoxDecoration(
                                  color: palette.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.accent
                                          .withValues(alpha: 0.28),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  // The brief pins the action to the physical
                                  // bottom-left, so the arrow points outward
                                  // in the Arabic reading direction.
                                  Icons.arrow_back_rounded,
                                  size: dense ? 15 : 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
