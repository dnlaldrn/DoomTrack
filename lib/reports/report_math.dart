import 'dart:math';

import '../tracking/session.dart';

/// Total seconds of [s] that fall inside [startMs, endMs).
int secondsInWindow(List<Session> s, int startMs, int endMs) {
  var ms = 0;
  for (final x in s) {
    ms += max(0, min(x.endMs, endMs) - max(x.startMs, startMs));
  }
  return ms ~/ 1000;
}

/// Seconds per local day; index 0 is [firstDay]. Sessions are split at midnight.
List<int> secondsPerDay(List<Session> s, DateTime firstDay, int days) => [
      for (var i = 0; i < days; i++)
        secondsInWindow(
          s,
          DateTime(firstDay.year, firstDay.month, firstDay.day + i).millisecondsSinceEpoch,
          DateTime(firstDay.year, firstDay.month, firstDay.day + i + 1).millisecondsSinceEpoch,
        ),
    ];

/// Sessions trimmed to [startMs, endMs); ones fully outside are dropped.
List<Session> clipSessions(List<Session> s, int startMs, int endMs) => [
      for (final x in s)
        if (x.endMs > startMs && x.startMs < endMs)
          Session(x.package, x.appName, max(x.startMs, startMs), min(x.endMs, endMs)),
    ];

/// appName → seconds, most used first.
List<MapEntry<String, int>> topApps(List<Session> s, {int limit = 3}) {
  final totals = <String, int>{};
  for (final x in s) {
    totals[x.appName] = (totals[x.appName] ?? 0) + x.durationSec;
  }
  return (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(limit).toList();
}
