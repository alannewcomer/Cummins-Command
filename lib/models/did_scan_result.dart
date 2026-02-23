/// Result of scanning a single DID via Mode $22 (ReadDataByIdentifier).
class DidScanResult {
  final int did;

  /// 'ok', 'negative', 'timeout', 'error'
  final String response;
  final List<int>? dataBytes;

  /// Negative Response Code (if response == 'negative')
  final int? nrc;
  final String rawHex;

  /// CAN source address of the responding ECU (e.g. '7E8'=PCM, '7E9'=TCM).
  /// Extracted from the raw CAN frame header. Null if not parseable.
  final String? ecuAddress;

  const DidScanResult({
    required this.did,
    required this.response,
    this.dataBytes,
    this.nrc,
    required this.rawHex,
    this.ecuAddress,
  });

  String get didHex => did.toRadixString(16).toUpperCase().padLeft(4, '0');

  String get dataBytesHex => dataBytes != null
      ? dataBytes!
          .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
          .join(' ')
      : '';

  /// Human-readable name for common UDS Negative Response Codes.
  static String nrcName(int code) {
    return switch (code) {
      0x10 => 'generalReject',
      0x11 => 'serviceNotSupported',
      0x12 => 'subFunctionNotSupported',
      0x13 => 'incorrectMessageLength',
      0x14 => 'responseTooLong',
      0x22 => 'conditionsNotCorrect',
      0x24 => 'requestSequenceError',
      0x25 => 'noResponseFromSubnet',
      0x26 => 'failurePreventsExecution',
      0x31 => 'requestOutOfRange',
      0x33 => 'securityAccessDenied',
      0x35 => 'invalidKey',
      0x36 => 'exceededNumberOfAttempts',
      0x37 => 'requiredTimeDelayNotExpired',
      0x70 => 'uploadDownloadNotAccepted',
      0x71 => 'transferDataSuspended',
      0x72 => 'generalProgrammingFailure',
      0x73 => 'wrongBlockSequenceCounter',
      0x78 => 'responsePending',
      0x7E => 'subFunctionNotSupportedInActiveSession',
      0x7F => 'serviceNotSupportedInActiveSession',
      _ => 'unknown_0x${code.toRadixString(16).toUpperCase()}',
    };
  }
}

/// Progress update emitted during a DID scan.
class DidScanProgress {
  final int current;
  final int total;
  final int currentDid;
  final int foundCount;
  final int negativeCount;
  final int timeoutCount;
  final int errorCount;
  final Duration elapsed;

  /// Most recent result (if any).
  final DidScanResult? lastResult;

  const DidScanProgress({
    required this.current,
    required this.total,
    required this.currentDid,
    required this.foundCount,
    required this.negativeCount,
    required this.timeoutCount,
    required this.errorCount,
    required this.elapsed,
    this.lastResult,
  });

  double get fraction => total > 0 ? current / total : 0;

  Duration get estimatedRemaining {
    if (current == 0) return Duration.zero;
    final msPerDid = elapsed.inMilliseconds / current;
    final remaining = (total - current) * msPerDid;
    return Duration(milliseconds: remaining.round());
  }
}

/// Final summary after a scan completes or is stopped.
class DidScanSummary {
  final List<DidScanResult> results;
  final int totalScanned;
  final int foundCount;
  final int negativeCount;
  final int timeoutCount;
  final int errorCount;
  final Duration duration;
  final List<String> ranges;
  final bool wasStopped;

  /// Snapshot of live OBD data at scan start (RPM, speed, temps, etc.).
  /// Used for cross-referencing DID values with known engine conditions.
  final Map<String, double> conditionsAtStart;

  /// Snapshot of live OBD data at scan end.
  final Map<String, double> conditionsAtEnd;

  const DidScanSummary({
    required this.results,
    required this.totalScanned,
    required this.foundCount,
    required this.negativeCount,
    required this.timeoutCount,
    required this.errorCount,
    required this.duration,
    required this.ranges,
    required this.wasStopped,
    this.conditionsAtStart = const {},
    this.conditionsAtEnd = const {},
  });

  List<DidScanResult> get foundResults =>
      results.where((r) => r.response == 'ok').toList();

  /// DIDs that returned NRC 0x22 (conditionsNotCorrect) — these exist but
  /// need engine in a specific state (running, warm, etc.) to respond.
  List<DidScanResult> get conditionsNotCorrectResults =>
      results.where((r) => r.response == 'negative' && r.nrc == 0x22).toList();

  /// DIDs that returned NRC 0x33 (securityAccessDenied) — exist but locked.
  List<DidScanResult> get securityDeniedResults =>
      results.where((r) => r.response == 'negative' && r.nrc == 0x33).toList();

  /// NRC distribution: code → count.
  Map<int, int> get nrcDistribution {
    final dist = <int, int>{};
    for (final r in results) {
      if (r.response == 'negative' && r.nrc != null) {
        dist[r.nrc!] = (dist[r.nrc!] ?? 0) + 1;
      }
    }
    return dist;
  }
}
