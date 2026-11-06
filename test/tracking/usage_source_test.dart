import 'package:doomtrack/tracking/usage_event.dart';
import 'package:doomtrack/tracking/usage_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1 → foreground', () {
    final e = toUsageEvent('1', '1000', 'com.instagram.android')!;
    expect((e.package, e.timeMs, e.kind), ('com.instagram.android', 1000, UsageEventKind.foreground));
  });
  test('2 → background', () => expect(toUsageEvent('2', '5', 'p')!.kind, UsageEventKind.background));
  test('16 → screenOff with empty package', () {
    final e = toUsageEvent('16', '5', 'android')!;
    expect((e.kind, e.package), (UsageEventKind.screenOff, ''));
  });
  test('other types dropped', () => expect(toUsageEvent('23', '5', 'p'), isNull));
  test('bad timestamp dropped', () => expect(toUsageEvent('1', null, 'p'), isNull));
  test('missing package on foreground dropped', () => expect(toUsageEvent('1', '5', null), isNull));
}
