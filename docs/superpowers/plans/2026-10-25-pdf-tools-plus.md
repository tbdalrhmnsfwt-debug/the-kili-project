# PDF Reader Plus — Plan 1: Library + Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the existing «أدوات الـ PDF» section a real on-device PDF library and a tiled, zoomable, searchable reader, with the current routes and screens still working.

**Architecture:** A pure-Dart library layer (models, index, file store, page geometry, tile cache) that is verifiable without Flutter; a Kotlin `PdfRenderer` MethodChannel for clipped tile rendering; a Flutter reader that lays pages out itself and overlays chrome. Syncfusion is used only for text extraction/search in this plan. The existing `PdfViewerScreen` becomes a thin adapter so every current call site keeps working.

**Tech Stack:** Flutter 3.x (project SDK at `vendor/flutter`), Riverpod 2.5.1, go_router 14, `file_picker` 8.1.2, `syncfusion_flutter_pdf` 35.1.41, `printing`, `share_plus`, `path_provider`, `path`. Android `android.graphics.pdf.PdfRenderer` (minSdk 32) via Kotlin.

**Spec:** `docs/superpowers/specs/2026-10-25-pdf-tools-plus-design.md`

## Scope: this is Plan 1 of 4

The design covers four subsystems. Each ships working software and gets its own plan, in this order:

1. **This plan — library + reader + search.** Import, thumbnails, catalog, native tiled reader, zoom/rotation/night, in-document search, last-page restore. Ships a usable PDF reader.
2. Annotations + signature + export (`PdfWriter`), building on the reader.
3. File tools: merge, split, compress, protect/unlock, print/share flows, file actions.
4. Image-to-PDF (gallery/camera, crop/rotate/filters).

Do not implement later plans' features here, but do not block them: the models, store paths, and reader hooks below are shaped for them.

## Global Constraints

- **No new dependencies.** Use only what `pubspec.yaml` already declares. `image` becomes a direct dependency only in Plan 4.
- **No new Android permissions.** File access is SAF/picker only. No `MANAGE_EXTERNAL_STORAGE`. Camera stays untouched in this plan.
- **Privacy:** never log document text, file paths of user documents, passwords, or note content. Errors are generic. Passwords live in memory only, are never written to `LocalStore`, filenames, or the share sheet.
- **Arabic RTL, teal identity.** Every user-visible string goes through `TrText` with the Arabic source. Use `ZakerColors`/palette, `ZakerSpacing`, `ZakerRadius`, `SectionHeader`, `FeatureTile`, `EmptyState`, `LoadingBox`; no new palette or font. Directional padding via `EdgeInsetsDirectional`.
- **Keep existing behaviour:** `/pdf-tools`, `/pdf-viewer?path=`, `PdfViewerScreen(bytes:)` (used by `subject_screen.dart`), `/scan`, all current hub cards and `_saveOutput` outputs keep working.
- **`minSdk 32`.** Kotlin compiles only in CI.
- **Never claim an unrun check passed.** Local checks are `dart analyze`, `dart format`, and `tool/verify_pdf_library.dart`. `flutter test` and the APK build run in CI only.
- Commands below define:
  - `DART=/data/data/com.termux/files/home/the-kili-project/work/dartsdk/dart-sdk/bin/dart`
  - `cd /data/data/com.termux/files/home/the-kili-project/replica_src`
- Commits: one per task, message given in the task. Do not push.

## Review Focus

Inputs/conditions the spec implies but no task naturally tests; each is pinned to a test in its owning task.

1. **A library file deleted outside the app** (cleaner, restore) — the entry must survive as "unavailable" with a remove/re-import path, never a crash. Test in Task 6 and Task 7.
2. **A corrupt or truncated PDF chosen for import** — rejected before it enters the library, no half-written entry. Test in Task 3.
3. **A huge page at 5× zoom** — the requested tile source must stay inside the page and the pixel budget must cap the bitmap. Test in Task 2 and Task 9.
4. **Repeated wrong passwords** — the dialog returns with a clear Arabic error, no crash, no password leaked into the error. Test in Task 8.
5. **A scanned PDF with no text layer searched** — an explicit "no searchable text" message, never a spinner that never ends. Test in Task 10.

---

### Task 1: Models, library index, repository

**Files:**
- Create: `lib/models/pdf_document.dart`
- Create: `lib/core/pdf/pdf_library_index.dart`
- Create: `lib/core/pdf/pdf_library_repository.dart`
- Create: `tool/verify_pdf_library.dart` (verifier harness + this task's sections)
- Test: `tool/verify_pdf_library.dart`

**Interfaces:**
- Consumes: `KeyValueStore` (`lib/core/key_value_store.dart`).
- Produces:

```dart
enum PdfDocumentSource { imported, generated }
enum PdfEncryptionState { unknown, no, yes }

class PdfDocumentEntry {
  const PdfDocumentEntry({
    required this.id,
    required this.displayName,
    required this.baseFileName,
    this.originalName,
    required this.sizeBytes,
    this.pageCount,
    required this.addedAt,
    this.lastOpenedAt,
    this.lastPage = 1,
    this.favorite = false,
    this.thumbnailFileName,
    this.annotationCount = 0,
    this.source = PdfDocumentSource.imported,
    this.encryption = PdfEncryptionState.unknown,
    this.exportedAt,
  });
  final String id;
  final String displayName;
  final String baseFileName;
  final String? originalName;
  final int sizeBytes;
  final int? pageCount;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final int lastPage;
  final bool favorite;
  final String? thumbnailFileName;
  final int annotationCount;
  final PdfDocumentSource source;
  final PdfEncryptionState encryption;
  final DateTime? exportedAt;

  PdfDocumentEntry copyWith({ /* every field, nullable-aware for the DateTime? ones */ });
  Map<String, dynamic> toJson();
  factory PdfDocumentEntry.fromJson(Map<String, dynamic> json);
}

enum PdfSort { name, addedAt, size }

class PdfLibraryIndex {
  const PdfLibraryIndex(this.entries);
  factory PdfLibraryIndex.empty();
  factory PdfLibraryIndex.fromJson(Map<String, dynamic>? json);
  final List<PdfDocumentEntry> entries;

  Map<String, dynamic> toJson();          // {'version': 1, 'documents': [...]}
  PdfLibraryIndex upsert(PdfDocumentEntry entry);
  PdfLibraryIndex remove(String id);
  PdfLibraryIndex pruneMissing(bool Function(PdfDocumentEntry) fileExists);
  List<PdfDocumentEntry> query({
    String search = '',
    PdfSort sort = PdfSort.addedAt,
    bool descending = true,
    bool favoritesOnly = false,
    int? limit,
  });
}

class PdfLibraryRepository {
  PdfLibraryRepository(this._store);
  static const String storeKey = 'pdf.library.v1';
  PdfLibraryIndex load();
  Future<void> save(PdfLibraryIndex index);
}
```

JSON keys are exactly: `id`, `name`, `base`, `originalName`, `size`, `pages`, `addedAt`, `lastOpenedAt`, `lastPage`, `favorite`, `thumb`, `annotations`, `source`, `encryption`, `exportedAt`. Dates are ISO-8601 UTC strings; missing/null dates stay null. `source`/`encryption` are their enum names; unknown values fall back to `imported`/`unknown`.

`query` semantics: `search` is a trimmed, case-insensitive `contains` on `displayName`; empty means all. `PdfSort.name` uses `String.compareTo`; `addedAt` uses `addedAt` with `lastOpenedAt ?? addedAt` as the recency key; `size` uses `sizeBytes`. Descending reverses the final list. `pruneMissing` drops entries whose predicate returns false. `fromJson` skips a malformed document element instead of throwing, and an unreadable root yields an empty index.

- [ ] **Step 1: Write the failing verifier sections**

Add to `tool/verify_pdf_library.dart` a harness matching `tool/verify_calculator_logic.dart` (`check(bool, String)`, `_checks`, `_failures`, exit code 1), then these assertions:

- `PdfDocumentEntry.fromJson(entry.toJson())` reproduces every field, including `pageCount: null`, `lastOpenedAt: null`, `thumbnailFileName: null`.
- `{'id':'a','name':'x','base':'a.pdf','size':1,'addedAt':'2026-10-25T00:00:00.000Z'}` defaults `lastPage == 1`, `favorite == false`, `annotations == 0`, `source == PdfDocumentSource.imported`, `encryption == PdfEncryptionState.unknown`.
- A JSON object missing `base` throws `FormatException`; `PdfLibraryIndex.fromJson` catches that and skips the element.
- `{'encryption': 'maybe'}` → `PdfEncryptionState.unknown`.
- `PdfLibraryIndex.fromJson(null)` → `entries` empty.
- An index with one malformed document element and one valid one loads only the valid one.
- `upsert` of an entry with an existing id replaces in place; a new id appends.
- `query(search: 'كيم')` matches `كيمياء` and not `فيزياء`; `query(search: 'AI')` matches `ai notes`.
- `query(sort: PdfSort.addedAt, descending: true)` puts the newest first; `descending: false` reverses it; `limit: 2` truncates.
- `query(favoritesOnly: true)` excludes non-favorites.
- `pruneMissing((e) => e.id != 'gone')` drops `gone`.
- `PdfLibraryRepository` with an in-memory `KeyValueStore` round-trips: `save` then `load` yields the same JSON.

Include an in-memory `KeyValueStore` implementation in the tool file (a `Map<String, String>`).

- [ ] **Step 2: Run the verifier to confirm it fails**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: compile error / failure because `lib/models/pdf_document.dart` does not exist.

- [ ] **Step 3: Implement the three files**

Straightforward value classes. Use `String.compareTo` for names (Arabic sorts acceptably; no locale collation in pure Dart). `copyWith` must distinguish "not provided" from "set to null" for `originalName`, `pageCount`, `lastOpenedAt`, `thumbnailFileName`, `exportedAt` — use `Object? sentinel = _unset` parameters for the nullable ones.

- [ ] **Step 4: Run the verifier until it passes**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: `All checks passed` and exit 0.

- [ ] **Step 5: Format and analyze**

Run: `$DART format lib/models/pdf_document.dart lib/core/pdf/pdf_library_index.dart lib/core/pdf/pdf_library_repository.dart tool/verify_pdf_library.dart`
Run: `$DART analyze --fatal-infos lib/models/pdf_document.dart lib/core/pdf/pdf_library_index.dart lib/core/pdf/pdf_library_repository.dart tool/verify_pdf_library.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/models/pdf_document.dart lib/core/pdf/pdf_library_index.dart lib/core/pdf/pdf_library_repository.dart tool/verify_pdf_library.dart
git commit -m "feat(pdf): add document model and library index"
```

---

### Task 2: Page geometry

**Files:**
- Create: `lib/core/pdf/pdf_page_geometry.dart`
- Test: `tool/verify_pdf_library.dart` (new section)

**Interfaces:**
- Produces:

```dart
/// Rectangle in normalized page coordinates: 0..1, origin top-left.
class NormalizedRect {
  const NormalizedRect(this.left, this.top, this.width, this.height);
  final double left, top, width, height;
  double get right;
  double get bottom;
  NormalizedRect clampToPage();
}

class PdfPageGeometry {
  const PdfPageGeometry({required this.widthPoints, required this.heightPoints});
  final double widthPoints;
  final double heightPoints;

  double fitScale(double viewportWidth);
  double displayWidth({required double fitScale, required double zoom});
  double displayHeight({required double fitScale, required double zoom});

  /// Visible fraction of the unrotated page for a viewport, expanded by
  /// [margin] on every side and clamped to the page.
  NormalizedRect visibleSource({
    required double scrollX,
    required double scrollY,
    required double viewportWidth,
    required double viewportHeight,
    required double fitScale,
    required double zoom,
    double margin = 0.15,
  });

  /// Maps a rect in rotated display space back to unrotated page space.
  static NormalizedRect unrotateSource(NormalizedRect displayRect, int quarterTurns);
}
```

Formulas the implementer must use (the tests pin them):

- `fitScale = viewportWidth / widthPoints`.
- `displayWidth = widthPoints * fitScale * zoom`, `displayHeight = heightPoints * fitScale * zoom`.
- `visibleSource`: `w = displayWidth`, `h = displayHeight`; `left = scrollX / w`, `top = scrollY / h`, `width = viewportWidth / w`, `height = viewportHeight / h`; expand each side by `margin`; clamp all four edges into `[0, 1]`.
- `unrotateSource` with `q = ((quarterTurns % 4) + 4) % 4`:
  - `0` → `displayRect`
  - `1` → `(top, 1 - left - width, height, width)`
  - `2` → `(1 - left - width, 1 - top - height, width, height)`
  - `3` → `(1 - top - height, left, height, width)`

- [ ] **Step 1: Write the failing assertions**

- `PdfPageGeometry(widthPoints: 600, heightPoints: 800).fitScale(400)` returns `2/3` (±1e-9).
- At that fit scale and `zoom: 1`, `displayWidth == 400`; at `zoom: 5`, `displayWidth == 2000`.
- `visibleSource(scrollX: 0, scrollY: 0, viewportWidth: 400, viewportHeight: 600, fitScale: 2/3, zoom: 5, margin: 0)` → `left == 0`, `top == 0`, `width == 0.2` (400 / 2000), `height == 0.225` (600 / 2666.666…).
- The same call with `margin: 0.15` keeps `left == 0` (clamped) and produces `right <= 1`, `bottom <= 1`.
- Scrolling past the end (`scrollX: 99999`) clamps `left` to `1 - width` (or `0` when the visible width is 1); the rect never leaves the page at zoom 5 in either axis.
- `unrotateSource(NormalizedRect(0.1, 0.2, 0.3, 0.4), 0)` equals the input.
- `unrotateSource(..., 1)` equals `(0.2, 0.6, 0.4, 0.3)`.
- `unrotateSource(..., 2)` equals `(0.6, 0.4, 0.3, 0.4)`.
- `unrotateSource(..., 3)` equals `(0.4, 0.1, 0.4, 0.3)`.
- `unrotateSource(rect, -1)` equals the `3` result.

- [ ] **Step 2: Run to confirm failure**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: failure naming the missing `PdfPageGeometry`.

- [ ] **Step 3: Implement `pdf_page_geometry.dart`**

Use `clamp(0.0, 1.0)` per edge; when computing width after clamping, derive `right` from the clamped left/right so width never goes negative. Compare doubles with a 1e-9 epsilon in tests.

- [ ] **Step 4: Run the verifier until it passes**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: exit 0.

- [ ] **Step 5: Format, analyze, commit**

Run: `$DART format lib/core/pdf/pdf_page_geometry.dart tool/verify_pdf_library.dart`
Run: `$DART analyze --fatal-infos lib/core/pdf/pdf_page_geometry.dart`
```bash
git add lib/core/pdf/pdf_page_geometry.dart tool/verify_pdf_library.dart
git commit -m "feat(pdf): add page geometry for tiled rendering"
```

---

### Task 3: Library file store

**Files:**
- Create: `lib/core/pdf/pdf_library_store.dart`
- Test: `tool/verify_pdf_library.dart` (new section using temp directories)

**Interfaces:**
- Produces:

```dart
enum PdfImportFailure { invalidHeader, empty, storage }

class PdfImportException implements Exception {
  const PdfImportException(this.failure);
  final PdfImportFailure failure;
}

class PdfLibraryStore {
  PdfLibraryStore({required Directory rootDir, required Directory cacheDir});
  final Directory rootDir;
  final Directory cacheDir;

  Directory get documentsDir;   // <root>/pdf_library
  Directory get thumbsDir;      // <cache>/pdf_thumbs
  Directory get sessionTempDir; // <cache>/pdf_session_tmp

  File baseFile(String id);          // documentsDir/<id>.pdf
  File thumbFile(String id);         // thumbsDir/<id>.png
  File sessionTempFile(String id);   // sessionTempDir/<id>.pdf

  Future<void> ensureReady();
  Future<int> copyIn(Stream<List<int>> bytes, String id);
  Future<void> deleteEntry(String id);
  Future<void> sweepTemp();
  Future<void> writeThumbnail(String id, Uint8List png);
  static bool looksLikePdf(List<int> header);
}
```

Rules: `copyIn` validates the first five bytes are `%PDF-` before writing anything, writes `<id>.pdf.part`, then renames to `<id>.pdf`; on any failure it deletes the partial file and throws `PdfImportException`. Empty input throws `empty`. `looksLikePdf` compares the first five bytes to `37 50 44 46 2D`. `deleteEntry` removes the base file, all files in `thumbsDir` starting with `<id>.`, and returns quietly when they do not exist. `sweepTemp` deletes files in `sessionTempDir` older than now (all of them; nothing there is durable) and recreates the directory. `writeThumbnail` writes atomically the same way (`.part` then rename).

- [ ] **Step 1: Write the failing assertions** (create a temp root under `Directory.systemTemp.createTempSync('zaker_pdf_')` and delete it at the end)

- `looksLikePdf('%PDF-1.7'.codeUnits)` is true; `looksLikePdf('hello'.codeUnits)` is false; fewer than five bytes is false.
- `copyIn(Stream.value('%PDF-1.7\n...'.codeUnits), 'doc1')` returns the byte length and `baseFile('doc1').readAsBytesSync()` equals the input.
- `copyIn(Stream.value('hello'.codeUnits), 'bad')` throws `PdfImportException` with `invalidHeader`, and `baseFile('bad').existsSync()` is false.
- `copyIn(const Stream.empty(), 'empty')` throws with `empty`.
- After writing a base file and a thumbnail for `a`, and a base file for `ab`, `deleteEntry('a')` removes `a.pdf` and `a.png` but leaves `ab.pdf`.
- `sweepTemp` leaves no files in `sessionTempDir` and leaves `documentsDir` untouched.

- [ ] **Step 2: Run to confirm failure**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: failure naming the missing store.

- [ ] **Step 3: Implement `pdf_library_store.dart`**

Use `dart:io`, `dart:typed_data`, and `package:path`. Read from the source stream until at least five bytes arrive (or the stream ends), validate those five bytes, and only then open `<id>.pdf.part` and write the buffered bytes plus the remainder of the stream. This file imports no Flutter.

- [ ] **Step 4: Run the verifier until it passes**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: exit 0.

- [ ] **Step 5: Format, analyze, commit**

Run: `$DART format lib/core/pdf/pdf_library_store.dart tool/verify_pdf_library.dart`
Run: `$DART analyze --fatal-infos lib/core/pdf/pdf_library_store.dart`
```bash
git add lib/core/pdf/pdf_library_store.dart tool/verify_pdf_library.dart
git commit -m "feat(pdf): add private library file store"
```

---

### Task 4: Native render channel

**Files:**
- Create: `lib/core/pdf/pdf_render_channel.dart`
- Create: `lib/providers/pdf_providers.dart` (start it here with the channel provider)
- Create: `android/app/src/main/kotlin/com/zaker/zaker_ai/PdfRenderChannel.kt`
- Modify: `android/app/src/main/kotlin/com/zaker/zaker_ai/MainActivity.kt` (register a channel in `configureFlutterEngine`, add `PDF_RENDER_CHANNEL` to the companion object near line 313-318)
- Test: `test/pdf_render_channel_test.dart`

**Interfaces:**
- Produces:

```dart
class PdfPageSize {
  const PdfPageSize(this.widthPoints, this.heightPoints);
  final double widthPoints, heightPoints;
}

class PdfRendererHandle {
  const PdfRendererHandle({required this.id, required this.pageCount, required this.pages});
  final int id;
  final int pageCount;
  final List<PdfPageSize> pages;
}

enum PdfRenderFailure { passwordRequired, wrongPassword, corrupt, unavailable, renderFailed }

class PdfRenderException implements Exception {
  const PdfRenderException(this.failure);
  final PdfRenderFailure failure;
}

class PdfRenderChannel {
  const PdfRenderChannel();
  static const MethodChannel channel = MethodChannel('zaker/pdf_render');

  Future<PdfRendererHandle> open(String path, {String? password});
  Future<Uint8List> render({
    required int handle,
    required int pageIndex,
    required double scale,           // output pixels per PDF point
    required NormalizedRect source,  // normalized page rect
    int maxPixels = 4096,            // longest edge cap
  });
  Future<void> close(int handle);
}

final pdfRenderChannelProvider = Provider<PdfRenderChannel>((ref) => const PdfRenderChannel());
```

Channel contract:
- `open` args `{path: String, password: String?}` → `{handle: int, pageCount: int, pages: List<{width: double, height: double}>}`; errors `passwordRequired`, `wrongPassword`, `corrupt`, `unavailable`.
- `render` args `{handle: int, page: int, scale: double, left/top/width/height: double, maxPixels: int}` → `Uint8List` PNG; errors `renderFailed`, `corrupt`.
- `close` args `{handle: int}` → `null`; never throws.

Dart maps `PlatformException.code` to `PdfRenderFailure`; unknown codes become `renderFailed`; `MissingPluginException` becomes `unavailable`.

Kotlin `PdfRenderChannel`:
- Single `Executors.newSingleThreadExecutor()` for rendering; results posted back to the main looper.
- `SparseArray<PdfRenderer>` of open documents; handles increase from 1.
- `open`: `ParcelFileDescriptor.open(File(path), MODE_READ_ONLY)`; try `PdfRenderer(pfd, password ?: "")`; if `SecurityException` with a null password → `passwordRequired`, with a password → `wrongPassword`. Page sizes from `page.width.toDouble()`/`page.height.toDouble()` (points at 72 dpi).
- `render`: open the page, compute `bw = ceil(page.width * sourceWidth * scale)`, `bh = ceil(page.height * sourceHeight * scale)`, scale both down so `max(bw, bh) <= maxPixels`; create `Bitmap.createBitmap(bw, bh, ARGB_8888)`; canvas matrix = `translate(-left*page.width, -top*page.height)` then `scale(scale*bwFactor, scale*bhFactor)`; `page.render(bitmap, null, matrix, RENDER_MODE_FOR_DISPLAY)`; compress PNG; `bitmap.recycle()`; `page.close()` in `finally`.
- `close`: close the renderer, remove it, shut down the descriptor.
- Guard every renderer with a lock; a closed handle returns `renderFailed` rather than crashing.

- [ ] **Step 1: Write the failing test** (`test/pdf_render_channel_test.dart`)

Use `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(PdfRenderChannel.channel, ...)`.

- `open('doc.pdf')` with a mocked `{handle: 1, pageCount: 2, pages: [{width: 595.0, height: 842.0}, ...]}` returns those values.
- A mocked `PlatformException(code: 'passwordRequired')` throws `PdfRenderException` with `PdfRenderFailure.passwordRequired`.
- A mocked `MissingPluginException` becomes `PdfRenderFailure.unavailable`.
- `render(handle: 1, pageIndex: 0, scale: 2, source: NormalizedRect(0, 0, 0.5, 0.5))` sends `handle`, `page`, `scale`, `left`, `top`, `width`, `height`, `maxPixels` as the mock handler records (assert from `call.arguments`), and returns the mocked `Uint8List`.
- `close` swallows a platform exception.

- [ ] **Step 2: Run to confirm failure**

Run (CI only): `flutter test test/pdf_render_channel_test.dart`
Expected: compile failure — the file does not exist. Locally, run `$DART analyze lib/core/pdf/pdf_render_channel.dart` and expect a missing-file error; note that the test itself is not runnable here.

- [ ] **Step 3: Implement the Dart bridge and the Kotlin channel**

Dart: one private `_invoke` helper that maps exceptions. Kotlin: as specified. `MainActivity.configureFlutterEngine` adds, after the adhan channel:

```kotlin
PdfRenderChannel(flutterEngine.dartExecutor.binaryMessenger, applicationContext).register()
```

Add `const val PDF_RENDER_CHANNEL = "zaker/pdf_render"` in the companion object and use it in `PdfRenderChannel.kt`.

- [ ] **Step 4: Analyze**

Run: `$DART format lib/core/pdf/pdf_render_channel.dart lib/providers/pdf_providers.dart test/pdf_render_channel_test.dart`
Run: `$DART analyze --fatal-infos lib/core/pdf/pdf_render_channel.dart lib/providers/pdf_providers.dart`
Expected: no issues. The Kotlin file is only compiled by CI; record that it is unverified here.

- [ ] **Step 5: Commit**

```bash
git add lib/core/pdf/pdf_render_channel.dart lib/providers/pdf_providers.dart test/pdf_render_channel_test.dart android/app/src/main/kotlin/com/zaker/zaker_ai/PdfRenderChannel.kt android/app/src/main/kotlin/com/zaker/zaker_ai/MainActivity.kt
git commit -m "feat(pdf): add native PdfRenderer tile channel"
```

---

### Task 5: Tile cache

**Files:**
- Create: `lib/core/pdf/pdf_tile_cache.dart`
- Test: `tool/verify_pdf_library.dart` (new section)

**Interfaces:**
- Produces:

```dart
class PdfTileKey {
  factory PdfTileKey.fromSource({
    required int pageIndex,
    required double scale,
    required NormalizedRect source,
  });
  const PdfTileKey({required this.pageIndex, required this.scaleBucket, required this.x0, required this.y0, required this.x1, required this.y1});
  final int pageIndex;
  final int scaleBucket; // (scale * 100).round()
  final int x0, y0, x1, y1; // normalized coords quantized to 0..1000
  // == and hashCode over all fields
}

class PdfTileCache {
  PdfTileCache({int maxBytes = 96 * 1024 * 1024});
  Uint8List? get(PdfTileKey key);
  void put(PdfTileKey key, Uint8List bytes);
  void clear();
  int get bytes;
  int get length;
}
```

Quantization: `x0 = (source.left * 1000).round().clamp(0, 1000)`, and the same for the other three edges, so a 0.5% scroll nudge reuses the tile.

- [ ] **Step 1: Write the failing assertions**

- `fromSource(pageIndex: 2, scale: 1.234, source: NormalizedRect(0.1001, 0, 0.5, 0.5))` has `scaleBucket == 123`, `x0 == 100`, `x1 == 600`, and equals the same key built from `0.1004`.
- `put` then `get` returns the identical bytes; a missing key returns null.
- With `maxBytes: 10`, putting three 4-byte buffers leaves `length == 2` and evicts the first inserted.
- `get` on the first of two entries then a third `put` evicts the *other* one (recency refresh).
- Replacing an existing key updates `bytes` to the new size without growing `length`.
- `clear` sets `bytes == 0` and `length == 0`.

- [ ] **Step 2: Run to confirm failure**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: missing `PdfTileCache`.

- [ ] **Step 3: Implement with a `LinkedHashMap<PdfTileKey, Uint8List>`**

On `get`, remove and re-insert to refresh recency. On `put`, evict from the front while `bytes > maxBytes` and `length > 1` (always keep the newest entry even if it alone exceeds the budget).

- [ ] **Step 4: Run the verifier until it passes**

Run: `$DART run tool/verify_pdf_library.dart`
Expected: exit 0.

- [ ] **Step 5: Format, analyze, commit**

Run: `$DART format lib/core/pdf/pdf_tile_cache.dart tool/verify_pdf_library.dart`
Run: `$DART analyze --fatal-infos lib/core/pdf/pdf_tile_cache.dart`
```bash
git add lib/core/pdf/pdf_tile_cache.dart tool/verify_pdf_library.dart
git commit -m "feat(pdf): add bounded LRU tile cache"
```

---

### Task 6: Library controller, providers, app wiring

**Files:**
- Create: `lib/core/pdf/pdf_library_controller.dart`
- Create: `lib/core/pdf/pdf_thumbnailer.dart`
- Modify: `lib/providers/pdf_providers.dart`
- Modify: `lib/main.dart:29-62` (compute directories, override the store provider)
- Test: `test/pdf_library_controller_test.dart`

**Interfaces:**
- Consumes: `PdfLibraryStore`, `PdfLibraryRepository`, `PdfRenderChannel`.
- Produces:

```dart
class PdfImportSource {
  const PdfImportSource({required this.name, required this.sizeBytes, required this.openRead});
  final String name;
  final int sizeBytes;
  final Stream<List<int>> Function() openRead;
}

class PdfProbeResult {
  const PdfProbeResult({this.pageCount, this.encrypted = false});
  final int? pageCount; // null when the file is encrypted
  final bool encrypted;
}

typedef PdfProbe = Future<PdfProbeResult> Function(File file);

typedef PdfThumbnailer = Future<void> Function(File baseFile, File thumbFile);

class PdfImportResult {
  const PdfImportResult({required this.imported, required this.failures});
  final List<PdfDocumentEntry> imported;
  final List<PdfImportFailure> failures;
}

class PdfLibraryController extends StateNotifier<PdfLibraryIndex> {
  PdfLibraryController({
    required PdfLibraryStore store,
    required PdfLibraryRepository repository,
    required PdfProbe probe,
    required PdfThumbnailer thumbnailer,
    String Function()? newId,
  });
  bool get isBusy;
  Future<PdfImportResult> import(List<PdfImportSource> sources);
  Future<void> rename(String id, String name);
  Future<void> remove(String id);
  Future<void> setFavorite(String id, bool value);
  Future<void> markOpened(String id, {int? page});
  Future<void> refresh();
  Future<void> reindex();
}

// lib/providers/pdf_providers.dart
final pdfLibraryStoreProvider = Provider<PdfLibraryStore>((ref) => throw UnimplementedError('pdfLibraryStoreProvider must be overridden'));
final pdfLibraryControllerProvider = StateNotifierProvider<PdfLibraryController, PdfLibraryIndex>((ref) { ... });
```

Behaviour:
- `import`: for each source, generate an id, `copyIn`, probe, then upsert. On `PdfRenderException(passwordRequired)` mark the entry `encryption: yes`, `pageCount: null`, skip the thumbnail. On any other probe failure keep the entry with `encryption: unknown` and no page count (the reader will surface the real error). Header failures add to `failures` and never create an entry. Run one source at a time; `isBusy` guards re-entry.
- `probe` default (in providers) opens through `PdfRenderChannel`, reads the page count, and closes in `finally`. It returns `PdfProbeResult(encrypted: true)` on `PdfRenderFailure.passwordRequired` and rethrows every other failure.
- `thumbnailer` default (`pdf_thumbnailer.dart`): open the file with `PdfRenderChannel`, render page 0 with `scale = 120 / page.widthPoints`, `source = NormalizedRect(0, 0, 1, 1)`, write with `store.writeThumbnail`. Swallow failures — a missing thumbnail is not an import failure.
- `refresh`: prune entries whose `baseFile` is missing, save, emit the new index. Never deletes anything from disk.
- `newId` default: `'${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 20).toRadixString(16)}'`.
- `rename` only changes `displayName`; `remove` deletes files then the entry; `markOpened` sets `lastOpenedAt` and `lastPage`.
- Persist after every mutation through the repository.

- [ ] **Step 1: Write the failing tests**

Using `Directory.systemTemp.createTempSync`, an in-memory `KeyValueStore`, a fake probe and a no-op thumbnailer:

- Importing `'%PDF-1.7'` bytes creates one entry named after the source, persists it, and leaves `store.baseFile(entry.id)` on disk; `pageCount` equals the probe's.
- A source whose header is `'hello'` returns one `invalidHeader` failure, and the index stays empty.
- A probe that reports `encrypted: true` yields `pageCount == null`, `encryption == PdfEncryptionState.yes`, and no thumbnail file.
- Deleting the base file then calling `refresh()` removes the entry from state and from the persisted JSON.
- `markOpened(id, page: 7)` then a fresh controller over the same store restores `lastPage == 7`.
- `rename` and `setFavorite` persist; `remove` deletes the base file and the entry.

- [ ] **Step 2: Run to confirm failure**

Run (CI only): `flutter test test/pdf_library_controller_test.dart`
Expected: compile failure. Locally, `$DART analyze lib/core/pdf/pdf_library_controller.dart` fails with a missing file.

- [ ] **Step 3: Implement controller, thumbnailer, providers, and `main.dart` wiring**

`main.dart`: after `LocalStore.open()`, add

```dart
final support = await getApplicationSupportDirectory();
final cache = await getTemporaryDirectory();
final pdfStore = PdfLibraryStore(rootDir: support, cacheDir: cache);
await pdfStore.ensureReady();
await pdfStore.sweepTemp();
```

and extend the override list with `pdfLibraryStoreProvider.overrideWithValue(pdfStore)`. Import `package:path_provider/path_provider.dart`, `core/pdf/pdf_library_store.dart`, and `providers/pdf_providers.dart`. Keep the existing notification setup untouched.

`pdfLibraryControllerProvider` builds the repository from `localStoreProvider`, the store from `pdfLibraryStoreProvider`, the probe/thumbnailer from `pdfRenderChannelProvider`, and returns the controller.

- [ ] **Step 4: Analyze and format**

Run: `$DART format lib/core/pdf/pdf_library_controller.dart lib/core/pdf/pdf_thumbnailer.dart lib/providers/pdf_providers.dart lib/main.dart test/pdf_library_controller_test.dart`
Run: `$DART analyze --fatal-infos lib/core/pdf/pdf_library_controller.dart lib/core/pdf/pdf_thumbnailer.dart lib/providers/pdf_providers.dart lib/main.dart`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/core/pdf/pdf_library_controller.dart lib/core/pdf/pdf_thumbnailer.dart lib/providers/pdf_providers.dart lib/main.dart test/pdf_library_controller_test.dart
git commit -m "feat(pdf): add library controller and app wiring"
```

---

### Task 7: Library UI and hub section

**Files:**
- Create: `lib/features/pdf/pdf_library_screen.dart`
- Create: `lib/features/pdf/widgets/pdf_document_card.dart`
- Create: `lib/features/pdf/widgets/pdf_thumbnail.dart`
- Create: `lib/features/pdf/widgets/pdf_import_button.dart`
- Modify: `lib/features/tools/pdf_tools_screen.dart` (add the «ملفاتي» section above `SectionHeader('أدواتك')`)
- Modify: `lib/core/router.dart` (add `pdfLibrary = '/pdf-library'` near line 116 and a `GoRoute` near line 389)
- Test: `test/pdf_library_screen_test.dart`

**Interfaces:**
- Consumes: `pdfLibraryControllerProvider`, `pdfLibraryStoreProvider`, `pdfRenderChannelProvider`.
- Produces:

```dart
// lib/features/pdf/pdf_library_screen.dart
class PdfLibraryScreen extends ConsumerStatefulWidget {
  const PdfLibraryScreen({super.key});
}

// lib/features/pdf/widgets/pdf_document_card.dart
enum PdfDocumentCardLayout { grid, list }
class PdfDocumentCard extends StatelessWidget {
  const PdfDocumentCard({
    super.key,
    required this.entry,
    required this.layout,
    required this.available,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onShare,
    required this.onDetails,
  });
}

// lib/features/pdf/widgets/pdf_import_button.dart
Future<void> importPdfFiles(BuildContext context, WidgetRef ref);
```

UI:
- `PdfLibraryScreen`: `DefaultTabController` with tabs «الحديثة»، «كل الملفات»، «المفضلة»; a search field; a sort menu (`name`/`addedAt`/`size`); grid/list toggle; import button; `EmptyState` with «لسه مفيش ملفات — ضيف أول PDF» when empty.
- `PdfDocumentCard`: 48×64 thumbnail, two-line name with `maxLines: 2` + ellipsis, size and date, favorite icon, three-dot menu with «إعادة تسمية»، «حذف»، «مشاركة»، «تفاصيل». Delete opens an `AlertDialog` naming the file and explaining that only the app's copy is removed. Rename opens a dialog with the current name prefilled; empty names are refused. Details is a bottom sheet with name, pages («مش معروف» when null), size, added/opened dates, encryption state, and the same copy explanation. Use `Share.shareXFiles([XFile(baseFile.path)])` from `share_plus` for share.
- Unavailable entry (`!baseFile.existsSync()`): dimmed card, a «الملف مش موجود» line, menu offers «شيل من المكتبة» only.
- `_LibrarySection` in the hub: `SectionHeader('ملفاتي', actionLabel: 'عرض الكل', onAction: ...)` then up to 6 recent entries as compact cards in a horizontal `ListView` (height ~148) with a small `FeatureTile`-style import tile; hidden entirely when the library is empty (the tools grid remains the first thing seen).
- «ضغط» replaces the «تضغيم» label in `_PdfTool.compress` while touching the grid.

- [ ] **Step 1: Write the failing widget tests**

- On an empty index, the library screen shows the empty state and an import action.
- With two entries, both names render; a 60-character name is clipped (`maxLines == 2`, `overflow == TextOverflow.ellipsis`).
- Tapping a card's menu → «حذف» shows a dialog containing the file name; cancelling leaves the entry.
- The hub shows «ملفاتي» and «عرض الكل» when the index is non-empty, and not when empty.

- [ ] **Step 2: Run to confirm failure**

Run (CI only): `flutter test test/pdf_library_screen_test.dart`
Expected: compile failure (missing screen).

- [ ] **Step 3: Implement the widgets and hub section**

`importPdfFiles` calls `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true, withReadStream: true)`, maps each `PlatformFile` to a `PdfImportSource` (`name`, `size`, `openRead: () => stream ?? File(path).openRead()`), and calls the controller. A picker result with neither a stream nor a path is skipped with an Arabic message. Show progress while `isBusy`, then a snackbar «تمت إضافة N ملف».

Build the thumbnail with `Image.file(store.thumbFile(id), fit: BoxFit.cover)` and a `PdfThumbnail` fallback (`Icons.picture_as_pdf` in a tinted rounded box) when the PNG is missing. Wire card taps to

```dart
context.push('/pdf-viewer?docId=${Uri.encodeQueryComponent(entry.id)}');
```

(Later plans add annotate/sign modes; keep the `docId` parameter now.)

- [ ] **Step 4: Analyze and format**

Run: `$DART format lib/features/pdf lib/features/tools/pdf_tools_screen.dart lib/core/router.dart test/pdf_library_screen_test.dart`
Run: `$DART analyze --fatal-infos lib/features/pdf lib/features/tools/pdf_tools_screen.dart lib/core/router.dart`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pdf lib/features/tools/pdf_tools_screen.dart lib/core/router.dart test/pdf_library_screen_test.dart
git commit -m "feat(pdf): add private PDF library screen and hub section"
```

---

### Task 8: Reader shell — open, password, errors, chrome

**Files:**
- Create: `lib/features/pdf/pdf_reader_screen.dart`
- Rewrite: `lib/features/tools/pdf_viewer_screen.dart` (keep the class name, `bytes`, `path`, `title`, `fileName`, and `location`)
- Modify: `lib/core/router.dart:392-398` (pass `docId`)
- Test: `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: `pdfLibraryControllerProvider`, `pdfLibraryStoreProvider`, `pdfRenderChannelProvider`.
- Produces:

```dart
enum PdfReaderMode { read } // annotate/sign arrive in Plan 2

class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({
    super.key,
    this.path,
    this.title,
    this.bytes,
    this.fileName,
    this.docId,
    this.mode = PdfReaderMode.read,
  });
  final String? path;
  final String? title;
  final Uint8List? bytes;
  final String? fileName;
  final String? docId;
  final PdfReaderMode mode;
}
```

Behaviour:
- Resolves the document: `docId` → entry from the controller and `store.baseFile(id)`; `bytes` → write to `store.sessionTempFile(id)` and use that; `path` → use directly (transient). A missing file shows the error state.
- Opens through `PdfRenderChannel`; on `passwordRequired` shows a secure dialog (obscured text, «كلمة السر»، «فتح»، «إلغاء»). Wrong passwords re-open the dialog with «كلمة السر مش صح — جرّب تاني». Three failures offer «إلغاء». The password is never stored or included in any message.
- Error states: `corrupt`/`unavailable`/missing file → `EmptyState` with «تعذّر فتح الملف» and a retry action; in a transient session also a `share_plus` action on the file.
- Chrome: auto-hiding top bar (back, name, search, favorite) toggled by tapping the page area; bottom bar with `Slider` and «صفحة X من Y»; page-jump dialog accepting 1..pageCount; floating page-mode and rotation buttons. Favourite is disabled for transient documents.
- Close: `close(handle)` in `dispose`, delete a session temp file for `bytes`, keep `path` files.
- Last page: call `markOpened(id, page: currentPage)` debounced 500 ms for library entries.

- [ ] **Step 1: Write the failing tests** (override `pdfRenderChannelProvider` with a fake that records calls)

- Opening a fake handle for 10 pages shows «صفحة 1 من 10».
- A `passwordRequired` fake shows the password dialog; entering text and confirming calls `open` again with that password; a second `passwordRequired` keeps the dialog open.
- `open` throwing `corrupt` renders «تعذّر فتح الملف» and a retry button that calls `open` again.
- `bytes` input writes to the session temp dir and deletes it on dispose.
- `PdfViewerScreen(path: '/x.pdf')` builds a `PdfReaderScreen` (smoke test).

- [ ] **Step 2: Run to confirm failure**

Run (CI only): `flutter test test/pdf_reader_screen_test.dart`
Expected: compile failure.

- [ ] **Step 3: Implement the reader shell and the adapter**

`PdfViewerScreen` becomes:

```dart
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({super.key, this.path, this.title, this.bytes, this.fileName, this.docId});
  // ... fields ...
  static String location(String path, {String? title}) => ...; // unchanged body
  @override
  Widget build(BuildContext context) => PdfReaderScreen(path: path, title: title, bytes: bytes, fileName: fileName, docId: docId);
}
```

Remove the old `PdfPreview` body and its imports from this file. Router builder adds `docId: state.uri.queryParameters['docId']`.

- [ ] **Step 4: Analyze and format**

Run: `$DART format lib/features/pdf/pdf_reader_screen.dart lib/features/tools/pdf_viewer_screen.dart lib/core/router.dart test/pdf_reader_screen_test.dart`
Run: `$DART analyze --fatal-infos lib/features/pdf lib/features/tools/pdf_viewer_screen.dart lib/core/router.dart`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pdf/pdf_reader_screen.dart lib/features/tools/pdf_viewer_screen.dart lib/core/router.dart test/pdf_reader_screen_test.dart
git commit -m "feat(pdf): replace preview with native reader shell"
```

---

### Task 9: Page rendering, zoom, modes, rotation, night

**Files:**
- Create: `lib/features/pdf/widgets/pdf_page_view.dart`
- Create: `lib/features/pdf/widgets/pdf_reader_viewport.dart`
- Modify: `lib/features/pdf/pdf_reader_screen.dart` (host the viewport)
- Test: `test/pdf_reader_screen_test.dart` (extend)

**Interfaces:**
- Produces:

```dart
class PdfReaderViewport extends StatefulWidget {
  const PdfReaderViewport({
    super.key,
    required this.handle,
    required this.geometry,       // List<PdfPageGeometry>
    required this.initialPage,    // zero-based
    required this.onPageChanged,  // ValueChanged<int>
    this.vertical = true,
    this.nightMode = false,
    this.quarterTurns = 0,
  });
}
```

Rendering rules:
- `fitScale` is computed from the viewport width and the first page's `widthPoints`. The `scrollX`/`scrollY` passed to `visibleSource` are page-local offsets (scroll-view offset minus the page's leading edge), so the same geometry call works in both scroll modes.
- Zoom lives in the viewport state, `1.0`–`5.0`, default `1.0`; a `ScaleGestureDetector` updates it continuously and `onScaleEnd` re-requests at the settled value.
- Page display size = `geometry.displayWidth(fitScale, zoom)` × `displayHeight(...)`, then swapped for odd quarter turns.
- For each visible page, request a tile with `source = geometry.visibleSource(...)` and `scale = zoom * fitScale * devicePixelRatio`, rounded to 0.01. Before the tile arrives, paint the previous tile for that page scaled up (or a neutral page-coloured box). Store the returned PNG bytes in a `PdfTileCache` and paint with `Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true)` — one decoded-image cache, no second `Map<PdfTileKey, ui.Image>` to keep in sync.
- Requests carry a generation integer; a response from an older generation is dropped. Only the current page ±1 is prefetched.
- Vertical mode: `SingleChildScrollView(horizontal)` wrapping a `ListView.builder` of pages with known heights; horizontal mode: `PageView.builder`. Both use `PageStorageKey`s.
- Night mode wraps tiles in a `ColorFiltered` matrix (dim/warm); page geometry and hit areas are unchanged.
- Rotation: quarter-turns increments; the viewport re-requests because the visible source changed via `unrotateSource`.
- Dispose: bump the generation so late responses are dropped, clear the cache, and let the reader call `close(handle)` (not the viewport).

- [ ] **Step 1: Write the failing assertions**

- With a fake renderer and a 400×800 viewport, the first frame requests page 0 with `source ≈ (0, 0, 1, 1)` at zoom 1 (full page visible).
- A simulated zoom to 5 requests a source whose width is under 0.6 (margin-expanded 0.2 + 2×0.15) and strictly narrower than at zoom 1; the returned bytes are painted in an `Image` widget.
- A fake renderer that never completes leaves a page-coloured placeholder, not an exception.
- `quarterTurns: 1` requests a source whose width/height are swapped relative to `quarterTurns: 0`.
- Switching to horizontal mode shows one page at a time (`PageView` present).

- [ ] **Step 2: Run to confirm failure**

Run (CI only): `flutter test test/pdf_reader_screen_test.dart`
Expected: failures for the missing widgets.

- [ ] **Step 3: Implement the viewport**

Decode with `ui.instantiateImageCodec(bytes)`. Log nothing about the document. Use `RepaintBoundary` per page. Keep the code free of `setState` during build; schedule tile requests with `addPostFrameCallback` or a microtask after layout.

- [ ] **Step 4: Analyze and format**

Run: `$DART format lib/features/pdf test/pdf_reader_screen_test.dart`
Run: `$DART analyze --fatal-infos lib/features/pdf`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/pdf test/pdf_reader_screen_test.dart
git commit -m "feat(pdf): render pages as viewport tiles with zoom"
```

---

### Task 10: Text map and in-document search

**Files:**
- Create: `lib/core/pdf/pdf_text_map.dart`
- Create: `lib/features/pdf/widgets/pdf_search_sheet.dart`
- Modify: `lib/features/pdf/pdf_reader_screen.dart` (search button opens the sheet; jumping selects the page and paints matches)
- Test: `test/pdf_text_map_test.dart`, `test/pdf_search_sheet_test.dart`

**Interfaces:**
- Produces:

```dart
class PdfTextWord {
  const PdfTextWord({required this.text, required this.bounds});
  final String text;
  final NormalizedRect bounds;
}

class PdfTextLine {
  const PdfTextLine({required this.text, required this.bounds, required this.words});
  final String text;
  final NormalizedRect bounds;
  final List<PdfTextWord> words;
}

class PdfTextMatch {
  const PdfTextMatch({required this.pageIndex, required this.bounds, required this.snippet});
  final int pageIndex;
  final NormalizedRect bounds;
  final String snippet;
}

class PdfTextMap {
  PdfTextMap.fromBytes(Uint8List bytes, {String? password, required int pageCount});
  Future<List<PdfTextLine>> linesOnPage(int pageIndex);   // cached
  Future<List<PdfTextMatch>> search(String query);        // empty query → []
  Future<bool> hasAnyText();                              // true when any page has extractable text
}
```

Implementation notes:
- Use `sf.PdfDocument(inputBytes: bytes, password: password)` and `PdfTextExtractor(doc).extractTextLines(startPageIndex, endPageIndex)`; close the document in `finally`.
- Map each line/word `bounds` (points) to normalized coordinates by dividing by the page width/height. Syncfusion reports bounds on the rotated page; divide by the geometry's *displayed* size, which matches what the user sees.
- `search` calls `doc.findText(query)` and turns each `MatchedItem` into a `PdfTextMatch` with `pageIndex` and normalized bounds; snippets come from the matching line when it exists, otherwise the query itself.
- Close the document after extraction so no file handle lingers.
- Search runs page by page with a `await Future<void>.delayed(Duration.zero)` between pages so the UI stays responsive.

- [ ] **Step 1: Write the failing tests**

- Build a 2-page `sf.PdfDocument` with `PdfPage` text «كيمياء» on page 1 and «فيزياء» on page 2; `search('كيمياء')` returns one match with `pageIndex == 0` and bounds inside 0..1.
- `search('')` returns `[]`; `search('غير موجود')` returns `[]`.
- `await hasAnyText()` is false for a blank/no-text document, and the sheet shows «الملف ده صور — مفيش نص نبحث فيه».
- With a fake text map returning three matches, the search sheet lists three rows and tapping the second invokes the jump callback with its page index.

- [ ] **Step 2: Run to confirm failure**

Run (CI only): `flutter test test/pdf_text_map_test.dart test/pdf_search_sheet_test.dart`
Expected: compile failure.

- [ ] **Step 3: Implement the text map and the sheet**

The sheet is a `DraggableScrollableSheet` inside `showModalBottomSheet`: search field, result rows with page number and snippet, a progress line while searching, and the empty-text message. It does not log text.

- [ ] **Step 4: Analyze and format**

Run: `$DART format lib/core/pdf/pdf_text_map.dart lib/features/pdf/widgets/pdf_search_sheet.dart lib/features/pdf/pdf_reader_screen.dart test/pdf_text_map_test.dart test/pdf_search_sheet_test.dart`
Run: `$DART analyze --fatal-infos lib/core/pdf/pdf_text_map.dart lib/features/pdf/widgets/pdf_search_sheet.dart lib/features/pdf/pdf_reader_screen.dart`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/core/pdf/pdf_text_map.dart lib/features/pdf/widgets/pdf_search_sheet.dart lib/features/pdf/pdf_reader_screen.dart test/pdf_text_map_test.dart test/pdf_search_sheet_test.dart
git commit -m "feat(pdf): add in-document search"
```

---

### Task 11: Reader settings and session persistence

**Files:**
- Create: `lib/models/pdf_settings.dart`
- Create: `lib/features/pdf/widgets/pdf_settings_sheet.dart`
- Modify: `lib/features/pdf/pdf_reader_screen.dart` (read defaults, persist page/zoom/rotation)
- Modify: `lib/providers/pdf_providers.dart` (settings controller)
- Test: `test/pdf_settings_test.dart`

**Interfaces:**
- Produces:

```dart
enum PdfScrollMode { vertical, horizontal }

class PdfReaderSettings {
  const PdfReaderSettings({
    this.scrollMode = PdfScrollMode.vertical,
    this.nightMode = false,
    this.haptics = true,
  });
  Map<String, dynamic> toJson();
  factory PdfReaderSettings.fromJson(Map<String, dynamic>? json);
  PdfReaderSettings copyWith({...});
}

class PdfSettingsController extends StateNotifier<PdfReaderSettings> {
  PdfSettingsController(LocalStore store);
  void setScrollMode(PdfScrollMode mode);
  void setNightMode(bool value);
  void setHaptics(bool value);
}

final pdfSettingsProvider = StateNotifierProvider<PdfSettingsController, PdfReaderSettings>(...);
```

Store key `pdf.settings.v1`. Unknown enum strings fall back to vertical. Booleans default as above when missing.

- [ ] **Step 1: Write the failing tests**

- `PdfReaderSettings.fromJson(null)` equals the defaults.
- `fromJson({'scroll': 'sideways'})` gives `PdfScrollMode.vertical`.
- `setNightMode(true)` persists; a fresh controller over the same store restores it.
- The reader persists `lastPage` for a library document: navigate to page 4, dispose, reopen → starts on page 4.
- The settings sheet toggles night mode and scroll direction and the reader rebuilds accordingly.

- [ ] **Step 2: Run to confirm failure**

Run (CI only): `flutter test test/pdf_settings_test.dart`
Expected: compile failure.

- [ ] **Step 3: Implement settings, sheet, and persistence**

The sheet (from the reader's overflow menu and the hub) uses `SwitchListTile`s for «وضع الليل» and «اهتزاز خفيف», and a segmented control for «اتجاه التمرير» (رأسي / أفقي). Do not add a keep-screen-on toggle: the app has no wakelock dependency and this plan adds none.

- [ ] **Step 4: Analyze and format**

Run: `$DART format lib/models/pdf_settings.dart lib/features/pdf/widgets/pdf_settings_sheet.dart lib/features/pdf/pdf_reader_screen.dart lib/providers/pdf_providers.dart test/pdf_settings_test.dart`
Run: `$DART analyze --fatal-infos lib/models/pdf_settings.dart lib/features/pdf lib/providers/pdf_providers.dart`
Expected: no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/models/pdf_settings.dart lib/features/pdf/widgets/pdf_settings_sheet.dart lib/features/pdf/pdf_reader_screen.dart lib/providers/pdf_providers.dart test/pdf_settings_test.dart
git commit -m "feat(pdf): persist reader settings and last page"
```

---

### Task 12: CI test gate and honest wrap-up

**Files:**
- Modify: `.github/workflows/build-apk.yml` (insert a test step between «Analyze» and «Build release APK», around line 239)
- Modify: `docs/superpowers/specs/2026-10-25-pdf-tools-plus-design.md` (only if implementation revealed a changed fact; otherwise leave it)
- Test: the whole suite

- [ ] **Step 1: Add the CI step**

```yaml
      - name: Run tests
        run: flutter test
```

Place it before `Run analyze` (rename the existing `Analyze` step to `Run analyze` only if needed for readability).

- [ ] **Step 2: Run every local check**

Run: `$DART format --output=none --set-exit-if-changed lib tool test`
Run: `$DART analyze --fatal-infos`
Run: `$DART run tool/verify_pdf_library.dart`
Expected: no formatting changes, no analyzer issues, verifier exits 0. Record the exact output.

- [ ] **Step 3: Report what is unverified**

Write in the task commit message body (not the app) that `flutter test` and the Kotlin compilation were not run locally; CI is the only proof. Do not claim otherwise.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/build-apk.yml docs/superpowers/specs/2026-10-25-pdf-tools-plus-design.md
git commit -m "ci: run Flutter tests before building the APK"
```

---

## Plan 1 done when

- Importing PDFs through the picker produces library entries with thumbnails and page counts.
- The «ملفاتي» section and `/pdf-library` show Recent/All/Favorites with search, sort, grid/list, rename, delete, share, details.
- `/pdf-viewer?path=`, `docId`, and bytes all open the new reader; official books still open without entering the library.
- Pages render as viewport tiles, pinch zooms 1×–5× of fit-width, both scroll modes work, rotation and night mode work, and the scrubber reports «صفحة X من Y».
- Search finds text and jumps to the page; scanned documents say there is no text.
- Last page and reader settings survive a restart.
- `dart analyze --fatal-infos`, formatting, and `tool/verify_pdf_library.dart` are clean locally; `flutter test` and the Kotlin channel are proven only by CI and say so.
