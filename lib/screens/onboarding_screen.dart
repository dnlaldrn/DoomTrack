import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nudge/bedtime_watcher.dart';
import '../permissions.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  PermissionState _p = const PermissionState(false, false, false);

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

  // Permissions are granted in system Settings; re-check when the user comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final p = await checkPermissions();
    if (mounted) setState(() => _p = p);
  }

  Future<void> _continue() async {
    await (await SharedPreferences.getInstance()).setBool('onboarded', true);
    await startWatcher();
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  Widget _row(String title, String why, bool granted, Future<void> Function() grant) => Card(
        child: ListTile(
          leading: Icon(granted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: granted ? Colors.green : null, semanticLabel: granted ? 'Granted' : 'Not granted'),
          title: Text(title),
          subtitle: Text(why),
          trailing: granted ? null : FilledButton.tonal(onPressed: () async {
            await grant();
            await _refresh();
          }, child: const Text('Grant')),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Welcome to DoomTrack', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('DoomTrack keeps everything on this phone. It only stores which social apps you '
                  'used and for how long.'),
              const SizedBox(height: 20),
              _row('Usage access', 'To see how long you spend in social apps. Find DoomTrack in the list and turn it on.',
                  _p.usage, requestUsage),
              _row('Notifications', 'To send you a gentle nudge at bedtime.', _p.notifications, requestNotifications),
              _row('Battery (optional)', 'Stops your phone from closing DoomTrack in the background, so nudges arrive on time.',
                  _p.battery, requestBattery),
              const SizedBox(height: 20),
              FilledButton(
                // Only usage access is required: Android stops showing the notification prompt after
                // two denials, and the home screen already shows a banner when nudges are off.
                onPressed: _p.usage ? _continue : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
}
