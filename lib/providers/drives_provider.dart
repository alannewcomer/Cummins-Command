import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drive_session.dart';
import '../models/drive_route.dart';
import '../config/constants.dart';
import 'vehicle_provider.dart';

/// Stream of drives for the active vehicle, ordered by start time descending.
final drivesStreamProvider = StreamProvider<List<DriveSession>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.drivesSubcollection)
      .orderBy('startTime', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(DriveSession.fromFirestore).toList());
});

/// Single drive detail with real-time updates.
final driveDetailProvider =
    StreamProvider.family<DriveSession?, String>((ref, driveId) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.drivesSubcollection)
      .doc(driveId)
      .snapshots()
      .map((snap) => snap.exists ? DriveSession.fromFirestore(snap) : null);
});

/// Stream of routes for the active vehicle, ordered by lastDriveDate desc.
final routesStreamProvider = StreamProvider<List<DriveRoute>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.routesSubcollection)
      .orderBy('lastDriveDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(DriveRoute.fromFirestore).toList());
});

/// Single route detail with real-time updates.
final routeDetailProvider =
    StreamProvider.family<DriveRoute?, String>((ref, routeId) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.routesSubcollection)
      .doc(routeId)
      .snapshots()
      .map((snap) => snap.exists ? DriveRoute.fromFirestore(snap) : null);
});

/// Drives filtered by routeId, ordered by startTime desc.
final routeDrivesProvider =
    StreamProvider.family<List<DriveSession>, String>((ref, routeId) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.drivesSubcollection)
      .where('routeId', isEqualTo: routeId)
      .orderBy('startTime', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(DriveSession.fromFirestore).toList());
});

/// Drive recording state.
class RecordingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setRecording(bool value) => state = value;
}

final isRecordingProvider =
    NotifierProvider<RecordingNotifier, bool>(RecordingNotifier.new);

/// Current active drive ID.
class ActiveDriveIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setDriveId(String? id) => state = id;
}

final activeDriveIdProvider =
    NotifierProvider<ActiveDriveIdNotifier, String?>(ActiveDriveIdNotifier.new);
