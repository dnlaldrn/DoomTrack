import 'package:flutter/material.dart';

import '../settings/settings.dart';
import '../tracking/usage_event.dart';
import '../tracking/usage_repository.dart';
import '../tracking/usage_source.dart';

/// Debug builds only: raw events (Stage 0 test) and today's stored sessions (Stage 2 test).
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  List<String> _lines = ['Loading…'];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  String _t(int ms) => DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String().substring(11, 19);

  Future<void> _refresh() async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final events = await queryEvents(nowMs - 3600 * 1000, nowMs);
    final repo = await UsageRepository.open();
    final r = await repo.sync((await SettingsStore.load()).tracked);
    final sessions = await repo.sessionsBetween(DateTime(now.year, now.month, now.day).millisecondsSinceEpoch, nowMs);
    setState(() => _lines = [
          '— Sessions today (sync imported ${r.imported}) —',
          for (final s in sessions) '${_t(s.startMs)}–${_t(s.endMs)}  ${s.appName}  ${s.durationSec}s',
          '— Raw events, last hour (${events.length}) —',
          for (final e in events.reversed)
            '${_t(e.timeMs)}  ${e.kind.name}  ${e.kind == UsageEventKind.screenOff ? '' : e.package}',
        ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Debug'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [for (final l in _lines) Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))],
        ),
      );
}
