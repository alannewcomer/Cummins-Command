import 'package:cloud_firestore/cloud_firestore.dart';

/// A real-time or historical alert triggered by a PID threshold breach.
class Alert {
  final String id;
  final String pidId;
  final String paramName;
  final double value;
  final String severity; // warning, critical
  final String message;
  final String? aiContext;
  final DateTime timestamp;
  final bool isDismissed;

  const Alert({
    required this.id,
    required this.pidId,
    required this.paramName,
    required this.value,
    required this.severity,
    required this.message,
    this.aiContext,
    required this.timestamp,
    this.isDismissed = false,
  });

  bool get isWarning => severity == 'warning';
  bool get isCritical => severity == 'critical';

  Alert copyWith({
    String? id,
    String? pidId,
    String? paramName,
    double? value,
    String? severity,
    String? message,
    String? aiContext,
    DateTime? timestamp,
    bool? isDismissed,
  }) {
    return Alert(
      id: id ?? this.id,
      pidId: pidId ?? this.pidId,
      paramName: paramName ?? this.paramName,
      value: value ?? this.value,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      aiContext: aiContext ?? this.aiContext,
      timestamp: timestamp ?? this.timestamp,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pidId': pidId,
      'paramName': paramName,
      'value': value,
      'severity': severity,
      'message': message,
      'aiContext': aiContext,
      'timestamp': Timestamp.fromDate(timestamp),
      'isDismissed': isDismissed,
    };
  }

  factory Alert.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Alert(
      id: doc.id,
      pidId: d['pidId'] as String? ?? '',
      paramName: d['paramName'] as String? ?? '',
      value: (d['value'] as num?)?.toDouble() ?? 0.0,
      severity: d['severity'] as String? ?? 'warning',
      message: d['message'] as String? ?? '',
      aiContext: d['aiContext'] as String?,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDismissed: d['isDismissed'] as bool? ?? false,
    );
  }
}
