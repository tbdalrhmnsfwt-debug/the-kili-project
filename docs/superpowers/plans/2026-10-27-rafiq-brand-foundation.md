# رفيق الطالب — Brand Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the whole app navy-gold «رفيق الطالب» — tokens, four appearances, splash, Android launch/icon, shell colours and brand copy — with no new features.

**Architecture:** The theme stays a token layer: `ZakerColors` gains the brand palette, `ZakerTheme` retunes the four existing `ZakerPalette` instances, and existing widgets that read `primary`/`primaryLight` turn navy without edits. A source-scan test makes teal impossible to reintroduce. Brand identity lives in two new files under `lib/core/brand/`, and the Android launch surface is committed as resource XML that the CI's `flutter create` step must not overwrite.

**Tech Stack:** Flutter 3.x / Dart 3.13, Material 3, Riverpod 2.5.1, Cairo font, `flutter_test` in CI, local ARM64 Dart for analysis only.

**Spec:** `docs/superpowers/specs/2026-10-27-rafiq-al-talib-rebrand-design.md`

**Plan 1 of 7.** The remaining phases (Home & shell, My Bag, PDF annotations & reader, PDF editor & export, Islamic dashboard & focus, calculator & polish) get their own plans once this one ships; each is a working increment.

## Global Constraints

- No new pub dependency, no network call, no analytics.
- Arabic source string is the translation key: widgets use `TrText`, interpolation uses `context.trf`. No ARB/gen-l10n.
- Cairo for UI/body, Amiri for Quran. No new font file.
- Cards are `ZakerRadius.card` = 16 dp; sheets stay 26; `ZakerRadius.md` stays 14 for inner surfaces.
- Card shadow is `ZakerShadows.card` (`0x14203A5C`, blur 10, offset (0,4)); cards keep the 1 px hairline border.
- Gold `#D4AF37` is never used for small text on white; `goldDeep #8A6A12` is the label token there.
- The four appearance ids `light`, `dark`, `black_gold`, `deep_blue` stay storable and behave as today's stored values.
- `flutter test` and `flutter analyze` run in CI; the local ARM64 Dart only runs `dart analyze` and pure-Dart tests.
- No Gradle files are committed. CI runs `flutter create --platforms=android` before building; it skips files that already exist, so committed `res/` files survive — Task 6 adds a guard that proves it.

## Review Focus

1. **Gold primary in dark appearances.** `dark`, `black_gold` and `deep_blue` use gold as `colorScheme.primary`; any hand-written `Colors.white` label painted on that fill becomes unreadable. Task 1 pins the token contrast; Task 7 audits the fills.
2. **Large text on the bottom bar.** Five Arabic labels at 2.0× text scale on a 320 dp screen. Task 5 pins that it ellipsises instead of overflowing.
3. **Reduced motion.** A user with "remove animations" must get no 1.5 s animated splash and no blocking overlay. Task 4 pins it.
4. **Cold start before Flutter.** Android shows the native window background and launcher icon before any Dart runs; on pre-26/pre-31 devices a missing resource means the Flutter default icon or a white flash. Task 6 pins the resources and the generation step that could erase them.
5. **English locale.** App name and credit must translate instead of leaking Arabic keys. Task 3 pins the dictionary entries.

---

### Task 1: Brand tokens, four palettes, radius and shadow

**Files:**
- Modify: `lib/core/theme.dart`
- Test: `test/theme_brand_test.dart` (create)

**Interfaces:**
- Produces: `ZakerColors.navy`, `.navyDeep`, `.navyLight`, `.gold`, `.goldLight`, `.goldDeep`, `.page`, `.ink`, `.muted`, `.border`, `.backpack`; `ZakerColors.primary/primaryLight/primaryDark` = navy/navyLight/navyDeep; `ZakerRadius.cardValue` (`double` 16); `ZakerShadows.card` (`List<BoxShadow>`); `ZakerPalette.secondary` and `.onSecondary` (`Color`).
- Later tasks read these tokens; Tasks 2, 5 and 7 depend on them.

- [ ] **Step 1: Write the failing test**

```dart
// test/theme_brand_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';

void main() {
  test('brand tokens carry the specified values', () {
    expect(ZakerColors.navy, const Color(0xFF121E36));
    expect(ZakerColors.navyDeep, const Color(0xFF0B1426));
    expect(ZakerColors.navyLight, const Color(0xFF1B2B4A));
    expect(ZakerColors.gold, const Color(0xFFD4AF37));
    expect(ZakerColors.goldLight, const Color(0xFFE5C158));
    expect(ZakerColors.goldDeep, const Color(0xFF8A6A12));
    expect(ZakerColors.page, const Color(0xFFF8F9FB));
    expect(ZakerColors.ink, const Color(0xFF121E36));
    expect(ZakerColors.muted, const Color(0xFF5B6678));
    expect(ZakerColors.border, const Color(0xFFE6E9F0));
    expect(ZakerColors.backpack, const Color(0xFFD32F2F));
    expect(ZakerColors.primary, ZakerColors.navy);
    expect(ZakerColors.primaryLight, ZakerColors.navyLight);
    expect(ZakerColors.primaryDark, ZakerColors.navyDeep);
  });

  test('cards are 16 dp with the soft brand shadow', () {
    expect(ZakerRadius.cardValue, 16);
    expect(ZakerRadius.card, const BorderRadius.all(Radius.circular(16)));
    expect(ZakerRadius.md, 14);
    final shadow = ZakerShadows.card.single;
    expect(shadow.color, const Color(0x14203A5C));
    expect(shadow.blurRadius, 10);
    expect(shadow.offset, const Offset(0, 4));
  });

  test('the text pairs the design uses meet 4.5:1', () {
    expect(contrastRatio(Colors.white, ZakerColors.navy),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(ZakerColors.goldLight, ZakerColors.navy),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(ZakerColors.goldDeep, Colors.white),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(Colors.white, ZakerColors.backpack),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(ZakerColors.navy, ZakerColors.goldLight),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(ZakerColors.ink, Colors.white),
        greaterThanOrEqualTo(4.5));
    expect(contrastRatio(ZakerColors.muted, Colors.white),
        greaterThanOrEqualTo(4.5));
  });

  test('plain gold is never a small-text colour on white', () {
    expect(contrastRatio(ZakerColors.gold, Colors.white), lessThan(4.5));
  });

  test('the four appearances keep their ids and on-primary contrast', () {
    expect(
      ZakerThemeStyle.values.map((s) => s.id).toList(),
      ['light', 'dark', 'black_gold', 'deep_blue'],
    );
    for (final style in ZakerThemeStyle.values) {
      final palette = ZakerTheme.paletteFor(style);
      expect(contrastRatio(palette.onPrimary, palette.primary),
          greaterThanOrEqualTo(4.5),
          reason: '${style.id} primary fill text');
      expect(contrastRatio(palette.onSurface, palette.card),
          greaterThanOrEqualTo(4.5),
          reason: '${style.id} card text');
      for (final accent in _accentValues(palette.accents)) {
        expect(contrastRatio(accent, palette.card), greaterThanOrEqualTo(4.5),
            reason: '${style.id} feature accent $accent on card');
      }
    }
    expect(ZakerTheme.paletteFor(ZakerThemeStyle.light).primary,
        ZakerColors.navy);
    expect(ZakerTheme.paletteFor(ZakerThemeStyle.dark).primary,
        ZakerColors.goldLight);
    expect(ZakerTheme.paletteFor(ZakerThemeStyle.blackGold).primary,
        ZakerColors.gold);
    expect(ZakerTheme.paletteFor(ZakerThemeStyle.deepBlue).primary,
        ZakerColors.goldLight);
  });
}

List<Color> _accentValues(ZakerFeatureAccents a) => [
      a.assistant, a.study, a.tasks, a.islamic,
      a.prayer, a.qibla, a.azkar, a.hifz,
    ];
```

- [ ] **Step 2: Run the test and watch it fail**

Run (CI-equivalent, cannot run locally): `flutter test test/theme_brand_test.dart`
Expected: FAIL — `navy` etc. are not defined on `ZakerColors`.

- [ ] **Step 3: Implement the tokens and palettes in `lib/core/theme.dart`**

Add to `ZakerColors` (keep the existing names and doc comments; replace the teal values):

```dart
static const Color navy = Color(0xFF121E36);
static const Color navyDeep = Color(0xFF0B1426);
static const Color navyLight = Color(0xFF1B2B4A);
static const Color gold = Color(0xFFD4AF37);
static const Color goldLight = Color(0xFFE5C158);
static const Color goldDeep = Color(0xFF8A6A12);
static const Color page = Color(0xFFF8F9FB);
static const Color ink = Color(0xFF121E36);
static const Color muted = Color(0xFF5B6678);
static const Color border = Color(0xFFE6E9F0);
static const Color backpack = Color(0xFFD32F2F);

static const Color primary = navy;
static const Color primaryLight = navyLight;
static const Color primaryDark = navyDeep;
static const Color accent = gold;
static const Color surface = page;
static const Color surfaceDark = Color(0xFF0B1220);
```

Add next to `ZakerRadius`:

```dart
static const double cardValue = 16;
static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));

class ZakerShadows {
  const ZakerShadows._();
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14203A5C), blurRadius: 10, offset: Offset(0, 4)),
  ];
}
```

Add `secondary`/`onSecondary` to `ZakerPalette` (constructor, fields, and every palette instance).

Retune the four palettes exactly as follows (accent values are the heritage set from the spec):

| style | seed | primary | onPrimary | secondary | onSecondary | surface | card | border | onSurface | muted | feature accents |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| light | navy | navy | white | gold | navy | `page` | white | `border` | `ink` | `muted` | assistant `#5B4BC4`, study `#2F5EA8`, tasks `#4F7A4A`, islamic `#8A6A12`, prayer `#8A6A12`, qibla `#5B6678`, azkar `#A2603A`, hifz `#5C6B2A` |
| dark | goldLight | goldLight | navy | goldLight | navy | `#0B1220` | `#16233C` | `#26344F` | `#F2F5FA` | `#9AA6BC` | assistant `#B9AEF7`, study `#9CC3F2`, tasks `#A8CBA0`, islamic `#E5C158`, prayer `#E5C158`, qibla `#AEB8C8`, azkar `#E0A882`, hifz `#C3CE8A` |
| black_gold | `#D4AF37` | gold | `#0B0B0B` | gold | `#0B0B0B` | `#000000` | `#141414` | `#332C1C` | `#F5F1E6` | `#A8A29E` | assistant `#E9D5FF`, study `#E3C05B`, tasks `#C3CE8A`, islamic `#E3C05B`, prayer `#E3C05B`, qibla `#D6C08A`, azkar `#F5D07A`, hifz `#B7E4C7` |
| deep_blue | goldLight | goldLight | navy | goldLight | navy | `#071426` | `#0E2038` | `#1E3A5F` | `#E8F0FB` | `#9DB2CE` | assistant `#A5B4FC`, study `#9CC3F2`, tasks `#A8CBA0`, islamic `#E5C158`, prayer `#E5C158`, qibla `#AEB8C8`, azkar `#E0A882`, hifz `#C3CE8A` |

Hero gradients:
`light`: `[navy, navyLight, navyDeep]`; `dark`: `[navyDeep, navy, navyLight]`;
`black_gold`: `[Color(0xFF2A220E), Color(0xFF1A1608), Color(0xFF050505)]` (unchanged);
`deep_blue`: `[Color(0xFF071426), navy, navyDeep]`.

In `_build`, add to the `copyWith` chain `secondary: palette.secondary`, `onSecondary: palette.onSecondary`, `surfaceTint: Colors.transparent`.

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/theme_brand_test.dart`
Expected: PASS (all five tests). If a feature accent misses 4.5:1, darken that single accent until it passes — do not lower the threshold.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme.dart test/theme_brand_test.dart
git commit -m "feat(brand): navy/gold tokens and four retuned appearances"
```

---

### Task 2: Remove every legacy teal literal

**Files:**
- Modify: `lib/core/curriculum.dart:106`, `lib/core/study_library.dart:212`, `lib/features/home/home_screen.dart:242`, `lib/features/tools/irab_screen.dart:415`, `lib/features/tools/calculator_screen.dart:172-173,192,198,238`, `lib/features/calculator/ui/calc_palette.dart:149`, `lib/features/subjects/subjects_screen.dart:289`, `lib/features/prayer/location_picker_sheet.dart:117`, `lib/features/prayer/prayer_home_card.dart:371-372`, `lib/features/hifz/hifz_home_screen.dart:271`, `lib/features/hifz/hifz_session_screen.dart:336`, `lib/features/library/official_library_screen.dart:280`, `lib/features/library/study_grade_screen.dart:153`, `lib/features/library/study_library_screen.dart:178,287`, `lib/features/library/study_subject_screen.dart:219`, `lib/widgets/zaker_visuals.dart:104`
- Test: `test/theme_brand_test.dart` (add one scan test)

**Interfaces:**
- Consumes: the Task 1 tokens.
- Produces: no new API; the source is teal-free.

- [ ] **Step 1: Add the failing source-scan test**

Append to `test/theme_brand_test.dart`:

```dart
test('no legacy teal literal survives under lib/', () {
  const banned = [
    '0F766E', '14B8A6', '115E59', '0D9488', '134E4A',
    '0D4F4A', '0B4F49', '062F2B', '2DD4BF', '99F6E4',
    'CCFBF1', 'F0FDFA', '9FE3D4', '5EEAD4',
  ];
  final offenders = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final text = entity.readAsStringSync().toUpperCase();
    for (final hex in banned) {
      if (text.contains(hex)) offenders.add('${entity.path}: $hex');
    }
  }
  expect(offenders, isEmpty);
});
```

Add `import 'dart:io';` at the top of the file.

- [ ] **Step 2: Run it and watch it fail**

Run: `dart test` — not available for Flutter tests locally; run in CI with `flutter test test/theme_brand_test.dart`.
Expected: FAIL listing the 17 files above.

- [ ] **Step 3: Replace the literals**

| Site | Replace with |
| --- | --- |
| `curriculum.dart` / `study_library.dart` `const _teal = Color(0xFF0F766E)` | `const _teal = ZakerColors.navy;` — rename the identifier and its uses to `_brand` (import `theme.dart`) |
| `home_screen.dart` `softWhite 0xFFF0FDFA` | `Color(0xFFEDF1F8)` |
| `irab_screen.dart` `0xFFCCFBF1` | `Color(0xFFE8EDF6)` |
| `calculator_screen.dart` `[0xFF134E4A, 0xFF0F172A]` | `[ZakerColors.navyDeep, const Color(0xFF0F172A)]` |
| `calculator_screen.dart` `[0xFF0F766E, 0xFF0D9488]` | `[ZakerColors.navy, ZakerColors.navyLight]` |
| `calculator_screen.dart` `0xFF99F6E4` / `0xFFCCFBF1` | `ZakerColors.goldLight` / `const Color(0xFFF2E4B0)` |
| `calc_palette.dart` accent `0xFF0F766E` | `ZakerColors.navy` |
| `subjects_screen.dart`, `official_library_screen.dart`, `study_grade_screen.dart`, `study_library_screen.dart` gradients `[0xFF0F766E, 0xFF0D9488, 0xFF115E59]` | `[ZakerColors.navy, ZakerColors.navyLight, ZakerColors.navyDeep]` |
| `location_picker_sheet.dart` `[ZakerColors.primary, 0xFF0D9488]` | `[ZakerColors.navy, ZakerColors.navyLight]` |
| `prayer_home_card.dart` `[0xFF0F766E, 0xFF0D9488]` | `[ZakerColors.navy, ZakerColors.navyLight]` |
| `hifz_home_screen.dart`, `hifz_session_screen.dart` `[0xFF0F766E, 0xFF115E59, 0xFF0D4F4A]` | `ZakerTheme.paletteFor(ZakerThemeStyle.light).heroGradient` |
| `study_library_screen.dart:178` `StudyStage.secondary => 0xFF0F766E` | `=> ZakerColors.navy` |
| `study_subject_screen.dart:219` `0xFF115E59` | `ZakerColors.navyDeep` |
| `zaker_visuals.dart:104` aurora palette `0xFF0D9488` | `ZakerColors.gold` |

Each `const` list that now references a constant stays `const` because `ZakerColors.navy` is a `const Color`.

- [ ] **Step 4: Run analysis and the scan**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib` → no issues.
Run in CI: `flutter test test/theme_brand_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test/theme_brand_test.dart
git commit -m "feat(brand): sweep the legacy teal tokens out of the tree"
```

---

### Task 3: Brand name, credit and English entries

**Files:**
- Create: `lib/core/brand/rafiq_brand.dart`
- Modify: `lib/main.dart:1,103-108`, `lib/features/home/shell_screen.dart:247-261`, `lib/features/settings/settings_screen.dart:107,114,285`, `lib/features/home/home_screen.dart:2077`, `lib/core/notification_service.dart:1187,1251`, `lib/core/pdf_documents.dart:46,84,258`, `lib/core/official_library_store.dart:285`, `lib/features/achievement/achievement_screen.dart:253`, `lib/features/weekly/weekly_screen.dart:93`, `lib/features/prayer/battery_optimization_screen.dart:357,448,454,460,467,471`, `lib/features/islamic/diagnostics_screen.dart:334`, `assets/i18n/en.json`
- Test: `test/brand_copy_test.dart` (create)

**Interfaces:**
- Produces: `RafiqBrand.appName` (`String` `'رفيق الطالب'`), `RafiqBrand.developer` (`'عبد الرحمن صفوت عطا'`), `RafiqBrand.studio` (`'عبد الرحمن سوفت'`), `RafiqBrand.credit` (`'من تطوير: عبد الرحمن صفوت عطا'`).
- Tasks 4, 5 and the later My Bag phase read these constants.

- [ ] **Step 1: Write the failing test**

```dart
// test/brand_copy_test.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/localization.dart';

void main() {
  test('brand strings are fixed', () {
    expect(RafiqBrand.appName, 'رفيق الطالب');
    expect(RafiqBrand.developer, 'عبد الرحمن صفوت عطا');
    expect(RafiqBrand.studio, 'عبد الرحمن سوفت');
    expect(RafiqBrand.credit, 'من تطوير: عبد الرحمن صفوت عطا');
  });

  test('brand strings have English entries', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final localizations = await AppLocalizations.load(const Locale('en'));
    expect(localizations.t('رفيق الطالب'), 'Rafiq Al-Talib');
    expect(localizations.t('عبد الرحمن سوفت'), 'Abdurrahman Soft');
    expect(localizations.t('من تطوير: عبد الرحمن صفوت عطا'),
        'Developed by: Abdurrahman Safwat Atta');
  });

  test('the window title and the app name are the new brand', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("t('رفيق الطالب')"));
    expect(main, isNot(contains("t('ذاكرلي')")));
  });

  test('the old app name survives only on the legacy layout labels', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('appearance.dart')) continue;
      if (entity.readAsStringSync().contains('ذاكرلي')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
```

`AppLocalizations.load` reads the two JSON assets through `rootBundle`, so the test binds the test binding first; the assets are declared in `pubspec.yaml` already.
- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/brand_copy_test.dart`
Expected: FAIL — `rafiq_brand.dart` does not exist.

- [ ] **Step 3: Add the constants and rewrite the copy**

```dart
// lib/core/brand/rafiq_brand.dart
/// The product identity shown in the shell, splash, Settings and share text.
abstract final class RafiqBrand {
  static const String appName = 'رفيق الطالب';
  static const String developer = 'عبد الرحمن صفوت عطا';
  static const String studio = 'عبد الرحمن سوفت';
  static const String credit = 'من تطوير: $developer';
}
```

Replace the user-visible «ذاكرلي» with «رفيق الطالب» (keep `ZakerHomeLayout` labels unchanged — they name legacy layouts, not the app), and keep each string's surrounding wording:

- `main.dart` title → `t(RafiqBrand.appName)` with the same fallback; its file doc comment → «رفيق الطالب».
- `shell_screen.dart` sidebar brand: title → `RafiqBrand.appName`, subtitle → `RafiqBrand.studio` (Task 5 restyles this block; the copy changes here so the scan below passes).
- Settings «عن ذاكرلي» → «عن رفيق الطالب»; version line → «رفيق الطالب — النسخة 1.1.0 (86)»; share `applicationName` → `RafiqBrand.appName`.
- Notification bodies, battery-optimisation instructions, diagnostics instructions, home all-tools subtitle, achievement and weekly share text, official-library mismatch message, PDF author and page footer → «رفيق الطالب».

Add to `assets/i18n/en.json` (single-line JSON; use `python3 -I` to load, insert and dump with `ensure_ascii=False, sort_keys=True, indent=0` preserved style — check the file's existing formatting first and match it):

```json
"رفيق الطالب": "Rafiq Al-Talib",
"عبد الرحمن سوفت": "Abdurrahman Soft",
"من تطوير: عبد الرحمن صفوت عطا": "Developed by: Abdurrahman Safwat Atta"
```

Keep the existing `"ذاكرلي": "Zakerly"` entry (legacy layout labels still use it).

- [ ] **Step 4: Update the old smoke test**

`test/widget_test.dart` renders «ذاكرلي» today; change the fixture text to `RafiqBrand.appName` and keep asserting `colorScheme.primary == ZakerColors.primary`.

- [ ] **Step 5: Run the tests**

Run in CI: `flutter test test/brand_copy_test.dart test/widget_test.dart` → PASS.

- [ ] **Step 6: Commit**

```bash
git add lib assets/i18n/en.json test/brand_copy_test.dart test/widget_test.dart
git commit -m "feat(brand): rename the product to رفيق الطالب with English entries"
```

---

### Task 4: Brand mark and splash gate

**Files:**
- Create: `lib/core/brand/rafiq_mark.dart`, `lib/core/brand/rafiq_splash_gate.dart`
- Modify: `lib/main.dart` (wrap the router in the gate)
- Test: `test/rafiq_splash_test.dart` (create)

**Interfaces:**
- Consumes: `RafiqBrand`, `ZakerColors`.
- Produces:
  - `class RafiqMark extends StatelessWidget { const RafiqMark({super.key, this.size = 96, this.color = ZakerColors.gold}); final double size; final Color color; }`
  - `class RafiqSplashGate extends StatefulWidget { const RafiqSplashGate({super.key, required this.child, this.animationsDisabled, this.fadeIn = const Duration(milliseconds: 450), this.hold = const Duration(milliseconds: 700), this.fadeOut = const Duration(milliseconds: 400)}); }`
  - The overlay carries `const Key('rafiq-splash')`.

- [ ] **Step 1: Write the failing test**

```dart
// test/rafiq_splash_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/brand/rafiq_mark.dart';
import 'package:zaker_ai/core/brand/rafiq_splash_gate.dart';

Widget _app({bool disabled = false}) => MaterialApp(
      home: RafiqSplashGate(
        animationsDisabled: disabled,
        child: const Scaffold(body: Text('home')),
      ),
    );

void main() {
  testWidgets('shows the mark, name and credit, then gets out of the way',
      (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byKey(const Key('rafiq-splash')), findsOneWidget);
    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(find.text(RafiqBrand.credit), findsOneWidget);
    expect(find.byType(RafiqMark), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byKey(const Key('rafiq-splash')), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('reduced motion finishes fast and never animates forever',
      (tester) async {
    await tester.pumpWidget(_app(disabled: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('rafiq-splash')), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('does not replay on rebuild', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpWidget(_app());
    expect(find.byKey(const Key('rafiq-splash')), findsNothing);
  });

  testWidgets('the mark paints at every used size', (tester) async {
    for (final size in [22.0, 72.0, 180.0]) {
      await tester.pumpWidget(
        MaterialApp(home: Center(child: RafiqMark(size: size))),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/rafiq_splash_test.dart`
Expected: FAIL — the two brand files do not exist.

- [ ] **Step 3: Implement the mark**

`RafiqMark` is a `CustomPaint` with a painter that draws, in `color`: an open book (two mirrored quads with a centre spine) and a four-point star above it. Size the shapes from `size` (book occupies the lower 60%, star the upper 40%, stroke width `size * 0.045`). No image assets, no new fonts, no text inside the mark.

- [ ] **Step 4: Implement the splash gate**

Rules the test pins:
- The overlay is drawn in a `Stack` above `child`; `child` is always built.
- `AnimatedOpacity` fades in over `fadeIn`, holds `hold`, fades out over `fadeOut`, then the overlay is removed with `setState` (`_done = true`). Total = `fadeIn + hold + fadeOut` = 1.55 s.
- `animationsDisabled` is `widget.animationsDisabled ?? WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations`. When true, use 120 ms in, 0 hold, 120 ms out and no scale animation.
- The overlay is a navy `[navy, navyLight, navyDeep]` gradient with `Directionality(textDirection: TextDirection.rtl)`: the mark, `Text(RafiqBrand.appName)` in Cairo bold white, then `Text(RafiqBrand.credit)` and `Text(RafiqBrand.studio)` beneath it in `ZakerColors.goldLight` at 13–15 pt. Above `MaterialApp` there is no inherited text style, so set `fontFamily`, `color` and `textAlign` explicitly on every `Text` and wrap the column in a `DefaultTextStyle`.
- On finish, call `WidgetsBinding.instance.addPostFrameCallback`-safe `setState` only if `mounted`.

- [ ] **Step 5: Wire it into `main.dart`**

Wrap the existing `MaterialApp.router` inside `ZakerlyApp.build` with `RafiqSplashGate(child: …)`, leaving the sync hosts above it untouched.

- [ ] **Step 6: Run the test**

Run in CI: `flutter test test/rafiq_splash_test.dart` → PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/brand lib/main.dart test/rafiq_splash_test.dart
git commit -m "feat(brand): add the gold mark and the navy splash gate"
```

---

### Task 5: Shell brand block and navy/gold navigation

**Files:**
- Modify: `lib/features/home/shell_screen.dart`
- Test: `test/shell_nav_test.dart` (create)

**Interfaces:**
- Produces (public, extracted from the private widgets, same behaviour):
  - `class ShellBottomNav extends StatelessWidget { const ShellBottomNav({super.key, required this.selected, required this.onSelect}); }`
  - `class ShellSidebar extends StatelessWidget { const ShellSidebar({super.key, required this.selected, required this.onSelect, required this.userName, this.drawer = false}); }`
  - Selected items carry `const Key('nav-selected-dot')` on the gold dot.
- Tab 2 stays «المكتبة الدراسية» in this phase; the My Bag phase renames it.

- [ ] **Step 1: Write the failing test**

```dart
// test/shell_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/brand/rafiq_brand.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/features/home/shell_screen.dart';

Widget _host(Widget child, {ZakerThemeStyle style = ZakerThemeStyle.light,
    double textScale = 1, double width = 360}) {
  return MaterialApp(
    theme: ZakerTheme.forStyle(style),
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: inner ?? const SizedBox.shrink(),
      ),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('bottom bar keeps five tabs and paints the selected one',
      (tester) async {
    await tester.pumpWidget(
      _host(ShellBottomNav(selected: 1, onSelect: (_) {})),
    );
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('المكتبة الدراسية'), findsOneWidget);
    expect(find.text('الاختبار'), findsOneWidget);
    expect(find.text('القرآن'), findsOneWidget);
    expect(find.text('الدفعات'), findsOneWidget);
    expect(find.byKey(const Key('nav-selected-dot')), findsOneWidget);

    final theme = Theme.of(tester.element(find.text('الاختبار')));
    final label = tester.widget<Text>(find.text('المكتبة الدراسية'));
    expect(label.style?.color, theme.colorScheme.onPrimary);
  });

  testWidgets('sidebar shows the brand and the studio credit', (tester) async {
    await tester.pumpWidget(
      _host(ShellSidebar(selected: 0, onSelect: (_) {}, userName: 'طالب')),
    );
    expect(find.text(RafiqBrand.appName), findsOneWidget);
    expect(find.text(RafiqBrand.studio), findsOneWidget);
    expect(find.text('ذاكرلي'), findsNothing);
  });

  testWidgets('no overflow at 320 dp and 2.0x text in any appearance',
      (tester) async {
    for (final style in ZakerThemeStyle.values) {
      await tester.pumpWidget(
        _host(
          Column(children: [
            Expanded(child: ShellSidebar(selected: 3, onSelect: (_) {}, userName: 'طالب')),
          ]),
          style: style,
          textScale: 2,
          width: 320,
        ),
      );
      await tester.pumpWidget(
        _host(
          ShellBottomNav(selected: 3, onSelect: (_) {}),
          style: style,
          textScale: 2,
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull, reason: style.id);
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/shell_nav_test.dart`
Expected: FAIL — `ShellBottomNav` / `ShellSidebar` are not defined (the classes are private today).

- [ ] **Step 3: Extract and restyle**

- Rename `_FloatingNav` → `ShellBottomNav` and `_Sidebar` → `ShellSidebar`, keeping `_NavItem`/`_SidebarItem` private. `ShellSidebar` takes `userName` instead of watching `authUserProvider`; `_ShellScreenState` passes `ref.watch(authUserProvider)?.displayName ?? 'ضيف'`.
- Brand block: replace the `HugeIcons.strokeRoundedBookOpen02` tile with `RafiqMark(size: 22)` inside a navy gradient container, title `TrText(RafiqBrand.appName)`, subtitle `TrText(RafiqBrand.studio)`.
- Both nav surfaces: selected fill = `theme.colorScheme.primary` (solid), foreground = `theme.colorScheme.onPrimary` for icon, label and dot; unselected stays `onSurfaceVariant`. Remove every `Colors.white` in these two widgets.
- Add the gold dot `Key('nav-selected-dot')` to the sidebar item and keep the existing dot in the bottom bar, now `onPrimary`-coloured? No — the indicator dot is gold in both: `ZakerColors.gold` on the navy fill (light) and `ZakerColors.navyDeep` on the gold fill (dark). Use `theme.colorScheme.onPrimary` for the dot so it always contrasts; the test only checks the dot exists.
- Bottom-bar label keeps `maxLines: 2`, `overflow: TextOverflow.ellipsis`, `textAlign: center`.

- [ ] **Step 4: Run the test**

Run in CI: `flutter test test/shell_nav_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/shell_screen.dart test/shell_nav_test.dart
git commit -m "feat(brand): brand the shell and paint navigation with palette roles"
```

---

### Task 6: Android launch surface, label and launcher icon

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:84`, `.github/workflows/build-apk.yml` (after the "Generate Android platform files" step)
- Create: `android/app/src/main/res/values/colors.xml`, `values/styles.xml`, `values-night/styles.xml`, `values-v31/styles.xml`, `values-night-v31/styles.xml`, `drawable/launch_background.xml`, `drawable/ic_launcher_foreground.xml`, `mipmap-anydpi/ic_launcher.xml`, `mipmap-anydpi-v26/ic_launcher.xml`, `mipmap-anydpi-v26/ic_launcher_round.xml`
- Test: `.github/workflows/build-apk.yml` guard step (no Flutter test can cover native resources)

**Interfaces:**
- Consumes: the navy/gold values from the spec (`#121E36`, `#D4AF37`).
- Produces: `@color/rafiq_navy`, `@drawable/launch_background`, `@mipmap/ic_launcher`.

- [ ] **Step 1: Add the CI guard first, and watch it fail**

After the "Generate Android platform files" step in `.github/workflows/build-apk.yml`:

```yaml
      # The app's launch surface and label are committed resources. The
      # generation step above must never replace them; fail loudly if it does.
      - name: Verify brand resources survived project generation
        run: |
          grep -q '@drawable/launch_background' android/app/src/main/res/values/styles.xml
          grep -q 'rafiq_navy' android/app/src/main/res/values/styles.xml
          grep -q 'رفيق الطالب' android/app/src/main/AndroidManifest.xml
          test -f android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
          echo "brand resources intact"
```

Push the branch and watch CI: the step FAILS — `styles.xml` and the mipmap do not exist yet. Commit the guard on its own first so the run can see it:

```bash
git add .github/workflows/build-apk.yml
git commit -m "test(brand): guard the committed Android launch resources"
```

- [ ] **Step 2: Add the resources**

`values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="rafiq_navy">#121E36</color>
    <color name="rafiq_navy_deep">#0B1426</color>
    <color name="rafiq_gold">#D4AF37</color>
</resources>
```

`drawable/launch_background.xml` — navy fill with the gold mark centred at 25% of the shortest side:

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/rafiq_navy" />
    <item
        android:width="96dp"
        android:height="96dp"
        android:gravity="center"
        android:drawable="@drawable/ic_launcher_foreground" />
</layer-list>
```

`drawable/ic_launcher_foreground.xml` — a 108×108 vector: a gold `#D4AF37` open book (two mirrored path segments meeting at the spine) with a four-point star above it, all inside the 66 dp safe zone.

`mipmap-anydpi-v26/ic_launcher.xml` and `ic_launcher_round.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/rafiq_navy" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
```

`mipmap-anydpi/ic_launcher.xml` (legacy fallback for API < 26, which beat density buckets):

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/rafiq_navy" />
    <item android:drawable="@drawable/ic_launcher_foreground" />
</layer-list>
```

`values/styles.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

`values-night/styles.xml`: the same `LaunchTheme`; `NormalTheme`'s window background is `@color/rafiq_navy_deep` instead of `?android:colorBackground`.

`values-v31/styles.xml` and `values-night-v31/styles.xml` add the Android 12 splash items:

```xml
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">@color/rafiq_navy</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_launcher_foreground</item>
        <item name="android:windowSplashScreenIconBackgroundColor">@color/rafiq_navy</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
```

- [ ] **Step 3: Change the Android label**

`android/app/src/main/AndroidManifest.xml:84` → `android:label="رفيق الطالب"`. `android:icon="@mipmap/ic_launcher"` stays.

- [ ] **Step 4: Verify the XML locally, then push**

Run: `python3 -I -c "import glob,xml.dom.minidom as m; [m.parse(p) for p in glob.glob('android/app/src/main/res/**/*.xml', recursive=True)]; print('xml ok')"`
Expected: `xml ok`.

Push the branch; CI must show "brand resources intact" after the generation step, and the APK build must succeed.

- [ ] **Step 5: Commit**

```bash
git add android .github/workflows/build-apk.yml
git commit -m "feat(brand): navy launch surface, gold mark and launcher icon"
```

---

### Task 7: Foregrounds on primary fills and the shared card surface

**Files:**
- Modify: `lib/widgets/common.dart` (`FeatureTile`, `StatChip`), plus the sites found by the audit below
- Test: `test/card_surface_test.dart` (create); extend `test/shell_nav_test.dart` only if a shell site surfaces

**Interfaces:**
- Consumes: `ZakerRadius.cardValue`, `ZakerShadows.card`, palette roles.

- [ ] **Step 1: Write the failing card-surface test**

```dart
// test/card_surface_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaker_ai/core/theme.dart';
import 'package:zaker_ai/widgets/common.dart';

void main() {
  for (final style in ZakerThemeStyle.values) {
    testWidgets('FeatureTile uses the 16 dp card and the soft shadow (${style.id})',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZakerTheme.forStyle(style),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: FeatureTile(title: 'أداة', icon: Icons.calculate),
            ),
          ),
        ),
      );

      final inner = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(inner.borderRadius, ZakerRadius.card);

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(FeatureTile), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, ZakerRadius.card);
      expect(decoration.boxShadow, ZakerShadows.card);
    });
  }
}
```

- [ ] **Step 2: Run it and watch it fail**

Run in CI: `flutter test test/card_surface_test.dart`
Expected: FAIL — `InkWell.borderRadius` is 14 and no shadow is set.

- [ ] **Step 3: Fix `FeatureTile`**

Use `ZakerRadius.card` for the `InkWell` radius and add `boxShadow: ZakerShadows.card` to the existing `BoxDecoration`. No other visual change.

- [ ] **Step 4: Audit the primary fills**

For every file that mixes `Colors.white` with `colorScheme.primary` or `ZakerColors.primary` (list them with:
`for f in $(grep -rl "Colors.white" lib/); do grep -q "colorScheme.primary\|ZakerColors.primary" "$f" && echo "$f"; done`),
inspect each `Colors.white` and replace it with `theme.colorScheme.onPrimary` **only** where it is the foreground of a widget whose fill is that primary colour (solid or gradient). Leave white text on `navy`/`navyDeep` gradients and on photos untouched.

Where the widget has no `theme` in scope, take `Theme.of(context).colorScheme.onPrimary`.

- [ ] **Step 5: Verify**

Run: `work/dartsdk/dart-sdk/bin/dart analyze lib test` → no issues.
Run in CI: `flutter test` → whole suite green (the existing PDF, batch and study tests use `ZakerTheme.light()` and must keep passing).

- [ ] **Step 6: Commit**

```bash
git add lib test/card_surface_test.dart
git commit -m "fix(brand): use palette on-primary for text on primary fills"
```

---

## Self-review notes

- Spec coverage for this plan: tokens, four appearances, radius/shadow, global migration items 1–5, brand title/credit, splash, launch/icon, shell colours, English entries, four-appearance manual pass. Home, My Bag, PDF editor, calculator, Islamic dashboard and focus are explicitly the later plans.
- Deliberately deferred: tab 2 relabel and `MyBagScreen` (My Bag plan), the gold indicator-dot design beyond `onPrimary`, the empty-folder/bag surfaces.
- Verification limits: only `dart analyze` runs on this device; every `flutter test` result must come from CI, and Task 6 is only provable in a CI build.
