# Light UI Contrast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the eight Light UI gaps from the 2026-10-29 four-area review — one critical (StatChip labels vanish on navy cards), four important (gold/green as text, dead home-layout setting, white70 on red, translucent hero subtitle), and three minor (qibla needle, dead home widgets, appearance model leniency).

**Architecture:** The palette already exposes `readableTextColor(color, background)`, `cardAccentOf(accent, theme)` and `cardSurfaceOf(theme)` in `lib/core/theme.dart`; every fix routes text through those instead of raw brand shades, so a colour that passes 4.5:1 on the active surface is left untouched and only failing copies are shifted. No new colour constants are introduced except where a surface is not the theme card.

**Tech Stack:** Flutter 3.x, Dart 3.13 (ARM64 SDK at `work/dartsdk/dart-sdk`).

**Spec:** the user-approved four-area gap review of 2026-10-29, Light UI section (findings 1–8).

## Global Constraints

- Verify with `$SDK/bin/dart analyze lib test` (expect `No issues found!`) — `flutter test` cannot run on this device (no ARM64 Flutter engine), so widget tests are analyze-checked here and executed in CI.
- Format only touched files: `$SDK/bin/dart format <paths>`; never `dart format lib test`.
- Contrast claims are checked numerically (WCAG relative luminance) before and after each colour change.
- Arabic user-facing strings, Latin digits.
- Commit per task; do not push.

## Task 1: StatChip labels are invisible on navy cards

**Files:** `lib/widgets/common.dart:161-215`, `test/light_ui_contrast_test.dart` (create)

**Interfaces:**
- Consumes: `readableTextColor`, `cardSurfaceOf` from `core/theme.dart`.
- Produces: `StatChip({..., Color? labelColor})`; existing call sites unchanged.

- [x] Write a widget test that renders `StatChip` on the light theme card (default accent) and on a navy `ZakerColors.navy` background with `color: Colors.white`, and asserts both the value and label colours reach 4.5:1 against the composited chip background.
- [x] Run `dart analyze test/light_ui_contrast_test.dart` and record the current UI code: labels use `onSurfaceVariant`, which fails on navy.
- [x] Derive both colours from the accent: an accent with luminance > 0.8 (callers pass
  `Colors.white` there) marks a chip on a dark banner and keeps itself for value and label;
  any other accent uses `readableTextColor(accent, alphaBlend(accent@10%, cardSurfaceOf(theme)))`
  for the value and `readableTextColor(onSurfaceVariant, same)` for the label.
  Ruling: the plan's first draft measured against the bare card; the numeric check showed the
  chip's own 10% tint drops gold to 4.40:1, so the target is the composited chip surface, and
  the label keeps full accent instead of 85% alpha (unknown backdrop behind a banner chip).
  Cost if wrong: chips read slightly heavier than the old muted look.
- [x] `labelColor` overrides the derived label colour.
- [ ] Analyze clean; commit.

## Task 2: Gold and green used as text on light cards

**Files:** the text call sites found by the audit — `quran/adhkar_screen.dart:179`, `recall/active_recall_screen.dart:347`, `tools/scan_screen.dart:358`, `mistakes/mistakes_screen.dart:272`, `words/words_screen.dart:574`, `subjects/subjects_screen.dart:570`, `azkar/azkar_licenses_screen.dart:128`, `azkar/azkar_list_screen.dart:397,440`, `azkar/azkar_salat_counter_screen.dart:452`, `library/official_book_screen.dart:804,915`, `prayer/qibla_screen.dart:530,623`; test file above.

**Interfaces:**
- Consumes: `cardAccentOf(accent, theme)`.

- [ ] Add contrast assertions for `ZakerColors.gold` and `ZakerColors.success` on the light card, and for `cardAccentOf(...)` on both light and dark themes.
- [ ] Replace `color: ZakerColors.accent` / `ZakerColors.success` in those `TextStyle`s with `cardAccentOf(ZakerColors.accent, theme)` / `cardAccentOf(ZakerColors.success, theme)`; leave icon and fill colours untouched.
- [ ] Analyze clean; commit.

## Task 3: The home-layout setting does nothing

**Files:** `lib/core/appearance.dart:55-100`, `lib/features/settings/appearance_screen.dart:66-79`

- [ ] `AppearanceSettings.fromJson` only accepts layouts whose `available` is true, falling back to `calm`.
- [ ] Delete the unused `AppearanceController.palette` getter.
- [ ] Render the «شكل الصفحة الرئيسية» section only when at least two layouts are available.
- [ ] Analyze clean; commit.

## Task 4: `white70` labels on the red bag banner

**Files:** `lib/features/bag/my_bag_screen.dart:583,639`

- [ ] Use pure `Colors.white` for both labels (white on `ZakerColors.backpack` ≥ 4.5:1).
- [ ] Analyze clean; commit.

## Task 5: Translucent white subtitle on the subject hero

**Files:** `lib/features/subjects/subject_screen.dart:424-468`

- [ ] Derive the title and subtitle colours with `readableTextColor(Colors.white, subject.color)` so light subject colours get dark text instead of 85% white.
- [ ] Analyze clean; commit.

## Task 6: White kaaba on gold in the black-gold and deep-blue themes

**Files:** `lib/features/prayer/qibla_compass.dart:131-160`

- [ ] When not aligned, the disc is painted with `primary` (gold in two themes); use `theme.colorScheme.onPrimary` for the icon and its ring in that branch, and keep white for the aligned green disc.
- [ ] Analyze clean; commit.

## Task 7: Dead home widgets carry light-only borders

**Files:** delete `lib/features/home/widgets/home_bag_preview.dart`, `lib/features/home/widgets/library_shortcut.dart`, `lib/features/bag/widgets/bag_folder_strip.dart`, `test/home_bag_preview_test.dart`

- [ ] Re-verify with `grep -rn` that only the test imports `HomeBagPreview`/`LibraryShortcut` and only the preview imports `BagFolderStrip`.
- [ ] Delete; `dart analyze lib test` clean; commit.

## Task 8: Final verification

- [ ] `dart analyze lib test` clean; run the numeric contrast table for every changed pair and record it in the commit message.
- [ ] Note in the final message that widget tests cannot run locally (no ARM64 Flutter engine) and CI is billing-blocked.
