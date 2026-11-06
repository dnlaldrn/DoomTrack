import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../settings/settings.dart';
import '../tracking/session_builder.dart';
import '../tracking/tracked_apps.dart';
import '../tracking/usage_source.dart';
import 'notifications.dart';
import 'nudge_decider.dart';

const kLookbackMs = 2 * 3600 * 1000;

@pragma('vm:entry-point')
void _startCallback() => FlutterForegroundTask.setTaskHandler(_BedtimeTaskHandler());

class _BedtimeTaskHandler extends TaskHandler {
  final _decider = NudgeDecider();
  var _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) => initNotifications((_) {});

  @override
  void onRepeatEvent(DateTime timestamp) async {
    if (_busy) return; // a slow query must not overlap the next tick
    _busy = true;
    try {
      final s = await SettingsStore.load(); // reloaded every tick so setting changes apply
      final now = DateTime.now();
      if (!s.inBedtime(now)) return;
      final nowMs = now.millisecondsSinceEpoch;
      // The session's start event must be inside the window, or it isn't seen at all.
      // shortcut: a session open for over 2h is missed; raise kLookbackMs if testers hit that.
      final sessions = buildSessions(await queryEvents(nowMs - kLookbackMs, nowMs),
          windowEndMs: nowMs, appNames: kDefaultTrackedApps, onlyPackages: s.tracked);
      final current = sessions.isNotEmpty && sessions.last.endMs == nowMs ? sessions.last : null;
      if (_decider.shouldNudge(current: current, nowMs: nowMs, limitSec: s.effectiveLimitSec, inBedtime: true)) {
        await showNudge(current!.appName, ((nowMs - current.startMs) / 60000).ceil());
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Starts the always-on watcher if it isn't running. Safe to call repeatedly.
// shortcut: always-on service avoids an alarm scheduler; add android_alarm_manager_plus to start/stop at bedtime edges if the persistent notification bothers testers.
Future<void> startWatcher() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'watcher',
      channelName: 'Bedtime watcher',
      channelDescription: 'Keeps DoomTrack able to nudge you at bedtime',
      channelImportance: NotificationChannelImportance.MIN,
      priority: NotificationPriority.MIN,
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(15000),
      autoRunOnBoot: true,
      allowWakeLock: true,
    ),
  );
  if (await FlutterForegroundTask.isRunningService) return;
  await FlutterForegroundTask.startService(
    serviceTypes: [ForegroundServiceTypes.specialUse],
    notificationTitle: 'DoomTrack bedtime watcher',
    notificationText: 'Watching for late-night scrolling',
    callback: _startCallback,
  );
}
