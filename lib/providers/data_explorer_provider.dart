import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../config/constants.dart';
import '../config/pid_config.dart';
import '../models/datapoint.dart';
import '../services/timeseries_file.dart';
import 'ai_provider.dart';
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

  // Load timeseries files in parallel — prefer local files first
  final localDir = await getApplicationDocumentsDirectory();
  final futures = <Future<void>>[];

  for (final driveDoc in drivesSnap.docs) {
    final driveId = driveDoc.id;
    final data = driveDoc.data();
    final timeseriesPath = data['timeseriesPath'] as String?;
    final uploaded = data['timeseriesUploaded'] as bool? ?? false;

    // 1. Check for local timeseries file (recorded on this device)
    final localFile = File('${localDir.path}/timeseries_$driveId.json.gz');
    if (localFile.existsSync()) {
      futures.add(_loadFromLocalFile(localFile.path, selectedParams, result));
    } else if (timeseriesPath != null && uploaded) {
      // 2. Download from Firebase Storage (cached in temp)
      futures.add(_loadFromStorage(timeseriesPath, selectedParams, result));
    } else {
      // 3. Legacy: read from Firestore subcollection
      futures.add(_loadFromFirestore(driveDoc.reference, selectedParams, result));
    }
  }

  await Future.wait(futures);

  // Sort each parameter's data chronologically (drives load in parallel)
  for (final entries in result.values) {
    entries.sort((a, b) => a.key.compareTo(b.key));
  }

  return result;
});

/// Load datapoints from a local timeseries file on this device.
Future<void> _loadFromLocalFile(
  String filePath,
  List<String> selectedParams,
  Map<String, List<MapEntry<DateTime, double>>> result,
) async {
  final points = await TimeseriesReader.fromLocalFile(filePath);
  _extractParams(points, selectedParams, result);
}

/// Load datapoints from a Firebase Storage timeseries file.
Future<void> _loadFromStorage(
  String storagePath,
  List<String> selectedParams,
  Map<String, List<MapEntry<DateTime, double>>> result,
) async {
  final points = await TimeseriesReader.fromStorage(storagePath);
  _extractParams(points, selectedParams, result);
}

/// Extract selected parameters from a list of DataPoints into the result map.
void _extractParams(
  List<DataPoint> points,
  List<String> selectedParams,
  Map<String, List<MapEntry<DateTime, double>>> result,
) {
  for (final dp in points) {
    final ts = DateTime.fromMillisecondsSinceEpoch(dp.timestamp);
    final dpMap = dp.toFirestore();
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

// ─── Explorer AI Chat Providers ───

/// Chat history isolated to the Data Explorer AI sheet.
class ExplorerChatHistoryNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  void addUserMessage(String content) {
    state = [...state, ChatMessage(role: 'user', content: content)];
  }

  void addAiMessage(String content) {
    state = [...state, ChatMessage(role: 'ai', content: content)];
  }

  void clear() => state = [];
}

final explorerChatHistoryProvider =
    NotifierProvider<ExplorerChatHistoryNotifier, List<ChatMessage>>(
        ExplorerChatHistoryNotifier.new);

/// Whether the explorer AI chat is generating a response.
class ExplorerAiLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoading(bool value) => state = value;
}

final explorerAiLoadingProvider =
    NotifierProvider<ExplorerAiLoadingNotifier, bool>(
        ExplorerAiLoadingNotifier.new);

/// Build a data context map for the explorer AI chat.
///
/// Computes per-param stats (min, max, avg, median, stdDev, count) and
/// downsamples to ~50 points per param to keep token usage reasonable.
Map<String, dynamic> buildExplorerDataContext({
  required Map<String, List<MapEntry<DateTime, double>>> data,
  required List<String> selectedParams,
  required TimeRange timeRange,
}) {
  String presetLabel(TimeRangePreset preset) {
    switch (preset) {
      case TimeRangePreset.thisDrive: return 'This Drive';
      case TimeRangePreset.lastDrive: return 'Last Drive';
      case TimeRangePreset.days7: return '7D';
      case TimeRangePreset.days30: return '30D';
      case TimeRangePreset.days90: return '90D';
      case TimeRangePreset.year1: return '1Y';
      case TimeRangePreset.allTime: return 'All';
      case TimeRangePreset.custom: return 'Custom';
    }
  }

  final parameters = <String, dynamic>{};

  for (final paramId in selectedParams) {
    final points = data[paramId] ?? [];
    if (points.isEmpty) continue;

    final pid = PidRegistry.get(paramId);
    final values = points.map((e) => e.value).toList()..sort();
    final count = values.length;
    final min = values.first;
    final max = values.last;
    final sum = values.fold<double>(0, (s, v) => s + v);
    final avg = sum / count;

    // Median
    final median = count.isOdd
        ? values[count ~/ 2]
        : (values[count ~/ 2 - 1] + values[count ~/ 2]) / 2;

    // Standard deviation
    final variance = values.fold<double>(0, (s, v) => s + (v - avg) * (v - avg)) / count;
    final stdDev = math.sqrt(variance);

    // Downsample to ~50 evenly-spaced points
    const maxSamples = 50;
    final samples = <Map<String, dynamic>>[];
    if (points.length <= maxSamples) {
      for (final p in points) {
        samples.add({'t': p.key.toIso8601String(), 'v': double.parse(p.value.toStringAsFixed(1))});
      }
    } else {
      final step = points.length / maxSamples;
      for (var i = 0; i < maxSamples; i++) {
        final idx = (i * step).floor();
        final p = points[idx];
        samples.add({'t': p.key.toIso8601String(), 'v': double.parse(p.value.toStringAsFixed(1))});
      }
    }

    parameters[paramId] = {
      'name': pid?.name ?? paramId,
      'unit': pid?.unit ?? '',
      'stats': {
        'min': double.parse(min.toStringAsFixed(2)),
        'max': double.parse(max.toStringAsFixed(2)),
        'avg': double.parse(avg.toStringAsFixed(2)),
        'median': double.parse(median.toStringAsFixed(2)),
        'stdDev': double.parse(stdDev.toStringAsFixed(2)),
        'count': count,
      },
      'samples': samples,
    };
  }

  return {
    'timeRange': {
      'start': timeRange.start.toIso8601String(),
      'end': timeRange.end.toIso8601String(),
      'preset': presetLabel(timeRange.preset),
    },
    'parameters': parameters,
  };
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
