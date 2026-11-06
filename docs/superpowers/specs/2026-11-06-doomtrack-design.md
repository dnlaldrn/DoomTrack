# DoomTrack — Design Spec

Date: 2026-11-06
Status: Approved in brainstorming, pending written-spec review

## 1. Purpose

College students lose sleep, focus, and calm to unintentional late-night doomscrolling.
DoomTrack is an Android app that tracks social media sessions, shows usage reports, and
interrupts late-night sessions with a nudge → breathing pause → alternative activity flow.

**Context:** capstone project, demo + write-up due in 20 days (deadline ≈ 2026-11-26).
One developer (Person A) builds the app in testable stages (section 8); Person B tests each stage on devices;
Person C owns the write-up and demo.

**Success criteria (for the capstone):**
- The full flow works live at the demo: open a tracked app during bedtime → nudge → breathing → activities.
- Reports show correct per-app usage for today and the last 7 days, including the post-bedtime share.
- The app runs on at least 2 phone brands, with known limits documented.

## 2. Constraints

- Flutter, Android only. No iOS.
- Data stays on the device: only app package/name, timestamps, and durations, plus settings. No network calls.
- No app blocking. Interventions are notifications and in-app screens only.
- No medical claims in UI copy or the write-up (say "may help you wind down", never "improves sleep").
- Detection may vary on phones that kill background services (Xiaomi, Oppo, Samsung). This is documented, not hidden.

## 3. Scope

### Core (must ship)
1. **Onboarding:** step-by-step permission grants: Usage Access (`PACKAGE_USAGE_STATS`, via system Settings),
   notifications (Android 13+), and the battery-optimization exemption. Each step shows whether it's granted.
2. **Tracking:** sessions per tracked app, imported from Android's usage history.
3. **Reports:** today's total, a 7-day bar chart, the top apps, and the minutes used after bedtime started.
4. **Bedtime mode:** a start/end time (may cross midnight) and a session limit in minutes (default 10).
5. **Nudge → Breathing → Activities:**
   - During bedtime, when a tracked-app session passes the limit, send one notification per session.
   - Tapping it opens the Breathing screen: a 60-second guided animation (4s in, 4s hold, 6s out), skippable.
   - Breathing ends on the Activities screen: a fixed list (stretch, journal, read, drink water, set an alarm and sleep).
6. **Demo mode:** a toggle in Settings that sets the limit to 30 seconds and treats the current time as bedtime.

### Stretch (only after Stages 0–6 pass)
7. **Intention check:** when a tracked app opens during bedtime, a notification with 5 / 15 / 30 min action buttons.
   The chosen minutes replace the limit for that session.

### Out of scope
iOS, app blocking, cloud sync or accounts, sleep tracking, analytics, overlays (`SYSTEM_ALERT_WINDOW`), AccessibilityService.

## 4. Architecture

**Packages:** `usage_stats`, `flutter_foreground_task`, `flutter_local_notifications`, `sqflite`, `fl_chart`,
`shared_preferences`. Stage 0 confirms each one builds with the team's Flutter SDK. If `usage_stats` fails,
fall back to a ~50-line Kotlin method channel over `UsageStatsManager.queryEvents`.

**Two independent paths:**

```
Reports path (reliable)                        Nudge path (best-effort)
App opened / resumed                           Foreground service, bedtime only
  → UsageRepository.sync()                       → every 15s: query events from the last 5 min
    → usage_stats events since lastSync            → current foreground tracked app + session start
    → SessionBuilder → sessions                    → elapsed > limit && not yet nudged for this session
    → sqflite                                        → notification (tap → /breathing)
  → Reports screen reads sqflite
```

If the service is killed, the reports stay correct; only nudges are lost.

### Components

| Unit | Responsibility | Depends on |
|---|---|---|
| `SessionBuilder` | Pure function: `List<UsageEvent> → List<Session>`. Pairs foreground/background events per package; closes open sessions on screen-off or at the end of the query window. | nothing |
| `UsageRepository` | `sync()` imports events since `lastSync` (max 7 days back), dedupes by (package, start), saves sessions. Query methods for reports. | usage_stats, sqflite, SessionBuilder |
| `BedtimeWatcher` | Foreground-task handler. Starts at bedtime start, stops at bedtime end (scheduled on app open plus a check on each tick). Keeps an in-memory "nudged session start" so each session gets one nudge. | usage_stats, notifications, settings |
| `Settings` | Bedtime start/end, limit, tracked package list, demo mode. Stored in shared_preferences. | shared_preferences |
| Screens | Onboarding, Home/Reports, Settings, Breathing, Activities | the units above |

**Tracked apps:** default list of Instagram, TikTok, Facebook, X, YouTube, Snapchat, Reddit (by package name).
Settings lets the user toggle each one; apps that aren't installed are hidden.

## 5. Data

`sessions` table:

| column | type |
|---|---|
| id | INTEGER PK |
| package | TEXT |
| app_name | TEXT |
| start_ms | INTEGER |
| end_ms | INTEGER |
| duration_sec | INTEGER |

Unique index on (package, start_ms). Settings and `lastSync` live in shared_preferences.
No other data is stored. "Post-bedtime minutes" are computed at query time from the bedtime window.

## 6. Error handling

- **Usage Access revoked:** a home-screen banner with a button that reopens the Settings intent; reports show cached data.
- **Notifications denied:** a banner explaining that nudges won't appear.
- **Service killed / OEM restrictions:** a "Nudges may be unreliable on this phone" tip with a link to battery settings.
  Reports are unaffected.
- **Usage-history gap:** Android keeps only a few days of events. If `lastSync` is older than that, import what exists
  and show "Some older data is unavailable."
- **Session crosses midnight:** stored once; reports split its duration at midnight between the two days.

## 7. Testing

**Unit tests (`SessionBuilder` and the report math):**
- normal foreground → background pair
- overlapping events from two apps
- a session crossing midnight
- a session ending on screen-off with no background event
- a foreground event with no matching close (closed at the end of the query window)
- a duplicate import that's already in the database (deduped)
- the post-bedtime calculation with a bedtime that crosses midnight

**Manual device checklist (Person B, on 2 brands):**
- onboarding grants all 3 permissions
- in demo mode, the nudge arrives within about 45 seconds of opening a tracked app
- tapping the nudge opens Breathing, and Breathing leads to Activities
- reports match the phone's built-in Digital Wellbeing numbers within about 5%
- the service survives screen-off for 30 minutes and restarts after a reboot (record pass/fail per brand)
- the permission-revoked banner appears

## 8. Build stages

Each stage ends in something you can run on a real phone. Don't start the next stage until the
current one's test passes. Person B re-runs the earlier stages' tests on the second phone brand
after each stage.

| Stage | Build | Test: done when |
|---|---|---|
| **0. Plugin proof** | Flutter project; add packages; a temporary debug screen that lists raw usage events from the last hour | You open Instagram, come back, and see its foreground/background events. If not, switch to the Kotlin fallback before going on. |
| **1. Onboarding** | Permission steps for Usage Access, notifications and the battery exemption, each showing its granted state | A fresh install walks through all 3; revoking one in system Settings shows it as not granted again |
| **2. Tracking** | `SessionBuilder` (pure Dart), `UsageRepository.sync()`, the sqflite `sessions` table; the debug screen now lists sessions | All `SessionBuilder` unit tests in section 7 pass; today's per-app minutes match Digital Wellbeing within about 5%; opening the app twice adds no duplicates |
| **3. Reports** | Home screen with today's total, top apps, the 7-day bar chart and post-bedtime minutes | The numbers match the Stage 2 debug list; the post-bedtime unit test passes; the debug screen can be removed |
| **4. Bedtime + nudge** | Settings screen (bedtime window, limit, tracked apps, demo mode), `BedtimeWatcher` in a foreground task, nudge notification | In demo mode, a nudge arrives within about 45s of opening a tracked app, only once per session; no nudge outside bedtime with demo mode off |
| **5. Breathing + Activities** | 60s breathing animation (skippable), Activities list, notification tap → `/breathing` | Tapping the nudge (app closed and app open) opens Breathing, which ends on Activities |
| **6. Hardening** | Permission and battery banners, the usage-history gap message, the full device checklist from section 7 on 2 brands | Every checklist item passes or has a documented per-brand result. **The core is now demo-ready.** |
| **7. Intention check** *(stretch)* | 5/15/30 action buttons on a bedtime notification when a tracked app opens; the choice overrides the limit | Picking 5 min in demo mode delivers the nudge about 5 minutes later |

Person C writes the write-up from this spec in parallel, and writes the demo script once Stage 5 passes.

## 9. Risks

| Risk | Mitigation |
|---|---|
| A plugin doesn't work with the current Flutter SDK | Checked in Stage 0; Kotlin method-channel fallback |
| An OEM phone kills the foreground service | Battery-exemption step during onboarding; document per-brand results; reports don't depend on the service |
| The nudge fails during the live demo | Demo mode (30s limit) tested on the demo phone the day before; screen recording as a backup |
| Running out of time | Stage 7 is cut first, then the 7-day chart in Stage 3 (keep only today) |
