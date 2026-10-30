# PDF Engine Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the twelve PDF-engine findings of the 2026-10-29 four-area review so a protected, corrupt, zero-page, or oversized document fails honestly instead of hanging, leaking a native renderer, or blocking the UI.

**Architecture:** Keep `PdfRenderer` in Kotlin as the only rasteriser and move every policy decision to Dart: passwords are unlocked into a session temp copy with Syncfusion (works on every Android version), the reader guards the handle lifecycle, the viewport bounds its own memory and render queue, and text search stops copying the whole file into the Dart heap. Kotlin changes stay small — close-on-failure, answer on `Throwable`, refuse a zero-page document.

**Tech Stack:** Flutter 3.x / Dart 3.13, Riverpod 2, `syncfusion_flutter_pdf` 35 (unlock + text), Android `PdfRenderer` via `MethodChannel('zaker/pdf_render')`.

**Spec:** `docs/superpowers/specs/2026-10-25-pdf-tools-plus-design.md` (the PDF engine design this plan argues from; lines 288–345 cover tiling, memory, passwords and extraction).

## Global Constraints

- Every user-facing string is Arabic with Latin digits, matching the file it lands in.
- Kotlin cannot be compiled here: no `android/settings.gradle`, no Gradle, no Android SDK. Every commit that touches `.kt` says so in one line of its message.
- Flutter tests cannot run here: no ARM64 engine, and CI is billing-blocked. The Dart gate is `dart analyze lib test` → `No issues found!`; a widget test's RED is observable only as a compile error (an undefined symbol) before the implementation exists. Say this in every commit body that adds a test.
- Dart SDK: `/data/data/com.termux/files/home/the-kili-project/work/dartsdk/dart-sdk/bin/dart`.
- Format only the files a task touched, and revert formatter-only hunks in pre-existing code (Dart 3.13 rewraps unrelated lines).
- Passwords live in memory only: never logged, never written into a file name, temp copies deleted on close and swept at startup.
- `close`-on-failure and channel answers must never throw on the Kotlin side: an exception in a channel handler takes the process down.

## Review Focus

- **A render fails and never answers.** Every native path that can fail (`open` after `descriptor` is taken, `render`, `Bitmap.createBitmap` on an `OutOfMemoryError`) must answer exactly one channel result, and the Dart side must retry a failed tile a bounded number of times.
- **A document with zero pages.** Anywhere `clamp` or a page index is derived from `pageCount`, page count 0 must produce a visible failure, not an `ArgumentError` inside `setState`.
- **A file that cannot be read or written.** Disk-full while materialising session bytes, a deleted library file, and a cache directory that cannot be created must surface «مفيش مساحة كافية…» rather than hanging on «بنفتح الملف…».
- **A protected document.** First open must ask for the password, a correct password must yield a readable temp copy on every Android version, a wrong one must re-prompt, and search must work on the same unlocked copy.
- **Memory under pressure.** A reader on a low-RAM device must drop tiles it is not showing without losing the page it is on.

---

### Task 1: Native renderer hygiene

**Files:**
- Modify: `android/app/src/main/kotlin/com/zaker/zaker_ai/PdfRenderChannel.kt:71-140` (`open`), `:142-216` (`render`)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `open` answers `corrupt` for a document with zero pages; `open` and `render` close everything they acquired when they fail; `render` answers `renderFailed` on any `Throwable`, including `OutOfMemoryError`.

- [ ] **Step 1: Refuse a zero-page document in `open`**

In `open`, after the `pages` loop and before building `payload`, add:

```kotlin
if (renderer.pageCount <= 0 || pages.isEmpty()) {
    // A PDF with no pages cannot be read; answering the empty handle would
    // make Dart clamp against a zero page count.
    try {
        renderer.close()
    } catch (_: Exception) {
    }
    try {
        descriptor?.close()
    } catch (_: Exception) {
    }
    main.post { result.error("corrupt", null, null) }
    return@execute
}
```

- [ ] **Step 2: Close the renderer when anything after creation fails**

Replace the declared `val renderer = try { ... }` with an outer `var` so the outer `catch` can reach it:

```kotlin
var renderer: PdfRenderer? = null
try {
    renderer = try {
        openRenderer(descriptor, password)
    } catch (error: SecurityException) { ... same body ... }
    ... pages loop, payload ...
} catch (error: Exception) {
    try {
        renderer?.close()
    } catch (_: Exception) {
    }
    try {
        descriptor?.close()
    } catch (_: Exception) {
    }
    main.post { result.error("corrupt", null, null) }
}
```

`renderer` is a `var` everywhere inside `try` after this; where Kotlin insists on a non-null local, use `val built = renderer ?: return@execute`.

- [ ] **Step 3: Answer on any `Throwable` in `render`**

Change the outer `catch (error: Exception)` of `render` to `catch (error: Throwable)` and keep the body (`main.post { result.error("renderFailed", null, null) }`). Add above it the same `Throwable` guard around the bitmap allocation only if `createBitmap` already sits inside the outer `try` — it does, so one catch covers it. A `Throwable` that is an `OutOfMemoryError` still answers; the allocator recovers once the bitmap is not retained.

- [ ] **Step 4: Verify by reading, and by the Dart gate**

Run: `dart analyze lib test`
Expected: `No issues found!` (Kotlin is not analysed here; the step exists so the branch's gate is run once per task).

Re-read `open` once end to end and confirm: every early `return@execute` has posted a result; no path both closes the descriptor and stores it in `descriptors`.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/zaker/zaker_ai/PdfRenderChannel.kt
git commit -m "$(cat <<'EOF'
fix(pdf): answer every native render failure and close what it opened

open() refused no page counts, and a failure after PdfRenderer was
constructed leaked the renderer and its descriptor; render() caught only
Exception, so an OutOfMemoryError never answered the awaiting Dart future.

Unbuilt: this checkout has no Gradle or Android SDK, so the Kotlin was
not compiled.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: A zero-page document fails cleanly

**Files:**
- Modify: `lib/features/pdf/pdf_reader_screen.dart:117-176` (`_open`)
- Test: `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: Task 1's `corrupt` answer from `open`.
- Produces: after a successful `open` whose `pageCount <= 0`, the reader closes the handle, sets `_failure = PdfRenderFailure.corrupt`, and `_loading = false`; `_handle` stays null.

- [ ] **Step 1: Write the failing test**

Append to `test/pdf_reader_screen_test.dart`:

```dart
  testWidgets('a document with no pages fails without leaking its handle', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 0);
    await pump(tester, channel, const PdfReaderScreen(path: '/tmp/empty.pdf'));

    expect(find.text('تعذّر فتح الملف'), findsOneWidget);
    expect(channel.closes, 1);

    await tester.tap(find.text('جرّب تاني'));
    await tester.pumpAndSettle();

    expect(channel.closes, 2, reason: 'each retry must release its own handle');
  });
```

- [ ] **Step 2: Run it to watch it fail**

Run: `dart analyze test/pdf_reader_screen_test.dart`
Expected: no error at this point (the test compiles against today's API). Confirm by reading that today `_page = lastPage.clamp(1, handle.pageCount) - 1` throws for `pageCount == 0` inside `setState`, so the screen settles on `unavailable` («قارئ PDF مش متاح على الجهاز ده.») and never closes the handle — the assertions above are the RED.

- [ ] **Step 3: Guard the handle in `_open`**

Immediately after `final handle = await _channel.open(...)` and the `if (!mounted)` block, insert:

```dart
      if (handle.pageCount <= 0) {
        // A zero-page file cannot be shown; keeping the handle would leak a
        // native renderer on every retry.
        unawaited(_channel.close(handle.id));
        setState(() {
          _handle = null;
          _loading = false;
          _failure = PdfRenderFailure.corrupt;
        });
        return;
      }
```

- [ ] **Step 4: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/pdf/pdf_reader_screen.dart test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): refuse a zero-page document instead of clamping to page 1

lastPage.clamp(1, 0) throws inside setState, so a broken file reported
"reader unavailable" and kept the native handle, leaking a renderer per
retry. The handle is now closed and the file reported as corrupt.

The test has not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Storage failures are visible

**Files:**
- Modify: `lib/core/pdf/pdf_render_channel.dart:33-54` (enum), `:133-142` (mapping)
- Modify: `lib/features/pdf/pdf_reader_screen.dart:117-176` (`_open`, `_resolvePath` call), `:536-546` (`_failureMessage`)
- Modify: `lib/features/pdf/widgets/pdf_import_button.dart:79-87`
- Test: `test/pdf_render_channel_test.dart`, `test/pdf_import_message_test.dart` (create), `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `PdfRenderFailure.storage` (new enum value mapped from the platform code `storage`); `String pdfImportMessage({required int added, required List<PdfImportFailure> failures})` exported from `pdf_import_button.dart`.

- [ ] **Step 1: Write the failing tests**

In `test/pdf_render_channel_test.dart`, append:

```dart
  test('a storage platform error becomes a typed failure', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'storage');
    });

    await expectLater(
      const PdfRenderChannel().open('/docs/a.pdf'),
      throwsA(
        isA<PdfRenderException>().having(
          (error) => error.failure,
          'failure',
          PdfRenderFailure.storage,
        ),
      ),
    );
  });
```

Create `test/pdf_import_message_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/features/pdf/widgets/pdf_import_button.dart';

void main() {
  test('a pass rejected for space says so instead of "not a PDF"', () {
    expect(
      pdfImportMessage(
        added: 0,
        failures: const [PdfImportFailure.storage],
      ),
      'مفيش مساحة كافية على الجهاز — الملفات ما اتضافتش.',
    );
  });

  test('a pass rejected as non-PDF keeps the format message', () {
    expect(
      pdfImportMessage(
        added: 0,
        failures: const [PdfImportFailure.invalidHeader],
      ),
      'مفيش ملفات اتضافت — اتأكد إنهم PDF.',
    );
  });

  test('a mixed pass reports both counts', () {
    expect(
      pdfImportMessage(added: 2, failures: const [PdfImportFailure.storage]),
      'تمت إضافة 2 ملف، و1 ملف اتترفض.',
    );
  });
}
```

In `test/pdf_reader_screen_test.dart`, append:

```dart
  testWidgets('a renderer that cannot write session bytes reports storage', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 3);
    final brokenStore = PdfLibraryStore(
      rootDir: root,
      cacheDir: Directory('/proc/zaker_no_such_cache'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdfRenderChannelProvider.overrideWithValue(channel),
          pdfLibraryStoreProvider.overrideWithValue(brokenStore),
          pdfLibraryControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: ZakerTheme.light(),
          home: PdfReaderScreen(bytes: Uint8List.fromList([1, 2, 3])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مفيش مساحة كافية على الجهاز.'), findsOneWidget);
    expect(channel.opens, 0);
  });
```

- [ ] **Step 2: Run the gate to see the compile-level RED**

Run: `dart analyze test`
Expected: `undefined_identifier` / `undefined_getter` for `PdfRenderFailure.storage` and `pdfImportMessage`, and the reader test cannot compile until the message exists.

- [ ] **Step 3: Add the enum, the mapping and the reader guard**

`pdf_render_channel.dart` — add to the enum after `renderFailed`:

```dart
  /// The document could not be read from or written to disk.
  storage,
```

and to `_failureFor`:

```dart
      'storage' => PdfRenderFailure.storage,
```

`pdf_reader_screen.dart` — wrap the resolve in `_open`:

```dart
    final String? path;
    try {
      path = _resolvePath();
    } on FileSystemException {
      setState(() {
        _loading = false;
        _failure = PdfRenderFailure.storage;
      });
      return;
    }
```

(`_writeSessionFile` runs inside `_resolvePath`, which is where a full disk throws.)

Add to `_failureMessage`:

```dart
      PdfRenderFailure.storage => 'مفيش مساحة كافية على الجهاز.',
```

`pdf_import_button.dart` — replace the inline `switch` with a call to the new exported function:

```dart
/// The snack-bar line for one import pass.
String pdfImportMessage({
  required int added,
  required List<PdfImportFailure> failures,
}) {
  final rejected = failures.length;
  if (added == 0 &&
      rejected > 0 &&
      failures.every((failure) => failure == PdfImportFailure.storage)) {
    return 'مفيش مساحة كافية على الجهاز — الملفات ما اتضافتش.';
  }
  return switch ((added, rejected)) {
    (0, _) => 'مفيش ملفات اتضافت — اتأكد إنهم PDF.',
    (_, 0) => 'تمت إضافة $added ملف.',
    _ => 'تمت إضافة $added ملف، و$rejected ملف اتترفض.',
  };
}
```

and in `importPdfFiles`:

```dart
  final message = pdfImportMessage(added: added, failures: result.failures);
```

`PdfImportFailure` is already exported from `pdf_library_store.dart`; add that import if the file lacks it.

- [ ] **Step 4: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/pdf/pdf_render_channel.dart lib/features/pdf/pdf_reader_screen.dart \
  lib/features/pdf/widgets/pdf_import_button.dart test/pdf_render_channel_test.dart \
  test/pdf_import_message_test.dart test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): report an unwritable disk instead of hanging or blaming the format

_resolvePath ran outside the try, so a full disk left the reader on
"بنفتح الملف…" forever, and every rejected import was blamed on the file
not being a PDF even when the store had failed to write.

The tests have not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: A failed tile is retried, a hopeless one is marked

**Files:**
- Modify: `lib/features/pdf/widgets/pdf_reader_viewport.dart:384-450` (`_requestTile`, `_paint`)
- Test: `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `PdfReaderViewportState.failedTilePages` (`Set<int>`, `@visibleForTesting`); a failed render clears its reserved key and retries at most `_maxTileAttempts` (2) times, 400 ms apart.

- [ ] **Step 1: Give the fake channel a way to fail**

In `test/pdf_reader_screen_test.dart`, add to `FakeChannel`:

```dart
  /// How many upcoming `render` calls throw before one succeeds.
  int failRenders = 0;
```

and in `render`, before `return _onePixelPng;`:

```dart
    if (failRenders > 0) {
      failRenders -= 1;
      throw const PdfRenderException(PdfRenderFailure.renderFailed);
    }
```

- [ ] **Step 2: Write the failing test**

Append to `test/pdf_reader_screen_test.dart`:

```dart
  testWidgets('a tile that fails renders is retried and then shown', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 1)..failRenders = 1;
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _portraitViewport(),
    );
    expect(find.byType(Image), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(channel.renders, hasLength(2));
    expect(find.byType(Image), findsWidgets);
  });
```

- [ ] **Step 3: Run the gate to watch it fail**

Run: `dart analyze test/pdf_reader_screen_test.dart`
Expected: compiles; the RED is behavioural — today `catchError` keeps `_requestedKeys[index]` reserved forever, so `channel.renders` stays at 1 and no `Image` ever appears.

- [ ] **Step 4: Implement the retry**

Add near the top of `PdfReaderViewportState`:

```dart
  /// How many times a tile render may be retried before it is marked failed.
  static const int _maxTileAttempts = 2;
```

Add fields beside `_requestGenerations`:

```dart
  final Map<int, int> _tileAttempts = {};
  final Set<int> _failedTiles = {};
  final Set<Timer> _retryTimers = {};

  /// Pages whose tile could not be rendered at all. Test hook.
  @visibleForTesting
  Set<int> get failedTilePages => Set.unmodifiable(_failedTiles);
```

Replace the `catchError` body in `_requestTile` with:

```dart
          .catchError((Object _) {
            if (!mounted || _requestGenerations[index] != generation) return;
            _retryTile(index);
          }),
```

and add:

```dart
  /// Retries a tile that failed to render, a bounded number of times.
  ///
  /// The key stays reserved, so [_requestTile] will not spin on it; clearing
  /// it here is what lets the next attempt through.
  void _retryTile(int index) {
    _requestedKeys.remove(index);
    final attempts = (_tileAttempts[index] ?? 0) + 1;
    _tileAttempts[index] = attempts;
    if (attempts > _maxTileAttempts) {
      setState(() => _failedTiles.add(index));
      return;
    }
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 400), () {
      _retryTimers.remove(timer);
      if (!mounted) return;
      final viewport = _lastViewport;
      if (viewport == null) return;
      _requestTile(index, viewport);
    });
    _retryTimers.add(timer);
  }
```

Cancel the timers and clear the maps in `dispose`:

```dart
    for (final timer in _retryTimers) {
      timer.cancel();
    }
    _retryTimers.clear();
```

In `_releaseOffscreenTiles`, also drop `_tileAttempts`/`_failedTiles` for pages that left the screen, so scrolling back retries instead of showing a permanent hole:

```dart
    _tileAttempts.removeWhere((index, _) => !keep.contains(index));
    _failedTiles.removeWhere((index) => !keep.contains(index));
```

- [ ] **Step 5: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/pdf/widgets/pdf_reader_viewport.dart test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): retry a tile that failed to render

A failed render left its key in _requestedKeys, so the placeholder stayed
blank for the page's whole lifetime and no second attempt was ever made.
Failed tiles now retry twice, 400 ms apart, and are marked after that.

The test has not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Page mode renders the visible region

**Files:**
- Modify: `lib/features/pdf/widgets/pdf_reader_viewport.dart:222-240` (`_singlePages`), `:384-404` (`_requestTile`)
- Test: `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: `PdfPageGeometry.visibleSource(...)` and `PdfPageGeometry.unrotateSource(...)`, both existing.
- Produces: in single-page mode the requested source follows the inner scroll offsets instead of always being the whole page.

- [ ] **Step 1: Write the failing test**

Append to `test/pdf_reader_screen_test.dart`:

```dart
  testWidgets('page mode requests the visible region when zoomed in', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 3);
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: PdfReaderViewport(
        handle: _handle(3),
        geometry: List.filled(
          3,
          const PdfPageGeometry(widthPoints: 595, heightPoints: 842),
        ),
        initialPage: 0,
        onPageChanged: (_) {},
        vertical: false,
        initialZoom: 5,
      ),
    );

    final call = channel.renders.first;
    expect(call.source.width, lessThan(0.5));
    expect(call.source.height, lessThan(0.6));
  });
```

- [ ] **Step 2: Run the gate to watch it fail**

Run: `dart analyze test/pdf_reader_screen_test.dart`
Expected: compiles; the RED is behavioural — today the page-mode branch returns `const NormalizedRect(0, 0, 1, 1)`, so `source.width` is 1 and the first expectation fails.

- [ ] **Step 3: Track the page-mode scroll offsets**

Add fields beside `_lastViewport`:

```dart
  /// How far the single-page view has scrolled into the current page.
  double _pageScrollX = 0;
  double _pageScrollY = 0;
```

Wrap the two scroll views in `_singlePages` with one notification listener that records both axes:

```dart
      itemBuilder: (context, index) => Center(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (index != _page) return false;
            final metrics = notification.metrics;
            if (metrics.axis == Axis.horizontal) {
              _pageScrollX = metrics.pixels;
            } else {
              _pageScrollY = metrics.pixels;
            }
            return false;
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(child: _pageView(index)),
          ),
        ),
      ),
```

and reset both to zero when the shown page changes, in `_jumpToPage` and in the `PageView.onPageChanged` callback:

```dart
        _pageScrollX = 0;
        _pageScrollY = 0;
```

- [ ] **Step 4: Use the same visible-source maths in both modes**

In `_requestTile`, replace the ternary with:

```dart
    final scrollX = widget.vertical
        ? (_horizontalScroll.hasClients ? _horizontalScroll.offset : 0.0) -
            _pageLeft(index)
        : _pageScrollX;
    final scrollY = widget.vertical
        ? (_verticalScroll.hasClients ? _verticalScroll.offset : 0.0) -
            _pageTop(index)
        : _pageScrollY;
    final source = PdfPageGeometry.unrotateSource(
      display.visibleSource(
        scrollX: scrollX,
        scrollY: scrollY,
        viewportWidth: viewport.width,
        viewportHeight: viewport.height,
        fitScale: _fitScale,
        zoom: _zoom,
      ),
      widget.quarterTurns,
    );
```

`visibleSource` clamps a page smaller than the viewport to the whole page, which is exactly the page-mode case at `zoom == 1`, so the existing full-page request is preserved there.

- [ ] **Step 5: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/pdf/widgets/pdf_reader_viewport.dart test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): render the visible region in single-page mode too

Page mode always asked for NormalizedRect(0,0,1,1) and relied on the
2048-pixel cap, so a page at 500% came back at the cap and looked blurred.
The page-mode scroll offsets now feed the same visibleSource maths the
continuous mode uses.

The test has not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Bounded tile memory and a memory-pressure handler

**Files:**
- Modify: `lib/core/pdf/pdf_tile_cache.dart:70`
- Modify: `lib/features/pdf/widgets/pdf_reader_viewport.dart:84-157` (state, `initState`, `dispose`)
- Test: `test/pdf_reader_screen_test.dart`, `tool/verify_pdf_library.dart` (no change expected)

**Interfaces:**
- Consumes: `PdfTileCache.bytes` and `PdfTileCache.clear()`, both existing.
- Produces: `PdfReaderViewportState` is a `WidgetsBindingObserver`; `@visibleForTesting void handleMemoryPressure()` drops cached tiles, decoded tiles and Flutter's image cache; the default `PdfTileCache` budget is 48 MiB.

- [ ] **Step 1: Write the failing test**

Append to `test/pdf_reader_screen_test.dart`:

```dart
  testWidgets('memory pressure drops the tiles this reader holds', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 1);
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _portraitViewport(),
    );
    final state = tester.state<PdfReaderViewportState>(
      find.byType(PdfReaderViewport),
    );
    expect(state.retainedTilePages, contains(0));
    expect(state.cachedTileBytes, greaterThan(0));

    state.handleMemoryPressure();
    await tester.pump();

    expect(state.retainedTilePages, isEmpty);
    expect(state.cachedTileBytes, 0);
  });
```

- [ ] **Step 2: Run the gate to watch it fail**

Run: `dart analyze test/pdf_reader_screen_test.dart`
Expected: `undefined_method` for `handleMemoryPressure` and `undefined_getter` for `cachedTileBytes`.

- [ ] **Step 3: Implement the observer**

```dart
class PdfReaderViewportState extends ConsumerState<PdfReaderViewport>
    with WidgetsBindingObserver {
```

Expose the budget for the test:

```dart
  /// Bytes held by the tile cache. Test hook.
  @visibleForTesting
  int get cachedTileBytes => _cache.bytes;
```

Register and unregister:

```dart
    WidgetsBinding.instance.addObserver(this);   // in initState
    WidgetsBinding.instance.removeObserver(this); // in dispose
```

Add the handler:

```dart
  @override
  void didHaveMemoryPressure() {
    handleMemoryPressure();
  }

  /// Drops everything this reader can rebuild from the native renderer.
  ///
  /// The pages in flight are unaffected: their results are cached and painted
  /// again on arrival, so a pressure drop never leaves a blank visible page.
  @visibleForTesting
  void handleMemoryPressure() {
    _cache.clear();
    _tiles.clear();
    _tileSources.clear();
    _requestedKeys.clear();
    _failedTiles.clear();
    _tileAttempts.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (mounted) setState(() {});
  }
```

- [ ] **Step 4: Lower the default budget**

In `pdf_tile_cache.dart`:

```dart
  PdfTileCache({this.maxBytes = 48 * 1024 * 1024});
```

Rationale to keep in the doc comment: two visible tiles at the 2048-pixel cap are ~12 MiB each decoded, so 48 MiB keeps the current page and a prefetch neighbour without competing with Flutter's own 100 MiB image cache.

- [ ] **Step 5: Check the pure-Dart harness still agrees**

Run: `dart run tool/verify_pdf_library.dart`
Expected: ends with its success line and no `FAILED` entries (it constructs its own caches with explicit budgets, so the default change is inert there).

- [ ] **Step 6: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/pdf/pdf_tile_cache.dart lib/features/pdf/widgets/pdf_reader_viewport.dart \
  test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): bound the tile cache and honour memory pressure

A reader could hold 96 MiB of tiles plus Flutter's 100 MiB image cache,
and the design's promise to drop tiles under pressure had no
implementation. The budget is now 48 MiB and didHaveMemoryPressure drops
this reader's tiles and the image cache.

The test has not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Search stops copying the file and stops extracting twice

**Files:**
- Modify: `lib/core/pdf/pdf_text_map.dart:51-123` (`fromBytes`, `search`, `_open`)
- Modify: `lib/features/pdf/pdf_reader_screen.dart:343-361` (`_openSearch`)
- Test: `test/pdf_text_map_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `PdfTextMap.fromFile(File file, {required int pageCount, String? password})`; `search()` performs one extraction pass and never copies the file into a `Uint8List`.

- [ ] **Step 1: Write the failing test**

Append to `test/pdf_text_map_test.dart` (it already builds real PDFs):

```dart
  test('fromFile searches the file without loading its bytes', () async {
    final directory = Directory.systemTemp.createTempSync('zaker_pdf_text_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/two.pdf')
      ..writeAsBytesSync(await _twoPageDocument());

    final map = PdfTextMap.fromFile(file, pageCount: 2);

    final matches = await map.search('physics');
    expect(matches, hasLength(1));
    expect(matches.single.pageIndex, 1);
  });
```

Add `import 'dart:io';` to that test file.

- [ ] **Step 2: Run the gate to watch it fail**

Run: `dart analyze test/pdf_text_map_test.dart`
Expected: `undefined_named_parameter` / `member_not_found` for `PdfTextMap.fromFile`.

- [ ] **Step 3: Add the file-backed constructor**

```dart
  PdfTextMap.fromBytes(this._bytes, {String? password, required this.pageCount})
    : _file = null,
      _password = password;

  /// Reads the page text straight from [file].
  ///
  /// Nothing is copied into the Dart heap: Syncfusion opens the path itself,
  /// so a 200 MB document costs the extractor's own buffer, not another copy.
  PdfTextMap.fromFile(File file, {required this.pageCount, String? password})
    : _file = file,
      _bytes = null,
      _password = password;

  final Uint8List? _bytes;
  final File? _file;
```

Add `import 'dart:io';` and make `_open`:

```dart
  sf.PdfDocument? _open() {
    try {
      final file = _file;
      if (file != null) {
        return sf.PdfDocument(inputFile: file, password: _password);
      }
      return sf.PdfDocument(inputBytes: _bytes, password: _password);
    } on Object {
      return null;
    }
  }
```

- [ ] **Step 4: Drop the duplicate extraction inside `search`**

Delete `if (!await hasAnyText()) return const [];` from `search`. The search sheet already calls `hasAnyText()` once to decide its empty state, so the pass would otherwise extract every page twice. Update the doc comment: "An empty query and an unreadable document return no matches; the caller decides whether to say the document has no text."

- [ ] **Step 5: Use it from the reader**

In `_openSearch`:

```dart
    final file = File(path);
    if (!file.existsSync()) return;
    final textMap = PdfTextMap.fromFile(file, pageCount: handle.pageCount);
```

and move the `if (!mounted) return;` after `showPdfSearchSheet`'s call site needs it? It is no longer needed before constructing the map (nothing awaits); keep the existing `if (!mounted) return;` immediately before `await showPdfSearchSheet(...)`.

The reader's import of `dart:typed_data` may become unused if `bytes:` no longer feeds `readAsBytes`; remove it only if the analyzer says so.

- [ ] **Step 6: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/pdf/pdf_text_map.dart lib/features/pdf/pdf_reader_screen.dart \
  test/pdf_text_map_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): open search straight from the file and extract it once

The reader read the whole document into a Uint8List and search then ran
two full extraction passes over it on the UI isolate, one from
hasAnyText() and one from search(). Search now opens the path itself and
the duplicate pass is gone; the sheet still asks hasAnyText() once.

The test has not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Protected documents open on every Android version

**Files:**
- Create: `lib/core/pdf/pdf_unlock.dart`
- Modify: `lib/providers/pdf_providers.dart` (new `pdfUnlockerProvider`)
- Modify: `lib/features/pdf/pdf_reader_screen.dart:73-262` (state, `dispose`, `_open`, `_promptPassword`, `_resolvePath`, `_shareFile`)
- Test: `test/pdf_unlock_test.dart` (create), `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: `PdfLibraryStore.sessionTempFile(String id)`, `PdfRenderFailure.storage` from Task 3.
- Produces: `typedef PdfUnlocker = Future<bool> Function({required File input, required String password, required File output});`, the default `unlockPdfTo` in `pdf_unlock.dart`, and the provider `pdfUnlockerProvider`. The reader routes every password through the unlocker and opens the decrypted copy, so `PdfRenderChannel.open` is never given a password.

- [ ] **Step 1: Write the failing unlock test**

Create `test/pdf_unlock_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../lib/core/pdf/pdf_unlock.dart';

/// A one-page document locked with «secret».
Future<List<int>> _lockedDocument() async {
  final document = sf.PdfDocument();
  document.pages.add();
  document.security.userPassword = 'secret';
  final bytes = await document.save();
  document.dispose();
  return bytes;
}

void main() {
  test('a correct password writes a copy that opens without one', () async {
    final directory = Directory.systemTemp.createTempSync('zaker_pdf_unlock_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('${directory.path}/locked.pdf')
      ..writeAsBytesSync(await _lockedDocument());
    final output = File('${directory.path}/open.pdf');

    final unlocked = await unlockPdfTo(
      input: input,
      password: 'secret',
      output: output,
    );

    expect(unlocked, isTrue);
    final document = sf.PdfDocument(inputFile: output);
    expect(document.pages.count, 1);
    document.dispose();
  });

  test('a wrong password writes nothing', () async {
    final directory = Directory.systemTemp.createTempSync('zaker_pdf_unlock_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('${directory.path}/locked.pdf')
      ..writeAsBytesSync(await _lockedDocument());
    final output = File('${directory.path}/open.pdf');

    final unlocked = await unlockPdfTo(
      input: input,
      password: 'nope',
      output: output,
    );

    expect(unlocked, isFalse);
    expect(output.existsSync(), isFalse);
  });
}
```

- [ ] **Step 2: Write the failing reader test**

In `test/pdf_reader_screen_test.dart`, add a fake unlocker and rewrite the two password tests. In `FakeChannel`, add:

```dart
  /// Paths passed to `open`, in order.
  final List<String> paths = [];
```

and record `paths.add(path);` as the first line of `open`.

Add to `main`:

```dart
  Future<bool> unlock({
    required File input,
    required String password,
    required File output,
  }) async {
    if (password != 'secret') return false;
    await output.writeAsBytes(await input.readAsBytes());
    return true;
  }
```

and give the `pump` helper an override: `pdfUnlockerProvider.overrideWithValue(unlock)`.

Replace the test `'a locked document asks for the password and reopens with it'` with:

```dart
  testWidgets('a locked document opens the unlocked copy it wrote', (
    tester,
  ) async {
    final source = File('${root.path}/locked.pdf')
      ..writeAsBytesSync('%PDF-1.7'.codeUnits);
    final channel = FakeChannel(
      pageCount: 3,
      failures: [PdfRenderFailure.passwordRequired],
    );
    await pump(tester, channel, PdfReaderScreen(path: source.path));

    expect(find.text('الملف محمي بكلمة سر'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(channel.passwords, [null, null]);
    expect(channel.paths.first, source.path);
    expect(channel.paths.last, isNot(source.path));
    expect(find.text('صفحة 1 من 3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(channel.closes, 1);
    expect(store.sessionTempDir.listSync(), isEmpty);
  });
```

and the test `'three wrong passwords still allow a fresh retry'` keeps its shape but uses the unlocker: `FakeChannel(pageCount: 3, failures: List.filled(4, PdfRenderFailure.passwordRequired))`.

- [ ] **Step 3: Run the gate to watch it fail**

Run: `dart analyze test`
Expected: `undefined_identifier` for `unlockPdfTo`, `pdfUnlockerProvider`, `File` (add `dart:io` is already imported in the reader test) and `paths`.

- [ ] **Step 4: Implement the unlocker**

Create `lib/core/pdf/pdf_unlock.dart`:

```dart
/// Turns a password-protected PDF into a plain one for the native renderer.
///
/// `PdfRenderer` only accepts a password from Android 15 (API 35), so below
/// that a correct password could not unlock anything. Syncfusion can decrypt
/// on every version, into the session temp directory, and the copy is deleted
/// when the reader closes and swept at the next start.
library;

import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Writes an unlocked copy of [input] to [output].
typedef PdfUnlocker =
    Future<bool> Function({
      required File input,
      required String password,
      required File output,
    });

/// The real [PdfUnlocker]: Syncfusion decrypts in memory and saves.
///
/// Returns false for a wrong password (or a file that cannot be decrypted at
/// all). Nothing is written in that case, so a failed attempt never leaves a
/// half-open copy behind. Filesystem errors propagate: the caller turns them
/// into a storage failure.
Future<bool> unlockPdfTo({
  required File input,
  required String password,
  required File output,
}) async {
  sf.PdfDocument document;
  try {
    document = sf.PdfDocument(inputFile: input, password: password);
  } on Object {
    return false;
  }
  try {
    final bytes = await document.save();
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes, flush: true);
  } finally {
    document.dispose();
  }
  return true;
}
```

- [ ] **Step 5: Add the provider**

In `lib/providers/pdf_providers.dart`:

```dart
/// Decrypts a protected document into a session temp copy.
///
/// Overridden in tests so reader flows never depend on real crypto.
final pdfUnlockerProvider = Provider<PdfUnlocker>((ref) => unlockPdfTo);
```

with `import '../core/pdf/pdf_unlock.dart';`.

- [ ] **Step 6: Route the reader through it**

Fields:

```dart
  File? _unlockedFile;
  late final PdfUnlocker _unlocker;
```

In `initState`: `_unlocker = ref.read(pdfUnlockerProvider);`.

In `dispose`, delete `_unlockedFile` the same way `_sessionFile` is deleted (one helper `_deleteQuietly(File?)` used by both).

`_resolvePath` becomes:

```dart
  String? _resolvePath() {
    final unlocked = _unlockedFile;
    if (unlocked != null && unlocked.existsSync()) return unlocked.path;
    return _sourcePath();
  }

  /// The file the user opened, before any decryption.
  String? _sourcePath() {
    // ... the existing body of _resolvePath ...
  }
```

`_shareFile` uses `_sourcePath()` — never the decrypted copy.

`_open` loses its `password` parameter; the password path now goes through `_unlockWith`:

```dart
  Future<void> _unlockWith(String password) async {
    final source = _sourcePath();
    if (source == null) {
      setState(() {
        _loading = false;
        _failure = PdfRenderFailure.corrupt;
      });
      return;
    }
    final store = ref.read(pdfLibraryStoreProvider);
    final noise = Random.secure().nextInt(1 << 24).toRadixString(16);
    final target = store.sessionTempFile(
      'unlocked-${DateTime.now().microsecondsSinceEpoch}-$noise',
    );
    final bool unlocked;
    try {
      unlocked = await _unlocker(
        input: File(source),
        password: password,
        output: target,
      );
    } on FileSystemException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failure = PdfRenderFailure.storage;
      });
      return;
    }
    if (!mounted) return;
    if (!unlocked) {
      _deleteQuietly(target);
      await _promptPassword(wrong: true);
      return;
    }
    _deleteQuietly(_unlockedFile);
    _unlockedFile = target;
    await _open();
  }
```

`_promptPassword({required bool wrong})` keeps its three-attempt counter and, instead of `_open(password: password)`, calls `await _unlockWith(password)`; it also no longer treats `wrongPassword` from the channel as its input — `_open`'s `PdfRenderException` switch keeps `passwordRequired` and `wrongPassword` both funnel into `await _promptPassword(wrong: ...)`.

- [ ] **Step 7: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/core/pdf/pdf_unlock.dart lib/providers/pdf_providers.dart \
  lib/features/pdf/pdf_reader_screen.dart test/pdf_unlock_test.dart \
  test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): unlock protected documents on every Android version

PdfRenderer only takes a password from Android 15, so below it a correct
password was rejected outright and search ran on the encrypted bytes and
found nothing. The reader now decrypts into a session temp copy with
Syncfusion, renders and searches that copy, and deletes it on close;
sharing still hands over the original protected file.

The tests have not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Session restore is real

**Files:**
- Modify: `lib/models/pdf_document.dart:32-200` (`PdfDocumentEntry`)
- Modify: `lib/core/pdf/pdf_library_controller.dart:193-204` (`markOpened`)
- Modify: `lib/core/pdf/pdf_library_index.dart:75-82` (delete `pruneMissing`)
- Modify: `tool/verify_pdf_library.dart:195-196` (drop the deleted check)
- Modify: `lib/features/pdf/pdf_reader_screen.dart` (restore zoom/rotation, flush on dispose)
- Modify: `lib/features/pdf/widgets/pdf_reader_viewport.dart:37-49` (`onZoomChanged`)
- Test: `test/pdf_library_controller_test.dart`, `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: `PdfDocumentEntry.lastPage`, existing.
- Produces: `PdfDocumentEntry.lastZoom` (`double`, default 1, clamped 1–5) and `PdfDocumentEntry.lastQuarterTurns` (`int`, default 0, `% 4`); `markOpened(String id, {int? page, double? zoom, int? quarterTurns})`; `PdfReaderViewport.onZoomChanged` (`ValueChanged<double>?`).

- [ ] **Step 1: Write the failing model and controller tests**

In `test/pdf_library_controller_test.dart`, add:

```dart
  test('markOpened keeps the zoom and rotation the reader restored', () async {
    final controller = _controller();
    await controller.import([_source('a')]);
    final id = controller.state.entries.single.id;

    await controller.markOpened(id, page: 4, zoom: 2.5, quarterTurns: 1);

    final entry = controller.state.entryById(id)!;
    expect(entry.lastPage, 4);
    expect(entry.lastZoom, 2.5);
    expect(entry.lastQuarterTurns, 1);
  });

  test('an entry round-trips its reading position through JSON', () {
    final entry = _entry().copyWith(
      lastZoom: 3,
      lastQuarterTurns: 2,
    );

    final restored = PdfDocumentEntry.fromJson(entry.toJson());

    expect(restored.lastZoom, 3);
    expect(restored.lastQuarterTurns, 2);
  });

  test('a stored zoom outside 1..5 is clamped on load', () {
    final json = _entry().toJson()
      ..['lastZoom'] = 9.0
      ..['lastQuarterTurns'] = 6;

    final restored = PdfDocumentEntry.fromJson(json);

    expect(restored.lastZoom, 5);
    expect(restored.lastQuarterTurns, 2);
  });
```

Reuse whatever helpers that file already has for controller/entry construction; if it has none, build a `PdfLibraryController` the way `pdf_reader_screen_test.dart` does and an entry with `PdfDocumentEntry(id: 'a', ...)`.

- [ ] **Step 2: Write the failing reader tests**

Append to `test/pdf_reader_screen_test.dart`:

```dart
  testWidgets('reopening restores the page, zoom and rotation', (tester) async {
    final index = PdfLibraryIndex([
      PdfDocumentEntry(
        id: 'doc',
        displayName: 'ملف',
        baseFileName: 'doc.pdf',
        sizeBytes: 10,
        pageCount: 10,
        addedAt: DateTime(2026),
        lastPage: 4,
        lastZoom: 2,
        lastQuarterTurns: 1,
      ),
    ]);
    controller = PdfLibraryController(
      store: store,
      repository: PdfLibraryRepository(
        MemoryStore()
          ..values[PdfLibraryRepository.storeKey] = jsonEncode(index.toJson()),
      ),
      probe: (file) async => const PdfProbeResult(pageCount: 10),
      thumbnailer: (base, thumb) async {},
      newId: () => 'doc',
    );
    store.baseFile('doc').writeAsBytesSync('%PDF-1.7'.codeUnits);

    final channel = FakeChannel(pageCount: 10);
    await pump(tester, channel, const PdfReaderScreen(docId: 'doc'));

    expect(find.text('صفحة 4 من 10'), findsOneWidget);
    final viewport = tester.widget<PdfReaderViewport>(
      find.byType(PdfReaderViewport),
    );
    expect(viewport.initialZoom, 2);
    expect(viewport.quarterTurns, 1);
  });

  testWidgets('leaving immediately still saves the page', (tester) async {
    controller = PdfLibraryController(
      store: store,
      repository: PdfLibraryRepository(
        MemoryStore()
          ..values[PdfLibraryRepository.storeKey] = jsonEncode(
            PdfLibraryIndex([
              PdfDocumentEntry(
                id: 'doc',
                displayName: 'ملف',
                baseFileName: 'doc.pdf',
                sizeBytes: 10,
                pageCount: 10,
                addedAt: DateTime(2026),
              ),
            ]).toJson(),
          ),
      ),
      probe: (file) async => const PdfProbeResult(pageCount: 10),
      thumbnailer: (base, thumb) async {},
      newId: () => 'doc',
    );
    store.baseFile('doc').writeAsBytesSync('%PDF-1.7'.codeUnits);
    final channel = FakeChannel(pageCount: 10);
    await pump(tester, channel, const PdfReaderScreen(docId: 'doc'));
    expect(controller.state.entryById('doc')!.lastOpenedAt, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(controller.state.entryById('doc')!.lastOpenedAt, isNotNull);
  });
```

Add the imports those tests need (`dart:convert`, `PdfLibraryIndex`, `PdfDocumentEntry`) — `pdf_reader_screen_test.dart` already imports `dart:convert` and the repository.

- [ ] **Step 3: Run the gate to watch it fail**

Run: `dart analyze test`
Expected: `undefined_named_parameter` for `zoom`/`quarterTurns`, `undefined_getter` for `lastZoom`/`lastQuarterTurns`.

- [ ] **Step 4: Extend the entry**

In `PdfDocumentEntry`: fields `final double lastZoom;` (default 1) and `final int lastQuarterTurns;` (default 0); `copyWith` parameters; `toJson` keys `lastZoom` and `lastQuarterTurns`; `fromJson` with clamping:

```dart
      lastZoom: ((json['lastZoom'] as num?)?.toDouble() ?? 1)
          .clamp(1.0, 5.0)
          .toDouble(),
      lastQuarterTurns: ((json['lastQuarterTurns'] as num?)?.toInt() ?? 0) % 4,
```

`%` on a negative int in Dart yields a non-negative result, so a corrupt negative value lands back on 0–3.

- [ ] **Step 5: Extend `markOpened`**

```dart
  Future<void> markOpened(
    String id, {
    int? page,
    double? zoom,
    int? quarterTurns,
  }) async {
    final entry = _entry(id);
    if (entry == null) return;
    await _commit(
      state.upsert(
        entry.copyWith(
          lastOpenedAt: DateTime.now(),
          lastPage: page == null || page < 1 ? entry.lastPage : page,
          lastZoom: zoom?.clamp(1.0, 5.0).toDouble(),
          lastQuarterTurns: quarterTurns == null
              ? null
              : quarterTurns % 4,
        ),
      ),
    );
  }
```

- [ ] **Step 6: Delete the dead prune**

Remove `pruneMissing` from `PdfLibraryIndex` and the two lines at `tool/verify_pdf_library.dart:195-196`. The library deliberately keeps entries whose file vanished (the card shows «الملف مش موجود»), so a helper that drops them contradicts `refresh()`'s documented behaviour and only the verify tool ever called it.

- [ ] **Step 7: Report zoom from the viewport**

Add to `PdfReaderViewport`:

```dart
  /// Called when pinch zoom changes the scale.
  final ValueChanged<double>? onZoomChanged;
```

Call `widget.onZoomChanged?.call(next)` at the end of `_onPointerMove` (after `setState`), and `widget.onZoomChanged?.call(_zoom)` in `didUpdateWidget` when `initialZoom` changed.

- [ ] **Step 8: Restore and flush in the reader**

- `initState`: seed `_quarterTurns = entry?.lastQuarterTurns ?? 0` — but `_entry` needs a provider, so seed it in `_open` next to `_page`, from `entry.lastQuarterTurns`, and pass `_zoom` from `entry.lastZoom`:

```dart
        _page = lastPage.clamp(1, handle.pageCount) - 1;
        _quarterTurns = entry?.lastQuarterTurns ?? 0;
        _zoom = entry?.lastZoom ?? 1;
```

with a new field `double _zoom = 1;` and `initialZoom: _zoom` on the viewport, `onZoomChanged: (value) { _zoom = value; _scheduleMarkOpened(); }`.

- `_scheduleMarkOpened` passes everything: `.markOpened(id, page: _page + 1, zoom: _zoom, quarterTurns: _quarterTurns)`.
- Capture the notifier in `initState` — `_library = ref.read(pdfLibraryControllerProvider.notifier)` — and in `dispose`, before `super.dispose()`, cancel `_markTimer` and call `unawaited(_library.markOpened(id, page: _page + 1, zoom: _zoom, quarterTurns: _quarterTurns))` when `widget.docId != null`.
- The rotate action (`onRotate`) updates `_quarterTurns` and calls `_scheduleMarkOpened()`.

- [ ] **Step 9: Run the gates**

Run: `dart run tool/verify_pdf_library.dart`
Expected: success line, no `FAILED`.

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/models/pdf_document.dart lib/core/pdf/pdf_library_controller.dart \
  lib/core/pdf/pdf_library_index.dart lib/features/pdf/pdf_reader_screen.dart \
  lib/features/pdf/widgets/pdf_reader_viewport.dart tool/verify_pdf_library.dart \
  test/pdf_library_controller_test.dart test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(pdf): restore zoom and rotation, and never lose the last page

The design promises zoom and rotation per entry, only lastPage was saved,
and a 500 ms debounce lost it when the reader was closed quickly.
markOpened now carries page, zoom and rotation, the reader flushes them in
dispose, and the unused pruneMissing helper is gone because the library
intentionally keeps entries whose file vanished.

The tests have not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: One render in flight per page

**Files:**
- Modify: `lib/features/pdf/widgets/pdf_reader_viewport.dart:384-450` (`_requestTile` and surrounding state)
- Test: `test/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: `_retryTile` from Task 4.
- Produces: at most one native `render` per page at a time; the newest wanted key is kept as `_pending` and dispatched when the current one returns or fails.

- [ ] **Step 1: Write the failing test**

Append to `test/pdf_reader_screen_test.dart`:

```dart
  testWidgets('zooming while a tile renders does not queue a second one', (
    tester,
  ) async {
    final channel = FakeChannel(pageCount: 1)..hangRenders = true;
    await _pumpViewport(
      tester,
      channel: channel,
      viewport: _portraitViewport(),
    );
    expect(channel.renders, hasLength(1));

    final center = tester.getCenter(find.byType(PdfReaderViewport));
    final first = await tester.startGesture(center - const Offset(30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();
    await first.moveBy(const Offset(-60, 0));
    await second.moveBy(const Offset(60, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(
      channel.renders,
      hasLength(1),
      reason: 'the in-flight tile is the only request until it returns',
    );
  });
```

- [ ] **Step 2: Run the gate to watch it fail**

Run: `dart analyze test/pdf_reader_screen_test.dart`
Expected: compiles; the RED is behavioural — today the pinch clears `_requestedKeys` and issues a second `render` while the first is still in flight, so `renders` has length 2.

- [ ] **Step 3: Coalesce the request**

Add fields:

```dart
  final Map<int, PdfTileKey> _inFlight = {};
  final Map<int, PdfTileKey> _pending = {};
  final Map<int, NormalizedRect> _pendingSources = {};
```

Rewrite the tail of `_requestTile` after the key is computed:

```dart
    if (_requestedKeys[index] == key) return;

    if (_inFlight.containsKey(index)) {
      // One render per page at a time: remember the newest request and issue
      // it when the current one returns or fails.
      _pending[index] = key;
      _pendingSources[index] = source;
      return;
    }

    final cached = _cache.get(key);
    if (cached != null) {
      _requestedKeys[index] = key;
      _paint(index, cached, source);
      return;
    }

    _requestedKeys[index] = key;
    _dispatch(index, key, source);
```

Extract the existing `ref.read(...).render(...)` chain into:

```dart
  void _dispatch(int index, PdfTileKey key, NormalizedRect source) {
    final generation = ++_generation;
    _requestGenerations[index] = generation;
    _inFlight[index] = key;
    unawaited(
      ref
          .read(pdfRenderChannelProvider)
          .render(
            handle: widget.handle.id,
            pageIndex: index,
            scale: key.scaleBucket / 100,
            source: source,
            maxPixels: _maxTilePixels,
          )
          .then((bytes) {
            _inFlight.remove(index);
            if (!mounted || _requestGenerations[index] != generation) {
              _drainPending(index);
              return;
            }
            _tileAttempts.remove(index);
            _cache.put(key, bytes);
            _paint(index, bytes, source);
            _drainPending(index);
          })
          .catchError((Object _) {
            _inFlight.remove(index);
            if (!mounted || _requestGenerations[index] != generation) {
              _drainPending(index);
              return;
            }
            _retryTile(index);
            _drainPending(index);
          }),
    );
  }

  /// Issues the newest request that arrived while a page was rendering.
  void _drainPending(int index) {
    final key = _pending.remove(index);
    if (key == null) return;
    final source = _pendingSources.remove(index) ?? const NormalizedRect(0, 0, 1, 1);
    if (!mounted) return;
    if (_cache.get(key) case final cached?) {
      _requestedKeys[index] = key;
      _paint(index, cached, source);
      return;
    }
    _requestedKeys[index] = key;
    _dispatch(index, key, source);
  }
```

`_dispatch` recomputes `scale` from the key bucket so the native call matches the cache key exactly. Keep `_maxTilePixels` as is.

Clear the new maps in `_releaseOffscreenTiles` and `handleMemoryPressure`:

```dart
    _pending.removeWhere((index, _) => !keep.contains(index));
    _pendingSources.removeWhere((index, _) => !keep.contains(index));
```

(The in-flight render is not cancelled — Android's single executor has already accepted it — but its page no longer holds a pending slot.)

- [ ] **Step 4: Run the gate**

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/pdf/widgets/pdf_reader_viewport.dart test/pdf_reader_screen_test.dart
git commit -m "$(cat <<'EOF'
fix(pdf): keep one render in flight per page

Every scroll event and pinch cleared the requested keys and pushed another
execute() onto the native single-thread executor, so a zoomed scroll
queued tens of tile renders and a pending closeHandle behind all of them.
The newest wanted tile is now held as pending and dispatched when the
current one returns or fails.

The test has not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Coverage and CI wiring

**Files:**
- Create: `test/pdf_thumbnailer_test.dart`
- Modify: `.github/workflows/build-apk.yml:260-264`
- Test: the new file

**Interfaces:**
- Consumes: `pdfThumbnailer(PdfRenderChannel channel, PdfLibraryStore store)` (existing) and `PdfLibraryStore.writeThumbnail`.
- Produces: nothing later tasks consume.

- [ ] **Step 1: Write the failing thumbnailer test**

Create `test/pdf_thumbnailer_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/pdf/pdf_library_store.dart';
import '../lib/core/pdf/pdf_page_geometry.dart';
import '../lib/core/pdf/pdf_render_channel.dart';
import '../lib/core/pdf/pdf_thumbnailer.dart';

class _FakeChannel extends PdfRenderChannel {
  final List<String> opened = [];
  final List<double> scales = [];
  int closes = 0;

  @override
  Future<PdfRendererHandle> open(String path, {String? password}) async {
    opened.add(path);
    return const PdfRendererHandle(
      id: 5,
      pageCount: 2,
      pages: [PdfPageSize(600, 800), PdfPageSize(600, 800)],
    );
  }

  @override
  Future<Uint8List> render({
    required int handle,
    required int pageIndex,
    required double scale,
    required NormalizedRect source,
    int maxPixels = 4096,
  }) async {
    scales.add(scale);
    return Uint8List.fromList([7, 8, 9]);
  }

  @override
  Future<void> close(int handle) async {
    closes += 1;
  }
}

void main() {
  late Directory root;
  late Directory cache;
  late PdfLibraryStore store;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('zaker_thumb_root_');
    cache = Directory.systemTemp.createTempSync('zaker_thumb_cache_');
    store = PdfLibraryStore(rootDir: root, cacheDir: cache);
    await store.ensureReady();
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  test('renders page one at 120 px wide and closes the handle', () async {
    final channel = _FakeChannel();
    final base = store.baseFile('doc')..writeAsBytesSync([1, 2, 3]);

    await pdfThumbnailer(channel, store)(base, store.thumbFile('doc'));

    expect(channel.opened, [base.path]);
    expect(channel.scales.single, closeTo(120 / 600, 0.0001));
    expect(channel.closes, 1);
    expect(store.thumbFile('doc').readAsBytesSync(), [7, 8, 9]);
  });
}
```

- [ ] **Step 2: Run the gate to watch it fail**

Run: `dart analyze test/pdf_thumbnailer_test.dart`
Expected: compiles against the existing thumbnailer; if `PdfRendererHandle`'s constructor is not `const`, drop the `const` — the RED is only the CI step missing, so move to Step 3 without a behavioural failure (record in the commit body that this task adds coverage, not a behaviour change).

- [ ] **Step 3: Run the harness in CI**

In `.github/workflows/build-apk.yml`, after the `Verify calculator logic` step:

```yaml
      # The PDF library layer is Flutter-free and has no widget coverage;
      # without this step its checks would never gate a merge.
      - name: Verify PDF library
        run: dart run tool/verify_pdf_library.dart
```

- [ ] **Step 4: Run everything this branch gates on**

Run: `dart run tool/verify_pdf_library.dart`
Expected: success line, no `FAILED`.

Run: `dart run tool/verify_calculator_logic.dart`
Expected: unchanged success line.

Run: `dart analyze lib test`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add test/pdf_thumbnailer_test.dart .github/workflows/build-apk.yml
git commit -m "$(cat <<'EOF'
test(pdf): cover the thumbnailer and gate the library harness in CI

The thumbnailer could open a document and never close it without any test
noticing, and tool/verify_pdf_library.dart was never run by the workflow.

The new test has not executed: no Flutter engine here and CI is blocked.

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:** Every 2026-10-29 PDF finding has one owning task — 1 (native close/answer) → Task 1; 2 (search on a protected file) → Task 8; 3 (zero pages) → Tasks 1+2; 4 (renderer/fd leak) → Task 1; 5 (no retry, OOM never answers) → Tasks 1+4; 6 (memory) → Task 6; 7 (request pile-up) → Task 10; 8 (disk full, import message) → Task 3; 9 (two extractions, whole file in RAM) → Task 7; 10 (zoom/rotation/lastPage/prune) → Task 9; 11 (page mode source) → Task 5; 12 (coverage/CI) → Tasks 3, 11. The spec's «decrypted temp copy» promise (lines 336–342) is Task 8.

**Type consistency:** `PdfRenderFailure.storage` (Task 3) is consumed by Task 8's `_unlockWith`; `_retryTile` (Task 4) is consumed by Task 10's `_dispatch`; `failedTilePages` (Task 4) and `cachedTileBytes` (Task 6) are test hooks only; `onZoomChanged` (Task 9) is the only new widget parameter, and it is optional.

**Review Focus coverage:** the five lines at the top each name their owning task's test — zero pages (Task 2), a render that fails (Tasks 1, 4), an unreadable file (Task 3), a protected document (Task 8), memory pressure (Task 6).
