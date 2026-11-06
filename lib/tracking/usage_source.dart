import 'package:usage_stats/usage_stats.dart';

import 'usage_event.dart';

/// Maps Android UsageEvents codes: 1 = resumed/foreground, 2 = paused/background,
/// 16 = SCREEN_NON_INTERACTIVE. Everything else is dropped.
UsageEvent? toUsageEvent(String? type, String? timeStamp, String? package) {
  final t = int.tryParse(timeStamp ?? '');
  if (t == null) return null;
  return switch (type) {
    '1' when package != null => UsageEvent(package, t, UsageEventKind.foreground),
    '2' when package != null => UsageEvent(package, t, UsageEventKind.background),
    '16' => UsageEvent('', t, UsageEventKind.screenOff),
    _ => null,
  };
}

Future<List<UsageEvent>> queryEvents(int startMs, int endMs) async {
  final raw = await UsageStats.queryEvents(
    DateTime.fromMillisecondsSinceEpoch(startMs),
    DateTime.fromMillisecondsSinceEpoch(endMs),
  );
  return [for (final e in raw) ?toUsageEvent(e.eventType, e.timeStamp, e.packageName)];
}
