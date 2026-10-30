/// The home's visual language: deep navy slate, champagne gold, emerald teal,
/// soft amber and coral, held together by dark glass.
///
/// These tokens are deliberately scoped to the home screen. The rest of the
/// app keeps the `ZakerColors` / `ZakerPalette` system, so this richer
/// treatment can evolve without repainting every other screen.
library;

import 'package:flutter/material.dart';

/// The home palette.
abstract final class HomePalette {
  const HomePalette._();

  /// The darkest slate, used behind navy glass and as the page anchor.
  static const Color midnight = Color(0xFF08111F);

  /// Deep navy slate: the primary anchor.
  static const Color navy = Color(0xFF0E1B2E);

  /// The raised navy-slate used for glass panels and card tops.
  static const Color navyRaised = Color(0xFF16273F);

  /// A lighter edge for hairlines inside glass.
  static const Color slateEdge = Color(0xFF2A4059);

  /// Premium champagne gold: the secondary accent.
  static const Color champagne = Color(0xFFE7C879);

  /// A soft champagne for text and small icons on navy.
  static const Color champagneLight = Color(0xFFF5E5B4);

  /// The readable champagne for labels on light surfaces.
  static const Color champagneDeep = Color(0xFF9A7627);

  /// Emerald teal: study progress, minutes and momentum.
  static const Color emerald = Color(0xFF12A58B);

  /// A lifted emerald for icons on dark glass.
  static const Color emeraldLight = Color(0xFF6FE3C8);

  /// The emerald used for text on light surfaces.
  static const Color emeraldDeep = Color(0xFF0B7A66);

  /// Soft amber for time, deadlines and highlights.
  static const Color amber = Color(0xFFF2B45A);

  /// Coral for actionable cards and gentle urgency.
  static const Color coral = Color(0xFFF07C6C);

  /// A lifted coral for supporting text on dark glass.
  static const Color coralLight = Color(0xFFFFB4A8);

  /// Foregrounds on the navy glass.
  static const Color textPrimary = Color(0xFFF6F8FC);
  static const Color textSecondary = Color(0xFFB8C5D8);
  static const Color textFaint = Color(0xFF93A3BA);

  /// The hero field: three navy-slate stops with a cool centre.
  static const List<Color> headerGradient = [
    Color(0xFF0A1524),
    Color(0xFF14263F),
    Color(0xFF0B1728),
  ];

  /// The default glass panel.
  static const List<Color> panelGradient = [
    Color(0xFF1A2C46),
    Color(0xFF0C1626),
  ];

  /// The action-card fields: dark slate warmed by each functional accent.
  static const List<Color> assistantGradient = [
    Color(0xFF2B2617),
    Color(0xFF111A29),
  ];
  static const List<Color> bagGradient = [
    Color(0xFF0D2E2B),
    Color(0xFF0C1826),
  ];
  static const List<Color> tasksGradient = [
    Color(0xFF34212A),
    Color(0xFF131725),
  ];

  /// The two banner fields: warm amber for deadlines, emerald for advice.
  static const List<Color> countdownGradient = [
    Color(0xFF3A2A12),
    Color(0xFF171823),
  ];
  static const List<Color> adviceGradient = [
    Color(0xFF0E302B),
    Color(0xFF111B28),
  ];

  /// The accent cycle for the all-tools grid: champagne, emerald, coral and
  /// amber repeated, never a rainbow of unrelated hues.
  static const List<Color> toolAccents = [
    champagne,
    emeraldLight,
    coral,
    amber,
    emerald,
    champagneLight,
  ];

  /// A subtle accent wash over the raised navy, for tool and feature cards.
  static List<Color> tintedCardGradient(Color accent) => [
        Color.alphaBlend(accent.withValues(alpha: 0.12), navyRaised),
        midnight,
      ];
}

/// A navy glass surface with an inner sheen, a hairline accent and a soft
/// accent shadow. Used for the home's cards so the treatment stays in one
/// place instead of drifting between sections.
class HomeGlassPanel extends StatelessWidget {
  const HomeGlassPanel({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.gradient,
    this.borderColor,
    this.shadows,
    this.showSheen = true,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? gradient;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final bool showSheen;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? HomePalette.champagne;
    final corners = BorderRadius.circular(radius);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: gradient ?? HomePalette.panelGradient,
        ),
        borderRadius: corners,
        border: Border.all(
          color: borderColor ?? tint.withValues(alpha: 0.24),
        ),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
              BoxShadow(
                color: tint.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: Stack(
        children: [
          if (showSheen)
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              height: 58,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.09),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// The atmosphere painted behind the home header: three slow radial glows
/// (champagne, emerald and coral) over the navy field.
///
/// It is static by design. The screen already has enough movement in its
/// press states, and an always-animating hero would cost battery for no
/// information.
class HomeHeaderAtmosphere extends StatelessWidget {
  const HomeHeaderAtmosphere({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _HeaderAtmospherePainter()),
    );
  }
}

class _HeaderAtmospherePainter extends CustomPainter {
  const _HeaderAtmospherePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _glow(
      canvas,
      Offset(size.width * 0.92, size.height * 0.10),
      size.width * 0.55,
      HomePalette.champagne,
      0.17,
    );
    _glow(
      canvas,
      Offset(size.width * 0.06, size.height * 0.82),
      size.width * 0.52,
      HomePalette.emerald,
      0.16,
    );
    _glow(
      canvas,
      Offset(size.width * 0.70, size.height * 1.05),
      size.width * 0.44,
      HomePalette.coral,
      0.10,
    );
    _glow(
      canvas,
      Offset(size.width * 0.36, size.height * 0.34),
      size.width * 0.38,
      Colors.white,
      0.035,
    );
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderAtmospherePainter oldDelegate) => false;
}
