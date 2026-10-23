/// The navigation shell shared by all tab screens.
///
/// Wide screens get the mockup's right-hand sidebar; phones get its floating
/// rounded bottom bar. Both drive the same four tabs.
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

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [for (var i = 0; i < _tabs.length; i++) _bodyFor(i)],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The mockup switches from the bottom bar to the sidebar at `md`
        // width; 900 leaves the content enough room beside a 260px panel.
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _Sidebar(selected: _index, onSelect: _select),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).dividerTheme.color,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: body,
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

/// The wide-screen sidebar: brand, tabs, settings, and the profile card.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authUserProvider);
    final name = (user?.displayName ?? 'ضيف').trim();
    final initial = name.isEmpty ? 'ض' : name.characters.first;

    return Container(
      width: 260,
      color: theme.cardTheme.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
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
                TrText(
                  'ذاكرلي',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // Scroll the destinations so the panel also fits short/landscape
          // windows; the profile card stays pinned to the bottom.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _SidebarItem(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: selected == i,
                      onTap: () => onSelect(i),
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
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(ZakerRoutes.account),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
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
                              fontWeight: FontWeight.w700,
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
                  ],
                ),
              ),
            ),
          ),
        ],
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
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                HugeIcon(icon: icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: TrText(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
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
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: icon, size: 22, color: color),
              const SizedBox(height: 4),
              TrText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: ZakerTheme.fontBody,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
