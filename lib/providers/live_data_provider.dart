import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../services/background_service.dart';
import '../services/bluetooth_service.dart';
import '../services/diagnostic_service.dart';
import '../services/drive_recorder.dart';
import '../services/obd_service.dart';
import 'auth_provider.dart';
import 'bluetooth_provider.dart';
import 'drives_provider.dart';
import 'location_provider.dart';
import 'vehicle_provider.dart';

export '../services/obd_service.dart' show PidStatus, EngineState;

/// Live OBD data stream — the core real-time data provider.
final obdServiceProvider = Provider<ObdService>((ref) {
  final btService = ref.watch(bluetoothServiceProvider);
  final service = ObdService(bluetooth: btService);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of live data from OBD polling.
final liveDataStreamProvider = StreamProvider<Map<String, double>>((ref) {
  final obdService = ref.watch(obdServiceProvider);
  return obdService.dataStream;
});

/// Current snapshot of live data values.
final liveDataProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(liveDataStreamProvider).when(
    data: (data) => data,
    loading: () => <String, double>{},
    error: (_, __) => <String, double>{},
  );
});

/// Sparkline history for each parameter (last 10 minutes).
class SparklineDataNotifier extends Notifier<Map<String, List<double>>> {
  static const _maxPoints = 600;

  @override
  Map<String, List<double>> build() => {};

  void addDataPoint(Map<String, double> data) {
    final updated = Map<String, List<double>>.from(state);
    for (final entry in data.entries) {
      final list = List<double>.from(updated[entry.key] ?? []);
      list.add(entry.value);
      if (list.length > _maxPoints) {
        list.removeAt(0);
      }
      updated[entry.key] = list;
    }
    state = updated;
  }

  void clear() => state = {};
}

final sparklineDataProvider =
    NotifierProvider<SparklineDataNotifier, Map<String, List<double>>>(
        SparklineDataNotifier.new);

/// Whether OBD polling is currently active.
class PollingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void setPolling(bool value) => state = value;
}

final isPollingProvider =
    NotifierProvider<PollingNotifier, bool>(PollingNotifier.new);

/// Drive session recorder — manages batched Firestore writes of OBD data.
final driveRecorderProvider = Provider<DriveRecorder>((ref) {
  final obdService = ref.watch(obdServiceProvider);
  final locationService = ref.watch(locationServiceProvider);
  final recorder = DriveRecorder(
    obdService: obdService,
    locationService: locationService,
  );
  ref.onDispose(() => recorder.dispose());
  return recorder;
});

/// Stream of engine state changes for UI consumption.
final engineStateStreamProvider = StreamProvider<EngineState>((ref) {
  final obdService = ref.watch(obdServiceProvider);
  return obdService.engineStateStream;
});

/// Current engine state snapshot.
final engineStateProvider = Provider<EngineState>((ref) {
  return ref.watch(engineStateStreamProvider).when(
    data: (state) => state,
    loading: () => EngineState.unknown,
    error: (_, __) => EngineState.unknown,
  );
});

/// Watches Bluetooth state for disconnect cleanup and auto-reconnect.
/// Also watches engine state for ignition-aware battery drain prevention.
///
/// Initial connection is handled by BluetoothSetupScreen.
/// This provider handles:
/// - Auto-connecting to last known adapter on init (app restart)
/// - Stopping polling + recording on disconnect
/// - Re-initializing OBD + restarting polling/recording on auto-reconnect
/// - Stopping recording when engine enters accessory mode
/// - Disconnecting Bluetooth when engine is off (letting adapter sleep)
/// Watch this from CommandCenterScreen.
final obdLifecycleProvider = Provider<void>((ref) {
  final btService = ref.watch(bluetoothServiceProvider);
  final obdService = ref.read(obdServiceProvider);
  final recorder = ref.read(driveRecorderProvider);

  // Auto-connect to last known adapter on init (covers app restart).
  // Fire-and-forget — if no saved address or connect fails, no harm done.
  if (!btService.isConnected) {
    btService.tryAutoConnect().then((success) {
      if (success) {
        diag.info('LIFE', 'Auto-connected to saved adapter on init');
      }
    });
  }

  // Auto-connect when app comes to foreground (covers overnight scenario:
  // truck starts → MX+ wakes on CAN → user opens/switches to app → connects).
  final lifecycleListener = AppLifecycleListener(
    onStateChange: (state) {
      if (state == AppLifecycleState.resumed && !btService.isConnected) {
        diag.info('LIFE', 'App resumed — trying auto-connect');
        btService.tryAutoConnect().then((success) {
          if (success) {
            diag.info('LIFE', 'Auto-connected to saved adapter on resume');
          }
        });
      }
    },
  );

  // Watch Bluetooth connection state
  final btSub = btService.stateStream.listen((state) async {
    if (state == BluetoothConnectionState.connected) {
      // Start foreground service on first connect (keeps process alive for
      // background reconnect when the app is minimized)
      startBackgroundService();
      updateBackgroundNotification('Connected — monitoring');

      // Skip if OBD is already initializing or polling (initial connect
      // is handled by BluetoothSetupScreen — this is for reconnects only)
      if (obdService.isPolling || obdService.initState == ObdInitState.initializing) {
        return;
      }
      // This is a reconnect — re-init and restart
      diag.info('LIFE', 'Reconnect detected, re-initializing OBD');
      final ok = await obdService.initialize();
      if (ok) {
        obdService.startPolling();
        _autoStartRecording(ref, recorder);
      }
    } else if (state == BluetoothConnectionState.disconnected) {
      updateBackgroundNotification('Waiting for adapter...');
      obdService.stopPolling();
      if (recorder.isRecording) {
        await recorder.stopRecording();
        ref.read(isRecordingProvider.notifier).setRecording(false);
        ref.read(activeDriveIdProvider.notifier).setDriveId(null);
      }
    }
  });

  // Watch engine state for ignition-aware behavior
  final engineSub = obdService.engineStateStream.listen((engineState) async {
    switch (engineState) {
      case EngineState.accessory:
        // Engine off but key on — stop recording immediately
        // (much faster than waiting for the 5-minute idle timeout)
        if (recorder.isRecording) {
          diag.info('LIFE', 'Engine accessory — stopping drive recording');
          await recorder.stopRecording();
          ref.read(isRecordingProvider.notifier).setRecording(false);
          ref.read(activeDriveIdProvider.notifier).setDriveId(null);
        }
        break;

      case EngineState.off:
        // Engine fully off — disconnect BT and let adapter sleep
        diag.info('LIFE', 'Engine off — disconnecting for adapter sleep');
        obdService.stopPolling();
        if (recorder.isRecording) {
          await recorder.stopRecording();
          ref.read(isRecordingProvider.notifier).setRecording(false);
          ref.read(activeDriveIdProvider.notifier).setDriveId(null);
        }
        await btService.disconnectForSleep();
        break;

      case EngineState.running:
        updateBackgroundNotification('Connected — engine running');
        // Engine confirmed running — auto-start recording if not already
        _autoStartRecording(ref, recorder);
        break;
      case EngineState.unknown:
        // No action needed — normal polling continues
        break;
    }
  });

  ref.onDispose(() {
    btSub.cancel();
    engineSub.cancel();
    lifecycleListener.dispose();
  });
});

/// Auto-start recording when OBD is connected, engine is running, and we have user context.
///
/// RPM gate: only start recording when RPM confirms engine is actually running.
/// This prevents recording bogus data during key-on-engine-off states.
Future<void> _autoStartRecording(Ref ref, DriveRecorder recorder) async {
  if (recorder.isRecording) return;

  // RPM gate — don't start recording unless engine is confirmed running
  final obdService = ref.read(obdServiceProvider);
  final rpm = obdService.liveData['rpm'] ?? obdService.liveData['engineSpeed'];
  if (rpm == null || rpm < AppConstants.engineOffRpmThreshold) return;

  final uid = ref.read(authStateProvider).value?.uid;
  final vehicle = ref.read(activeVehicleProvider);
  if (uid == null || vehicle == null) return;

  // Finalize any orphaned drives from previous sessions before starting new one
  await recorder.finalizeOrphanedDrives(uid, vehicle.id);

  final driveId = await recorder.startRecording(vehicle.id, userId: uid);
  if (driveId != null) {
    ref.read(isRecordingProvider.notifier).setRecording(true);
    ref.read(activeDriveIdProvider.notifier).setDriveId(driveId);
  }
}

/// Stream of per-PID polling status for the PID STATUS debug tab.
final pidStatusProvider = StreamProvider<Map<String, PidStatus>>((ref) {
  final obd = ref.watch(obdServiceProvider);
  return obd.pidStatusStream;
});

/// Feeds live data into sparkline history. Must be listened to (watched)
/// by a widget that's always mounted while connected (e.g. CommandCenterScreen).
final sparklineFeederProvider = Provider<void>((ref) {
  final dataAsync = ref.watch(liveDataStreamProvider);
  dataAsync.whenData((data) {
    ref.read(sparklineDataProvider.notifier).addDataPoint(data);
  });
});
