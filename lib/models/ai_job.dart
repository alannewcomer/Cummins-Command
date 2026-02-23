import 'package:cloud_firestore/cloud_firestore.dart';

/// An AI processing job dispatched to a Cloud Function.
/// Written by the app, processed server-side, result flows back via snapshot listener.
class AiJob {
  final String id;
  final String type; // drive_analysis, range_analysis, predictive_maintenance, custom_query, dashboard_generation
  final String vehicleId;
  final Map<String, dynamic> parameters;
  final String status; // queued, processing, complete, failed
  final double progress; // 0.0 - 1.0
  final String? currentStep;
  final Map<String, dynamic>? result;
  final String? model;
  final int? tokensUsed;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const AiJob({
    required this.id,
    required this.type,
    required this.vehicleId,
    this.parameters = const {},
    this.status = 'queued',
    this.progress = 0.0,
    this.currentStep,
    this.result,
    this.model,
    this.tokensUsed,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  bool get isQueued => status == 'queued';
  bool get isProcessing => status == 'processing';
  bool get isComplete => status == 'complete';
  bool get isFailed => status == 'failed';
  bool get isFinished => isComplete || isFailed;

  AiJob copyWith({
    String? id,
    String? type,
    String? vehicleId,
    Map<String, dynamic>? parameters,
    String? status,
    double? progress,
    String? currentStep,
    Map<String, dynamic>? result,
    String? model,
    int? tokensUsed,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return AiJob(
      id: id ?? this.id,
      type: type ?? this.type,
      vehicleId: vehicleId ?? this.vehicleId,
      parameters: parameters ?? this.parameters,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      result: result ?? this.result,
      model: model ?? this.model,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'vehicleId': vehicleId,
      'parameters': parameters,
      'status': status,
      'progress': progress,
      'currentStep': currentStep,
      'result': result,
      'model': model,
      'tokensUsed': tokensUsed,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory AiJob.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AiJob(
      id: doc.id,
      type: d['type'] as String? ?? '',
      vehicleId: d['vehicleId'] as String? ?? '',
      parameters: (d['parameters'] as Map<String, dynamic>?) ?? {},
      status: d['status'] as String? ?? 'queued',
      progress: (d['progress'] as num?)?.toDouble() ?? 0.0,
      currentStep: d['currentStep'] as String?,
      result: d['result'] as Map<String, dynamic>?,
      model: d['model'] as String?,
      tokensUsed: (d['tokensUsed'] as num?)?.toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
