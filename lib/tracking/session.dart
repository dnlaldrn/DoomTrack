class Session {
  final String package;
  final String appName;
  final int startMs;
  final int endMs;
  const Session(this.package, this.appName, this.startMs, this.endMs);

  int get durationSec => (endMs - startMs) ~/ 1000;

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.package == package &&
      other.appName == appName &&
      other.startMs == startMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(package, appName, startMs, endMs);

  @override
  String toString() => 'Session($package, $startMs–$endMs)';
}
