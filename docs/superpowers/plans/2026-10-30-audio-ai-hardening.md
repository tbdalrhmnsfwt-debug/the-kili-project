# Audio / AI Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the twelve Audio/AI gaps from the 2026-10-29 four-area review — seven Important (shared player, silent AI failure, lying adhan result, endless "preparing", unstarted job service, unwired grounded AI, phantom sticky notifications) and five Minor (preview outliving its screen, orphaned temp recordings, no escape from a denied mic, keep-screen-on forever, zero coverage).

**Architecture:** Two halves. The Dart half owns state and must never present a placeholder as a result: `AiService` reports which backend answered, `AudioPlaybackController` reports a file it cannot open, library screens hand the real `AiService` to `GroundedStudyService`. The Kotlin half owns the Android service lifecycle: results come from the service, sticky restarts stop, and the native player gains a client identity so two screens cannot share one engine.

**Tech Stack:** Flutter 3.x / Dart 3.13, Riverpod 2.x, Dio (injectable for offline tests), Kotlin (`MediaPlayer`, foreground services, `MethodChannel`).

**Spec:** the user-approved four-area gap review of 2026-10-29, section 2 (Audio / AI), verified against the tree on 2026-10-30.

## Global Constraints

- **Kotlin cannot be compiled or run here.** The replica tree has no `android/settings.gradle`, no `build.gradle(.kts)`, no Gradle or Android SDK, so every Kotlin task ships unbuilt. Each Kotlin commit message must say so in one line.
- **Flutter tests cannot run here** (no ARM64 engine); CI is billing-blocked. Dart work is gated on `dart analyze lib test` plus offline unit tests written but run only in CI.
- Format only touched files: `$SDK/bin/dart format <paths>`; never `dart format lib test`. Revert formatter-only hunks.
- Arabic user-facing strings, Latin digits.
- Commit per task; do not push or merge.
- SDK: `/data/data/com.termux/files/home/the-kili-project/work/dartsdk/dart-sdk/bin/dart`.

## Task 1: The adhan preview outlives its screen

**Files:** `lib/features/azkar/azkar_settings_screen.dart` (dispose at 47-50, preview at 208-219)

- [x] In `dispose()`, stop the preview before removing the observer, exactly as `salat_counter_screen.dart:57-60` already does: `unawaited(AdhanPlatform.stopPreview());`.
- [x] Analyze clean; commit.

## Task 2: The chat recorder offers a way out of a denied microphone

**Files:** `lib/features/batches/chat/voice_note_recorder.dart:231-261`

- [x] In the `_Stage.denied` branch, add an `AdhanPlatform.openAppSettings` action beside «اطلب الإذن تاني» — the bag's recorder already does this at `bag_voice_recorder_sheet.dart:300`, and after «don't ask again» `_prepare` can never succeed.
- [x] Analyze clean; commit.

## Task 3: The AI service reports who answered, and Translate stops guessing

**Files:** `lib/core/ai_service.dart:36,55-95`, `lib/features/translate/translate_screen.dart:46-70`, `test/ai_service_test.dart` (create)

**Interfaces:**
- Produces: `class AiAnswer { final String text; final AiBackend backend; }`; `Future<AiAnswer> askDetailed(String question, {String? subject})`; `ask` unchanged in signature, now `(await askDetailed(...)).text`.

- [x] Write `test/ai_service_test.dart`: a `Dio` with a stub adapter that throws → `askDetailed` returns `AiAnswer(backend: AiBackend.canned)` and its text is the canned reply; a stub that returns `{'answer': '42'}` → `backend == AiBackend.cloud`, `text == '42'`; with a `CurriculumSearch`-shaped offline hit → `backend == AiBackend.canned` but the text is the textbook answer, not the canned one.
- [x] Run `dart analyze test/ai_service_test.dart`; expect `AiAnswer` / `askDetailed` undefined (RED).
- [x] Add `AiAnswer` and `askDetailed` to `AiService`; `ask` delegates to it. `_askRemote` returns `(String text, AiBackend backend)`.
- [x] In `TranslateScreen._run`, use the returned value and show «الخدمة مش متاحة دلوقتي» when `backend == AiBackend.canned` instead of printing the assistant's canned study text; stop scanning `ai.history`.
- [x] Ruling: the shared `history` still interleaves for the chat screen's own transcript. Fixing that needs per-screen transcripts (a bigger design); the finding's user-visible half — Translate printing someone else's answer — is what this task closes. Cost if wrong: two simultaneous chat turns can still mix in the transcript view.
- [x] Analyze clean; commit.

## Task 4: A file with no duration fails instead of preparing forever

**Files:** `lib/core/batches/audio_playback_controller.dart:74-86`, `test/audio_playback_controller_test.dart:179-191`

- [x] Change the existing test that codifies the stall: after `initialize()` with a binding whose `open` returns `null`, expect `state == AudioPlayerState.failed` and `errorCode == 'no_duration'` (RED against today's code).
- [x] In `initialize()`, when the open reply carries no positive duration and no event has supplied one, call `_fail('no_duration')` instead of moving to `preparing`. The screen's existing `_retry` path is already wired to `hasError`.
- [x] Ruling: fail immediately rather than after a timeout — the channel's open reply is synchronous and carries the duration; live streams are not a resource type this screen accepts. Cost if wrong: a format whose duration arrives only later would show the retry button instead of playing.
- [x] Analyze clean; commit.

## Task 5: Library explanations use the real AI

**Files:** `lib/features/library/official_section_screen.dart:47`, `official_mind_map_screen.dart:98`, `official_flashcards_screen.dart:78`, `test/grounded_study_test.dart` (create)

- [x] Write the test first: `GroundedStudyService(ai: <an AiService whose askGrounded returns null>)` must still return the local explanation (already true); `GroundedStudyService(ai: null)` must too. The new behaviour to pin is that the screens pass the provider's service — assert it through a small widget test only if the screens can be pumped cheaply; otherwise ledger that the wiring is analyze-checked.
- [x] Replace the field initialisers with `late final GroundedStudyService _study;` assigned in `initState` from `ref.read(aiServiceProvider)`.
- [x] Ruling: only `official_section_screen.dart` is wired. The mind-map and flashcard screens build their notes with the synchronous `mindMap()` / `flashcards()` calls, which never touch the AI — passing the service there would be dead wiring. Cost if wrong: those two screens stay local-only, which is what they already document.
- [x] Analyze clean; commit.

## Task 6: Offline coverage for the two Dart seams

**Files:** `test/ai_service_test.dart`, `test/audio_playback_controller_test.dart`

- [ ] Extend the AiService test with `askGrounded` returning `null` on a network throw (no canned fallback for grounded calls).
- [ ] Cover the no-duration path's `close()` still releasing the binding exactly once.
- [ ] Analyze clean; commit.

## Task 7: Keep-screen-on becomes opt-in

**Files:** `android/app/src/main/kotlin/com/zaker/zaker_ai/MainActivity.kt:196-200`

- [ ] Delete the unconditional `FLAG_KEEP_SCREEN_ON` from `onCreate`; re-add it only around the screens that need it (recording, adhan playback, qibla) through a small channel call, or drop it if those screens already set it themselves. Read both screens before deciding and ledger the choice.
- [ ] Commit; note the Kotlin is unbuilt.

## Task 8: Sticky services stop instead of resurrecting

**Files:** `LectureRecordService.kt:30-45`, `AiJobService.kt:36-54`

- [ ] Return `START_NOT_STICKY`; when `intent == null`, `stopSelf()` and return before building any notification.
- [ ] Commit; note the Kotlin is unbuilt.

## Task 9: Adhan start reports the truth

**Files:** `MainActivity.kt:127-136`, `AdhanPlaybackService.kt:368-383`, `lib/features/prayer/adhan_playback_screen.dart:112-131`

- [ ] Have `AdhanPlaybackService.start` return whether it actually started (vibrate-only and failed-player paths return false), and pass that through the channel instead of `result.success(true)`.
- [ ] Dart: only set `_playing = true` and cancel the source notification when the platform reports a start.
- [ ] Commit; note the Kotlin is unbuilt.

## Task 10: One player per client

**Files:** `AudioPlayerChannel.kt:39,92-95,140,268-287`, `lib/core/batches/audio_player_channel.dart`, `lib/providers/batch_providers.dart:177-179`, the three controllers (`batch_chat_screen.dart:1305`, `audio_resource_screen.dart:151`, `bag_audio_player.dart:108,101`)

- [ ] Give `open`/`play`/`pause`/`seek`/`close` a `clientId`; the Kotlin channel keeps a map of `MediaPlayer` per client and releases only that one.
- [ ] Dart: `AudioPlayerBindings` methods take the id; the provider becomes `Provider.autoDispose.family<AudioPlayerBindings, String>`, and `BagAudioPlayer.dispose` stops closing a binding it does not own.
- [ ] Commit; note the Kotlin is unbuilt.

## Task 11: Orphaned recordings are swept at startup

**Files:** `AudioRecorderChannel.kt:236-271,311-313,324-328`, `MainActivity.kt`

- [ ] Delete `cacheDir/recordings` files older than a day in `onCreate`, and delete the target when a recording is stopped but never consumed.
- [ ] Commit; note the Kotlin is unbuilt.

## Task 12: AI jobs run in the foreground service

**Files:** `AiJobService.kt:29-114`, `MainActivity.kt:44-65,383`, `lib/core/ai_service.dart:247-273`

- [ ] `runJob` starts the service, updates progress through `zaker/ai_jobs`, and stops it in a `finally`.
- [ ] Commit; note the Kotlin is unbuilt.
