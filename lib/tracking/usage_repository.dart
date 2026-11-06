import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'session.dart';
import 'session_builder.dart';
import 'tracked_apps.dart';
import 'usage_source.dart';

const kSyncOverlapMs = 10 * 60 * 1000;
const _maxBackMs = 7 * 24 * 3600 * 1000;

/// Where the next import starts. Re-reads the last 10 minutes, extended back to the start of any
/// stored session reaching into that overlap, so a rebuilt session keeps its start_ms and replaces
/// its row instead of being inserted again. [overlapStart] = MIN(start_ms) of those sessions.
int syncFrom({required int now, required int? lastSync, required int? overlapStart}) {
  if (lastSync == null) return now - _maxBackMs;
  return max(min(overlapStart ?? lastSync, lastSync - kSyncOverlapMs), now - _maxBackMs);
}

class SyncResult {
  final int imported;
  final bool possibleGap;
  const SyncResult(this.imported, this.possibleGap);
}

class UsageRepository {
  final Database _db;
  UsageRepository._(this._db);

  static Future<UsageRepository> open() async {
    final db = await openDatabase('doomtrack.db', version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE sessions(id INTEGER PRIMARY KEY, package TEXT, app_name TEXT, '
          'start_ms INTEGER, end_ms INTEGER, duration_sec INTEGER)');
      await db.execute('CREATE UNIQUE INDEX ux_sessions ON sessions(package, start_ms)');
    });
    return UsageRepository._(db);
  }

  /// Imports usage events since the last sync (max 7 days back) into the sessions table.
  Future<SyncResult> sync(Set<String> tracked) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt('lastSync');
    final overlapStart = last == null
        ? null
        : Sqflite.firstIntValue(
            await _db.rawQuery('SELECT MIN(start_ms) FROM sessions WHERE end_ms > ?', [last - kSyncOverlapMs]));
    final from = syncFrom(now: now, lastSync: last, overlapStart: overlapStart);
    final sessions = buildSessions(await queryEvents(from, now),
        windowEndMs: now, appNames: kDefaultTrackedApps, onlyPackages: tracked);

    final batch = _db.batch();
    for (final s in sessions) {
      batch.insert(
        'sessions',
        {'package': s.package, 'app_name': s.appName, 'start_ms': s.startMs, 'end_ms': s.endMs, 'duration_sec': s.durationSec},
        conflictAlgorithm: ConflictAlgorithm.replace, // a re-read open session gets its longer end
      );
    }
    await batch.commit(noResult: true);
    await prefs.setInt('lastSync', now);
    // shortcut: Android's event retention varies by OEM; 3 days is a guess, replace with the earliest-event check if the message misfires.
    return SyncResult(sessions.length, last != null && now - last > 3 * 24 * 3600 * 1000);
  }

  /// Sessions overlapping [startMs, endMs).
  Future<List<Session>> sessionsBetween(int startMs, int endMs) async {
    final rows = await _db.query('sessions',
        where: 'end_ms > ? AND start_ms < ?', whereArgs: [startMs, endMs], orderBy: 'start_ms');
    return [
      for (final r in rows) Session(r['package'] as String, r['app_name'] as String, r['start_ms'] as int, r['end_ms'] as int),
    ];
  }
}
