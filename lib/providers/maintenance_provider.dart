import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance_record.dart';
import '../config/constants.dart';
import 'vehicle_provider.dart';

/// Stream of maintenance records for the active vehicle.
final maintenanceStreamProvider =
    StreamProvider<List<MaintenanceRecord>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.maintenanceSubcollection)
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map(MaintenanceRecord.fromFirestore).toList());
});

/// Maintenance CRUD operations.
final maintenanceRepositoryProvider =
    Provider<MaintenanceRepository>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  return MaintenanceRepository(uid: uid, vehicleId: vehicle?.id);
});

class MaintenanceRepository {
  final String? uid;
  final String? vehicleId;
  final _db = FirebaseFirestore.instance;

  MaintenanceRepository({this.uid, this.vehicleId});

  CollectionReference? _ref() {
    if (uid == null || vehicleId == null) return null;
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(vehicleId)
        .collection(AppConstants.maintenanceSubcollection);
  }

  Future<String?> add(MaintenanceRecord record) async {
    final ref = _ref();
    if (ref == null) return null;
    final doc = await ref.add(record.toFirestore());
    return doc.id;
  }

  Future<void> update(MaintenanceRecord record) async {
    await _ref()?.doc(record.id).update(record.toFirestore());
  }

  Future<void> delete(String recordId) async {
    await _ref()?.doc(recordId).delete();
  }

  Future<void> markComplete(String recordId) async {
    await _ref()?.doc(recordId).update({'isCompleted': true});
  }
}
