import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../services/bluetooth_service.dart';
import 'bluetooth_provider.dart';
import 'vehicle_provider.dart';

/// Collapsed UX state for Bluetooth connection — one enum for the UI layer.
enum BluetoothUxState {
  newSetup, // No saved adapter on vehicle → full scan flow
  knownDisconnected, // Has adapter, idle
  scanning,
  connecting,
  connected,
  sleepPhaseA, // Quick restart detection (0-5 min)
  sleepPhaseB, // Quiet period (5-35 min)
  sleepPhaseC, // Background polling (35+ min)
  error,
}

/// Collapses BT connection state + sleep phase + saved adapter into one UX enum.
final bluetoothUxStateProvider = Provider<BluetoothUxState>((ref) {
  final btState = ref.watch(bluetoothStateProvider);
  final btService = ref.watch(bluetoothServiceProvider);
  final adapter = ref.watch(savedAdapterProvider);

  final connectionState =
      btState.value ?? BluetoothConnectionState.disconnected;

  // Check sleep phases first (they occur while disconnected)
  if (btService.sleepPhase != SleepReconnectPhase.none) {
    return switch (btService.sleepPhase) {
      SleepReconnectPhase.phaseA => BluetoothUxState.sleepPhaseA,
      SleepReconnectPhase.phaseB => BluetoothUxState.sleepPhaseB,
      SleepReconnectPhase.phaseC => BluetoothUxState.sleepPhaseC,
      SleepReconnectPhase.none => BluetoothUxState.knownDisconnected, // unreachable
    };
  }

  return switch (connectionState) {
    BluetoothConnectionState.connected => BluetoothUxState.connected,
    BluetoothConnectionState.connecting => BluetoothUxState.connecting,
    BluetoothConnectionState.scanning => BluetoothUxState.scanning,
    BluetoothConnectionState.error => BluetoothUxState.error,
    BluetoothConnectionState.disconnected =>
      adapter != null ? BluetoothUxState.knownDisconnected : BluetoothUxState.newSetup,
  };
});

/// Convenience provider: the saved OBD adapter from the active vehicle.
final savedAdapterProvider = Provider<ObdAdapter?>((ref) {
  return ref.watch(activeVehicleProvider)?.obdAdapter;
});
