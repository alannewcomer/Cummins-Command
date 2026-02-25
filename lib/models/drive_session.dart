import 'package:cloud_firestore/cloud_firestore.dart';

enum DriveStatus {
  recording,
  pendingUpload,
  uploaded,
  pendingAnalysis,
  analysisComplete,
}

class DriveSession {
  final String id;
  final String vehicleId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final double startOdometer;
  final double? endOdometer;
  final double distanceMiles;

  // Fuel
  final double fuelUsedGallons;
  final double averageMPG;
  final double? instantMPGMin;
  final double? instantMPGMax;

  // Maximums
  final double? maxBoostPsi;
  final double? maxEgtF;
  final double? maxCoolantTempF;
  final double? maxTransTempF;
  final double? maxOilTempF;
  final double? maxTurboSpeedRpm;
  final double? maxRailPressurePsi;

  // Averages
  final double? avgBoost;
  final double? avgEgt;
  final double? avgCoolant;
  final double? avgTrans;
  final double? avgLoad;
  final double? avgRpm;

  // Idle
  final int idleSeconds;

  // DPF
  final bool dpfRegenOccurred;
  final int dpfRegenCount;
  final int dpfRegenDurationSeconds;

  // GPS
  final double? gpsStartLat;
  final double? gpsStartLng;
  final double? gpsEndLat;
  final double? gpsEndLng;

  // Status
  final DriveStatus status;

  // AI results
  final String? aiSummary;
  final List<String> aiAnomalies;
  final int? aiHealthScore;
  final List<String> aiRecommendations;

  // Tags
  final List<String> tags;

  // Notes & Cargo
  final String? notes;
  final String? cargoDescription;
  final double? cargoWeightLbs;

  // Route Intelligence
  final String? routeId;
  final String? routeName;

  // Smart Auto-Tags (AI-generated, separate from user tags)
  final List<String> autoTags;

  // Photos
  final List<String> photoUrls;

  // Timeseries storage
  final String? timeseriesPath;
  final bool timeseriesUploaded;
  final String? parquetPath;
  final int datapointCount;
  final List<String> sensorList;
  final Map<String, Map<String, double>> parameterStats;

  const DriveSession({
    required this.id,
    required this.vehicleId,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.startOdometer = 0,
    this.endOdometer,
    this.distanceMiles = 0,
    this.fuelUsedGallons = 0,
    this.averageMPG = 0,
    this.instantMPGMin,
    this.instantMPGMax,
    this.idleSeconds = 0,
    this.maxBoostPsi,
    this.maxEgtF,
    this.maxCoolantTempF,
    this.maxTransTempF,
    this.maxOilTempF,
    this.maxTurboSpeedRpm,
    this.maxRailPressurePsi,
    this.avgBoost,
    this.avgEgt,
    this.avgCoolant,
    this.avgTrans,
    this.avgLoad,
    this.avgRpm,
    this.dpfRegenOccurred = false,
    this.dpfRegenCount = 0,
    this.dpfRegenDurationSeconds = 0,
    this.gpsStartLat,
    this.gpsStartLng,
    this.gpsEndLat,
    this.gpsEndLng,
    this.status = DriveStatus.recording,
    this.aiSummary,
    this.aiAnomalies = const [],
    this.aiHealthScore,
    this.aiRecommendations = const [],
    this.tags = const [],
    this.notes,
    this.cargoDescription,
    this.cargoWeightLbs,
    this.routeId,
    this.routeName,
    this.autoTags = const [],
    this.photoUrls = const [],
    this.timeseriesPath,
    this.timeseriesUploaded = false,
    this.parquetPath,
    this.datapointCount = 0,
    this.sensorList = const [],
    this.parameterStats = const {},
  });

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  bool get hasAiAnalysis => status == DriveStatus.analysisComplete;

  DriveSession copyWith({
    String? id,
    String? vehicleId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? startOdometer,
    double? endOdometer,
    double? distanceMiles,
    double? fuelUsedGallons,
    double? averageMPG,
    double? instantMPGMin,
    double? instantMPGMax,
    int? idleSeconds,
    double? maxBoostPsi,
    double? maxEgtF,
    double? maxCoolantTempF,
    double? maxTransTempF,
    double? maxOilTempF,
    double? maxTurboSpeedRpm,
    double? maxRailPressurePsi,
    double? avgBoost,
    double? avgEgt,
    double? avgCoolant,
    double? avgTrans,
    double? avgLoad,
    double? avgRpm,
    bool? dpfRegenOccurred,
    int? dpfRegenCount,
    int? dpfRegenDurationSeconds,
    double? gpsStartLat,
    double? gpsStartLng,
    double? gpsEndLat,
    double? gpsEndLng,
    DriveStatus? status,
    String? aiSummary,
    List<String>? aiAnomalies,
    int? aiHealthScore,
    List<String>? aiRecommendations,
    List<String>? tags,
    String? notes,
    String? cargoDescription,
    double? cargoWeightLbs,
    String? routeId,
    String? routeName,
    List<String>? autoTags,
    List<String>? photoUrls,
    String? timeseriesPath,
    bool? timeseriesUploaded,
    String? parquetPath,
    int? datapointCount,
    List<String>? sensorList,
    Map<String, Map<String, double>>? parameterStats,
  }) {
    return DriveSession(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startOdometer: startOdometer ?? this.startOdometer,
      endOdometer: endOdometer ?? this.endOdometer,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      fuelUsedGallons: fuelUsedGallons ?? this.fuelUsedGallons,
      averageMPG: averageMPG ?? this.averageMPG,
      instantMPGMin: instantMPGMin ?? this.instantMPGMin,
      instantMPGMax: instantMPGMax ?? this.instantMPGMax,
      idleSeconds: idleSeconds ?? this.idleSeconds,
      maxBoostPsi: maxBoostPsi ?? this.maxBoostPsi,
      maxEgtF: maxEgtF ?? this.maxEgtF,
      maxCoolantTempF: maxCoolantTempF ?? this.maxCoolantTempF,
      maxTransTempF: maxTransTempF ?? this.maxTransTempF,
      maxOilTempF: maxOilTempF ?? this.maxOilTempF,
      maxTurboSpeedRpm: maxTurboSpeedRpm ?? this.maxTurboSpeedRpm,
      maxRailPressurePsi: maxRailPressurePsi ?? this.maxRailPressurePsi,
      avgBoost: avgBoost ?? this.avgBoost,
      avgEgt: avgEgt ?? this.avgEgt,
      avgCoolant: avgCoolant ?? this.avgCoolant,
      avgTrans: avgTrans ?? this.avgTrans,
      avgLoad: avgLoad ?? this.avgLoad,
      avgRpm: avgRpm ?? this.avgRpm,
      dpfRegenOccurred: dpfRegenOccurred ?? this.dpfRegenOccurred,
      dpfRegenCount: dpfRegenCount ?? this.dpfRegenCount,
      dpfRegenDurationSeconds: dpfRegenDurationSeconds ?? this.dpfRegenDurationSeconds,
      gpsStartLat: gpsStartLat ?? this.gpsStartLat,
      gpsStartLng: gpsStartLng ?? this.gpsStartLng,
      gpsEndLat: gpsEndLat ?? this.gpsEndLat,
      gpsEndLng: gpsEndLng ?? this.gpsEndLng,
      status: status ?? this.status,
      aiSummary: aiSummary ?? this.aiSummary,
      aiAnomalies: aiAnomalies ?? this.aiAnomalies,
      aiHealthScore: aiHealthScore ?? this.aiHealthScore,
      aiRecommendations: aiRecommendations ?? this.aiRecommendations,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      cargoDescription: cargoDescription ?? this.cargoDescription,
      cargoWeightLbs: cargoWeightLbs ?? this.cargoWeightLbs,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      autoTags: autoTags ?? this.autoTags,
      photoUrls: photoUrls ?? this.photoUrls,
      timeseriesPath: timeseriesPath ?? this.timeseriesPath,
      timeseriesUploaded: timeseriesUploaded ?? this.timeseriesUploaded,
      parquetPath: parquetPath ?? this.parquetPath,
      datapointCount: datapointCount ?? this.datapointCount,
      sensorList: sensorList ?? this.sensorList,
      parameterStats: parameterStats ?? this.parameterStats,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vehicleId': vehicleId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'durationSeconds': durationSeconds,
      'startOdometer': startOdometer,
      'endOdometer': endOdometer,
      'distanceMiles': distanceMiles,
      'fuelUsedGallons': fuelUsedGallons,
      'averageMPG': averageMPG,
      'instantMPGMin': instantMPGMin,
      'instantMPGMax': instantMPGMax,
      'idleSeconds': idleSeconds,
      'maximums': {
        'maxBoostPsi': maxBoostPsi,
        'maxEgtF': maxEgtF,
        'maxCoolantTempF': maxCoolantTempF,
        'maxTransTempF': maxTransTempF,
        'maxOilTempF': maxOilTempF,
        'maxTurboSpeedRpm': maxTurboSpeedRpm,
        'maxRailPressurePsi': maxRailPressurePsi,
      },
      'averages': {
        'avgBoost': avgBoost,
        'avgEgt': avgEgt,
        'avgCoolant': avgCoolant,
        'avgTrans': avgTrans,
        'avgLoad': avgLoad,
        'avgRpm': avgRpm,
      },
      'dpfRegenOccurred': dpfRegenOccurred,
      'dpfRegenCount': dpfRegenCount,
      'dpfRegenDurationSeconds': dpfRegenDurationSeconds,
      'gpsStartLat': gpsStartLat,
      'gpsStartLng': gpsStartLng,
      'gpsEndLat': gpsEndLat,
      'gpsEndLng': gpsEndLng,
      'status': status.name,
      'aiSummary': aiSummary,
      'aiAnomalies': aiAnomalies,
      'aiHealthScore': aiHealthScore,
      'aiRecommendations': aiRecommendations,
      'tags': tags,
      'notes': notes,
      'cargoDescription': cargoDescription,
      'cargoWeightLbs': cargoWeightLbs,
      'routeId': routeId,
      'routeName': routeName,
      'autoTags': autoTags,
      'photoUrls': photoUrls,
      'timeseriesPath': timeseriesPath,
      'timeseriesUploaded': timeseriesUploaded,
      'parquetPath': parquetPath,
      'datapointCount': datapointCount,
      'sensorList': sensorList,
      'parameterStats': parameterStats,
    };
  }

  factory DriveSession.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final maxs = d['maximums'] as Map<String, dynamic>? ?? {};
    final avgs = d['averages'] as Map<String, dynamic>? ?? {};
    return DriveSession(
      id: doc.id,
      vehicleId: d['vehicleId'] as String? ?? '',
      startTime: (d['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (d['endTime'] as Timestamp?)?.toDate(),
      durationSeconds: (d['durationSeconds'] as num?)?.toInt() ?? 0,
      startOdometer: (d['startOdometer'] as num?)?.toDouble() ?? 0,
      endOdometer: (d['endOdometer'] as num?)?.toDouble(),
      distanceMiles: (d['distanceMiles'] as num?)?.toDouble() ?? 0,
      fuelUsedGallons: (d['fuelUsedGallons'] as num?)?.toDouble() ?? 0,
      averageMPG: (d['averageMPG'] as num?)?.toDouble() ?? 0,
      instantMPGMin: (d['instantMPGMin'] as num?)?.toDouble(),
      instantMPGMax: (d['instantMPGMax'] as num?)?.toDouble(),
      idleSeconds: (d['idleSeconds'] as num?)?.toInt() ?? 0,
      maxBoostPsi: (maxs['maxBoostPsi'] as num?)?.toDouble(),
      maxEgtF: (maxs['maxEgtF'] as num?)?.toDouble(),
      maxCoolantTempF: (maxs['maxCoolantTempF'] as num?)?.toDouble(),
      maxTransTempF: (maxs['maxTransTempF'] as num?)?.toDouble(),
      maxOilTempF: (maxs['maxOilTempF'] as num?)?.toDouble(),
      maxTurboSpeedRpm: (maxs['maxTurboSpeedRpm'] as num?)?.toDouble(),
      maxRailPressurePsi: (maxs['maxRailPressurePsi'] as num?)?.toDouble(),
      avgBoost: (avgs['avgBoost'] as num?)?.toDouble(),
      avgEgt: (avgs['avgEgt'] as num?)?.toDouble(),
      avgCoolant: (avgs['avgCoolant'] as num?)?.toDouble(),
      avgTrans: (avgs['avgTrans'] as num?)?.toDouble(),
      avgLoad: (avgs['avgLoad'] as num?)?.toDouble(),
      avgRpm: (avgs['avgRpm'] as num?)?.toDouble(),
      dpfRegenOccurred: d['dpfRegenOccurred'] as bool? ?? false,
      dpfRegenCount: (d['dpfRegenCount'] as num?)?.toInt() ?? 0,
      dpfRegenDurationSeconds: (d['dpfRegenDurationSeconds'] as num?)?.toInt() ?? 0,
      gpsStartLat: (d['gpsStartLat'] as num?)?.toDouble(),
      gpsStartLng: (d['gpsStartLng'] as num?)?.toDouble(),
      gpsEndLat: (d['gpsEndLat'] as num?)?.toDouble(),
      gpsEndLng: (d['gpsEndLng'] as num?)?.toDouble(),
      status: DriveStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => DriveStatus.recording,
      ),
      aiSummary: d['aiSummary'] as String?,
      aiAnomalies: _parseStringList(d['aiAnomalies']),
      aiHealthScore: (d['aiHealthScore'] as num?)?.toInt(),
      aiRecommendations: _parseStringList(d['aiRecommendations']),
      tags: _parseStringList(d['tags']),
      notes: d['notes'] as String?,
      cargoDescription: d['cargoDescription'] as String?,
      cargoWeightLbs: (d['cargoWeightLbs'] as num?)?.toDouble(),
      routeId: d['routeId'] as String?,
      routeName: d['routeName'] as String?,
      autoTags: _parseStringList(d['autoTags']),
      photoUrls: _parseStringList(d['photoUrls']),
      timeseriesPath: d['timeseriesPath'] as String?,
      timeseriesUploaded: d['timeseriesUploaded'] as bool? ?? false,
      parquetPath: d['parquetPath'] as String?,
      datapointCount: (d['datapointCount'] as num?)?.toInt() ?? 0,
      sensorList: _parseStringList(d['sensorList']),
      parameterStats: _parseParameterStats(d['parameterStats']),
    );
  }

  /// Safely parse a Firestore field that should be a string list.
  /// Returns [] if the value is null, not a List, or contains non-String items.
  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return [];
  }

  static Map<String, Map<String, double>> _parseParameterStats(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, Map<String, double>>{};
    for (final entry in raw.entries) {
      final key = entry.key as String;
      final value = entry.value;
      if (value is Map) {
        final inner = <String, double>{};
        for (final e in value.entries) {
          final v = e.value;
          if (v is num) inner[e.key as String] = v.toDouble();
        }
        result[key] = inner;
      }
    }
    return result;
  }
}
