import 'session.dart';
import 'usage_event.dart';

/// Gaps shorter than this between two sessions of the same app are merged
/// (notification shade, quick reply) so the nudge timer doesn't reset.
const kMergeGapMs = 30 * 1000;

List<Session> buildSessions(
  List<UsageEvent> events, {
  required int windowEndMs,
  required Map<String, String> appNames,
  Set<String>? onlyPackages,
}) {
  final sorted = [...events]..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  final raw = <(String, int, int)>[];
  String? openPkg;
  var openStart = 0;

  void close(int at) {
    if (openPkg != null) raw.add((openPkg!, openStart, at));
    openPkg = null;
  }

  for (final e in sorted) {
    switch (e.kind) {
      case UsageEventKind.foreground:
        if (e.package == openPkg) break;
        close(e.timeMs);
        openPkg = e.package;
        openStart = e.timeMs;
      case UsageEventKind.background:
        if (e.package == openPkg) close(e.timeMs);
      case UsageEventKind.screenOff:
        close(e.timeMs);
    }
  }
  close(windowEndMs);

  // Merge before filtering, so an untracked app in between keeps sessions apart.
  final merged = <(String, int, int)>[];
  for (final s in raw) {
    final last = merged.isEmpty ? null : merged.last;
    if (last != null && last.$1 == s.$1 && s.$2 - last.$3 < kMergeGapMs) {
      merged[merged.length - 1] = (last.$1, last.$2, s.$3);
    } else {
      merged.add(s);
    }
  }

  return [
    for (final (pkg, start, end) in merged)
      if (onlyPackages == null || onlyPackages.contains(pkg)) Session(pkg, appNames[pkg] ?? pkg, start, end),
  ];
}
