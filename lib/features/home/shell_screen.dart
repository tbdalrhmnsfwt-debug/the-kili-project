/// The bottom-navigation shell shared by all tab screens.
library;

import 'package:flutter/material.dart';

import '../courses/course_list_screen.dart';
import '../exam/exam_home_screen.dart';
import '../quran/quran_home_screen.dart';
import 'home_screen.dart';

/// The shell hosting the four bottom-nav tabs.
///
/// The original app uses `google_nav_bar` (present in the dependency
/// manifest) for this bar; the Material 3 [NavigationBar] is used here
/// because it needs no extra plugin at build time.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.initialIndex = 0, this.child});

  /// The index of the tab that is shown when the shell first appears.
  final int initialIndex;

  /// Overrides the widget rendered for [initialIndex].
  ///
  /// The router passes the tab body explicitly so a deep link into a tab
  /// renders the same screen the tab would show.
  final Widget? child;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int _index = widget.initialIndex.clamp(0, 3);

  static const _tabs = <({IconData icon, IconData active, String label})>[
    (
      icon: Icons.grid_view_rounded,
      active: Icons.grid_view_rounded,
      label: 'الرئيسية',
    ),
    (
      icon: Icons.library_books_outlined,
      active: Icons.library_books_rounded,
      label: 'المواد',
    ),
    (
      icon: Icons.school_outlined,
      active: Icons.school_rounded,
      label: 'الاختبار',
    ),
    (
      icon: Icons.menu_book_outlined,
      active: Icons.menu_book_rounded,
      label: 'القرآن',
    ),
  ];

  Widget _bodyFor(int i) {
    if (i == widget.initialIndex && widget.child != null) return widget.child!;
    return switch (i) {
      0 => const HomeScreen(),
      1 => const CourseListScreen(),
      2 => const ExamHomeScreen(),
      _ => const QuranHomeScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _tabs.length; i++) _bodyFor(i)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.active, color: scheme.primary),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
