import 'package:doomtrack/nudge/nudge_decider.dart';
import 'package:doomtrack/tracking/session.dart';
import 'package:flutter_test/flutter_test.dart';

const s0 = Session('com.instagram.android', 'Instagram', 0, 0);

bool ask(NudgeDecider d, Session? s, int nowSec, {bool bed = true}) =>
    d.shouldNudge(current: s, nowMs: nowSec * 1000, limitSec: 30, inBedtime: bed);

void main() {
  test('no nudge under limit', () => expect(ask(NudgeDecider(), s0, 20), isFalse));
  test('no nudge exactly at limit', () => expect(ask(NudgeDecider(), s0, 30), isFalse));
  test('nudge once when over limit', () {
    final d = NudgeDecider();
    expect(ask(d, s0, 31), isTrue);
    expect(ask(d, s0, 46), isFalse);
  });
  test('new session nudges again', () {
    final d = NudgeDecider();
    expect(ask(d, s0, 31), isTrue);
    expect(ask(d, const Session('com.instagram.android', 'Instagram', 100000, 0), 200), isTrue);
  });
  test('no nudge outside bedtime', () => expect(ask(NudgeDecider(), s0, 100, bed: false), isFalse));
  test('null current → false', () => expect(ask(NudgeDecider(), null, 100), isFalse));
}
