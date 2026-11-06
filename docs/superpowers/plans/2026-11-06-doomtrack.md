# DoomTrack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Android Flutter app that tracks social-media sessions on the device, shows usage reports, and interrupts bedtime sessions with a nudge → breathing → activities flow.

**Architecture:** Two independent paths. The reports path imports Android usage events into sqflite whenever the app opens. The nudge path is a foreground task that checks every 15s and sends a notification. Pure Dart units (`buildSessions`, report math, `isInBedtime`, `NudgeDecider`) hold all the logic and carry the unit tests; plugin wrappers stay thin.

**Tech Stack:** Flutter (Android only), `usage_stats`, `flutter_foreground_task`, `flutter_local_notifications`, `sqflite`, `fl_chart`, `shared_preferences`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-06-doomtrack-design.md`

## Global Constraints

- Android only. No iOS code paths and no iOS folder work.
- No network calls. Store only package, app name, start/end timestamps, duration, and settings.
- No app blocking, no `SYSTEM_ALERT_WINDOW`, no AccessibilityService.
- UI copy makes no medical claims ("may help you wind down", never "improves sleep").
- Default session limit: 10 min. Demo mode: limit 30 s, always counts as bedtime.
- Breathing: 60 s total, cycles of 4 s in / 4 s hold / 6 s out, skippable.
- Activities (fixed list): Stretch, Journal, Read, Drink water, Set an alarm and sleep.
- Watcher tick: every 15 s, looking back 5 min of events. One nudge per session.
- Import window: at most 7 days back.
- Default tracked packages: `com.instagram.android`, `com.zhiliaoapp.musically`, `com.ss.android.ugc.trill`, `com.facebook.katana`, `com.twitter.android`, `com.google.android.youtube`, `com.snapchat.android`, `com.reddit.frontpage`.

## Review Focus

1. **Out-of-order events** (clock change, plugin ordering): sessions must come out the same as for sorted input. *Test in Task 3:* `sorts unsorted events`.
2. **Briefly leaving and returning to the same app** (notification shade, a quick reply): a gap under 30 s should not split the session, or the nudge timer resets. *Test in Task 3:* `merges same-app gap under 30s`.
3. **Bedtime start == end, or a window crossing midnight:** equal times mean never in bedtime; 23:00–06:00 covers 23:30 and 05:59 but not 06:00. *Tests in Task 6:* `isInBedtime` cases.
4. **Settings changed while the watcher is running:** the next tick must use the new values, with no restart needed. *Test in Task 7:* the watcher reloads settings on every tick (checked in the manual gate step).
5. **Tapping a nudge while the app is fully closed:** it must still open Breathing. *Task 8 gate:* the cold-start case.

## File Structure

```
doomtrack/
  lib/
    main.dart                        app, routes, navigatorKey, notification-tap routing
    tracking/
      usage_event.dart               UsageEvent, UsageEventKind
      session.dart                   Session
      session_builder.dart           buildSessions() — pure
      usage_source.dart              queryEvents() — wraps usage_stats
      tracked_apps.dart              kDefaultTrackedApps
      usage_repository.dart          sqflite + sync()
    reports/report_math.dart         secondsPerDay(), secondsInWindow(), topApps() — pure
    settings/settings.dart           Settings, isInBedtime(), SettingsStore
    nudge/nudge_decider.dart         NudgeDecider — pure
    nudge/notifications.dart         init + showNudge()
    nudge/bedtime_watcher.dart       TaskHandler + startWatcher()
    screens/
      debug_screen.dart              temporary (Tasks 1–4)
      onboarding_screen.dart
      home_screen.dart
      settings_screen.dart
      breathing_screen.dart
      activities_screen.dart
  test/
    tracking/session_builder_test.dart
    reports/report_math_test.dart
    settings/settings_test.dart
    nudge/nudge_decider_test.dart
```

---

## Stage 0 — Plugin proof

### Task 1: Project, permissions manifest, raw event debug screen

**Files:**
- Create: `doomtrack/` (via `flutter create`), `lib/tracking/usage_event.dart`, `lib/tracking/usage_source.dart`, `lib/screens/debug_screen.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`, `lib/main.dart`

**Interfaces:**
- Produces:
  - `enum UsageEventKind { foreground, background, screenOff }`
  - `class UsageEvent { final String package; final int timeMs; final UsageEventKind kind; const UsageEvent(this.package, this.timeMs, this.kind); }`
  - `Future<List<UsageEvent>> queryEvents(int startMs, int endMs)` in `usage_source.dart`

- [ ] **Step 1:** Run `flutter create --org com.doomtrack --platforms android doomtrack`, then `git init` inside `doomtrack/`. Copy the spec and plan into `doomtrack/docs/superpowers/`.
- [ ] **Step 2:** `flutter pub add usage_stats flutter_foreground_task flutter_local_notifications sqflite fl_chart shared_preferences`. Run `flutter build apk --debug`. Expected: the build succeeds. If a plugin fails against the SDK, pin the newest version that builds and write it in a comment in `pubspec.yaml`.
- [ ] **Step 3:** Add these to the manifest: `PACKAGE_USAGE_STATS` (with `tools:ignore="ProtectedPermissions"`), `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `RECEIVE_BOOT_COMPLETED`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, plus the `<service>` entry that `flutter_foreground_task`'s README requires (`foregroundServiceType="specialUse"`). Add a `<queries>` entry for each package in `kDefaultTrackedApps` so app labels resolve.
- [ ] **Step 4:** Implement `queryEvents` using `UsageStats.queryEvents(DateTime, DateTime)`. Map Android event types: `"1"` → foreground, `"2"` → background, `"16"` → screenOff; drop all others. Screen-off events have no useful package, so store `''`.
- [ ] **Step 5:** `DebugScreen`: a button that calls `UsageStats.grantUsagePermission()`, and a list of `queryEvents(now - 1h, now)` showing time, package and kind. Make it `main.dart`'s home screen.
- [ ] **Step 6 — GATE:** On a real phone: grant Usage Access, open Instagram for about 20 s, return to DoomTrack, tap refresh. Expected: `com.instagram.android` foreground, then background, about 20 s apart. **If this fails,** replace `usage_source.dart` with a Kotlin `MethodChannel("doomtrack/usage")` that calls `UsageStatsManager.queryEvents` and returns the same three kinds. Keep the same Dart signature.
- [ ] **Step 7:** Commit `feat: project setup and raw usage events`.

---

## Stage 1 — Onboarding

### Task 2: Onboarding screen

**Files:** Create `lib/screens/onboarding_screen.dart`. Modify `lib/main.dart`.

**Interfaces:**
- Produces: route `/onboarding`; a shared_preferences bool `onboarded`.

- [ ] **Step 1:** Three rows, each with a status icon and a "Grant" button:
  - Usage Access: `UsageStats.checkUsagePermission()` / `grantUsagePermission()`
  - Notifications: `AndroidFlutterLocalNotificationsPlugin.areNotificationsEnabled()` / `requestNotificationsPermission()`
  - Battery: `FlutterForegroundTask.isIgnoringBatteryOptimizations` / `requestIgnoreBatteryOptimization()`

  Re-check all three in `didChangeAppLifecycleState(resumed)`. "Continue" turns on when Usage Access and Notifications are granted (battery stays optional), then sets `onboarded = true`.
- [ ] **Step 2:** `main.dart`: if `onboarded` is false, start at `/onboarding`; otherwise start at the debug screen (the home screen from Task 5 on).
- [ ] **Step 3 — GATE:** Fresh install: all 3 rows go green after granting. Revoke Usage Access in system Settings and return: that row shows as not granted again.
- [ ] **Step 4:** Commit `feat: onboarding permissions`.

---

## Stage 2 — Tracking

### Task 3: `buildSessions` (TDD)

**Files:** Create `lib/tracking/session.dart`, `lib/tracking/session_builder.dart`, `test/tracking/session_builder_test.dart`.

**Interfaces:**
- Consumes: `UsageEvent`, `UsageEventKind`
- Produces:
  - `class Session { final String package; final String appName; final int startMs; final int endMs; int get durationSec => (endMs - startMs) ~/ 1000; }`
  - `List<Session> buildSessions(List<UsageEvent> events, {required int windowEndMs, required Map<String, String> appNames, Set<String>? onlyPackages})`

Algorithm (not fixed by the tests alone):
- Sort events by `timeMs`. At most one session is open at a time.
- On `foreground(P)`: if P is already open, ignore it. Otherwise close the open session at this time, then open P.
- On `background(P)`: close the session if P is the open one.
- On `screenOff`: close any open session.
- At the end, close any open session at `windowEndMs`.
- Merge consecutive same-package sessions with a gap under 30 s.
- Drop sessions whose package isn't in `onlyPackages` (when given).
- `appName` = `appNames[package] ?? package`.

- [ ] **Step 1: Write the failing tests** (times in seconds × 1000; IG = `com.instagram.android`, TT = `com.zhiliaoapp.musically`):

```dart
test('normal pair', () => expect(b([fg(IG,0), bg(IG,60)]).single, sess(IG,0,60)));
test('second app foreground closes first', () {
  expect(b([fg(IG,0), fg(TT,100), bg(TT,160)]), [sess(IG,0,100), sess(TT,100,160)]);
});
test('screen off closes session', () => expect(b([fg(IG,0), off(90)]).single, sess(IG,0,90)));
test('open session closes at window end', () => expect(b([fg(IG,0)], end: 300).single, sess(IG,0,300)));
test('sorts unsorted events', () => expect(b([bg(IG,60), fg(IG,0)]).single, sess(IG,0,60)));
test('merges same-app gap under 30s', () {
  expect(b([fg(IG,0), bg(IG,60), fg(IG,80), bg(IG,200)]).single, sess(IG,0,200));
});
test('keeps same-app gap of 30s or more split', () {
  expect(b([fg(IG,0), bg(IG,60), fg(IG,90), bg(IG,200)]).length, 2);
});
test('filters untracked packages', () {
  expect(b([fg('com.android.chrome',0), bg('com.android.chrome',60)], only: {IG}), isEmpty);
});
test('appName falls back to package', () => expect(b([fg('x.y',0), bg('x.y',5)]).single.appName, 'x.y'));
```

Write small local helpers (`fg`, `bg`, `off`, `sess`, `b` with default `end: 10000` and `appNames: {}`). `Session` needs `==`/`hashCode` (or compare fields).

- [ ] **Step 2:** `flutter test test/tracking/session_builder_test.dart`. Expected: FAIL (`buildSessions` isn't defined).
- [ ] **Step 3:** Implement `Session` and `buildSessions` as described above.
- [ ] **Step 4:** Run the same command. Expected: all 9 pass.
- [ ] **Step 5:** Commit `feat: session builder`.

### Task 4: Tracked apps + `UsageRepository`

**Files:** Create `lib/tracking/tracked_apps.dart`, `lib/tracking/usage_repository.dart`. Modify `lib/screens/debug_screen.dart`.

**Interfaces:**
- Consumes: `queryEvents`, `buildSessions`, `Session`
- Produces:
  - `const Map<String, String> kDefaultTrackedApps` (the package → label map from Global Constraints; labels: Instagram, TikTok, TikTok, Facebook, X, YouTube, Snapchat, Reddit)
  - `class SyncResult { final int imported; final bool possibleGap; }`
  - `class UsageRepository { static Future<UsageRepository> open(); Future<SyncResult> sync(Set<String> tracked); Future<List<Session>> sessionsBetween(int startMs, int endMs); }`

- [ ] **Step 1:** Implement `open()`: sqflite db `doomtrack.db` with the `sessions` table from spec §5 and `CREATE UNIQUE INDEX ux_sessions ON sessions(package, start_ms)`.
- [ ] **Step 2:** Implement `sync()`:
  - `from = max(lastSync - 10 min, now - 7 days)`; the 10-minute overlap re-reads sessions still open at the last sync.
  - `queryEvents(from, now)` → `buildSessions(windowEndMs: now, onlyPackages: tracked, appNames: kDefaultTrackedApps)` → insert with `ConflictAlgorithm.replace` (so a re-read open session gets its longer end).
  - Save `lastSync = now`.
  - `possibleGap = lastSync != null && now - lastSync > 3 days`, with the comment `// shortcut: Android's event retention varies by OEM; 3 days is a guess, replace with the earliest-event check if the message misfires.`
- [ ] **Step 3:** The debug screen now calls `sync()` on resume and lists today's sessions with their durations.
- [ ] **Step 4 — GATE:** Use Instagram and YouTube for a few minutes each. Today's per-app minutes on the debug screen match Digital Wellbeing within about 5%. Close and reopen DoomTrack twice: the session count doesn't grow.
- [ ] **Step 5:** Commit `feat: usage repository and sync`.

---

## Stage 3 — Reports

### Task 5: Report math (TDD) + home screen

**Files:** Create `lib/reports/report_math.dart`, `test/reports/report_math_test.dart`, `lib/screens/home_screen.dart`. Modify `lib/main.dart`. Delete `lib/screens/debug_screen.dart`.

**Interfaces:**
- Consumes: `Session`, `UsageRepository.sessionsBetween`; `Bedtime` and `bedtimeWindowFor` from Task 6 (until Task 6 exists, use a hardcoded 23:00–06:00 window)
- Produces:
  - `List<int> secondsPerDay(List<Session> s, DateTime firstDay, int days)`: index 0 = `firstDay`, each session split at local midnight
  - `int secondsInWindow(List<Session> s, int startMs, int endMs)`: total overlap
  - `List<MapEntry<String, int>> topApps(List<Session> s, {int limit = 3})`: appName → seconds, descending

- [ ] **Step 1: Write the failing tests:**

```dart
test('session crossing midnight splits across days', () {
  // 23:50 → 00:20 on Nov 5/6
  expect(secondsPerDay([sessAt(DateTime(2026,11,5,23,50), DateTime(2026,11,6,0,20))], DateTime(2026,11,5), 2), [600, 1200]);
});
test('window overlap counts only inside', () {
  expect(secondsInWindow([sessMs(0, 100000)], 50000, 200000), 50);
});
test('post-bedtime with window crossing midnight', () {
  // bedtime 23:00–06:00; session 22:30–23:30 → 30 min after bedtime
  final s = [sessAt(DateTime(2026,11,5,22,30), DateTime(2026,11,5,23,30))];
  expect(secondsInWindow(s, DateTime(2026,11,5,23).millisecondsSinceEpoch, DateTime(2026,11,6,6).millisecondsSinceEpoch), 1800);
});
test('topApps sums per app and sorts', () { /* IG 60+60, TT 100 → [IG:120, TT:100] */ });
```

- [ ] **Step 2:** `flutter test test/reports/report_math_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement the three functions.
- [ ] **Step 4:** Run again. Expected: PASS.
- [ ] **Step 5:** `HomeScreen`: `sync()` on resume, then show: today's total (h m), the top 3 apps, a 7-day `BarChart` (fl_chart) of `secondsPerDay` in minutes, and "After bedtime last night: N min" (the window that started yesterday). Make it the post-onboarding home screen and delete the debug screen.
- [ ] **Step 6 — GATE:** The home screen totals match the numbers you got from the Stage 2 debug screen and Digital Wellbeing. `flutter test` is fully green.
- [ ] **Step 7:** Commit `feat: reports`.

---

## Stage 4 — Bedtime + nudge

### Task 6: Settings (TDD for `isInBedtime`) + settings screen

**Files:** Create `lib/settings/settings.dart`, `test/settings/settings_test.dart`, `lib/screens/settings_screen.dart`.

**Interfaces:**
- Produces:
  - `class Bedtime { final int startMin; final int endMin; }` (minutes since midnight; defaults 23:00 → 06:00)
  - `bool isInBedtime(DateTime now, Bedtime b)`: false when `startMin == endMin`
  - `(int, int) bedtimeWindowFor(DateTime day, Bedtime b)`: start/end ms of the window starting on `day`
  - `class Settings { Bedtime bedtime; int limitMin; Set<String> tracked; bool demoMode; int get effectiveLimitSec => demoMode ? 30 : limitMin * 60; bool inBedtime(DateTime now) => demoMode || isInBedtime(now, bedtime); }`
  - `class SettingsStore { static Future<Settings> load(); static Future<void> save(Settings s); }` using shared_preferences keys `bedStart`, `bedEnd`, `limitMin`, `tracked` (string list), `demoMode`

- [ ] **Step 1: Write the failing tests:**

```dart
const b = Bedtime(23 * 60, 6 * 60);
test('inside before midnight', () => expect(isInBedtime(DateTime(2026,11,6,23,30), b), isTrue));
test('inside after midnight', () => expect(isInBedtime(DateTime(2026,11,7,5,59), b), isTrue));
test('end is exclusive', () => expect(isInBedtime(DateTime(2026,11,7,6,0), b), isFalse));
test('daytime outside', () => expect(isInBedtime(DateTime(2026,11,7,14,0), b), isFalse));
test('equal start/end never in bedtime', () => expect(isInBedtime(DateTime(2026,11,7,1,0), const Bedtime(60, 60)), isFalse));
test('same-day window 13:00–15:00', () => expect(isInBedtime(DateTime(2026,11,7,14,0), const Bedtime(780, 900)), isTrue));
test('demo mode forces 30s and bedtime', () { /* Settings(demoMode: true) → effectiveLimitSec 30, inBedtime(noon) true */ });
```

- [ ] **Step 2:** `flutter test test/settings/settings_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement. Defaults: limit 10, tracked = all `kDefaultTrackedApps` keys, demo off.
- [ ] **Step 4:** Run again. Expected: PASS. Swap Task 5's hardcoded window for `bedtimeWindowFor(yesterday, settings.bedtime)`.
- [ ] **Step 5:** `SettingsScreen`: two `showTimePicker` rows, a limit slider (5–60 min), a switch per tracked app (skip uninstalled apps: `UsageStats.queryUsageStats` over 7 days returns nothing for them, so treat "no usage ever" as hidden), and a "Demo mode (30s limit, always bedtime)" switch. Save on every change. Add a gear icon on the home screen that opens it.
- [ ] **Step 6:** Commit `feat: settings and bedtime`.

### Task 7: `NudgeDecider` (TDD) + notifications + watcher

**Files:** Create `lib/nudge/nudge_decider.dart`, `test/nudge/nudge_decider_test.dart`, `lib/nudge/notifications.dart`, `lib/nudge/bedtime_watcher.dart`. Modify `lib/main.dart`.

**Interfaces:**
- Consumes: `queryEvents`, `buildSessions`, `SettingsStore.load`, `Settings.inBedtime`, `Settings.effectiveLimitSec`
- Produces:
  - `class NudgeDecider { bool shouldNudge({required Session? current, required int nowMs, required int limitSec, required bool inBedtime}); }`: returns true once per `(package, startMs)`; `current == null` → false
  - `Future<void> initNotifications(void Function(String? payload) onTap)` and `Future<void> showNudge(String appName, int minutes)`: payload `'/breathing'`, channel `nudges` (high importance)
  - `Future<void> startWatcher()`: idempotent

- [ ] **Step 1: Write the failing tests:**

```dart
test('no nudge under limit', ...);                    // elapsed 20s, limit 30 → false
test('nudge once when over limit', ...);              // 31s → true; then 46s same session → false
test('new session nudges again', ...);                // different startMs, over limit → true
test('no nudge outside bedtime', ...);                // over limit, inBedtime false → false
test('null current → false', ...);
```

- [ ] **Step 2:** `flutter test test/nudge/nudge_decider_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Implement `NudgeDecider`. Run again. Expected: PASS.
- [ ] **Step 4:** `notifications.dart`: initialize `flutter_local_notifications`. The nudge text is `"You've been on $appName for $minutes min. Take a 1-minute breather?"`.
- [ ] **Step 5:** `bedtime_watcher.dart`: a `TaskHandler` with `onRepeatEvent` every 15 000 ms (`ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.repeat(15000), autoRunOnBoot: true, allowWakeLock: true)`). Each tick:
  1. `SettingsStore.load()` (reloaded every tick so setting changes apply on the next tick; call `SharedPreferences.reload()` first because this runs in a separate isolate).
  2. If not `inBedtime`, return.
  3. `queryEvents(now - 5 min, now)` → `buildSessions(windowEndMs: now, onlyPackages: tracked)`.
  4. `current` = the last session if `endMs == now` (still open), else null.
  5. If `decider.shouldNudge(...)`, call `showNudge`.

  The ongoing service notification text is "DoomTrack bedtime watcher". `startWatcher()` runs after onboarding and on each app start.

  This deviates from spec §4 ("starts at bedtime start, stops at bedtime end"). The service runs all the time and ticks do nothing outside bedtime. Add the comment `// shortcut: always-on service avoids an alarm scheduler; add android_alarm_manager_plus to start/stop at bedtime edges if the persistent notification bothers testers.`
- [ ] **Step 6 — GATE:**
  - Turn demo mode on and open Instagram. A nudge arrives within about 45 s, and no second one comes for the same session.
  - Leave Instagram and come back after more than 30 s: one new nudge.
  - Turn demo mode off with bedtime set to a window that excludes now: no nudge after 2 minutes.
  - While Instagram is open in demo mode, change the limit in Settings. The next tick uses the new value.
- [ ] **Step 7:** Commit `feat: bedtime watcher and nudge`.

---

## Stage 5 — Breathing + Activities

### Task 8: Breathing, Activities, notification deep link

**Files:** Create `lib/screens/breathing_screen.dart`, `lib/screens/activities_screen.dart`. Modify `lib/main.dart`.

**Interfaces:**
- Consumes: `initNotifications(onTap)`; payload `'/breathing'`
- Produces: routes `/breathing` and `/activities`; `GlobalKey<NavigatorState> navigatorKey` in `main.dart`

- [ ] **Step 1:** `BreathingScreen`: an `AnimationController` that grows a circle for 4 s, holds 4 s, shrinks for 6 s, with the label "Breathe in" / "Hold" / "Breathe out". It runs 60 s total (just over 4 cycles; stop at 60 s), shows a "Skip" button, and when done (or skipped) does `pushReplacementNamed('/activities')`.
- [ ] **Step 2:** `ActivitiesScreen`: a heading "Try one of these instead", the 5 fixed activities as cards with icons, and a "Done" button that closes the screen. Copy stays within the no-medical-claims rule.
- [ ] **Step 3:** `main.dart`: the tap callback runs `navigatorKey.currentState?.pushNamed(payload)`. On startup, if `getNotificationAppLaunchDetails()?.didNotificationLaunchApp == true`, push its payload after the first frame.
- [ ] **Step 4 — GATE:**
  - With DoomTrack in the background, tap a nudge: Breathing opens and finishes on Activities after 60 s.
  - Swipe DoomTrack away from recents, trigger a nudge in demo mode, and tap it: Breathing opens (the cold-start case).
  - Skip goes straight to Activities.
- [ ] **Step 5:** Commit `feat: breathing and activities`.

---

## Stage 6 — Hardening

### Task 9: Banners + device checklist

**Files:** Modify `lib/screens/home_screen.dart`. Create `docs/device-checklist.md`.

**Interfaces:**
- Consumes: the permission checks from Task 2; `SyncResult.possibleGap`

- [ ] **Step 1:** Home-screen banners, re-checked on resume:
  - Usage Access missing: "DoomTrack can't see app usage." with an [Open settings] button.
  - Notifications off: "Nudges are off because notifications are blocked."
  - Battery not exempt: "Nudges may be unreliable on this phone." with a [Fix] button that calls `requestIgnoreBatteryOptimization()`.
  - `possibleGap`: "Some older data is unavailable."
- [ ] **Step 2:** Copy spec §7's manual checklist into `docs/device-checklist.md` as a table with columns: check, brand 1 result, brand 2 result.
- [ ] **Step 3 — GATE:** Person B runs the full checklist on 2 brands. Every row is either a pass or has a written per-brand result. Fix failures, or document them when they're OEM limits. `flutter test` is green. **The core is now demo-ready.**
- [ ] **Step 4:** Commit `feat: hardening and device checklist`.

---

## Stage 7 — Intention check (stretch)

### Task 10: 5/15/30 notification actions

**Files:** Modify `lib/nudge/nudge_decider.dart`, `test/nudge/nudge_decider_test.dart`, `lib/nudge/notifications.dart`, `lib/nudge/bedtime_watcher.dart`.

**Interfaces:**
- Produces:
  - `bool shouldAskIntention({required Session? current, required bool inBedtime})`: true once per session, on the first tick a tracked session is seen
  - `Future<void> showIntention(String appName, int sessionStartMs)`: 3 `AndroidNotificationAction`s (ids `i5`, `i15`, `i30`, `showsUserInterface: false`)
  - The chosen minutes are stored in prefs as `intent_<package>_<startMs>`. The watcher uses `minutes * 60` in place of `effectiveLimitSec` when the key exists. In demo mode the choice still overrides: 5 means 5 real minutes.

- [ ] **Step 1:** Tests: `asks intention once per session`, and `override limit is used`: with an override of 300 s, 31 s → false and 301 s → true. Add an optional `int? overrideLimitSec` to `shouldNudge`.
- [ ] **Step 2:** Run, see them fail, implement, see them pass.
- [ ] **Step 3:** Handle the action in `onDidReceiveBackgroundNotificationResponse` (a top-level `@pragma('vm:entry-point')` function) by writing the prefs key.
- [ ] **Step 4 — GATE:** In demo mode, open Instagram, tap "5 min" on the intention notification. No nudge at 30 s; a nudge at about 5 min.
- [ ] **Step 5:** Commit `feat: intention check`.
