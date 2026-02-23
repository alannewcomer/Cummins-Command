import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart'
    as bt;
import 'package:myapp/config/constants.dart';
import 'package:myapp/services/diagnostic_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connection state for the Bluetooth OBD adapter.
enum BluetoothConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Represents a discovered Bluetooth device.
class BluetoothDeviceInfo {
  final String name;
  final String address;
  final int? rssi;

  const BluetoothDeviceInfo({
    required this.name,
    required this.address,
    this.rssi,
  });

  bool get isOBDLink =>
      name.toUpperCase().contains('OBDLINK') ||
      name.toUpperCase().contains('OBD');

  @override
  String toString() => 'BluetoothDeviceInfo($name, $address)';
}

/// Abstract interface for Bluetooth Classic communication.
///
/// Backed by flutter_bluetooth_classic_serial for real hardware.
abstract class BluetoothAdapter {
  /// Whether Bluetooth is available and enabled on this device.
  Future<bool> get isAvailable;

  /// Scan for paired/nearby Bluetooth Classic devices.
  /// Returns a stream that emits devices as they are discovered.
  Stream<BluetoothDeviceInfo> scan({Duration? timeout});

  /// Connect to a device by its MAC address.
  /// Returns true on success.
  Future<bool> connect(String address);

  /// Disconnect from the current device.
  Future<void> disconnect();

  /// Send raw bytes to the connected device.
  Future<void> sendBytes(Uint8List data);

  /// Stream of raw bytes received from the connected device.
  Stream<Uint8List> get inputStream;

  /// Whether currently connected.
  bool get isConnected;

  /// Dispose all resources.
  void dispose();
}

/// Real Bluetooth adapter backed by flutter_bluetooth_classic_serial.
class RealBluetoothAdapter implements BluetoothAdapter {
  final bt.FlutterBluetoothClassic _bt = bt.FlutterBluetoothClassic();
  bool _connected = false;
  final StreamController<Uint8List> _inputController =
      StreamController<Uint8List>.broadcast();
  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;

  RealBluetoothAdapter() {
    // Listen for connection state changes to detect disconnects
    _connectionSubscription = _bt.onConnectionChanged.listen((state) {
      _connected = state.isConnected;
    });

    // Pipe incoming data into our broadcast stream
    _dataSubscription = _bt.onDataReceived.listen((btData) {
      final bytes = Uint8List.fromList(btData.data);
      if (!_inputController.isClosed) {
        _inputController.add(bytes);
      }
    });
  }

  @override
  Future<bool> get isAvailable async {
    final supported = await _bt.isBluetoothSupported();
    if (!supported) return false;
    return await _bt.isBluetoothEnabled();
  }

  @override
  Stream<BluetoothDeviceInfo> scan({Duration? timeout}) {
    final controller = StreamController<BluetoothDeviceInfo>();
    final effectiveTimeout = timeout ?? const Duration(seconds: 15);
    final seen = <String>{};

    () async {
      try {
        // Phase 1: Yield paired devices instantly
        final paired = await _bt.getPairedDevices();
        for (final d in paired) {
          final addr = d.address;
          if (addr.isEmpty || seen.contains(addr)) continue;
          seen.add(addr);
          controller.add(BluetoothDeviceInfo(
            name: d.name.isEmpty ? 'Unknown' : d.name,
            address: addr,
          ));
        }

        // Phase 2: Run discovery for the timeout period
        await _bt.startDiscovery();

        // Poll discovered devices during the discovery window
        final deadline = DateTime.now().add(effectiveTimeout);
        while (DateTime.now().isBefore(deadline) && !controller.isClosed) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final discovered = await _bt.getDiscoveredDevices();
          for (final d in discovered) {
            final addr = d.address;
            if (addr.isEmpty || seen.contains(addr)) continue;
            seen.add(addr);
            controller.add(BluetoothDeviceInfo(
              name: d.name.isEmpty ? 'Unknown' : d.name,
              address: addr,
            ));
          }
        }

        await _bt.stopDiscovery();
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }();

    return controller.stream;
  }

  @override
  Future<bool> connect(String address) async {
    try {
      _connected = false;
      diag.info('RFCOMM', 'Calling _bt.connect($address)');

      // _bt.connect() returns immediately — it just spawns a coroutine.
      // The actual RFCOMM socket takes 2-10+ seconds to open.
      // The onConnectionChanged listener (in constructor) sets _connected
      // to true when the socket is really ready.
      await _bt.connect(address);
      diag.info('RFCOMM', 'connect() returned, waiting for socket...');

      // Poll _connected (set by onConnectionChanged stream in constructor)
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (_connected) {
          diag.info('RFCOMM', 'Socket ready after ${(i + 1) * 200}ms');
          return true;
        }
      }

      // 10 seconds without onConnectionChanged — give up
      diag.error('RFCOMM', 'Socket never opened after 10s');
      _connected = false;
      return false;
    } catch (e) {
      diag.error('RFCOMM', 'connect() threw', '$e');
      _connected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _bt.disconnect();
    } catch (_) {}
    _connected = false;
  }

  @override
  Future<void> sendBytes(Uint8List data) async {
    if (!_connected) throw StateError('Not connected');
    await _bt.sendData(data);
  }

  @override
  Stream<Uint8List> get inputStream => _inputController.stream;

  @override
  bool get isConnected => _connected;

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _bt.disconnect();
    _connected = false;
    _inputController.close();
  }
}

// ─── Main BluetoothService ───

/// Production Bluetooth service managing the OBD adapter connection lifecycle.
///
/// Features:
/// - Device scanning with filter for OBDLink MX+
/// - Auto-reconnect with exponential backoff
/// - Connection health monitoring (ping every 10s)
/// - Stream-based data flow
/// - Send-command-wait-for-response pattern with timeout
class BluetoothService {
  final BluetoothAdapter _adapter;

  BluetoothService({required BluetoothAdapter adapter}) : _adapter = adapter;

  // ─── State ───

  BluetoothConnectionState _state = BluetoothConnectionState.disconnected;
  String? _connectedAddress;
  String? _lastError;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;
  bool _autoReconnectEnabled = false;
  bool _disposed = false;
  bool _healthCheckPaused = false;
  bool _sleepDisconnect = false;
  /// Address preserved after sleep disconnect for periodic reconnect.
  String? _sleepAddress;
  Timer? _sleepReconnectTimer;
  int _sleepReconnectAttempts = 0;
  /// When the last sleep disconnect happened — used for loop detection.
  DateTime? _lastSleepDisconnect;

  final StreamController<BluetoothConnectionState> _stateController =
      StreamController<BluetoothConnectionState>.broadcast();
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();

  StreamSubscription<Uint8List>? _inputSubscription;

  // Response accumulation buffer
  final StringBuffer _responseBuffer = StringBuffer();
  Completer<String>? _pendingResponse;
  Timer? _responseTimeout;

  // ─── Public getters ───

  BluetoothConnectionState get state => _state;
  String? get connectedAddress => _connectedAddress;
  String? get lastError => _lastError;
  bool get isConnected => _state == BluetoothConnectionState.connected;
  int get reconnectAttempts => _reconnectAttempts;

  /// Stream of connection state changes.
  Stream<BluetoothConnectionState> get stateStream => _stateController.stream;

  /// Stream of raw data received from the adapter.
  Stream<String> get dataStream => _dataController.stream;

  // ─── Scanning ───

  /// Scan for Bluetooth devices, optionally filtering for OBDLink adapters.
  Stream<BluetoothDeviceInfo> scanDevices({bool filterObd = true}) async* {
    _setState(BluetoothConnectionState.scanning);

    try {
      await for (final device
          in _adapter.scan(timeout: AppConstants.btScanTimeout)) {
        if (_disposed) break;
        if (!filterObd || device.isOBDLink) {
          yield device;
        }
      }
    } catch (e) {
      _setError('Scan failed: $e');
    } finally {
      if (_state == BluetoothConnectionState.scanning) {
        _setState(BluetoothConnectionState.disconnected);
      }
    }
  }

  // ─── Connection ───

  /// Connect to an OBD adapter at the given Bluetooth MAC address.
  ///
  /// Returns true on success. On failure, sets the error state and
  /// optionally starts auto-reconnect if enabled.
  Future<bool> connect(String address) async {
    if (_disposed) return false;
    if (_state == BluetoothConnectionState.connected &&
        _connectedAddress == address) {
      return true; // Already connected
    }

    _setState(BluetoothConnectionState.connecting);
    _connectedAddress = address;
    _lastError = null;
    diag.info('BT-SVC', 'Connecting to $address...');

    try {
      // This now waits for the RFCOMM socket to actually open
      final success = await _adapter.connect(address);
      if (!success) {
        diag.error('BT-SVC', 'Adapter connect failed');
        _setError('Connection refused by device');
        _handleConnectionFailure();
        return false;
      }

      diag.info('BT-SVC', 'Adapter connected, setting up streams');

      // Connection succeeded — clear all sleep/reconnect state
      _sleepDisconnect = false;
      _sleepAddress = null;
      _sleepReconnectTimer?.cancel();
      _sleepReconnectAttempts = 0;

      // Start listening for incoming data
      _inputSubscription?.cancel();
      _inputSubscription = _adapter.inputStream.listen(
        _onDataReceived,
        onError: (Object error) {
          _setError('Data stream error: $error');
          _handleDisconnect();
        },
        onDone: () {
          if (!_disposed) _handleDisconnect();
        },
      );

      _reconnectAttempts = 0;
      _responseBuffer.clear();
      _pendingResponse = null;
      _setState(BluetoothConnectionState.connected);
      _startHealthCheck();

      // Save adapter address for auto-connect on app restart
      _saveAdapterAddress(address);

      diag.info('BT-SVC', 'Connection complete, ready for commands');
      return true;
    } catch (e) {
      diag.error('BT-SVC', 'Connection exception', '$e');
      _setError('Connection failed: $e');
      _handleConnectionFailure();
      return false;
    }
  }

  /// Disconnect from the current device (manual disconnect).
  ///
  /// Stops auto-reconnect and health monitoring.
  /// Clears the saved adapter address — user must re-select on next connect.
  Future<void> disconnect() async {
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    _sleepReconnectTimer?.cancel();
    _sleepAddress = null;
    _sleepReconnectAttempts = 0;
    _healthCheckTimer?.cancel();
    _inputSubscription?.cancel();
    _pendingResponse?.completeError(
      StateError('Disconnected while waiting for response'),
    );
    _pendingResponse = null;
    _responseTimeout?.cancel();

    try {
      await _adapter.disconnect();
    } catch (_) {
      // Ignore disconnect errors
    }

    _connectedAddress = null;
    _setState(BluetoothConnectionState.disconnected);

    // Clear saved address — manual disconnect means user wants to stop
    _clearSavedAdapterAddress();
  }

  /// Disconnect for engine-off sleep — sends AT LP to put the OBDLink MX+
  /// into low-power mode (~microamps), then disconnects Bluetooth.
  ///
  /// Suppresses auto-reconnect so the adapter stays asleep until the user
  /// explicitly reconnects (or a future background wake mechanism triggers).
  ///
  /// The OBDLink MX+ wakes from AT LP on CAN bus activity (engine start)
  /// or a new Bluetooth connection attempt.
  Future<void> disconnectForSleep() async {
    diag.info('BT-SVC', 'Sleep disconnect — sending AT LP before disconnect');
    _sleepDisconnect = true;
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();

    // Try to send AT LP to put adapter in low-power mode
    if (isConnected) {
      try {
        await sendCommand('AT LP', timeout: const Duration(seconds: 1));
      } on TimeoutException {
        // AT LP may not produce a response — that's OK
        diag.debug('BT-SVC', 'AT LP timeout (expected — adapter is sleeping)');
      } on StateError {
        // Command pending — skip AT LP, just disconnect
        diag.debug('BT-SVC', 'AT LP skipped (command pending)');
      } catch (e) {
        diag.debug('BT-SVC', 'AT LP failed (non-critical)', '$e');
      }
    }

    // Disconnect Bluetooth
    _healthCheckTimer?.cancel();
    _inputSubscription?.cancel();
    _pendingResponse?.completeError(
      StateError('Sleep disconnect'),
    );
    _pendingResponse = null;
    _responseTimeout?.cancel();

    try {
      await _adapter.disconnect();
    } catch (_) {}

    // Preserve address for sleep reconnect — don't null it out
    _sleepAddress = _connectedAddress;
    _connectedAddress = null;
    _setState(BluetoothConnectionState.disconnected);
    diag.info('BT-SVC', 'Sleep disconnect complete — adapter should enter BatterySaver');

    // Start slow periodic reconnect — when the engine starts again,
    // the OBDLink wakes from AT LP on CAN bus activity and accepts
    // Bluetooth connections. We try every 30s for up to 30 minutes.
    _startSleepReconnect();
  }

  // ─── Communication ───

  /// Send an AT/OBD command and wait for a complete response.
  ///
  /// The command string is sent with a carriage return appended.
  /// Waits for the ELM327 prompt character ('>') or times out
  /// after [AppConstants.obdTimeout].
  ///
  /// Throws [TimeoutException] if no response is received in time.
  /// Throws [StateError] if not connected or another command is pending.
  Future<String> sendCommand(String command, {Duration? timeout}) async {
    if (!isConnected) {
      throw StateError('Not connected to OBD adapter');
    }
    if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
      // Wait briefly for the previous response to complete, then fail
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
        throw StateError(
          'Previous command still pending. Only one command at a time.',
        );
      }
    }

    _responseBuffer.clear();
    _pendingResponse = Completer<String>();

    // Send command with CR terminator
    final bytes = Uint8List.fromList('$command\r'.codeUnits);
    try {
      await _adapter.sendBytes(bytes);
    } catch (e) {
      _pendingResponse?.completeError(e);
      _pendingResponse = null;
      rethrow;
    }

    // Set up timeout (use provided timeout or default)
    final effectiveTimeout = timeout ?? AppConstants.obdTimeout;
    _responseTimeout?.cancel();
    _responseTimeout = Timer(effectiveTimeout, () {
      if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
        _pendingResponse!.completeError(
          TimeoutException(
            'OBD command timed out: $command',
            effectiveTimeout,
          ),
        );
        _pendingResponse = null;
      }
    });

    try {
      final response = await _pendingResponse!.future;
      return response;
    } finally {
      _responseTimeout?.cancel();
      _pendingResponse = null;
    }
  }

  // ─── Auto-Reconnect ───

  /// Enable auto-reconnect with exponential backoff.
  ///
  /// When enabled, the service will automatically attempt to reconnect
  /// if the connection drops, up to [AppConstants.btMaxReconnectAttempts]
  /// times with exponential backoff starting at
  /// [AppConstants.btReconnectDelay].
  void startAutoReconnect() {
    _autoReconnectEnabled = true;
    _reconnectAttempts = 0;
  }

  /// Disable auto-reconnect.
  void stopAutoReconnect() {
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
  }

  /// Whether we're in sleep reconnect mode (adapter sleeping, periodic retry).
  bool get isSleepReconnecting =>
      _sleepDisconnect && _sleepAddress != null && _sleepReconnectAttempts > 0;

  /// Pause health checks (call when OBD polling is active to avoid conflicts).
  void pauseHealthCheck() {
    _healthCheckPaused = true;
  }

  /// Resume health checks (call when OBD polling stops).
  void resumeHealthCheck() {
    _healthCheckPaused = false;
  }

  // ─── Lifecycle ───

  /// Release all resources.
  ///
  /// After calling dispose, this service instance must not be used again.
  void dispose() {
    _disposed = true;
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    _sleepReconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    _inputSubscription?.cancel();
    _responseTimeout?.cancel();
    _pendingResponse?.completeError(
      StateError('BluetoothService disposed'),
    );
    _adapter.dispose();
    _stateController.close();
    _dataController.close();
  }

  // ─── Private ───

  void _setState(BluetoothConnectionState newState) {
    if (_disposed) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _setError(String message) {
    _lastError = message;
    _setState(BluetoothConnectionState.error);
  }

  void _onDataReceived(Uint8List data) {
    if (_disposed) return;

    final chunk = String.fromCharCodes(data);
    if (!_dataController.isClosed) {
      _dataController.add(chunk);
    }

    // Accumulate into response buffer
    _responseBuffer.write(chunk);
    final bufferStr = _responseBuffer.toString();

    // Check for prompt character '>' indicating response complete
    if (bufferStr.contains('>')) {
      final response = bufferStr
          .replaceAll('>', '')
          .replaceAll('\r', '\n')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .join('\n')
          .trim();

      if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
        _pendingResponse!.complete(response);
      }
      _responseBuffer.clear();
    }
  }

  void _handleDisconnect() {
    _healthCheckTimer?.cancel();
    _inputSubscription?.cancel();
    _setState(BluetoothConnectionState.disconnected);

    if (_autoReconnectEnabled) {
      _scheduleReconnect();
    }
  }

  void _handleConnectionFailure() {
    if (_autoReconnectEnabled) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_sleepDisconnect) return; // Don't reconnect after engine-off sleep
    if (_connectedAddress == null) return;
    if (_reconnectAttempts >= AppConstants.btMaxReconnectAttempts) {
      _setError(
        'Auto-reconnect exhausted after ${AppConstants.btMaxReconnectAttempts} attempts',
      );
      return;
    }

    _reconnectAttempts++;

    // Exponential backoff: base * multiplier^(attempt-1)
    final baseMs = AppConstants.btReconnectDelay.inMilliseconds;
    final delayMs = baseMs *
        _pow(AppConstants.btReconnectBackoffMultiplier, _reconnectAttempts - 1);
    final clampedDelay = Duration(
      milliseconds: delayMs.round().clamp(baseMs, 60000),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(clampedDelay, () async {
      if (_disposed || !_autoReconnectEnabled) return;
      if (_connectedAddress != null) {
        await connect(_connectedAddress!);
      }
    });
  }

  /// Start three-phase sleep reconnect after engine-off sleep disconnect.
  ///
  /// Phase A (0-5 min):  30s polling — quick restart detection (gas station)
  /// Phase B (5-35 min): QUIET — let MX+ BatterySaver fully power down BT radio
  /// Phase C (35+ min):  60s polling — MX+ BT is OFF, attempts instant-fail, harmless
  ///
  /// Loop detection: if the last sleep disconnect was < 5 min ago, we just
  /// reconnected during Phase A and immediately detected engine-off again.
  /// Skip to Phase B to stop waking the MX+.
  void _startSleepReconnect() {
    _sleepReconnectTimer?.cancel();
    _sleepReconnectAttempts = 0;

    if (_sleepAddress == null) return;

    final now = DateTime.now();
    final isLoop = _lastSleepDisconnect != null &&
        now.difference(_lastSleepDisconnect!) <
            AppConstants.sleepReconnectPhaseADuration;
    _lastSleepDisconnect = now;

    if (isLoop) {
      // Loop detected: we reconnected and immediately went back to off.
      // Skip Phase A, go directly to Phase B (quiet period).
      diag.info('BT-SVC', 'Sleep reconnect loop detected',
          'Last sleep disconnect was < ${AppConstants.sleepReconnectPhaseADuration.inMinutes}min ago — '
          'skipping to quiet period for MX+ BatterySaver');
      _startPhaseB();
    } else {
      _startPhaseA();
    }
  }

  /// Phase A: Quick restart detection — every 30s for 5 minutes.
  void _startPhaseA() {
    final maxAttempts = AppConstants.sleepReconnectPhaseADuration.inSeconds ~/
        AppConstants.sleepReconnectPhaseAInterval.inSeconds;

    diag.info('BT-SVC', 'Sleep reconnect Phase A',
        'every ${AppConstants.sleepReconnectPhaseAInterval.inSeconds}s, '
        'max $maxAttempts attempts (${AppConstants.sleepReconnectPhaseADuration.inMinutes}min)');

    _sleepReconnectTimer = Timer.periodic(
      AppConstants.sleepReconnectPhaseAInterval,
      (_) async {
        if (_disposed || _sleepAddress == null) {
          _sleepReconnectTimer?.cancel();
          return;
        }

        _sleepReconnectAttempts++;
        if (_sleepReconnectAttempts > maxAttempts) {
          _sleepReconnectTimer?.cancel();
          diag.info('BT-SVC', 'Phase A complete — entering Phase B quiet period',
              '${AppConstants.sleepReconnectPhaseBDuration.inMinutes}min quiet for MX+ BatterySaver');
          _startPhaseB();
          return;
        }

        diag.debug('BT-SVC', 'Phase A attempt '
            '$_sleepReconnectAttempts/$maxAttempts');

        final address = _sleepAddress!;
        final success = await connect(address);
        if (success) {
          diag.info('BT-SVC', 'Phase A reconnect succeeded',
              'attempt $_sleepReconnectAttempts — quick restart detected');
        }
      },
    );
  }

  /// Phase B: Quiet period — let MX+ BatterySaver fully power down.
  ///
  /// The MX+ BatterySaver takes ~30 min of no BT activity to fully sleep
  /// (BT radio OFF). We must not poke it during this window.
  /// After the quiet period, transition to Phase C.
  void _startPhaseB() {
    _sleepReconnectTimer?.cancel();
    _sleepReconnectTimer = Timer(
      AppConstants.sleepReconnectPhaseBDuration,
      () {
        if (_disposed || _sleepAddress == null) return;
        diag.info('BT-SVC', 'Phase B complete — entering Phase C background polling',
            'MX+ should be in deep sleep now, BT radio off');
        _startPhaseC();
      },
    );
  }

  /// Phase C: Background polling — every 60s, forever.
  ///
  /// At this point the MX+ BatterySaver has fully powered down the BT radio.
  /// Our connect attempts fail instantly (~50ms, device not found) with zero
  /// impact on truck battery. When the truck starts, CAN activity wakes the
  /// MX+, BT radio turns on, and our next attempt succeeds.
  void _startPhaseC() {
    _sleepReconnectTimer?.cancel();

    diag.info('BT-SVC', 'Phase C started',
        'every ${AppConstants.sleepReconnectPhaseCInterval.inSeconds}s, no cap');

    _sleepReconnectTimer = Timer.periodic(
      AppConstants.sleepReconnectPhaseCInterval,
      (_) async {
        if (_disposed || _sleepAddress == null) {
          _sleepReconnectTimer?.cancel();
          return;
        }

        _sleepReconnectAttempts++;
        diag.debug('BT-SVC', 'Phase C attempt $_sleepReconnectAttempts');

        final address = _sleepAddress!;
        final success = await connect(address);
        if (success) {
          diag.info('BT-SVC', 'Phase C reconnect succeeded',
              'attempt $_sleepReconnectAttempts — truck restarted');
        }
      },
    );
  }

  // ─── Auto-Connect ───

  /// Try to auto-connect to the last known adapter address.
  ///
  /// Checks (in order): in-memory sleep address, then SharedPreferences.
  /// Returns true if connection succeeded, false if no saved address or failed.
  ///
  /// Call this on:
  ///   - App init (covers app restart / fresh launch)
  ///   - App foreground resume (covers overnight: truck starts → MX+ wakes → user opens app)
  Future<bool> tryAutoConnect() async {
    if (_disposed || isConnected) return false;
    // Don't interfere if sleep reconnect timer is still running
    if (_sleepReconnectTimer?.isActive == true) return false;

    // Try in-memory sleep address first (set during this app session)
    final address = _sleepAddress ?? await _getSavedAdapterAddress();
    if (address == null) {
      diag.debug('BT-SVC', 'No saved adapter address for auto-connect');
      return false;
    }

    diag.info('BT-SVC', 'Auto-connecting to saved adapter', address);
    return connect(address);
  }

  /// Save the adapter address to SharedPreferences for auto-connect on restart.
  Future<void> _saveAdapterAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.savedAdapterAddressKey, address);
      diag.debug('BT-SVC', 'Saved adapter address', address);
    } catch (e) {
      diag.warn('BT-SVC', 'Failed to save adapter address', '$e');
    }
  }

  /// Clear the saved adapter address (manual disconnect).
  Future<void> _clearSavedAdapterAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.savedAdapterAddressKey);
      diag.debug('BT-SVC', 'Cleared saved adapter address');
    } catch (e) {
      diag.warn('BT-SVC', 'Failed to clear adapter address', '$e');
    }
  }

  /// Get the saved adapter address from SharedPreferences.
  Future<String?> _getSavedAdapterAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(AppConstants.savedAdapterAddressKey);
    } catch (e) {
      diag.warn('BT-SVC', 'Failed to read saved adapter address', '$e');
      return null;
    }
  }

  /// Start periodic health checks (ping every 10 seconds).
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async {
        if (_disposed || !isConnected || _healthCheckPaused) return;
        try {
          // Send a simple AT command as a heartbeat
          final response = await sendCommand('AT@1');
          if (response.isEmpty) {
            _handleDisconnect();
          }
        } on TimeoutException {
          _handleDisconnect();
        } on StateError {
          // Another command was pending; skip this health check
        }
      },
    );
  }

  /// Simple power function for doubles.
  static double _pow(double base, int exponent) {
    double result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
