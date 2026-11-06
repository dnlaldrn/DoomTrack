import 'package:doomtrack/settings/settings.dart';
import 'package:doomtrack/tracking/tracked_apps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  reviewFixes();
  const b = Bedtime(23 * 60, 6 * 60);
  test('inside before midnight', () => expect(isInBedtime(DateTime(2026, 11, 6, 23, 30), b), isTrue));
  test('inside after midnight', () => expect(isInBedtime(DateTime(2026, 11, 7, 5, 59), b), isTrue));
  test('end is exclusive', () => expect(isInBedtime(DateTime(2026, 11, 7, 6, 0), b), isFalse));
  test('daytime outside', () => expect(isInBedtime(DateTime(2026, 11, 7, 14, 0), b), isFalse));
  test('equal start/end never in bedtime', () => expect(isInBedtime(DateTime(2026, 11, 7, 1, 0), const Bedtime(60, 60)), isFalse));
  test('same-day window 13:00–15:00', () => expect(isInBedtime(DateTime(2026, 11, 7, 14, 0), const Bedtime(780, 900)), isTrue));
  test('demo mode forces 30s and bedtime', () {
    final s = Settings(demoMode: true);
    expect(s.effectiveLimitSec, 30);
    expect(s.inBedtime(DateTime(2026, 11, 7, 12)), isTrue);
  });
  test('defaults', () {
    final s = Settings();
    expect(s.effectiveLimitSec, 600);
    expect(s.tracked, kDefaultTrackedApps.keys.toSet());
    expect(s.inBedtime(DateTime(2026, 11, 7, 12)), isFalse);
  });
  test('window crossing midnight ends next day', () {
    final (start, end) = bedtimeWindowFor(DateTime(2026, 11, 5), b);
    expect(DateTime.fromMillisecondsSinceEpoch(start), DateTime(2026, 11, 5, 23));
    expect(DateTime.fromMillisecondsSinceEpoch(end), DateTime(2026, 11, 6, 6));
  });
  test('same-day window ends same day', () {
    final (_, end) = bedtimeWindowFor(DateTime(2026, 11, 5), const Bedtime(780, 900));
    expect(DateTime.fromMillisecondsSinceEpoch(end), DateTime(2026, 11, 5, 15));
  });
  test('store round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.save(Settings(bedtime: const Bedtime(1320, 420), limitMin: 15, tracked: {'a'}, demoMode: true));
    final s = await SettingsStore.load();
    expect((s.bedtime.startMin, s.bedtime.endMin, s.limitMin, s.demoMode), (1320, 420, 15, true));
    expect(s.tracked, {'a'});
  });
}

void reviewFixes() {
  test('equal start/end gives an empty window', () {
    final (start, end) = bedtimeWindowFor(DateTime(2026, 11, 5), const Bedtime(1380, 1380));
    expect(end, start);
  });
}
