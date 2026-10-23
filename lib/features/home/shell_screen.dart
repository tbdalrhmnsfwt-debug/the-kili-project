/// The navigation shell shared by all tab screens.
///
/// Wide screens get a permanent sidebar. Phones get the mockup's floating
/// rounded bottom bar plus an off-canvas drawer opened from the hamburger in
/// the hero banner or in each tab's app bar. Both navigation surfaces drive
/// the same four tabs, and every existing route stays untouched.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/tr_text.dart';
import '../courses/course_list_screen.dart';
import '../exam/exam_home_screen.dart';
import '../quran/quran_home_screen.dart';
import 'home_screen.dart';

/// One bottom-nav / sidebar destination.
class _Tab {
  const _Tab({required this.icon, required this.label});

  final List<List<dynamic>> icon;
  final String label;
}

const List<_Tab> _tabs = [
  _Tab(icon: HugeIcons.strokeRoundedHome01, label: 'الرئيسية'),
  _Tab(icon: HugeIcons.strokeRoundedBookOpen01, label: 'مكتبتي'),
  _Tab(icon: HugeIcons.strokeRoundedTaskDone01, label: 'الاختبار'),
  _Tab(icon: HugeIcons.strokeRoundedBook02, label: 'القرآن'),
];

/// Makes the shell's drawer reachable from any tab screen.
///
/// A tab screen calls [shellMenuLeading] to get an app-bar button, or
/// [shellDrawerOpener] to attach the same action to a custom control such as
/// the home hero's menu button. Outside the shell (pushed routes) both return
/// `null`, so the normal back button is left in place.
class ShellMenuScope extends InheritedWidget {
  const ShellMenuScope({
    super.key,
    required this.openDrawer,
    required this.enabled,
    required super.child,
  });

  final VoidCallback openDrawer;
  final bool enabled;

  static ShellMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellMenuScope>();

  @override
  bool updateShouldNotify(ShellMenuScope oldWidget) =>
      enabled != oldWidget.enabled || openDrawer != oldWidget.openDrawer;
}

/// The app-bar leading button for a tab screen, or `null` when the shell is
/// wide (sidebar visible) or absent (pushed route, which keeps its back
/// button).
Widget? shellMenuLeading(BuildContext context) {
  final scope = ShellMenuScope.maybeOf(context);
  if (scope == null || !scope.enabled) return null;
  return IconButton(
    tooltip: 'القائمة',
    onPressed: scope.openDrawer,
    icon: const HugeIcon(icon: HugeIcons.strokeRoundedMenu01, size: 24),
  );
}

/// The drawer opener for a custom button, or `null` on wide screens.
VoidCallback? shellDrawerOpener(BuildContext context) {
  final scope = ShellMenuScope.maybeOf(context);
  if (scope == null || !scope.enabled) return null;
  return scope.openDrawer;
}

/// The shell hosting the four tabs.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, this.initialIndex = 0, this.child});

  /// The index of the tab that is shown when the shell first appears.
  final int initialIndex;

  /// Overrides the widget rendered for [initialIndex].
  ///
  /// The router passes the tab body explicitly so a deep link into a tab
  /// renders the same screen the tab would show.
  final Widget? child;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _index = widget.initialIndex.clamp(0, 3);

  Widget _bodyFor(int i) {
    if (i == widget.initialIndex && widget.child != null) return widget.child!;
    return switch (i) {
      0 => const HomeScreen(),
      1 => const CourseListScreen(),
      2 => const ExamHomeScreen(),
      _ => const QuranHomeScreen(),
    };
  }

  void _select(int index) => setState(() => _index = index);

  void _selectFromDrawer(int index) {
    _select(index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = IndexedStack(
      index: _index,
      children: [for (var i = 0; i < _tabs.length; i++) _bodyFor(i)],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The mockup switches from the bottom bar to the sidebar at `md`
        // width; 900 leaves the content enough room beside a 272px panel.
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _Sidebar(selected: _index, onSelect: _select),
                  VerticalDivider(
                    width: 1,
                    color: theme.dividerTheme.color,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            width: (constraints.maxWidth * 0.86).clamp(280.0, 340.0),
            backgroundColor: theme.cardTheme.color,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(26)),
            ),
            child: SafeArea(
              child: _Sidebar(
                selected: _index,
                onSelect: _selectFromDrawer,
                drawer: true,
              ),
            ),
          ),
          body: ShellMenuScope(
            openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            enabled: true,
            child: body,
          ),
          bottomNavigationBar: _FloatingNav(
            selected: _index,
            onSelect: _select,
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------- sidebar

/// The sidebar: brand, tabs, quick links, and the profile card.
///
/// The same widget backs the permanent panel on wide screens and the content
/// of the mobile drawer, so both surfaces can never drift apart.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    this.drawer = false,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final bool drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider);
    final name = (user?.displayName ?? 'ضيف').trim();
    final initial = name.isEmpty ? 'ض' : name.characters.first;

    return Container(
      width: drawer ? double.infinity : 272,
      color: theme.cardTheme.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [ZakerColors.primary, ZakerColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: ZakerColors.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedBookOpen02,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrText(
                        'ذاكرلي',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TrText(
                        'رفيق الطالب',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (drawer)
                  IconButton(
                    tooltip: 'قفل القائمة',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!drawer) const _SidebarLabel('القائمة'),
                  for (var i = 0; i < _tabs.length; i++)
                    _SidebarItem(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: selected == i,
                      onTap: () => onSelect(i),
                    ),
                  const SizedBox(height: 16),
                  const _SidebarLabel('أدوات سريعة'),
                  _SidebarItem(
                    icon: HugeIcons.strokeRoundedWallet01,
                    label: 'محفظتي',
                    selected: false,
                    onTap: () => context.push(ZakerRoutes.wallet),
                  ),
                  _SidebarItem(
                    icon: HugeIcons.strokeRoundedAward01,
                    label: 'إنجازاتي',
                    selected: false,
                    onTap: () => context.push(ZakerRoutes.achievements),
                  ),
                  _SidebarItem(
                    icon: HugeIcons.strokeRoundedSettings01,
                    label: 'الإعدادات',
                    selected: false,
                    onTap: () => context.push(ZakerRoutes.settings),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.dividerTheme.color),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push(ZakerRoutes.account),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 21,
                        backgroundColor: theme.colorScheme.primary,
                        child: TrText(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TrText(
                              name.isEmpty ? 'ضيف' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TrText(
                              'طالب مجتهد',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 6),
      child: TrText(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [ZakerColors.primary, ZakerColors.primaryLight],
                    )
                  : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: ZakerColors.primary.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: icon,
                  size: 22,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TrText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
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
    );
  }
}

// ---------------------------------------------------------------- bottom bar

/// The mockup's floating rounded bottom bar for phones.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: selected == i,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
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
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [ZakerColors.primary, ZakerColors.primaryLight],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: ZakerColors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: icon,
                size: 22,
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              TrText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ZakerTheme.fontBody,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
