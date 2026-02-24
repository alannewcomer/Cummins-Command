import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vehicle.dart';
import '../config/constants.dart';
import 'auth_provider.dart';

/// Current authenticated user ID — reactive to auth state changes.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

/// Stream of all vehicles for the current user.
final vehiclesStreamProvider = StreamProvider<List<Vehicle>>((ref) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .snapshots()
      .map((snap) => snap.docs.map(Vehicle.fromFirestore).toList());
});

/// The currently active vehicle.
final activeVehicleProvider = Provider<Vehicle?>((ref) {
  final vehicles = ref.watch(vehiclesStreamProvider).value;
  if (vehicles == null || vehicles.isEmpty) return null;
  return vehicles.firstWhere(
    (v) => v.isActive,
    orElse: () => vehicles.first,
  );
});

/// Vehicle CRUD operations.
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepository();
});

class VehicleRepository {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference _vehiclesRef() {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(_uid)
        .collection(AppConstants.vehiclesSubcollection);
  }

  Future<String> addVehicle(Vehicle vehicle) async {
    if (_uid == null) throw Exception('Not authenticated');
    final ref = await _vehiclesRef().add(vehicle.toFirestore());
    return ref.id;
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await _vehiclesRef().doc(vehicle.id).update(vehicle.toFirestore());
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _vehiclesRef().doc(vehicleId).delete();
  }

  Future<void> setActiveVehicle(String vehicleId) async {
    if (_uid == null) return;
    final batch = _db.batch();
    final snap = await _vehiclesRef().get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isActive': doc.id == vehicleId});
    }
    await batch.commit();
  }
}
