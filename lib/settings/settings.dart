import 'package:shared_preferences/shared_preferences.dart';

import '../tracking/tracked_apps.dart';

/// Bedtime window in minutes since local midnight. May cross midnight.
class Bedtime {
  final int startMin;
  final int endMin;
  const Bedtime(this.startMin, this.endMin);
}

const kDefaultBedtime = Bedtime(23 * 60, 6 * 60);

bool isInBedtime(DateTime now, Bedtime b) {
  final m = now.hour * 60 + now.minute;
  if (b.startMin == b.endMin) return false;
  return b.startMin < b.endMin ? m >= b.startMin && m < b.endMin : m >= b.startMin || m < b.endMin;
}

/// Start/end ms of the bedtime window that starts on [day].
(int, int) bedtimeWindowFor(DateTime day, Bedtime b) {
  final start = DateTime(day.year, day.month, day.day, 0, b.startMin);
  final endDay = b.endMin <= b.startMin ? day.day + 1 : day.day;
  final end = DateTime(day.year, day.month, endDay, 0, b.endMin);
  return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
}

class Settings {
  Bedtime bedtime;
  int limitMin;
  Set<String> tracked;
  bool demoMode;

  Settings({this.bedtime = kDefaultBedtime, this.limitMin = 10, Set<String>? tracked, this.demoMode = false})
      : tracked = tracked ?? kDefaultTrackedApps.keys.toSet();

  int get effectiveLimitSec => demoMode ? 30 : limitMin * 60;
  bool inBedtime(DateTime now) => demoMode || isInBedtime(now, bedtime);
}

class SettingsStore {
  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // the watcher runs in another isolate; pick up changes made by the UI
    return Settings(
      bedtime: Bedtime(p.getInt('bedStart') ?? kDefaultBedtime.startMin, p.getInt('bedEnd') ?? kDefaultBedtime.endMin),
      limitMin: p.getInt('limitMin') ?? 10,
      tracked: p.getStringList('tracked')?.toSet(),
      demoMode: p.getBool('demoMode') ?? false,
    );
  }

  static Future<void> save(Settings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('bedStart', s.bedtime.startMin);
    await p.setInt('bedEnd', s.bedtime.endMin);
    await p.setInt('limitMin', s.limitMin);
    await p.setStringList('tracked', s.tracked.toList());
    await p.setBool('demoMode', s.demoMode);
  }
}
