/// Backwards-compatible host for the home's top bar.
///
/// The light design lives in [DashboardTopBar]; this wrapper keeps the old
/// `HomeTopBar` import working for screens and tests that still use it.
library;

import 'package:flutter/material.dart';

import '../../dashboard/widgets/header_widget.dart';

export '../../dashboard/widgets/header_widget.dart'
    show DashboardTopBar, WelcomeProgressCard;

/// A nominal content height for callers that reserve space for the bar.
///
/// The real bar is intrinsic so its two lines of type can grow with the
/// reader's text scale; this helper only describes the normal-scale height.
double homeTopBarHeightFor(double screenHeight) =>
    (screenHeight * 0.075).clamp(56.0, 64.0);

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
    return DashboardTopBar(
      showBadge: showBadge,
      onMenu: onMenu,
      onNotifications: onNotifications,
      onSettings: onSettings,
    );
  }
}
