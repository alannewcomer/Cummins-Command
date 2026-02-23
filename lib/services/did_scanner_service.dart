import 'dart:async';

import 'package:myapp/models/did_scan_result.dart';
import 'package:myapp/services/bluetooth_service.dart';
import 'package:myapp/services/diagnostic_service.dart';
import 'package:myapp/services/obd2_parser.dart';
import 'package:myapp/services/obd_service.dart';

const _tag = 'DID-SCAN';

/// Default DID ranges for Chrysler/Stellantis 6.7L Cummins.
class DidRanges {
  static const powertrain = (0x0100, 0x02FF);
  static const enhanced = (0xA000, 0xA0FF);
  static const bodyChassis = (0xB000, 0xB0FF);
  static const udsStandard = (0xF100, 0xF2FF);
  static const manufacturer = (0xFD00, 0xFDFF);

  static const all = [powertrain, enhanced, bodyChassis, udsStandard, manufacturer];

  static String rangeLabel((int, int) range) {
    final start = range.$1.toRadixString(16).toUpperCase().padLeft(4, '0');
    final end = range.$2.toRadixString(16).toUpperCase().padLeft(4, '0');
    return '$start-$end';
  }

  static int totalDids(List<(int, int)> ranges) {
    return ranges.fold(0, (sum, r) => sum + (r.$2 - r.$1 + 1));
  }
}

/// Scans Mode $22 DID ranges via BluetoothService.sendCommand().
///
/// Automatically stops OBD polling and pauses health checks before scanning,
/// then restores both when done. Read-only, warranty-safe.
class DidScannerService {
  final BluetoothService _bluetooth;
  final ObdService _obdService;

  DidScannerService({
    required BluetoothService bluetooth,
    required ObdService obdService,
  })  : _bluetooth = bluetooth,
        _obdService = obdService;

  bool _scanning = false;
  bool _stopRequested = false;
  bool _wasPolling = false;

  final _progressController = StreamController<DidScanProgress>.broadcast();

  Stream<DidScanProgress> get progressStream => _progressController.stream;
  bool get isScanning => _scanning;

  /// Start scanning the given DID ranges.
  ///
  /// Automatically stops OBD polling if active and pauses health checks.
  /// Returns a summary when complete (or stopped early).
  /// Throws [StateError] if already scanning or not connected.
  Future<DidScanSummary> startScan({
    required List<(int, int)> ranges,
    Duration timeout = const Duration(milliseconds: 120),
  }) async {
    if (_scanning) throw StateError('Scan already in progress');
    if (!_bluetooth.isConnected) throw StateError('Not connected to adapter');

    _scanning = true;
    _stopRequested = false;

    // ── Capture engine conditions before stopping polling ──
    final conditionsAtStart = Map<String, double>.from(_obdService.liveData);
    diag.info(_tag, 'Conditions at start',
        'rpm=${conditionsAtStart['rpm']?.toStringAsFixed(0) ?? '?'} '
        'speed=${conditionsAtStart['speed']?.toStringAsFixed(0) ?? '?'}mph '
        'coolant=${conditionsAtStart['coolantTemp']?.toStringAsFixed(0) ?? '?'}F');

    // ── Take exclusive control of the adapter ──
    _wasPolling = _obdService.isPolling;
    if (_wasPolling) {
      diag.info(_tag, 'Auto-stopping OBD polling for scan');
      _obdService.stopPolling();
      // Wait for any in-flight command to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    _bluetooth.pauseHealthCheck();

    final results = <DidScanResult>[];
    final stopwatch = Stopwatch()..start();
    int foundCount = 0;
    int negativeCount = 0;
    int timeoutCount = 0;
    int errorCount = 0;

    final totalDids = DidRanges.totalDids(ranges);
    final rangeLabels = ranges.map(DidRanges.rangeLabel).toList();

    diag.info(_tag, 'Starting DID scan', '$totalDids DIDs across ${ranges.length} ranges');

    try {
      // Verify connection with ATRV (read voltage)
      final voltage = await _bluetooth.sendCommand('ATRV', timeout: const Duration(seconds: 2));
      diag.info(_tag, 'Adapter voltage', voltage);

      // Set fast timeout: 0x1E = 30 decimal → 30 × 4.096ms ≈ 123ms
      await _bluetooth.sendCommand('ATST1E', timeout: const Duration(seconds: 1));

      int current = 0;

      for (final range in ranges) {
        if (_stopRequested) break;

        for (int did = range.$1; did <= range.$2; did++) {
          if (_stopRequested) break;

          current++;
          final didHex = did.toRadixString(16).toUpperCase().padLeft(4, '0');
          final command = '22$didHex';

          try {
            final raw = await _bluetooth.sendCommand(
              command,
              timeout: timeout + const Duration(milliseconds: 80),
            );

            final result = _classifyResponse(did, raw, didHex);
            results.add(result);

            switch (result.response) {
              case 'ok':
                foundCount++;
                diag.info(_tag, 'FOUND DID $didHex',
                    'ecu=${result.ecuAddress ?? '?'} '
                    '${result.dataBytes?.length ?? 0}B: ${result.dataBytesHex}');
              case 'negative':
                negativeCount++;
              case 'timeout':
                timeoutCount++;
              case 'error':
                errorCount++;
            }
          } on TimeoutException {
            timeoutCount++;
            results.add(DidScanResult(
              did: did,
              response: 'timeout',
              rawHex: '',
            ));
          } on StateError catch (e) {
            errorCount++;
            results.add(DidScanResult(
              did: did,
              response: 'error',
              rawHex: e.toString(),
            ));
            diag.error(_tag, 'StateError at DID $didHex', e.toString());
            if (!_bluetooth.isConnected) {
              diag.error(_tag, 'Adapter disconnected, aborting scan');
              _stopRequested = true;
              break;
            }
          } catch (e) {
            errorCount++;
            results.add(DidScanResult(
              did: did,
              response: 'error',
              rawHex: e.toString(),
            ));
          }

          // Emit progress
          if (!_progressController.isClosed) {
            _progressController.add(DidScanProgress(
              current: current,
              total: totalDids,
              currentDid: did,
              foundCount: foundCount,
              negativeCount: negativeCount,
              timeoutCount: timeoutCount,
              errorCount: errorCount,
              elapsed: stopwatch.elapsed,
              lastResult: results.isNotEmpty ? results.last : null,
            ));
          }
        }
      }

      // Restore default timeout (ATST64 from init sequence)
      try {
        await _bluetooth.sendCommand('ATST64', timeout: const Duration(seconds: 1));
      } catch (_) {
        diag.warn(_tag, 'Failed to restore adapter timeout');
      }
    } catch (e) {
      diag.error(_tag, 'Scan error', e.toString());
    } finally {
      stopwatch.stop();
      _scanning = false;
      _restoreAdapterState();
    }

    // Capture end conditions (liveData is stale since polling was stopped,
    // but still reflects the last known values — useful for comparison)
    final conditionsAtEnd = Map<String, double>.from(_obdService.liveData);

    final summary = DidScanSummary(
      results: results,
      totalScanned: results.length,
      foundCount: foundCount,
      negativeCount: negativeCount,
      timeoutCount: timeoutCount,
      errorCount: errorCount,
      duration: stopwatch.elapsed,
      ranges: rangeLabels,
      wasStopped: _stopRequested,
      conditionsAtStart: conditionsAtStart,
      conditionsAtEnd: conditionsAtEnd,
    );

    diag.info(_tag, 'Scan complete',
        '${summary.foundCount} found / ${summary.negativeCount} neg / '
        '${summary.timeoutCount} timeout in ${summary.duration.inSeconds}s'
        '${summary.wasStopped ? ' (stopped early)' : ''}');

    return summary;
  }

  void stopScan() {
    if (_scanning) {
      _stopRequested = true;
      diag.info(_tag, 'Stop requested');
    }
  }

  /// Restore adapter state after scan — resume health check and optionally
  /// restart OBD polling if it was running before.
  void _restoreAdapterState() {
    _bluetooth.resumeHealthCheck();
    if (_wasPolling && _bluetooth.isConnected) {
      diag.info(_tag, 'Restarting OBD polling after scan');
      _obdService.startPolling();
    }
    _wasPolling = false;
  }

  /// Classify a raw adapter response for a Mode $22 DID.
  ///
  /// IMPORTANT: Check positive response (62XXXX) BEFORE negative (7F22XX).
  /// On CAN bus, multiple ECUs respond — one may send valid data while
  /// another sends 7F. We want to capture the valid data.
  DidScanResult _classifyResponse(int did, String raw, String didHex) {
    final cleaned = raw.trim().toUpperCase();

    // Check for timeout / no data
    if (cleaned.isEmpty || Obd2Parser.isError(cleaned)) {
      return DidScanResult(
        did: did,
        response: 'timeout',
        rawHex: raw,
      );
    }

    // Extract ECU source address from CAN header (e.g. "7E8 06 62 ...")
    final ecuAddr = _extractEcuAddress(cleaned);

    // ── Check POSITIVE response first (before negative!) ──
    // On multi-ECU CAN buses, one ECU gives 62XXXX data while others give 7F.
    // Obd2Parser.parseMode22Response() already filters out 7F lines internally.
    final dataBytes = Obd2Parser.parseMode22Response(raw, dataId: did);
    if (dataBytes != null && dataBytes.isNotEmpty) {
      // Extract ECU address specifically from the positive response line
      final positiveEcu = _extractPositiveEcuAddress(cleaned, didHex);
      return DidScanResult(
        did: did,
        response: 'ok',
        dataBytes: dataBytes,
        rawHex: raw,
        ecuAddress: positiveEcu ?? ecuAddr,
      );
    }

    // ── No positive data — check for negative response: 7F 22 XX ──
    final negMatch = RegExp(r'7F22([0-9A-F]{2})')
        .firstMatch(cleaned.replaceAll(' ', '').replaceAll('\n', ''));
    if (negMatch != null) {
      final nrc = int.parse(negMatch.group(1)!, radix: 16);
      return DidScanResult(
        did: did,
        response: 'negative',
        nrc: nrc,
        rawHex: raw,
        ecuAddress: ecuAddr,
      );
    }

    // Could not classify — mark as error
    return DidScanResult(
      did: did,
      response: 'error',
      rawHex: raw,
    );
  }

  /// Extract ECU address from the line containing the positive response (62XXXX).
  static String? _extractPositiveEcuAddress(String cleaned, String didHex) {
    final lines = cleaned.split('\n');
    final target = '62$didHex';
    for (final line in lines) {
      final hex = line.trim().replaceAll(' ', '');
      if (hex.contains(target)) {
        // The 3-char CAN ID is at the start of the line
        final match = RegExp(r'^([0-9A-F]{3})').firstMatch(hex);
        return match?.group(1);
      }
    }
    return null;
  }

  /// Extract 11-bit CAN source address from raw response (ATH1 enabled).
  static String? _extractEcuAddress(String cleaned) {
    final hex = cleaned.replaceAll('\n', ' ').trim();
    final match = RegExp(r'^([0-9A-F]{3})\s').firstMatch(hex);
    return match?.group(1);
  }

  void dispose() {
    _stopRequested = true;
    _progressController.close();
  }
}
