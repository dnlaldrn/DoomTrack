import 'package:doomtrack/reports/report_math.dart';
import 'package:doomtrack/tracking/session.dart';
import 'package:flutter_test/flutter_test.dart';

Session sessAt(DateTime a, DateTime b, [String app = 'IG']) =>
    Session(app, app, a.millisecondsSinceEpoch, b.millisecondsSinceEpoch);
Session sessMs(int a, int b, [String app = 'IG']) => Session(app, app, a, b);

void main() {
  reviewFixes();
  test('session crossing midnight splits across days', () {
    // 23:50 → 00:20 on Nov 5/6
    expect(secondsPerDay([sessAt(DateTime(2026, 11, 5, 23, 50), DateTime(2026, 11, 6, 0, 20))], DateTime(2026, 11, 5), 2),
        [600, 1200]);
  });
  test('window overlap counts only inside', () {
    expect(secondsInWindow([sessMs(0, 100000)], 50000, 200000), 50);
  });
  test('post-bedtime with window crossing midnight', () {
    // bedtime 23:00–06:00; session 22:30–23:30 → 30 min after bedtime
    final s = [sessAt(DateTime(2026, 11, 5, 22, 30), DateTime(2026, 11, 5, 23, 30))];
    expect(secondsInWindow(s, DateTime(2026, 11, 5, 23).millisecondsSinceEpoch, DateTime(2026, 11, 6, 6).millisecondsSinceEpoch),
        1800);
  });
  test('topApps sums per app and sorts', () {
    final r = topApps([sessMs(0, 60000), sessMs(100000, 160000), sessMs(0, 100000, 'TT')]);
    expect(r.map((e) => (e.key, e.value)).toList(), [('IG', 120), ('TT', 100)]);
  });
  test('topApps respects limit', () {
    expect(topApps([sessMs(0, 1000, 'A'), sessMs(0, 2000, 'B')], limit: 1).single.key, 'B');
  });
}

void reviewFixes() {
  test('clipSessions trims to the window and drops outside ones', () {
    final r = clipSessions([sessMs(0, 100000), sessMs(200000, 300000), sessMs(500000, 600000)], 50000, 250000);
    expect(r.map((s) => (s.startMs, s.endMs)).toList(), [(50000, 100000), (200000, 250000)]);
  });
}
