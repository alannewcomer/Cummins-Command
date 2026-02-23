import 'dart:collection';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/config/constants.dart';

/// Severity levels for diagnostic log entries.
enum DiagLevel { debug, info, warn, error }

/// A single diagnostic log entry.
class DiagEntry {
  final DateTime timestamp;
  final DiagLevel level;
  final String tag;
  final String message;
  final String? detail;

  DiagEntry({
    required this.level,
    required this.tag,
    required this.message,
    this.detail,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toMap() => {
        't': timestamp.millisecondsSinceEpoch,
        'level': level.name,
        'tag': tag,
        'msg': message,
        if (detail != null) 'detail': detail,
      };

  @override
  String toString() {
    final ts = '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${timestamp.millisecond.toString().padLeft(3, '0')}';
    final lvl = level.name.toUpperCase().padRight(5);
    final d = detail != null ? ' | $detail' : '';
    return '[$ts] $lvl $tag: $message$d';
  }
}

/// Diagnostic logging service.
///
/// Keeps an in-memory ring buffer for the live debug view and optionally
/// flushes batches to Firestore for remote debugging.
class DiagnosticService {
  DiagnosticService._();
  static final instance = DiagnosticService._();

  // ─── In-memory ring buffer ───
  static const _maxEntries = 500;
  final _entries = Queue<DiagEntry>();
  final _controller = StreamController<DiagEntry>.broadcast();

  /// Live stream of new log entries (for the debug UI).
  Stream<DiagEntry> get stream => _controller.stream;

  /// All buffered entries (newest last).
  List<DiagEntry> get entries => _entries.toList();

  // ─── Firestore batch upload ───
  String? _userId;
  Timer? _flushTimer;
  final _pending = <DiagEntry>[];
  bool _firestoreEnabled = false;
  bool _cloudUploadEnabled = true;

  /// Whether dev logs are uploaded to Firestore.
  bool get cloudUploadEnabled => _cloudUploadEnabled;

  /// Load the cloud-upload preference from SharedPreferences.
  Future<void> loadCloudUploadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _cloudUploadEnabled =
        prefs.getBool(AppConstants.devLogsCloudUploadKey) ?? true;
  }

  /// Toggle cloud upload on/off and persist the choice.
  Future<void> setCloudUploadEnabled(bool enabled) async {
    _cloudUploadEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.devLogsCloudUploadKey, enabled);
    if (!enabled) {
      _pending.clear();
    }
  }

  /// Call once after auth to enable Firestore uploads.
  void enableFirestore(String userId) {
    _userId = userId;
    _firestoreEnabled = true;
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _flush(),
    );
  }

  void disableFirestore() {
    _firestoreEnabled = false;
    _flushTimer?.cancel();
  }

  // ─── Logging methods ───

  void debug(String tag, String msg, [String? detail]) =>
      _log(DiagLevel.debug, tag, msg, detail);

  void info(String tag, String msg, [String? detail]) =>
      _log(DiagLevel.info, tag, msg, detail);

  void warn(String tag, String msg, [String? detail]) =>
      _log(DiagLevel.warn, tag, msg, detail);

  void error(String tag, String msg, [String? detail]) =>
      _log(DiagLevel.error, tag, msg, detail);

  void _log(DiagLevel level, String tag, String msg, String? detail) {
    final entry = DiagEntry(level: level, tag: tag, message: msg, detail: detail);
    _entries.add(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
    if (_firestoreEnabled && _cloudUploadEnabled) {
      _pending.add(entry);
    }
  }

  Future<void> _flush() async {
    if (_pending.isEmpty || _userId == null) return;
    final batch = List<DiagEntry>.from(_pending);
    _pending.clear();

    // Count entries by level for the summary
    int debugCount = 0, infoCount = 0, warnCount = 0, errorCount = 0;
    for (final e in batch) {
      switch (e.level) {
        case DiagLevel.debug: debugCount++;
        case DiagLevel.info: infoCount++;
        case DiagLevel.warn: warnCount++;
        case DiagLevel.error: errorCount++;
      }
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('devLogs')
          .doc();
      await docRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'entryCount': batch.length,
        'summary': {
          'debug': debugCount,
          'info': infoCount,
          'warn': warnCount,
          'error': errorCount,
        },
        'entries': batch.map((e) => e.toMap()).toList(),
      });
    } catch (e) {
      // Don't let logging failures crash the app, but re-queue the batch
      // so entries aren't silently lost.
      _pending.insertAll(0, batch);
      // Cap pending to prevent unbounded growth if Firestore is down
      if (_pending.length > _maxEntries) {
        _pending.removeRange(0, _pending.length - _maxEntries);
      }
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _controller.close();
  }
}

/// Shorthand accessor.
DiagnosticService get diag => DiagnosticService.instance;
