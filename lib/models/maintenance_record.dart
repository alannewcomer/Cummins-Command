import 'package:cloud_firestore/cloud_firestore.dart';

/// A maintenance log entry for a vehicle — manual or AI-predicted.
class MaintenanceRecord {
  final String id;
  final String vehicleId;
  final String category;
  final String title;
  final String? description;
  final DateTime date;
  final double? cost;
  final double? odometerReading;
  final bool isCompleted;
  final String? aiPredictionId;
  final DateTime? nextDueDate;
  final double? nextDueMileage;
  final String? serviceTypeId;
  final String? source; // 'manual', 'scheduled', 'checklist', 'seasonal'
  final String? serviceProvider; // 'DIY', 'Dealer', 'Shop'
  final List<String> partsUsed;

  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.category,
    required this.title,
    this.description,
    required this.date,
    this.cost,
    this.odometerReading,
    this.isCompleted = false,
    this.aiPredictionId,
    this.nextDueDate,
    this.nextDueMileage,
    this.serviceTypeId,
    this.source,
    this.serviceProvider,
    this.partsUsed = const [],
  });

  bool get isOverdue =>
      nextDueDate != null && nextDueDate!.isBefore(DateTime.now()) && !isCompleted;

  bool get isAiPredicted => aiPredictionId != null;

  MaintenanceRecord copyWith({
    String? id,
    String? vehicleId,
    String? category,
    String? title,
    String? description,
    DateTime? date,
    double? cost,
    double? odometerReading,
    bool? isCompleted,
    String? aiPredictionId,
    DateTime? nextDueDate,
    double? nextDueMileage,
    String? serviceTypeId,
    String? source,
    String? serviceProvider,
    List<String>? partsUsed,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      cost: cost ?? this.cost,
      odometerReading: odometerReading ?? this.odometerReading,
      isCompleted: isCompleted ?? this.isCompleted,
      aiPredictionId: aiPredictionId ?? this.aiPredictionId,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      nextDueMileage: nextDueMileage ?? this.nextDueMileage,
      serviceTypeId: serviceTypeId ?? this.serviceTypeId,
      source: source ?? this.source,
      serviceProvider: serviceProvider ?? this.serviceProvider,
      partsUsed: partsUsed ?? this.partsUsed,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vehicleId': vehicleId,
      'category': category,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'cost': cost,
      'odometerReading': odometerReading,
      'isCompleted': isCompleted,
      'aiPredictionId': aiPredictionId,
      'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
      'nextDueMileage': nextDueMileage,
      'serviceTypeId': serviceTypeId,
      'source': source,
      'serviceProvider': serviceProvider,
      'partsUsed': partsUsed.isEmpty ? null : partsUsed,
    };
  }

  factory MaintenanceRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return MaintenanceRecord(
      id: doc.id,
      vehicleId: d['vehicleId'] as String? ?? '',
      category: d['category'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cost: (d['cost'] as num?)?.toDouble(),
      odometerReading: (d['odometerReading'] as num?)?.toDouble(),
      isCompleted: d['isCompleted'] as bool? ?? false,
      aiPredictionId: d['aiPredictionId'] as String?,
      nextDueDate: (d['nextDueDate'] as Timestamp?)?.toDate(),
      nextDueMileage: (d['nextDueMileage'] as num?)?.toDouble(),
      serviceTypeId: d['serviceTypeId'] as String?,
      source: d['source'] as String?,
      serviceProvider: d['serviceProvider'] as String?,
      partsUsed: (d['partsUsed'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
