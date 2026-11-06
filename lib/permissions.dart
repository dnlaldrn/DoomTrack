import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';

import 'nudge/notifications.dart';

class PermissionState {
  final bool usage, notifications, battery;
  const PermissionState(this.usage, this.notifications, this.battery);
}

Future<PermissionState> checkPermissions() async => PermissionState(
      await UsageStats.checkUsagePermission() ?? false,
      await androidNotifications?.areNotificationsEnabled() ?? false,
      await FlutterForegroundTask.isIgnoringBatteryOptimizations,
    );

Future<void> requestUsage() => UsageStats.grantUsagePermission();
Future<void> requestNotifications() async => androidNotifications?.requestNotificationsPermission();
Future<void> requestBattery() async => FlutterForegroundTask.requestIgnoreBatteryOptimization();
