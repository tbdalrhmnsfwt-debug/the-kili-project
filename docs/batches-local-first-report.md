# Batches, local-first — implementation report

**Date:** 2026-10-26
**Branch:** `main`
**Scope:** the batch/community education feature for Zakerly, built into the
existing Flutter replica as a local-first feature. Every server-dependent
behaviour appears as an explicit blocked state; nothing is simulated.

## What works on the device

| Area | Local behaviour |
| --- | --- |
| Batches tab | Lists per-account local batches, empty state, create and join entry points, honest “device only” note. |
| Create | Name (2–60 chars) and up to 30 optional subjects; review step; saves locally and generates an 8-digit invite code. |
| Join | Invite code entry with Arabic-digit and dash tolerance; looks up batches on this device only; the code is a discovery token, not authentication. |
| Claim | A signed-in account can move guest batches to itself on this device; the move is not reversible automatically and nothing leaves the device. |
| Hub | Batch header, role, code for the owner, subjects, schedule, updates, exams and admin entry points. |
| Subjects/resources | Up to 30 subjects; PDF, audio and text notes; files copied into private batch storage; import caps enforced. |
| Study tools | Text extraction from local PDFs, quiz, fact bank and mind map built only from the extracted text with page evidence. |
| Chat | Text (4,000 chars) and voice notes (15 minutes), pin, edit, delete, reactions, per-account read state; private local storage. |
| Schedule | Timetable picture OCR plus manual rows, per-row review, explicit publish, device-time reminders 10 minutes before, 4-week rolling window. |
| Updates | Owner/admin-authored updates with per-account read state and local notification payloads containing ids only. |
| Exams | Multiple-choice authoring, open/close windows, duration, attempt policies, auto-submit, local grading, result visibility policy, attempt history. |
| Administration | Local audit log, code rotation/revocation with confirmations, owner-only settings, local member list, storage usage and cache cleanup, delete with confirmation. |
| Tutorial | 13-step full tour and 7-step getting-started tour, per-account progress, replay, reduced-motion support. |

## Blocked features (honest states)

Each item explains itself in the UI. No fake buttons, counts or content.

- **Joining from another device / by a code from another device.** Needs a server; the local build searches this device only.
- **Join requests and approval.** The request queue is local-empty and has no approve/reject buttons.
- **Invite, mute and remove members across devices.** Member management is read-only on the device.
- **Real-time message delivery and push notifications.** Chat and updates are stored locally; notifications contain ids only and are device-local.
- **Reporting and blocking (moderation).** Needs a moderation server.
- **Cloud AI study tools.** Need a server and a stored provider key; the local quiz/fact bank/mind map are used instead.
- **Voice-message transcription.** No on-device Arabic speech model and no external provider configured; no audio is uploaded.
- **Live challenge and live ranking.** No server-authoritative clock or ranking; the entry point is absent/replaced by an explanation.
- **Cloud storage and public file links.** Files stay in private batch storage.
- **Server sync of batches, schedules, updates and exams.** Everything is stored per account on this device.
- **Sending an issue report to the app team.** The report is saved locally.
- **Server-side authoritative exam timing.** Timing and grading use the device clock, with that limitation stated in the UI.

## Security and privacy decisions

- No login is invented. The 8-digit invite code is generated with a
  cryptographically secure RNG, checked atomically against the local
  registry, and rate-limited on guesses. It is described as discovery, not
  authentication.
- Roles and memberships are never trusted from the caller: every repository
  method re-authorizes the uid and batch on the device.
- Classroom media, chat and recordings live in private per-account/batch
  storage; there are no public permanent URLs.
- Chat text, voice content, invite codes, transcripts, exam answers, AI
  prompts and private file paths are not logged.
- The audit log is local, capped at 200 entries, stores no message text or
  exam answers, and the UI states that it is not tamper-proof.
- Clearing the cache removes only extracted text and thumbnails; originals
  are untouched.

## Caps

| Item | Cap |
| --- | --- |
| Audit entries | 200 (UI shows the latest 12) |
| Subjects per batch | 30 |
| Batch name / subject name | 60 / 40 chars |
| Update title / body | 120 / 20,000 chars |
| Updates stored | 200 |
| Schedule entries / warnings | 100 / 20 |
| Exams / questions per exam | 100 / 50 |
| Exam duration | 180 minutes |
| Attempts per exam | policy: once / limited (1–10) / unlimited; 20 attempt files kept |
| Chat text / voice | 4,000 chars / 15 minutes |
| Import size | 250 MB general, 100 MB PDF, 20 MB image |
| PDF pages | 500 pages; OCR up to 50 scanned pages |
| Note text | 20,000 chars |

## English

`assets/i18n/en_extra.json` now carries English for 712 batch/settings
strings added or aligned by this feature (1,069 entries total). Strings built
with Dart interpolation that embed Arabic-Indic digits, dates or localised
labels (for example counts and AM/PM markers) still fall back to Arabic in
English mode, and the language dialog says that English is partial. Arabic
remains the complete interface.

## Verification

- Locally: `dart analyze lib test` is clean. Formatting was applied only to
  new or touched files because the local Dart formatter applies the newer
  tall style to the whole tree.
- Widget and unit tests cannot run on this ARM64 phone with the vendored
  Flutter tool; they run in CI.
- CI workflow **Build APK** runs analyze, the full Flutter test suite, and a
  release APK build. Each phase was pushed and watched to a green
  conclusion. Phase 9's first run failed on a Flutter ListTile ink assertion
  in the settings card; the card was moved onto a `Material` surface and the
  re-run passed.
- Phase 10 adds: full English strings for the batch surfaces, theme-token
  contrast (`onPrimary` instead of white badges), reduced motion for the
  recording level meter, a narrow-RTL/large-text widget test for the admin
  dashboard, and this report.

## Manual device checklist

Run against the release APK, online first and then in airplane mode.

1. Arabic RTL on all batch screens; switch to English and confirm the batch
   navigation, empty states and blocked cards are English.
2. Create a batch, note the code, reopen it, and join with a second account
   on the same device. Confirm a code from another device is not found and
   the copy says why.
3. Claim guest batches into a signed-in account; confirm the wording says
   the move is local and not reversible automatically.
4. Add a PDF, extract text, run the quiz, fact bank and mind map; confirm a
   password-protected PDF shows the blocked message.
5. Upload audio, play it, record a voice note, send text, pin/edit/delete,
   then mute the membership and confirm the composer is replaced by a
   read-only notice.
6. Import a timetable picture, correct rows, publish, check the reminder
   permission and confirm a notification appears 10 minutes before a lesson;
   change the device timezone and confirm the stated behaviour.
7. Publish an update and confirm another account on the device sees the
   unread marker; confirm no push notification claim is made.
8. Author an exam, open it, let the timer expire, and confirm auto-submit and
   the configured result policy.
9. Owner admin: rotate and revoke the code (with confirmations), toggle each
   policy (including the close-uploads confirmation), prune the cache, read
   the audit log, and delete a batch after the confirmation.
10. Replay the tutorial at step 13, leave midway, reopen and confirm it
    resumes; enable “remove animations” and confirm the tour card and level
    meter stop animating.
11. Check all four appearances for contrast, set 1.5× text and a 360 dp
    width, and confirm no overflow on the batches list, hub, admin and
    tutorial.
12. In airplane mode, repeat steps 2–10 and confirm the blocked cards still
    tell the truth; inspect logcat and confirm no chat text, voice content,
    invite code, transcript, exam answer, AI prompt or private file URL is
    logged.

## Assumptions

- Photos and timetable questions never invent dates, timezones or recurrence;
  unclear rows stay manual and are marked uncertain.
- Weekly schedule defaults to the seven days; reminders are device-local,
  may be inexact on Android, and roll four weeks ahead.
- Updates are owner/admin-authored; read state is per account; notification
  payloads carry ids only.
- Exams are multiple-choice only; the default result policy is “immediately
  on submission”; no time limit means no deadline; attempt files keep the
  newest 20.
- Live ranking, live challenge, the server clock and transcription are
  blocked as described above.
- The tutorial is a bottom card without anchor cut-outs, keyed by step
  number, and offers a real “open this screen” action instead of navigating
  automatically.
- Local administration shows the latest 12 audit entries of the capped 200 and
  states that the log is not tamper-proof.
- The audit log records action identifiers and resource ids, never message
  text, answers or private paths.
- English translations are partial for interpolated strings, as stated in the
  language dialog.
