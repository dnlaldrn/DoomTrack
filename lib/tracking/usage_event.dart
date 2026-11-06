enum UsageEventKind { foreground, background, screenOff }

class UsageEvent {
  final String package;
  final int timeMs;
  final UsageEventKind kind;
  const UsageEvent(this.package, this.timeMs, this.kind);
}
