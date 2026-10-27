import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/brand/rafiq_brand.dart';
import '../../../core/theme.dart';
import '../../../widgets/tr_text.dart';

/// The top bar's content height for a [screenHeight].
///
/// 6% of the screen keeps the bar proportional on tall phones; the clamp keeps
/// it tappable on short ones and from eating a tablet's top.
double homeTopBarHeightFor(double screenHeight) =>
    (screenHeight * 0.06).clamp(48.0, 56.0);

/// The compact brand bar above the greeting: name, menu, bell, settings.
///
/// It never scrolls away with the body, so the drawer and the notifications
/// stay reachable from anywhere in the home. [onMenu] is null when the shell
/// already shows its own menu button (wide screens, where the sidebar is
/// visible).
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.showBadge,
    this.onMenu,
    required this.onNotifications,
    required this.onSettings,
  });

  final bool showBadge;
  final VoidCallback? onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    return SizedBox(
      key: const Key('home-top-bar'),
      height: media.padding.top + homeTopBarHeightFor(media.size.height),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ZakerSpacing.sm,
        ),
        child: Row(
          children: [
            if (onMenu == null)
              const SizedBox(width: 48)
            else
              IconButton(
                key: const Key('home-top-bar-menu'),
                tooltip: 'القائمة',
                onPressed: onMenu,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedMenu01,
                  size: 22,
                ),
              ),
            Expanded(
              child: TrText(
                RafiqBrand.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              key: const Key('home-top-bar-bell'),
              tooltip: 'التنبيهات',
              onPressed: onNotifications,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedNotification01,
                    size: 22,
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
              onPressed: onSettings,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSettings01,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
