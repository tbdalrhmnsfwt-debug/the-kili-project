# «أدوات الـ PDF» — PDF Reader Plus inside Zakerly — Design

**Date:** 2026-10-25
**Status:** Draft — awaiting user approval
**Approach:** A (native tiled renderer + Syncfusion writer), chosen by the user
**Scope decision:** an internal «ملفاتي» PDF library plus eight new tool cards,
inside the existing Arabic/Zakerly identity. No standalone app, no home-shell
replacement, no teal-theme replacement.

## Intent

The app already has an «أدوات الـ PDF» screen (`/pdf-tools`) with a basic
viewer, an OCR scanner, library-to-PDF exports, and a rasterising compressor.
The user wants that same section to carry the PDF Reader Plus feature set:
annotations, digital signature, merge, split, compression, password
protect/unlock, image-to-PDF, and print — all real, all on-device, all Arabic
RTL, all in the app's current visual language.

The source brief's audience (students annotating books, professionals signing
contracts, general readers) and its privacy rules apply. Core work must stay
offline and account-free. Passwords, document text, and signatures must never
be logged or persisted in plaintext.

## Goals

- Add a durable, local PDF library inside the PDF hub: import through the
  Android document picker, first-page thumbnails, Recent / All / Favorites,
  search, sort, grid/list, rename, delete, share, details, last-page restore.
- Replace the current preview-only reader with a real reader built for large
  documents: lazy page loading, bounded tile cache, continuous vertical and
  horizontal modes, pinch zoom to 500%, page jumper, scrubber, rotation,
  night mode, in-document search, password entry, graceful corrupt-file
  handling, print, share.
- Implement annotations that are created and edited over the page and
  **baked into a real output PDF** with Syncfusion: highlight, underline,
  strikethrough, freehand ink, sticky notes, eight-colour palette, stroke
  width, eraser, select/move/resize/delete, undo/redo, and crash-safe
  autosave of the annotation layer.
- Implement the complete signature journey: draw, clear, redraw, choose
  colour, reuse a securely stored signature, place/move/resize it on a page,
  bake it into a new PDF, keep the original, and share on request.
- Implement real Merge, Split, Compress, Password Protect, Unlock, and
  Image-to-PDF tools with input validation, output validation, progress, and
  explicit success/error reporting.
- Keep every existing PDF tool and output working. Fix the «تضغيم» label to
  «ضغط» while touching that grid.
- Preserve the app's Arabic RTL, Cairo typography, teal palette, spacing and
  card language. Add depth through the existing `ZakerGlassGlyph` /
  `ZakerPressScale` materials, not a new brand.

## Non-goals (explicitly out of this iteration)

- No standalone app, no new entry point, no change to the home shell or the
  four bottom tabs.
- No replacement of the teal identity with the source brief's blue/orange
  palette. The required annotation colours (yellow, green, pink, blue) live
  only in the annotation palette.
- No DOCX, XLSX, PPTX or text-document rendering/conversion. There is no
  compatible converter in the resolved offline stack; unsupported files are
  rejected with a clear Arabic explanation rather than presented as PDFs.
- No text-to-speech/auto-read and no reflow/text-mode reader in this
  iteration. The brief names them; they are documented limitations, not
  silently removed.
- No editing of the original PDF text. Annotations are a layer; exported ink
  and signature strokes are genuine vector content, but underlying text is
  never rewritten.
- No cloud, account, AI, analytics, ads, purchase, or network call.
- No new Android permissions and no `MANAGE_EXTERNAL_STORAGE` or whole-device
  scan. File access is SAF/picker only. Camera is requested at the moment the
  user chooses camera capture.
- No password storage, no document-text logging, no signature logging.

## Constraints and environment

- Flutter app `zaker_ai`, Arabic-first RTL, Riverpod 2.5.1, go_router 14.
- Resolved and cached packages only: `printing` 5.15.1 (raster/print),
  `syncfusion_flutter_pdf` 35.1.41 (text extraction with bounds, markup
  annotations, page templates, AES-128/256, decryption), `file_picker` 8.1.2,
  `image_picker` 1.2.4, `image` 4.12.0 (already resolved transitively; it
  becomes a direct dependency), `path_provider`, `shared_preferences`,
  `share_plus`, `pdf` 3.13.1, `url_launcher`, `path`, `crypto`.
- No pdfium/viewer plugin is in the offline cache. Adding one would break
  local `dart analyze` and depend on CI fetch. Approach A avoids that.
- `minSdk 32`, so `android.graphics.pdf.PdfRenderer` is available on every
  supported device. The CI builds Android only.
- Local verification uses `work/dartsdk/dart-sdk/bin/dart` (ARM64) for
  `dart analyze` / `dart format`. Flutter tests and Kotlin compilation happen
  only in CI. This design adds a CI `flutter test` step; without a push the
  suite is not executed here. No result will be claimed that was not run.
- Existing provider pattern: `StateNotifier` + `LocalStore` JSON persistence
  (see `appearance.dart`). Follow it.
- Existing visual vocabulary: `SectionHeader`, `FeatureTile`,
  `ZakerGlassGlyph`, `ZakerPressScale`, `EmptyState`, `LoadingBox`,
  `ZakerSkeleton`, `ZakerSpacing`, `ZakerRadius`, `TrText`.

## Approaches considered

1. **Native tiled renderer + Syncfusion writer (chosen).** Kotlin
   `PdfRenderer` renders clipped tiles at the requested zoom; Dart owns the
   cache, gestures, annotation layer, and UI. Syncfusion handles text
   extraction/search, annotation export, signatures, merge/split, compression
   validation, and AES encryption. No new packages or licences, fully offline,
   and tile-level crispness at 500%.
2. **`printing` raster + Syncfusion text map.** No Kotlin. But pages are
   rasterised whole, there is no tile-level zoom, large pages blow memory,
   and 500% crispness cannot be claimed. Rejected.
3. **Add `pdfrx` (pdfium).** Best viewer ergonomics, but not in the offline
   cache, breaks local analysis, relies on CI fetch, and grows the APK.
   Rejected for this environment.
4. **`syncfusion_flutter_pdfviewer`.** Fastest annotation UI, but needs a
   commercial licence key that the project does not have, and its
   freehand/export model does not cover the full brief. Rejected.

## Architecture

New module, keeping the existing routes and screen entry points working:

```
lib/features/pdf/
  pdf_hub_screen.dart          # the expanded /pdf-tools hub
  pdf_library_screen.dart      # Recent / All / Favorites, search/sort
  pdf_reader_screen.dart       # the new reader (route-compatible)
  annotation/
    annotation_controller.dart
    annotation_layer.dart
    selection_layer.dart
    annotation_toolbar.dart
  signature/
    signature_canvas_screen.dart
    signature_overlay.dart
  tools/
    merge_screen.dart
    split_screen.dart
    compress_screen.dart
    password_screen.dart
    image_to_pdf_screen.dart
    image_crop_editor.dart
  widgets/
    pdf_document_card.dart
    pdf_page_view.dart
    pdf_thumbnail.dart
    pdf_source_picker.dart
lib/models/
  pdf_document.dart          # library metadata
  pdf_annotation.dart        # annotation model + JSON
  pdf_signature.dart         # signature model + JSON
  pdf_settings.dart          # reader/tool preferences
lib/core/pdf/
  pdf_library_store.dart     # dirs, import, thumbnails, metadata
  pdf_render_channel.dart    # Dart side of zaker/pdf_render
  pdf_text_map.dart          # Syncfusion text lines / search
  pdf_writer.dart            # annotation bake, merge, split, decrypt
  pdf_security_service.dart  # protect/unlock; no storage
  pdf_signature_store.dart   # Keystore-sealed signatures
  pdf_image_pipeline.dart    # crop/rotate/filters, JPEG encode
  pdf_page_geometry.dart     # normalized <-> points, rotation, tiles
lib/providers/pdf_providers.dart
```

The old paths stay valid. `lib/features/tools/pdf_tools_screen.dart` re-exports
the new hub (or keeps a thin wrapper) so the router and any existing imports
continue to work. The same applies to `pdf_viewer_screen.dart`. `scan_screen.dart`
stays where it is and is still reachable from the hub.

Native side:

```
android/app/src/main/kotlin/com/zaker/zaker_ai/
  PdfRenderChannel.kt     # PdfRenderer + tile rendering + open/close
  PdfSecureChannel.kt     # Android Keystore seal/unseal for signatures
  PdfOpenWithChannel.kt   # ACTION_VIEW via a dedicated FileProvider (optional)
  MainActivity.kt         # register the channels
android/app/src/main/res/xml/pdf_file_paths.xml
```

Third-party documents are never handed a raw filesystem path from external
storage. An import is copied into app-private storage; a generated file is
created there. Share and open-with go through FileProvider/content URIs.

## Data and storage

All paths are under `path_provider` directories:

```
<app support>/pdf_library/<id>.pdf            # base copies — never mutated
<app support>/pdf_exports/<id>-<ts>.pdf       # baked exports (Save / Save a copy)
<app support>/pdf_annotations/<id>.json       # annotation sidecars
<app support>/pdf_signatures.bin              # Keystore-sealed signatures
<app cache>/pdf_thumbs/<id>.png               # regenerable thumbnails
<app cache>/pdf_secure_tmp/                   # session-decrypted temp files
```

- **Metadata only** goes in `LocalStore` under `pdf.library.v1`. Documents are
  never stored in SharedPreferences or a database.
- `PdfDocumentEntry`: `id`, `displayName`, `baseFileName`, `originalName`,
  `sizeBytes`, `pageCount` (nullable until the file is successfully opened —
  an encrypted import cannot be opened at import time), `addedAt`,
  `lastOpenedAt`, `lastPage`, `favorite`, `thumbnailFileName`,
  `annotationCount`, `source` (imported/generated), `encrypted`
  (unknown/yes/no), `exportedAt`.
- **The base file is immutable.** Annotations and signatures are never baked
  into the file the reader shows. The sidecar is the editable truth, and every
  export is generated afresh from *base + current layer*. That keeps exports
  idempotent (no double-markup on the second Save) and keeps on-screen
  highlights reliable: Android's `PdfRenderer` paints page content, not PDF
  annotation objects, so a baked working copy would visibly lose its text
  markup in-app. A baked PDF exists only as an export (`pdf_exports/`) or as
  the target of Share/Print and the file tools.
- `PdfLibraryController` (`StateNotifierProvider`) loads metadata, verifies
  files exist (pruning missing entries with a user-visible notice), exposes
  `isIndexing`/progress, and persists changes. It never deletes an external
  source file.
- Import: `FilePicker.pickFiles(type: custom, extensions: ['pdf'],
  allowMultiple: true, withReadStream: true)`. Stream to app storage in
  chunks, validate the `%PDF-` header, and avoid loading the whole file into
  memory. If the picker only supplies a cached `path`, copy it. Duplicate
  content is allowed but the UI marks the likely duplicate by name/size.
- Thumbnails: native render of page 1 at thumbnail scale, written as PNG.
  Generated lazily and on demand; a missing/corrupt thumbnail falls back to a
  PDF glyph. Clearing thumbnails never touches documents.
- Annotation sidecars: JSON, app-private, written debounced (400 ms) and on
  `AppLifecycleState.inactive/paused` and before leaving the reader. They are
  never logged. Notes live here; signature coordinates are included but the
  signature *image/path library* is encrypted separately.
- Decrypted temp files: created only for encrypted documents, named with a
  random id (never the password), deleted in `finally` and swept at startup.
  A decrypted copy is **never** promoted to the base file: the library keeps
  the encrypted original, and each open asks for the password again. That is
  slower on repeat opens and deliberately so — the brief forbids storing
  passwords, and keeping a permanently decrypted copy would defeat the
  protection the user asked for.
- Import of an encrypted PDF does not prompt. The cheap `%PDF` /`/Encrypt`
  scan marks the entry `encrypted: yes`, `pageCount: null`, with a lock glyph
  as its thumbnail; the page count and real thumbnail are filled in on the
  first successful unlock (session metadata only, not persisted secrets), and
  the card/Details state says so until then.
- Reader state (`lastPage`, zoom, scroll direction, night mode, rotation) is
  persisted per entry, debounced. Restore on reopen.

## File picker and library UX

The hub keeps `/pdf-tools` and «أدوات الـ PDF», and opens on the tools grid
(current behaviour). Above it, a «ملفاتي» section shows up to six recent
documents as compact cards plus «عرض الكل»; below the grid, the existing
«ورقاتك» outputs remain.

`PdfLibraryScreen` owns the full catalog with the brief's order:
**الحديثة → كل الملفات → المفضلة**, implemented as a TabBar inside the PDF
hub flow (not the app's main navigation). It offers search by name, sort by
name/date/size (asc/desc), a grid/list toggle, import, and an empty state with
an import action and an explanation of private app storage.

Document card/tile: 48×64 dp thumbnail with 8 dp radius, two-line ellipsized
name, size and modified/added date in secondary text, favorite marker, and a
three-dot menu with **إعادة تسمية، حذف، مشاركة، تفاصيل**. Delete always asks,
names the file, and explains that only the app's copy is removed and the
original on the device is untouched. Details shows name, page count, size,
dates, source, annotation count, favourite state, encryption state, and the
same explanation; it never shows a password.

If the library file disappears (external cleanup, restored backup), the entry
is marked unavailable, the card explains it, and the user can remove the entry
or re-import. No crash.

## Reader

`PdfReaderScreen` replaces the `PdfPreview` body. The route
`/pdf-viewer?path=...&title=...` still works, and gains optional
`docId` and `mode=read|annotate|sign`.

### Rendering and tiles

- A native `PdfRenderer` is opened per document (or per decrypted temp copy).
  Page sizes in points come from the renderer.
- **Zoom is a multiple of fit-width.** `fitScale` is the scale that makes a
  page exactly viewport-wide; the visible zoom factor runs `1.0`–`5.0`, where
  `1.0` is fit-width and `5.0` is 500% of fit-width (the brief's "pinch to
  500%"). Flutter lays pages out at `pagePoints * fitScale * zoom` logical
  pixels. A shared viewport controller tracks vertical scroll, horizontal
  scroll, viewport size, and zoom. For each visible page, the reader asks the
  native side for a tile covering the visible region plus a prefetch margin,
  in page coordinates, at `zoom * fitScale * devicePixelRatio` (capped by a
  pixel budget). Every acceptance figure — 500%, cache budgets, double-tap —
  is relative to fit-width, so it is measurable on any screen size.
- The native renderer creates an ARGB_8888 bitmap for the requested region,
  sets a scale/translate matrix, renders the page with `RENDER_MODE_FOR_DISPLAY`,
  returns PNG bytes, and recycles the bitmap. Pages and the renderer are
  closed deterministically; a single renderer lock prevents concurrent page
  rendering.
- The Dart cache is an LRU of tiles keyed by page + scale bucket + source
  rect, budgeted (e.g. 96 MB, configurable internally), with a strict
  current ±1 page focus for full-page requests and eviction of old scales on
  zoom changes. Requests are generation-tagged; stale results are dropped.
  On memory pressure, drop non-visible tiles first. The previous scale's tile
  stays visible (scaled) until the crisp tile arrives to avoid blank pages.
- Continuous vertical mode: a horizontal `SingleChildScrollView` (only active
  when zoom > fit) wraps a vertical lazy list of pages with known heights.
  Horizontal/page-by-page mode: a `PageView` with the same tile renderer.
  The mode is a persisted setting.
- Pinch updates zoom continuously (clamped 1.0–5.0 relative to fit-width);
  tiles re-request at the settled scale. Double-tap toggles 1.0 ↔ 2.5.
  Panning is native scrolling. The default is 1.0 (fit-width).
- Rotation: quarter turns applied to layout and painting; the source rect for
  a tile is the inverse rotation of the viewport (pure geometry, unit-tested).
  Orientation lock is an explicit toggle; the document rotation is persisted.

### Chrome and navigation

- Auto-hiding top bar on tap: back, document name (two lines, ellipsized),
  search, favorite, night mode. Hides while reading/scrolling, reappears on
  tap. A three-dot menu holds print, share, details, rotation lock, scroll
  direction, cache size, and "clear cache".
- Bottom page scrubber: slider with «صفحة X من Y», a page-jump dialog, and
  drag-to-page. Page numbers are logical (1-based).
- Thumb-reachable floating actions: annotations, signature, rotate, print,
  and save (when dirty). In annotation mode, a bottom toolbar with the tools
  replaces the floating rail.
- Night mode: an in-app colour transform over rendered tiles (dim/warm/
  invert option), never applied to the source file. Default from settings.
- At 500% the chrome must not crowd the page; controls auto-hide and respect
  large text scale and 48 dp targets.

### Search

- Tap search opens a bottom sheet with an input and results list (page number
  + snippet). Search uses Syncfusion `PdfTextExtractor.findText` on the
  current document. Scanned/image-only pages return no results; the sheet says
  so instead of pretending.
- Tapping a result jumps to that page and paints temporary match highlights.
- Extraction runs page-by-page with yields between pages so the UI remains
  responsive. Extracted text is held in memory only, never persisted or
  logged.

### Passwords, corruption, and unsupported files

- On open, try without a password. If the file is encrypted:
  - First try an empty password (permissions-only encryption).
  - Otherwise show a secure password dialog with retry and cancel.
  - On success, create a decrypted temp copy for the native renderer and text
    extraction, then open it. The password stays in memory for the session,
    is never logged, written, or put in a filename, and temp files are
    deleted on close.
  - Wrong passwords show «كلمة السر مش صح — جرّب تاني» and allow another try.
    After three attempts the screen offers retry/cancel/share/open-with.
- Corrupt/unreadable files show «تعذّر فتح الملف» with retry, open-with,
  share, and remove-from-library where appropriate. No crash, no fake pages.
- Unsupported non-PDF inputs are rejected at import with a clear Arabic
  message. A PDF that cannot be rendered by the device engine also offers
  open-with.

### Reader actions

- **Save:** bakes *base + the whole current layer* into
  `pdf_exports/<id>-<ts>.pdf`, validates it by reopening, records
  `exportedAt` and the layer revision on the sidecar, and offers share/open.
  The original base is untouched and the layer stays editable, so the next
  Save simply re-bakes from the same base — no stacked markup, no lost layer.
  The banner then reads «التعليقات اتحفظت في نسخة PDF» with a link to that
  export. **Save a copy:** the same bake, but added as a separate library
  entry with an empty sidecar — a clean annotated file to hand over; the
  current document (base + layer) is unchanged.
- Unsaved changes show a persistent, non-blocking banner and are never lost
  when leaving: the sidecar restores them on reopen.
- **Print:** `Printing.layoutPdf` from the selected file (decrypted in memory
  if needed).
- **Share:** explicit only, through the share sheet with a content URI.
- **Favorite:** toggled in the top bar and reflected in the library.
- **TTS/reflow:** out of scope; no no-op controls are shown.

### Opening documents outside the library

The existing entry points must keep working:

- `/pdf-viewer?path=...` is used for official books and other files outside
  `pdf_library`, and `PdfViewerScreen(bytes: ...)` is constructed directly by
  `subject_screen.dart`. Both still open the new reader.
- In-memory bytes are materialised to `<cache>/pdf_session_tmp/<random>.pdf`
  for the native renderer and deleted when the reader closes (swept at
  startup if a crash left one behind).
- These documents are **transient**: fully readable, searchable, printable and
  shareable, but not annotatable and not listed in «ملفاتي». An official book
  is never silently copied into the user's library. A prominent
  «أضف لملفاتي» action imports a copy and switches the same reader session to
  the full mode (annotations, signature, last page, favorites).
- A library document opened by `docId` gets the full feature set. `path` and
  `bytes` stay transient unless they resolve to a library entry.

This preserves today's behaviour exactly, while making the richer mode one tap
away.

## Annotations

- Text selection is word/glyph-based from Syncfusion `TextLine` /
  `TextWord` / glyph bounds, mapped through `PdfPageGeometry` to normalized
  page coordinates. Drag to extend; handles adjust selection; in RTL the
  logical word order comes from the extractor.
- Tools: highlight, underline, strikethrough, pen (freehand), sticky note,
  eraser. Selection toolbar offers the 8 colours and stroke width.
- Palette (8): yellow `#FFEB3B`, green `#00E676`, pink `#FF4081`, blue
  `#40C4FF`, orange `#FF6D00`, red, purple, and black. Colour is saved per
  annotation.
- Freehand ink is captured as normalized vector points (smoothed), drawn
  live in a `CustomPainter`, and stored as paths. Eraser removes strokes it
  crosses; an undo/redo stack covers add/move/edit/delete for the session.
- Sticky note: tap the note tool then the page, type/edit text in a dialog;
  a visible marker is drawn at the normalized anchor. Notes are movable.
- Existing annotations can be selected, moved, resized (sticky notes and
  signatures; text markup moves as a group), edited (colour/note), and
  deleted. The selected annotation gets a clear outline and handles.
- Coordinates are normalized to the unrotated page, so zoom, rotation,
  scrolling and page-mode changes never drift. `PdfPageGeometry` owns the
  conversions and is covered by pure-Dart tests.
- Autosave: sidecar JSON, debounced and on lifecycle changes. Distinguish in
  the UI between "layer saved in the app" and "exported into a PDF";
  the banner says exactly which state the work is in.
- Export (`PdfWriter`):
  - Highlight/underline/strikethrough → genuine `PdfTextMarkupAnnotation`
    objects with `boundsCollection`, colour, author, modified date.
  - Freehand/signature → smooth `PdfPath` strokes drawn with `PdfPen` into
    the page content as vectors.
  - Sticky notes → `PdfPopupAnnotation` with the note text, anchored at the
    marker bounds.
  - The export reopens the source with the session password when needed, so
    an encrypted source stays encrypted in the saved output (same password).
    If that fails, the tool says so; it never silently produces a different
    security state.
  - Every export is built from the base document plus the full current layer,
    never from a previous export, so repeating Save cannot stack markup twice.
    Exporting opens the base in Syncfusion and writes into it, which is also
    what preserves any annotations the original file already carried.
- Undo/redo applies to the in-app layer. Exported output is validated by
  reopening and checking page count; success is not claimed otherwise.

## Signature

- A dedicated full-screen canvas: finger/stylus strokes, smoothing, colour
  choice, thickness, clear, undo, and a review step before saving.
- Saved signatures are serialized as normalized vector paths and sealed with
  an Android Keystore AES/GCM key (`PdfSecureChannel`); only ciphertext is
  kept in app-private storage. If the Keystore is unavailable, saving a
  reusable signature is refused with an explanation rather than falling back
  to plaintext. Nothing is logged.
- The signature picker lets the user draw a new one or reuse a stored one
  (with a delete action). No signature is exposed to other apps without an
  explicit share/export.
- Placement: a movable, resizable overlay with a clear selected state and
  corner handle; position is stored normalized. Multiple signatures can be
  placed; each is independently selectable/deletable.
- Save bakes the signature paths into a new PDF with `PdfWriter`, preserves
  the source, validates the output, and offers share. The contract journey
  (open → sign → draw → place/size → save → share) is a single tested flow.

## Tools

Every tool that reads a document with annotations or placed signatures shows a
guard sheet first: «فيه تعليقات/توقيعات — تحب نصدّرها مع الملف؟» with
**صدّر الأول** (default: bake, then continue on the baked copy),
**كمّل من غيرها** (with an explicit warning that the output will not contain
them), and cancel. Documents without a layer skip the sheet silently. This one
rule covers Merge, Split, Compress, Protect, Unlock, Print, and Share, so
annotations are never dropped without a visible choice, and no tool needs a
sidecar-remapping subsystem.

Encrypted inputs prompt for the password when the file is selected and are
processed from a session temp copy. Compress decrypts first explicitly —
`Printing.raster` takes bytes and knows nothing about passwords.

### Merge
- Sources: multi-select from «ملفاتي» and/or device picker; imports happen
  first. Show the ordered list with explicit up/down controls (RTL-safe),
  page counts, and total. Encrypted sources ask for a password per file.
- Output: new library entry, page count = sum, validated by reopening.
  Sources are preserved. Errors name the failing file without logging content.

### Split
- Load a document, render a lazy thumbnail grid, and allow page selection
  (tap) plus range input (`1-3,5,8-10`, validated). Modes: extract selection
  into one PDF, split every N pages, or one file per page.
- Outputs are named from the source base and range, added to the library,
  validated (page counts), and the source is preserved.

### Compress
- Presets for image resolution (144/96/72 dpi) and JPEG quality (85/70/50).
  Warn that text/vector-only PDFs may not shrink and that rasterising
  flattens text and annotations.
- Rasterise page-by-page with `Printing.raster`, encode JPEG with `image`,
  rebuild a valid PDF at the original page sizes with `pdf`, compare sizes.
  If the result is not smaller, keep the source and say so.
- Guard large inputs (documented page/size cap) with a clear message instead
  of an OOM. Output is validated by reopening before reporting success.

### Password protect and unlock
- Protect: pick a PDF, enter and confirm a password in secure fields, choose
  AES-128 (default, as named in the brief) or AES-256, show a warning that a
  lost password may make the file unrecoverable. The password is used in
  memory only. Output is a new entry; validate by reopening with the password
  and checking the reported algorithm. Permissions are set explicitly
  (allow print/copy/annotations/accessibility; disallow structural edits).
- Unlock: prompt securely, try an empty password first, then the entered one;
  write a decrypted copy by copying pages into a fresh document, validate it
  opens with no password, and add it to the library. No password is stored or
  logged. Accept that page-template copying drops interactive forms/links;
  the UI warns that the decrypted copy is a flattened copy.

### Image to PDF
- Multi-select from the gallery or capture with the camera (permission
  requested at use; denial leaves gallery import available).
- Per-image crop (draggable rectangle), rotation, and previewable filters:
  **أبيض وأسود**, **ألوان ساحرة (Magic Color)**, **رمادي**. Filters are
  applied to the actual exported image, not just the preview.
- Reorder pages, set the output name, create a valid multi-page A4 PDF, add
  it to the library, and offer open/share. Process images one at a time with
  bounded memory; failures name the image and do not leave a partial entry.
- Keep the existing OCR «المسح الضوئي» screen reachable and unchanged in
  behaviour.

### Print and share
- Print from the reader toolbar and from a tool card. Share from file menus
  and after save/sign. Use content URIs with temporary read grants; share
  only after an explicit action. If work is unsaved, prompt to save first.

## Hub and visual system

- New cards, in a responsive 2-column (phone) / 3-column (wide) grid using
  the existing `FeatureTile`:
  - «قراءة وتعديل»: اعرض PDF، تعليقات وملاحظات، توقيع رقمي، طباعة.
  - «تنظيم الملفات»: دمج ملفات، تقسيم الصفحات، ضغط الملف، حماية بكلمة سر،
    إزالة الحماية.
  - «إنشاء»: PDF من صور، المسح الضوئي، PDF بالحل، PDF منسق، PDF أسئلة بس.
- The existing «طباعة» card keeps its current behaviour — printing the bundled
  formatted book via `_exportBook(print: true)`. Printing an arbitrary PDF
  lives in the reader's top bar and in each file's menu, so the card's
  meaning does not quietly change and the current feature survives.
- Keep the current «ورقاتك» list and `_saveOutput` behaviour for generated
  library sheets. Keep the existing OCR entry point.
- Every screen reuses `ZakerSpacing`, `ZakerRadius`, `ZakerColors`/palette,
  `SectionHeader`, `FeatureTile`, `EmptyState`, `LoadingBox`,
  `ZakerSkeleton`, `ZakerGlassGlyph`, `ZakerPressScale`, and `TrText`.
- Arabic RTL first; all new user-visible strings are Arabic and go through
  `TrText`, with English additions in `assets/i18n/en.json` where practical.
- Subtle depth only: existing glass glyphs, 12–14 dp card radii, soft borders,
  restrained press/scale and fade transitions. No effect distorts page
  content; reader chrome may use a translucent surface but page pixels stay
  faithful.
- Reduced motion (`MediaQuery.disableAnimations`) is respected. Touch targets
  are ≥48 dp; icon-only controls have Semantics labels/tooltips.
- Loading, empty, error and permission-denied states are designed for the
  library, reader, each tool, and each export.
- Settings inside the PDF hub: default scroll direction, night default,
  orientation lock, haptics, reindex, and a safe **مسح الكاش** that removes
  only thumbnails/decrypted temp files and explains exactly what is removed.

## Performance and resource rules

- Never render a full page at 500% when only a viewport is visible; render
  viewport tiles with prefetch margins and a pixel cap.
- Cache budget is bounded and configurable; current ±1 page priority; stale
  requests are cancelled; old zoom scales are evicted.
- Lightweight page placeholders keep scrolling smooth before tiles arrive.
- `PdfRenderer`, `PdfRenderer.Page`, `PdfDocument`, temp files, and text
  extractors are closed/disposed in `finally` or `dispose()`.
- Text extraction and PDF writing run off the UI thread where the platform
  permits; otherwise they are chunked with yields and progress UI.
- Large operations (merge/split/compress/encrypt) run one at a time, show
  progress, and disable duplicate starts. No operation silently drops pages.
- Long operations are cancellable where it is safe (before writing the final
  file); a cancelled operation deletes partial output.

## Privacy and security

- No document text, note content, password, signature data, or document path
  is written to logs, crash messages, analytics, or filenames. Errors are
  generic.
- No network access is added. Core features work offline and without an
  account.
- Passwords exist only in memory for the duration of an operation; they are
  never persisted, never in `LocalStore`, never in temp names, and never in
  the share sheet.
- Signature at rest is Keystore-sealed ciphertext. Annotations/notes live in
  app-private storage and are not exported except when the user saves/shares
  the PDF.
- Imports are copies in app-private storage. The original external file is
  never modified or deleted. No broad storage permission is requested.
- Share/open-with uses content URIs and temporary grants; the user initiates
  every share.
- Deleting a library entry removes only the app's base copy, sidecar, exports,
  and thumbnail; it says so and asks first.

## Error handling

A `PdfFailure` enum/code plus Arabic message mapping:
`missingFile`, `corrupt`, `encrypted`, `wrongPassword`, `unsupported`,
`storageFull`, `renderFailed`, `textUnavailable`, `channelUnavailable`,
`cancelled`, `validationFailed`. Every tool returns a result object, shows a
clear error, and never reports success without reopening/validating the
output. On a missing native channel (tests/previews), the reader shows a
graceful message; library/tools that do not need rendering still work.

## Testing and verification

**Runs locally now (ARM64 Dart):**
- `dart format --output=none --set-exit-if-changed` on touched files.
- `dart analyze --fatal-infos` over the package.
- `dart run tool/verify_pdf_logic.dart` — a pure-Dart assertion script for:
  normalized↔point conversion, rotation mapping, tile/source-rect math,
  page-range parsing, annotation/signature JSON round-trips, merge ordering,
  size/date formatting, search-snippet/temporary-highlight math, and
  duplicate/edge cases. No Flutter or platform imports.

**CI (cannot be run locally):**
- Add `flutter test` before the APK build. Tests:
  - library controller with `LocalStore.memory()` and temp directories:
    import metadata, missing-file prune, rename/delete, favorites, sort,
    last-page restore, corrupt metadata fallback.
  - annotation controller: add/undo/redo/move/delete, normalized coordinates,
    sidecar restore.
  - page geometry: rotation/zoom invariance; range parser.
  - merge/split ordering and validation with generated PDFs (Syncfusion).
  - signature JSON sealing interface with a fake channel; refusal when
    unavailable.
  - widget tests: hub cards, empty/loading/error states, password dialog,
    annotation toolbar, save banner; reader with a fake renderer.
- `flutter build apk --release` compiles Kotlin and packages the app.
- A manual device checklist (normal/large/encrypted/corrupt/scanned PDFs,
  camera denial, share targets) is documented. It is not claimed as executed
  unless it is.

**Not available here:** a 500 MB fixture/device stress run. The bounded cache
and guards are designed for it; the result is unverified and will be reported
as such.

## Phased delivery

1. **Foundation:** module skeleton, models, `PdfLibraryController`, storage
   dirs, import/thumbnail pipeline, hub shell, route compatibility.
2. **Render engine:** native channel (open/render/close), tile cache,
   `PdfPageView`, vertical/horizontal reader, zoom, page nav, rotation,
   night, lifecycle save.
3. **Text and search:** `PdfTextMap`, search sheet, selection geometry.
4. **Annotations:** tools, palette, ink/notes, selection/move/resize, undo,
   sidecar autosave, `PdfWriter` export, save/save-copy.
5. **Signature:** canvas, Keystore sealing, placement, export, share.
6. **File tools:** merge, split, compress, protect/unlock, print/share,
   rename/delete/details.
7. **Image to PDF:** gallery/camera, crop/rotate/filters, reorder, output.
8. **Polish and verification:** settings, cache clear, empty/error states,
   RTL/accessibility, tests, CI test step, documentation of limitations.

Each phase ends with format + analyze (and the pure-Dart verifier where it
applies). Nothing is reported as passing unless it actually ran.

## Decisions left to the builder

- Exact Arabic microcopy, icons, and the order of cards inside each group.
- Whether the hub's recent strip is horizontal cards or a compact two-column
  grid; keep the 48×64 thumbnail and the three-dot menu.
- Exact tile sizes, prefetch margins, cache MB, and scale buckets within the
  budgets above.
- Exact compression presets and the page/size guard threshold, chosen so the
  device fails gracefully rather than OOMs.
- The 8th annotation colour after the four required plus orange/red/purple.
- The crop editor's handle styling and whether crop is a separate screen or a
  sheet, as long as it is previewable and applied on export.
- Whether "open with" is offered through a dedicated FileProvider or omitted
  where the share sheet is sufficient.
- Whether to put the PDF settings in a sheet from the hub or mirror them in
  the app's main Settings screen; the hub sheet is the minimum.

## Builder review — questions resolved

A cold builder review of this document surfaced seven ambiguities. All were
settled here rather than left open:

1. **Zoom scale.** `1.0`–`5.0` is measured against fit-width, not PDF points,
   so the default sits inside the range and "500%" is screen-independent.
2. **Non-library opens.** Official books and raw bytes open transient
   (read/search/print/share, no annotation, not in «ملفاتي») with an
   «أضف لملفاتي» upgrade action.
3. **State after Save.** The base file never changes; exports are always
   base + current layer, so saves are idempotent and on-screen markup stays
   trustworthy. Save a copy is a separate, clean library entry.
4. **Tools and unsaved layers.** One shared guard sheet offers bake-first
   (default) or an explicit continue-without, before every tool.
5. **Encrypted files.** Import does not prompt; page count is unknown until
   first unlock; decrypted copies are session temp only, never persisted.
6. **Pre-existing annotations/forms/links.** Page content only, plus a
   read-only overlay for annotation bounds where available; forms and links
   are a documented limitation.
7. **The «طباعة» card.** Keeps printing the bundled formatted book; printing
   an arbitrary PDF lives in the reader and file menus.

## Risks and documented limitations

- Native tile rendering and Syncfusion text bounds must agree on origin and
  page rotation; `PdfPageGeometry` plus tests mitigate this, and device
  acceptance is required. Text selection is word/glyph-based, not a native
  text-selection widget.
- Android's `PdfRenderer` paints page content only: annotations, form fields,
  links and bookmarks that already exist in an imported file are not
  interactive in the reader. Text markup and note markers whose bounds the
  Syncfusion pass exposes are drawn read-only over the page; form widgets and
  link targets are not. A textbook highlighted on another device can therefore
  look plainer here than in a desktop viewer. Save writes into the original
  document, so the file's own annotations survive in the export; merge, split
  and decrypt copy pages and do not carry them.
- Syncfusion decryption may not support every encryption flavour; unsupported
  files get a clear error.
- Page-template copying for merge/split/decrypt preserves visual content but
  can drop interactive forms, links, bookmarks, pre-existing annotations, and
  some metadata. This is stated in the UI where it matters.
- Compression rasterises, flattening text and existing annotations; text-only
  PDFs may not shrink. Large inputs are guarded.
- The Kotlin channel compiles only in CI; a local typo will surface there.
- TTS/auto-read, reflow, Office formats, and cloud are not implemented in
  this iteration and are shown nowhere as working controls.
