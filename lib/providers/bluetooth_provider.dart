import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';

/// Bluetooth connection service provider — always uses the real adapter.
final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService(adapter: RealBluetoothAdapter());
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of Bluetooth connection state changes.
final bluetoothStateProvider = StreamProvider<BluetoothConnectionState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.stateStream;
});

/// Whether Bluetooth is currently connected to a real OBD adapter.
final isBluetoothConnectedProvider = Provider<bool>((ref) {
  final state = ref.watch(bluetoothStateProvider);
  return state.value == BluetoothConnectionState.connected;
});

/// Discovered Bluetooth devices during scan.
class BluetoothDeviceListNotifier extends Notifier<List<BluetoothDeviceInfo>> {
  StreamSubscription? _sub;

  @override
  List<BluetoothDeviceInfo> build() {
    ref.onDispose(() => _sub?.cancel());
    return [];
  }

  Future<void> startScan() async {
    state = [];
    _sub?.cancel();
    final service = ref.read(bluetoothServiceProvider);
    _sub = service.scanDevices(filterObd: false).listen((device) {
      if (!state.any((d) => d.address == device.address)) {
        state = [...state, device];
      }
    });
  }

  void stopScan() {
    _sub?.cancel();
  }
}

final bluetoothDevicesProvider =
    NotifierProvider<BluetoothDeviceListNotifier, List<BluetoothDeviceInfo>>(
        BluetoothDeviceListNotifier.new);
