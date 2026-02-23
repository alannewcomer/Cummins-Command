import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/drive_session.dart';
import '../services/ai_service.dart';
import 'drives_provider.dart';
import 'vehicle_provider.dart';

/// AI service — rebuilt whenever the active vehicle changes so the system
/// instruction always reflects the actual truck in Firestore.
final aiServiceProvider = Provider<AiService>((ref) {
  final vehicle = ref.watch(activeVehicleProvider);
  return AiService(vehicle: vehicle);
});

/// AI status strip message (updates periodically with live data).
class AiStatusNotifier extends Notifier<String> {
  @override
  String build() => 'Connecting to AI intelligence...';
  void setMessage(String message) => state = message;
}

final aiStatusMessageProvider =
    NotifierProvider<AiStatusNotifier, String>(AiStatusNotifier.new);

/// Chat message model.
class ChatMessage {
  final String role; // 'user' or 'ai'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Chat history for "Ask Gemini" feature.
class ChatHistoryNotifier extends Notifier<List<ChatMessage>> {
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

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
        ChatHistoryNotifier.new);

/// Whether AI chat is currently generating a response.
class AiLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoading(bool value) => state = value;
}

final aiLoadingProvider =
    NotifierProvider<AiLoadingNotifier, bool>(AiLoadingNotifier.new);

// ─── Analysis Scope & Providers ───

enum AnalysisScope {
  lastTrip('Last Trip'),
  today('Today'),
  thisWeek('This Week'),
  last30Days('30 Days');

  final String label;
  const AnalysisScope(this.label);
}

/// Currently selected analysis scope.
class AnalysisScopeNotifier extends Notifier<AnalysisScope> {
  @override
  AnalysisScope build() => AnalysisScope.lastTrip;
  void select(AnalysisScope scope) => state = scope;
}

final analysisScopeProvider =
    NotifierProvider<AnalysisScopeNotifier, AnalysisScope>(
        AnalysisScopeNotifier.new);

/// Analysis result from Gemini. Null = idle, loading, data, or error.
class AnalysisResultNotifier extends Notifier<AsyncValue<Map<String, dynamic>?>> {
  @override
  AsyncValue<Map<String, dynamic>?> build() => const AsyncData(null);

  Future<void> runAnalysis(AnalysisScope scope, List<DriveSession> drives) async {
    state = const AsyncLoading();
    try {
      final filtered = _filterDrivesByScope(scope, drives);
      if (filtered.isEmpty) {
        state = AsyncError('No drives found for ${scope.label}', StackTrace.current);
        return;
      }
      final context = _buildDriveContext(filtered);
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.runAnalysis(scope.label, context);
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void clear() => state = const AsyncData(null);
}

final analysisResultProvider =
    NotifierProvider<AnalysisResultNotifier, AsyncValue<Map<String, dynamic>?>>(
        AnalysisResultNotifier.new);

/// Quick stats derived from drives filtered by scope. Pure local computation.
class ScopeStats {
  final int driveCount;
  final double totalMiles;
  final int totalDurationSeconds;
  final double avgMPG;
  final String dateRange;

  const ScopeStats({
    this.driveCount = 0,
    this.totalMiles = 0,
    this.totalDurationSeconds = 0,
    this.avgMPG = 0,
    this.dateRange = '',
  });

  String get formattedDuration {
    final h = totalDurationSeconds ~/ 3600;
    final m = (totalDurationSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

final scopeStatsProvider = Provider<ScopeStats>((ref) {
  final scope = ref.watch(analysisScopeProvider);
  final drivesAsync = ref.watch(drivesStreamProvider);

  return drivesAsync.when(
    loading: () => const ScopeStats(),
    error: (_, __) => const ScopeStats(),
    data: (drives) {
      final filtered = _filterDrivesByScope(scope, drives);
      if (filtered.isEmpty) return const ScopeStats();

      final totalMiles = filtered.fold<double>(0, (sum, d) => sum + d.distanceMiles);
      final totalDuration = filtered.fold<int>(0, (sum, d) => sum + d.durationSeconds);
      final withMpg = filtered.where((d) => d.averageMPG > 0).toList();
      final avgMpg = withMpg.isEmpty
          ? 0.0
          : withMpg.fold<double>(0, (sum, d) => sum + d.averageMPG) / withMpg.length;

      final fmt = DateFormat.MMMd();
      String dateRange;
      if (filtered.length == 1) {
        dateRange = fmt.format(filtered.first.startTime);
      } else {
        dateRange = '${fmt.format(filtered.last.startTime)} – ${fmt.format(filtered.first.startTime)}';
      }

      return ScopeStats(
        driveCount: filtered.length,
        totalMiles: totalMiles,
        totalDurationSeconds: totalDuration,
        avgMPG: avgMpg,
        dateRange: dateRange,
      );
    },
  );
});

// ─── Helper Functions ───

List<DriveSession> _filterDrivesByScope(AnalysisScope scope, List<DriveSession> drives) {
  final now = DateTime.now();
  switch (scope) {
    case AnalysisScope.lastTrip:
      return drives.isNotEmpty ? [drives.first] : [];
    case AnalysisScope.today:
      final midnight = DateTime(now.year, now.month, now.day);
      return drives.where((d) => d.startTime.isAfter(midnight)).toList();
    case AnalysisScope.thisWeek:
      final weekAgo = now.subtract(const Duration(days: 7));
      return drives.where((d) => d.startTime.isAfter(weekAgo)).toList();
    case AnalysisScope.last30Days:
      final monthAgo = now.subtract(const Duration(days: 30));
      return drives.where((d) => d.startTime.isAfter(monthAgo)).toList();
  }
}

Map<String, dynamic> _buildDriveContext(List<DriveSession> drives) {
  final perDrive = drives.map((d) => {
    'date': DateFormat.yMMMd().format(d.startTime),
    'distanceMiles': d.distanceMiles,
    'durationMinutes': d.durationSeconds / 60,
    'averageMPG': d.averageMPG,
    'maxEGT': d.maxEgtF,
    'maxCoolant': d.maxCoolantTempF,
    'maxTransTemp': d.maxTransTempF,
    'maxOilTemp': d.maxOilTempF,
    'maxBoost': d.maxBoostPsi,
    'avgLoad': d.avgLoad,
    'avgRPM': d.avgRpm,
    'avgEGT': d.avgEgt,
    'avgCoolant': d.avgCoolant,
    'avgTransTemp': d.avgTrans,
    'avgBoost': d.avgBoost,
    'dpfRegenOccurred': d.dpfRegenOccurred,
    'dpfRegenCount': d.dpfRegenCount,
  }).toList();

  // Aggregated stats
  final totalMiles = drives.fold<double>(0, (s, d) => s + d.distanceMiles);
  final withMpg = drives.where((d) => d.averageMPG > 0);
  final avgMpg = withMpg.isEmpty
      ? 0.0
      : withMpg.fold<double>(0, (s, d) => s + d.averageMPG) / withMpg.length;

  double? peakEGT, peakCoolant, peakTrans, peakOilTemp, peakBoost;
  double avgLoadAll = 0, avgRpmAll = 0;
  int dpfRegenTotal = 0;
  int loadCount = 0, rpmCount = 0;

  for (final d in drives) {
    if (d.maxEgtF != null && (peakEGT == null || d.maxEgtF! > peakEGT)) peakEGT = d.maxEgtF;
    if (d.maxCoolantTempF != null && (peakCoolant == null || d.maxCoolantTempF! > peakCoolant)) peakCoolant = d.maxCoolantTempF;
    if (d.maxTransTempF != null && (peakTrans == null || d.maxTransTempF! > peakTrans)) peakTrans = d.maxTransTempF;
    if (d.maxOilTempF != null && (peakOilTemp == null || d.maxOilTempF! > peakOilTemp)) peakOilTemp = d.maxOilTempF;
    if (d.maxBoostPsi != null && (peakBoost == null || d.maxBoostPsi! > peakBoost)) peakBoost = d.maxBoostPsi;
    if (d.avgLoad != null) { avgLoadAll += d.avgLoad!; loadCount++; }
    if (d.avgRpm != null) { avgRpmAll += d.avgRpm!; rpmCount++; }
    dpfRegenTotal += d.dpfRegenCount;
  }

  return {
    'driveCount': drives.length,
    'drives': perDrive,
    'aggregated': {
      'totalMiles': totalMiles,
      'averageMPG': avgMpg,
      'peakEGT': peakEGT,
      'peakCoolant': peakCoolant,
      'peakTransTemp': peakTrans,
      'peakOilTemp': peakOilTemp,
      'peakBoost': peakBoost,
      'avgLoad': loadCount > 0 ? avgLoadAll / loadCount : null,
      'avgRPM': rpmCount > 0 ? avgRpmAll / rpmCount : null,
      'dpfRegenTotal': dpfRegenTotal,
    },
  };
}
