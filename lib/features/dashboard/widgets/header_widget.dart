/// The dashboard's light header: the compact brand bar and the welcome card.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/brand/rafiq_brand.dart';
import '../../../widgets/tr_text.dart';
import '../../home/widgets/home_light_style.dart';

/// The light top bar: brand name, subtitle, and rounded notification/settings
/// controls. The menu button is optional because the wide layout shows the
/// sidebar instead of the drawer.
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.showBadge,
    required this.onNotifications,
    required this.onSettings,
    this.onMenu,
  });

  final bool showBadge;
  final VoidCallback? onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Container(
        key: const Key('home-top-bar'),
        padding: EdgeInsetsDirectional.fromSTEB(16, topInset + 10, 16, 8),
        child: Row(
          children: [
            if (onMenu != null) ...[
              _RoundIconButton(
                key: const Key('home-top-bar-menu'),
                tooltip: 'القائمة',
                icon: Icons.menu_rounded,
                onTap: onMenu!,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TrText(
                    RafiqBrand.appName,
                    key: const Key('home-app-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomeLight.ink,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const TrText(
                    'طريقك نحو مستقبل أفضل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomeLight.mutedStrong,
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              key: const Key('home-top-bar-bell'),
              tooltip: 'التنبيهات',
              icon: Icons.notifications_none_rounded,
              onTap: onNotifications,
              showBadge: showBadge,
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              key: const Key('home-top-bar-settings'),
              tooltip: 'الإعدادات',
              icon: Icons.settings_outlined,
              onTap: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showBadge = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: HomeLight.shadow,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(icon, size: 21, color: HomeLight.ink),
                  ),
                  if (showBadge)
                    PositionedDirectional(
                      top: 10,
                      end: 10,
                      child: Container(
                        key: const Key('home-top-bar-badge'),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: HomeLight.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
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

/// The "مرحباً بك" card: greeting and book mark on the right, today's progress
/// ring on the left.
class WelcomeProgressCard extends StatelessWidget {
  const WelcomeProgressCard({
    super.key,
    required this.name,
    required this.progress,
    this.footer,
  });

  final String name;

  /// Today's progress in the range 0..1.
  final double progress;

  /// An optional row such as the live prayer badge.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final safeName = name.trim().isEmpty ? 'طالب' : name.trim();
    final value = progress.clamp(0.0, 1.0);
    final percent = (value * 100).round();

    return Container(
      key: const Key('home-header'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: HomeLight.headerGradient,
        ),
        borderRadius: BorderRadius.circular(HomeLight.cardRadius),
        boxShadow: HomeLight.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: HomeLight.blue.withValues(alpha: 0.10),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: HomeLight.blue,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TrText(
                            'مرحباً بك يا $safeName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomeLight.ink,
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const TrText(
                            'كمّل يومك خطوة بخطوة',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HomeLight.mutedStrong,
                              fontSize: 11.5,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ProgressRing(value: value, percent: percent),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.percent});

  final double value;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$percent% تقدمك اليوم',
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                color: HomeLight.blue,
                backgroundColor: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(
              width: 62,
              height: 62,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: HomeLight.ink,
                        fontSize: 19,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const TrText(
                      'تقدمك اليوم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HomeLight.mutedStrong,
                        fontSize: 8.5,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
