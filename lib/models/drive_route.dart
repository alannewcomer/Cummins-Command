import 'package:cloud_firestore/cloud_firestore.dart';

class DriveRoute {
  final String id;
  final String vehicleId;
  final String name;
  final String startGeohash;
  final String endGeohash;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final int driveCount;
  final double? avgMPG;
  final double? avgDuration;
  final double? avgMaxEGT;
  final double? avgMaxBoost;
  final double? avgMaxTransTemp;
  final String? bestDriveId;
  final String? worstDriveId;
  final double? bestMPG;
  final double? worstMPG;
  final DateTime? lastDriveDate;
  final String? aiRouteInsights;
  final DateTime? createdAt;

  const DriveRoute({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.startGeohash,
    required this.endGeohash,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.driveCount = 0,
    this.avgMPG,
    this.avgDuration,
    this.avgMaxEGT,
    this.avgMaxBoost,
    this.avgMaxTransTemp,
    this.bestDriveId,
    this.worstDriveId,
    this.bestMPG,
    this.worstMPG,
    this.lastDriveDate,
    this.aiRouteInsights,
    this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'vehicleId': vehicleId,
      'name': name,
      'startGeohash': startGeohash,
      'endGeohash': endGeohash,
      'startLat': startLat,
      'startLng': startLng,
      'endLat': endLat,
      'endLng': endLng,
      'driveCount': driveCount,
      'avgMPG': avgMPG,
      'avgDuration': avgDuration,
      'avgMaxEGT': avgMaxEGT,
      'avgMaxBoost': avgMaxBoost,
      'avgMaxTransTemp': avgMaxTransTemp,
      'bestDriveId': bestDriveId,
      'worstDriveId': worstDriveId,
      'bestMPG': bestMPG,
      'worstMPG': worstMPG,
      'lastDriveDate': lastDriveDate != null
          ? Timestamp.fromDate(lastDriveDate!)
          : null,
      'aiRouteInsights': aiRouteInsights,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory DriveRoute.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DriveRoute(
      id: doc.id,
      vehicleId: d['vehicleId'] as String? ?? '',
      name: d['name'] as String? ?? 'Unknown Route',
      startGeohash: d['startGeohash'] as String? ?? '',
      endGeohash: d['endGeohash'] as String? ?? '',
      startLat: (d['startLat'] as num?)?.toDouble(),
      startLng: (d['startLng'] as num?)?.toDouble(),
      endLat: (d['endLat'] as num?)?.toDouble(),
      endLng: (d['endLng'] as num?)?.toDouble(),
      driveCount: (d['driveCount'] as num?)?.toInt() ?? 0,
      avgMPG: (d['avgMPG'] as num?)?.toDouble(),
      avgDuration: (d['avgDuration'] as num?)?.toDouble(),
      avgMaxEGT: (d['avgMaxEGT'] as num?)?.toDouble(),
      avgMaxBoost: (d['avgMaxBoost'] as num?)?.toDouble(),
      avgMaxTransTemp: (d['avgMaxTransTemp'] as num?)?.toDouble(),
      bestDriveId: d['bestDriveId'] as String?,
      worstDriveId: d['worstDriveId'] as String?,
      bestMPG: (d['bestMPG'] as num?)?.toDouble(),
      worstMPG: (d['worstMPG'] as num?)?.toDouble(),
      lastDriveDate: (d['lastDriveDate'] as Timestamp?)?.toDate(),
      aiRouteInsights: d['aiRouteInsights'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
