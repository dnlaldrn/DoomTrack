import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();
const _nudgeId = 1;

const _details = NotificationDetails(
  android: AndroidNotificationDetails('nudges', 'Bedtime nudges',
      channelDescription: 'Reminders to take a breather during bedtime',
      importance: Importance.high,
      priority: Priority.high),
);

/// Safe to call from both the UI isolate and the watcher isolate.
Future<void> initNotifications(void Function(String? payload) onTap) async {
  await _plugin.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: (r) => onTap(r.payload),
  );
}

Future<void> showNudge(String appName, int minutes) => _plugin.show(
      id: _nudgeId,
      title: 'Time for a breather?',
      body: "You've been on $appName for $minutes min. Take a 1-minute breather?",
      notificationDetails: _details,
      payload: '/breathing',
    );

/// Payload of the notification that cold-started the app, if any.
Future<String?> launchPayload() async {
  final d = await _plugin.getNotificationAppLaunchDetails();
  return d?.didNotificationLaunchApp == true ? d!.notificationResponse?.payload : null;
}

AndroidFlutterLocalNotificationsPlugin? get androidNotifications =>
    _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
