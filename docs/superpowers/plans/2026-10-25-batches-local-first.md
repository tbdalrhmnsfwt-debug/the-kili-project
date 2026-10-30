# «الدفعات» Local-First Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real, durable, single-device batch workspace to Zakerly, with every server-dependent capability shown as an honest blocked state.

**Architecture:** Domain models and pure services live under `lib/models` and `lib/core/batches`; `BatchRepository` is the future-server contract and `LocalBatchRepository` persists per-uid JSON documents and private files. `lib/providers/batch_providers.dart` exposes async state to the new `lib/features/batches` screens. The fifth shell tab hosts the list; detail screens are pushed.

**Tech Stack:** Flutter 3.x, Dart >=3.5, Riverpod 2.5.1, go_router 14.2.7, `KeyValueStore`/`LocalStore`, app-private files via `path_provider`, existing Syncfusion/Printing/Tesseract stack, existing `ExamQuestion`/`QuizRunner`, new Kotlin `MediaPlayer`/`MediaRecorder` channels.

**Spec:** `docs/superpowers/specs/2026-10-25-batches-local-first-design.md`

## Global Constraints

- Stay inside Zakerly teal (`#0F766E`), Cairo, `ZakerSpacing`, `ZakerRadius`, the four palettes; no new palette.
- Arabic literal UI strings inside `TrText`; English additions only in `assets/i18n/en_extra.json`; never edit `strings.dart`.
- No seeded people, messages, challenges, transcripts or citations.
- No new backend, push, ASR, remote AI or storage. Server-only actions return typed blocked results.
- Per-uid storage: `<support>/batches/<uid>/<batchId>/`; no cross-account reads.
- No new Android permission; no new package except promoting the already-resolved `image`.
- Every screen: loading, empty, error, missing-file and blocked states; RTL; 48dp targets; text scaling.
- Local verification: `work/dartsdk/dart-sdk/bin/dart format` + `dart analyze`; `flutter test`/APK in CI.
- Commits end with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.

## Review Focus

- A code input with Arabic-Indic digits, spaces or a leading zero must resolve or show a precise state, never crash or silently trim.
- A timetable row with no date/timezone must never create a reminder or an invented date.
- A corrupt or missing per-collection file must keep the batch and the other collections usable.
- An exam taken across app restart, backgrounding or the close time must not reset its deadline or double-submit.
- A generated study item whose quote is absent from the cited page must be rejected, not shown.
- A guest who signs in must either move their batches explicitly or keep them under the guest workspace; no silent loss.

---

## Phase 1 — Foundation, tab, local repository

**Files:** `lib/models/batch.dart`, `batch_resource.dart`, `batch_chat.dart`,
`batch_schedule.dart`, `batch_update.dart`, `batch_exam.dart`,
`lib/core/batches/{batch_ids,batch_failure,batch_access,batch_code_service,
document_store,batch_store,batch_file_store,batch_repository,
local_batch_repository}.dart`, `lib/providers/batch_providers.dart`,
`lib/features/batches/batches_screen.dart`, shell/router edits,
`test/batch_{models,access,code_service,document_store,local_repository}.dart`,
`test/batches_screen_test.dart`.

**Interfaces (produced):**
- `Batch`, `BatchSubject`, `BatchSettings`, `BatchRole`, `Membership`,
  `InviteCodeState`, `AuditEntry`, `BatchResource`, `ChatMessage`,
  `TimetableDraft`, `TimetableEntry`, `BatchUpdate`, `BatchExam`,
  `ExamAttempt`; all have `toJson`/`fromJson`.
- `BatchAccess.can(BatchRole role, BatchAction action) -> bool`.
- `BatchCodeService.generateUnique({required Set<String> taken}) -> String`, `codeMatches`, `CodeAttemptGuard` cooldown.
- `DocumentStore<T>.load() -> DocumentLoad<T>`, `.save(T)`; atomic + `.bak` + quarantine.
- `BatchRepository`: `listBatches`, `loadBatch`, `createBatch`, `updateSettings`, `addSubject`, `renameSubject`, `deleteSubject`, `rotateCode`, `revokeCode`, `deleteBatch`.
- `batchFileStoreProvider`, `batchRepositoryProvider`, `batchListProvider`, `batchControllerProvider`.

**Tests:** model round-trips; role matrix default-deny; 8-digit leading-zero
codes and cooldown; document backup/corruption; create/list/delete/code
rotation; empty batches screen; fifth tab builds.

**Verification:** `dart format lib test`; `dart analyze lib test`; CI green.

## Phase 2 — Create, join, code share, identity claim

**Files:** `create_batch_screen.dart`, `batch_created_screen.dart`,
`join_batch_screen.dart`, `claim_batches_prompt.dart`,
`core/batches/batch_claim_service.dart`, account/provider edits,
`test/create_batch_test.dart`, `test/join_batch_test.dart`,
`test/batch_claim_service_test.dart`.

**Interfaces:** `JoinCodeState` enum + `resolveCode`; `BatchClaimService.claim(guestUid, accountUid, batchIds)`; `BatchController.create(...)`, `.rotateCode(...)`.
**Behaviour:** real create/review/success/copy/share; eight-digit local join
states; guest identity persistence; one-time claim prompt.
**Tests:** validation, review, code share text, join states incl. Arabic-Indic,
claim accept/decline/rollback/idempotency.
**Verification:** same as Phase 1.

## Phase 3 — Hub, subjects, private resources

**Files:** `batch_hub_screen.dart`, `subjects/*`, `widgets/*`,
`core/batches/resource_store.dart`, tests.
**Interfaces:** `BatchController.addResource`, `.deleteResource`, `.setStarred`;
`BatchFileStore.copyResource`.
**Behaviour:** hub header/member count/chat preview/four sections; subject CRUD;
week/day folders; PDF/audio/note import with validation, thumbnails, missing
file handling, storage usage.
**Tests:** hub order, empty states, import validation, delete subject move/delete,
missing file card, per-collection corruption.
**Verification:** same.

## Phase 4 — Audio, voice notes, local chat

**Files:** `AudioPlayerChannel.kt`, `AudioRecorderChannel.kt`, `MainActivity.kt`,
`audio_player_channel.dart`, `audio_recorder_channel.dart`,
`playback_position_store.dart`, `chat_store.dart`, `audio_resource_screen.dart`,
`batch_chat_screen.dart`, `voice_note_recorder.dart`, tests.
**Interfaces:** player `open/play/pause/seek/dispose` + event stream;
recorder `start/stop/cancel`; `ChatStore.send/edit/delete/react/pin/page`.
**Behaviour:** resume per uid/resource; real voice notes with permission;
durable text/voice chat with replies, reactions, pins, pagination, tombstones;
transcription blocked card only.
**Tests:** fake channels, position clamping, idempotent send, pagination,
reaction dedupe, pin, removal guard.
**Verification:** same + Kotlin compiles in CI.

## Phase 5 — PDF extraction and grounded study tools

**Files:** `study_source_extractor.dart`, `study_tools_engine.dart`,
`evidence_validator.dart`, `subjects/study_tools_screen.dart`,
`interactive_test_screen.dart`, `information_bank_screen.dart`,
`mind_map_screen.dart`, tests.
**Interfaces:** `StudySourceExtractor.extract(BatchResource) -> SourceDocument`;
`StudyToolsEngine.test/bank/mindMap(SourceDocument)`.
**Behaviour:** page text + OCR fallback with caps/cancel; validated evidence;
interactive test, bank, mind map with list alternative; encrypted PDF and
remote AI blocked.
**Tests:** citation rejection, malformed questions, deterministic fixtures,
encrypted source, cancel.
**Verification:** same.

## Phase 6 — Timetable OCR, review, reminders

**Files:** `schedule_ocr_service.dart`, `hocr_parser.dart`,
`timetable_layout_parser.dart`, `schedule_reminder_service.dart`,
`batch_schedules_screen.dart`, import/review screens, tests + hOCR fixtures.
**Interfaces:** `HocrParser.parse(String) -> OcrDocument`;
`TimetableLayoutParser.parse(OcrDocument) -> TimetableDraftDraft`;
`ScheduleReminderService.sync(batchId)`.
**Behaviour:** rotate/copy image; Tesseract hOCR; separate layout parser;
uncertainty labels; editable draft; explicit publish; weekly/one-off reminders
only with timezone basis.
**Tests:** Arabic/English/Indic digits/RTL/low confidence/no invented dates;
reminder privacy/cancel/resync.
**Verification:** same.

## Phase 7 — Updates and notification routing

**Files:** `batch_updates_screen.dart`, `update_editor_screen.dart`,
`adhan_launch.dart` edit, tests.
**Interfaces:** `BatchController.publishUpdate`, `.markUpdateRead`.
**Behaviour:** local announcements, read state, in-app indicators, batch
payload route; push blocked.
**Tests:** CRUD, unread count, payload routing, permission-denied screen state.
**Verification:** same.

## Phase 8 — Exams

**Files:** `batch_exams_screen.dart`, `exam_editor_screen.dart`,
`exam_taking_screen.dart`, `exam_result_screen.dart`, repository methods, tests.
**Interfaces:** `BatchController.saveExam/publishExam/startAttempt/
submitAttempt`; `BatchExamAttempt` persistence.
**Behaviour:** editor validation, grounded generation + review, availability
window enforcement, persisted deadline, idempotent submit, scoring, results
gating, attempt history; ranking/live challenge blocked.
**Tests:** window, deadline cap, background/restart, auto-submit, double submit,
scoring, `afterClose` gate.
**Verification:** same.

## Phase 9 — Administration and tutorial

**Files:** `admin/*`, `tutorial/*`, tests.
**Interfaces:** audit entries; `BatchTutorialController` mode+step.
**Behaviour:** join-request/member blocked states, code status, settings,
content review, storage, audit, delete; 13-step full and 7-step getting-started
tutorial, resumable/replayable.
**Tests:** authorization re-check, confirmations, audit cap, tutorial modes and
no-batch fallback.
**Verification:** same.

## Phase 10 — Polish and verification

**Files:** touched screens/widgets, `assets/i18n/en_extra.json`, docs.
**Behaviour:** RTL/text scaling/contrast across four themes, reduced motion,
performance caps, all blocked cards, final blocked-features checklist, manual
device checklist. Report exactly what ran locally and what ran in CI.

## Self-Review

- Spec coverage: phases map to §10.1–§10.14 and §7.4. Transcription stays
  blocked; lecture recording/time expiry/transcript UI are documented omissions.
- Types: repository methods above are the single surface used by providers and
  screens; no screen reads files directly.
- Review Focus tests are placed in Phases 1, 2, 4, 5, 6, 8.
- Deliberately omitted: seeded content, server simulation, fake live challenge.

## Status (2026-10-26)

All ten phases are implemented on `main`. Phase 9's first CI attempt exposed a
Flutter ListTile ink assertion in the settings card; the fix moved the card
onto a `Material` surface and passed on the next run. The final report,
blocked-feature checklist, caps and manual device checklist live in
[`docs/batches-local-first-report.md`](../../batches-local-first-report.md).

