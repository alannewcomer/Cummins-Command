import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/datapoint.dart';
import '../models/drive_stats.dart';
import '../services/timeseries_file.dart';
import 'vehicle_provider.dart';

/// Loads all datapoints for a drive and computes [DriveStats].
/// Reads from Firebase Storage if timeseriesPath exists (new drives),
/// falls back to Firestore subcollection for legacy drives.
/// Cached by Riverpod — only computed once per drive per session.
final driveStatsProvider =
    FutureProvider.family<DriveStats, String>((ref, driveId) async {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const DriveStats();

  final driveDoc = await FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.drivesSubcollection)
      .doc(driveId)
      .get();

  final data = driveDoc.data();
  if (data == null) return const DriveStats();

  // New path: read from Firebase Storage timeseries file
  final timeseriesPath = data['timeseriesPath'] as String?;
  if (timeseriesPath != null && (data['timeseriesUploaded'] as bool? ?? false)) {
    final points = await TimeseriesReader.fromStorage(timeseriesPath);
    return computeDriveStats(points);
  }

  // Legacy fallback: read from Firestore datapoints subcollection
  final snap = await driveDoc.reference
      .collection(AppConstants.datapointsSubcollection)
      .orderBy('timestamp')
      .get();

  final points = snap.docs.map(DataPoint.fromFirestore).toList();
  return computeDriveStats(points);
});
