import 'package:doomtrack/tracking/usage_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const min = 60 * 1000;
const day = 24 * 60 * min;

void main() {
  final now = 100 * day;
  test('first sync reads 7 days', () => expect(syncFrom(now: now, lastSync: null, overlapStart: null), now - 7 * day));
  test('10-minute overlap by default', () {
    expect(syncFrom(now: now, lastSync: now - 60 * min, overlapStart: null), now - 70 * min);
  });
  test('reaches back to the start of a stored session that overlaps the overlap window', () {
    // stored IG 21:00–21:20, lastSync 21:21 → overlap window starts 21:11, inside the session
    expect(syncFrom(now: now, lastSync: now - 30 * min, overlapStart: now - 60 * min), now - 60 * min);
  });
  test('never more than 7 days back', () {
    expect(syncFrom(now: now, lastSync: now - 30 * min, overlapStart: now - 9 * day), now - 7 * day);
  });
}
