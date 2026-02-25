import 'package:cloud_firestore/cloud_firestore.dart';

/// A timestamped checklist run.
/// Path: `/users/{uid}/vehicles/{vid}/checklistSessions/{id}`
class ChecklistSession {
  final String id;
  final String vehicleId;
  final String checklistTypeId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double? odometerReading;
  final Map<String, bool> itemStates;
  final String? notes;

  const ChecklistSession({
    required this.id,
    required this.vehicleId,
    required this.checklistTypeId,
    required this.startedAt,
    this.completedAt,
    this.odometerReading,
    this.itemStates = const {},
    this.notes,
  });

  bool get isComplete =>
      completedAt != null ||
      (itemStates.isNotEmpty && itemStates.values.every((v) => v));

  int get checkedCount => itemStates.values.where((v) => v).length;

  int get totalCount => itemStates.length;

  ChecklistSession copyWith({
    String? id,
    String? vehicleId,
    String? checklistTypeId,
    DateTime? startedAt,
    DateTime? completedAt,
    double? odometerReading,
    Map<String, bool>? itemStates,
    String? notes,
  }) {
    return ChecklistSession(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      checklistTypeId: checklistTypeId ?? this.checklistTypeId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      odometerReading: odometerReading ?? this.odometerReading,
      itemStates: itemStates ?? this.itemStates,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vehicleId': vehicleId,
      'checklistTypeId': checklistTypeId,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'odometerReading': odometerReading,
      'itemStates': itemStates,
      'notes': notes,
    };
  }

  factory ChecklistSession.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawStates = d['itemStates'] as Map<String, dynamic>? ?? {};
    return ChecklistSession(
      id: doc.id,
      vehicleId: d['vehicleId'] as String? ?? '',
      checklistTypeId: d['checklistTypeId'] as String? ?? '',
      startedAt: (d['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      odometerReading: (d['odometerReading'] as num?)?.toDouble(),
      itemStates: rawStates.map((k, v) => MapEntry(k, v as bool? ?? false)),
      notes: d['notes'] as String?,
    );
  }
}
