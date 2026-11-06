import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:usage_stats/usage_stats.dart';

import '../settings/settings.dart';
import '../tracking/tracked_apps.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings? _s;
  Set<String> _installed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SettingsStore.load();
    final installed = <String>{
      for (final p in kDefaultTrackedApps.keys)
        if (await UsageStats.getAppInfo(p) != null) p,
    };
    if (mounted) setState(() => (_s = s, _installed = installed));
  }

  void _update(void Function(Settings s) change) {
    setState(() => change(_s!));
    SettingsStore.save(_s!);
  }

  String _fmt(int min) => TimeOfDay(hour: min ~/ 60, minute: min % 60).format(context);

  Future<void> _pickTime(bool start) async {
    final b = _s!.bedtime;
    final cur = start ? b.startMin : b.endMin;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null) return;
    final m = t.hour * 60 + t.minute;
    _update((s) => s.bedtime = start ? Bedtime(m, b.endMin) : Bedtime(b.startMin, m));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const ListTile(title: Text('Bedtime', style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(title: const Text('Starts'), trailing: Text(_fmt(s.bedtime.startMin)), onTap: () => _pickTime(true)),
                ListTile(title: const Text('Ends'), trailing: Text(_fmt(s.bedtime.endMin)), onTap: () => _pickTime(false)),
                ListTile(
                  title: Text('Nudge after ${s.limitMin} min in one app'),
                  subtitle: Slider(
                    value: s.limitMin.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '${s.limitMin} min',
                    onChanged: (v) => _update((s) => s.limitMin = v.round()),
                  ),
                ),
                const Divider(),
                const ListTile(title: Text('Tracked apps', style: TextStyle(fontWeight: FontWeight.bold))),
                if (_installed.isEmpty) const ListTile(subtitle: Text('None of the supported social apps are installed.')),
                for (final p in kDefaultTrackedApps.keys.where(_installed.contains))
                  SwitchListTile(
                    title: Text(kDefaultTrackedApps[p]!),
                    value: s.tracked.contains(p),
                    onChanged: (on) => _update((s) => on ? s.tracked.add(p) : s.tracked.remove(p)),
                  ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Demo mode'),
                  subtitle: const Text('30-second limit, always counts as bedtime'),
                  value: s.demoMode,
                  onChanged: (on) => _update((s) => s.demoMode = on),
                ),
                if (kDebugMode)
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text('Debug: raw events & sessions'),
                    onTap: () => Navigator.of(context).pushNamed('/debug'),
                  ),
              ],
            ),
    );
  }
}
