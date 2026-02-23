import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/did_scan_result.dart';
import '../services/did_scanner_service.dart';
import 'bluetooth_provider.dart';
import 'live_data_provider.dart';

/// DID scanner service — uses BluetoothService directly, auto-manages
/// OBD polling state (stops before scan, restores after).
final didScannerServiceProvider = Provider<DidScannerService>((ref) {
  final bt = ref.watch(bluetoothServiceProvider);
  final obd = ref.watch(obdServiceProvider);
  final service = DidScannerService(bluetooth: bt, obdService: obd);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of scan progress updates.
final didScanProgressProvider = StreamProvider<DidScanProgress>((ref) {
  return ref.watch(didScannerServiceProvider).progressStream;
});
