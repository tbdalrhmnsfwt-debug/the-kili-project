# «رفيق الطالب» — full navy/gold rebrand and feature integration — Design

**Date:** 2026-10-27
**Status:** Draft — awaiting user approval after a cold builder review
**Approach:** A — full rebrand in place, then additive feature modules
**Scope decision:** keep every existing feature and route; replace the old look,
not the app.

## Intent

The app is the working Flutter replica of **ذاكرلي / Zakerly**: an Arabic-first
student companion with a study library, exams, Quran and azkar, prayer times,
batches, PDF tools, a scientific calculator and a focus timer. The user wants it
to become **«رفيق الطالب»**: the same product and the same features, with a
deep-navy and gold identity, a compact home, a new «شنطتي» bag, a real PDF
editor, a Casimir-style calculator face, a proper Islamic dashboard, and the
requested focus-session presets.

This is a rebrand and an integration, not a new app. A student who used the
previous build must still find every old screen, route, saved grade, task, PDF,
batch and setting after the update. Nothing is removed to make the new design
easier.

The brief's quality bar is explicit: no `RenderFlex` overflow at any supported
phone width or text scale, and no invisible text on either navy or white.

## Goals

- Rebrand the whole app through the existing `ZakerColors` / `ZakerPalette` /
  `ZakerTheme` system: navy `#121E36`–`#1B2B4A`, gold `#D4AF37` and
  `#E5C158`, off-white `#F8F9FB`, white cards with 16 dp radius and a
  `blurRadius: 10, offset: (0, 4)` shadow, and Cairo typography.
- Make text on white deep navy and text on navy white or light gold; remove
  every remaining teal assumption and every fixed white label that lands on a
  gold surface.
- Add the «رفيق الطالب» splash and brand mark, including the developer credit
  «من تطوير: عبد الرحمن صفوت عطا» / «عبد الرحمن سوفت», with a smooth fade-in.
- Rebuild the home screen around a compact top bar, an AI search bar, a slim
  next-prayer strip, and «شنطتي»; keep the existing actions, banners, daily
  tools and complete all-tools grid.
- Make «شنطتي» the second tab. Each subject folder has four real pockets:
  PDFs with auto-resume, voice recordings with a waveform player, board images
  with an image-to-PDF compiler, and study links. The full study library stays
  reachable at `/courses`.
- Add a Samsung-Notes-inspired PDF editor: sliding toolbar, straight
  horizontal/vertical highlighter with `BlendMode.multiply`, text styles,
  colour palette, insert menu (voice, image, camera, scan, audio file, freehand,
  emoji/stickers), and blank ruled/blank pages, with a durable sidecar and a
  real exported PDF.
- Reskin the existing 12-mode calculator as a Casio 991-style instrument,
  including SHIFT gold, ALPHA red, a D-pad/MODE strip, teal function keys,
  dark grey number keys, blue operators and a gold `=`, while moving the
  keypad body to `SliverGrid`.
- Turn `/islam` into a standalone navy/gold dashboard: compact next-prayer card
  with countdown, location and Hijri date; a horizontal five-prayer strip;
  adhan and salat-reminder switches with intervals; real preview/test buttons;
  all ten existing tool tiles remain.
- Add focus presets of 5 min, 10 min, 1 h, 2 h, 3 h and 10 h, plus a live
  prayer-to-prayer session such as «من الظهر للعصر» that ends at the next
  prayer.
- Preserve the app's local-first, offline, account-free behaviour. No new
  network dependency, backend, analytics, ads or permission is introduced.

## Non-goals (explicitly out of this iteration)

- No new standalone application, package id, repository or launcher entry.
  The Android package stays `com.zaker.zaker_ai`; only the display identity
  changes.
- No removal or renaming of an existing route. The second tab's label changes
  to «شنطتي», but `/courses` and every `/library`, `/prayer`, `/quran`,
  `/batches`, PDF and tool route still resolve.
- No server, sync, cloud AI, account system, push service or public file URL.
- No new Flutter package. The work uses the already-resolved stack:
  Riverpod 2.5.1, go_router 14.2.7, `syncfusion_flutter_pdf` 35.1.41,
  `pdf`/`printing`, `file_picker`, `image_picker`, `share_plus`,
  `url_launcher`, `path_provider`, `flutter_local_notifications`,
  `adhan_dart` and the existing native audio channels.
- No PDF text reflow, OCR-to-editable-text, Office conversion, digital
  signature, form filling, or editing of the original PDF's own text objects.
- No Readex Pro download. Cairo is already bundled and satisfies the brief's
  «Cairo or Readex Pro» choice.
- No runtime import of a user's salat recording. The app bundles one licensed
  human recording and explains the remaining phrase gap honestly.
- No Dart audio isolate. Audio continues through the existing Android
  `MethodChannel` / foreground-service architecture; that is the reliable
  background path on this platform.
- No new appearance styles and no removal of the four selectable appearances.
  All four are retuned so an existing stored preference still works.

## Anti-goals

The work fails if any of these is true even when the new screens look right:

- The old teal survives somewhere visible, so the app looks half-rebranded.
- Gold is used for small text on white; it is unreadable and fails the brief.
- A new screen introduces a fixed `Row` that overflows at 320 dp or 2.0× text.
- A control is shown but does nothing, or a recording/sound is claimed when the
  file is missing.
- The PDF editor overwrites the imported original or silently discards
  annotations on a crash.
- «شنطتي» hides or removes the study library, official books, exams, Quran,
  batches or any existing tool.
- The new identity is applied only to a splash and two cards while the rest of
  the app remains teal/amber.

## Constraints and environment

- Flutter, Arabic-first RTL, Material 3, Riverpod `StateNotifier` + `LocalStore`
  JSON persistence, go_router route constants in `lib/core/router.dart`.
- The repository intentionally has no Gradle files; CI runs `flutter create
  --platforms=android` before building, so the generated template's
  `minSdk`/`targetSdk` are authoritative. Do not add a Gradle patch to pin 32/36
  (the original APK's values are background, not a build constraint). Android
  resources must therefore include a pre-26 legacy launcher icon and a pre-31
  launch background, because the generated `minSdk` may be below 26/31. CI
  builds Android only. The local machine is ARM64 and uses
  `work/dartsdk/dart-sdk/bin/dart`; Flutter tests and Kotlin compilation happen
  in CI. No result may be claimed that did not run.
- The PDF renderer is native Android `PdfRenderer` with tiled PNG responses,
  normalized page geometry, a bounded tile cache, and an immutable app-private
  base file. Syncfusion is the writer.
- Existing native audio channels: `zaker/audio_recorder` with
  `RecorderTick {elapsedMs, amplitude, maxReached}` and
  `zaker/audio_player` with position/duration events. Reuse them; do not add a
  second recorder.
- Existing prayer providers expose `PrayerDay`, `previousTime`, `next`,
  `remaining`, `progress`, `phaseFor`; no prayer API is needed.
- Existing four appearances and their string ids (`light`, `dark`,
  `black_gold`, `deep_blue`) are stored in `LocalStore`. Keep the ids.
- Existing tests: 64 files. `test/widget_test.dart` asserts the old «ذاكرلي»
  title and must be updated. There are no home/shell/golden tests today.
- The Android launch resources and launcher icon are currently absent and CI
  regenerates missing scaffolding with `flutter create`. New resources are
  committed so CI keeps them.

## Approaches considered

1. **Fork a separate «رفيق الطالب» app.** Clean slate for the visual identity,
   but every study library, batch, exam, prayer and native channel would have
   to be rebuilt or copied. It would split data and violate «keep all existing
   features». Rejected.
2. **Skin only the new screens and prototype the rest.** Fast to demo, but the
   old teal home, library and prayer screens would sit beside navy/gold new
   ones. The brief explicitly says full identity refresh. Rejected.
3. **In-place token migration plus additive modules (chosen).** Change the
   central palette and radius/shadow tokens first, sweep hard-coded teal, then
   add «شنطتي», the PDF editor and the new dashboards on top of the existing
   services. This keeps every route and saved value, and makes the brand
   change testable in one place.
4. **PDF editor as a rewrite vs. an extension of the reader.** A separate
   reader rewrite would risk the tested tiled renderer. The chosen route is a
   shared annotation/page model with a new editor screen and a read-only
   overlay added to the existing reader.
5. **Calculator rewrite vs. reskin.** The 12 computation modes are real and
   tested; rewriting them would add risk with no product gain. Reskin
   `CalcPalette`, keep every mode, and replace the keypad body with a
   `SliverGrid`.
6. **«شنطتي» as a home section only vs. the second tab.** A home-only section
   would leave the old library tab in place, contradicting «replace the
   standard library with شنطتي». The second tab becomes «شنطتي»; the full
   library moves behind a visible button and `/courses`.

## Architecture

New code, grouped by responsibility:

```
lib/core/theme.dart                     # navy/gold tokens, four palettes, shadows
lib/core/brand/rafiq_brand.dart         # brand strings, logo painter, splash gate
lib/core/my_bag/
  my_bag_models.dart                    # folders, pockets, links, clips
  my_bag_store.dart                     # atomic index + per-folder files
  my_bag_controller.dart                # Riverpod state + seeding
  image_pdf_builder.dart                # shared board-image → PDF bytes
lib/core/pdf/annotations/
  pdf_annotation.dart                   # sealed annotation + page-ref models
  pdf_annotation_codec.dart             # versioned sidecar JSON
  pdf_annotation_store.dart             # atomic read/write/asset files
  pdf_annotation_controller.dart        # CRUD, undo/redo, autosave
  pdf_page_layout.dart                  # base + inserted page flattening
  pdf_export_service.dart               # Syncfusion writer
lib/features/bag/
  my_bag_screen.dart
  bag_folder_screen.dart
  bag_pocket_screen.dart
  widgets/…                             # folder card, pocket grid, waveform
lib/features/pdf/
  pdf_editor_screen.dart
  widgets/pdf_editor_toolbar.dart
  widgets/pdf_text_options_sheet.dart
  widgets/pdf_insert_sheet.dart
  widgets/pdf_annotation_layer.dart
  widgets/pdf_page_overlay.dart
lib/features/islamic/islamic_hub_screen.dart   # rewritten dashboard
lib/features/focus/focus_screen.dart           # new presets + prayer window
lib/features/calculator/…                      # reskinned palette + SliverGrid
lib/features/home/home_screen.dart             # compact home
lib/features/home/shell_screen.dart            # tab 2 → شنطتي, navy/gold nav
lib/core/router.dart                           # /bag, /pdf-editor, /courses
android/app/src/main/res/…                     # launch theme, icon, salat raw
assets/salat/…                                 # CC0 human salat clip + licence
```

Dependency direction: feature screens depend on core controllers; core models
stay Flutter-free where they already are (`PdfAnnotation`, `MyBagIndex`,
`PdfPageLayout`) so they can be verified with plain Dart.

## Visual identity

### Tokens

Add to `ZakerColors` (existing names keep their meaning; only their values and
a few foreground roles change):

| Token | Value | Use |
| --- | --- | --- |
| `navy` | `#121E36` | primary light-theme brand, text on white |
| `navyDeep` | `#0B1426` | gradient end, dark backing |
| `navyLight` | `#1B2B4A` | gradient mid, raised navy |
| `gold` | `#D4AF37` | accent, icon fill, selected indicator |
| `goldLight` | `#E5C158` | text/icons on navy, dark-theme primary |
| `goldDeep` | `#8A6A12` | gold-family text on white (4.5:1) |
| `page` | `#F8F9FB` | light scaffold |
| `ink` | `#121E36` | light-theme body text |
| `muted` | `#5B6678` | secondary text on light |
| `border` | `#E6E9F0` | card hairline |
| `backpack` | `#D32F2F` | the red «شنطتي» backpack only |
| `danger` | `#DC2626` | errors/destructive |
| `success` | `#16A34A` | success |

`ZakerColors.primary`, `primaryLight`, `primaryDark` are redefined to `navy`,
`navyLight`, `navyDeep`. This deliberately turns the many existing
`primary → primaryLight` gradients navy in one change, with white foregrounds
still legible. Any use of `primaryLight` as a **foreground on a dark surface**
must be migrated to `theme.colorScheme.primary` (gold in dark themes) or
`ZakerColors.goldLight`; those are the only old usages that would become
invisible.

Gold is never used for small text on white. `readableTextColor` stays as the
last-resort adjuster, and `goldDeep` is the explicit token for label text.

### Four appearances

The enum, ids and stored preferences stay. Values are retuned:

| Style | Surface | Card | Primary | On primary | Hero gradient |
| --- | --- | --- | --- | --- | --- |
| `light` — رفيق فاتح | `#F8F9FB` | `#FFFFFF` | navy `#121E36` | white | navy → navyLight → navyDeep |
| `dark` — رفيق ليلي | `#0B1220` | `#16233C` | goldLight `#E5C158` | navy `#121E36` | navyDeep → navy → navyLight |
| `black_gold` — أسود وذهبي | `#000000` | `#141414` | gold `#D4AF37` | black | existing black/gold, warmed |
| `deep_blue` — أزرق عميق | `#071426` | `#0E2038` | goldLight `#E5C158` | navy | deep blue → navy → navyDeep |

`ColorScheme.secondary` is gold (on light: `goldDeep` for text, with `gold` for
fills). `surfaceTint` is transparent so white cards stay white.

Feature accents become a restrained heritage set, not the old teal rainbow:
muted violet for the assistant, steel blue for study, sage for tasks, goldDeep
for Islamic/prayer, slate for qibla, clay for azkar, olive for hifz. Each is
checked against its own card surface at 4.5:1 for label text.

### Shape, shadow, type

- `ZakerRadius.card` becomes `16`; `ZakerRadius.md` stays `14` for inner
  surfaces; sheets stay 26.
- Add `ZakerShadows.card` = `BoxShadow(color: 0x14203A5C, blurRadius: 10,
  offset: Offset(0, 4))`. Apply it to `FeatureTile`, the new bag/folder cards
  and other white elevated cards. Cards keep the hairline border; the shadow is
  soft, not a Material elevation.
- Cairo for UI and body, Amiri for Quran. No new font file.
- Headings on navy are white; small labels on navy use `goldLight`; body text
  on white uses `ink`.

### Global migration

1. Update `theme.dart` tokens and all four `ZakerPalette` instances.
2. Replace the hard-coded teal hex values (`0F766E`, `14B8A6`, `115E59`,
   `0D9488`, and the `_teal` constants) across the 16 files that still carry
   them.
3. Replace `Colors.white` foregrounds that sit on `primary` or gold with
   `palette.onPrimary` / `theme.colorScheme.onPrimary`.
4. Replace dark-surface `primaryLight` foregrounds with the theme primary or
   `goldLight`.
5. Add a static brand test that fails if an old teal token reappears under
   `lib/`, and contrast tests for the pairs above.

## Brand, splash and launch

- App title becomes «رفيق الطالب» through `MaterialApp.onGenerateTitle` (it is
  currently `t('ذاكرلي')`, so the title follows the locale), the Android label
  and launcher resources. The Dart class `ZakerlyApp` and package name stay;
  this is an identity change, not a package rename.
- Brand mark: a gold open book with a four-point star, drawn once as a
  `CustomPainter` and mirrored as a simple Android vector for the launch icon.
  No third-party logo or font is introduced.
- Flutter splash: a `RafiqSplashGate` above `MaterialApp.router` shows the mark,
  «رفيق الطالب», and the credit «من تطوير: عبد الرحمن صفوت عطا» / «عبد الرحمن
  سوفت» on a navy gradient. Timings: 450 ms fade/scale in, 700 ms hold, 400 ms
  fade out; reduced-motion mode uses a 120 ms cross-fade. It never blocks the
  first frame after it fades and never replays on resume.
- Native launch: `LaunchTheme` and `NormalTheme` use navy, a gold vector mark,
  and a matching Android 12 splash background. Add adaptive launcher icon
  resources (navy background, gold foreground), plus legacy PNG mipmaps for
  devices below API 26, so the app icon is not the Flutter default on any
  supported device. Add a pre-31 `windowBackground` drawable for the same navy
  launch surface. All text on the launch screen is drawn by Flutter; the
  Android 12 system splash only shows the mark.
- The first-run experience remains: the existing prayer onboarding and the
  Islamic intro sheet are not replaced by the splash.

## Shell and navigation

- Five tabs stay, with tab 2 relabelled «شنطتي» and given the backpack icon:
  الرئيسية، شنطتي، الاختبار، القرآن، الدفعات.
- Selecting a tab in the floating bar or sidebar switches the body in the
  existing `IndexedStack`, so state is preserved exactly as today.
- `_bodyFor(1)` becomes `MyBagScreen`. `/courses` still renders
  `StudyLibraryScreen`, but as a pushed top-level route with a normal back
  button rather than the shell's second tab. A visible «المكتبة الدراسية»
  button in the bag header and the existing all-tools grid keep the library
  one tap away.
- New route `ZakerRoutes.bag = '/bag'` renders
  `ShellScreen(initialIndex: 1, child: MyBagScreen())` for deep links.
- New route `ZakerRoutes.pdfEditorPattern = '/pdf-editor/:docId'` renders
  `PdfEditorScreen(docId: …)`. The reader's «تحرير» action pushes it.
- Sidebar brand becomes «رفيق الطالب» with the small «عبد الرحمن سوفت» line.
  Selected nav items use the active palette's primary gradient and
  `onPrimary`, not hard-coded white. A small gold indicator dot marks the
  selected tab in both nav surfaces.
- Mobile bottom bar labels may wrap to two lines but must ellipsis at 2.0×
  text; the bar keeps five equal slots.

## Home

The home is a `Column` with a fixed compact top bar and an
`Expanded(RefreshIndicator(ListView(...)))`, inside the existing max-width
1080 constraint.

**Compact top bar.** Height
`(MediaQuery.sizeOf(context).height * 0.06).clamp(48.0, 56.0)` plus the top
safe-area inset. On a 800–900 dp phone that is 48–54 dp, under the 6% target;
on very short screens 48 dp is the accessibility floor. Contents: menu button,
«رفيق الطالب» wordmark (one line, ellipsis), notification bell with unread
badge, settings. No greeting block in the bar.

**Home body, in order:**

1. `_WelcomeSearch` — a compact navy gradient strip (about 128 dp) with
   «صباح الخير، {name}» / «مساء الخير، {name}», a one-line gold subline, and
   the AI search field. Search hint: «اسأل معلم AI عن أي حاجة...»; submitting
   opens `/chat?q=...` exactly as today.
2. `_StatsStrip` — three compact chips (streak, minutes today, pending tasks)
   using `Wrap` so they reflow.
3. `_PrayerPill` — one 64 dp row: next prayer name and time, live countdown,
   location and Hijri date; tap opens `/islam`; a trailing chevron is the only
   affordance. No full prayer card, no prayer quick-action row, no progress
   ring on the home.
4. `_BagPreview` — the red backpack hero and up to six subject folders from
   «شنطتي», each with four tiny pocket count dots and an «افتح الشنطة» button.
   This is a preview; the full folder UI lives in the bag tab.
5. `_ActionCards` — the existing three actions (AI, study library, tasks),
   restyled to the new card language and kept compact.
6. `_BannerRow` — the task countdown and daily-advice banners, preserved.
7. `_DailyTools` — the existing six tools (calculator, i‘rab, study plan,
   focus, weekly progress, recall), retuned.
8. `_LibraryShortcut` — a single card linking to `/courses`, replacing the
   old `_LibrarySection` subject grid on the home.
9. `_AllToolsSection` — the complete existing tool grid, every route kept.
   This is the safety net: no feature becomes unreachable because the second
   tab changed.

The old `_HeroBanner` prayer block and `_IslamicHubCard` are removed from the
home. Their functions move to the compact pill and `/islam`; the routes and
settings remain. The notifications sheet, location onboarding and refresh
behaviour stay.

**Overflow rules for the home:** every text gets `maxLines` +
`TextOverflow.ellipsis`; all horizontal groups use `Expanded`/`Wrap`/a
horizontal scroller, never an unconstrained fixed-width `Row`; the all-tools
grid is responsive (`SliverGrid` or a `GridView` with a computed column count)
and the body is a `ListView`. The top bar must be tested at 320, 360, 411 and
800 dp widths and at 1.0/1.5/2.0 text scales.

## «شنطتي» — My Bag

### Data model and storage

`MyBagIndex` (versioned JSON, stored in `LocalStore` under `my_bag_index`):

```
MyBagIndex { int version; List<MyBagFolder> folders; }
MyBagFolder {
  String id;              // 'subject:<gradeId>:<subjectKey>' or 'custom:<uuid>'
  String name;
  String gradeId;         // '' for custom folders
  String subjectKey;      // canonical key from officialSubjectKey()
  bool custom;
  int colorValue;
  String iconName;        // a HugeIcons selector name, not a raw icon object
  List<String> pdfIds;    // explicit library references
  DateTime createdAt;
}
MyBagVoiceClip { String id; String fileName; int durationMs; int sizeBytes;
                 int createdAtMs; String title; List<int> waveform; }
MyBagBoardImage { String id; String fileName; int width; int height;
                  int createdAtMs; }
MyBagLink { String id; String title; String url; int createdAtMs; }
```

Files live under the app support directory:

```
my_bag/
  folders/<folderId>/voice/<clipId>.m4a
  folders/<folderId>/boards/<imageId>.jpg
  folders/<folderId>/links.json
  folders/<folderId>/meta.json
```

The index is small and atomic; media is per-folder and private. A deleted
folder removes its own folder after confirmation; PDF library files are never
deleted by the bag. Removing a PDF from a folder only removes the reference.
`pdfIds` entries that no longer resolve are pruned lazily on open.

### Seeding subject folders

On first open for the selected grade, the controller reads
`studySubjects(grade, readLessons)` and ensures one folder per subject, using
`officialSubjectKey(name)` for stability. Existing folders are not duplicated
when the grade or catalog changes. Custom folders are always shown. This means
the bag is not an invented second curriculum: it mirrors the same subjects the
library already derives from the bundled indexes.

The bag never hides saved material when the selected grade changes. The folder
grid is grouped by grade with the current grade first, and a grade filter
(«الصف الحالي» / «كل الصفوف» / a specific grade) sits above it; the default is
the current grade, and «كل الصفوف» shows every folder, including previous
grades, grouped under its grade heading. Custom folders appear in both views.
Old-grade folders can be renamed or deleted like any other folder; a grade
change only changes the default filter, not what still exists.

`PdfDocumentEntry` gains optional `subjectKey`, `gradeId` and `sourceDocId`
fields (absent in old JSON, default `''`). Import from a bag folder sets them;
the general PDF library can assign a document to a folder later. The existing
`lastPage` field is the auto-resume value.

### Screens

**`MyBagScreen`** — AppBar «شنطتي» (shell menu), actions: study-library link
and search. A red backpack hero (HugeIcon `backpack`, red gradient, white
icon) with a one-line tagline, four pocket totals (PDFs, recordings, boards,
links) and an «المكتبة الدراسية» outlined button. Below, a grade filter row
(«الصف الحالي» default, «كل الصفوف», and a grade picker) and a responsive
`SliverGrid` of folder cards grouped by grade (2 columns phone, 3 at 700 dp,
4 at 1000 dp).
Each card: coloured subject tab, icon, name, read progress, four pocket chips
with counts, and an overflow menu (rename / change colour / delete). A final
«أضف مادة» card creates a custom folder. Empty state explains that folders are
created from the selected grade and offers the library link.

**`BagFolderScreen`** — header with folder name, colour, and a four-pocket
2×2 grid. Each pocket shows its icon, label, count and a one-line preview.
Tapping opens `BagPocketScreen(folderId, kind)`; long-press on a pocket opens
the same screen. Under the pockets, a «آخر ما أضفت» list of the four most recent
items across pockets.

**`BagPocketScreen`** — one of four bodies, selected by
`BagPocketKind { pdfs, voice, boards, links }`. Every body is a `CustomScrollView`
with a sliver app bar action for adding, and a max-width list/grid. No fixed
`Row` of controls.

### Pocket behaviours

**PDFs.** List the folder's `pdfIds` with thumbnail, title, size, page count,
favourite star and last-page progress («صفحة 12 من 240»). Tap opens
`PdfReaderScreen(docId: …, mode: read)`; the reader already restores `lastPage`.
«أضف PDF» uses `file_picker` → `PdfLibraryController.import`, tags the new
entries, and adds their ids. Long-press offers «افتح في المحرر», «أزل من
الشنطة», «شارك», «أعد التسمية». If a reference is missing, show a one-line
stale row with «أزل المرجع», not a crash. A small «فتح ملفاتي» action opens the
existing PDF library.

**Voice.** A record button opens a bottom sheet with a live timer, an
amplitude waveform from `RecorderTick.amplitude`, cancel and save. Permission
is requested at the moment of recording; denied shows a plain explanation and
an «افتح الإعدادات» action. On save, copy the temp M4A into the folder and
store the clip metadata plus a downsampled waveform (max 96 samples). The list
player is a waveform strip with play/pause, seek by tap, duration, title, share
and delete. Playback uses `AudioPlayerChannel`; exactly one player is open at a
time. Cap: 15 minutes per clip (the native recorder already enforces it) and
100 clips per folder.

**Boards.** A photo grid with camera/gallery import (up to 25 images at once,
each downscaled to max 2200 px / JPEG 88), drag-to-reorder, delete, and a
«كوّن PDF» button. The button calls the shared `ImagePdfBuilder`, which builds
an A4 PDF with one image per page, white margins and aspect-fit; the result is
saved through `PdfLibraryController` and added to the folder's PDF pocket, then
offered as «افتح» / «شارك». The same builder is extracted from the existing
scan screen so both paths produce identical output. No OCR is required for this
pocket; the scan screen's OCR remains separate.

**Links.** Add/edit a link with title and URL. Accept only `http`/`https`;
reject and explain anything else. List shows title, host and date; tap opens
with `url_launcher` in the external app; long-press edits or deletes. Cap 100
per folder. No favicon fetch or network call is made before the tap.

### Empty, error, and deletion rules

- Empty pocket: icon, one sentence, one primary action; no zero-value charts.
- Missing media file: keep metadata, show «الملف مش موجود» and a delete action.
- Folder delete: confirmation names the folder and says that recordings,
  board images and links will be deleted and PDFs will only be untagged.
- No bag operation logs titles, URLs, recordings or PDF text.

## PDF editor

### Relationship to the existing reader

The native tiled reader stays. `PdfReaderScreen` gains:

- a read-only annotation overlay and virtual-page support;
- the same flattened page list as the editor;
- an «تحرير» action when the document is not encrypted and the handle opened;
- a «مشاركة مع التعديلات» action that exports on demand.

A new `PdfEditorScreen` owns editing; it reuses the tiled viewport rather than
reimplementing rendering.

### Page references and virtual pages

`PdfPageRef` is either `base(index)` or `inserted(id)`. `PdfInsertedPage` has
`after: PdfPageRef`, a monotonically increasing `order`, a `template` of
`blank | ruled | lined` (ruled and lined are the same horizontal-rule style
with different spacing; the UI exposes «مسطرة» and «سادة»), and a page size in
points (default A4 portrait, or the current page's size when it is a base
page). `PdfPageLayout.flatten(baseCount, insertedPages)` builds the display
order: base pages in order, each followed by the inserted pages anchored to it,
with anchors to inserted pages resolved in order. An anchor that no longer
exists is re-anchored to the nearest preceding base page, never dropped
silently.

Inserted pages are visible in the editor and in the read-only reader. The
reader gets their geometry (A4/current size) and draws the ruled/blank template
instead of requesting a native tile. This means a page inserted on Tuesday is
still there on Wednesday, before export.

### Annotation model

A sealed `PdfAnnotation` with a common envelope:

```
id, kind, page: PdfPageRef, rect: NormalizedRect,
colorValue, opacity, createdAt, updatedAt
```

Kinds:

- `highlight` — axis-aligned rectangle, `BlendMode.multiply`, opacity 0.30–0.45,
  stroke width 0.012–0.035 of page height. The drag is locked to the dominant
  axis: a mostly horizontal drag produces a horizontal band, a mostly vertical
  drag a vertical band. A drag under 8 logical pixels is discarded.
- `ink` — freehand points normalized to the page, stroke width and colour.
- `text` — text, font size 12–72 with presets 17/18/19/20/24/28/32, bold,
  italic, underline, alignment (`right`, `center`, `left`, `justify`), bullet
  mode, colour. The box auto-heights; dragging moves it; a corner handle
  resizes its width.
- `image` — a private asset file, aspect-fit into its rect, opacity.
- `emoji` — a glyph or short sticker string, size 24–72, rendered like text.
- `audio` — a private M4A/MP3 asset, duration, a speaker icon; tap plays,
  long-press offers play/share/delete.

Annotations are painted in creation order; new annotations go on top. Tapping
with the select tool hit-tests topmost-first. The eraser deletes the tapped
annotation in one undoable action. Text/images/audio can be dragged; highlight
and ink can be selected and deleted.

### Colour palette

A horizontal palette sheet with a check mark on the selected swatch, per the
brief. Highlighter and text keep separate remembered colours:

- Highlighter: yellow, green, pink, blue, orange.
- Text/ink: navy, black, goldDeep, red, blue, green, purple.
- The sheet shows the swatch, its Arabic name, and the check mark; no tiny
  unlabeled colour dots.

The highlighter is composed so the page shows through: the overlay painter uses
`BlendMode.multiply` for highlight rectangles, not an opaque fill. Text stays
dark and legible under the band.

### Toolbar

A floating vertical toolbar on the physical right edge, implemented with
`AnimatedPositioned` (the brief names it). Hidden, it sits mostly off-screen;
a persistent eye/chevron tab at the edge toggles it. Duration 220 ms,
`Curves.easeOutCubic`; reduced motion switches instantly.

Tools: select, highlighter, pen, text, eraser, insert, pages, palette, undo,
redo, export. Each is a 48×48 target with a tooltip and semantic label. The
toolbar scrolls if the viewport is too short (landscape), and never overlays the
page's own top chrome permanently.

The editor's page area uses the tiled viewport in single-page mode while a tool
is active, so a drag cannot be stolen by the scroll view. Pinch-zoom is
disabled while a tool is active; the toolbar has zoom ± buttons. Read mode
keeps the current pinch/scroll behaviour.

### Text options sheet

Bottom sheet, scrollable, with a live preview:

- size chips 17, 18, 19, 20, 24, 28, 32 plus a stepper for 12–72;
- alignment icons in RTL order (right, center, left, justify);
- bold / italic / underline toggles;
- bullet toggle, with a real `• ` prefix per line on commit;
- colour row with check marks;
- «تم» commits one undoable annotation; dismissing without changes creates
  nothing. Editing an existing text annotation reopens the same sheet and
  commits one undoable replacement.

### Insert menu

A 3-column sheet grid:

1. **تسجيل صوتي** — the same recorder sheet as the bag; the clip is saved under
   the document's annotation assets and an audio annotation is placed on the
   current page.
2. **صورة** — gallery picker; copy into annotation assets; place at 60% page
   width, aspect-fit.
3. **كاميرا** — camera capture; same path.
4. **مسح ضوئي** — camera capture with the existing scan flow's capture step;
   insert the captured image (no OCR is required for the annotation).
5. **ملف صوتي** — `file_picker` audio; validate it is playable, copy it into
   annotation assets, place an audio icon.
6. **رسم حر** — switches to the pen tool; the first stroke creates an ink
   annotation and the tool stays active for more strokes.
7. **ملصقات** — a grid of 24 emoji/stickers; insert as an emoji annotation at
   the page centre with a 32 pt default.

### Pages sheet

«إدراج صفحة» offers a count 1–10, a template (مسطرة / سادة), and «بعد الصفحة
الحالية». Each inserted page gets a stable id and a page ref. Deleting an
inserted page asks for confirmation, removes its annotations, and re-anchors
pages that were anchored to it. The page strip at the bottom shows base and
inserted pages with a small gold corner on inserted pages.

### Sidecar storage

```
support/pdf_annotations/<docId>.json
support/pdf_annotations/<docId>/<annotationId>.<ext>
```

Sidecar schema version 1:

```json
{
  "schema": 1,
  "docId": "…",
  "updatedAt": "2026-10-27T12:00:00.000Z",
  "insertedPages": [
    {
      "id": "p1",
      "after": {"kind": "base", "index": 3},
      "order": 1,
      "template": "ruled",
      "widthPoints": 595.28,
      "heightPoints": 841.89
    }
  ],
  "annotations": [
    {
      "id": "a1",
      "kind": "highlight",
      "page": {"kind": "base", "index": 3},
      "rect": {"left": 0.1, "top": 0.2, "width": 0.5, "height": 0.02},
      "color": 4291821568,
      "opacity": 0.35,
      "blend": "multiply",
      "strokeWidth": 0.02,
      "createdAt": "…",
      "updatedAt": "…"
    }
  ]
}
```

Rules:

- Writes are atomic (`*.tmp` then rename).
- Unknown kinds, missing assets, out-of-range rects and dangling page refs are
  tolerated on read; invalid values are clamped or dropped, never thrown into
  the UI.
- Autosave is debounced 400 ms; it also flushes on app pause/inactive and when
  the screen closes. A failed write leaves a visible «لم يتم حفظ التعديلات»
  banner and a retry action; the in-memory layer stays intact.
- Deleting a library document deletes its sidecar and asset folder. A startup
  sweep removes orphaned sidecars older than 7 days.
- Undo/redo keeps at least 50 steps in memory; redo is cleared by a new edit.

### Export

New `PdfExportService`:

1. Build the flattened output page list from base + inserted pages.
2. Rasterize text/emoji annotations on the UI isolate at 4× their point size
   with a transparent background (Flutter is the source of truth for Arabic
   shaping). Cap the raster to 2048 px per side.
3. In a background `Isolate.run`, load the base bytes with Syncfusion, create an
   output `PdfDocument`, copy each base page as a `PdfTemplate` into a page of
   the same size, insert generated pages for inserted refs, draw vector
   highlights/ink, place image/text/emoji bitmaps, and attach audio files with
   a speaker icon. The isolate receives only bytes/paths and a plain data
   description; it logs nothing.
4. Validate the output by loading it again and checking page count; write to
   `pdf_exports/<docId>/<timestamp>-<slug>.pdf` via a temp file and rename.
5. Return the output path. The UI offers «مشاركة», «فتح», and «حفظ في ملفاتي»
   (which adds a new library entry with `sourceDocId` and a suffix
   «— معدّل»). The original base file is never overwritten.

If the isolate fails, show a clear error and keep the sidecar. If the document
is larger than 200 MB or 500 pages, block with an explanation rather than
risking an OOM. Encrypted PDFs stay read-only; the editor is not offered because
the base bytes cannot be read without the password, and passwords are never
stored.

### Reader integration and auto-resume

`PdfReaderScreen` loads the sidecar, flattens pages, and paints read-only
annotations. `lastPage` becomes a display page index; it is clamped to the
flattened page count. Opening from «شنطتي» therefore resumes at the right page
even if pages were inserted. The reader's share menu offers «الأصل» and
«نسخة مع التعديلات»; the second runs the export path.

## Calculator

Keep every computation mode (COMP, CMPLX, STAT, BASE-N, EQN, MATRIX, TABLE,
VECTOR, GRAPH, CAS, FORMULAS, UNITS) and every command. Change only the shell:

- `CalcPalette.dark`: charcoal chassis `#1B1B1F`, panel `#232329`, dark LCD
  `#0E1512` with `#A8C8A8` text, SHIFT `#D4AF37`, ALPHA `#C0392B`, function
  keys teal `#0E7490`, number keys `#3A3A44`, operator keys `#1E3A5F`, equals
  `#D4AF37` with navy text.
- `CalcPalette.light`: a light instrument panel with the same semantic key
  colours, navy casing and gold equals; no teal brand accent.
- `CalcKeypad` body moves from seven hard-coded `Row`s to a `CustomScrollView`
  with a `SliverGrid` (5 columns, uniform `mainAxisExtent`, 4–6 dp gaps).
  `CalcKeyButton` remains the cell content, so SHIFT/ALPHA labels and haptics
  are unchanged. If the available height is too short, the grid scrolls rather
  than shrinking below a readable key height.
- The modifier strip (SHIFT, ALPHA, D-pad, ±, S⇔D, STO, RCL, M+, f(x)) stays
  above the grid and remains horizontally scrollable.
- The display keeps formula/history above the result and uses `FittedBox` for
  long expressions. Landscape keeps the side-by-side display/keypad layout.
- Add a visible `MODE` label/button in the modifier strip that opens the
  existing mode picker; the D-pad is the real four-way control, not decoration.

## Islamic dashboard

`/islam` becomes a standalone navy/gold screen. It keeps every existing tile
and route.

1. **Hero next-prayer card** (navy gradient, gold rule): prayer name, time,
   live countdown, location, Hijri date, and a thin progress line between the
   previous and next prayer. Tap opens `/prayer`.
2. **Five-prayer strip**: a horizontally scrollable bar of five chips (الفجر,
   الظهر, العصر, المغرب, العشاء). The next prayer is gold-filled; passed
   prayers are muted; a small clock marks «الآن». Tapping a chip opens the full
   prayer screen.
3. **Adhan card**: a switch bound to the existing `AdhanSettings`; a voice
   selector showing the current real voice; «جرب الأذان الآن» opens
   `AdhanPlaybackScreen` with the selected voice. A small «الإعدادات» link opens
   `AdhanSettingsScreen` for per-prayer choices, Fajr voice and exact-alarm
   status.
4. **Salat reminder card**: a switch bound to `AzkarSettings.salatEnabled`;
   interval chips from the existing `kSalatIntervals` (15/30/60 minutes); a
   phrase selector; a sound mode selector (voice / chime / silent); «اختبار
   التذكير» calls `NotificationService.showTestSalat` after permission;
   «تشغيل النموذج» plays the bundled human salat clip through the existing
   asset-capable `AdhanPlatform.playPreview('', assetPath: …)` path (the same
   path `salat_counter_screen.dart` already uses), not through the private-file
   `AudioPlayerChannel`. A link opens the full `AzkarSettingsScreen` for
   windows, phrase selection and vibration.

   The interval list stays 15/30/60. The scheduler has a hard 200-slot-per-day
   cap and a three-day horizon (`kSalatHorizonDays = 3`); a 5-minute all-day
   interval would silently stop at the cap around 16:40, and a 5/10-minute
   option would require a scheduler and notification-id redesign. Short
   intervals are therefore out of scope, not a hidden truncation. If they are
   ever added, the scheduler gets a shorter per-interval horizon and tests that
   prove no slot is silently dropped.
5. **Existing tools grid**: prayer times, adhan settings, qibla, morning/evening
   azkar, salat on the Prophet, tasbih, hifz, prayer log, adhan diagnostics and
   Quran. Every tile goes to the same route as today.

The first-open intro sheet is retained and rewritten for the dashboard. The
dashboard recomputes from `prayerDayProvider` and `prayerClockProvider`; it does
not call a network service and does not invent a location. With no location, the
hero shows «حدد موقعك» and opens the existing location flow.

Audio reliability: adhan playback/scheduling stays on the existing Android
foreground service and notification channels; salat reminders stay scheduled
through `flutter_local_notifications`. No Dart isolate is introduced. "Voice"
means a real bundled human clip, not a generated tone.

## Focus sessions

`FocusPreset` keeps its old enum names for stored-session compatibility and
gains the new choices. The picker shows:

| Preset | Duration |
| --- | --- |
| تركيز سريع | 5 min |
| تركيز قصير | 10 min |
| ساعة | 60 min |
| ساعتان | 120 min |
| 3 ساعات | 180 min |
| 10 ساعات | 600 min |
| من الصلاة للصلاة | live window |
| مدة مخصصة | 1–600 min |

The custom limit rises from 240 to 600 minutes. The preset picker is a
responsive `SliverGrid`/`Wrap`, not a fixed `Row`.

**Prayer-to-prayer.** Reads `prayerDayProvider`. If a location exists, the
session label is «من {previous} لل{next}» and the duration is
`next.time - now` (clamped to at least one minute). If no location exists, the
tile explains that location is needed and offers the existing location flow,
rather than showing a fake window. If the next prayer is tomorrow's Fajr, the
label uses the correct names and the session crosses midnight.

**Timer correctness.** `FocusSession` gains `endsAt` (absolute) and
`prayerWindowLabel`. Every session sets `endsAt` at start; the ticking UI
derives remaining time from `endsAt - now` on each tick and on app resume, so a
backgrounded app does not freeze or double-count. Standard presets set
`endsAt = startedAt + workMinutes`. The session persists in `LocalStore` and is
restored if the app is killed mid-session; a session whose `endsAt` has passed
is restored as finished, once, and its minutes are recorded once. Existing
short/medium/long stored sessions still load through `fromJson`.

The existing study-minutes and garden-points recording remains; a finished
session is recorded at most once per id. Breaks remain available but are not
part of the new preset labels.

## Salat recording — source and licence

The brief asks for a real human voice for the salat reminder. No recording of
the exact full phrase «اللهم صلِّ وسلِّم وزد وبارك على سيدنا محمد» was found
under a clear public-domain/CC0/CC-BY licence. Rejecting unlicensed MP3 sites is
part of the decision.

The bundled recording is:

- **Source:** Freesound, user `ibrahim_baig`, sound 788917, «Sale'ala'Muhammad
  صَلِّ عَلَىٰ مُحَمَّدٍ».
- **Licence:** CC0 1.0 (public-domain dedication).
- **File:** 2.187 s, MP3, 44.1 kHz, mono, about 52 KB.
- **URL:** https://freesound.org/people/ibrahim_baig/sounds/788917/
- **Bundled as:** `assets/salat/asal_ala_muhammad_ibrahim_baig.mp3` and the
  Android raw resource `salat_asal_ala_muhammad` (raw names must be
  lower-case/underscore).
- **Licence record:** update `assets/salat/LICENSES.md` with the source, licence,
  duration and the fact that the file is unmodified except for the copy/rename.

`SalatAudioCatalog` gains a built-in mapping for the first phrase
(`asal_ala_muhammad`): `notificationResourceFor` returns the raw resource and
`customAssetFor` returns the asset for preview. The other two phrases continue
to fall back to the existing chime/silent behaviour; the UI states «الصوت
البشري متاح لصيغة: صلِّ على محمد» and disables the voice mode for the other
phrases rather than playing the wrong words. A user-added asset with the
existing filename convention still takes precedence for preview.

`ensureSalatChannels` already creates a channel per phrase/sound combination;
the new raw resource makes the voice channel real. Because Android channel
sounds are immutable, the channel id already includes the phrase and vibration
state; no migration of an existing channel is attempted.

## Localization, RTL and accessibility

- The existing localization layer is kept exactly: `TrText` renders
  `AppLocalizations.t(data)`, and the **Arabic source string is the key**. There
  is no ARB/gen-l10n step. New static copy is added to `TrText` and its exact
  Arabic key is added to `assets/i18n/en_extra.json`; a missing English key
  falls back to Arabic by design.
- Interpolated copy uses the existing `context.trf('… {0} …', [value])` /
  shape-matching path, and `en_extra.json` must contain the matching `{0}`
  template (for example a count, a page number, or a duration). Do not build a
  dynamically concatenated Arabic string that has no template key; those are
  the strings that currently fall back to Arabic in English mode.
- `main.dart`'s `onGenerateTitle` uses
  `Localizations.of<AppLocalizations>(context, AppLocalizations)?.t('رفيق الطالب')`,
  so the title follows the active locale.
- English remains partial where the existing app is partial; the language
  dialog already says so. No new screen is Arabic-only by accident.
- Every new string is RTL-safe: no mirrored punctuation hacks, no `TextDirection`
  overrides on Arabic copy; mathematical and calculator surfaces stay LTR as
  today.
- Touch targets are at least 48×48; icon-only controls have tooltips and
  semantic labels; switches and toggles have `Semantics` labels.
- Colour is never the only signal: selected palette swatches show a check mark,
  next prayer shows a text label, pockets show counts and names.
- Text scaling is tested at 1.0/1.5/2.0. `MediaQuery.textScaler` is respected;
  no `textScaleFactor` clamping is used to hide overflow.

## Privacy, security and resource rules

- Everything stays on the device. No new network call, account, analytics or
  crash reporter.
- PDFs, sidecars, bag audio/images and links are in app-private storage. No
  public file URL. Sharing is always a user action through the system share
  sheet.
- Passwords are passed only to the native open call, never stored or logged.
  PDF text, annotation text, recording contents, link URLs and batch content are
  never logged.
- Audio/PDF assets are deleted with their owner; orphan sweeps are bounded and
  never delete a base PDF.
- Caps: 5,000 annotations per document, 100 inserted pages, 200 MB / 500 pages
  export guard; 100 voice clips per folder, 15 min each; 200 board images per
  folder; 100 links per folder; 25 images per compile.
- My Bag media is downscaled/compressed at import; the PDF tile cache stays at
  its existing budget. The editor repaints only visible pages and uses
  `RepaintBoundary` around page views.

## Testing and verification

CI already runs `flutter test`, `flutter analyze --no-fatal-infos`, and a
release APK build. Add tests that can run there:

**Pure Dart (runnable locally and in CI)**

- `pdf_annotation_codec_test.dart`: round-trip every annotation kind, unknown
  fields/kinds ignored, rect clamping, missing assets tolerated.
- `pdf_page_layout_test.dart`: insertions after base/inserted pages, before the
  first page, after the last page, deletion/re-anchoring.
- `my_bag_store_test.dart`: atomic index save/load, subject-folder seeding is
  idempotent, deleting a folder leaves PDFs, stale refs prune.
- `focus_session_test.dart`: new presets, 600-minute custom limit, prayer
  window duration, absolute `endsAt`, resume/expiry, old JSON compatibility.

These stay free of `package:flutter` imports so they run under the local ARM64
Dart SDK; a test that needs `dart:ui` moves to the group below.

**Flutter (CI only)**

- `theme_brand_test.dart`: navy/gold token values, 16 dp card radius, contrast
  pairs (`goldLight` on navy, `goldDeep` on white, white on navy, white on
  backpack red), and a source scan that fails on old teal hex in `lib/`.
- `pdf_export_test.dart`: a small generated base, one inserted page and a
  highlight/ink annotation; assert output page count, page order and that the
  original bytes are unchanged. `syncfusion_flutter_pdf` pulls in Flutter and
  `dart:ui`, so this cannot run under plain Dart even though it uses no widgets.

**Widget**

- `home_compact_test.dart`: 320/360/411/800 dp and 1.0/1.5/2.0 text; assert no
  exceptions, top bar height within the stated formula, all five tabs present,
  search hint present, old prayer block absent, all-tools entry present.
- `my_bag_test.dart`: folder grid, four pockets, empty states, no overflow.
- `islamic_dashboard_test.dart`: next-prayer card, five chips, adhan and salat
  switches, test buttons exist and are wired to fakes.
- `calculator_sliver_test.dart`: the keypad body is a `SliverGrid`, all 35 keys
  are reachable by scrolling at short heights, mode picker still works.
- `pdf_editor_toolbar_test.dart`: `AnimatedPositioned` hide/show, text sheet
  options, insert menu, palette check marks, no overflow at 320 dp.
- `focus_presets_test.dart`: all presets, custom dialog 1–600, prayer tile
  without location.

Update `test/widget_test.dart` to expect «رفيق الطالب» and the new primary.
Keep existing PDF/library/batch tests green; any test that asserted teal is
updated to the token, not deleted.

**Manual device checklist**

1. Cold start: native navy launch → Flutter splash with gold mark and credit,
   then home; no white flash.
2. All four appearances: text on white is navy, text on navy is white/gold,
   selected nav is readable, no teal remnants.
3. Home at 320 dp and 2.0× text: no overflow, top bar under 6% on an 800 dp
   screen, search opens AI, prayer pill opens `/islam`.
4. Bag: seed folders for the selected grade, add a PDF and resume its saved
   page, record/play/seek a voice clip, import/reorder boards and compile a
   PDF, add/open/delete a link, delete a folder and confirm PDFs remain.
5. PDF editor: hide/show toolbar with the eye tab, draw only horizontal and
   vertical highlighter bands that show text through them, add styled text with
   bullets, change colours, insert image/audio/emoji, insert ruled pages,
   background the app and reopen, export and verify page order/annotations in
   the exported file and that the original is untouched. Repeat with an
   encrypted PDF: read-only, no editor.
6. Calculator: all 12 modes still open; SHIFT/ALPHA labels; D-pad/MODE; grid
   scrolls in landscape; equals gold; no clipped digits.
7. `/islam`: next prayer/countdown/location/Hijri, five-prayer strip, adhan
   preview, salat test notification with the human clip, interval change
   reschedules.
8. Focus: 5/10/60/120/180/600, custom 600, prayer window label/duration, app
   background/resume, finish once and confirm minutes recorded once.
9. English mode: new screens show English strings where provided; the language
   dialog still states partial English. Arabic remains complete.
10. Airplane mode: all the above except the existing online AI/cloud features;
    no new network call appears.

## Phased delivery

1. **Brand foundation.** Theme tokens, four palettes, radius/shadow, global
   teal sweep, splash gate, Android launch/icon, shell nav labels/colours,
   brand/contrast tests. End state: app is navy/gold everywhere, no new
   feature yet.
2. **Home and shell.** Compact top bar, welcome/search, prayer pill, stats,
   bag preview, action cards, banners, daily tools, library shortcut, all-tools
   grid; remove the home prayer block and Islamic hub card. Widget tests.
3. **My Bag.** Models/store/controller, subject seeding, bag home, folder and
   pocket screens, PDF/voice/board/link flows, shared image-to-PDF builder,
   PDF entry subject tags, routes. Unit/widget tests.
4. **PDF annotation core and reader.** Models, codec, store, controller,
   flattened page layout, read-only overlay, virtual pages, auto-resume,
   encrypted read-only behaviour, undo/autosave. Unit tests.
5. **PDF editor and export.** Toolbar, text sheet, palette, insert menu, pages,
   assets, export service, share/save flows, editor tests.
6. **Islamic dashboard and focus.** Dashboard, adhan/salat cards and test
   actions, bundled CC0 clip/channel, focus presets and prayer sessions.
7. **Calculator and polish.** Casio palette, `SliverGrid` keypad, mode strip,
   responsive tests, localization, accessibility, full suite, manual checklist,
   docs/report.

Each phase ends with `dart format` on touched files, `dart analyze lib test`
(ARM64 local Dart), and the relevant tests. Flutter tests and the APK build are
reported only when CI actually ran them. No phase is declared done on a visual
claim alone.

## Decisions left to the builder

- Exact logo geometry and the Android vector paths; the splash timings may be
  trimmed but must stay within 1.2–1.8 s total and respect reduced motion.
- Exact heritage accent values for the seven feature categories, within the
  contrast rules and without reintroducing teal.
- Exact folder-card composition, icon choices, and whether the bag header shows
  all grade subjects or only non-empty folders (empty folders are shown with
  their pockets, per the empty-state rule).
- Exact text-size presets beyond 17/18/19/20 and the 4× raster scale, within the
  12–72 pt and 2048 px caps.
- Exact autosave debounce (400 ms stated), undo depth (at least 50), export
  temp naming and progress copy.
- Exact Arabic microcopy and English translations for the new screens; the
  existing language dialog remains the source of truth for partial English.
- Whether an exported copy is automatically saved into «ملفاتي» or only offered
  there (the export sheet must offer it explicitly; the original remains
  untouched either way).
- The precise salat clip filename casing on disk, provided the Android raw
  resource is lower-case/underscore and the licence record matches.

## Builder review — questions resolved

A cold builder read the draft and raised five points. All are settled; none
needs the product owner's input.

1. **Salat reminder intervals.** The draft offered 5/10 minutes, but the
   scheduler plans a fixed 200 notifications per day over a three-day
   horizon, so a short interval would silently run out before the evening
   and the user would miss reminders without any error. Kept the existing
   **15/30/60**-minute intervals. The scheduling budget stays honest, and the
   UI continues to reuse existing strings.
2. **My Bag grade scope.** The draft did not say what happens when the user
   changes grade. Folders are grouped by grade and the bag shows the current
   grade by default, with a grade filter that keeps every earlier folder —
   and its media — reachable. Seeding runs only for the active grade and is
   idempotent, so nothing is duplicated or orphaned.
3. **Salat preview playback.** `AudioPlayerChannel` only opens private file
   paths, so a bundled asset could not be previewed through it. The preview
   uses the already-shipped asset-capable path
   `AdhanPlatform.playPreview('', assetPath: …)` that the salat counter screen
   uses today. Notification playback still resolves the Android raw resource.
4. **Android SDK levels.** The draft pinned `minSdk 32` / `targetSdk 36`, but
   the repository commits no Gradle files; CI regenerates the Android project
   with `flutter create`, so the template's defaults are authoritative. The
   document now forbids adding a Gradle patch to pin them and requires a
   pre-26 legacy launcher icon plus a pre-31 launch background so the brand
   survives on whatever range CI generates.
5. **Export test classification.** The draft called `pdf_export_test.dart`
   pure Dart. `syncfusion_flutter_pdf` depends on Flutter and `dart:ui`, so
   the export test is CI-only. The testing section now separates genuinely
   Flutter-free tests (local and CI) from Flutter tests (CI only).

## Risks and documented limitations

- **Global sweep risk.** Some existing screens use the brand colour directly in
  `const` widgets, so the theme cannot adapt them. The chosen redefinition of
  `primary`/`primaryLight`/`primaryDark` keeps those gradients navy and
  legible; the explicit foreground migration list covers the cases that would
  go invisible. A source test catches old teal but not every aesthetic
  inconsistency; the manual four-theme pass is required.
- **Gold contrast.** Gold on white is a real accessibility failure. It is
  restricted to fills/icons and dark surfaces; small gold-family text on white
  uses `goldDeep`. The contrast test enforces the pairs, but new ad-hoc colours
  can still be introduced; the theme tokens are the only approved source.
- **PDF text export.** Arabic text annotations are rasterized at export so
  Flutter's shaping is preserved; the exported text is not selectable or
  searchable. This is a deliberate fidelity-over-vector trade-off. Highlights,
  ink and images stay vector/bitmap as described.
- **Page templates and existing PDF features.** Copying base pages as
  Syncfusion templates preserves visual content but can drop existing forms,
  links, bookmarks and some metadata. The original is never modified; the
  limitation is stated in the export sheet.
- **Audio annotations in other viewers.** An exported audio note is embedded as
  a PDF attachment with a speaker icon; many desktop/mobile viewers do not play
  attachments inline. In-app playback always works from the sidecar asset. The
  UI does not promise inline playback elsewhere.
- **Virtual pages.** Inserted pages are stored in the sidecar until export.
  They are visible in the app's reader/editor, but a raw share of the base file
  will not include them. The share sheet distinguishes «الأصل» from «نسخة مع
  التعديلات».
- **Salat phrase gap.** The bundled human clip is the exact first phrase only;
  the other two phrases use the chime/silent fallback and say so. No unlicensed
  audio is shipped.
- **Native resources in CI.** Launch/icon resources must survive
  `flutter create`; they are committed under `android/app/src/main/res` and the
  build is checked after CI regeneration.
- **Tests on this device.** The local ARM64 Dart can analyze and run the
  pure-Dart tests, but Flutter widget tests, the Syncfusion export test and
  Kotlin compilation are CI-only. No green result is claimed locally.
