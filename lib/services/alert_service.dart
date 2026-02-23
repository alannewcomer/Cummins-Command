import 'dart:async';

import 'package:myapp/config/pid_config.dart';
import 'package:myapp/config/thresholds.dart';
import 'package:myapp/models/alert.dart';

/// Alert threshold monitoring service.
///
/// Evaluates live OBD data against configured thresholds and fires alerts
/// when thresholds are crossed. Tracks active alerts to avoid duplicate
/// notifications for the same parameter, and supports alert dismissal.
///
/// Features:
/// - Evaluates every parameter against DefaultThresholds
/// - De-duplicates: only one active alert per parameter
/// - Upgrades: a warning alert is replaced by critical if severity increases
/// - Clears: alerts auto-clear when the value returns to normal
/// - Dismissal: user can dismiss alerts (they won't re-fire until cleared and re-triggered)
/// - Alert stream for UI consumption
///
/// Designed for use with Riverpod providers.
class AlertService {
  // Active alerts keyed by PID id
  final Map<String, Alert> _activeAlerts = {};

  // Set of dismissed alert PIDs (won't re-fire until value returns to normal)
  final Set<String> _dismissedPids = {};

  // Alert event stream
  final StreamController<AlertEvent> _eventController =
      StreamController<AlertEvent>.broadcast();

  // Counter for generating unique alert IDs
  int _alertCounter = 0;

  bool _disposed = false;

  // ─── Public getters ───

  /// All currently active (non-dismissed) alerts.
  List<Alert> get activeAlerts =>
      _activeAlerts.values.where((a) => !a.isDismissed).toList()
        ..sort((a, b) {
          // Critical first, then by timestamp (newest first)
          if (a.isCritical && !b.isCritical) return -1;
          if (!a.isCritical && b.isCritical) return 1;
          return b.timestamp.compareTo(a.timestamp);
        });

  /// All alerts including dismissed ones.
  List<Alert> get allAlerts => _activeAlerts.values.toList();

  /// Number of active, non-dismissed alerts.
  int get activeCount =>
      _activeAlerts.values.where((a) => !a.isDismissed).length;

  /// Whether there are any critical alerts active.
  bool get hasCritical =>
      _activeAlerts.values.any((a) => a.isCritical && !a.isDismissed);

  /// Whether there are any warning alerts active.
  bool get hasWarning =>
      _activeAlerts.values.any((a) => a.isWarning && !a.isDismissed);

  /// Stream of alert events (new, upgraded, cleared, dismissed).
  Stream<AlertEvent> get eventStream => _eventController.stream;

  // ─── Evaluation ───

  /// Evaluate a live data snapshot against all configured thresholds.
  ///
  /// Returns a list of newly triggered or upgraded alerts from this
  /// evaluation cycle. Also clears alerts for parameters that have
  /// returned to normal.
  List<Alert> evaluate(Map<String, double> liveData) {
    if (_disposed) return [];

    final newAlerts = <Alert>[];

    // Check each parameter that has a threshold defined
    for (final entry in liveData.entries) {
      final pidId = entry.key;
      final value = entry.value;

      final state = DefaultThresholds.evaluate(pidId, value);

      if (state == ThresholdState.normal) {
        _handleNormalValue(pidId);
        continue;
      }

      final alert = _handleThresholdCrossed(pidId, value, state);
      if (alert != null) {
        newAlerts.add(alert);
      }
    }

    return newAlerts;
  }

  // ─── Alert Management ───

  /// Dismiss an alert by its ID.
  ///
  /// The alert remains tracked internally but is marked as dismissed
  /// and won't appear in [activeAlerts]. It won't re-fire until the
  /// value returns to normal and crosses the threshold again.
  void dismissAlert(String alertId) {
    final entry = _activeAlerts.entries
        .where((e) => e.value.id == alertId)
        .firstOrNull;

    if (entry != null) {
      _activeAlerts[entry.key] = entry.value.copyWith(isDismissed: true);
      _dismissedPids.add(entry.key);

      if (!_eventController.isClosed) {
        _eventController.add(AlertEvent(
          type: AlertEventType.dismissed,
          alert: _activeAlerts[entry.key]!,
        ));
      }
    }
  }

  /// Dismiss all active alerts.
  void dismissAll() {
    for (final pidId in _activeAlerts.keys.toList()) {
      final alert = _activeAlerts[pidId]!;
      if (!alert.isDismissed) {
        _activeAlerts[pidId] = alert.copyWith(isDismissed: true);
        _dismissedPids.add(pidId);
      }
    }
  }

  /// Clear all alerts and dismissed state. Used when disconnecting.
  void clearAll() {
    _activeAlerts.clear();
    _dismissedPids.clear();
  }

  // ─── Lifecycle ───

  void dispose() {
    _disposed = true;
    _eventController.close();
  }

  // ─── Private ───

  void _handleNormalValue(String pidId) {
    if (_activeAlerts.containsKey(pidId)) {
      final cleared = _activeAlerts.remove(pidId)!;
      _dismissedPids.remove(pidId);

      if (!_eventController.isClosed) {
        _eventController.add(AlertEvent(
          type: AlertEventType.cleared,
          alert: cleared,
        ));
      }
    }
  }

  Alert? _handleThresholdCrossed(
    String pidId,
    double value,
    ThresholdState state,
  ) {
    final severity = state == ThresholdState.critical ? 'critical' : 'warning';
    final threshold = DefaultThresholds.forPid(pidId);

    // Get PID definition for human-readable name and AI context
    final pidDef = PidRegistry.get(pidId);
    final paramName = pidDef?.name ?? pidId;
    final aiContext = pidDef?.aiContext;

    // Build alert message
    final message = _buildAlertMessage(pidId, paramName, value, state, threshold);

    // Check if we already have an active alert for this parameter
    final existing = _activeAlerts[pidId];

    if (existing != null) {
      // Check if we need to upgrade severity
      if (existing.severity == 'warning' && severity == 'critical') {
        // Upgrade: replace with critical alert
        final upgraded = Alert(
          id: existing.id, // Keep same ID
          pidId: pidId,
          paramName: paramName,
          value: value,
          severity: severity,
          message: message,
          aiContext: aiContext,
          timestamp: DateTime.now(),
          isDismissed: false, // Un-dismiss on upgrade
        );
        _activeAlerts[pidId] = upgraded;
        _dismissedPids.remove(pidId); // Un-dismiss on severity upgrade

        if (!_eventController.isClosed) {
          _eventController.add(AlertEvent(
            type: AlertEventType.upgraded,
            alert: upgraded,
          ));
        }
        return upgraded;
      }

      // Same or lower severity — update value but don't re-alert
      _activeAlerts[pidId] = existing.copyWith(value: value);
      return null;
    }

    // No existing alert — check if this PID was dismissed
    if (_dismissedPids.contains(pidId)) {
      return null; // Still dismissed, don't re-fire
    }

    // New alert
    _alertCounter++;
    final alert = Alert(
      id: 'alert_${pidId}_$_alertCounter',
      pidId: pidId,
      paramName: paramName,
      value: value,
      severity: severity,
      message: message,
      aiContext: aiContext,
      timestamp: DateTime.now(),
    );

    _activeAlerts[pidId] = alert;

    if (!_eventController.isClosed) {
      _eventController.add(AlertEvent(
        type: AlertEventType.triggered,
        alert: alert,
      ));
    }

    return alert;
  }

  String _buildAlertMessage(
    String pidId,
    String paramName,
    double value,
    ThresholdState state,
    ThresholdLevel? threshold,
  ) {
    if (threshold == null) {
      return '$paramName at ${value.toStringAsFixed(1)}';
    }

    final severity = state == ThresholdState.critical ? 'CRITICAL' : 'WARNING';

    // Determine if high or low
    if (threshold.critHigh != null && value >= threshold.critHigh!) {
      return '$severity: $paramName is ${value.toStringAsFixed(1)} '
          '(limit: ${threshold.critHigh!.toStringAsFixed(1)})';
    }
    if (threshold.warnHigh != null && value >= threshold.warnHigh!) {
      return '$severity: $paramName is ${value.toStringAsFixed(1)} '
          '(limit: ${threshold.warnHigh!.toStringAsFixed(1)})';
    }
    if (threshold.critLow != null && value <= threshold.critLow!) {
      return '$severity: $paramName is ${value.toStringAsFixed(1)} '
          '(minimum: ${threshold.critLow!.toStringAsFixed(1)})';
    }
    if (threshold.warnLow != null && value <= threshold.warnLow!) {
      return '$severity: $paramName is ${value.toStringAsFixed(1)} '
          '(minimum: ${threshold.warnLow!.toStringAsFixed(1)})';
    }

    return '$severity: $paramName at ${value.toStringAsFixed(1)}';
  }
}

// ─── Alert Events ───

enum AlertEventType {
  triggered,
  upgraded,
  cleared,
  dismissed,
}

/// An event emitted by the AlertService when an alert state changes.
class AlertEvent {
  final AlertEventType type;
  final Alert alert;

  const AlertEvent({required this.type, required this.alert});

  @override
  String toString() => 'AlertEvent(${type.name}: ${alert.pidId})';
}
