import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nudge/bedtime_watcher.dart';
import 'nudge/notifications.dart';
import 'screens/activities_screen.dart';
import 'screens/breathing_screen.dart';
import 'screens/debug_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications((payload) {
    if (payload != null) navigatorKey.currentState?.pushNamed(payload);
  });
  final onboarded = (await SharedPreferences.getInstance()).getBool('onboarded') ?? false;
  if (onboarded) await startWatcher();
  final coldStartRoute = await launchPayload(); // nudge tapped while the app was closed
  runApp(DoomTrackApp(initialRoute: onboarded ? '/home' : '/onboarding'));
  if (coldStartRoute != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => navigatorKey.currentState?.pushNamed(coldStartRoute));
  }
}

class DoomTrackApp extends StatelessWidget {
  final String initialRoute;
  const DoomTrackApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DoomTrack',
        navigatorKey: navigatorKey,
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
        initialRoute: initialRoute,
        routes: {
          '/onboarding': (_) => const OnboardingScreen(),
          '/home': (_) => const HomeScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/breathing': (_) => const BreathingScreen(),
          '/activities': (_) => const ActivitiesScreen(),
          '/debug': (_) => const DebugScreen(),
        },
      );
}
