import 'package:doomtrack/tracking/session.dart';
import 'package:doomtrack/tracking/session_builder.dart';
import 'package:doomtrack/tracking/usage_event.dart';
import 'package:flutter_test/flutter_test.dart';

const IG = 'com.instagram.android';
const TT = 'com.zhiliaoapp.musically';

// Helpers take seconds.
UsageEvent fg(String p, int s) => UsageEvent(p, s * 1000, UsageEventKind.foreground);
UsageEvent bg(String p, int s) => UsageEvent(p, s * 1000, UsageEventKind.background);
UsageEvent off(int s) => UsageEvent('', s * 1000, UsageEventKind.screenOff);
Session sess(String p, int start, int end) => Session(p, p, start * 1000, end * 1000);
List<Session> b(List<UsageEvent> e, {int end = 10000, Set<String>? only}) =>
    buildSessions(e, windowEndMs: end * 1000, appNames: const {}, onlyPackages: only);

void main() {
  test('normal pair', () => expect(b([fg(IG, 0), bg(IG, 60)]).single, sess(IG, 0, 60)));
  test('second app foreground closes first', () {
    expect(b([fg(IG, 0), fg(TT, 100), bg(TT, 160)]), [sess(IG, 0, 100), sess(TT, 100, 160)]);
  });
  test('screen off closes session', () => expect(b([fg(IG, 0), off(90)]).single, sess(IG, 0, 90)));
  test('open session closes at window end', () => expect(b([fg(IG, 0)], end: 300).single, sess(IG, 0, 300)));
  test('sorts unsorted events', () => expect(b([bg(IG, 60), fg(IG, 0)]).single, sess(IG, 0, 60)));
  test('merges same-app gap under 30s', () {
    expect(b([fg(IG, 0), bg(IG, 60), fg(IG, 80), bg(IG, 200)]).single, sess(IG, 0, 200));
  });
  test('keeps same-app gap of 30s or more split', () {
    expect(b([fg(IG, 0), bg(IG, 60), fg(IG, 90), bg(IG, 200)]).length, 2);
  });
  test('filters untracked packages', () {
    expect(b([fg('com.android.chrome', 0), bg('com.android.chrome', 60)], only: {IG}), isEmpty);
  });
  test('appName falls back to package', () => expect(b([fg('x.y', 0), bg('x.y', 5)]).single.appName, 'x.y'));
  test('durationSec', () => expect(sess(IG, 0, 61).durationSec, 61));
}
