import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

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
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false, // Started explicitly when we have an adapter to connect to
      autoStartOnBoot: false,
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
Future<void> startBackgroundService() async {
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
