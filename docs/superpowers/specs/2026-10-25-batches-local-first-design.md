# «الدفعات» — Batches & Study Community, Local-First — Design

**Date:** 2026-10-25
**Status:** Draft — awaiting user approval
**Approach:** A — repository-backed local-first (chosen by the user)
**Identity decision:** stay inside Zakerly's teal/Cairo system (chosen by the user)
**Data decision:** no seeded demo people or messages; every server-dependent
surface shows an honest blocked state (chosen by the user)

## 1. Intent

The brief describes a blue-and-white student-community app built around
**batches**: a teacher or moderator creates a cohort with subjects and an
eight-digit invitation code, students join (sometimes after approval), and the
batch becomes a place for subjects, schedules, updates, exams, chat, lecture
audio, PDF study tools and a live challenge.

This repository is not that app. It is the Flutter replica `zaker_ai`
(Zakerly): Arabic-first, RTL, Riverpod + go_router, local-first, with a real
private PDF library/reader, on-device Tesseract OCR, local exams and
leaderboards, notifications, and an existing «فهيم» AI chat. It has no batch,
membership, group-chat, audio-player/recorder or transcription system.

The user has decided that this batch area will be added to Zakerly as a
**local-first study workspace**:

- every feature that can be real on one device is implemented for real;
- every feature that needs a trusted server, multi-user delivery or a remote
  provider is **blocked with a plain explanation**, never faked;
- the visual language stays Zakerly teal, Cairo and the existing design
  tokens — not the brief's blue/white palette;
- no sample classmates, sample conversations or sample live challenges.

The result is a complete single-user batch experience and an honest map of
what a server would add.

## 2. Goals

- Add a fifth bottom tab «الدفعات» with a list of local batches and two
  entry actions: **اعمل دفعة** and **ادخل بكود**.
- Create a batch with name, subjects, upload policy and join-approval policy,
  a review step, and an eight-digit code generated with a cryptographically
  secure RNG — with copy and native-share actions.
- Implement batch detail: header (name, member count), chat preview, and the
  four sections in the brief's order — **المواد، المواعيد، المستجدات،
  امتحانات** — plus administration and a replayable 13-step tutorial.
- Organize learning resources by subject and week/day; import PDFs and audio
  into app-private storage; play audio with resume; record voice notes.
- Build a real local chat: text, voice notes, replies, reactions, pins,
  timestamps, unread state and pagination, durable across restarts.
- Build page-aware PDF text extraction, on-device OCR for scanned pages, and
  grounded study tools (interactive test, information bank, mind map) whose
  questions/facts/nodes each carry a page reference and an evidence excerpt
  that is validated against the source.
- Build the photo-to-schedule workflow with hOCR word boxes, a separate
  layout/semantic parser, an editable review screen with uncertain cells
  highlighted, and publish-after-confirmation.
- Build local announcements/updates with read state and in-app indicators.
- Build MCQ exam authoring, publication, timed local attempts, local scoring,
  and honest blocked states for cross-member ranking and live challenges.
- Build a batch administration screen with confirmations, local audit entries
  and server-style authorization re-checks in the domain layer.
- Cover the core logic and screens with automated tests; document every
  blocked capability and its reason.

## 3. Non-goals and anti-goals

**Non-goals in this iteration**

- No new backend, Firebase/Supabase project, server rules, push service,
  object storage, transcription service, remote AI provider or on-device ASR
  model.
- No cross-device membership, invite redemption, approval, realtime delivery,
  presence, or multi-user ranking.
- No seeded demo personas, fake member lists, fake incoming messages, fake
  live scores or simulated server time.
- No replacement of Zakerly's teal identity, four existing tabs or existing
  screens; the fourth tab stays Quran and the fifth is appended.
- No new Android permissions. Existing manifest permissions
  (`RECORD_AUDIO`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS`,
  camera via picker) cover the plan.
- No new package dependency unless it is already resolved in the offline
  cache; `image` may be promoted to a direct dependency for image rotation
  because it is already in the resolved lock graph.

**Anti-goals — a technically working result that still fails**

- A screen that says «تم الانضمام» when no membership was created.
- A chat list that looks multi-user because sample people were seeded.
- A transcript that was generated from a canned template.
- A live-challenge leaderboard computed from local device times and presented
  as fair.
- A schedule published without the administrator confirming ambiguous days,
  times or dates.
- A generated exam question that cites a page that does not contain the quoted
  evidence.
- A UI that hides blocked features with no explanation, or disables them
  without saying why.

## 4. Constraints and environment

- Flutter app `zaker_ai`, Dart `>=3.5`, Riverpod 2.5.1, go_router 14.2.7.
- Existing persistence: `LocalStore` (`KeyValueStore`, `zaker.` prefix) plus
  app-private files via `path_provider`. No database package is resolved or
  needed; batch data is JSON files with atomic writes.
- Existing PDF stack: `file_picker`, `syncfusion_flutter_pdf` (text
  extraction with bounds), `printing` (raster/print), native
  `PdfRenderChannel` (`PdfRenderer` tiles), `PdfLibraryStore` (atomic private
  copies), `PdfTextMap` (page lines/search).
- Existing OCR: `flutter_tesseract_ocr` 0.4.31 with bundled `ara` + `eng`
  traineddata, fully on-device. `extractHocr` is available on Android and
  returns word `bbox` + `x_wconf`; this is what the timetable parser uses.
- Existing audio: only bundled adhan assets through `MediaPlayer`; no
  arbitrary-file player, no recorder. A new Kotlin channel is required.
- Existing notifications: `flutter_local_notifications`, permission/exact
  alarm handling and payload routing in `adhan_launch.dart`; batch payloads
  and a public scheduling method are not implemented.
- Local verification uses `work/dartsdk/dart-sdk/bin/dart` for
  `dart format` and `dart analyze`. `flutter test` and the APK build run in
  CI (`.github/workflows/build-apk.yml`), not on this ARM64 device. No result
  will be claimed that was not run.
- Existing visual vocabulary: `ZakerColors` (teal `#0F766E`), `ZakerSpacing`,
  `ZakerRadius`, `SectionHeader`, `FeatureTile`, `StatChip`, `ProgressBar`,
  `EmptyState`, `LoadingBox`, `ChipStrip`, `ZakerGlassGlyph`,
  `ZakerSkeleton`, `ZakerPressScale`, `TrText`, four complete palettes.
- Every user-visible string is an Arabic literal inside `TrText`; English
  additions go only to `assets/i18n/en_extra.json`. `strings.dart` is
  generated from the shipped APK — never edited by hand.

## 5. What exists today (verified)

- **Navigation:** four hard-coded tabs in `shell_screen.dart:31-36`; the index
  is clamped to 0–3 at `:102`; `_bodyFor` ends in a Quran catch-all at
  `:104-112`. The sidebar and bottom bar iterate `_tabs`, so appending a fifth
  entry updates both. No test mounts the shell or the router.
- **Identity:** `AuthUser` is either a Firebase account or a local guest.
  Sign-out currently mints a brand-new guest uid (`AccountScreen._signOut`,
  `account_screen.dart:246-253`), and sign-in swaps to the Firebase uid
  (`app_providers.dart:65-78`). Any per-uid data written before that switch
  becomes unreachable. This design fixes guest persistence and adds an
  explicit claim step (§7.2), because batch data is per-uid.
- **Persistence:** `LocalStore` is failure-tolerant shared preferences;
  `OfficialLibraryStore` demonstrates schema version, backup, corrupt
  quarantine and import/export, and is the durability model to follow.
  `persistenceProvider` saves a fixed list of providers; batch data is not
  present.
- **PDF:** imported files are copied atomically into app support; page text
  can be read per page with `PdfTextExtractor`; `PdfTextMap` is in-memory
  only; the official-book pipeline is the only persisted page-text cache and
  is hard-wired to `OfficialBook`. Encrypted files can render but text
  extraction/search does not pass the password. Reader search loads the whole
  file into memory.
- **Grounded study:** `GroundedStudyService` has real local extractive
  generators (explanation, summary, definitions, formulas, steps,
  flashcards, quiz, mind map) tied to page numbers, but its input type is
  `OfficialPassage`; the remote `askGrounded` path is never wired and does not
  validate citations.
- **OCR:** scan flow uses `extractText` (`ara+eng`, psm 4) and returns flat
  text. No coordinates, table parser, timetable model or image rotation.
- **Audio:** no arbitrary-file playback, no position/seek, no recorder. The
  `LectureRecordService` only owns a microphone-typed foreground notification.
- **Exams:** `ExamQuestion`, `ExamSession`, `QuizRunner`, local cloze/bank
  generators and answer grading are real. Sessions and banks are in-memory;
  only mistakes persist. All timing and scoring use device time.
- **Schedules:** the active model is a task list (`ScheduleEntry`), not a
  weekly timetable; no timezone IDs, no start/end times, no grid. The unused
  `StudyPlan`/`ScheduleSlot` is dead code and will not be revived.
- **Notifications:** scheduled task reminders exist; payload routing lives in
  `adhan_launch.dart`; there is no generic batch payload or channel.
- **Tutorial:** no coach-mark/overlay widget exists; the only onboarding is a
  one-off prayer bottom sheet.
- **Tests:** 22 files, all `flutter_test`; fakes use `KeyValueStore`,
  `ProviderScope` overrides and fake channels. No batch tests.

## 6. Approaches considered

1. **Repository-backed local-first (chosen).** Screens depend on domain
   repositories and a permission matrix. On-device implementations are real;
   server-only operations return typed blocked results. The repository
   interfaces are the contract a future backend implements, so no screen is
   rewritten later.
2. **An in-app authority core.** Put codes, roles and scoring inside a Dart
   service that "acts like a server". Rejected: the client owns it, so it is
   not a trust boundary and would misrepresent the security model.
3. **Seeded demo batch.** Ship sample classmates, messages and a challenge to
   exercise every screen. Rejected by the user: fabricated content presented
   as a feature.

## 7. Architecture

### 7.1 Layers

```
lib/models/batch.dart              Batch, BatchSubject, BatchSettings, BatchRole,
                                   Membership, InviteCodeState, AuditEntry
lib/models/batch_resource.dart     BatchResource, ResourceKind, WeekDay,
                                   AudioMetadata, PlaybackPosition
lib/models/batch_chat.dart         ChatMessage, MessageReaction, ChatCursor
lib/models/batch_schedule.dart     TimetableDraft, TimetableEntry, OcrWord,
                                   ScheduleSource
lib/models/batch_update.dart       BatchUpdate, UpdateReadState
lib/models/batch_exam.dart         BatchExam, BatchExamQuestion, ExamAttempt,
                                   ExamResult, AttemptPolicy
lib/models/study_source.dart       SourceDocument, SourcePage, EvidenceRef

lib/core/batches/
  batch_access.dart                pure role/state permission matrix
  batch_code_service.dart          secure gen, uniqueness, cooldown
  batch_repository.dart            interface (the future-server contract)
  local_batch_repository.dart      file-backed implementation
  batch_store.dart                 batch.json envelope, backup, corrupt recovery
  document_store.dart              generic atomic JSON document with backup
  batch_claim_service.dart         guest -> account workspace claim
  batch_file_store.dart            private dirs, atomic copy, delete, usage
  batch_paths.dart
  batch_ids.dart                   crypto-random ids, no uuid dependency
  chat_store.dart                  per-channel durable message store
  playback_position_store.dart     uid + resource resume positions
  transcription_service.dart       interface + unavailable implementation
  schedule_ocr_service.dart        image -> hOCR words (Tesseract)
  hocr_parser.dart                 pure hOCR -> words/lines/confidence
  timetable_layout_parser.dart     pure words -> draft rows + uncertainty
  schedule_reminder_service.dart   batch reminder scheduling + payload
  audio_player_channel.dart        Dart side of zaker/audio_player
  audio_recorder_channel.dart      Dart side of zaker/audio_recorder
  study_source_extractor.dart      page text/OCR cache for a batch PDF
  study_tools_engine.dart          local grounded test/fact bank/mind map
  evidence_validator.dart          normalisation + quote/page validation

lib/providers/batch_providers.dart
  batchListProvider, batchProvider(family), batchControllerProvider,
  chatControllerProvider(family), audioPlayerProvider,
  recorderProvider, studyToolsProvider, timetableDraftProvider,
  examAttemptProvider, tutorialProgressProvider

lib/features/batches/
  batches_screen.dart              list + create/join actions
  create_batch_screen.dart         form, subjects, settings, review
  batch_created_screen.dart        code, copy, share
  join_batch_screen.dart           code input, states, preview
  claim_batches_prompt.dart        one-time guest -> account claim sheet
  batch_hub_screen.dart            header, chat preview, four sections
  subjects/batch_subjects_screen.dart
  subjects/batch_subject_screen.dart
  subjects/resource_sheet.dart
  subjects/audio_resource_screen.dart
  subjects/study_tools_screen.dart
  subjects/interactive_test_screen.dart
  subjects/information_bank_screen.dart
  subjects/mind_map_screen.dart
  chat/batch_chat_screen.dart
  chat/voice_note_recorder.dart
  schedules/batch_schedules_screen.dart
  schedules/schedule_import_screen.dart
  schedules/schedule_review_screen.dart
  updates/batch_updates_screen.dart
  updates/update_editor_screen.dart
  exams/batch_exams_screen.dart
  exams/exam_editor_screen.dart
  exams/exam_taking_screen.dart
  exams/exam_result_screen.dart
  admin/batch_admin_screen.dart
  admin/batch_settings_screen.dart
  admin/members_screen.dart
  admin/join_requests_screen.dart
  tutorial/batch_tutorial_overlay.dart
  tutorial/batch_tutorial_steps.dart
  widgets/blocked_capability_card.dart
  widgets/batch_empty_state.dart

android/app/src/main/kotlin/com/zaker/zaker_ai/
  AudioPlayerChannel.kt            MediaPlayer, position/duration/seek/events
  AudioRecorderChannel.kt          MediaRecorder, runtime RECORD_AUDIO, service
  MainActivity.kt                  register the two channels
```

### 7.2 State and persistence

- One `BatchController` per signed-in uid owns the batch list and mutates it
  through `BatchRepository`. Screens watch derived providers; they never touch
  files.
- `BatchRepository` is an interface. `LocalBatchRepository` validates every
  command against `BatchAccess`, writes atomically, and returns typed
  `BatchFailure`s. A future remote repository implements the same interface.
- Batch state is **not** scattered across the existing 57 `StateProvider`s.
  Only the shared `LocalStore` provider, the auth uid and the file store are
  injected.
- Identity is the existing `AuthUser` (Firebase account or local guest). Each
  uid has its own batch index and its own directory tree; a different account
  on the same device cannot see another account's local batches.

### 7.2.1 Identity, sign-out and claiming (user decision: "Account + claim")

The user chose per-account ownership with an explicit one-time move from a
guest workspace to a signed-in account. This is the only part of the design
that changes existing account behaviour, so it is specified precisely:

- **Guest identity is persistent.** `main`/`app_providers` store the guest
  uid and display name in `LocalStore` (`auth.guest.v1`) on first launch and
  `AccountScreen` restores that same profile on sign-out instead of calling
  `newGuestUid()` again. Signing out therefore returns to the guest workspace
  that already exists on this device; it does not create an empty one.
- **Sign-in switches workspace.** After a successful Firebase sign-in the
  active uid becomes the Firebase uid. The guest workspace is untouched on
  disk. Signing out returns to the persistent guest workspace; signing in
  again returns to the account workspace.
- **Claim prompt.** If the guest workspace has at least one batch and the
  account workspace does not already contain those batch ids, the first
  successful sign-in on this device shows a sheet: «عندك N دفعة على حساب
  الضيف — تنقلها للحساب ده؟». It lists batch names, states that moving is
  local and irreversible, and offers «انقل» / «سيبها على الضيف». The decline
  is remembered per (guest uid, account uid) pair; new guest batches create a
  new prompt opportunity. No upload happens.
- **Claim is atomic per batch.** For each selected batch, rename
  `batches/<guestUid>/<batchId>` to `batches/<accountUid>/<batchId>`, rewrite
  `ownerUid`, membership uid, audit actor and playback/tutorial keys, and
  update both indexes. Failures roll the batch back to the guest directory
  and report which batches did not move. The claim never edits or deletes
  source files. Re-running the claim is idempotent by batch id.
- **No cross-account reads.** Screens, storage usage and deletion only address
  the active uid's directory. If an account is deleted remotely (a future
  server feature), its local workspace is not automatically deleted; the
  settings screen offers explicit removal.
- Tests cover: guest uid stability across sign-out, sign-in workspace switch,
  claim accept/decline/partial failure/idempotency, and the absence of a
  cross-account batch in the list.

### 7.3 Navigation

- Append tab index 4 «الدفعات» (`Icons.groups_rounded` / existing hugeicons
  style), change the clamp to 0–4, and make `_bodyFor` explicit for 3 and 4.
  Add `ZakerRoutes.batches = '/batches'` with
  `ShellScreen(initialIndex: 4, child: BatchesScreen())`.
- Pushed routes (outside the shell, matching the host app):
  `/batches/create`, `/batches/join`, `/batches/:id` (hub),
  `/batches/:id/admin`, `/batches/:id/settings`, `/batches/:id/members`,
  `/batches/:id/join-requests`, `/batches/:id/chat`,
  `/batches/:id/subject/:subjectId`,
  `/batches/:id/resource/:resourceId`,
  `/batches/:id/schedules`, `/batches/:id/schedules/import`,
  `/batches/:id/updates`, `/batches/:id/updates/new`,
  `/batches/:id/exams`, `/batches/:id/exams/new`,
  `/batches/:id/exams/:examId`, `/batches/:id/exams/:examId/result`.
- The bottom bar is visible on the batches list (it is a tab root) and hidden
  inside pushed batch screens, exactly as the existing challenges, planner and
  PDF screens behave. Every pushed screen has the automatic back arrow; the
  hub's back returns to the list, and the list's tab remains «الدفعات».
- A home card and an «كل الأدوات» tile also open `/batches` for discoverability.

### 7.4 Existing files this design changes

Only the following existing files are touched; each change is additive or a
small, tested correction:

| File | Change |
|---|---|
| `lib/features/home/shell_screen.dart` | Append the fifth tab, clamp 0–4, explicit body case |
| `lib/core/router.dart` | Batch routes and the shell route |
| `lib/features/account/account_screen.dart` | Restore the persisted guest profile; offer the claim prompt after sign-in |
| `lib/providers/app_providers.dart` | Persist/restore the guest profile; register batch providers; restore per-uid batch data |
| `lib/core/notification_service.dart` | Public batch reminder schedule/cancel methods with deterministic ids |
| `lib/features/prayer/adhan_launch.dart` | Route `{"type":"batch"}` payloads to the batch screens |
| `lib/main.dart` | Initialise the `timezone` database once if not already initialised; no other startup change |
| `assets/i18n/en_extra.json` | English strings for the new surfaces |
| `android/.../MainActivity.kt` | Register `zaker/audio_player` and `zaker/audio_recorder` |
| `pubspec.yaml` | Promote the already-resolved `image` package to a direct dependency |

No existing screen is restructured, no route is renumbered, and no existing
storage key changes. `strings.dart` and the four shell tabs stay untouched
apart from appending the fifth tab.

## 8. Local-first semantics and the blocked-capability matrix

The single rule: **a local implementation is used only when the result is
real; otherwise the UI states what is blocked and why.** Every blocked surface
uses one reusable `BlockedCapabilityCard` with a title, the reason, what still
works locally, and no fake controls.

| Capability | Local behaviour | Status |
|---|---|---|
| Create batch, subjects, policies, review | Real, atomic, validated | Works |
| 8-digit code generate / copy / share / rotate / revoke | Real `Random.secure`, local uniqueness, cooldown, used-code ledger; no time-based expiry (see §17.1) | Works on this device |
| Join a batch from another device | No lookup possible | **Blocked**: explains a server is required |
| Join a batch that exists on this device | Code resolves; the current user is the owner, so state is «already member» | Works as a state, not a membership change |
| Admin approval of join requests | No requests can arrive | **Blocked**: empty state with reason |
| Batch member list | Shows the current user only | Works honestly; no fabricated members |
| Mute/remove/report another member | No other members exist | **Blocked** |
| Chat text/voice/reply/reaction/pin/history | Durable local store; single author | Works locally, labelled local |
| Realtime delivery, reconnect catch-up, read receipts across users | No transport | **Blocked** |
| Push notifications from a batch | No push service | **Blocked**; in-app updates work |
| Private remote storage / cross-device files | Files are private on this device | **Blocked** for sharing; export via explicit share works |
| Audio playback of imported or recorded files | Real native player, resume per user | Works |
| Voice-note recording | Real native recorder, private files, 15-minute cap | Works |
| Recording a lecture | Imported lecture audio plays; there is no lecture-recording screen | **Not built** (documented omission) |
| Lecture transcription (queued/processing/completed) | No ASR provider or model | **Blocked** with reason |
| Transcript reading/search/segment seek | Depends on transcription | **Blocked** until a provider exists |
| PDF import, preview, thumbnails, private storage | Real | Works |
| Grounded test / information bank / mind map | Real local extractive generation with validated page evidence | Works; labelled on-device |
| Remote AI generation | No configured provider or consent path | **Blocked** |
| Timetable photo OCR + review + publish | Real on-device hOCR, layout parser, human confirmation | Works with documented accuracy limits |
| Personal schedule reminders | Local notifications via the existing service | Works |
| Updates/announcements and read state | Real local records and in-app indicators | Works |
| Exam authoring, timed attempt, local score | Real, device-clock authoritative | Works; labelled device-local |
| AI-assisted exam authoring | Local grounded generator only | Works locally; remote AI blocked |
| Cross-member grade table / ranking | No other members | **Blocked** |
| Live challenge (synced timer, live leaderboard) | No server authority | **Blocked** entirely |
| Tutorial, help, replay | Real in-app walkthrough | Works |

No blocked surface contains a button that pretends to succeed, a fake status
spinner, or invented data.

## 9. Data model and storage

### 9.1 Models (all JSON round-trip tested)

- `Batch`: `id`, `name`, `ownerUid`, `createdAt`, `settings`,
  `subjects`, `codeState`, `archivedAt`, `lastActivityAt`.
- `BatchSubject`: `id`, `name`, `order`, `createdAt`.
- `BatchSettings`: `uploadsAdminOnly` (default true), `requireApproval`
  (default true), `allowMemberReminders` (default true),
  `notificationDetail` (`generic` default, `titled` opt-in).
- `BatchRole { owner, admin, member, pending, muted, removed }` and
  `Membership { batchId, uid, displayName, role, joinedAt, removedAt }`.
  Locally only `owner` can exist, but the enum and matrix are complete so the
  server version has a tested contract.
- `InviteCodeState { code, createdAt, rotatedAt, revokedAt, rotationCount }`
  plus a per-uid `usedCodeHashes` ledger (SHA-256, capped, oldest pruned).
- `WeekDay { week (1-based), day (1–7) }` with a display helper; not a date.
- `BatchResource`: `id`, `batchId`, `subjectId` (non-null; there is no
  unassigned bucket), `weekDay?`, `kind` (`pdf`, `audio`, `note`), `title`,
  `fileName`, `mime`, `sizeBytes`, `durationMs?`, `uploaderUid`, `createdAt`,
  `starredBy`, `sha256?`, `processingState` (`none`, `extracting`, `ready`,
  `failed`, `blocked`), `transcriptionState` (`unavailable` locally).
- `PlaybackPosition { uid, resourceId, positionMs, updatedAt }`.
- `ChatMessage`: `id`, `batchId`, `channelId` (`main`), `authorUid`,
  `authorName`, `kind` (`text`, `voice`), `text`, `voiceFileName?`,
  `voiceDurationMs?`, `replyToId?`, `createdAt`, `editedAt?`, `deletedAt?`,
  `reactions Map<String, Set<String>>`, `pinned`, `clientKey` (idempotency).
- `TimetableDraft`: `id`, `batchId`, `sourceImageFileName`, `ocrEngine`,
  `status` (`draft`, `published`), `createdAt`, `updatedAt`, `entries`,
  `warnings`.
- `TimetableEntry`: `id`, `dayOfWeek` (1–7), `startMinutes`, `endMinutes`,
  `title`, `subjectId?`, `room?`, `teacher?`, `confidence` (0–1),
  `uncertainFields`, `recurrence` (`none` default, `weekly` opt-in),
  `weekAnchorDate?`, `timeZoneId?`, `reminderEnabled` (default false),
  `allDay` (false unless explicitly set).
- `BatchUpdate`: `id`, `batchId`, `title`, `body`, `authorUid`,
  `createdAt`, `editedAt?`, `publishedAt?`; read state keyed by uid.
- `BatchExam`: `id`, `batchId`, `title`, `instructions`, `questions`
  (snapshot of `ExamQuestion`), `timeLimitMinutes?`, `opensAt?`, `closesAt?`,
  `attemptPolicy` (`single` default, `limited`, `unlimited`),
  `maxAttempts`, `showResults` (`immediately`, `afterClose`), `published`,
  `createdAt`, `sourceResourceId?`.
- `ExamAttempt`: `id`, `examId`, `batchId`, `uid`, `startedAt`,
  `deadlineAt?`, `submittedAt?`, `answers`, `scorePercent?`, `status`
  (`active`, `submitted`, `expired`), `clientKey`.
- `AuditEntry`: `id`, `batchId`, `actorUid`, `action`, `at`, `detail`
  (non-sensitive, e.g. «تم تدوير الكود», never message text or answers).

### 9.2 File layout

```
<app support>/batches/<uid>/<batchId>/
  batch.json                 # Batch + subjects + settings + code + resource index
  batch.json.bak             # last known good
  updates.json               # announcements + per-uid read state
  exams.json                 # exam definitions (no attempts)
  attempts/<examId>/<attemptId>.json
  schedules.json             # drafts + published timetable entries
  audit.json                 # capped local audit entries
  chat/main.json             # snapshot, atomic rewrite, cursor pagination
  chat/voice/<messageId>.m4a
  resources/<resourceId>.<ext>
  thumbs/<resourceId>.png
  schedules/<draftId>-source.<ext>
  text/<sha16>.json          # page extraction cache
  transcripts/<resourceId>.json   # never created until a provider exists
```

The small per-uid index (batch ids, tutorial progress, used-code hashes,
playback positions, declined claim markers) lives in `LocalStore` under
`batches.index.v1.<uid>`, `batches.tutorial.v1.<uid>`,
`batches.codes.v1.<uid>`, `batches.playback.v1.<uid>` and
`batches.claim.v1.<uid>`.

- **Write granularity is one document per collection.** `batch.json` holds
  identity, settings, subjects, code state and the resource index, and is
  rewritten only when one of those changes. Updates, exams (definitions),
  attempts (one file per attempt), schedules (draft autosave and published
  entries), audit and chat each own their document. A timetable autosave never
  rewrites exams; an exam submission never rewrites chat. `LocalBatchRepository`
  composes these stores, so the future remote repository implements the same
  command surface without exposing files.
- Every document uses `DocumentStore`: an integer `schema`, atomic
  `<name>.part` → rename, a `<name>.bak` previous-good copy, and quarantine
  on parse failure. `batch_store.dart` is the batch-specific wrapper.
- **Corruption scope is explicit.** A corrupt `updates.json` loses updates but
  not the batch; `exams.json`/`attempts`/`schedules.json` likewise. A corrupt
  `batch.json` falls back to `.bak`; if both fail, the batch shows as
  unavailable with its directory quarantined, never silently deleted. Resource
  files remain on disk and the unavailable card offers delete or leave.
- Schema migration is a ladder per document type. A document written by a
  newer schema is opened read-only with an explanation; it is never
  downgraded.
- Imported files are validated (PDF `%PDF-` header; audio extension + a real
  `MediaPlayer.prepare` probe; image decodable) and copied into the batch
  directory. The external original is never modified or deleted.
- Deleting a batch removes its directory and index entry after an explicit
  confirmation naming what is deleted. There is no remote copy to erase.
- The settings screen shows storage used per batch and a manual cleanup for
  caches (thumbnails, extraction cache) that never touches originals.

## 10. Flows

### 10.1 Batches list

- Empty state: «مفيش دفعات على الجهاز» with the two actions, and one sentence
  explaining that local batches live on this device and multi-member features
  need a server.
- Cards: name, subject count, «أنت بس على الجهاز» member note, last activity,
  unread update dot, and owner-only code chip. Menu: open, admin, delete.
- Header actions: help (tutorial), create, join. No pull-to-refresh illusion;
  local changes appear immediately.
- Missing/corrupt batch files: the card is marked unavailable with a reason
  and actions to remove the entry or recover from backup.

### 10.2 Create a batch

1. **Form:** name (trimmed, 2–60 chars, no control characters), subject names
   (0–30, each 1–40, case/space-insensitive uniqueness), upload policy
   (admin-only / all active members), join approval (on/off).
2. **Review:** name, creator display name, subject list, both policies, and a
   plain-language sentence for each policy effect.
3. **Create:** repository validates again, generates the code
   (`Random.secure`, exactly 8 digits, leading zeros allowed, checked against
   active and recent codes), writes the batch atomically, records the audit
   entry, and returns the batch.
4. **Success:** batch name, creator, code in LTR selectable text, copy and
   native share via `share_plus`. The screen explains that the code is an
   invitation mechanism, not authentication, and that a second device cannot
   redeem it until a server exists — so the share sheet's text is honest.
5. Rotation/revocation live in Admin: rotating invalidates the previous code
   immediately on this device and increments the count; revoking leaves the
   batch with no usable code. Both explain exactly what stops working.

### 10.3 Join with a code

- Eight-digit field, numeric keyboard, paste, LTR display, grouping shown as
  `1234 5678` while the stored value is digits only.
- States: `invalidFormat`, `cooldown` (with remaining time), `notFound`
  (blocked: no local batch matches; a server is needed to look up another
  person's batch), `revoked` (matches a recent revoked code), `alreadyMember`
  (matches a local batch owned by this account), `pendingUnsupported`
  (approval cannot be exercised without a server), `storageError`.
- **No time-based expiry locally.** A code stops working when it is rotated or
  revoked. The brief's "expired" state is represented by `revoked`; adding a
  clock-based expiry would rely on the device time and add no protection
  without a server. This is listed as a documented omission in §17.
- When a local batch matches, show the confirmation preview: batch name,
  creator display name, subject count, and «أنت عضو بالفعل». No membership is
  created; the screen explains why.
- Failed attempts are logged locally only as timestamps (never the code) and
  trigger a cooldown after 5 failures in 10 minutes: 60 s, doubling to a
  10-minute cap. This is a usability guard, not a security boundary.

### 10.4 Batch hub

- Header: batch name, role badge, member count (honestly 1 locally), owner-only
  code chip, help icon, admin icon when authorized.
- Chat preview card: last local message or «لسه مفيش رسائل», unread dot,
  opens the chat. A one-line label says «محادثة على الجهاز».
- Four section cards in order: **المواد**, **المواعيد**, **المستجدات**,
  **امتحانات**. Each shows a count, a one-line latest item where relevant, an
  unread/new indicator, and an empty-state message when new.
- Loading skeleton, error card and missing-file notice never lose the selected
  section; the selected section is local UI state.
- No offline banner: local data is the normal state. A small
  «بيانات محفوظة على الجهاز» note appears once in settings, not repeatedly.

### 10.5 Subjects and resources

- Subject list with add/edit/delete for the owner. Deleting a subject that has
  resources requires choosing another subject to move them to, or deleting
  them with a count in the confirmation. If no other subject exists, only
  delete/cancel are offered. There is no «بدون مادة» bucket: `subjectId` stays
  non-null so every resource is always reachable.
- Inside a subject: week/day folders (`الأسبوع ١ · اليوم ٢`), resource cards.
- Add resource:
  - **PDF:** `FilePicker` multi-select, size/page guards, atomic copy,
    thumbnail from `PdfRenderChannel`, page count; scanned pages are detected
    later by extraction.
  - **Audio:** picker (m4a/aac/mp3/wav/ogg), `MediaPlayer` prepare probe,
    duration recorded, private copy.
  - **Note:** title + Arabic text.
- Resource card: thumbnail/title, subject, uploader (current user), date, size
  or duration, transcription badge (`غير متاح محليًا`), star toggle.
- Opening a PDF uses the existing reader via `/pdf-viewer?path=...&title=...`;
  it stays transient (read/search/print/share) and is not silently added to
  «ملفاتي».
- Delete resource asks first and removes the private file, thumbnail,
  extraction cache and playback positions only after confirmation.

### 10.6 Audio playback and recording

- `AudioPlayerChannel` (MethodChannel `zaker/audio_player` +
  EventChannel `zaker/audio_events`):
  - `open(path) -> {durationMs}` (nullable until prepared),
  - `play`, `pause`, `seek(ms)`, `stop`, `dispose`,
  - events: state (`idle`, `preparing`, `playing`, `paused`, `completed`,
    `failed`), position, duration, error code.
  - MediaPlayer with `USAGE_MEDIA`/`CONTENT_TYPE_SPEECH`, audio focus,
    `ACTION_AUDIO_BECOMING_NOISY` pause, completion, release in `dispose`.
  - Local app-private file paths only; no URL.
- `AudioPlaybackController` exposes play/pause/seek and progress, injects a
  fake channel in tests. Position is saved every 5 s, on pause/close, and on
  app lifecycle, keyed by uid + resource; reopen seeks to the saved position
  when it is below duration. Unknown duration shows a preparing state, not a
  fake total.
- `AudioRecorderChannel` (MethodChannel `zaker/audio_recorder`,
  `MediaRecorder`, AAC-LC `.m4a` mono 64 kbps):
  - requests `RECORD_AUDIO` through the activity if not granted; denial
    returns a typed permission failure and leaves all other features usable;
  - starts/stops the existing `LectureRecordService` microphone foreground
    notification while recording;
  - `start(tempPath)`, `stop() -> {path, durationMs}`, `cancel()`, events for
    elapsed time and amplitude;
  - cap: voice note 15 minutes; low-storage check before starting;
    interruption stops cleanly and keeps what was written.
- Voice notes: record → stop → repository copies into
  `chat/voice/<messageId>.m4a`, writes the message/resource, and the UI
  shows a real duration. Failure keeps a retry action; cancel deletes the
  temp file.
- **No lecture-recording flow in this iteration.** Lecture audio can be
  imported, stored privately, played with resume and studied like any audio
  resource; the recorder is offered only for chat voice notes. A long-running
  lecture recorder (hours, background lifecycle, storage pressure) is a
  documented omission in §17, not a silently missing button.

### 10.7 Transcription (blocked honestly)

- `TranscriptionService` interface with job states, retries, cancellation and
  provider metadata. `UnavailableTranscriptionService` returns
  `TranscriptionFailure.noProvider` and creates **no** job.
- The «فرّغه» action opens an explanation sheet: no on-device ASR model is
  bundled, and no consent/configured provider exists; nothing is uploaded.
  The Transcriptions section shows an empty blocked state and the same reason.
- No queued/processing animation, no canned transcript, no fake segments.
- The models for transcript segments (start/end ms, text, confidence, edited
  flag, original text) are defined now so a future provider can be added
  without a schema break; the segment-search/seek UI is not built until there
  is data to show. This is a documented omission, not a silent one.

### 10.8 Chat

- `ChatStore` per batch/channel: a JSON snapshot of messages, atomic writes,
  max page size 30 in the UI, cursor pagination by `(createdAt, id)`.
- Send: text or voice. A client-generated `clientKey` makes sends idempotent;
  the store rejects a duplicate key. Optimistic UI only after the local write
  succeeds (no fake delivery tick).
- Replies store `replyToId`; the composer shows a quoted preview; deleted
  parents render «الرسالة اتشالت» without losing the reply.
- Reactions are add/remove with a set of uids per emoji; duplicate-safe;
  the current user's reactions are highlighted and labelled with semantics,
  not colour alone.
- Pins: owner-only pin/unpin; a pinned strip at the top, dismissible per
  session; pin changes are audited without copying message text.
- Timestamps, date separators, unread marker, jump-to-latest, empty/loading
  states, and long-message truncation with a read-more control.
- A persistent, non-nagging header note: «محادثة محفوظة على الجهاز — توصيل
  الرسائل للأعضاء التانيين محتاج سيرفر». No fake online presence.
- Delete: author/owner deletes with confirmation, leaving a tombstone;
  report is a blocked capability (no moderation server).
- Access guards in the repository/matrix are tested for pending, removed and
  muted roles even though those roles cannot occur locally yet.

### 10.9 PDF study tools

- `StudySourceExtractor` builds a `SourceDocument` for a batch PDF:
  - opens it with Syncfusion, reads page text via `PdfTextExtractor`
    page-by-page with yields and progress;
  - detects pages below the text threshold and OCRs them with
    `Printing.raster` + Tesseract `ara+eng` (same path as the official
    pipeline), capped at 50 OCR pages per run with an explicit warning;
  - records `fromOcr`, warnings and a per-page failure; never invents text;
  - caches `text/<sha16>.json` keyed by file SHA-256 and schema version;
  - encrypted PDFs: the reader may open them, but extraction reports
    «الملف محمي بكلمة سر — أدوات الدراسة مش متاحة» (blocked for this file).
- Job model: stable id, `queued → processing(progress) → completed | failed |
  cancelled`, cancellable between pages, duplicate starts refused, one heavy
  job at a time, size/page limits (100 MB, 500 pages) with a clear message.
- `study_tools_engine.dart` generalises the existing local generators to
  `SourceDocument` (path/section adapters keep `OfficialPassage` behaviour and
  its tests unchanged):
  - **Interactive test:** MCQ/cloze/true-false built from source sentences;
    each question carries `resourceId`, page, evidence excerpt, explanation.
    Validation rejects: fewer than 3 choices, duplicate choices, no correct
    index, answer not in source, ambiguous/truncated stems, evidence not found.
    Submit → correct answer + evidence + page; retry missed questions; attempt
    persisted locally.
  - **Information bank:** definitions/dates/numbers/steps extracted locally,
    each with page and excerpt; local search over fact text; tap opens page
    evidence; empty state when the source has no extractable facts.
  - **Mind map:** heading/term hierarchy with page refs; pan/zoom; RTL labels;
    a text/list alternative for screen readers; every node exposes its page
    where available.
- `EvidenceValidator` normalises Arabic (diacritics, tatweel, alef/ya/ta
  variants, whitespace) and requires the excerpt to exist on the cited page;
  failures drop the item or mark it «مش موجود في المصدر». Unit-tested with
  fabricated citations.
- Every output is labelled «مولّد على الجهاز من نص الملف» — not AI. A
  «بلّغ عن خطأ» action stores a local report entry; it explains that sending
  the report needs a server.
- A remote `StudyToolsProvider` adapter is designed but not configured; it is
  not called, holds no keys, and the UI never implies it exists.

### 10.10 Schedules

- Import: gallery or camera via `image_picker` (camera permission requested at
  use; denial leaves gallery available). The chosen image is copied into
  `schedules/` before OCR. A rotate-left/right action re-encodes the image
  (promote cached `image` to a direct dependency) so rotated photos can be
  recognised.
- OCR: `FlutterTesseractOcr.extractHocr(path, language: 'ara+eng',
  args: {'psm': '6', 'preserve_interword_spaces': '1'})`.
  `hocr_parser.dart` parses `ocr_line`/`ocrx_word` spans into
  `OcrWord {text, left, top, right, bottom, confidence, lineId}`, normalises
  Arabic-Indic digits, and sorts RTL lines x-descending per line; it returns
  the image's pixel dimensions. Pure parser tests use fixture hOCR, including
  a missing/partial-title case.
- Layout and semantics are a **separate** pure step
  (`timetable_layout_parser.dart`):
  - find a header row with ≥3 day names (Arabic and English);
  - derive column ranges from day-word x-centres;
  - find time tokens in each row (`HH:MM`, `H.MM`, optional ص/م/AM/PM) and
    normalise to minutes; handle 12-hour ambiguity by asking, never guessing;
  - group remaining words per (row band × column) into cells, in reading
    order, and build candidate entries with title/subject/room/teacher where
    text shape supports it;
  - confidence from minimum word confidence plus penalties for missing day or
    time, overlapping words, and cells with no text;
  - `uncertainFields` lists exactly which fields the admin must check.
  - It never invents a date, year, calendar system, timezone or recurrence.
- Review: source image (zoom/pan) + editable rows. Each row shows day, start,
  end, title, optional subject/room/teacher, and an uncertainty icon + text
  label. Add/edit/delete rows. The draft autosaves. Publishing requires at
  least one complete entry and an explicit confirmation sheet describing what
  will appear and whether reminders will be offered.
- If a real date is needed (exam-like deadlines), the admin must choose a week
  anchor date and confirm the timezone. The `timezone` package is initialised
  once in `main.dart`; the chosen IANA zone and offset are stored with the
  entry. Without that confirmation, entries remain day-of-week wall-clock
  entries and the UI says so.
- Recurrence is `none` by default; `weekly` is opt-in and stored explicitly.
- Published entries appear in the Schedules tab grouped by day, linked to the
  source image and the draft for later correction.
- **Reminders need a concrete time and timezone, and are offered only when
  that basis exists.** The review/publish screen asks the admin to confirm the
  display timezone (device zone pre-filled) before any reminder toggle is
  available. With confirmation:
  - `recurrence = weekly` offers a weekly reminder at the entry's weekday and
    start time, scheduled with
    `DateTimeComponents.dayOfWeekAndTime` under deterministic id
    `batch:<batchId>:entry:<entryId>`;
  - an entry with a chosen week anchor and `recurrence = none` offers a
    one-off reminder at that anchored local date/time;
  - an entry with neither basis shows no reminder control and says a reminder
    needs a confirmed time and timezone.
- Notification text is privacy-safe by default (batch name only; generic when
  the user chose the generic setting). No reminder exists for an entry without
  a start time. Editing, unpublishing or deleting an entry cancels its
  reminder; the app re-syncs all batch reminders on start, resume and a
  timezone change (the existing adhan/azkar sync pattern). A timezone change
  re-schedules rather than leaving stale local times.
- Handwritten text, merged cells and low-quality photos may fail; the UI says
  OCR confidence is low and offers manual completion. No schedule is published
  without confirmation.

### 10.11 Updates

- Owner creates an announcement with title/body, preview, publish, edit and
  delete (with confirmation); published items are durable and audited.
- Active-member read state is stored per uid; the Updates card and tab show a
  dot/count for unread items; opening the tab marks visible items read after a
  short, cancellable delay (no read-on-scroll surprises).
- Push is blocked: one `BlockedCapabilityCard` explains that delivery to other
  members needs a server. In-app updates remain fully usable.
- A generic payload route `{"type":"batch","batchId":…,"section":"updates"}`
  is added to `handleNotificationPayload` and tested, so schedule reminders
  deep-link correctly today and push can use it later. No fake push.

### 10.12 Exams

- **Authoring:** title, instructions, questions (prompt, 2–6 options, correct
  index, explanation, optional source page/excerpt), time limit (1–180 min,
  optional), availability window (optional), attempt policy (single default,
  limited with max, unlimited), result visibility (immediately / after close),
  publish toggle. Validation blocks empty prompts, duplicate options, invalid
  correct index, missing explanation, and malformed time windows. If both
  `opensAt` and `closesAt` exist, open must be before close. **Choosing
  «بعد الإغلاق» requires a `closesAt`**, so there is never a result state that
  waits for a date that does not exist.
- **Generate from a resource:** runs the same local grounded generator and
  loads editable questions with page/evidence into the editor. Nothing is
  published until the owner reviews and presses publish.
- **Taking:** server-authoritative timing is blocked, so the attempt uses the
  device clock, labelled «الوقت والتقييم على الجهاز». The window is enforced on
  the device: before `opensAt` the start action returns «الامتحان لسه مفتحش»
  with the local time; at or after `closesAt` it returns «الامتحان قفل» and no
  attempt can start. Start persists an attempt with
  `deadlineAt = min(startedAt + timeLimit, closesAt)`; the UI timer is derived
  from the persisted deadline, not a decrementing counter, so backgrounding or
  restart does not reset it. Navigator allows question navigation and a final
  review before submit. Answer keys remain hidden in the UI until submission
  or closing; the domain only exposes them to the result screen after that.
- **Submission:** idempotent by attempt id + client key. A second submit is a
  no-op. When the timer or the availability window ends during an attempt, the
  saved answers are submitted automatically exactly once: status `submitted`
  if there is at least one answer, `expired` if there is none. There is no
  late-submission state locally; a start attempt after close is refused rather
  than recorded late.
- **Scoring:** deterministic: `scorePercent = correct / total * 100`, rounded
  half-up; free-text questions, if allowed, use the existing keyword grader and
  are labelled approximate. No speed bonus in local exams.
- **Results:** score, correct/total, per-question answer, correct answer,
  explanation and source evidence; review missed questions; attempt history
  per exam and uid, capped and persisted. With `afterClose`, the result stays
  hidden until `closesAt` has passed on the device clock and the screen says
  when it will open; there is no "preview" path around the gate.
- **Ranking:** a batch ranking card shows the current user's scores and a
  blocked notice for the rest («ترتيب باقي الأعضاء محتاج سيرفر»). No fabricated
  names or positions.
- **Live challenge:** no start button that pretends. The Exams tab carries a
  blocked card describing the future server rule: accuracy first, a capped
  speed bonus, a stable tie-break, server time, idempotent answers, no offline
  scoring. It explicitly says no live challenge is available locally.
- **AI-assisted exam generation:** local grounded generator only; remote AI is
  blocked as in §10.9.

### 10.13 Administration

- Dashboard sections: join requests (blocked empty state with reason), members
  (current user, role owner), invite code (status, rotate, revoke), batch
  details and subjects, upload/approval policies, content review (resources,
  schedules, updates, exams), storage usage, local audit log, delete batch.
- Every mutating action re-checks authorization in the repository through
  `BatchAccess`, not only in the widget. Tests call repository methods with
  `member`, `pending`, `muted`, `removed` roles and assert denial.
- High-impact confirmations name the action and the effect: removing a member
  (blocked locally), disabling member uploads, unpublishing an exam,
  rejecting a request (blocked), rotating/revoking the code, deleting the
  batch and its files. Destructive buttons are visually secondary, not the
  default focus.
- Audit entries record actor, action, time and a non-sensitive detail. They
  are shown in a list and pruned by count. The audit log is local and is not
  a tamper-proof record; the UI says so once.

### 10.14 Tutorial

- A shared `BatchTutorialOverlay` with 13 steps, each `{id, screen, title,
  body, anchorKey?}`. It navigates to the relevant real screen, waits for
  layout, and draws a dimmed cutout plus a numbered callout; if a target is
  not present (blocked feature or narrow screen), it shows a centered card
  with the explanation and an «افتح» action where useful.
- **Two modes, because steps 8–13 need a batch:**
  - **Full tour (steps ١–١٣):** offered from the hub help icon, and from the
    list help icon when at least one batch exists (it uses the most recently
    opened batch, or asks which batch when several exist).
  - **Getting started (steps ١–٧):** what the help icon on an empty list
    opens. It covers the tab, create, name/subjects, policies, review, code
    and join, ends with «كمّل الجولة بعد ما تعمل دفعة», and the batch-created
    screen offers «كمّل الجولة» from step ٨.
  - If a full tour reaches step ٨ and the batch was deleted (or the tour is
    resumed with no batch), the overlay pauses on a centered fallback card
    with an action to create one. Progress stays at that step and resumes once
    a batch exists; it never shows an anchor from a different batch.
- Controls: next, back, skip, close; progress `n/١٣` (or `n/٧` in getting
  started); the persisted record stores both mode and step per uid; finishing
  marks complete; close saves the current step so it can be resumed. Replay is
  available from the help icon in the batches list and hub and from a Settings
  row. Replay of the full tour starts at step ١; on an empty list the help
  offers getting started.
- Steps: (١) تبويب الدفعات، (٢) إنشاء دفعة، (٣) الاسم والمواد، (٤) صلاحيات
  الرفع والانضمام، (٥) المراجعة، (٦) كود الدعوة، (٧) الدخول بكود،
  (٨) هيدر الدفعة، (٩) المواد، (١٠) المواعيد، (١١) المستجدات،
  (١٢) الامتحانات، (١٣) الإدارة والمساعدة.
- RTL: callout placement mirrors; the cutout uses the anchor's global rect;
  the callout clamps inside the safe area on small screens and with large
  text. Reduced motion disables the dim/cutout animation; steps never block a
  control after the overlay closes. Every callout has a Semantics label and
  the overlay is dismissible with the back button.

## 11. Visual design and interaction

- Zakerly teal, Cairo, existing four palettes; no blue/white override. Batch
  cards use `ZakerRadius.card`, theme borders, and restrained elevation. The
  section hero uses the existing primary gradient (`heroGradient`).
- Status is always icon + text + colour: unread, uncertain, blocked,
  published, failed. `readableTextColor` is used for small accent text in
  every palette; contrast tests cover the batch surfaces.
- Reuse `ZakerGlassGlyph` for section icons and `ZakerPressScale` for tactile
  press states. No new illustration system, no decorative 3D, no noisy
  animation.
- Touch targets ≥48 dp for primary actions; icon-only buttons have tooltips
  and Semantics labels. Text scaling is respected: no fixed-height text rows,
  `maxLines` + overflow where truncation is intended, and tutorial callouts
  clamp to the safe area.
- Motion: short fades/slides between sections, no action is delayed for an
  animation; `MediaQuery.disableAnimations` removes non-essential motion.
- Directional padding/alignment everywhere; codes, digits and progress
  counter strings that must read LTR are wrapped in `TextDirection.ltr`.
- Empty, loading, error and blocked states are designed for every screen.

## 12. Security and privacy

- **The local boundary is honest.** Role checks here are UX and data-integrity
  guards, not security against a device owner. The UI never calls local data
  "secure" or "server-verified".
- Invite codes use `Random.secure`, are exactly 8 digits, are unique among
  this uid's active batches and the hashed recent-code ledger, and are never
  written to logs. Only the owner's batch keeps the display code. Failed
  attempts store timestamps only.
- Files are copied into app-private storage; no public permanent links, no
  `MANAGE_EXTERNAL_STORAGE`, no broad media permissions. Sharing is explicit
  (`share_plus`) and user-initiated. Imported originals are never modified.
- No document text, audio content, chat text, exam answers, codes or
  passwords are logged. Error messages are generic.
- No uploads exist in this build: transcription, remote AI and remote storage
  are blocked, so there is no consent path to bypass. If a provider is added
  later, consent must precede any upload and keys must stay off the client.
- Notification previews are privacy-safe by default (batch name only or a
  generic string); grades, message contents and transcript text never appear
  on a lock screen. Notification permission denial leaves in-app features
  fully usable.
- Local data remains after sign-out under its own uid, and the guest identity
  is now persistent, so returning as guest does not orphan it. Another
  account cannot read it; a guest→account move happens only through the
  explicit local claim prompt. The batch can be deleted locally; the UI states
  that no remote copy exists and previously exported/shared files cannot be
  recalled.
- Sensitive local state is not encrypted at rest in this iteration; the
  limitations are stated in batch settings. No password or signature is
  stored here.

## 13. Error handling

`BatchFailure` codes with Arabic mapping:
`invalidName`, `invalidSubject`, `invalidCode`, `codeCooldown`, `codeNotFound`,
`codeRevoked`, `alreadyMember`, `pendingUnsupported`, `notAuthorized`,
`claimFailed`, `missingFile`, `unsupportedFile`, `fileTooLarge`, `storageFull`,
`corruptStore`, `migrationUnsupported`, `permissionDenied`, `ocrFailed`,
`ocrLowConfidence`, `extractionFailed`, `encryptedSource`, `examNotOpen`,
`examClosed`, `examWindowInvalid`, `transcriptionUnavailable`,
`remoteRequired`, `cancelled`, `validationFailed`.

- Every screen renders loading, empty, error and missing-file states.
- A failed write leaves the previous document intact; no partial batch.
- A missing resource file marks the card unavailable and offers remove or
  re-import; it never crashes or shows a blank viewer.
- A cancelled extraction/import deletes partial output.
- Blocked actions return a `BlockedCapability` reason and never a fake
  success.

## 14. Testing and verification

**Pure logic tests (as much as possible without Flutter):**

- `batch_access`: every action × role × state; default deny; owner-only
  admin; pending/removed/muted cannot read or write; cross-batch isolation.
- `batch_code_service`: 8 digits, leading zeros, uniqueness under collisions,
  rotation/revocation, cooldown schedule, used-code ledger, no code in logs.
- `local_batch_repository` with a memory `KeyValueStore` + temp dirs: create
  atomicity, validation, rename/subjects/policies, code rotate/revoke, delete
  removes files, missing-file prune, corrupt JSON recovery from backup,
  schema migration rejection, and per-collection corruption not taking down
  the batch.
- `batch_claim_service`: accept, decline marker, partial failure rollback,
  idempotent rerun, guest uid stability across sign-out.
- `chat_store`: order, cursor pagination, idempotent send, reply dangling,
  reactions duplicate-safe, pin/unpin, tombstone, removed-role denial,
  retention cap.
- `timetable_layout_parser` + `hocr_parser`: Arabic/English fixtures,
  Arabic-Indic digits, RTL order, 12-hour ambiguity, merged/missing cells,
  low confidence, no invented dates.
- `batch_reminder_service`: weekly and one-off scheduling with a fake clock
  and fake notification sink; cancellation on edit/delete/unpublish; privacy
  default; no reminder without timezone/recurrence basis.
- `evidence_validator` + `study_tools_engine`: every citation exists; a
  fabricated quote is rejected; malformed questions rejected; deterministic
  output from a fixture source.
- `exam`: validation (including `afterClose` requiring a close date), window
  enforcement before open/after close, deadline capping at the window,
  idempotent submit, auto-submit at expiry with and without answers, scoring
  rounding, answer-key visibility gating, ranking blocked.
- `playback_position_store`: per-uid/per-resource resume, clamping, cleanup.
- `tutorial`: step bounds in both modes, progress persistence, finish/resume,
  and the no-batch fallback at step 8.

**Widget tests** (`ProviderScope` + `MaterialApp(theme: ZakerTheme.light())` +
`Directionality`): batches empty/list, create validation and review, created
screen code/share (fake share channel), join states, claim prompt, hub
sections/empty states, chat composer/voice button, resource cards, blocked
capability card, schedule review editing/publish confirmation, updates read
state, exam runner with a fake clock and window states, result screen, admin
confirmations, tutorial getting-started/full modes and
back/next/skip/replay, RTL and large text on a narrow surface.

**Fakes:** `KeyValueStore` memory store, fake clock injected into controllers,
temp directories, fake `AudioPlayerChannel`/`AudioRecorderChannel`/
`PdfRenderChannel`, fake transcription service, fixture hOCR and PDFs. Native
channels are verified through method-channel mocks; real MediaPlayer/
MediaRecorder/Tesseract/Kotlin compile only in CI or on a device.

**CI:** `flutter test`, `flutter analyze --no-fatal-infos`, release APK build.
**Local:** `dart format` on touched files and `dart analyze lib test` with
`work/dartsdk`; plus `tool/verify_batch_logic.dart` for the pure model/store
logic if it stays Flutter-free. Tests that require `flutter_test` are not
claimed to have run locally.

**Manual device checklist (documented, not claimed unless run):** Arabic and
English printed/handwritten rotated timetables; low-confidence review; audio
playback/resume/headphone unplug; voice-note permission denial; large PDF
scanned/extracted; encrypted PDF; storage pressure; all four themes; large
text; RTL; tutorial on a 360 dp screen; notification deep link.

## 15. Acceptance mapping

| Brief scenario | This design |
|---|---|
| Admin creates batch, subjects, policies, code, copies/shares, rotates | Works locally; code share is real but cross-device redemption is blocked and stated |
| Student enters invalid/valid/expired/revoked code; preview; pending; approval | Every local state is implemented; cross-device join and approval are blocked with reason; time-based expiry is a documented omission (§17.1) and `revoked` covers the invalidation case |
| Non-admin cannot approve/alter/pin/bypass uploads | Repository/matrix denies and is tested; locally only the owner exists |
| Removed/muted access; cross-batch isolation | Matrix and repository guards tested; roles cannot occur locally yet |
| Subjects by week/day; resume playback; upload retry; transcription states; transcript seek | Subjects/resume/upload are real; transcription and segment seek are blocked (no provider) |
| Chat text/voice/replies/reactions/pins; duplicates/offline/reconnect/pagination/permissions | Local chat and all message features are real; delivery/reconnect/removed-member server rules are blocked; dedupe tested |
| AI tests/facts/mind map link to evidence; malformed source errors; missing citations rejected | Local grounded tools with validated evidence; remote AI blocked; OCR/extraction failures honest |
| Timetable OCR Arabic/English/handwritten/rotated/low confidence; corrections persist; no silent publish | Real hOCR + parser + review + confirmation; accuracy limits documented and tested on fixtures, not claimed for handwriting |
| Updates deep-link; denied notification permission; private payloads | In-app updates and payload route real; push blocked; permission denial handled |
| Manual/AI exams reviewed before publish; non-members cannot take; keys private; timer/deadline/idempotency/scoring/reconnect/ranking server | Manual + local generated exams work; the availability window and timer are enforced on the device and labelled; keys gated in UI; ranking/reconnect/server time blocked |
| Live challenge no double score; reconnect/late/unauthorized | Blocked entirely with the future rule documented; no fake challenge |
| Tutorial complete/skip/resume/replay; help does something | Real 13-step tour with a batch, a 7-step getting-started tour on an empty list, both resumable and replayable |
| RTL, mixed text, scaling, screen reader, targets, contrast, themes, small screens, reduced motion | Covered by conventions and widget tests; device verification listed |

## 16. Phased delivery

Each phase is a working increment; every phase ends with format + analyze
(and CI tests where applicable). The implementation plan will carry a tracked
checklist that mirrors this list; blocked items stay visible in it.

1. **Foundation:** models, ids, `BatchAccess`, code service, document stores
   with schema/backup/recovery, per-uid paths, file store, repository interface
   + local implementation, providers, fifth tab, batches list, routes,
   empty/loading/error states, `BlockedCapabilityCard`, tests.
2. **Create and join:** create form, validation, review, atomic create,
   success with real code + copy/share, join states and preview, admin
   code rotation/revocation, persistent guest identity and the one-time
   guest→account claim prompt, tests.
3. **Hub and subjects:** hub header, member count, chat preview, four
   sections in order, subjects CRUD, week/day organization, resource import
   (PDF/audio/note), thumbnails, stars, missing-file handling, admin settings,
   tests.
4. **Audio and chat:** native player + recorder channels, playback controller
   with resume, voice-note recording UI and permissions, local chat with text/
   voice/replies/reactions/pins/pagination/dedupe, transcription blocked
   surfaces, tests and channel mocks.
5. **PDF study tools:** page extraction + OCR cache, job states, generic
   grounded engine, evidence validation, interactive test, information bank,
   mind map with list alternative, remote-provider blocked surface, tests.
6. **Schedules:** hOCR parsing, layout parser, rotation, review/edit,
   uncertainty labels, timezone/anchor confirmation, publish, weekly/one-off
   reminders and re-sync, deep links, tests.
7. **Updates:** announcements CRUD, read state, indicators, notification
   payload route, push-blocked surface, tests.
8. **Exams:** editor, validation, AI-assisted local generation + review,
   publish, attempt/timer/window persistence, idempotent submission, scoring,
   results/review, ranking and live-challenge blocked surfaces, tests.
9. **Administration and tutorial:** dashboard, join-request/member blocked
   states, audit log, confirmations, storage usage, delete batch, 13-step
   tutorial (full and getting-started modes) and replay, settings rows, tests.
10. **Polish and verification:** RTL/accessibility/text scaling/contrast,
    all four themes, reduced motion, performance (large PDF/chat/audio),
    missing/corrupt states, documentation of blocked capabilities, full test
    pass in CI, manual device checklist, and a final report that separates
    what ran from what did not.

## 17. Explicitly blocked (and where it is stated)

- Cross-device invite lookup, join, approval, member management, mute/
  remove, moderation/report, realtime delivery, push, remote private storage,
  live challenge, cross-member ranking, server time, transcription, remote AI.
- Each appears in the UI with a reason and with what works locally, and in
  the implementation plan's blocked checklist. None is silently removed and
  none is simulated.
- The app builds and runs without a backend; if a backend is later supplied,
  the repository interface, permission matrix, role model, code service and
  exam/challenge scoring rules are the contract to implement server-side.

### 17.1 Documented omissions (not blocked by a missing server)

These are features a reader might expect that this iteration deliberately
does not build. They are listed here and in the implementation checklist so
they are not mistaken for working features:

- **Lecture recording.** Imported lecture audio plays with resume; the
  recorder is only for chat voice notes. A multi-hour recorder with its own
  background lifecycle is left out to keep the audio scope reviewable.
- **Time-based invite-code expiry.** Rotate/revoke is the real invalidation
  path. A clock-only expiry would not be trustworthy without a server.
- **Transcript segment browser and search.** The transcript model is defined
  for a future provider, but no segment UI is built while every job is
  blocked; showing an empty player would add nothing.
- **Multi-user anything.** Membership beyond the current user, delivery,
  approval, moderation and ranking are blocked rather than omitted, because
  the screens do exist and explain the missing server.

## 18. Risks and limitations

- **Timetable OCR:** Arabic handwriting, merged cells, perspective and poor
  lighting will often fail or produce low confidence. hOCR boxes help, but
  the parser is heuristic; human review is mandatory. Accepted fixtures are
  not a guarantee for arbitrary real timetables.
- **RTL hOCR ordering** may vary by Tesseract build; the parser sorts words
  and lines explicitly, but device verification is required.
- **Native audio channels** compile only in CI; a local Kotlin typo surfaces
  there. MediaPlayer/MediaRecorder behaviour varies by OEM; interruptions are
  handled best-effort.
- **PDF extraction** is limited by Syncfusion support and by the OCR page
  cap; encrypted PDFs cannot use study tools. Reader search currently reads
  the whole file into memory — this design does not fix that, and extraction
  uses a separate page-by-page path.
- **Local authority is not security.** An owner of the device can read or
  alter local files. The UI says so; it never claims server-grade integrity.
- **Storage growth** from audio/PDF is real and local; there is no cloud
  quota. Usage is shown, operations pre-check free space, and deletion is
  explicit.
- **No transcription** means lecture-to-text, transcript search and segment
  seeking remain unavailable; the model is prepared but the experience is
  honestly incomplete.
- **Flutter tests are CI-only on this device.** Format/analyze and pure-Dart
  verification run locally; nothing else is claimed.

## 19. Decisions left to the builder

- Exact Arabic microcopy, icons and card order inside each section.
- Message retention cap, archive policy and compaction threshold.
- OCR page/size caps, confidence thresholds and parser clustering constants,
  chosen against fixtures and device samples.
- Audio bitrate/sample rate and the amplitude-meter design (the 15-minute
  voice-note cap is fixed).
- Exact extraction caps (pages/file size) and cache eviction policy.
- Whether the batches list appears as a full home card or only in «كل الأدوات»
  alongside the fifth tab.
- The precise tutorial callout styling and card copy.
- Storage usage display granularity and cleanup affordances.

## 20. Builder review — questions resolved

A cold builder review of an earlier draft of this document surfaced
ambiguities; they are settled here:

1. **Where the batch area lives.** A fifth bottom tab is appended at index 4
   (with the clamp and body switch fixed); detail screens are pushed outside
   the shell, matching the host app. No existing route is renumbered.
2. **What "local-first" means for multi-user features.** A capability is
   implemented only when the local result is real. Cross-device membership,
   approval, delivery and live scoring are blocked with reasons; there is no
   local "server" and no seeded data.
3. **Why the chat exists with one user.** It is a durable local conversation
   (text, voice, replies, reactions, pins) explicitly labelled as local; it
   is not presented as delivery to other members.
4. **Why the join screen is not dead code.** It implements and tests every
   state, resolves local codes, and tells the user exactly which step needs a
   server; the state model is the contract the backend will use.
5. **How the exam timer stays honest.** The deadline is persisted at start and
   the display derives from device time; the UI labels the result device-local
   and never claims server authority.
6. **How generated study content is verified.** Every item carries a page and
   excerpt; `EvidenceValidator` re-checks the excerpt against the extracted
   page text and rejects or marks unsupported items.
7. **How schedule ambiguity is handled.** The parser never invents a date,
   year, calendar, timezone or recurrence; uncertain fields are listed and
   publishing requires explicit confirmation and, when a real date matters, a
   chosen week anchor and timezone.
8. **What happens to local data on sign-out.** Per-uid workspaces stay on the
   device. Sign-out returns to a persistent guest identity rather than a new
   one; a guest with batches is offered a one-time local move when they sign
   in. Another account cannot see the previous workspace, and the UI explains
   that no remote copy exists and that local data is not encrypted at rest.

### 20.1 Second builder review — decisions

A second cold review checked the first draft against the actual account code
and persistence code. Its eight questions are resolved as follows; the user
chose the identity policy directly.

9. **Identity across sign-in/sign-out — user decision: "Account + claim."**
   Guest identity is persisted, sign-in switches workspace, and a guest with
   batches gets a one-time local move prompt. Detailed in §7.2.1; it is the
   only existing account behaviour this design changes.
10. **Where non-chat collections persist.** One document per collection
    (`batch.json`, `updates.json`, `exams.json`, per-attempt files,
    `schedules.json`, `audit.json`), each with schema/atomic write/backup and
    a defined corruption scope. `BatchRepository` composes the stores. See
    §9.2.
11. **Lecture recording is not in this iteration.** Imported lecture audio is
    fully supported; the recorder is only for chat voice notes. Listed as a
    documented omission (§17.1) rather than claimed as working.
12. **Reminders require a real time basis.** Weekly recurrence schedules a
    weekly reminder; an anchored non-recurring entry schedules a one-off; no
    timezone/date basis means no reminder control. Re-sync runs on start,
    resume and timezone change. See §10.10.
13. **No time-based code expiry.** Rotate/revoke is the real invalidation
    path; "expired" is represented by `revoked`, and the omission is stated in
    §17.1. No model field or failure code is added for a feature that is not
    built.
14. **Exam windows are enforced locally.** Results `afterClose` require a
    `closesAt`; before-open and after-close starts are refused; the attempt
    deadline is capped by the window; auto-submit at expiry is submitted once
    (or `expired` with no answers). All of it is labelled device-clock.
    See §10.12.
15. **Tutorial has a no-batch path.** Full 13 steps require a batch; an empty
    list starts a 7-step getting-started tour and the created screen offers
    the remaining steps; a full tour hitting step 8 without a batch pauses on
    a create card. Both modes persist mode + step. See §10.14.
16. **No «بدون مادة» bucket.** Deleting a subject with resources requires
    moving them to another subject or deleting them; `subjectId` stays
    non-null. See §10.5.
