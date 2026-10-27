import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;
import 'package:zaker_ai/core/shad_theme.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/widgets/stats_strip.dart';
import 'package:zaker_ai/features/home/widgets/welcome_search.dart';

Widget _searchApp(List<String> visited) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(body: WelcomeSearch(name: 'طالب')),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, state) {
          visited.add(state.uri.toString());
          return const SizedBox.shrink();
        },
      ),
    ],
  );
  return MaterialApp.router(
    theme: ZakerTheme.light(),
    routerConfig: router,
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      // shadcn_ui reads its own theme; without this the ShadInput throws.
      child: ShadTheme(
        data: ZakerShadTheme.light(),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  test('the greeting flips at noon', () {
    expect(greetingFor(0), 'صباح الخير');
    expect(greetingFor(11), 'صباح الخير');
    expect(greetingFor(12), 'مساء الخير');
    expect(greetingFor(23), 'مساء الخير');
  });

  testWidgets('shows the greeting, the gold subline and the AI hint', (
    tester,
  ) async {
    await tester.pumpWidget(_searchApp([]));
    expect(find.textContaining('، طالب'), findsOneWidget);
    expect(find.text('عايز تعمل إيه النهاردة؟'), findsOneWidget);
    expect(find.text('اسأل معلم AI عن أي حاجة…'), findsOneWidget);
  });

  testWidgets('submitting a question opens chat with it', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(_searchApp(visited));
    await tester.enterText(find.byType(EditableText), 'حل مسألة');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(visited.single, startsWith('/chat?q='));
    expect(Uri.parse(visited.single).queryParameters['q'], 'حل مسألة');
  });

  testWidgets('submitting only spaces does not navigate', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(_searchApp(visited));
    await tester.enterText(find.byType(EditableText), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(visited, isEmpty);
  });

  testWidgets('the three stat chips reflow instead of overflowing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ZakerTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: HomeStatsStrip(
              streakDays: 3,
              minutesToday: 42,
              pendingCount: 5,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('يوم متواصل'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
