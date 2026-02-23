import 'dart:async';

import 'package:myapp/config/constants.dart';
import 'package:myapp/config/pid_config.dart';
import 'package:myapp/services/bluetooth_service.dart';
import 'package:myapp/services/diagnostic_service.dart';
import 'package:myapp/services/obd2_parser.dart';

const _tag = 'OBD';
const _pidTag = 'PID'; // Distinct tag for per-PID success/failure logging

/// Engine/ignition state — drives polling behavior and battery drain prevention.
enum EngineState { unknown, running, accessory, off }

/// Protocol detected on the vehicle bus.
enum ObdProtocol { unknown, obd2 }

/// Initialization state of the OBD service.
enum ObdInitState { idle, initializing, ready, error }

/// Per-PID polling status — updated on every attempt (success or failure).
class PidStatus {
  final String id;
  final String name;
  final String command;
  final PidProtocol protocol;

  int successCount = 0;
  int failureCount = 0;
  double? lastValue;
  String? lastUnit;
  /// Last raw response from adapter, truncated to 80 chars.
  String? lastRawHex;
  DateTime? lastSuccess;
  /// Reason for last failure: 'no_response' | 'parse_fail' | 'negative_resp' | 'unsupported'
  String? failReason;

  PidStatus({
    required this.id,
    required this.name,
    required this.command,
    required this.protocol,
  });
}

/// OBD communication layer with single-threaded sequential polling.
///
/// Critical design: Only ONE command is ever in-flight at a time.
/// All polling tiers share a single sequential loop — no concurrent timers.
class ObdService {
  final BluetoothService _bluetooth;

  ObdService({required BluetoothService bluetooth}) : _bluetooth = bluetooth;

  // ─── State ───

  ObdInitState _initState = ObdInitState.idle;
  ObdProtocol _protocol = ObdProtocol.unknown;
  String? _lastError;
  bool _disposed = false;
  bool _polling = false;

  /// ATSP code for confirmed OBD2 protocol.
  String _obd2AtspCode = '7';

  final Map<String, double> _liveData = {};
  final Map<String, PidStatus> _pidStatus = {};

  final StreamController<Map<String, double>> _dataController =
      StreamController<Map<String, double>>.broadcast();

  final StreamController<Map<String, PidStatus>> _statusController =
      StreamController<Map<String, PidStatus>>.broadcast();

  final Map<String, int> _consecutiveFailures = {};
  static const _maxConsecutiveFailures = 10;
  static const _failureResetCycles = 30;

  // ─── Engine State ───

  EngineState _engineState = EngineState.unknown;
  DateTime? _rpmZeroSince;
  DateTime? _lowVoltageSince;
  double? _lastVoltageReading;

  /// Peak voltage observed while engine was running (alternator charging).
  /// Used for fast alternator-off detection: if peak was >13.5V and current
  /// drops below 13.0V, the alternator has stopped — engine is off.
  double _runningPeakVoltage = 0.0;

  /// When voltage first dropped below alternatorOffVoltage after alternator
  /// was charging. Used to confirm alternator-off for [alternatorOffConfirmSeconds].
  DateTime? _alternatorOffSince;

  /// Tracks when all accessory-mode commands started timing out.
  /// If both RPM and AT RV timeout for 30+ seconds, the ECU is
  /// unresponsive (key fully off) — transition to off.
  DateTime? _accessoryTimeoutSince;
  static const _accessoryTimeoutOffSeconds = 30;

  /// Whether we've refreshed the PID bitmap since engine started running.
  /// Reset when engine leaves running state. This ensures we re-query the
  /// bitmap once the ECU is fully awake (it may report more PIDs than at
  /// initial cold connect).
  bool _bitmapRefreshedSinceRunning = false;

  final StreamController<EngineState> _engineStateController =
      StreamController<EngineState>.broadcast();

  /// Set of OBD2 PID codes this ECU supports (from 0100/0120/0140 queries).
  /// Null means we don't know — try everything.
  Set<int>? _supportedPids;

  // ─── Public getters ───

  ObdInitState get initState => _initState;
  ObdProtocol get protocol => _protocol;
  String? get lastError => _lastError;
  bool get isReady => _initState == ObdInitState.ready;
  bool get isPolling => _polling;
  bool get isConnected => _bluetooth.isConnected;
  Map<String, double> get liveData => Map.unmodifiable(_liveData);
  Stream<Map<String, double>> get dataStream => _dataController.stream;
  Stream<Map<String, PidStatus>> get pidStatusStream => _statusController.stream;
  Map<String, PidStatus> get pidStatus => Map.unmodifiable(_pidStatus);
  EngineState get engineState => _engineState;
  Stream<EngineState> get engineStateStream => _engineStateController.stream;

  // ─── Initialization ───

  Future<bool> initialize() async {
    if (!_bluetooth.isConnected) {
      _lastError = 'Bluetooth not connected';
      _initState = ObdInitState.error;
      diag.error(_tag, 'Init failed: BT not connected');
      return false;
    }

    _initState = ObdInitState.initializing;
    _lastError = null;
    _consecutiveFailures.clear();
    _supportedPids = null;
    _bitmapRefreshedSinceRunning = false;
    _liveData.clear();
    _pidStatus.clear();
    diag.info(_tag, 'Starting OBD initialization');

    try {
      // Phase 1: Basic AT initialization
      // (NOT including ATSP/ATST — those are set during protocol detection)
      const initCmds = ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH1', 'ATAT1'];

      for (final cmd in initCmds) {
        if (cmd == 'ATZ') {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        final response = await _sendSafe(cmd);
        diag.debug(_tag, 'AT cmd: $cmd', 'response: $response');

        if (response == null) {
          _lastError = 'No response to AT command: $cmd';
          _initState = ObdInitState.error;
          diag.error(_tag, 'AT cmd timeout', cmd);
          return false;
        }

        if (cmd != 'ATZ' && !response.toUpperCase().contains('OK')) {
          _lastError = 'Unexpected response to $cmd: $response';
          _initState = ObdInitState.error;
          diag.error(_tag, 'AT cmd unexpected response', '$cmd → $response');
          return false;
        }

        if (cmd == 'ATZ') {
          await Future<void>.delayed(const Duration(milliseconds: 1000));
        }
      }

      diag.info(_tag, 'AT init complete, detecting protocol...');

      // Phase 2: Protocol detection with explicit protocol attempts
      _protocol = await _detectProtocol();
      diag.info(_tag, 'Protocol detected: ${_protocol.name}');

      _initState = ObdInitState.ready;
      diag.info(_tag, 'OBD ready (protocol: ${_protocol.name})');
      return true;
    } catch (e) {
      _lastError = 'Initialization failed: $e';
      _initState = ObdInitState.error;
      diag.error(_tag, 'Init exception', '$e');
      return false;
    }
  }

  // ─── Protocol Detection ───

  /// Tries explicit CAN protocols (fastest), then auto-detect.
  ///
  /// Uses the Supported PIDs query (0100) to both confirm the protocol
  /// and discover which PIDs the ECU supports.
  ///
  /// On the 2026 Ram 2500 6.7L Cummins, only OBD2 (ISO 15765-4)
  /// request-response works via the OBD-II port. The CAN gateway (SGW)
  /// blocks all J1939 traffic. Multiple ECUs respond to OBD2 queries —
  /// the engine ECU sends valid data while the TCM/body modules send
  /// 7F negative responses. This is normal and must not block detection.
  Future<ObdProtocol> _detectProtocol() async {
    bool obd2Confirmed = false;
    String? confirmedAtsp;

    // Try explicit protocols — CAN 29-bit 500k first (HD trucks including 2026 Ram).
    // ELM327 standard protocol numbers:
    //   6 = ISO 15765-4 CAN 11-bit 500k
    //   7 = ISO 15765-4 CAN 29-bit 500k  ← preferred for HD trucks
    //   8 = ISO 15765-4 CAN 11-bit 250k
    //   9 = ISO 15765-4 CAN 29-bit 250k
    const protocols = [
      ('7', 'ISO 15765-4 CAN 29-bit 500k'),
      ('6', 'ISO 15765-4 CAN 11-bit 500k'),
      ('9', 'ISO 15765-4 CAN 29-bit 250k'),
    ];

    for (final (code, name) in protocols) {
      diag.info(_tag, 'Trying $name (ATSP$code)');
      await _sendSafe('ATSP$code');
      await _sendSafe('ATSTFF');

      final response = await _sendSafe(
        '0100',
        timeout: const Duration(seconds: 12),
      );
      diag.debug(_tag, 'Probe 0100 on ATSP$code',
          'raw: ${_truncate(response)}');

      if (response != null) {
        // Try to parse the supported PIDs bitmap from the response.
        // The parser already handles multi-ECU responses — it scans
        // each line for '4100' and ignores 7F lines from other ECUs.
        final bytes = Obd2Parser.parseResponse(
          response, expectedPid: 0x00, mode: 0x01,
        );

        if (bytes != null && bytes.length >= 4) {
          diag.info(_tag, 'OBD2 confirmed on $name (supported PIDs bitmap OK)');
          _parseSupportedPidBitmap(response, 0x00);
          await _queryExtendedPidRanges();
          obd2Confirmed = true;
          confirmedAtsp = code;
          break;
        }

        // If bitmap parse failed but we got any response at all (even 7F),
        // the protocol is live — ECU may need engine running for 0100
        final upper = response.toUpperCase().replaceAll(' ', '');
        if (upper.contains('7F') || upper.contains('41')) {
          diag.warn(_tag, 'ECU responded on $name but 0100 bitmap unavailable',
              'Engine may need to be running. Proceeding with this protocol.');
          obd2Confirmed = true;
          confirmedAtsp = code;
          break;
        }
      }
    }

    // Auto-detect fallback
    if (!obd2Confirmed) {
      diag.info(_tag, 'Trying auto-detect (ATSP0)');
      await _sendSafe('ATSP0');
      await _sendSafe('ATSTFF');

      final autoResp = await _sendSafe(
        '0100',
        timeout: const Duration(seconds: 15),
      );
      diag.debug(_tag, 'Probe 0100 on ATSP0',
          'raw: ${_truncate(autoResp)}');

      if (autoResp != null) {
        final bytes = Obd2Parser.parseResponse(
          autoResp, expectedPid: 0x00, mode: 0x01,
        );

        if (bytes != null && bytes.length >= 4) {
          diag.info(_tag, 'Auto-detect confirmed OBD2 (bitmap OK)');
          _parseSupportedPidBitmap(autoResp, 0x00);
          await _queryExtendedPidRanges();
          obd2Confirmed = true;
          confirmedAtsp = '0';
        } else {
          final upper = autoResp.toUpperCase().replaceAll(' ', '');
          if (upper.contains('7F') || upper.contains('41')) {
            diag.warn(_tag, 'Auto-detect got ECU response, proceeding as OBD2');
            obd2Confirmed = true;
            confirmedAtsp = '0';
          }
        }
      }
    }

    // Set the adapter to the confirmed protocol
    ObdProtocol result;
    if (obd2Confirmed) {
      result = ObdProtocol.obd2;
      _obd2AtspCode = confirmedAtsp ?? '7';
      await _sendSafe('ATSP$_obd2AtspCode');
    } else {
      // Nothing confirmed — default to CAN 29-bit 500k and try everything
      diag.warn(_tag, 'No protocol confirmed, defaulting to CAN 29-bit 500k');
      await _sendSafe('ATSP7');
      _obd2AtspCode = '7';
      result = ObdProtocol.unknown;
    }

    await _sendSafe('ATST32'); // Normal timeout for polling

    final pidCounts = _supportedPids?.length ?? 0;
    diag.info(_tag, 'Protocol detection complete',
        'result=${result.name} obd2=$obd2Confirmed '
        'supportedPids=$pidCounts');

    return result;
  }

  /// Parse the 4-byte bitmap from a supported PIDs response (0100/0120/0140).
  void _parseSupportedPidBitmap(String response, int basePid) {
    final bytes = Obd2Parser.parseResponse(
      response,
      expectedPid: basePid,
      mode: 0x01,
    );
    if (bytes == null || bytes.length < 4) return;

    _supportedPids ??= {};
    for (int byteIdx = 0; byteIdx < 4 && byteIdx < bytes.length; byteIdx++) {
      for (int bit = 7; bit >= 0; bit--) {
        if ((bytes[byteIdx] >> bit) & 1 == 1) {
          final pid = basePid + byteIdx * 8 + (7 - bit) + 1;
          _supportedPids!.add(pid);
        }
      }
    }

    final pids = _supportedPids!
        .where((p) => p > basePid && p <= basePid + 0x20)
        .map((p) => '0x${p.toRadixString(16).padLeft(2, '0').toUpperCase()}')
        .toList()
      ..sort();
    diag.info(
      _tag,
      'Supported PIDs (${_hexPid(basePid + 1)}-${_hexPid(basePid + 0x20)})',
      pids.join(', '),
    );
  }

  /// Query extended PID ranges (0120 for PIDs 33-64, 0140 for PIDs 65-96).
  Future<void> _queryExtendedPidRanges() async {
    // PIDs 0x21-0x40
    if (_supportedPids != null && _supportedPids!.contains(0x20)) {
      final resp = await _sendSafe('0120');
      if (resp != null &&
          resp.toUpperCase().replaceAll(' ', '').contains('4120')) {
        _parseSupportedPidBitmap(resp, 0x20);
      }
    }

    // PIDs 0x41-0x60
    if (_supportedPids != null && _supportedPids!.contains(0x40)) {
      final resp = await _sendSafe('0140');
      if (resp != null &&
          resp.toUpperCase().replaceAll(' ', '').contains('4140')) {
        _parseSupportedPidBitmap(resp, 0x40);
      }
    }

    // PIDs 0x61-0x80 (covers 0x6B, 0x6D, 0x73)
    if (_supportedPids != null && _supportedPids!.contains(0x60)) {
      final resp = await _sendSafe('0160');
      if (resp != null &&
          resp.toUpperCase().replaceAll(' ', '').contains('4160')) {
        _parseSupportedPidBitmap(resp, 0x60);
      }
    }

    if (_supportedPids != null && _supportedPids!.isNotEmpty) {
      diag.info(_tag, 'Total supported OBD2 PIDs', '${_supportedPids!.length}');

      // Log PIDs we'll poll that the bitmap says aren't supported (advisory only)
      final notInBitmap = PidRegistry.getByProtocol(PidProtocol.obd2)
          .where((p) => !_supportedPids!.contains(p.code))
          .map((p) => '${p.id}(${_hexPid(p.code)})')
          .toList();
      if (notInBitmap.isNotEmpty) {
        diag.info(_tag, 'PIDs not in bitmap (will try anyway)',
            notInBitmap.join(', '));
      }
    }
  }

  // ─── PID Bitmap Self-Healing ───

  /// Re-query the PID bitmap without full re-init. Called mid-polling when
  /// the engine transitions to running, since the ECU may declare more PIDs
  /// once fully awake vs. during a cold/key-on-engine-off connect.
  ///
  /// This is the fix for the "only 9 PIDs" problem — if you connected with
  /// engine off, the initial bitmap may be incomplete. Once the engine starts,
  /// we re-query and pick up any newly available PIDs.
  Future<void> _refreshPidBitmap() async {
    final oldCount = _supportedPids?.length ?? 0;
    final oldPids = _supportedPids != null ? Set<int>.from(_supportedPids!) : <int>{};

    diag.info(_tag, 'Refreshing PID bitmap (engine running)',
        'previous supported PIDs: $oldCount');

    // Re-query 0100 for the base bitmap
    final resp0100 = await _sendSafe('0100', timeout: const Duration(seconds: 5));
    if (resp0100 != null) {
      final bytes = Obd2Parser.parseResponse(resp0100, expectedPid: 0x00, mode: 0x01);
      if (bytes != null && bytes.length >= 4) {
        _parseSupportedPidBitmap(resp0100, 0x00);
        await _queryExtendedPidRanges();
      }
    }

    final newCount = _supportedPids?.length ?? 0;
    final newPids = _supportedPids ?? <int>{};
    final gained = newPids.difference(oldPids);

    if (gained.isNotEmpty) {
      final gainedHex = gained
          .map((p) => '0x${p.toRadixString(16).padLeft(2, '0').toUpperCase()}')
          .toList()
        ..sort();
      diag.info(_tag, 'Bitmap refresh found ${gained.length} new PIDs',
          '$oldCount → $newCount: ${gainedHex.join(', ')}');

      // Clear failure counters for newly discovered PIDs so they get
      // polled immediately instead of waiting for the next reset cycle
      for (final pid in PidRegistry.getByProtocol(PidProtocol.obd2)) {
        if (gained.contains(pid.code)) {
          _consecutiveFailures.remove(pid.id);
        }
      }
    } else {
      diag.info(_tag, 'Bitmap refresh — no new PIDs', 'still $newCount');
    }

    _bitmapRefreshedSinceRunning = true;
  }

  // ─── Polling ───

  void startPolling() {
    if (!isReady || _polling) {
      diag.warn(_tag, 'startPolling skipped', 'ready=$isReady polling=$_polling');
      return;
    }
    _polling = true;

    // Log what will be polled
    final obd2Count = PidRegistry.getByTier(PollTier.fast).where((p) =>
        _isProtocolSupported(p.protocol)).length +
        PidRegistry.getByTier(PollTier.medium).where((p) =>
            _isProtocolSupported(p.protocol)).length +
        PidRegistry.getByTier(PollTier.slow).where((p) =>
            _isProtocolSupported(p.protocol)).length +
        PidRegistry.getByTier(PollTier.background).where((p) =>
            _isProtocolSupported(p.protocol)).length;
    final pidBitmapKnown = _supportedPids != null;
    diag.info(_tag, 'Polling started',
        'protocol=${_protocol.name} totalPIDs=$obd2Count '
        'pidBitmapKnown=$pidBitmapKnown '
        'supportedPids=${_supportedPids?.length ?? "unknown"}');

    // Pause BT health check to avoid AT@1 collisions
    _bluetooth.pauseHealthCheck();

    // Launch the single-threaded sequential poll loop
    _runPollLoop();
  }

  void stopPolling() {
    _polling = false;
    // Clear stale values so the dashboard shows blanks instead of frozen data.
    _liveData.clear();
    if (!_dataController.isClosed) {
      _dataController.add(const {});
    }
    // Reset engine state so next connection starts fresh
    _engineState = EngineState.unknown;
    _rpmZeroSince = null;
    _lowVoltageSince = null;
    _lastVoltageReading = null;
    _runningPeakVoltage = 0.0;
    _alternatorOffSince = null;
    _accessoryTimeoutSince = null;
    _bitmapRefreshedSinceRunning = false;
    diag.info(_tag, 'Polling stopped — live data cleared');
    _bluetooth.resumeHealthCheck();
  }

  /// Single-threaded sequential poll loop.
  ///
  /// Tiers are interleaved by tick count:
  /// - fast: every tick
  /// - medium: every 2nd tick
  /// - slow: every 4th tick
  /// - background: every 10th tick
  ///
  /// In accessory mode (engine off, key on), only RPM + voltage are polled
  /// at a slower interval to conserve battery while still detecting engine start.
  ///
  /// Each PID is polled one-at-a-time. No concurrent commands ever.
  Future<void> _runPollLoop() async {
    int tick = 0;

    while (_polling && !_disposed && _bluetooth.isConnected) {
      // In accessory mode, only poll RPM + voltage at a slower rate.
      // This keeps the connection alive for engine-start detection
      // while minimizing adapter activity (letting BatterySaver timer tick).
      if (_engineState == EngineState.accessory) {
        await _pollAccessoryMode();

        // Update engine state — may transition back to running or to off
        _updateEngineState();

        // If engine started again, resume full polling immediately
        if (_engineState == EngineState.running) {
          diag.info(_tag, 'Engine restarted — resuming full polling');
          continue;
        }

        // If transitioned to off, the provider will disconnect us
        if (_engineState == EngineState.off) {
          break;
        }

        // Slow poll interval in accessory mode
        if (_polling && !_disposed) {
          await Future<void>.delayed(const Duration(
            milliseconds: AppConstants.accessoryPollIntervalMs,
          ));
        }
        tick++;
        continue;
      }

      // ─── Normal (running) polling ───

      // Periodically reset failure counters so PIDs get retried
      // (e.g., engine was off when we connected, now it's running)
      if (tick > 0 && tick % _failureResetCycles == 0) {
        final disabledCount = _consecutiveFailures.entries
            .where((e) => e.value >= _maxConsecutiveFailures)
            .length;
        _consecutiveFailures.clear();
        diag.info(_tag, 'Failure counters reset (cycle $tick)',
            're-enabled $disabledCount PIDs for retry');
      }

      // Periodic polling summary every 50 ticks (~25 seconds)
      if (tick > 0 && tick % 50 == 0) {
        _logPollingSummary(tick);
      }

      // Build PID list for this tick based on tier rotation
      final pids = <PidDefinition>[];

      pids.addAll(_getActivePids(PollTier.fast));
      if (tick % 2 == 0) pids.addAll(_getActivePids(PollTier.medium));
      if (tick % 4 == 0) pids.addAll(_getActivePids(PollTier.slow));
      if (tick % 10 == 0) pids.addAll(_getActivePids(PollTier.background));

      // Poll each OBD2/Mode22 PID sequentially — one at a time
      for (final pid in pids) {
        if (!_polling || _disposed) return;
        await requestPid(pid);
      }

      // Emit aggregated snapshots after each cycle
      if (!_dataController.isClosed && _liveData.isNotEmpty) {
        _dataController.add(Map.unmodifiable(_liveData));
      }
      if (!_statusController.isClosed && _pidStatus.isNotEmpty) {
        _statusController.add(Map.unmodifiable(_pidStatus));
      }

      // Update engine state after each full poll cycle
      _updateEngineState();

      // Self-healing: re-query PID bitmap once after engine starts running.
      // The ECU may report more PIDs when fully awake than during a cold
      // connect (fixes the "only 9 PIDs" problem without manual reconnect).
      if (_engineState == EngineState.running &&
          !_bitmapRefreshedSinceRunning &&
          _supportedPids != null &&
          tick >= 5) {
        await _refreshPidBitmap();
      }

      tick++;

      // Brief pause between cycles
      if (_polling && !_disposed) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    // Cleanup when loop exits
    if (!_disposed) {
      _bluetooth.resumeHealthCheck();
    }
  }

  /// Reduced polling for accessory mode — voltage only (no CAN traffic).
  ///
  /// Uses AT RV (adapter pin 16 voltage) which reads the OBD port voltage
  /// directly from the adapter's hardware — no CAN bus traffic at all.
  /// This lets the truck's ECU and CAN modules sleep immediately while
  /// still detecting engine restart via voltage jump.
  ///
  /// When voltage jumps above alternatorChargingVoltage (13.5V), the
  /// alternator has started — confirm with a single RPM query on CAN.
  Future<void> _pollAccessoryMode() async {
    // Read voltage via AT RV (adapter pin 16 — zero CAN traffic)
    final voltageBefore = _lastVoltageReading;
    await _readAdapterVoltage();
    final voltageGotResponse = _lastVoltageReading != null &&
        _lastVoltageReading != voltageBefore;

    // Detect engine restart: voltage jump above alternator threshold
    // means the alternator is charging — engine has restarted.
    bool rpmGotResponse = false;
    if (_lastVoltageReading != null &&
        _lastVoltageReading! > AppConstants.alternatorChargingVoltage) {
      // Voltage says alternator is running — confirm with RPM on CAN
      final rpmPid = PidRegistry.get('rpm');
      if (rpmPid != null) {
        final successBefore = _pidStatus[rpmPid.id]?.successCount ?? 0;
        await requestPid(rpmPid);
        final successAfter = _pidStatus[rpmPid.id]?.successCount ?? 0;
        rpmGotResponse = successAfter > successBefore;
      }
    }

    // Track command timeout state — if AT RV times out consistently,
    // the adapter is unresponsive (fully off or BT link broken).
    if (!voltageGotResponse && !rpmGotResponse) {
      _accessoryTimeoutSince ??= DateTime.now();
    } else {
      _accessoryTimeoutSince = null;
    }

    // Emit data snapshot
    if (!_dataController.isClosed && _liveData.isNotEmpty) {
      _dataController.add(Map.unmodifiable(_liveData));
    }
  }

  /// Read the OBD port voltage via the ELM327 `AT RV` command.
  ///
  /// Returns the voltage from Pin 16 of the OBD port. This reflects:
  /// - ~14.0-14.5V when engine is running (alternator charging)
  /// - ~12.4-12.8V in accessory mode (battery only)
  /// - ~12.0-12.6V when fully off
  ///
  /// Used as a secondary engine-off signal alongside RPM.
  Future<void> _readAdapterVoltage() async {
    final response = await _sendSafe('AT RV');
    if (response == null) return;

    // Response format: "12.5V" or "12.5" (some adapters omit the V)
    final cleaned = response.replaceAll(RegExp(r'[^0-9.]'), '');
    final voltage = double.tryParse(cleaned);
    if (voltage != null && voltage > 0 && voltage < 20) {
      _lastVoltageReading = voltage;
      _liveData['batteryVoltage'] = voltage;
    }
  }

  /// Engine state machine — determines if the engine is running, in accessory
  /// mode, or fully off based on RPM and voltage readings.
  ///
  /// State transitions:
  /// - unknown/running → accessory: RPM < threshold for [engineOffConfirmSeconds]
  /// - accessory → running: RPM > threshold (immediate)
  /// - accessory → off: voltage < threshold for [accessoryToOffSeconds]
  /// - off: emitted once, then provider disconnects BT
  void _updateEngineState() {
    final rpm = _liveData['rpm'];
    final voltage = _lastVoltageReading ?? _liveData['batteryVoltage'];
    final now = DateTime.now();

    // RPM above threshold = engine is running
    if (rpm != null && rpm > AppConstants.engineOffRpmThreshold) {
      if (_engineState != EngineState.running) {
        _setEngineState(EngineState.running);
      }
      _rpmZeroSince = null;
      _lowVoltageSince = null;
      _alternatorOffSince = null;
      _accessoryTimeoutSince = null;

      // Track peak voltage while running — used for fast alternator-off detection
      if (voltage != null && voltage > _runningPeakVoltage) {
        _runningPeakVoltage = voltage;
      }
      return;
    }

    // RPM is zero (or unavailable) — track how long
    if (rpm != null && rpm <= AppConstants.engineOffRpmThreshold) {
      _rpmZeroSince ??= now;
      final rpmZeroDuration = now.difference(_rpmZeroSince!).inSeconds;

      // After confirmation period, transition to accessory
      if (rpmZeroDuration >= AppConstants.engineOffConfirmSeconds &&
          _engineState != EngineState.accessory &&
          _engineState != EngineState.off) {
        _setEngineState(EngineState.accessory);
      }
    }

    // In accessory mode, check voltage for full-off detection
    if (_engineState == EngineState.accessory && voltage != null) {
      // Fast path: alternator-off detection
      // If we saw charging voltage (>13.5V) while running, a drop below 13.0V
      // is definitive proof the alternator stopped. Confirm in 10s (not 120s).
      if (_runningPeakVoltage > AppConstants.alternatorChargingVoltage &&
          voltage < AppConstants.alternatorOffVoltage) {
        _alternatorOffSince ??= now;
        final altOffDuration = now.difference(_alternatorOffSince!).inSeconds;

        if (altOffDuration >= AppConstants.alternatorOffConfirmSeconds) {
          diag.info(_tag, 'Alternator off detected',
              'peak=${_runningPeakVoltage.toStringAsFixed(1)}V '
              'now=${voltage.toStringAsFixed(1)}V '
              'confirmed in ${altOffDuration}s');
          _setEngineState(EngineState.off);
          return;
        }
      } else {
        _alternatorOffSince = null;
      }

      // Fallback path: low absolute voltage (e.g., connected with engine already off)
      if (voltage < AppConstants.accessoryVoltageThreshold) {
        _lowVoltageSince ??= now;
        final lowVoltageDuration = now.difference(_lowVoltageSince!).inSeconds;

        if (lowVoltageDuration >= AppConstants.accessoryToOffSeconds) {
          _setEngineState(EngineState.off);
        }
      } else {
        _lowVoltageSince = null;
      }
    }

    // Fallback: if ALL commands timeout in accessory mode (ECU completely
    // unresponsive), the key is fully off. This catches the case where
    // voltage is stale from the running phase (OBD2 PID read 14.2V, but
    // AT RV keeps timing out so _lastVoltageReading is never updated).
    if (_engineState == EngineState.accessory &&
        _accessoryTimeoutSince != null) {
      final timeoutDuration =
          now.difference(_accessoryTimeoutSince!).inSeconds;
      if (timeoutDuration >= _accessoryTimeoutOffSeconds) {
        diag.info(_tag, 'ECU unresponsive for ${timeoutDuration}s in accessory mode',
            'All commands timing out — key is off');
        _setEngineState(EngineState.off);
      }
    }
  }

  void _setEngineState(EngineState newState) {
    if (_engineState == newState) return;
    final previous = _engineState;
    _engineState = newState;
    diag.info(_tag, 'Engine state: ${previous.name} → ${newState.name}',
        'rpm=${_liveData['rpm']?.toStringAsFixed(0) ?? "?"} '
        'voltage=${_lastVoltageReading?.toStringAsFixed(1) ?? "?"}V');
    if (!_engineStateController.isClosed) {
      _engineStateController.add(newState);
    }

    // Reset bitmap refresh flag when leaving running state so we
    // re-query next time engine starts.
    if (newState != EngineState.running) {
      _bitmapRefreshedSinceRunning = false;
    }
  }

  /// Get active PIDs for a tier, filtering out unsupported/failed PIDs.
  List<PidDefinition> _getActivePids(PollTier tier) {
    return PidRegistry.getByTier(tier).where((pid) {
      // Skip PIDs that have failed too many times
      if ((_consecutiveFailures[pid.id] ?? 0) >= _maxConsecutiveFailures) {
        return false;
      }
      // Skip PIDs not matching detected protocol
      if (!_isProtocolSupported(pid.protocol)) {
        return false;
      }
      // Skip OBD2 PIDs not in the ECU's supported PID bitmap.
      // This saves ~8 timeouts (16 seconds/session) for PIDs the ECU
      // explicitly declares unsupported. The failure counter is still
      // a fallback for edge cases where the bitmap is incomplete.
      if (pid.protocol == PidProtocol.obd2 && _supportedPids != null) {
        if (!_supportedPids!.contains(pid.code)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<double?> requestPid(PidDefinition pid) async {
    if (!isReady) return null;

    try {
      final command = _formatCommand(pid);
      if (command == null) {
        diag.warn(_pidTag, 'No command for ${pid.id}',
            'protocol=${pid.protocol.name}');
        _updatePidStatusFailure(pid, 'null', 'unsupported', null);
        return null;
      }

      // Ensure PidStatus entry exists
      _pidStatus.putIfAbsent(
        pid.id,
        () => PidStatus(
          id: pid.id,
          name: pid.name,
          command: command,
          protocol: pid.protocol,
        ),
      );

      final response = await _sendSafe(command);
      if (response == null) {
        final fails = (_consecutiveFailures[pid.id] ?? 0) + 1;
        _consecutiveFailures[pid.id] = fails;
        _updatePidStatusFailure(pid, command, 'no_response', null);
        if (fails == _maxConsecutiveFailures) {
          _liveData.remove(pid.id);
          diag.warn(_pidTag, '✗ ${pid.id} disabled — stale value evicted',
              'cmd=$command reason=no_response fails=$fails');
        } else if (fails == 1) {
          diag.warn(_pidTag, '✗ ${pid.id} no_response',
              'cmd=$command');
        }
        return null;
      }

      final rawTruncated = _truncate80(response);

      // Try parsing first — the parser handles multi-ECU responses correctly
      // by scanning each line for the expected response header (41xx/62xxxx).
      // On multi-ECU CAN buses (e.g. 2026 Ram with engine + TCM), one ECU
      // may return valid data while another returns 7F (negative response).
      // The old code checked for '7F' first and rejected the entire response,
      // throwing away valid data from the correct ECU.
      final value = _parseResponse(pid, response);

      if (value != null) {
        _liveData[pid.id] = value;
        final wasFirstSuccess = (_pidStatus[pid.id]?.successCount ?? 0) == 0;
        _updatePidStatusSuccess(pid, command, value, rawTruncated);
        _consecutiveFailures[pid.id] = 0;

        if (wasFirstSuccess) {
          diag.info(_pidTag,
              '✓ ${pid.id} first success = ${value.toStringAsFixed(2)} ${pid.unit}',
              'cmd=$command raw=$rawTruncated');
        }
      } else {
        // Parse failed — determine why for accurate failure tracking
        final upper = response.toUpperCase().replaceAll(' ', '');
        final isNegativeOnly = _isNegativeResponseOnly(upper);
        final failReason = isNegativeOnly ? 'negative_resp' : 'parse_fail';

        final fails = (_consecutiveFailures[pid.id] ?? 0) + 1;
        _consecutiveFailures[pid.id] = fails;
        _updatePidStatusFailure(pid, command, failReason, rawTruncated);
        if (fails == _maxConsecutiveFailures) {
          _liveData.remove(pid.id);
          diag.warn(_pidTag, '✗ ${pid.id} disabled — stale value evicted',
              'cmd=$command reason=$failReason fails=$fails');
        } else if (fails == 1) {
          diag.warn(_pidTag, '✗ ${pid.id} $failReason',
              'cmd=$command raw=$rawTruncated');
        }
      }

      return value;
    } catch (e) {
      _consecutiveFailures[pid.id] =
          (_consecutiveFailures[pid.id] ?? 0) + 1;
      diag.error(_pidTag, '✗ ${pid.id} exception', '$e');
      return null;
    }
  }

  void _updatePidStatusSuccess(
    PidDefinition pid,
    String command,
    double value,
    String? rawHex,
  ) {
    final status = _pidStatus[pid.id];
    if (status == null) return;
    status.successCount++;
    status.lastValue = value;
    status.lastUnit = pid.unit;
    status.lastRawHex = rawHex;
    status.lastSuccess = DateTime.now();
    status.failReason = null;
  }

  void _updatePidStatusFailure(
    PidDefinition pid,
    String command,
    String reason,
    String? rawHex,
  ) {
    _pidStatus.putIfAbsent(
      pid.id,
      () => PidStatus(
        id: pid.id,
        name: pid.name,
        command: command,
        protocol: pid.protocol,
      ),
    );
    final status = _pidStatus[pid.id]!;
    status.failureCount++;
    status.lastRawHex = rawHex;
    status.failReason = reason;
  }

  // ─── Lifecycle ───

  void dispose() {
    _disposed = true;
    stopPolling();
    _dataController.close();
    _statusController.close();
    _engineStateController.close();
  }

  // ─── Private: Protocol Support ───

  bool _isProtocolSupported(PidProtocol pidProtocol) {
    switch (_protocol) {
      case ObdProtocol.obd2:
        return pidProtocol == PidProtocol.obd2 ||
            pidProtocol == PidProtocol.mode22;
      case ObdProtocol.unknown:
        // When protocol detection failed, try all protocols — the ECU may
        // have been unresponsive during init but is ready now.
        return true;
    }
  }

  // ─── Private: Command Formatting ───

  String? _formatCommand(PidDefinition pid) {
    switch (pid.protocol) {
      case PidProtocol.obd2:
        final mode = (pid.mode ?? 0x01).toRadixString(16).padLeft(2, '0');
        final pidHex = pid.code.toRadixString(16).padLeft(2, '0');
        return '$mode$pidHex'.toUpperCase();

      case PidProtocol.mode22:
        // pid.code is the full 16-bit data identifier (e.g., 0xA09F)
        return '22${pid.code.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    }
  }

  // ─── Private: Response Parsing ───

  double? _parseResponse(PidDefinition pid, String response) {
    try {
      // Special handling for battery voltage: multi-ECU responses may return
      // different values. Pick the highest (most accurate from charging ECU).
      // Also compare with AT RV reading and use whichever is higher.
      if (pid.id == 'batteryVoltage') {
        return _parseBatteryVoltage(pid, response);
      }

      final value = _parseResponseRaw(pid, response);
      if (value == null) return null;

      // Filter sentinel / implausible values that indicate "not available"
      // OBD2 temp (A-40 formula): byte 0x00 = -40°F, byte 0x01 = -38.2°F
      if (pid.unit == '°F' && value <= -38.0) return null;
      if (pid.unit == '%' && value > 100.5) return null;
      if (value.isNaN || value.isInfinite) return null;

      // Per-PID plausibility checks for known-broken responses
      if (pid.id == 'railPressure' && value > 35000) {
        diag.debug(_pidTag, '${pid.id} implausible value filtered',
            '${value.toStringAsFixed(0)} PSI > 35000 PSI max');
        return null;
      }
      if (pid.id == 'intercoolerOutletTemp' && value > 500) {
        diag.debug(_pidTag, '${pid.id} implausible value filtered',
            '${value.toStringAsFixed(0)}°F > 500°F max');
        return null;
      }
      if (pid.id == 'runtimeExtended' && value > 500000) {
        diag.debug(_pidTag, '${pid.id} implausible value filtered',
            '${value.toStringAsFixed(0)}s > 500000s max');
        return null;
      }

      return value;
    } catch (e) {
      diag.error(_pidTag, '✗ ${pid.id} parse exception', '$e');
      return null;
    }
  }

  /// Battery voltage needs special multi-ECU handling: parse each ECU line
  /// independently and pick the highest value. Also compare with AT RV.
  double? _parseBatteryVoltage(PidDefinition pid, String response) {
    final lines = response.split(RegExp(r'[\r\n]+'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    double? bestValue;
    for (final line in lines) {
      final bytes = Obd2Parser.parseResponse(
        line,
        expectedPid: pid.code,
        mode: pid.mode ?? 0x01,
      );
      if (bytes != null && bytes.length >= pid.responseBytes) {
        final v = pid.parser(bytes.sublist(0, pid.responseBytes));
        if (v > 0 && v < 20 && !v.isNaN && !v.isInfinite) {
          if (bestValue == null || v > bestValue) {
            bestValue = v;
          }
        }
      }
    }

    // Compare with AT RV reading (stored in _lastVoltageReading)
    if (bestValue != null && _lastVoltageReading != null) {
      if (_lastVoltageReading! > bestValue) {
        bestValue = _lastVoltageReading;
      }
    }

    return bestValue;
  }

  double? _parseResponseRaw(PidDefinition pid, String response) {
    try {
      switch (pid.protocol) {
        case PidProtocol.obd2:
          final bytes = Obd2Parser.parseResponse(
            response,
            expectedPid: pid.code,
            mode: pid.mode ?? 0x01,
          );
          if (bytes == null) return null;
          if (bytes.length < pid.responseBytes) {
            diag.warn(_pidTag, '✗ ${pid.id} short response',
                'got ${bytes.length} bytes, need ${pid.responseBytes}');
            return null;
          }
          return pid.parser(bytes.sublist(0, pid.responseBytes));

        case PidProtocol.mode22:
          final bytes = Obd2Parser.parseMode22Response(
            response,
            dataId: pid.code,
          );
          if (bytes == null) return null;
          if (bytes.length < pid.responseBytes) {
            diag.warn(_pidTag, '✗ ${pid.id} short mode22 response',
                'got ${bytes.length} bytes, need ${pid.responseBytes}');
            return null;
          }
          return pid.parser(bytes.sublist(0, pid.responseBytes));
      }
    } catch (e) {
      diag.error(_pidTag, '✗ ${pid.id} parse exception', '$e');
      return null;
    }
  }

  // ─── Private: Safe Command Send ───

  /// Send a command to the adapter. Returns null on any failure.
  ///
  /// No in-flight lock needed — the single-threaded poll loop guarantees
  /// only one command runs at a time.
  Future<String?> _sendSafe(String command, {Duration? timeout}) async {
    if (_disposed || !_bluetooth.isConnected) return null;

    try {
      final response = await _bluetooth.sendCommand(command, timeout: timeout);
      return response;
    } on TimeoutException {
      diag.warn(_tag, 'Command timeout', command);
      return null;
    } on StateError catch (e) {
      diag.error(_tag, 'Command state error', '$command: $e');
      return null;
    } catch (e) {
      diag.error(_tag, 'Command exception', '$command: $e');
      return null;
    }
  }

  // ─── Private: Polling Summary ───

  /// Log a periodic summary of polling health — which PIDs are working,
  /// failing, disabled. This is the key diagnostic for the debug screen.
  void _logPollingSummary(int tick) {
    final active = _pidStatus.values.where((s) => s.successCount > 0).length;
    final failing = _pidStatus.values.where((s) =>
        s.successCount == 0 && s.failureCount > 0).length;
    final disabled = _consecutiveFailures.entries
        .where((e) => e.value >= _maxConsecutiveFailures)
        .length;
    final liveKeys = _liveData.keys.toList()..sort();

    diag.info(_tag, 'Poll summary (tick $tick)',
        'protocol=${_protocol.name} '
        'active=$active failing=$failing disabled=$disabled '
        'live=${liveKeys.length} values');

    // Log the actual live data keys so we know which sensors have data
    if (liveKeys.isNotEmpty) {
      diag.debug(_tag, 'Live sensors', liveKeys.join(', '));
    }

    // Log disabled PIDs for debugging
    final disabledPids = _consecutiveFailures.entries
        .where((e) => e.value >= _maxConsecutiveFailures)
        .map((e) => '${e.key}(${e.value})')
        .toList();
    if (disabledPids.isNotEmpty) {
      diag.debug(_tag, 'Disabled PIDs', disabledPids.join(', '));
    }
  }

  // ─── Private: Response Analysis ───

  /// Check if a response contains ONLY negative responses (7F xx xx) and
  /// no positive data. On multi-ECU CAN buses, a response may contain both
  /// a valid positive response from one ECU and a 7F from another — that's
  /// not a true negative response (the parser will extract the valid data).
  bool _isNegativeResponseOnly(String upperHex) {
    // Split into lines and check each CAN frame
    final lines = upperHex
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim().replaceAll(' ', ''))
        .where((l) => l.isNotEmpty)
        .toList();

    bool hasNegative = false;
    bool hasPositive = false;

    for (final line in lines) {
      if (line.contains('7F')) hasNegative = true;
      // Positive OBD2 response: 41xx, Mode $22 response: 62xxxx
      if (RegExp(r'4[1-9A-F][0-9A-F]{2}').hasMatch(line) ||
          line.contains('62')) {
        hasPositive = true;
      }
    }

    return hasNegative && !hasPositive;
  }

  // ─── Private: Utilities ───

  String _truncate(String? s) {
    if (s == null) return 'null';
    return s.length > 120 ? '${s.substring(0, 120)}...' : s;
  }

  String _truncate80(String s) {
    return s.length > 80 ? '${s.substring(0, 80)}...' : s;
  }

  static String _hexPid(int pid) =>
      '0x${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}
