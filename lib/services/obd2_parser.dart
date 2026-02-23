// Standard OBD-II hex response parser.
//
// Handles ELM327-style responses from OBD2 adapters. Strips headers,
// validates response codes, extracts data bytes, and handles multi-line
// responses and error conditions.

/// Result of parsing an OBD2 response.
class Obd2ParseResult {
  final int pid;
  final List<int> dataBytes;

  const Obd2ParseResult({required this.pid, required this.dataBytes});

  @override
  String toString() =>
      'Obd2ParseResult(pid: 0x${pid.toRadixString(16).toUpperCase()}, '
      'bytes: [${dataBytes.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}])';
}

class Obd2Parser {
  Obd2Parser._();

  /// Known error responses from ELM327/OBDLink adapters.
  static const _errorPatterns = [
    'NO DATA',
    'UNABLE TO CONNECT',
    'BUS INIT',
    'BUS ERROR',
    'CAN ERROR',
    'FB ERROR',
    'DATA ERROR',
    'BUFFER FULL',
    'ACT ALERT',
    'LV RESET',
    'STOPPED',
    'ERROR',
    '?',
  ];

  /// Parses a raw hex response string for an expected PID.
  ///
  /// Returns the data bytes (after the service/PID header) on success,
  /// or null if the response is invalid, an error, or doesn't match
  /// the expected PID.
  ///
  /// [rawHex] is the full response string from the adapter (may include
  /// headers, whitespace, carriage returns, multi-line data).
  /// [expectedPid] is the PID code we requested (e.g. 0x0C for RPM).
  /// [mode] is the OBD2 mode (default 0x01 for current data).
  static List<int>? parseResponse(
    String rawHex, {
    required int expectedPid,
    int mode = 0x01,
  }) {
    if (rawHex.isEmpty) return null;

    // Clean up: remove whitespace, carriage returns, prompts
    final cleaned = rawHex
        .replaceAll('\r', '\n')
        .replaceAll('>', '')
        .trim()
        .toUpperCase();

    if (cleaned.isEmpty) return null;

    // Check for known error responses
    if (_isErrorResponse(cleaned)) return null;

    // Handle multi-line responses — pick the relevant line.
    // On multi-ECU CAN buses, filter out lines that are negative responses
    // (contain 7F) from other ECUs so they don't pollute parsing.
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !_isErrorResponse(l))
        .where((l) => !_isNegativeResponseLine(l))
        .toList();

    if (lines.isEmpty) return null;

    // Build expected response header
    // Mode 01 responses start with 41, mode 02 with 42, etc.
    final responseMode = (mode + 0x40).toRadixString(16).toUpperCase().padLeft(2, '0');
    final pidHex = expectedPid.toRadixString(16).toUpperCase().padLeft(2, '0');
    final expectedHeader = '$responseMode$pidHex';

    // Try each line for a matching response
    for (final line in lines) {
      final result = _parseSingleLine(line, expectedHeader, expectedPid);
      if (result != null) return result;
    }

    // If single-line parse failed, try concatenating multi-line ISO TP frames
    final multiResult = _parseMultiLineResponse(lines, expectedHeader, expectedPid);
    if (multiResult != null) return multiResult;

    return null;
  }

  /// Parse a complete response that may return a structured result with PID.
  static Obd2ParseResult? parseResponseFull(
    String rawHex, {
    required int expectedPid,
    int mode = 0x01,
  }) {
    final bytes = parseResponse(rawHex, expectedPid: expectedPid, mode: mode);
    if (bytes == null) return null;
    return Obd2ParseResult(pid: expectedPid, dataBytes: bytes);
  }

  /// Checks if a cleaned response string represents an error.
  static bool isError(String response) {
    return _isErrorResponse(response.trim().toUpperCase());
  }

  static bool _isErrorResponse(String cleaned) {
    for (final pattern in _errorPatterns) {
      if (cleaned.contains(pattern)) return true;
    }
    return false;
  }

  /// Check if a single CAN frame line is a negative response (7F xx xx).
  ///
  /// On multi-ECU CAN buses (e.g. 2026 Ram with engine + TCM + body),
  /// multiple ECUs respond to every OBD2 request. The target ECU sends
  /// valid data (41 xx ...) while other ECUs send 7F (negative response,
  /// typically NRC 0x12 or 0x22). These 7F lines must be filtered out
  /// before parsing so they don't block valid data extraction.
  static bool _isNegativeResponseLine(String line) {
    final hex = line.replaceAll(' ', '');
    // A negative response CAN frame contains: [CAN header] + 7F + [service] + [NRC]
    // The data portion after the CAN header starts with 7F.
    // We check if 7F appears in a position consistent with a negative response
    // and the line does NOT also contain a positive response (4x xx).
    if (!hex.contains('7F')) return false;
    // If the line also contains a positive response header, keep it
    if (RegExp(r'4[1-9A-F][0-9A-F]{2}').hasMatch(hex)) return false;
    return true;
  }

  /// Parse a single line of hex data looking for the expected header.
  static List<int>? _parseSingleLine(
    String line,
    String expectedHeader,
    int expectedPid,
  ) {
    // Remove spaces for uniform processing
    final hex = line.replaceAll(' ', '');

    // Strip CAN headers if present (3 bytes = 6 hex chars before response mode)
    // CAN header format: XXX (11-bit) or XXXXXXXX (29-bit) followed by data
    // We look for our expected header anywhere in the line
    final headerIndex = hex.indexOf(expectedHeader);
    if (headerIndex < 0) return null;

    // Extract data bytes after the header
    // Header is: responseMode (2 chars) + PID (2 chars) = 4 chars
    final dataStart = headerIndex + expectedHeader.length;
    final dataHex = hex.substring(dataStart);

    return _hexStringToBytes(dataHex);
  }

  /// Parse multi-line ISO 15765-2 (ISO TP) responses.
  ///
  /// First Frame: 1XXX followed by data (XXX = total length)
  /// Consecutive Frames: 2N followed by data (N = sequence number)
  static List<int>? _parseMultiLineResponse(
    List<String> lines,
    String expectedHeader,
    int expectedPid,
  ) {
    if (lines.length < 2) return null;

    // Look for first frame indicator
    // Format varies; some adapters strip framing, some don't.
    // Try to find the response header across all lines combined.
    final combined = lines.map((l) => l.replaceAll(' ', '')).join();
    final headerIndex = combined.indexOf(expectedHeader);
    if (headerIndex < 0) return null;

    final dataStart = headerIndex + expectedHeader.length;
    if (dataStart >= combined.length) return null;

    final dataHex = combined.substring(dataStart);
    return _hexStringToBytes(dataHex);
  }

  /// Converts a hex string to a list of byte values.
  ///
  /// Returns null if the string contains non-hex characters or has
  /// an odd length.
  static List<int>? _hexStringToBytes(String hex) {
    final cleaned = hex.replaceAll(' ', '');
    if (cleaned.isEmpty) return null;

    // Must be even number of characters
    final length = cleaned.length % 2 == 0 ? cleaned.length : cleaned.length - 1;
    if (length == 0) return null;

    final bytes = <int>[];
    for (var i = 0; i < length; i += 2) {
      final byteStr = cleaned.substring(i, i + 2);
      final value = int.tryParse(byteStr, radix: 16);
      if (value == null) return null; // Invalid hex character
      bytes.add(value);
    }

    return bytes.isEmpty ? null : bytes;
  }

  /// Parses a raw hex response for a Mode $22 (manufacturer-enhanced) request.
  ///
  /// Mode $22 response prefix is 0x62 (= 0x22 + 0x40).
  /// Header format: "62" + 4-char data identifier (e.g., "62A09F").
  ///
  /// [rawHex] is the full response string from the adapter.
  /// [dataId] is the 16-bit data identifier that was requested (e.g., 0xA09F).
  ///
  /// Returns the data bytes after the 6-char header, or null on failure.
  static List<int>? parseMode22Response(String rawHex, {required int dataId}) {
    if (rawHex.isEmpty) return null;

    final cleaned = rawHex
        .replaceAll('\r', '\n')
        .replaceAll('>', '')
        .trim()
        .toUpperCase();

    if (cleaned.isEmpty) return null;
    if (_isErrorResponse(cleaned)) return null;

    // Filter out lines that are purely negative responses (7F 22 xx)
    // but don't reject the whole response — other ECUs may have valid data
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !_isErrorResponse(l))
        .where((l) => !_isNegativeResponseLine(l))
        .toList();

    if (lines.isEmpty) return null;

    // Build expected header: "62" + 4-hex-digit data identifier
    final expectedHeader =
        '62${dataId.toRadixString(16).padLeft(4, '0').toUpperCase()}';

    for (final line in lines) {
      final result = _parseSingleLine(line, expectedHeader, dataId);
      if (result != null) return result;
    }

    // Try multi-line
    final combined = lines.map((l) => l.replaceAll(' ', '')).join();
    final idx = combined.indexOf(expectedHeader);
    if (idx >= 0) {
      final dataStart = idx + expectedHeader.length;
      if (dataStart < combined.length) {
        return _hexStringToBytes(combined.substring(dataStart));
      }
    }

    return null;
  }

  /// Utility: convert a list of bytes to a hex string for debugging.
  static String bytesToHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
        .join(' ');
  }
}
