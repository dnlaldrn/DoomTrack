import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../permissions.dart';
import '../reports/report_math.dart';
import '../settings/settings.dart';
import '../tracking/usage_repository.dart';

String fmtDuration(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

class _Report {
  final List<int> week; // seconds per day, oldest first, today last
  final List<MapEntry<String, int>> top;
  final int afterBedtime;
  final PermissionState perms;
  final bool gap;
  const _Report(this.week, this.top, this.afterBedtime, this.perms, this.gap);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  _Report? _r;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final perms = await checkPermissions();
      final settings = await SettingsStore.load();
      final repo = await UsageRepository.open();
      // Without usage access, show what's already stored.
      final gap = perms.usage ? (await repo.sync(settings.tracked)).possibleGap : false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final first = DateTime(today.year, today.month, today.day - 6);
      final sessions = await repo.sessionsBetween(first.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      final todays = await repo.sessionsBetween(today.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      final (bedStart, bedEnd) = bedtimeWindowFor(DateTime(today.year, today.month, today.day - 1), settings.bedtime);
      final r = _Report(secondsPerDay(sessions, first, 7), topApps(todays), secondsInWindow(sessions, bedStart, bedEnd), perms, gap);
      if (mounted) setState(() => (_r = r, _error = null));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _banner(String text, {String? action, VoidCallback? onTap}) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(text),
          trailing: action == null ? null : TextButton(onPressed: onTap, child: Text(action)),
        ),
      );

  Widget _chart(List<int> week) {
    final now = DateTime.now();
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return SizedBox(
      height: 180,
      child: BarChart(BarChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) =>
                  Text(days[DateTime(now.year, now.month, now.day - 6 + v.toInt()).weekday - 1]),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < week.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: week[i] / 60, width: 16, color: Theme.of(context).colorScheme.primary),
            ]),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DoomTrack'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).pushNamed('/settings');
              _refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) _banner('Could not load usage: $_error'),
            if (r == null && _error == null) const Center(child: CircularProgressIndicator()),
            if (r != null) ...[
              if (!r.perms.usage)
                _banner("DoomTrack can't see app usage.", action: 'Open settings', onTap: requestUsage),
              if (!r.perms.notifications)
                _banner('Nudges are off because notifications are blocked.', action: 'Allow', onTap: requestNotifications),
              if (!r.perms.battery)
                _banner('Nudges may be unreliable on this phone.', action: 'Fix', onTap: requestBattery),
              if (r.gap) _banner('Some older data is unavailable.'),
              Text('Today', style: text.titleMedium),
              Text(fmtDuration(r.week.last), style: text.displaySmall),
              const SizedBox(height: 8),
              Text('After bedtime last night: ${fmtDuration(r.afterBedtime)}'),
              const SizedBox(height: 16),
              Text('Top apps today', style: text.titleMedium),
              if (r.top.isEmpty) const Text('No social app use yet today.'),
              for (final e in r.top) ListTile(dense: true, title: Text(e.key), trailing: Text(fmtDuration(e.value))),
              const SizedBox(height: 16),
              Text('Last 7 days (minutes)', style: text.titleMedium),
              const SizedBox(height: 8),
              _chart(r.week),
            ],
          ],
        ),
      ),
    );
  }
}
