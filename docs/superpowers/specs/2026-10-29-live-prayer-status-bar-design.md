# Live prayer times and a persistent prayer bar — Design

**Date:** 2026-10-29
**Status:** Approved — implemented (plan: `docs/superpowers/plans/2026-10-29-live-prayer-status-bar.md`)
**Approach:** C — OS-rendered chronometer notification + native boundary alarms
**Scope decision:** keep the existing in-app live clock; add the missing system
surface; harden the clock's timezone/lifecycle edges.

## Intent

The prayer feature must feel alive everywhere, not only while its screen is
open. The user asked for two things:

1. prayer times and the Fajr/next-prayer countdown to be continuously live;
2. a persistent notification bar that shows the next prayer and its countdown
   even when the app is closed.

This document is the result of an adversarial review of both requirements
against the code that exists today.

## Ground truth from the code

The in-app countdown is **already live**:

- `lib/features/prayer/prayer_providers.dart:49` — `prayerClockProvider` is a
  one-second aligned `StreamProvider.autoDispose`; its timer is cancelled when
  the provider is disposed (`test/prayer_clock_test.dart` pins this).
- `prayerTimesTodayProvider` recomputes the astronomical times only when the
  calendar day, location or calculation settings change.
- `prayerDayProvider` rebuilds every second and is consumed by the home pill
  (`lib/features/home/widgets/prayer_pill.dart:64`), the prayer screen
  (`lib/features/prayer/prayer_screen.dart:26`) and the home card
  (`lib/features/prayer/prayer_home_card.dart:64`).
- `PrayerDay.fromTimes` already resolves tomorrow's Fajr after Isha and
  yesterday's Isha before Fajr (`lib/features/prayer/prayer_models.dart:190`).

So a blind "convert the countdown to a stream" rewrite would be a regression,
not a fix. The genuine gaps are:

- there is **no persistent system notification** at all;
- the day key used by `prayerTimesTodayProvider` ignores the UTC offset, so a
  timezone change that does not change the local date can keep a stale
  calculation;
- the app has no forced refresh of the prayer providers on resume (the clock
  self-corrects on its next tick, but the cached day is not invalidated);
- the four home-screen widgets never receive prayer data from Dart (out of
  scope here, recorded as a known gap).

The report of a "static" in-app countdown is therefore most likely one of:
(a) the device build is older than this source, (b) the app was killed and the
reported surface was a system notification/widget, or (c) an OEM froze the
Flutter isolate. The plan below fixes the system surface and the lifecycle
edges, and adds a diagnostic note so the premise is verified on-device before
any in-app clock code is touched.

## Goals

- One ongoing, silent notification showing the next prayer name, its clock
  time, the city, and a countdown that ticks **every second with the app
  closed**.
- Correct transitions at every prayer boundary, including tomorrow's Fajr
  after Isha.
- The bar survives app closure and reboots, and is refreshed on timezone,
  date, location and calculation-method changes.
- No foreground service, no wake lock, no per-second Dart timer, no new
  astronomy implementation in Kotlin.
- A visible on/off switch in the adhan settings, and a bar that is always
  cancelled when the adhan master switch is off, notifications are denied, or
  no location is saved.
- The existing in-app countdown keeps working exactly as it does now.

## Non-goals

- Redesigning the in-app prayer screens or the home pill.
- Replacing `adhan_dart` or moving prayer calculation to Kotlin.
- Background adhan audio playback changes (the existing `AdhanPlaybackService`
  stays as it is).
- Live home-screen widget updates (separate backlog item; the widget
  providers currently read preferences that Dart never publishes).
- iOS behavior (this codebase ships Android; iOS fallbacks stay best-effort).
- A truly unremovable notification. That requires a foreground service, and
  the battery/policy cost was rejected by the council.

## Anti-goals

- A `Timer.periodic(1s)` in Dart that re-posts a notification. It stops when
  the process is killed, burns CPU while alive, and does not meet the
  requirement.
- A 24/7 foreground service just to animate a countdown. SystemUI already
  animates a chronometer for free.
- Duplicating the prayer calculation in Kotlin, which would create two sources
  of truth that drift across method/madhab changes.
- Scheduling five status notifications per day with the same notification id
  through `flutter_local_notifications`: the plugin keeps one pending request
  per id and replaces the previous one (`FlutterLocalNotificationsPlugin.java`,
  `saveScheduledNotification`), so only the last boundary would survive.

## Constraints

- Flutter + Riverpod 2; notifications through
  `flutter_local_notifications` 17.2.4.
- `adhan_dart` returns UTC instants; all display times are `.toLocal()`.
- Android 13+ needs `POST_NOTIFICATIONS`; Android 12+ may deny exact alarms.
- Android 14 caps exact alarms per app (≈500); the 8-day horizon is well under
  the cap.
- The repository does not commit Gradle files; CI regenerates them. Adding
  Kotlin sources and manifest components is supported and survives
  `flutter create` (committed files are not overwritten).
- `flutter_local_notifications` provides `usesChronometer`,
  `chronometerCountDown`, `when`, `showWhen`, `ongoing` and `onlyAlertOnce`,
  but it is still limited to one pending request per notification id.
- SystemUI renders a countdown chronometer without any app process; the app
  only has to update the target at prayer boundaries.

## Approaches considered

### A. Dart timer re-posts the notification every second

- Pure Dart, no native code.
- Dies when the app process is killed, which is the exact case the bar exists
  for. High battery cost. Rejected.

### B. Native foreground service updates the notification

- Guarantees updates while alive and can show richer content.
- Requires a permanent foreground service, a service-type declaration, a
  notification that users cannot dismiss, OEM battery exemptions, and either a
  second calculation implementation or a Dart-to-native clock bridge. This is
  disproportionate for a countdown that SystemUI can animate itself. Rejected
  as the default.

### C. Ongoing chronometer notification + native boundary alarms (chosen)

- Dart computes the existing 8-day prayer window once per sync and hands the
  ordered boundaries to a small Kotlin bridge.
- Kotlin posts one `ongoing`, low-importance notification whose chronometer
  counts down to the next boundary. SystemUI updates it every second for free.
- Kotlin schedules one exact alarm per boundary (unique request codes). Each
  alarm re-posts the notification with the following boundary as the new
  target.
- A boot/timezone/time receiver reloads the stored schedule and re-arms the
  alarms after a reboot, app upgrade or clock change.
- Tradeoffs: one small native module; if the app is force-stopped the OS
  clears its alarms (inherent to Android); an inexact alarm can delay a
  boundary update, after which the chronometer counts up until the update
  lands.

### D. Native `AlarmManager` updates through `flutter_local_notifications`

- Same boundary behavior as C, but reuses FLN's receiver and cache.
- FLN owns its PendingIntents and one-pending-per-id cache, so a shared-id
  update at every boundary is not expressible. Using unique ids creates
  multiple visible notifications. Rejected as more fragile than C.

## Decision

Approach C. The council's deciding argument: the second-by-second part is a
rendering concern that the OS already solves; the only work the app must do is
change the target five times a day and survive reboots. That is an alarm
problem, not a streaming problem.

## Architecture

```
adhan_dart (Dart)
   │  PrayerTimes × 8 days
   ▼
PrayerAdhanScheduler._sync()  (Dart, existing)
   │  ordered PrayerStatusBoundary[] + city + enabled
   ▼
PrayerStatusBar (Dart MethodChannel wrapper, new)
   │  zaker/prayer_status  "sync" / "cancel"
   ▼
PrayerStatusBridge (Kotlin, new)
   │  stores JSON in SharedPreferences
   │  posts/updates the ongoing notification
   │  AlarmManager exact/inexact per boundary, requestCode = 9100 + index
   ▼
PrayerStatusReceiver (Kotlin, new)
   │  on alarm: read schedule, find first boundary after now,
   │            post notification for the *following* boundary
   │  on BOOT_COMPLETED / MY_PACKAGE_REPLACED / TIME_SET / TIMEZONE_CHANGED:
   │            re-arm all alarms, re-post the current target
   ▼
SystemUI chronometer  →  1 Hz countdown, no app process
```

Tap behavior: the notification's content intent opens `MainActivity` with
`route = "/prayer"`. `MainActivity` forwards it through the same
`zaker/prayer_status` channel; Dart calls `appRouter.go('/prayer')`. If the
bridge is unavailable, the app simply opens on the home screen.

## Data contract

`zaker/prayer_status` → `sync`:

```json
{
  "enabled": true,
  "city": "القاهرة",
  "boundaries": [
    {"at": 1793350800000, "name": "العصر", "hour": 15, "minute": 10},
    {"at": 1793361600000, "name": "المغرب", "hour": 17, "minute": 40}
  ]
}
```

- `boundaries` is sorted ascending, covers `kAdhanHorizonDays` (8) days, and
  contains only boundaries strictly after `now + 5s`.
- `at` is an absolute epoch in milliseconds (UTC semantics; Kotlin formats the
  local clock time from `hour`/`minute` supplied by Dart, so a timezone change
  is reflected by the next sync while the countdown target stays correct).
- `name` is the Arabic prayer label; `hour`/`minute` are 24-hour local values.
- The immediate notification target is `boundaries[0]`. The alarm at
  `boundaries[i]` re-posts with target `boundaries[i + 1]`.
- `cancel` takes no arguments: cancels the notification and every alarm.

## Notification specification

- Channel id `zaker_prayer_status`, name «شريط مواقيت الصلاة», `IMPORTANCE_LOW`,
  no sound, no vibration, no badge.
- Notification id `9000` (outside the adhan/reminder/salat/azkar/hifz ranges).
- Title: «الصلاة القادمة: العصر» (the name comes from Dart).
- Text: «٣:١٠ م • القاهرة».
- `setOngoing(true)`, `setAutoCancel(false)`, `setOnlyAlertOnce(true)`,
  `setShowWhen(true)`, `setWhen(boundary.at)`, `setUsesChronometer(true)`,
  `setChronometerCountDown(true)` on API 24+.
- `setVisibility(PRIVATE)` with a public version «رفيق الطالب — مواقيت الصلاة»
  so the city is not exposed on the lock screen.
- Small icon `R.drawable.ic_adhan_notification` (already present).
- Channel creation is idempotent; Android ignores an identical channel. This
  is a **new** channel id, so a future importance change is possible without
  fighting channel immutability.

## Settings

- Add `statusBarEnabled` (default `true`) to `AdhanSettings`, persisted under
  the existing `adhan_settings` JSON as `statusBar`.
- `AdhanSettingsController.setStatusBarEnabled(bool)`.
- Effective state: `enabled && statusBarEnabled && location != null &&
  notificationsAllowed`.
- In `AdhanSettingsScreen`, add a switch under the adhan master switch:
  «شريط المواقيت الدائم» with the subtitle «يعرض الصلاة القادمة والعد
  التنازلي في شريط الإشعارات، حتى والتطبيق مقفول.»
- Turning the master switch off cancels the bar immediately. Turning
  notifications off in system settings cancels it on the next sync.
- No new permission beyond the existing `POST_NOTIFICATIONS`. Exact alarms
  use the existing `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` setup and fall back
  to inexact exactly like the adhan.

## In-app hardening (small, surgical)

1. `prayerTimesTodayProvider`: include `now.timeZoneOffset.inMinutes` in the
   selected day key so a timezone change recomputes the day.
2. `prayerHijriProvider`: include the same offset in its key.
3. `AdhanSyncHost.didChangeAppLifecycleState(resumed)`: invalidate
   `prayerTimesTodayProvider` and `prayerHijriProvider` before syncing, so a
   resumed app never shows a value computed in another zone.
4. Keep `prayerClockProvider` as-is. Do **not** replace it with
   `Timer.periodic`; the alignment logic is correct and already tested.
5. Add a short diagnostic line to the existing diagnostics screen explaining
   that the in-app countdown pauses only while the process is suspended, and
   that the system bar is the surface that keeps counting.

## Files to touch

Dart:

- `lib/features/prayer/prayer_providers.dart` — timezone key; resume refresh
  hooks if placed here.
- `lib/features/prayer/adhan_models.dart` — `statusBarEnabled`, JSON,
  `copyWith`, equality/hash.
- `lib/features/prayer/adhan_providers.dart` — setter.
- `lib/features/prayer/adhan_scheduler.dart` — build the boundary list from
  the existing 8-day loop; call `PrayerStatusBar.sync`/`cancel`; keep the
  status id out of `cancelPrayerNotifications`.
- `lib/core/prayer_status_bar.dart` (new) — MethodChannel wrapper, guarded
  like `AdhanPlatform`.
- `lib/features/prayer/adhan_sync_host.dart` — invalidate providers on resume.
- `lib/features/prayer/adhan_settings_screen.dart` — the switch and its
  explanation.
- `lib/main.dart` — wire the route callback if the bridge reports a tap.

Kotlin:

- `android/app/src/main/kotlin/com/zaker/zaker_ai/PrayerStatusBridge.kt` (new)
  — channel handler, notification, alarm scheduling/cancel, JSON persistence.
- `android/app/src/main/kotlin/com/zaker/zaker_ai/PrayerStatusReceiver.kt` (new)
  — boundary alarm + boot/time/timezone handling.
- `android/app/src/main/kotlin/com/zaker/zaker_ai/MainActivity.kt` — register
  the channel; forward the tap route.
- `android/app/src/main/AndroidManifest.xml` — declare the receiver
  (`exported="false"`, actions `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`,
  `TIME_SET`, `TIMEZONE_CHANGED`).

Tests:

- `test/prayer_day_boundaries_test.dart` (new) — `PrayerDay.fromTimes` at the
  exact Fajr second, just after Isha (tomorrow's Fajr), and across midnight.
- `test/prayer_status_settings_test.dart` (new) — default on, JSON round-trip,
  setter persistence.
- `test/prayer_status_boundaries_test.dart` (new) — the pure function that
  turns `PrayerTimes × 8 days` into the ordered, future-only boundary list
  (extract it so it is testable without a MethodChannel).
- Keep `test/prayer_clock_test.dart` and `test/prayer_pill_test.dart` green.

## Edge cases and second-order effects

| Case | Behavior |
| --- | --- |
| App killed normally | Notification persists; SystemUI keeps counting; alarms fire. |
| App force-stopped | Android clears alarms and notifications. Nothing can survive; documented. |
| Reboot | `PrayerStatusReceiver` re-arms from prefs and re-posts; `RECEIVE_BOOT_COMPLETED` already granted. |
| App upgrade | `MY_PACKAGE_REPLACED` re-arms. |
| Timezone / clock change | `TIME_SET`/`TIMEZONE_CHANGED` re-arm and re-post; the next Dart sync refreshes display times. |
| Exact alarm denied | Inexact fallback; a boundary may update late, so the chronometer counts up briefly. |
| Notifications denied | No post; the settings switch explains the system permission. |
| User swipes the ongoing notification | On stock Android `setOngoing(true)` prevents it; where an OEM allows it, the next boundary or app resume restores it. |
| Adhan at the same second | The adhan uses its own id/channel and still alerts; the bar updates silently with `onlyAlertOnce`. |
| Prayer method/madhab/location change | Existing listeners call `_sync`, which rebuilds the boundary list and re-arms. |
| 8-day horizon exhausted | Bar stops updating until the app is opened again (same limitation as the adhan window). Consider raising to 14 days only if alarm counts stay under the cap. |
| DST | Boundaries are absolute epochs; display strings come from Dart's local calculation. |
| Lock-screen privacy | `VISIBILITY_PRIVATE` + a generic public version hides the city. |
| Arabic/English UI | The bar is Arabic-first; the app's English locale keeps Arabic prayer names for v1 (recorded as acceptable). |

## Verification

1. Local: `dart analyze` on the touched paths (use the ARM64 Dart SDK under
   `work/dartsdk`), and `dart format` only the touched files.
2. Widget/unit tests on a scratch CI probe branch (the repository's Flutter
   tests run in CI, not locally); then the full workflow.
3. Device checks:
   - post the bar, kill the app, confirm the chronometer still decrements;
   - let a boundary pass with the app killed and confirm the title/time roll
     to the next prayer;
   - reboot and confirm the bar returns;
   - change the device timezone and confirm the displayed time corrects after
     the next app sync or boundary;
   - revoke notification permission and confirm the bar disappears;
   - turn the adhan master switch off and confirm the bar and alarms clear;
   - switch calculation method and confirm the boundaries change.

## Open decisions for the user

- Default of the switch: the council recommends **on** when the adhan master
  switch is enabled and notifications are granted, with an obvious off switch.
  An opt-in default is the safer alternative if notification fatigue is a
  concern.
- Whether the bar should show the city on the lock screen. The council
  recommends **not** (private visibility).
- Whether to raise the horizon from 8 to 14 days. The council recommends
  keeping 8 to match the adhan window and to stay far below Android's alarm
  cap.
