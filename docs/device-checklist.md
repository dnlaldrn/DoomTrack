# DoomTrack device checklist

Run with `flutter run` (debug build) on each phone. Do the stages in order; stop at the first failure
and report it. **Debug screen:** Settings → "Debug: raw events & sessions" (debug builds only).

Phone 1: ____________ (brand/model, Android version)  Phone 2: ____________

| # | Stage | Check | Phone 1 | Phone 2 |
|---|---|---|---|---|
| 0.1 | Plugin proof | `flutter run` builds and installs | | |
| 0.2 | Plugin proof | Grant usage access, open Instagram ~20 s, return, open Debug, tap refresh: `foreground com.instagram.android` then `background` ~20 s apart | | |
| 1.1 | Onboarding | Fresh install (uninstall first): all 3 rows turn green after granting; Continue unlocks after the first two | | |
| 1.2 | Onboarding | Revoke usage access in system Settings, come back: the home screen shows "DoomTrack can't see app usage." | | |
| 2.1 | Tracking | Use Instagram and YouTube a few minutes each. Debug "Sessions today" minutes match Digital Wellbeing within ~5% | | |
| 2.2 | Tracking | Close and reopen DoomTrack twice: the session list doesn't grow duplicates | | |
| 3.1 | Reports | Home "Today", top apps and today's bar match the Debug sessions | | |
| 4.1 | Nudge | Settings → Demo mode on. Open Instagram: a nudge arrives within ~45 s | | |
| 4.2 | Nudge | Stay in Instagram 2 more minutes: no second nudge | | |
| 4.3 | Nudge | Leave Instagram over 30 s, reopen: one new nudge | | |
| 4.4 | Nudge | Demo mode off, bedtime set to exclude now: no nudge after 2 min in Instagram | | |
| 4.5 | Nudge | Demo off, bedtime includes now, limit 5 min: nudge at ~5 min (checks the real limit, not just demo mode) | | |
| 4.6 | Nudge | Demo mode on, Instagram open: within 15 s of the nudge, turn demo mode off and set limit 60. Start a new Instagram session: no nudge at 30 s (the watcher picked up the change) | | |
| 4.7 | Nudge | Hop from Instagram to WhatsApp for ~5 s and back, in demo mode: still only one nudge for that session | | |
| 5.1 | Breathing | DoomTrack in background, tap the nudge: Breathing opens, ends on Activities after 60 s | | |
| 5.2 | Breathing | Swipe DoomTrack away from recents, trigger a nudge, tap it: Breathing opens | | |
| 5.3 | Breathing | Skip goes straight to Activities; Done closes Activities | | |
| 6.1 | Hardening | Block DoomTrack notifications: home shows the notifications banner | | |
| 6.2 | Hardening | Without the battery exemption: the "Nudges may be unreliable" banner shows; Fix opens the system prompt | | |
| 6.3 | Hardening | Screen off 30 min in demo mode, unlock, open Instagram: nudge still arrives | | |
| 6.4 | Hardening | Reboot the phone (don't open DoomTrack), open Instagram in demo mode: nudge arrives | | |
