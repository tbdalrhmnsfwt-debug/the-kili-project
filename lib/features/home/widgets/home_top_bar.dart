import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/brand/rafiq_brand.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// The top bar's content height for a [screenHeight].
///
/// 5.5% of the screen stays strictly under the 6% ceiling while keeping the
/// strip proportional on tall phones; the clamp keeps it tappable on short
/// ones and from eating a tablet's top. The 40 dp floor means the strip is
/// under 6% from roughly 667 dp up; below that the 40 dp tap targets win over
/// the percentage.
double homeTopBarHeightFor(double screenHeight) =>
    (screenHeight * 0.055).clamp(40.0, 54.0);

/// The compact navy strip above the greeting: menu, prayer badge, bell,
/// settings.
///
/// It never scrolls away with the body, so the drawer, the live prayer badge
/// and the notifications stay reachable from anywhere in the home. [onMenu] is
/// null when the shell already shows its own menu button (wide screens, where
/// the sidebar is visible). [prayerBadge] replaces the wordmark when supplied;
/// the fallback keeps the bar usable on its own in tests and previews.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.showBadge,
    this.onMenu,
    required this.onNotifications,
    required this.onSettings,
    this.prayerBadge,
  });

  final bool showBadge;
  final VoidCallback? onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;
  final Widget? prayerBadge;

  static const ButtonStyle _iconStyle = ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(Colors.white),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    minimumSize: WidgetStatePropertyAll(Size(40, 40)),
    maximumSize: WidgetStatePropertyAll(Size(40, 40)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final height = homeTopBarHeightFor(media.size.height);
    // On phones the body paints the navy strip under the system status bar.
    // Its default dark glyphs would disappear there, so ask for light ones
    // whenever the strip owns the inset. On wide layouts SafeArea consumes the
    // inset and the off-white surface keeps the theme's dark glyphs instead.
    final iconBrightness =
        theme.brightness == Brightness.dark || media.padding.top > 0
            ? Brightness.light
            : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusBarStyle(iconBrightness),
      child: Container(
        key: const Key('home-top-bar'),
        height: media.padding.top + height,
        decoration: BoxDecoration(
          color: ZakerColors.navy,
          border: Border(
            bottom: BorderSide(color: ZakerColors.gold.withValues(alpha: 0.34)),
          ),
        ),
        // The inset is part of the box's height, so it has to be part of its
        // padding too: otherwise the Row centres its controls inside the
        // status bar and half of each tap target is under the cutout.
        padding: EdgeInsetsDirectional.only(
          top: media.padding.top,
          start: ZakerSpacing.xs,
          end: ZakerSpacing.xs,
        ),
        child: Row(
          children: [
            if (onMenu == null)
              const SizedBox(width: 40)
            else
              IconButton(
                key: const Key('home-top-bar-menu'),
                tooltip: 'القائمة',
                style: _iconStyle,
                onPressed: onMenu,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedMenu01,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: ZakerSpacing.xs),
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: prayerBadge ??
                        TrText(
                          RafiqBrand.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('home-top-bar-bell'),
              tooltip: 'التنبيهات',
              style: _iconStyle,
              onPressed: onNotifications,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedNotification01,
                    size: 21,
                    color: Colors.white,
                  ),
                  if (showBadge)
                    PositionedDirectional(
                      top: -1,
                      end: -1,
                      child: Container(
                        key: const Key('home-top-bar-badge'),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: ZakerColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              key: const Key('home-top-bar-settings'),
              tooltip: 'الإعدادات',
              style: _iconStyle,
              onPressed: onSettings,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSettings01,
                size: 21,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Status-bar glyphs only; the navigation bar is left to its platform style.
  static SystemUiOverlayStyle _statusBarStyle(Brightness iconBrightness) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: iconBrightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      );
}
