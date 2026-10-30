/// The floating, glassy bottom navigation used by the phone shell.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/theme.dart';
import 'tr_text.dart';

/// One tab shared by the bottom bar and the shell sidebar.
class ShellTab {
  const ShellTab({required this.icon, required this.label});

  final List<List<dynamic>> icon;
  final String label;
}

/// The five destinations, in the order the shell indexes them.
const List<ShellTab> shellTabs = [
  ShellTab(icon: HugeIcons.strokeRoundedHome01, label: 'الرئيسية'),
  ShellTab(icon: HugeIcons.strokeRoundedUser, label: 'شخصي'),
  ShellTab(icon: HugeIcons.strokeRoundedTaskDone01, label: 'الاختبار'),
  ShellTab(icon: HugeIcons.strokeRoundedBook02, label: 'القرآن'),
  ShellTab(icon: HugeIcons.strokeRoundedWallet01, label: 'الدفعات'),
];

/// A floating capsule of glass above the bottom edge.
class ShellBottomNav extends StatelessWidget {
  const ShellBottomNav({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < shellTabs.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: shellTabs[i].icon,
                        label: shellTabs[i].label,
                        selected: selected == i,
                        onTap: () => onSelect(i),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The capsule is always white glass, so the inactive colour cannot follow
    // a dark appearance's light "on surface" token.
    const inactive = ZakerColors.muted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [ZakerColors.blue, ZakerColors.blueDeep],
                    )
                  : null,
              borderRadius: BorderRadius.circular(24),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: ZakerColors.blue.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: icon,
                    size: 22,
                    color: selected ? Colors.white : inactive,
                  ),
                  const SizedBox(height: 3),
                  TrText(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: ZakerTheme.fontBody,
                      fontSize: 9.5,
                      height: 1.15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : inactive,
                    ),
                  ),
                  if (selected)
                    Container(
                      key: const Key('nav-selected-dot'),
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
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
