import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_preview_provider.dart';
import 'package:zaker_ai/features/home/widgets/home_bag_preview.dart';
import 'package:zaker_ai/features/home/widgets/library_shortcut.dart';

BagFolderPreview _folder(int index) => BagFolderPreview(
      id: 'f$index',
      name: 'مادة $index',
      colorValue: 0xFF2F5EA8,
      pocketCounts: const [1, 0, 0, 0],
    );

List<BagFolderPreview> _seven() => [for (var i = 1; i <= 7; i++) _folder(i)];

Widget _app({
  List<BagFolderPreview> folders = const [],
  List<String>? visited,
  double textScale = 1,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ProviderScope(
          overrides: [bagFolderPreviewProvider.overrideWithValue(folders)],
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                HomeBagPreview(),
                SizedBox(height: 12),
                LibraryShortcut(),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/bag',
        builder: (_, __) {
          visited?.add('/bag');
          return const SizedBox.shrink();
        },
      ),
      GoRoute(
        path: '/courses',
        builder: (_, __) {
          visited?.add('/courses');
          return const SizedBox.shrink();
        },
      ),
    ],
  );
  return MaterialApp.router(
    theme: ZakerTheme.light(),
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  testWidgets('previews at most six folders and offers the bag', (
    tester,
  ) async {
    await tester.pumpWidget(_app(folders: _seven()));
    expect(find.text('مادة 1'), findsOneWidget);
    expect(find.text('مادة 6'), findsOneWidget);
    expect(find.text('مادة 7'), findsNothing);
    expect(find.text('افتح الشنطة'), findsOneWidget);
    expect(find.text('شنطتي'), findsOneWidget);
  });

  testWidgets('the bag button opens the bag', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.tap(find.byKey(const Key('home-bag-open')));
    await tester.pumpAndSettle();
    expect(visited, ['/bag']);
  });

  testWidgets('the library shortcut opens the library', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.tap(find.byKey(const Key('home-library-shortcut')));
    await tester.pumpAndSettle();
    expect(visited, ['/courses']);
  });

  testWidgets('an empty bag shows a sentence, not an empty grid', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    expect(find.text('لسه مفيش مواد في الشنطة'), findsOneWidget);
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(folders: _seven(), textScale: 2));
    expect(tester.takeException(), isNull);
  });
}
