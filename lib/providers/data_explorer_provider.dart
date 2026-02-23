import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../config/pid_config.dart';
import '../services/timeseries_file.dart';
import 'vehicle_provider.dart';

/// Selected parameters for the data explorer.
class SelectedParamsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void toggle(String paramId) {
    if (state.contains(paramId)) {
      state = state.where((p) => p != paramId).toList();
    } else if (state.length < AppConstants.maxOverlayParams) {
      state = [...state, paramId];
    }
  }

  void clear() => state = [];

  void setParams(List<String> params) =>
      state = params.take(AppConstants.maxOverlayParams).toList();
}

final selectedParamsProvider =
    NotifierProvider<SelectedParamsNotifier, List<String>>(
        SelectedParamsNotifier.new);

/// Time range for data explorer.
enum TimeRangePreset {
  thisDrive,
  lastDrive,
  days7,
  days30,
  days90,
  year1,
  allTime,
  custom,
}

class TimeRange {
  final TimeRangePreset preset;
  final DateTime start;
  final DateTime end;

  TimeRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  factory TimeRange.fromPreset(TimeRangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case TimeRangePreset.thisDrive:
      case TimeRangePreset.lastDrive:
        return TimeRange(preset: preset, start: now.subtract(const Duration(hours: 1)), end: now);
      case TimeRangePreset.days7:
        return TimeRange(preset: preset, start: now.subtract(const Duration(days: 7)), end: now);
      case TimeRangePreset.days30:
        return TimeRange(preset: preset, start: now.subtract(const Duration(days: 30)), end: now);
      case TimeRangePreset.days90:
        return TimeRange(preset: preset, start: now.subtract(const Duration(days: 90)), end: now);
      case TimeRangePreset.year1:
        return TimeRange(preset: preset, start: now.subtract(const Duration(days: 365)), end: now);
      case TimeRangePreset.allTime:
        return TimeRange(preset: preset, start: DateTime(2020), end: now);
      case TimeRangePreset.custom:
        return TimeRange(preset: preset, start: now.subtract(const Duration(days: 7)), end: now);
    }
  }
}

class TimeRangeNotifier extends Notifier<TimeRange> {
  @override
  TimeRange build() => TimeRange.fromPreset(TimeRangePreset.days7);

  void setPreset(TimeRangePreset preset) =>
      state = TimeRange.fromPreset(preset);

  void setCustomRange(DateTime start, DateTime end) =>
      state = TimeRange(preset: TimeRangePreset.custom, start: start, end: end);
}

final timeRangeProvider =
    NotifierProvider<TimeRangeNotifier, TimeRange>(TimeRangeNotifier.new);

/// Fetch datapoints for selected parameters and time range.
/// Reads from Firebase Storage for new drives, Firestore for legacy.
final explorerDataProvider =
    FutureProvider<Map<String, List<MapEntry<DateTime, double>>>>((ref) async {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  final selectedParams = ref.watch(selectedParamsProvider);
  final timeRange = ref.watch(timeRangeProvider);

  if (uid == null || vehicle == null || selectedParams.isEmpty) return {};

  final db = FirebaseFirestore.instance;
  final result = <String, List<MapEntry<DateTime, double>>>{};

  // Fetch drives in the time range
  final drivesSnap = await db
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicle.id)
      .collection(AppConstants.drivesSubcollection)
      .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(timeRange.start))
      .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(timeRange.end))
      .get();

  // Download timeseries files in parallel for new drives
  final futures = <Future<void>>[];

  for (final driveDoc in drivesSnap.docs) {
    final data = driveDoc.data();
    final timeseriesPath = data['timeseriesPath'] as String?;
    final uploaded = data['timeseriesUploaded'] as bool? ?? false;

    if (timeseriesPath != null && uploaded) {
      // New drive: download from Firebase Storage
      futures.add(_loadFromStorage(timeseriesPath, selectedParams, result));
    } else {
      // Legacy drive: read from Firestore subcollection
      futures.add(_loadFromFirestore(driveDoc.reference, selectedParams, result));
    }
  }

  await Future.wait(futures);

  return result;
});

/// Load datapoints from a Firebase Storage timeseries file.
Future<void> _loadFromStorage(
  String storagePath,
  List<String> selectedParams,
  Map<String, List<MapEntry<DateTime, double>>> result,
) async {
  final points = await TimeseriesReader.fromStorage(storagePath);
  for (final dp in points) {
    final ts = DateTime.fromMillisecondsSinceEpoch(dp.timestamp);
    final dpMap = dp.toFirestore(); // Reuse existing serialization
    for (final param in selectedParams) {
      final val = (dpMap[param] as num?)?.toDouble();
      if (val != null) {
        result.putIfAbsent(param, () => []).add(MapEntry(ts, val));
      }
    }
  }
}

/// Load datapoints from a legacy Firestore subcollection.
Future<void> _loadFromFirestore(
  DocumentReference driveRef,
  List<String> selectedParams,
  Map<String, List<MapEntry<DateTime, double>>> result,
) async {
  final datapointsSnap = await driveRef
      .collection(AppConstants.datapointsSubcollection)
      .orderBy('timestamp')
      .get();

  for (final dpDoc in datapointsSnap.docs) {
    final data = dpDoc.data();
    final ts = DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] as num?)?.toInt() ?? 0);

    for (final param in selectedParams) {
      final val = (data[param] as num?)?.toDouble();
      if (val != null) {
        result.putIfAbsent(param, () => []).add(MapEntry(ts, val));
      }
    }
  }
}

/// Searchable PID list for parameter picker.
class PidSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
}

final pidSearchProvider =
    NotifierProvider<PidSearchNotifier, String>(PidSearchNotifier.new);

final filteredPidsProvider = Provider<List<PidDefinition>>((ref) {
  final query = ref.watch(pidSearchProvider).toLowerCase();
  final allPids = PidRegistry.allSorted;
  if (query.isEmpty) return allPids;
  return allPids
      .where((p) =>
          p.name.toLowerCase().contains(query) ||
          p.shortName.toLowerCase().contains(query) ||
          p.id.toLowerCase().contains(query))
      .toList();
});
