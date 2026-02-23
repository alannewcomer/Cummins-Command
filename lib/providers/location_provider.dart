import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';

/// Provides a singleton [LocationService] for GPS tracking during drives.
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});
