import '../tracking/session.dart';

/// Decides when to nudge: once per session, after the limit, during bedtime.
class NudgeDecider {
  String? _nudgedKey;

  bool shouldNudge({required Session? current, required int nowMs, required int limitSec, required bool inBedtime}) {
    if (current == null || !inBedtime) return false;
    final key = '${current.package}@${current.startMs}';
    if (key == _nudgedKey || nowMs - current.startMs <= limitSec * 1000) return false;
    _nudgedKey = key;
    return true;
  }
}
