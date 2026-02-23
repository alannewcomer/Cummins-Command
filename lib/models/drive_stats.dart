import 'dart:math' as math;
import 'datapoint.dart';

/// Per-parameter thermal statistics computed from datapoint series.
class ThermalStats {
  final double min;
  final double max;
  final double avg;
  final int timeAboveWarnSeconds;
  final int timeAboveCritSeconds;
  final bool hasData;

  const ThermalStats({
    this.min = 0,
    this.max = 0,
    this.avg = 0,
    this.timeAboveWarnSeconds = 0,
    this.timeAboveCritSeconds = 0,
    this.hasData = false,
  });
}

/// A point in a time series for sparklines.
class TimeSeriesPoint {
  final double t; // normalized 0..1 across drive duration
  final double v; // value

  const TimeSeriesPoint(this.t, this.v);
}

/// GPS coordinate for route rendering.
class GpsPoint {
  final double lat;
  final double lng;

  const GpsPoint(this.lat, this.lng);
}

/// Comprehensive computed statistics from raw datapoints.
/// Immutable — produced once by [computeDriveStats].
class DriveStats {
  // Overview
  final double avgSpeedMph;
  final double maxSpeedMph;
  final double idlePercent;
  final int movingTimeSeconds;

  // Engine
  final double avgRpm;
  final double maxRpm;
  final double avgBoostPsi;
  final double maxBoostPsi;
  final double avgLoadPercent;
  final double maxLoadPercent;
  final double avgThrottlePercent;
  final double maxThrottlePercent;
  final double maxTurboSpeedRpm;
  final double maxRailPressurePsi;
  final double maxEstimatedHp;
  final double maxEstimatedTorque;
  final double highLoadPercent; // % time load > 70

  // Thermal
  final ThermalStats coolant;
  final ThermalStats trans;
  final ThermalStats egt;
  final ThermalStats egt2;
  final ThermalStats egt3;
  final ThermalStats egt4;
  final ThermalStats oilTemp;
  final ThermalStats intakeTemp;
  final ThermalStats intercoolerTemp;

  // Drivetrain
  final Map<int, double> gearDistribution; // gear# -> seconds
  final double tcLockedPercent;
  final double avgVgtPercent;
  final double avgEgrPercent;

  // Emissions
  final double avgDpfSootLoad;
  final double maxDpfSootLoad;
  final double avgDpfDiffPressure;
  final double avgNoxPreScr;
  final double avgNoxPostScr;
  final double scrEfficiencyPercent;
  final double defConsumedMl;
  final double defLevelStart;
  final double defLevelEnd;

  // System
  final double avgBatteryVoltage;
  final double minBatteryVoltage;
  final double avgOilPressure;
  final double minOilPressure;
  final double avgCrankcasePressure;
  final double coolantLevelStart;
  final double coolantLevelEnd;

  // Time series (downsampled for sparklines)
  final List<TimeSeriesPoint> speedSeries;
  final List<TimeSeriesPoint> boostSeries;
  final List<TimeSeriesPoint> egtSeries;
  final List<TimeSeriesPoint> transTempSeries;
  final List<TimeSeriesPoint> rpmSeries;
  final List<TimeSeriesPoint> throttleSeries;
  final List<TimeSeriesPoint> oilTempSeries;
  final List<TimeSeriesPoint> loadSeries;

  // GPS
  final List<GpsPoint> routePoints;
  final bool hasGpsData;

  // Metadata
  final int totalDatapoints;

  const DriveStats({
    this.avgSpeedMph = 0,
    this.maxSpeedMph = 0,
    this.idlePercent = 0,
    this.movingTimeSeconds = 0,
    this.avgRpm = 0,
    this.maxRpm = 0,
    this.avgBoostPsi = 0,
    this.maxBoostPsi = 0,
    this.avgLoadPercent = 0,
    this.maxLoadPercent = 0,
    this.avgThrottlePercent = 0,
    this.maxThrottlePercent = 0,
    this.maxTurboSpeedRpm = 0,
    this.maxRailPressurePsi = 0,
    this.maxEstimatedHp = 0,
    this.maxEstimatedTorque = 0,
    this.highLoadPercent = 0,
    this.coolant = const ThermalStats(),
    this.trans = const ThermalStats(),
    this.egt = const ThermalStats(),
    this.egt2 = const ThermalStats(),
    this.egt3 = const ThermalStats(),
    this.egt4 = const ThermalStats(),
    this.oilTemp = const ThermalStats(),
    this.intakeTemp = const ThermalStats(),
    this.intercoolerTemp = const ThermalStats(),
    this.gearDistribution = const {},
    this.tcLockedPercent = 0,
    this.avgVgtPercent = 0,
    this.avgEgrPercent = 0,
    this.avgDpfSootLoad = 0,
    this.maxDpfSootLoad = 0,
    this.avgDpfDiffPressure = 0,
    this.avgNoxPreScr = 0,
    this.avgNoxPostScr = 0,
    this.scrEfficiencyPercent = 0,
    this.defConsumedMl = 0,
    this.defLevelStart = 0,
    this.defLevelEnd = 0,
    this.avgBatteryVoltage = 0,
    this.minBatteryVoltage = 0,
    this.avgOilPressure = 0,
    this.minOilPressure = 0,
    this.avgCrankcasePressure = 0,
    this.coolantLevelStart = 0,
    this.coolantLevelEnd = 0,
    this.speedSeries = const [],
    this.boostSeries = const [],
    this.egtSeries = const [],
    this.transTempSeries = const [],
    this.rpmSeries = const [],
    this.throttleSeries = const [],
    this.oilTempSeries = const [],
    this.loadSeries = const [],
    this.routePoints = const [],
    this.hasGpsData = false,
    this.totalDatapoints = 0,
  });
}

// ─── Computation ─────────────────────────────────────────────────────────────

/// Single-pass computation of DriveStats from raw datapoints.
/// Expects datapoints sorted by timestamp ascending.
DriveStats computeDriveStats(List<DataPoint> points) {
  if (points.isEmpty) return const DriveStats();

  final n = points.length;
  final startTs = points.first.timestamp;
  final endTs = points.last.timestamp;
  final durationMs = (endTs - startTs).clamp(1, double.maxFinite.toInt());

  // Accumulators
  final acc = _Accumulators();

  // Raw series for downsampling
  final rawSpeed = <_RawPt>[];
  final rawBoost = <_RawPt>[];
  final rawEgt = <_RawPt>[];
  final rawTrans = <_RawPt>[];
  final rawRpm = <_RawPt>[];
  final rawThrottle = <_RawPt>[];
  final rawOilTemp = <_RawPt>[];
  final rawLoad = <_RawPt>[];

  // GPS
  final gpsPoints = <GpsPoint>[];

  // First/last values for start/end tracking
  double? defLevelFirst;
  double? defLevelLast;
  double? coolantLevelFirst;
  double? coolantLevelLast;

  // Gear distribution accumulator (gear# -> milliseconds)
  final gearMs = <int, int>{};

  for (int i = 0; i < n; i++) {
    final dp = points[i];
    final tNorm = (dp.timestamp - startTs) / durationMs;
    final dtMs = i > 0 ? (dp.timestamp - points[i - 1].timestamp) : 0;
    final dtSec = dtMs / 1000.0;

    // Speed
    if (dp.speed != null) {
      acc.addSpeed(dp.speed!, dtSec);
      rawSpeed.add(_RawPt(tNorm, dp.speed!));
    }

    // RPM
    if (dp.rpm != null) {
      acc.addRpm(dp.rpm!, dtSec);
      rawRpm.add(_RawPt(tNorm, dp.rpm!));
    }

    // Boost
    if (dp.boostPressure != null) {
      acc.addBoost(dp.boostPressure!);
      rawBoost.add(_RawPt(tNorm, dp.boostPressure!));
    }

    // Load
    if (dp.engineLoad != null) {
      acc.addLoad(dp.engineLoad!, dtSec);
      rawLoad.add(_RawPt(tNorm, dp.engineLoad!));
    }

    // Throttle / Accelerator Pedal
    final throttle = dp.accelPedalD ?? dp.throttlePos;
    if (throttle != null) {
      acc.addThrottle(throttle);
      rawThrottle.add(_RawPt(tNorm, throttle));
    }

    // Turbo
    if (dp.turboSpeed != null) {
      acc.maxTurbo = math.max(acc.maxTurbo, dp.turboSpeed!);
    }

    // Rail pressure
    final rail = dp.railPressure;
    if (rail != null) {
      acc.maxRail = math.max(acc.maxRail, rail);
    }

    // Estimated HP / Torque
    if (dp.estimatedHP != null) {
      acc.maxHp = math.max(acc.maxHp, dp.estimatedHP!);
    }
    if (dp.estimatedTorque != null) {
      acc.maxTorque = math.max(acc.maxTorque, dp.estimatedTorque!);
    }

    // Thermals
    acc.addThermal(acc.coolant, dp.coolantTemp, dtSec, 210, 220);
    acc.addThermal(acc.trans, dp.transTemp, dtSec, 200, 220);
    acc.addThermal(acc.egtAcc, dp.egt, dtSec, 900, 1100);
    acc.addThermal(acc.egt2Acc, dp.egt2, dtSec, 900, 1100);
    acc.addThermal(acc.egt3Acc, dp.egt3, dtSec, 900, 1100);
    acc.addThermal(acc.egt4Acc, dp.egt4, dtSec, 900, 1100);
    acc.addThermal(acc.oilTempAcc, dp.oilTemp, dtSec, 230, 240);
    acc.addThermal(acc.intakeTempAcc, dp.intakeTemp, dtSec, 120, 160);
    acc.addThermal(
        acc.intercoolerTempAcc, dp.intercoolerOutletTemp, dtSec, 150, 180);

    if (dp.egt != null) rawEgt.add(_RawPt(tNorm, dp.egt!));
    if (dp.transTemp != null) rawTrans.add(_RawPt(tNorm, dp.transTemp!));
    if (dp.oilTemp != null) rawOilTemp.add(_RawPt(tNorm, dp.oilTemp!));

    // Drivetrain
    final gear = dp.estimatedGear?.toInt();
    if (gear != null && gear > 0) {
      gearMs[gear] = (gearMs[gear] ?? 0) + dtMs;
    }
    if (dp.vgtPosition != null) acc.addVgt(dp.vgtPosition!);
    if (dp.egrPosition != null) acc.addEgr(dp.egrPosition!);

    // Emissions
    if (dp.dpfSootLoad != null) {
      acc.addDpfSoot(dp.dpfSootLoad!);
    }
    if (dp.dpfDiffPressure != null) acc.addDpfDiff(dp.dpfDiffPressure!);
    if (dp.noxPreScr != null) acc.addNoxPre(dp.noxPreScr!);
    if (dp.noxPostScr != null) acc.addNoxPost(dp.noxPostScr!);
    if (dp.defLevel != null) {
      defLevelFirst ??= dp.defLevel!;
      defLevelLast = dp.defLevel!;
    }
    if (dp.defDosingRate != null) {
      acc.defConsumedMl += dp.defDosingRate! * dtSec / 1000.0;
    }

    // System
    if (dp.batteryVoltage != null) acc.addBattery(dp.batteryVoltage!);
    if (dp.oilPressure != null) acc.addOilPressure(dp.oilPressure!);
    if (dp.crankcasePressure != null) acc.addCrankcase(dp.crankcasePressure!);
    if (dp.coolantLevel != null) {
      coolantLevelFirst ??= dp.coolantLevel!;
      coolantLevelLast = dp.coolantLevel!;
    }

    // GPS
    if (dp.lat != null && dp.lng != null) {
      gpsPoints.add(GpsPoint(dp.lat!, dp.lng!));
    }
  }

  // Build gear distribution in seconds
  final gearDist = <int, double>{};
  for (final e in gearMs.entries) {
    gearDist[e.key] = e.value / 1000.0;
  }

  final durationSec = durationMs / 1000.0;

  return DriveStats(
    // Overview
    avgSpeedMph: acc.speedCount > 0 ? acc.speedSum / acc.speedCount : 0,
    maxSpeedMph: acc.maxSpeed,
    idlePercent:
        durationSec > 0 ? (acc.idleSeconds / durationSec * 100).clamp(0, 100) : 0,
    movingTimeSeconds: (durationSec - acc.idleSeconds).clamp(0, durationSec).toInt(),

    // Engine
    avgRpm: acc.rpmCount > 0 ? acc.rpmSum / acc.rpmCount : 0,
    maxRpm: acc.maxRpm,
    avgBoostPsi: acc.boostCount > 0 ? acc.boostSum / acc.boostCount : 0,
    maxBoostPsi: acc.maxBoost,
    avgLoadPercent: acc.loadCount > 0 ? acc.loadSum / acc.loadCount : 0,
    maxLoadPercent: acc.maxLoad,
    avgThrottlePercent:
        acc.throttleCount > 0 ? acc.throttleSum / acc.throttleCount : 0,
    maxThrottlePercent: acc.maxThrottle,
    maxTurboSpeedRpm: acc.maxTurbo,
    maxRailPressurePsi: acc.maxRail,
    maxEstimatedHp: acc.maxHp,
    maxEstimatedTorque: acc.maxTorque,
    highLoadPercent: durationSec > 0
        ? (acc.highLoadSeconds / durationSec * 100).clamp(0, 100)
        : 0,

    // Thermal
    coolant: acc.coolant.toStats(),
    trans: acc.trans.toStats(),
    egt: acc.egtAcc.toStats(),
    egt2: acc.egt2Acc.toStats(),
    egt3: acc.egt3Acc.toStats(),
    egt4: acc.egt4Acc.toStats(),
    oilTemp: acc.oilTempAcc.toStats(),
    intakeTemp: acc.intakeTempAcc.toStats(),
    intercoolerTemp: acc.intercoolerTempAcc.toStats(),

    // Drivetrain
    gearDistribution: gearDist,
    tcLockedPercent:
        durationMs > 0 ? (acc.tcLockedMs / durationMs * 100).clamp(0, 100) : 0,
    avgVgtPercent: acc.vgtCount > 0 ? acc.vgtSum / acc.vgtCount : 0,
    avgEgrPercent: acc.egrCount > 0 ? acc.egrSum / acc.egrCount : 0,

    // Emissions
    avgDpfSootLoad:
        acc.dpfSootCount > 0 ? acc.dpfSootSum / acc.dpfSootCount : 0,
    maxDpfSootLoad: acc.maxDpfSoot,
    avgDpfDiffPressure:
        acc.dpfDiffCount > 0 ? acc.dpfDiffSum / acc.dpfDiffCount : 0,
    avgNoxPreScr: acc.noxPreCount > 0 ? acc.noxPreSum / acc.noxPreCount : 0,
    avgNoxPostScr:
        acc.noxPostCount > 0 ? acc.noxPostSum / acc.noxPostCount : 0,
    scrEfficiencyPercent: _scrEfficiency(
      acc.noxPreCount > 0 ? acc.noxPreSum / acc.noxPreCount : 0,
      acc.noxPostCount > 0 ? acc.noxPostSum / acc.noxPostCount : 0,
    ),
    defConsumedMl: acc.defConsumedMl,
    defLevelStart: defLevelFirst ?? 0,
    defLevelEnd: defLevelLast ?? 0,

    // System
    avgBatteryVoltage:
        acc.batteryCount > 0 ? acc.batterySum / acc.batteryCount : 0,
    minBatteryVoltage: acc.minBattery,
    avgOilPressure:
        acc.oilPressureCount > 0
            ? acc.oilPressureSum / acc.oilPressureCount
            : 0,
    minOilPressure: acc.minOilPressure,
    avgCrankcasePressure:
        acc.crankcaseCount > 0 ? acc.crankcaseSum / acc.crankcaseCount : 0,
    coolantLevelStart: coolantLevelFirst ?? 0,
    coolantLevelEnd: coolantLevelLast ?? 0,

    // Time series (downsampled to ~150 points)
    speedSeries: _downsampleLTTB(rawSpeed, 150),
    boostSeries: _downsampleLTTB(rawBoost, 150),
    egtSeries: _downsampleLTTB(rawEgt, 150),
    transTempSeries: _downsampleLTTB(rawTrans, 150),
    rpmSeries: _downsampleLTTB(rawRpm, 150),
    throttleSeries: _downsampleLTTB(rawThrottle, 150),
    oilTempSeries: _downsampleLTTB(rawOilTemp, 150),
    loadSeries: _downsampleLTTB(rawLoad, 150),

    // GPS
    routePoints: gpsPoints,
    hasGpsData: gpsPoints.length >= 2,

    // Metadata
    totalDatapoints: n,
  );
}

double _scrEfficiency(double pre, double post) {
  if (pre <= 0) return 0;
  return ((pre - post) / pre * 100).clamp(0, 100);
}

// ─── LTTB Downsampling ───────────────────────────────────────────────────────

List<TimeSeriesPoint> _downsampleLTTB(List<_RawPt> data, int target) {
  if (data.length <= target) {
    return data.map((p) => TimeSeriesPoint(p.t, p.v)).toList();
  }

  final result = <TimeSeriesPoint>[];
  result.add(TimeSeriesPoint(data.first.t, data.first.v));

  final bucketSize = (data.length - 2) / (target - 2);

  int prevIndex = 0;
  for (int i = 1; i < target - 1; i++) {
    final bucketStart = ((i - 1) * bucketSize + 1).floor();
    final bucketEnd = (i * bucketSize + 1).floor().clamp(0, data.length);

    // Average of next bucket for the triangle target
    final nextBucketStart = (i * bucketSize + 1).floor().clamp(0, data.length);
    final nextBucketEnd =
        ((i + 1) * bucketSize + 1).floor().clamp(0, data.length);
    double avgT = 0, avgV = 0;
    int count = 0;
    for (int j = nextBucketStart; j < nextBucketEnd && j < data.length; j++) {
      avgT += data[j].t;
      avgV += data[j].v;
      count++;
    }
    if (count > 0) {
      avgT /= count;
      avgV /= count;
    }

    // Find point in current bucket with max triangle area
    double maxArea = -1;
    int maxIndex = bucketStart;
    final prevPt = data[prevIndex];
    for (int j = bucketStart; j < bucketEnd && j < data.length; j++) {
      final area = ((prevPt.t - avgT) * (data[j].v - prevPt.v) -
                  (prevPt.t - data[j].t) * (avgV - prevPt.v))
              .abs() *
          0.5;
      if (area > maxArea) {
        maxArea = area;
        maxIndex = j;
      }
    }

    result.add(TimeSeriesPoint(data[maxIndex].t, data[maxIndex].v));
    prevIndex = maxIndex;
  }

  result.add(TimeSeriesPoint(data.last.t, data.last.v));
  return result;
}

// ─── Internal helpers ────────────────────────────────────────────────────────

class _RawPt {
  final double t;
  final double v;
  const _RawPt(this.t, this.v);
}

class _ThermalAcc {
  double min = double.infinity;
  double max = double.negativeInfinity;
  double sum = 0;
  int count = 0;
  double warnSeconds = 0;
  double critSeconds = 0;

  void add(double v, double dtSec, double warnThresh, double critThresh) {
    if (v < min) min = v;
    if (v > max) max = v;
    sum += v;
    count++;
    if (v >= critThresh) {
      critSeconds += dtSec;
    } else if (v >= warnThresh) {
      warnSeconds += dtSec;
    }
  }

  ThermalStats toStats() {
    if (count == 0) return const ThermalStats();
    return ThermalStats(
      min: min,
      max: max,
      avg: sum / count,
      timeAboveWarnSeconds: warnSeconds.round(),
      timeAboveCritSeconds: critSeconds.round(),
      hasData: true,
    );
  }
}

class _Accumulators {
  // Speed
  double speedSum = 0;
  int speedCount = 0;
  double maxSpeed = 0;
  double idleSeconds = 0;

  void addSpeed(double v, double dtSec) {
    speedSum += v;
    speedCount++;
    if (v > maxSpeed) maxSpeed = v;
    if (v < 2) idleSeconds += dtSec; // < 2 mph = idle
  }

  // RPM
  double rpmSum = 0;
  int rpmCount = 0;
  double maxRpm = 0;

  void addRpm(double v, double dtSec) {
    rpmSum += v;
    rpmCount++;
    if (v > maxRpm) maxRpm = v;
  }

  // Boost
  double boostSum = 0;
  int boostCount = 0;
  double maxBoost = 0;

  void addBoost(double v) {
    boostSum += v;
    boostCount++;
    if (v > maxBoost) maxBoost = v;
  }

  // Load
  double loadSum = 0;
  int loadCount = 0;
  double maxLoad = 0;
  double highLoadSeconds = 0;

  void addLoad(double v, double dtSec) {
    loadSum += v;
    loadCount++;
    if (v > maxLoad) maxLoad = v;
    if (v > 70) highLoadSeconds += dtSec;
  }

  // Throttle
  double throttleSum = 0;
  int throttleCount = 0;
  double maxThrottle = 0;

  void addThrottle(double v) {
    throttleSum += v;
    throttleCount++;
    if (v > maxThrottle) maxThrottle = v;
  }

  // Peaks
  double maxTurbo = 0;
  double maxRail = 0;
  double maxHp = 0;
  double maxTorque = 0;

  // Thermals
  final coolant = _ThermalAcc();
  final trans = _ThermalAcc();
  final egtAcc = _ThermalAcc();
  final egt2Acc = _ThermalAcc();
  final egt3Acc = _ThermalAcc();
  final egt4Acc = _ThermalAcc();
  final oilTempAcc = _ThermalAcc();
  final intakeTempAcc = _ThermalAcc();
  final intercoolerTempAcc = _ThermalAcc();

  void addThermal(
      _ThermalAcc a, double? v, double dtSec, double warn, double crit) {
    if (v != null) a.add(v, dtSec, warn, crit);
  }

  // Drivetrain
  int tcLockedMs = 0;
  double vgtSum = 0;
  int vgtCount = 0;
  double egrSum = 0;
  int egrCount = 0;

  void addVgt(double v) {
    vgtSum += v;
    vgtCount++;
  }

  void addEgr(double v) {
    egrSum += v;
    egrCount++;
  }

  // Emissions
  double dpfSootSum = 0;
  int dpfSootCount = 0;
  double maxDpfSoot = 0;

  void addDpfSoot(double v) {
    dpfSootSum += v;
    dpfSootCount++;
    if (v > maxDpfSoot) maxDpfSoot = v;
  }

  double dpfDiffSum = 0;
  int dpfDiffCount = 0;

  void addDpfDiff(double v) {
    dpfDiffSum += v;
    dpfDiffCount++;
  }

  double noxPreSum = 0;
  int noxPreCount = 0;

  void addNoxPre(double v) {
    noxPreSum += v;
    noxPreCount++;
  }

  double noxPostSum = 0;
  int noxPostCount = 0;

  void addNoxPost(double v) {
    noxPostSum += v;
    noxPostCount++;
  }

  double defConsumedMl = 0;

  // System
  double batterySum = 0;
  int batteryCount = 0;
  double minBattery = double.infinity;

  void addBattery(double v) {
    batterySum += v;
    batteryCount++;
    if (v < minBattery) minBattery = v;
  }

  double oilPressureSum = 0;
  int oilPressureCount = 0;
  double minOilPressure = double.infinity;

  void addOilPressure(double v) {
    oilPressureSum += v;
    oilPressureCount++;
    if (v < minOilPressure) minOilPressure = v;
  }

  double crankcaseSum = 0;
  int crankcaseCount = 0;

  void addCrankcase(double v) {
    crankcaseSum += v;
    crankcaseCount++;
  }
}
