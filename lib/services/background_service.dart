import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

const _notificationChannelId = 'cummins_command_obd';
const _notificationId = 888;

/// Initialize the Android foreground service.
///
/// This keeps the app process alive when backgrounded, so the main isolate's
/// Bluetooth reconnect timers continue to fire. Without this, Android kills
/// the process after a few minutes in the background and the Phase C
/// reconnect (60s polling) never runs.
///
/// The background isolate itself does minimal work — it just stays alive
/// and updates the notification. All BT/OBD logic runs in the main isolate.
///
/// autoStartOnBoot: true — after a phone reboot, the foreground service
/// restarts automatically. When the user opens the app, the main isolate
/// resumes and tryAutoConnect() fires, connecting to the MX+ if the truck
/// is running.
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false, // Started explicitly when we have an adapter to connect to
      autoStartOnBoot: false, // Disabled — boot start crashes before Flutter creates notif channel
      isForegroundMode: true,
      notificationChannelId: _notificationChannelId,
      initialNotificationTitle: 'Cummins Command',
      initialNotificationContent: 'Waiting for adapter...',
      foregroundServiceNotificationId: _notificationId,
      foregroundServiceTypes: [AndroidForegroundType.connectedDevice],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onStart,
    ),
  );
}

/// Request Android battery optimization exemption.
///
/// When granted, Android will not kill our foreground service under normal
/// memory pressure. This is the single most impactful change for "never
/// miss a trip" reliability — without it, Android may kill the service
/// after 30+ minutes in background, breaking Phase C reconnect.
///
/// Returns true if already granted or user just granted it.
/// Returns false if user denied or the request failed.
Future<bool> requestBatteryOptimizationExemption() async {
  final status = await Permission.ignoreBatteryOptimizations.status;
  if (status.isGranted) return true;

  final result = await Permission.ignoreBatteryOptimizations.request();
  return result.isGranted;
}

/// Entry point for the background isolate.
///
/// Keeps alive via the message listener. Updates the foreground notification
/// when the main isolate sends status changes.
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Listen for notification updates from the main isolate
  if (service is AndroidServiceInstance) {
    service.on('updateNotification').listen((event) {
      if (event != null) {
        service.setForegroundNotificationInfo(
          title: event['title'] as String? ?? 'Cummins Command',
          content: event['content'] as String? ?? '',
        );
      }
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });
}

/// Helper to start the foreground service from the main isolate.
///
/// On Android 13+ (API 33), requests POST_NOTIFICATIONS permission first.
/// Without it, startForeground() throws CannotPostForegroundServiceNotificationException.
Future<void> startBackgroundService() async {
  // Android 13+ requires notification permission for foreground services
  final notifStatus = await Permission.notification.status;
  if (!notifStatus.isGranted) {
    final result = await Permission.notification.request();
    if (!result.isGranted) return; // Can't run foreground service without it
  }

  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
  }
}

/// Helper to stop the foreground service from the main isolate.
Future<void> stopBackgroundService() async {
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (running) {
    service.invoke('stopService');
  }
}

/// Update the foreground notification content from the main isolate.
void updateBackgroundNotification(String content) {
  final service = FlutterBackgroundService();
  service.invoke('updateNotification', {
    'title': 'Cummins Command',
    'content': content,
  });
}
