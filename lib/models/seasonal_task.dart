import 'package:cloud_firestore/cloud_firestore.dart';

/// A seasonal task completion marker.
/// Path: `/users/{uid}/vehicles/{vid}/seasonalTasks/{id}`
class SeasonalTask {
  final String id;
  final String vehicleId;
  final String seasonalGroupId;
  final String taskId;
  final int year;
  final String season;
  final DateTime? completedAt;
  final String? notes;

  const SeasonalTask({
    required this.id,
    required this.vehicleId,
    required this.seasonalGroupId,
    required this.taskId,
    required this.year,
    required this.season,
    this.completedAt,
    this.notes,
  });

  bool get isCompleted => completedAt != null;

  SeasonalTask copyWith({
    String? id,
    String? vehicleId,
    String? seasonalGroupId,
    String? taskId,
    int? year,
    String? season,
    DateTime? completedAt,
    String? notes,
  }) {
    return SeasonalTask(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      seasonalGroupId: seasonalGroupId ?? this.seasonalGroupId,
      taskId: taskId ?? this.taskId,
      year: year ?? this.year,
      season: season ?? this.season,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vehicleId': vehicleId,
      'seasonalGroupId': seasonalGroupId,
      'taskId': taskId,
      'year': year,
      'season': season,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
    };
  }

  factory SeasonalTask.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return SeasonalTask(
      id: doc.id,
      vehicleId: d['vehicleId'] as String? ?? '',
      seasonalGroupId: d['seasonalGroupId'] as String? ?? '',
      taskId: d['taskId'] as String? ?? '',
      year: (d['year'] as num?)?.toInt() ?? DateTime.now().year,
      season: d['season'] as String? ?? '',
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      notes: d['notes'] as String?,
    );
  }
}
