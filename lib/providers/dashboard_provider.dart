import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_config.dart';
import '../config/constants.dart';
import '../config/dashboard_templates.dart';
import 'vehicle_provider.dart';

/// Stream of dashboards for the active vehicle.
final dashboardsStreamProvider = StreamProvider<List<DashboardConfig>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.dashboardsSubcollection)
      .snapshots()
      .map((snap) => snap.docs.map(DashboardConfig.fromFirestore).toList());
});

/// Currently active dashboard index.
class ActiveDashboardIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final activeDashboardIndexProvider =
    NotifierProvider<ActiveDashboardIndexNotifier, int>(
        ActiveDashboardIndexNotifier.new);

/// Get the active dashboard config.
///
/// Priority: Firestore dashboards (if any) → template library by index.
/// The index from [activeDashboardIndexProvider] is used in BOTH cases, so
/// tapping a template in the switcher actually changes what is shown.
final activeDashboardProvider = Provider<Map<String, dynamic>>((ref) {
  final dashboards = ref.watch(dashboardsStreamProvider).when(
    data: (data) => data,
    loading: () => <DashboardConfig>[],
    error: (_, __) => <DashboardConfig>[],
  );
  final index = ref.watch(activeDashboardIndexProvider);

  // Prefer user-saved Firestore dashboards when available
  if (dashboards.isNotEmpty && index < dashboards.length) {
    return dashboards[index].toFirestore();
  }

  // Fall back to the template library — index selects the template
  final templates = DashboardTemplates.all;
  final clampedIndex = index.clamp(0, templates.length - 1);
  return templates[clampedIndex];
});

/// Dashboard template library (static templates).
final dashboardTemplatesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return DashboardTemplates.all;
});
