# رفيق الطالب — Home and Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the tall teal home with the compact navy/gold home of the spec — fixed top bar, welcome/search strip, stats chips, one-row prayer pill, «شنطتي» preview, retuned cards, and a library shortcut — while tab 2 becomes «شنطتي» and every existing route stays reachable.

**Architecture:** The home's private sections move to public widgets under `lib/features/home/widgets/` so widget tests can pump them without the whole screen; `HomeScreen` becomes a thin assembly (`Column(HomeTopBar, Expanded(RefreshIndicator(ListView)))`) in the spec's order. The bag preview reads a new `bagFolderPreviewProvider` that returns `const []` in this phase; Phase 3 swaps its body for the real `MyBagController` without touching any widget. `MyBagScreen` is a minimal real screen now (header, folder strip, library button) so tab 2 is not a dead end, and `/courses` becomes a pushed top-level route instead of a second shell.

**Tech Stack:** Flutter 3.x / Dart 3.13, Material 3, Riverpod 2.5.1, go_router, hugeicons 1.2.0, `flutter_test` in CI, local ARM64 Dart for `dart analyze` only.

**Spec:** `docs/superpowers/specs/2026-10-27-rafiq-al-talib-rebrand-design.md` (§Shell and navigation 310–331, §Home 332–382, §My Bag screens 446–458 for the preview, §Testing 924–970, §Phased delivery phase 2)

**Plan 2 of 7.** Phase 1 (brand foundation) shipped at `2e0103f` with CI run `40533074184` green (608 tests). Phase 3 (My Bag) replaces this plan's `bagFolderPreviewProvider` body and `MyBagScreen` stub with the real controller and screens.

## Global Constraints

- No new pub dependency, no network call, no analytics.
- Arabic source string is the translation key: widgets use `TrText`; plain interpolation (greeting, counter) stays inside the string. No ARB/gen-l10n and no new `en_extra.json` rows are required this phase.
- All colours come from `ZakerColors` / the active `ZakerPalette` / `ZakerFeatureAccents`; no literal hex in new code. Teal is still banned by `test/theme_brand_test.dart`.
- Cards use `ZakerRadius.card` (16 dp) and `ZakerShadows.card`; inner surfaces stay `ZakerRadius.md` (14).
- Gold `#D4AF37` is never small text on white; `goldDeep` is the label token there, and `cardAccentOf(accent, theme)` is how an accent becomes readable text on a card.
- Every user-visible text gets `maxLines` + `TextOverflow.ellipsis` (or wraps by design, e.g. chips); horizontal groups use `Expanded` / `Wrap` / a scroller — never an unconstrained fixed-width `Row`.
- The home body is a `ListView`; the all-tools grid keeps a computed column count.
- Any widget test that pumps the AI search field wraps it in `ShadTheme(data: ZakerShadTheme.forStyle(style))` the way `main.dart:133` does — `ShadTheme.of` throws without an ancestor.
- Top bar height is exactly `(MediaQuery.sizeOf(context).height * 0.06).clamp(48.0, 56.0)` plus the top safe-area inset.
- `flutter test` and `flutter analyze` run in CI; this device's ARM64 Dart (`work/dartsdk/dart-sdk/bin/dart`) only runs `dart analyze` and `dart format`. No test result may be claimed that CI did not produce.
- Each task ends with `dart format` on the touched files, `dart analyze lib test` clean, a commit, a push to `main`, and the CI run for that sha read and recorded.

## Review Focus

1. **320 dp at 2.0× text.** A phone user with large text on the narrowest common width gets the top bar, stats, pill, action cards and banners stacked without a yellow-black overflow stripe. Task 7's `home_compact_test` walks 320/360/411/800 dp × 1.0/1.5/2.0 and every appearance; Task 7 stacks the action cards when text is large.
2. **No saved location, onboarding not yet seen.** A first-run user sees a prayer pill that still opens `/islam`, and the location onboarding sheet still appears exactly once. Task 4 pins the pill's no-location body; Task 7 runs the home with an onboarded store.
3. **Tab 2 replaced but the library must stay one tap away.** Anyone who used to open the library from the nav bar now lands on «شنطتي»; the bag header button and `/courses` must still work, and a `/bag` deep link must show the bag tab with a working back. Task 1 pins all three.
4. **Search with nothing to search.** Submitting an empty or whitespace-only field must not navigate to `/chat?q=`. Task 3 pins it, along with the real question reaching `/chat?q=`.
5. **A bag bigger than the preview.** More than six folders must still preview exactly six, and zero folders must show a sentence plus «افتح الشنطة», not an empty grid. Task 5 pins both.

---

### Task 1: «شنطتي» tab, `/bag` route, and the bag preview seam

**Files:**
- Create: `lib/features/bag/bag_preview_provider.dart`
- Create: `lib/features/bag/widgets/bag_folder_strip.dart`
- Create: `lib/features/bag/my_bag_screen.dart`
- Modify: `lib/features/home/shell_screen.dart:34-40` (the `_tabs` list), `:108-118` (`_bodyFor`), `:20-24` (imports)
- Modify: `lib/core/router.dart:111-113` (`ZakerRoutes`), `:352-361` (the `/` and `/courses` routes)
- Modify: `test/shell_nav_test.dart:31-43`
- Test: `test/my_bag_screen_test.dart` (create)

**Interfaces:**
- Produces: `class BagFolderPreview` — `const BagFolderPreview({required String id, required String name, required int colorValue, required List<int> pocketCounts})`, where `pocketCounts` is always four ints in the order PDFs, recordings, boards, links.
- Produces: `final Provider<List<BagFolderPreview>> bagFolderPreviewProvider` (`Provider.autoDispose`, body `const []` this phase).
- Produces: `class BagFolderStrip extends StatelessWidget` — `const BagFolderStrip({super.key, required List<BagFolderPreview> folders, int? maxFolders})`; card key `Key('bag-folder-${folder.id}')`, dot keys `Key('bag-dot-${folder.id}-$i')` for `i` 0–3.
- Produces: `class MyBagScreen extends ConsumerWidget` — `const MyBagScreen({super.key})`; key `my-bag-screen`, library button key `my-bag-library-button`.
- Produces: `ZakerRoutes.bag == '/bag'`.
- Task 5 consumes `BagFolderPreview`, `bagFolderPreviewProvider`, `BagFolderStrip`.

- [ ] **Step 1: Write the failing test**

```dart
// test/my_bag_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/router.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_preview_provider.dart';
import 'package:zaker_ai/features/bag/my_bag_screen.dart';

BagFolderPreview _folder(String name, {int pdfs = 0}) => BagFolderPreview(
  id: name,
  name: name,
  colorValue: 0xFF2F5EA8,
  pocketCounts: [pdfs, 0, 0, 0],
);

Widget _app(List<BagFolderPreview> folders, {double textScale = 1}) => ProviderScope(
  overrides: [
    localStoreProvider.overrideWithValue(LocalStore.memory()),
    bagFolderPreviewProvider.overrideWithValue(folders),
  ],
  child: MaterialApp(
    theme: ZakerTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: const MyBagScreen(),
  ),
);

void main() {
  test('/bag is the deep link for the second tab', () {
    expect(ZakerRoutes.bag, '/bag');
  });

  testWidgets('the bag screen names itself and keeps the library one tap away', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));
    // The AppBar title and the red hero both read «شنطتي».
    expect(find.text('شنطتي'), findsWidgets);
    expect(find.text('المكتبة الدراسية'), findsOneWidget);
    expect(
      find.byKey(const Key('my-bag-library-button')),
      findsOneWidget,
    );
  });

  testWidgets('shows one chip with four pocket dots per folder', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([_folder('الرياضيات', pdfs: 2), _folder('العلوم')]),
    );
    expect(find.text('الرياضيات'), findsOneWidget);
    expect(find.text('العلوم'), findsOneWidget);
    expect(find.byKey(const Key('bag-dot-الرياضيات-3')), findsOneWidget);
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app([_folder('الرياضيات'), _folder('العلوم')], textScale: 2));
    expect(tester.takeException(), isNull);
  });
}
```

Update the existing bottom-bar test in `test/shell_nav_test.dart`:

```dart
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('شنطتي'), findsOneWidget);
    expect(find.text('المكتبة الدراسية'), findsNothing);
    expect(find.text('الاختبار'), findsOneWidget);
    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الدفعات'), findsOneWidget);
    expect(find.byKey(const Key('nav-selected-dot')), findsOneWidget);

    final theme = Theme.of(tester.element(find.text('الاختبار')));
    final label = tester.widget<Text>(find.text('شنطتي'));
    expect(label.style?.color, theme.colorScheme.onPrimary);
```

- [ ] **Step 2: Run the test and watch it fail**

Run in CI: `flutter test test/my_bag_screen_test.dart test/shell_nav_test.dart`
Expected: FAIL — `bag_preview_provider.dart` and `my_bag_screen.dart` do not exist; `ZakerRoutes.bag` is undefined; the bottom bar still reads «المكتبة الدراسية».

- [ ] **Step 3: Create the preview model and provider**

`lib/features/bag/bag_preview_provider.dart` — no Flutter import, so Phase 3 can move it into a pure-Dart model:

```dart
/// What the home needs to know about one «شنطتي» folder.
///
/// Deliberately smaller than Phase 3's `MyBagFolder`: the home draws a name, a
/// colour and four counts, and nothing else. Phase 3 replaces the provider's
/// body with a watch on the bag controller; no widget changes with it.
class BagFolderPreview {
  const BagFolderPreview({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.pocketCounts,
  }) : assert(pocketCounts.length == 4, 'PDFs, voice, boards, links');

  final String id;
  final String name;
  final int colorValue;
  final List<int> pocketCounts;
}

/// Folder previews for the home and the bag screen; empty until Phase 3.
final bagFolderPreviewProvider = Provider.autoDispose<List<BagFolderPreview>>(
  (ref) => const [],
);
```

`PocketCounts` order is fixed by the assert: PDFs, recordings, boards, links.

- [ ] **Step 4: Create `BagFolderStrip`**

`lib/features/bag/widgets/bag_folder_strip.dart`: a `Wrap` (`spacing: ZakerSpacing.sm`, `runSpacing: ZakerSpacing.sm`) of chips, truncated to `maxFolders` when given. Each chip is a `Container` keyed `bag-folder-${folder.id}` with `ZakerRadius.md`, `ZakerShadows.card`, `ZakerColors.border` hairline, a 4 dp coloured bar in `Color(folder.colorValue)`, the name as `TrText(maxLines: 1, overflow: ellipsis)` inside a `ConstrainedBox(maxWidth: 150)`, and a `Row` of four 5 dp dots keyed `bag-dot-${folder.id}-$i`, filled with the accent when `pocketCounts[i] > 0` and `theme.colorScheme.outlineVariant` when zero. When `folders.isEmpty`, render `TrText('لسه مفيش مواد في الشنطة')` in `theme.colorScheme.onSurfaceVariant`.

- [ ] **Step 5: Create `MyBagScreen`**

`lib/features/bag/my_bag_screen.dart`: a `ConsumerWidget` returning a `Scaffold(key: Key('my-bag-screen'))` with `AppBar(leading: shellMenuLeading(context), title: const TrText('شنطتي'))`. Body is a `ListView(padding: EdgeInsets.all(ZakerSpacing.lg))` holding: a red hero (`ZakerColors.backpack` to `Color.lerp(ZakerColors.backpack, Colors.black, 0.25)!`, white `HugeIcons.strokeRoundedBackpack01`, «شنطتي», «كل موادك في شنطة واحدة»), `const SizedBox(height: ZakerSpacing.lg)`, `BagFolderStrip(folders: ref.watch(bagFolderPreviewProvider))`, and an outlined `FilledButton.tonal` keyed `my-bag-library-button` labelled «المكتبة الدراسية» that calls `context.push(ZakerRoutes.courses)`. Add a one-line comment that Phase 3 replaces the body with the folder grid, grade filter and pocket totals.

- [ ] **Step 6: Wire the tab and the routes**

In `shell_screen.dart`: `_Tab(icon: HugeIcons.strokeRoundedBackpack01, label: 'شنطتي')` as `_tabs[1]`, import `../bag/my_bag_screen.dart`, and `1 => const MyBagScreen(),` in `_bodyFor`.

In `router.dart`: add `static const String bag = '/bag';` after `courses`; add

```dart
    GoRoute(
      path: ZakerRoutes.bag,
      builder: (context, state) =>
          const ShellScreen(initialIndex: 1, child: MyBagScreen()),
    ),
```

directly after the `/` route, and change the `/courses` builder to `(context, state) => const StudyLibraryScreen()` (no `ShellScreen`). Add the `../features/bag/my_bag_screen.dart` import; keep the rest.

- [ ] **Step 7: Format, analyze, commit, push**

```bash
work/dartsdk/dart-sdk/bin/dart format lib/features/bag lib/features/home/shell_screen.dart lib/core/router.dart test/my_bag_screen_test.dart test/shell_nav_test.dart
work/dartsdk/dart-sdk/bin/dart analyze lib test
git add lib/features/bag lib/features/home/shell_screen.dart lib/core/router.dart test/my_bag_screen_test.dart test/shell_nav_test.dart
git commit -m "feat(bag): make شنطتي the second tab and open the library as a pushed route"
git push origin main
```

- [ ] **Step 8: Read the CI result**

Run: `gh run list --branch main --limit 1 --json databaseId,headSha,conclusion` after the run finishes.
Expected: `conclusion: success` for this task's sha. If the only failure is the new tests (the RED step) that is the expected failure; the task is complete only after a green run on the final commit.

---

### Task 2: Compact top bar

**Files:**
- Create: `lib/features/home/widgets/home_top_bar.dart`
- Test: `test/home_top_bar_test.dart` (create)

**Interfaces:**
- Produces: `double homeTopBarHeightFor(double screenHeight)` — `(screenHeight * 0.06).clamp(48.0, 56.0)`.
- Produces: `class HomeTopBar extends StatelessWidget` — `const HomeTopBar({super.key, required bool showBadge, VoidCallback? onMenu, required VoidCallback onNotifications, required VoidCallback onSettings})`.
- Keys: `home-top-bar` (root, fixed height + safe inset), `home-top-bar-menu`, `home-top-bar-bell`, `home-top-bar-badge`, `home-top-bar-settings`.
- Task 7 consumes both.

- [ ] **Step 1: Write the failing test**

```dart
// test/home_top_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/widgets/home_top_bar.dart';

Widget _host(
  Widget bar, {
  Size size = const Size(400, 800),
  double topPadding = 24,
  double textScale = 1,
}) => MaterialApp(
  theme: ZakerTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(
      size: size,
      padding: EdgeInsets.only(top: topPadding),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(body: bar),
  ),
);

void main() {
  test('height follows the 6% formula inside a 48–56 dp clamp', () {
    expect(homeTopBarHeightFor(600), 48);
    expect(homeTopBarHeightFor(700), 48);
    expect(homeTopBarHeightFor(800), 48);
    expect(homeTopBarHeightFor(900), closeTo(54, 1e-9));
    expect(homeTopBarHeightFor(1200), 56);
  });

  testWidgets('the bar is the formula height plus the top safe inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeTopBar(
          showBadge: true,
          onMenu: () {},
          onNotifications: () {},
          onSettings: () {},
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('home-top-bar'))).height,
      closeTo(48 + 24, 1e-9),
    );
    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-menu')), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-bell')), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-badge')), findsOneWidget);
    expect(find.byKey(const Key('home-top-bar-settings')), findsOneWidget);
  });

  testWidgets('the badge and the menu disappear when they do not apply', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeTopBar(
          showBadge: false,
          onNotifications: () {},
          onSettings: () {},
        ),
      ),
    );
    expect(find.byKey(const Key('home-top-bar-badge')), findsNothing);
    expect(find.byKey(const Key('home-top-bar-menu')), findsNothing);
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeTopBar(
          showBadge: true,
          onMenu: () {},
          onNotifications: () {},
          onSettings: () {},
        ),
        size: const Size(320, 800),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/home_top_bar_test.dart`
Expected: FAIL — `home_top_bar.dart` does not exist.

- [ ] **Step 3: Implement the bar**

`home_top_bar.dart`:

```dart
double homeTopBarHeightFor(double screenHeight) =>
    (screenHeight * 0.06).clamp(48.0, 56.0);
```

`HomeTopBar.build` returns a `SizedBox(key: Key('home-top-bar'), height: MediaQuery.paddingOf(context).top + homeTopBarHeightFor(MediaQuery.sizeOf(context).height))` whose child pads `EdgeInsetsDirectional.symmetric(horizontal: ZakerSpacing.sm)` and draws:

- `onMenu == null ? const SizedBox(width: 48)` : `IconButton(key: Key('home-top-bar-menu'), tooltip: 'القائمة', icon: HugeIcon(strokeRoundedMenu01, size: 22), onPressed: onMenu)`.
- `Expanded(child: TrText(RafiqBrand.appName, maxLines: 1, overflow: ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)))`.
- Bell: `IconButton(key: Key('home-top-bar-bell'), tooltip: 'التنبيهات', onPressed: onNotifications, icon: Stack(clipBehavior: Clip.none, children: [HugeIcon(strokeRoundedNotification01, size: 22), if (showBadge) PositionedDirectional(top: -1, end: -1, child: Container(key: Key('home-top-bar-badge'), width: 8, height: 8, decoration: BoxDecoration(color: ZakerColors.gold, shape: BoxShape.circle)))]))`.
- `IconButton(key: Key('home-top-bar-settings'), tooltip: 'الإعدادات', icon: HugeIcon(strokeRoundedSettings01, size: 22), onPressed: onSettings)`.

No greeting, no appearance button: appearance stays reachable through Settings (`settings_screen.dart:71`).

- [ ] **Step 4: Run it and watch it pass**

Run in CI: `flutter test test/home_top_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit, push**

```bash
work/dartsdk/dart-sdk/bin/dart format lib/features/home/widgets/home_top_bar.dart test/home_top_bar_test.dart
work/dartsdk/dart-sdk/bin/dart analyze lib test
git add lib/features/home/widgets/home_top_bar.dart test/home_top_bar_test.dart
git commit -m "feat(home): add the compact brand top bar"
git push origin main
```

- [ ] **Step 6: Read the CI result**

Expected: `conclusion: success` for this task's sha.

---

### Task 3: Welcome strip, AI search, and the stats chips

**Files:**
- Create: `lib/features/home/widgets/welcome_search.dart`
- Create: `lib/features/home/widgets/stats_strip.dart`
- Test: `test/home_welcome_test.dart` (create)

**Interfaces:**
- Produces: `String greetingFor(int hour)` — `'صباح الخير'` when `hour < 12`, otherwise `'مساء الخير'`.
- Produces: `class WelcomeSearch extends StatefulWidget` — `const WelcomeSearch({super.key, required String name})`; root key `home-welcome-search`; the text field's `EditableText` is the only one in its subtree.
- Produces: `class HomeStatsStrip extends StatelessWidget` — `const HomeStatsStrip({super.key, required int streakDays, required int minutesToday, required int pendingCount})`; root key `home-stats`.
- Pinned literals: hint `'اسأل معلم AI عن أي حاجة…'` (the existing shipped key, U+2026), subline `'عايز تعمل إيه النهاردة؟'`, labels `'يوم متواصل'`, `'دقيقة النهاردة'`, `'مهمة مستنية'`, greeting rendered as `'${greetingFor(hour)}، $name'`.
- Task 7 consumes both.

- [ ] **Step 1: Write the failing test**

```dart
// test/home_welcome_test.dart
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
```

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/home_welcome_test.dart`
Expected: FAIL — both widget files are missing.

- [ ] **Step 3: Implement `WelcomeSearch`**

`welcome_search.dart`: a `StatefulWidget` owning one `TextEditingController` (disposed) and no timer. Build a `Container(key: Key('home-welcome-search'), padding: EdgeInsets.fromLTRB(18, 16, 18, 16), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: ZakerColors.navyGradient, stops: const [0, 0.58, 1]), borderRadius: BorderRadius.circular(ZakerRadius.lg)))` holding a `Column(crossAxisAlignment: start)`:

1. `TrText('${greetingFor(DateTime.now().hour)}، $name', maxLines: 1, overflow: ellipsis, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.3))`.
2. `TrText('عايز تعمل إيه النهاردة؟', maxLines: 1, overflow: ellipsis, style: TextStyle(color: ZakerColors.goldLight, fontSize: 13, fontWeight: FontWeight.w700))`.
3. The existing pill from `home_screen.dart:1002-1059` moved verbatim (icon, `ShadInput` with the hint, arrow circle), except `_submit` stays exactly as it is today: trim, return on empty, clear, unfocus, `context.push('${ZakerRoutes.chat}?q=${Uri.encodeQueryComponent(query)}')`.

- [ ] **Step 4: Implement `HomeStatsStrip`**

`stats_strip.dart`: `Wrap(key: Key('home-stats'), spacing: ZakerSpacing.sm, runSpacing: ZakerSpacing.sm)` of three chips. Each chip is a `Container` with `ZakerRadius.pill`, `cardSurfaceOf(theme)`, a `ZakerColors.border` hairline, `EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6)`, and a `Row(mainAxisSize: min)` of the value (`fontWeight: w800`, `fontFeatures: [FontFeature.tabularFigures()]`) and the label (`color: theme.colorScheme.onSurfaceVariant`, `fontSize: 12`). Values: `'$streakDays'` / `'يوم متواصل'`, `'$minutesToday'` / `'دقيقة النهاردة'`, `'$pendingCount'` / `'مهمة مستنية'`.

- [ ] **Step 5: Run it and watch it pass**

Run in CI: `flutter test test/home_welcome_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit, push**

```bash
work/dartsdk/dart-sdk/bin/dart format lib/features/home/widgets/welcome_search.dart lib/features/home/widgets/stats_strip.dart test/home_welcome_test.dart
work/dartsdk/dart-sdk/bin/dart analyze lib test
git add lib/features/home/widgets/welcome_search.dart lib/features/home/widgets/stats_strip.dart test/home_welcome_test.dart
git commit -m "feat(home): add the welcome strip, AI search and stat chips"
git push origin main
```

- [ ] **Step 7: Read the CI result**

Expected: `conclusion: success` for this task's sha.

---

### Task 4: One-row prayer pill

**Files:**
- Create: `lib/features/home/widgets/prayer_pill.dart`
- Modify: `lib/core/theme.dart` — add `featureAccentsOf`
- Test: `test/prayer_pill_test.dart` (create)

**Interfaces:**
- Produces: `ZakerFeatureAccents featureAccentsOf(ThemeData theme)` in `lib/core/theme.dart` — `theme.extension<ZakerFeatureAccents>() ?? _fallbackAccents`, where `_fallbackAccents` is a private top-level `final` built once from `ZakerTheme.light()`. Task 6 consumes it for the home cards.
- Produces: `class PrayerPill extends ConsumerStatefulWidget` — `const PrayerPill({super.key})`. Reads `prayerLocationProvider`, `prayerDayProvider`, `prayerHijriProvider`; keeps today's first-frame behaviour: `maybeShowPrayerOnboarding` when `!prayerSettingsProvider.onboarded`, otherwise `refreshLocationIfMoved`, plus the `WidgetsBindingObserver` resume refresh (`home_screen.dart:200-227` moves here).
- Produces: `class PrayerPillView extends StatelessWidget` — `const PrayerPillView({super.key, required PrayerDay? day, required PrayerLocation? location, required HijriDate hijri, required VoidCallback onTap})`; root key `home-prayer-pill`, chevron key `home-prayer-chevron`.
- Pinned copy: no `day` → `'حدد موقعك لمعرفة مواقيت الصلاة'`; with `day` → `day.next.name.invocation`, `formatClockTime(day.next.time)`, `formatCountdown(day.remaining)`, `day.location.displayName`, `hijri.formatted`, a `'غدًا'` badge when `day.next.tomorrow`, and the label `'بعد'` before the countdown.
- Task 7 consumes `PrayerPill`.

- [ ] **Step 1: Write the failing test**

```dart
// test/prayer_pill_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/hijri_date.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/widgets/prayer_pill.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';

final PrayerLocation _cairo = PrayerLocation(
  latitude: 30.0444,
  longitude: 31.2357,
  city: 'القاهرة',
);
final HijriDate _hijri = HijriDate.fromGregorian(DateTime(2026, 10, 27));

PrayerDay _day() {
  DateTime at(int hour, int minute) => DateTime(2026, 10, 27, hour, minute);
  return PrayerDay(
    date: DateTime(2026, 10, 27),
    now: at(4, 0),
    prayers: [
      PrayerMoment(name: PrayerName.fajr, time: at(5, 4)),
      PrayerMoment(name: PrayerName.dhuhr, time: at(11, 50)),
      PrayerMoment(name: PrayerName.asr, time: at(15, 10)),
      PrayerMoment(name: PrayerName.maghrib, time: at(17, 25)),
      PrayerMoment(name: PrayerName.isha, time: at(18, 55)),
    ],
    next: PrayerMoment(name: PrayerName.fajr, time: at(5, 4)),
    previousTime: DateTime(2026, 10, 26, 18, 55),
    location: _cairo,
  );
}

Widget _host(Widget pill) => MaterialApp(
  theme: ZakerTheme.light(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 360, child: pill),
    ),
  ),
);

void main() {
  test('a bare theme still yields feature accents', () {
    final fallback = featureAccentsOf(ThemeData.light());
    final light = ZakerTheme.light().extension<ZakerFeatureAccents>()!;
    expect(fallback.prayer, light.prayer);
  });

  testWidgets('shows the next prayer, its time, the countdown and the day', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PrayerPillView(
          day: _day(),
          location: _cairo,
          hijri: _hijri,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('صلاة الفجر'), findsOneWidget);
    expect(find.text('5:04 ص'), findsOneWidget);
    expect(find.text('01:04:00'), findsOneWidget);
    expect(find.text('القاهرة'), findsOneWidget);
    expect(find.text(_hijri.formatted), findsOneWidget);
    expect(find.byKey(const Key('home-prayer-chevron')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-prayer-pill')));
    expect(taps, 1);
  });

  testWidgets('without a location it asks for one and still opens /islam', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PrayerPillView(
          day: null,
          location: null,
          hijri: _hijri,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('حدد موقعك لمعرفة مواقيت الصلاة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-prayer-pill')));
    expect(taps, 1);
  });

  testWidgets('no overflow at 320 dp and 2.0x text', (tester) async {
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
          child: Scaffold(
            body: PrayerPillView(
              day: _day(),
              location: _cairo,
              hijri: _hijri,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('home-prayer-pill'))).height,
      greaterThanOrEqualTo(64),
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/prayer_pill_test.dart`
Expected: FAIL — `prayer_pill.dart` does not exist.

- [ ] **Step 3: Add `featureAccentsOf`**

In `lib/core/theme.dart`, under `cardAccentOf`:

```dart
final ZakerFeatureAccents _fallbackAccents =
    ZakerTheme.light().extension<ZakerFeatureAccents>()!;

/// [theme]'s feature accents, or the light palette's when a bare [ThemeData]
/// (a test harness, a dialog outside the app theme) carries none.
ZakerFeatureAccents featureAccentsOf(ThemeData theme) =>
    theme.extension<ZakerFeatureAccents>() ?? _fallbackAccents;
```

- [ ] **Step 4: Implement `PrayerPillView`**

A `Material(color: Colors.transparent)` wrapping `InkWell(key: Key('home-prayer-pill'), borderRadius: BorderRadius.circular(ZakerRadius.cardValue), onTap: onTap, child: Ink(...))`, with `constraints: const BoxConstraints(minHeight: 64)`, `padding: EdgeInsetsDirectional.symmetric(horizontal: ZakerSpacing.md, vertical: ZakerSpacing.sm)`, `cardSurfaceOf(theme)`, the hairline border and `ZakerShadows.card`.

Row children: a 36×36 rounded `Color.alphaBlend(featureAccentsOf(theme).prayer.withValues(alpha: 0.14), cardSurfaceOf(theme))` tile holding `HugeIcons.strokeRoundedMoon02`; `SizedBox(width: ZakerSpacing.sm)`; `Expanded(child: Column(crossAxisAlignment: start, mainAxisSize: min, children: [Row(children: [Flexible(TrText(invocation, maxLines: 1, overflow: ellipsis, fontWeight w800)), if (tomorrow) 'غدًا' badge]), Text(formatClockTime(...)), Text(displayName + ' · ' + hijri.formatted, maxLines 1, ellipsis, onSurfaceVariant, fontSize 11)]))`; then the countdown column (label `'بعد'` at 10 px + `Text(formatCountdown(day.remaining), textDirection: TextDirection.ltr, fontFeatures: tabularFigures, fontWeight w800, color: cardAccentOf(featureAccentsOf(theme).prayer, theme))`); then `HugeIcon(strokeRoundedArrowLeft01, key: Key('home-prayer-chevron'), size: 18, color: onSurfaceVariant)`.

`day == null` renders a single row: prayer icon, `Expanded(TrText('حدد موقعك لمعرفة مواقيت الصلاة', maxLines: 1, overflow: ellipsis))`, chevron — same key, same tap.

Ruling recorded for execution: the row is a 64 dp **minimum**, not a fixed height, so 2.0× text grows it instead of clipping; the spec's "64 dp row" is met at normal scale.

- [ ] **Step 5: Implement `PrayerPill`**

A `ConsumerStatefulWidget` that copies `_HeroBannerState`'s lifecycle (`initState` post-frame onboarding/refresh, `didChangeAppLifecycleState` resume refresh, observer removed on dispose) and returns

```dart
PrayerPillView(
  day: ref.watch(prayerDayProvider),
  location: ref.watch(prayerLocationProvider),
  hijri: ref.watch(prayerHijriProvider),
  onTap: () => context.push(ZakerRoutes.islamicHub),
)
```

- [ ] **Step 6: Run it and watch it pass**

Run in CI: `flutter test test/prayer_pill_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit, push**

```bash
work/dartsdk/dart-sdk/bin/dart format lib/core/theme.dart lib/features/home/widgets/prayer_pill.dart test/prayer_pill_test.dart
work/dartsdk/dart-sdk/bin/dart analyze lib test
git add lib/core/theme.dart lib/features/home/widgets/prayer_pill.dart test/prayer_pill_test.dart
git commit -m "feat(home): replace the prayer block with a one-row prayer pill"
git push origin main
```

- [ ] **Step 8: Read the CI result**

Expected: `conclusion: success` for this task's sha.

---

### Task 5: Home bag preview, library shortcut, and the subject grid removal

**Files:**
- Create: `lib/features/home/widgets/home_bag_preview.dart`
- Create: `lib/features/home/widgets/library_shortcut.dart`
- Modify: `lib/features/home/home_screen.dart` — delete `_LibrarySection`, `_SubjectGrid`, `_SubjectCard`, `_subjectRoute` and any import they alone used (`../../core/curriculum.dart`, `../../models/manhaji.dart` if now unused). Keep `_subjectAccents`: the all-tools grid still cycles it (Task 6 replaces it).
- Test: `test/home_bag_preview_test.dart` (create)

**Interfaces:**
- Consumes: `BagFolderPreview`, `bagFolderPreviewProvider`, `BagFolderStrip` (Task 1).
- Produces: `class HomeBagPreview extends ConsumerWidget` — `const HomeBagPreview({super.key})`; keys `home-bag-preview`, `home-bag-open`; renders `BagFolderStrip(folders: ..., maxFolders: 6)`; copy `'شنطتي'`, `'كل موادك في شنطة واحدة'`, button `'افتح الشنطة'` → `context.push(ZakerRoutes.bag)`.
- Produces: `class LibraryShortcut extends StatelessWidget` — `const LibraryShortcut({super.key})`; key `home-library-shortcut`; copy `'المكتبة الدراسية'` / `'كل الكتب والمناهج في مكان واحد'` → `context.push(ZakerRoutes.courses)`.
- Task 7 consumes both.

- [ ] **Step 1: Write the failing test**

```dart
// test/home_bag_preview_test.dart
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
          child: const Scaffold(
            body: ListView(
              padding: EdgeInsets.all(16),
              children: [
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
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  testWidgets('previews at most six folders and offers the bag', (tester) async {
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
```

No `SingleChildScrollView` is needed: the test hosts the widgets in a `ListView`, exactly as the home does.

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/home_bag_preview_test.dart`
Expected: FAIL — both widget files are missing.

- [ ] **Step 3: Implement `HomeBagPreview`**

A `Container(key: Key('home-bag-preview'))` with `ZakerRadius.cardValue`, `cardSurfaceOf(theme)`, hairline border and `ZakerShadows.card`, `padding: EdgeInsets.all(ZakerSpacing.md)`, holding:

1. A row: 44×44 rounded tile with gradient `[ZakerColors.backpack, Color.lerp(ZakerColors.backpack, Colors.black, 0.3)!]` and a white `HugeIcons.strokeRoundedBackpack01(size: 24)`; `SizedBox(width: ZakerSpacing.md)`; `Expanded(Column: TrText('شنطتي', fontWeight w800, maxLines 1, ellipsis), TrText('كل موادك في شنطة واحدة', maxLines 1, ellipsis, onSurfaceVariant, fontSize 12))`; then `FilledButton.tonal(key: Key('home-bag-open'), onPressed: () => context.push(ZakerRoutes.bag), child: const TrText('افتح الشنطة'))`.
2. `const SizedBox(height: ZakerSpacing.md)`.
3. `BagFolderStrip(folders: ref.watch(bagFolderPreviewProvider), maxFolders: 6)`.

- [ ] **Step 4: Implement `LibraryShortcut`**

A `Material`+`InkWell(key: Key('home-library-shortcut'), borderRadius: ZakerRadius.card, onTap: () => context.push(ZakerRoutes.courses))` card with `cardSurfaceOf(theme)`, hairline, `ZakerShadows.card`, `padding: ZakerSpacing.lg`, a row: study-accent tile with `HugeIcons.strokeRoundedBookOpen01`, `Expanded(Column: TrText('المكتبة الدراسية', w800, maxLines 1, ellipsis), TrText('كل الكتب والمناهج في مكان واحد', maxLines 1, ellipsis, onSurfaceVariant, fontSize 12))`, and a trailing `HugeIcons.strokeRoundedArrowLeft01` in `onSurfaceVariant`.

- [ ] **Step 5: Delete the subject grid from the home**

Remove `_LibrarySection`, `_SubjectGrid`, `_SubjectCard` and `_subjectRoute` from `home_screen.dart` — but keep `_subjectAccents`, which `_AllToolsSection._tiles` still reads — and remove the `_LibrarySection(grades: ..., gradeId: ...)` entry from `HomeScreen.build` (Task 7 rewrites that body; deleting the entries now keeps this task compiling). Remove the `grades`/`gradeId` locals if nothing else uses them.

- [ ] **Step 6: Run it and watch it pass**

Run in CI: `flutter test test/home_bag_preview_test.dart test/`
Expected: PASS, and the whole suite still green (the home is still assembled from the old hero until Task 7).

- [ ] **Step 7: Format, analyze, commit, push**

```bash
work/dartsdk/dart-sdk/bin/dart format lib/features/home test/home_bag_preview_test.dart
work/dartsdk/dart-sdk/bin/dart analyze lib test
git add lib/features/home test/home_bag_preview_test.dart
git commit -m "feat(home): preview the bag and shortcut the library on the home"
git push origin main
```

- [ ] **Step 8: Read the CI result**

Expected: `conclusion: success` for this task's sha.

---

### Task 6: Heritage feature accents on the home cards

**Files:**
- Modify: `lib/features/home/home_screen.dart` — every `_Accents.x` and `_subjectAccents` use
- Test: `test/home_accents_test.dart` (create)

**Interfaces:**
- Consumes: `ZakerFeatureAccents featureAccentsOf(ThemeData theme)` from Task 4.
- Pinned mapping (spec §Visual identity, "feature accents"):

| Site | Old constant | New |
| --- | --- | --- |
| action card — المساعد الذكي | `_Accents.purple` | `accents.assistant` |
| action card — المكتبة الدراسية | `_Accents.teal` | `accents.study` |
| action card — مهامي | `_Accents.blue` | `accents.tasks` |
| countdown banner | `_Accents.amber` | `accents.islamic` |
| advice banner | `_Accents.green` | `accents.tasks` |
| daily tool — calculator | `_Accents.blue` | `accents.study` |
| daily tool — إعراب | `_Accents.amber` | `accents.azkar` |
| daily tool — خطة المذاكرة | `_Accents.green` | `accents.tasks` |
| daily tool — تركيز | `_Accents.purple` | `accents.qibla` |
| daily tool — التقدم الأسبوعي | `_Accents.rose` | `accents.islamic` |
| daily tool — المراجعة | `_Accents.sky` | `accents.hifz` |
| all-tools tile colours | `_subjectAccents[...]` | `_allToolsAccents(accents)[...]` |

`_allToolsAccents` is a private top-level helper in `home_screen.dart` returning `const`-free list `[assistant, study, tasks, islamic, qibla, azkar, hifz]` from the resolved accents; the AI tile keeps index 0 and the remaining tiles keep the `(i + 1) % length` cycle.

- Task 7's home keeps these accents.

- [ ] **Step 1: Write the failing test**

```dart
// test/home_accents_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';

void main() {
  test('every appearance exposes the feature accents', () {
    for (final style in ZakerThemeStyle.values) {
      expect(
        ZakerTheme.forStyle(style).extension<ZakerFeatureAccents>(),
        isNotNull,
        reason: style.id,
      );
    }
  });

  test('a bare theme falls back to the light accents', () {
    final fallback = featureAccentsOf(ThemeData.light());
    final light = ZakerTheme.light().extension<ZakerFeatureAccents>()!;
    expect(fallback.assistant, light.assistant);
  });

  test('the home uses the palette accents, not the old rainbow', () {
    final source =
        File('lib/features/home/home_screen.dart').readAsStringSync();
    expect(source.contains('_Accents.'), isFalse);
    for (final old in const [
      '_Accents.',
      '_subjectAccents.',
      '0xFF7C3AED',
      '0xFF2563EB',
      '0xFFD97706',
      '0xFFE11D48',
      '0xFF0284C7',
      '0xFF059669',
    ]) {
      expect(source.contains(old), isFalse, reason: old);
    }
    expect(source.contains('featureAccentsOf'), isTrue);
  });
}
```

`ZakerColors.primary` is not in the list on purpose: `ZakerColors.primaryDark` contains it as a substring, and that use sits in a hero widget Task 7 deletes.

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/home_accents_test.dart`
Expected: FAIL — the source still contains `_Accents.` and `_subjectAccents.`.

- [ ] **Step 3: Replace every `_Accents.x` use**

Delete the `_Accents` class and replace `_subjectAccents` with `_allToolsAccents`. In each widget that used either, resolve `final accents = featureAccentsOf(Theme.of(context));` and swap per the mapping table. Where the accent paints a label, wrap it: `color: cardAccentOf(accents.study, theme)`. Where it paints an icon or a fill, use the accent directly. Keep `_wash`, `_hairline` and `_depth` exactly as they are.

- [ ] **Step 4: Run it and watch it pass**

Run in CI: `flutter test test/home_accents_test.dart test/theme_brand_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit, push**

```bash
work/dartsdk/dart-sdk/bin/dart format lib/features/home/home_screen.dart test/home_accents_test.dart
work/dartsdk/dart-sdk/bin/dart analyze lib test
git add lib/features/home/home_screen.dart test/home_accents_test.dart
git commit -m "feat(home): retune the action cards, banners and tools to the brand accents"
git push origin main
```

- [ ] **Step 6: Read the CI result**

Expected: `conclusion: success` for this task's sha.

---

### Task 7: Assemble the compact home and prove it

**Files:**
- Modify: `lib/features/home/home_screen.dart` — rewrite `HomeScreen.build`; delete `_HeroBanner`, `_HeroPrayerBlock`, `_HeroPrayerSetup`, `_HeroPrayerLoading`, `_HeroQuickAction`, `_HeroStat`, `_HeroDivider`, `_HeroButton`, `_HeroPill`, `_Bubble`, `_SearchBox`, `_IslamicHubCard`; stack the action cards when text is large
- Test: `test/home_compact_test.dart` (create)

**Interfaces:**
- Consumes: `HomeTopBar`, `homeTopBarHeightFor`, `WelcomeSearch`, `HomeStatsStrip`, `PrayerPill`, `HomeBagPreview`, `LibraryShortcut` (Tasks 2–5).
- Produces: `HomeScreen` with the same public name and `const HomeScreen({super.key})` signature; the body order is the spec's list, 1–9.

- [ ] **Step 1: Write the failing test**

```dart
// test/home_compact_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;
import 'package:zaker_ai/core/auth_service.dart';
import 'package:zaker_ai/core/local_store.dart';
import 'package:zaker_ai/core/shad_theme.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/bag/bag_preview_provider.dart';
import 'package:zaker_ai/features/home/home_screen.dart';
import 'package:zaker_ai/features/home/widgets/home_top_bar.dart';
import 'package:zaker_ai/features/prayer/prayer_models.dart';
import 'package:zaker_ai/features/prayer/prayer_providers.dart';
import 'package:zaker_ai/providers/app_providers.dart';

/// The real controller reports the first run only through its stored state, so
/// the test seeds the flag by subclassing instead of writing a file.
class _OnboardedSettings extends PrayerSettingsController {
  _OnboardedSettings() : super(LocalStore.memory()) {
    state = const PrayerSettings(onboarded: true);
  }
}

List<BagFolderPreview> _folders(int count) => [
  for (var i = 1; i <= count; i++)
    BagFolderPreview(
      id: 'f$i',
      name: 'مادة $i',
      colorValue: 0xFF2F5EA8,
      pocketCounts: const [1, 0, 0, 0],
    ),
];

Widget _app({
  ZakerThemeStyle style = ZakerThemeStyle.light,
  double textScale = 1,
  List<BagFolderPreview>? folders,
}) => ProviderScope(
  overrides: [
    localStoreProvider.overrideWithValue(LocalStore.memory()),
    authUserProvider.overrideWith(
      (ref) => const AuthUser(uid: 'u1', displayName: 'طالب'),
    ),
    prayerSettingsProvider.overrideWith((ref) => _OnboardedSettings()),
    bagFolderPreviewProvider.overrideWithValue(folders ?? _folders(7)),
  ],
  child: MaterialApp(
    theme: ZakerTheme.forStyle(style),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        // shadcn_ui reads its own theme; without this the ShadInput throws.
        child: ShadTheme(
          data: ZakerShadTheme.forStyle(style),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
    home: const Scaffold(body: HomeScreen()),
  ),
);

Future<void> _pumpAt(
  WidgetTester tester, {
  double width = 400,
  double height = 800,
  double textScale = 1,
  ZakerThemeStyle style = ZakerThemeStyle.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(textScale: textScale, style: style));
  await tester.pump();
}

void main() {
  for (final width in [320.0, 360.0, 411.0, 800.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('no overflow at $width dp and ${scale}x text', (tester) async {
        await _pumpAt(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(find.text('اسأل معلم AI عن أي حاجة…'), findsOneWidget);
      });
    }
  }

  for (final style in ZakerThemeStyle.values) {
    testWidgets('no overflow in ${style.id} at 320 dp and 2.0x text', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        width: 320,
        textScale: 2,
        style: style,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the top bar is the formula height at 800 dp', (tester) async {
    await _pumpAt(tester);
    expect(
      tester.getSize(find.byKey(const Key('home-top-bar'))).height,
      closeTo(homeTopBarHeightFor(800), 1e-9),
    );
  });

  testWidgets('the old prayer block and the Islamic hub card are gone', (
    tester,
  ) async {
    await _pumpAt(tester);
    expect(find.text('الصلاة القادمة'), findsNothing);
    expect(find.text('الأذان'), findsNothing);
    expect(find.text('الإسلاميات'), findsNothing);
    expect(find.byKey(const Key('home-prayer-pill')), findsOneWidget);
  });

  testWidgets('the bag preview stops at six folders', (tester) async {
    await _pumpAt(tester);
    expect(find.text('مادة 6'), findsOneWidget);
    expect(find.text('مادة 7'), findsNothing);
    expect(find.text('افتح الشنطة'), findsOneWidget);
  });

  testWidgets('the all-tools grid is still reachable by scrolling', (
    tester,
  ) async {
    await _pumpAt(tester);
    // Drag the keyed body, not `find.byType(Scrollable).first`: the search
    // field owns a scrollable of its own.
    await tester.dragUntilVisible(
      find.text('كل الأدوات'),
      find.byKey(const Key('home-body')),
      const Offset(0, -400),
    );
    expect(find.text('كل الأدوات'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/home_compact_test.dart`
Expected: FAIL — the top-bar key, the pill key and the bag preview are not in the tree; `'الصلاة القادمة'` is still present.

- [ ] **Step 3: Rewrite `HomeScreen.build`**

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final stats = ref.watch(studyStatsProvider);
  final user = ref.watch(authUserProvider);
  final notificationsOn = ref.watch(notificationsEnabledProvider);
  final schedule = ref.watch(taskScheduleProvider);
  final pending = schedule.forDay().where((e) => !e.done).toList();
  final nextDeadline = _nextDeadline(schedule.entries);
  final openDrawer = shellDrawerOpener(context);

  return Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          children: [
            HomeTopBar(
              showBadge: notificationsOn && pending.isNotEmpty,
              onMenu: openDrawer,
              onNotifications: () => _showNotifications(context),
              onSettings: () => context.push(ZakerRoutes.settings),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(gradesProvider);
                  await ref.read(gradesProvider.future);
                },
                child: ListView(
                  key: const Key('home-body'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    WelcomeSearch(name: user?.displayName ?? 'ضيف'),
                    const SizedBox(height: ZakerSpacing.md),
                    HomeStatsStrip(
                      streakDays: stats.streakDays,
                      minutesToday: stats.minutesToday,
                      pendingCount: pending.length,
                    ),
                    const SizedBox(height: ZakerSpacing.md),
                    const PrayerPill(),
                    const SizedBox(height: ZakerSpacing.lg),
                    const HomeBagPreview(),
                    const SizedBox(height: ZakerSpacing.lg),
                    _ActionCards(streakDays: stats.streakDays),
                    const SizedBox(height: ZakerSpacing.md),
                    _BannerRow(
                      nextDeadline: nextDeadline,
                      onCountdown: () => context.push(ZakerRoutes.tasks),
                    ),
                    const SizedBox(height: 22),
                    const _DailyTools(),
                    const SizedBox(height: 22),
                    const LibraryShortcut(),
                    const SizedBox(height: 22),
                    const _AllToolsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

Keep `_showNotifications` and `_nextDeadline` as they are. `gradesProvider` stays the refresh target so pull-to-refresh still reloads the shelves the other screens read.

- [ ] **Step 4: Stack the action cards when space or text is tight**

In `_ActionCards.build`, compute `final scale = MediaQuery.textScalerOf(context).scale(14) / 14;` and take the stacked branch when `constraints.maxWidth < 620 || scale > 1.3`: a `Column` of the three cards, each `SizedBox(width: double.infinity, child: card)` with `SizedBox(height: 10)` between. Otherwise keep today's `IntrinsicHeight` + `Row` exactly.

- [ ] **Step 5: Delete the retired widgets**

Remove `_HeroBanner`, `_HeroPrayerBlock`, `_HeroPrayerSetup`, `_HeroPrayerLoading`, `_HeroQuickAction`, `_HeroStat`, `_HeroDivider`, `_HeroButton`, `_HeroPill`, `_Bubble`, `_SearchBox` and `_IslamicHubCard`, plus now-unused imports (`../../core/prayer_formats.dart` stays for the pill? no — the pill is its own file; delete it if unused, `../prayer/location_flow.dart`, `../prayer/prayer_onboarding.dart`, `../prayer/prayer_models.dart`, `../../core/hijri_date.dart` are candidates). `dart analyze` must be clean afterwards.

- [ ] **Step 6: Run it and watch it pass**

Run in CI: `flutter test test/home_compact_test.dart`
Expected: PASS. Then run the whole suite: `flutter test` → PASS.

- [ ] **Step 7: Format, analyze, commit, push**

```bash
work/dartsdk/dart-sdk/bin/dart format lib/features/home/home_screen.dart test/home_compact_test.dart
work/dartsdk/dart-sdk/bin/dart analyze lib test
git add lib/features/home/home_screen.dart test/home_compact_test.dart
git commit -m "feat(home): assemble the compact home in the spec order"
git push origin main
```

- [ ] **Step 8: Read the CI result**

Expected: `conclusion: success` for this task's sha, whole suite green, APK job green. Record the run id, the test count and the APK size in the ledger.

---

## Self-Review

**Spec coverage.** §Shell: tab 2 label/icon (T1), `_bodyFor(1)` (T1), `/courses` pushed (T1), `/bag` (T1), sidebar already rebranded in Phase 1, selected nav from Phase 1. §Home: top bar (T2), body order 1–9 (T3–T7), old hero/hub removed (T7), overflow rules (T7), top-bar width/scale matrix (T7). §My Bag preview (T1 + T5). §Testing `home_compact_test.dart` (T7) with its five assertions; the five-tabs assertion lives in `test/shell_nav_test.dart` because pumping the full shell would build all five tab screens and their stores — that is the one deliberate deviation and it is named here rather than left implicit.

**Step scan.** Each step names one action and its expected output. Visual steps carry the exact widget tree, keys, copy and token names, so no step leaves a choice of values. No step says "retune appropriately".

**Type consistency.** `BagFolderPreview.pocketCounts` is four ints in every task; `BagFolderStrip` is constructed with `folders:` and `maxFolders:` in T1 and T5; `HomeTopBar`'s parameters are identical in T2 and T7; `PrayerPillView`'s four parameters match T4's test and T7's use of `PrayerPill`; `homeTopBarHeightFor` is used in T2's test and T7's test with the same name.

**Review Focus mapping.** 1 → T7 (`home_compact_test`, action-card stacking in T7 Step 4). 2 → T4 (`PrayerPillView` null day) and T7 (`_OnboardedSettings`). 3 → T1 (`/bag`, `/courses`, library button) and T5 (shortcut tap). 4 → T3 (empty/whitespace submit). 5 → T5 (seven folders, zero folders).

**Proportion.** The plan's code blocks are tests plus one assembly body; every visual instruction is a signature, key, literal or token name, not an implementation transcript.
