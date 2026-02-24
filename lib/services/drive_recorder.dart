import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:myapp/config/constants.dart';
import 'package:myapp/models/datapoint.dart';
import 'package:myapp/models/drive_session.dart';
import 'package:myapp/services/diagnostic_service.dart';
import 'package:myapp/services/location_service.dart';
import 'package:myapp/services/obd_service.dart';
import 'package:myapp/services/timeseries_file.dart';

const _tag = 'REC';

/// Drive session recorder that auto-detects drive start/end and writes
/// datapoints to a local column-oriented timeseries file, then uploads
/// to Firebase Storage after the drive ends.
///
/// Features:
/// - Auto-detect drive start (speed > 5 mph for 5 consecutive seconds)
/// - Auto-detect drive end (speed < 5 mph for 5+ minutes)
/// - Local timeseries file (column-oriented JSON + gzip)
/// - Upload to Firebase Storage after drive
/// - Full parameterStats on drive doc (no raw data in Firestore)
/// - Running statistics (max, min, avg for all parameters)
/// - Derived parameter calculation (instantMPG, estimatedGear)
/// - DPF regen tracking
///
/// Designed for use with Riverpod providers.
class DriveRecorder {
  final ObdService _obdService;
  final LocationService? _locationService;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DriveRecorder({
    required ObdService obdService,
    LocationService? locationService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _obdService = obdService,
        _locationService = locationService,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // ─── State ───

  bool _recording = false;
  bool _disposed = false;
  String? _userId;
  String? _vehicleId;
  String? _driveId;
  DriveSession? _currentSession;

  // Auto-detect state
  bool _autoDetectEnabled = false;
  DateTime? _speedAboveThresholdSince;
  DateTime? _speedBelowThresholdSince;

  // Timeseries writer (replaces Firestore batch buffer)
  TimeseriesWriter? _timeseriesWriter;

  // Data subscription
  StreamSubscription<Map<String, double>>? _dataSubscription;

  // Running statistics
  final Map<String, _RunningStats> _stats = {};
  int _datapointCount = 0;
  double _totalFuelUsed = 0.0;
  double _totalDistance = 0.0;
  DateTime? _recordingStart;
  DateTime? _lastDataTimestamp; // For accurate interval calculation
  int _dpfRegenCount = 0;
  int _dpfRegenSeconds = 0;
  bool _dpfRegenActive = false;
  DateTime? _dpfRegenStart;

  // GPS start/end coordinates for DriveSession
  double? _gpsStartLat;
  double? _gpsStartLng;

  // ─── Public getters ───

  bool get isRecording => _recording;
  String? get currentDriveId => _driveId;
  DriveSession? get currentSession => _currentSession;
  int get datapointCount => _datapointCount;

  /// Finalize any orphaned drives from previous app sessions.
  ///
  /// Handles two cases:
  /// 1. Local timeseries files that need uploading (app killed after finalize
  ///    but before upload).
  /// 2. Drives stuck in "recording" status in Firestore.
  Future<int> finalizeOrphanedDrives(String userId, String vehicleId) async {
    int count = 0;
    try {
      // ── Case 1: Retry pending timeseries uploads ──
      count += await _retryPendingUploads(userId, vehicleId);

      // ── Case 2: Drives stuck in "recording" status ──
      final drivesRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.vehiclesSubcollection)
          .doc(vehicleId)
          .collection(AppConstants.drivesSubcollection);

      final orphans = await drivesRef
          .where('status', isEqualTo: 'recording')
          .get();

      for (final doc in orphans.docs) {
        final data = doc.data();
        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        final driveId = doc.id;
        final now = DateTime.now();
        final duration = startTime != null
            ? now.difference(startTime).inSeconds
            : 0;

        // Check if there's a local timeseries file for this drive
        final localDir = await timeseriesLocalDir;
        final tsFile = File('$localDir/timeseries_$driveId.json.gz');

        if (await tsFile.exists()) {
          // We have local data — upload it and finalize
          final path =
              '${AppConstants.timeseriesStoragePrefix}/$userId/$vehicleId/$driveId/timeseries.json.gz';
          try {
            await _uploadTimeseriesFile(driveId, tsFile, path);
            await doc.reference.update({
              'status': 'uploaded',
              'endTime': FieldValue.serverTimestamp(),
              'durationSeconds': duration,
              'timeseriesPath': path,
              'timeseriesUploaded': true,
            });
            diag.info(_tag, 'Orphan uploaded from local file',
                'driveId=$driveId');
          } catch (e) {
            // Upload failed — mark as orphan with what we have
            await doc.reference.update({
              'status': 'completed_orphan',
              'endTime': FieldValue.serverTimestamp(),
              'durationSeconds': duration,
            });
            diag.warn(_tag, 'Orphan upload failed, marked as completed_orphan',
                'driveId=$driveId error=$e');
          }
        } else {
          // No local file — check legacy datapoints subcollection
          final dpSnap = await drivesRef
              .doc(driveId)
              .collection(AppConstants.datapointsSubcollection)
              .get();

          final dpCount = dpSnap.size;
          if (dpSnap.docs.isNotEmpty) {
            final firstTs = dpSnap.docs.first.data()['timestamp'] as int?;
            final lastTs = dpSnap.docs.last.data()['timestamp'] as int?;
            if (firstTs != null && lastTs != null) {
              final actualDuration = ((lastTs - firstTs) / 1000).round();
              await doc.reference.update({
                'status': 'completed_orphan',
                'endTime': FieldValue.serverTimestamp(),
                'durationSeconds': actualDuration,
                'datapointCount': dpCount,
              });
            } else {
              await doc.reference.update({
                'status': 'completed_orphan',
                'endTime': FieldValue.serverTimestamp(),
                'durationSeconds': duration,
                'datapointCount': dpCount,
              });
            }
          } else {
            await doc.reference.update({
              'status': 'completed_empty',
              'endTime': FieldValue.serverTimestamp(),
              'durationSeconds': 0,
            });
          }
        }

        count++;
        diag.info(_tag, 'Finalized orphaned drive',
            'driveId=$driveId startTime=$startTime');
      }

      if (count > 0) {
        diag.warn(_tag, 'Finalized $count orphaned drive(s)',
            'These were stuck in "recording" from a previous session');
      }
    } catch (e) {
      diag.error(_tag, 'Failed to finalize orphaned drives', '$e');
    }
    return count;
  }

  /// Retry uploading timeseries files for drives with timeseriesUploaded=false.
  Future<int> _retryPendingUploads(String userId, String vehicleId) async {
    int count = 0;
    try {
      final drivesRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.vehiclesSubcollection)
          .doc(vehicleId)
          .collection(AppConstants.drivesSubcollection);

      final pending = await drivesRef
          .where('timeseriesUploaded', isEqualTo: false)
          .where('status', isEqualTo: 'pendingUpload')
          .get();

      for (final doc in pending.docs) {
        final driveId = doc.id;
        final localDir = await timeseriesLocalDir;
        final tsFile = File('$localDir/timeseries_$driveId.json.gz');

        if (await tsFile.exists()) {
          final path =
              '${AppConstants.timeseriesStoragePrefix}/$userId/$vehicleId/$driveId/timeseries.json.gz';
          try {
            await _uploadTimeseriesFile(driveId, tsFile, path);
            await doc.reference.update({
              'timeseriesUploaded': true,
              'timeseriesPath': path,
              'status': 'uploaded',
            });
            count++;
            diag.info(_tag, 'Retry upload succeeded', 'driveId=$driveId');
          } catch (e) {
            diag.warn(_tag, 'Retry upload failed', 'driveId=$driveId error=$e');
          }
        }
      }
    } catch (e) {
      diag.error(_tag, 'Failed to retry pending uploads', '$e');
    }
    return count;
  }

  /// Current running statistics for each parameter.
  Map<String, Map<String, double>> get statistics {
    final result = <String, Map<String, double>>{};
    for (final entry in _stats.entries) {
      result[entry.key] = {
        'min': entry.value.min,
        'max': entry.value.max,
        'avg': entry.value.average,
        'count': entry.value.count.toDouble(),
      };
    }
    return result;
  }

  // ─── Auto-Detection ───

  /// Enable auto-detection of drive start and end.
  ///
  /// Listens to OBD data stream and automatically starts recording when
  /// vehicle speed exceeds threshold, stops when idling for too long.
  void enableAutoDetect(String userId, String vehicleId) {
    _userId = userId;
    _vehicleId = vehicleId;
    _autoDetectEnabled = true;
    _speedAboveThresholdSince = null;
    _speedBelowThresholdSince = null;

    _dataSubscription?.cancel();
    _dataSubscription = _obdService.dataStream.listen(_onDataForAutoDetect);
  }

  /// Disable auto-detection.
  void disableAutoDetect() {
    _autoDetectEnabled = false;
    // Don't cancel the data subscription if we're recording
    if (!_recording) {
      _dataSubscription?.cancel();
    }
  }

  // ─── Recording ───

  /// Start recording a drive session manually.
  ///
  /// Creates the drive document in Firestore and begins writing datapoints
  /// to a local timeseries file.
  /// Returns null if OBD adapter is not connected — only real data is recorded.
  Future<String?> startRecording(String vehicleId, {String? userId}) async {
    if (_recording) return _driveId;
    if (_disposed) return null;

    // SAFETY: Only record when the real OBD adapter is connected.
    if (!_obdService.isConnected) return null;

    _userId = userId ?? _userId;
    _vehicleId = vehicleId;

    if (_userId == null) {
      return null;
    }

    _recording = true;
    _datapointCount = 0;
    _totalFuelUsed = 0.0;
    _totalDistance = 0.0;
    _stats.clear();
    _dpfRegenCount = 0;
    _dpfRegenSeconds = 0;
    _dpfRegenActive = false;
    _recordingStart = DateTime.now();
    _lastDataTimestamp = null;
    _gpsStartLat = null;
    _gpsStartLng = null;

    // Start GPS tracking (best-effort — recording works without GPS)
    _locationService?.startTracking();

    try {
      // Create drive session document in Firestore
      final session = DriveSession(
        id: '', // Will be set by Firestore
        vehicleId: vehicleId,
        startTime: _recordingStart!,
        status: DriveStatus.recording,
        startOdometer: _obdService.liveData['odometer'] ?? 0,
      );

      final docRef = await _driveDocCollection().add(session.toFirestore());
      _driveId = docRef.id;
      _currentSession = session.copyWith(id: _driveId);
      diag.info(_tag, 'Drive session created', 'driveId=$_driveId vehicle=$vehicleId');

      // Open timeseries writer for local file accumulation
      _timeseriesWriter = TimeseriesWriter();
      await _timeseriesWriter!.open(_driveId!);

      // Subscribe to OBD data if not already subscribed
      _dataSubscription?.cancel();
      _dataSubscription = _obdService.dataStream.listen(_onDataForRecording);

      // Enable auto-detect drive end (speed < 5 mph for 5+ minutes).
      // This ensures the drive is finalized even if BT stays connected
      // while the engine is off (OBDLink MX+ stays powered on pin 16).
      _autoDetectEnabled = true;

      return _driveId;
    } catch (e) {
      _recording = false;
      _driveId = null;
      _currentSession = null;
      _timeseriesWriter = null;
      rethrow;
    }
  }

  /// Stop recording and finalize the drive session.
  ///
  /// Finalizes the local timeseries file, computes full parameterStats,
  /// updates the drive document, and uploads to Firebase Storage in background.
  Future<void> stopRecording() async {
    if (!_recording || _driveId == null) {
      diag.warn(_tag, 'stopRecording called but not recording',
          'recording=$_recording driveId=$_driveId');
      return;
    }

    final driveId = _driveId!;
    diag.info(_tag, 'Stopping drive recording',
        'driveId=$driveId pts=$_datapointCount');

    _recording = false;

    // Finalize the timeseries file
    File? tsFile;
    try {
      if (_timeseriesWriter != null && _timeseriesWriter!.rowCount > 0) {
        tsFile = await _timeseriesWriter!.finalize();
      }
    } catch (e) {
      diag.error(_tag, 'Timeseries finalize failed', '$e');
    }

    // Finalize DPF regen if still active
    if (_dpfRegenActive && _dpfRegenStart != null) {
      _dpfRegenSeconds +=
          DateTime.now().difference(_dpfRegenStart!).inSeconds;
      _dpfRegenActive = false;
    }

    // Calculate final session data
    final now = DateTime.now();
    final durationSeconds = _recordingStart != null
        ? now.difference(_recordingStart!).inSeconds
        : 0;

    final avgMpg = _totalFuelUsed > 0
        ? _totalDistance / _totalFuelUsed
        : 0.0;

    // Build full parameterStats from running stats
    final paramStats = statistics; // Uses the public getter

    // Build sensor list
    final activeSensors = _timeseriesWriter?.sensorList ??
        _stats.entries
            .where((e) => e.value.count > 0)
            .map((e) => e.key)
            .toList()
      ..sort();

    // Pre-compute storage path
    final storagePath =
        '${AppConstants.timeseriesStoragePrefix}/$_userId/$_vehicleId/$driveId/timeseries.json.gz';

    diag.info(_tag, 'Drive summary',
        'dur=${durationSeconds}s dist=${_totalDistance.toStringAsFixed(1)}mi '
        'mpg=${avgMpg.toStringAsFixed(1)} fuel=${_totalFuelUsed.toStringAsFixed(2)}gal '
        'pts=$_datapointCount sensors=${activeSensors.length}');
    diag.debug(_tag, 'Active sensors', activeSensors.join(', '));

    // Capture GPS end coordinates from last known position
    final gpsEndPos = _locationService?.lastPosition;
    final gpsEndLat = gpsEndPos?.latitude;
    final gpsEndLng = gpsEndPos?.longitude;

    // Stop GPS tracking
    _locationService?.stopTracking();

    final updatedSession = _currentSession?.copyWith(
      endTime: now,
      durationSeconds: durationSeconds,
      endOdometer: _obdService.liveData['odometer'],
      distanceMiles: _totalDistance,
      fuelUsedGallons: _totalFuelUsed,
      averageMPG: avgMpg,
      instantMPGMin: _stats['instantMPG']?.min,
      instantMPGMax: _stats['instantMPG']?.max,
      maxBoostPsi: _stats['boostPressureCtrl']?.max,
      maxEgtF: _stats['egtObd2']?.max,
      maxCoolantTempF: _stats['coolantTemp']?.max,
      maxTransTempF: null, // Trans temp was J1939-only, unavailable via OBD2
      maxOilTempF: null, // Oil temp was J1939-only, unavailable via OBD2
      maxTurboSpeedRpm: null, // Turbo speed was J1939-only, unavailable via OBD2
      maxRailPressurePsi: _stats['railPressure']?.max,
      avgBoost: _stats['boostPressureCtrl']?.average,
      avgEgt: _stats['egtObd2']?.average,
      avgCoolant: _stats['coolantTemp']?.average,
      avgTrans: null,
      avgLoad: _stats['engineLoadObd2']?.average,
      avgRpm: _stats['rpm']?.average,
      dpfRegenOccurred: _dpfRegenCount > 0,
      dpfRegenCount: _dpfRegenCount,
      dpfRegenDurationSeconds: _dpfRegenSeconds,
      gpsStartLat: _gpsStartLat,
      gpsStartLng: _gpsStartLng,
      gpsEndLat: gpsEndLat,
      gpsEndLng: gpsEndLng,
      status: DriveStatus.pendingUpload,
      timeseriesPath: storagePath,
      timeseriesUploaded: false,
      datapointCount: _datapointCount,
      sensorList: activeSensors,
      parameterStats: paramStats,
    );

    // Update Firestore document — retry once on failure
    bool updated = false;
    for (int attempt = 0; attempt < 2 && !updated; attempt++) {
      try {
        if (updatedSession != null) {
          await _driveDocCollection().doc(driveId).update(
                updatedSession.toFirestore(),
              );
          updated = true;
          diag.info(_tag, 'Drive finalized in Firestore',
              'driveId=$driveId status=pendingUpload');
        } else {
          // Safety: even if session is null, at least mark the drive as ended
          await _driveDocCollection().doc(driveId).update({
            'status': 'pendingUpload',
            'endTime': Timestamp.fromDate(now),
            'durationSeconds': durationSeconds,
            'datapointCount': _datapointCount,
            'parameterStats': paramStats,
            'sensorList': activeSensors,
            'timeseriesPath': storagePath,
            'timeseriesUploaded': false,
          });
          updated = true;
          diag.warn(_tag, 'Drive finalized with minimal data (session was null)',
              'driveId=$driveId');
        }
      } catch (e) {
        if (attempt == 0) {
          diag.warn(_tag, 'Drive finalize attempt 1 failed, retrying', '$e');
          await Future<void>.delayed(const Duration(seconds: 1));
        } else {
          diag.error(_tag, 'Drive finalize FAILED after 2 attempts',
              'driveId=$driveId error=$e — drive may be orphaned');
        }
      }
    }

    // Upload timeseries to Firebase Storage in background (don't block stop)
    if (tsFile != null) {
      _uploadTimeseries(driveId, tsFile, storagePath);
    }

    // Reset state
    _currentSession = updatedSession;
    _driveId = null;
    _timeseriesWriter = null;
    _speedBelowThresholdSince = null;

    // Re-subscribe for auto-detect if enabled
    if (_autoDetectEnabled && _vehicleId != null) {
      _dataSubscription?.cancel();
      _dataSubscription = _obdService.dataStream.listen(_onDataForAutoDetect);
    } else {
      _dataSubscription?.cancel();
    }
  }

  // ─── Lifecycle ───

  void dispose() {
    _disposed = true;
    _recording = false;
    _autoDetectEnabled = false;
    _dataSubscription?.cancel();
    _locationService?.stopTracking();
  }

  // ─── Private: Auto-Detect Logic ───

  void _onDataForAutoDetect(Map<String, double> data) {
    if (_disposed || !_autoDetectEnabled) return;
    // SAFETY: Only auto-detect drives from real OBD data.
    if (!_obdService.isConnected) return;

    final speed = data['speed'] ?? 0.0;

    if (!_recording) {
      // Detect drive start: speed above threshold for 5 seconds
      if (speed > AppConstants.driveStartSpeedThreshold) {
        _speedAboveThresholdSince ??= DateTime.now();
        final elapsed =
            DateTime.now().difference(_speedAboveThresholdSince!).inSeconds;
        if (elapsed >= 5 && _vehicleId != null) {
          _speedAboveThresholdSince = null;
          startRecording(_vehicleId!);
        }
      } else {
        _speedAboveThresholdSince = null;
      }
    } else {
      // Detect drive end: speed below threshold for 5+ minutes
      if (speed < AppConstants.driveStartSpeedThreshold) {
        _speedBelowThresholdSince ??= DateTime.now();
        final elapsed =
            DateTime.now().difference(_speedBelowThresholdSince!).inMinutes;
        if (elapsed >= AppConstants.driveEndIdleMinutes) {
          _speedBelowThresholdSince = null;
          stopRecording();
        }
      } else {
        _speedBelowThresholdSince = null;
      }
    }
  }

  // ─── Private: Data Recording ───

  void _onDataForRecording(Map<String, double> data) {
    if (_disposed || !_recording) return;

    // Update running statistics
    for (final entry in data.entries) {
      _stats.putIfAbsent(entry.key, () => _RunningStats());
      _stats[entry.key]!.add(entry.value);
    }

    // Calculate derived parameters
    final derivedData = Map<String, double>.from(data);
    _calculateDerived(derivedData);

    // Track fuel usage and distance
    _trackAccumulators(derivedData);

    // Track DPF regen
    _trackDpfRegen(derivedData);

    // Create datapoint and add to timeseries writer
    final dp = _createDataPoint(derivedData);
    _timeseriesWriter?.addDatapoint(dp);
    _datapointCount++;

    // Log with sensor coverage info for debugging
    if (_datapointCount == 1) {
      final nonNull = derivedData.entries
          .where((e) => e.value != 0.0 || e.key == 'speed' || e.key == 'rpm')
          .map((e) => e.key)
          .toList()..sort();
      diag.info(_tag, 'First datapoint captured',
          '${derivedData.length} sensors, active: ${nonNull.join(", ")}');
    } else if (_datapointCount % 100 == 0) {
      final sensorCount = _stats.entries.where((e) => e.value.count > 0).length;
      diag.debug(_tag, 'Recording: $_datapointCount pts',
          'sensors=$sensorCount '
          'dist=${_totalDistance.toStringAsFixed(1)}mi');
    }

    // Also handle auto-detect end while recording
    if (_autoDetectEnabled) {
      _onDataForAutoDetect(data);
    }
  }

  void _calculateDerived(Map<String, double> data) {
    // Instant MPG = speed / (fuelRate * some conversion)
    // fuelRate is in gph, speed is in mph
    // MPG = mph / gph
    final speed = data['speed'];
    final fuelRate = data['fuelRate'];

    if (speed != null && fuelRate != null && fuelRate > 0.1) {
      final instantMpg = speed / fuelRate;
      // Clamp to reasonable range (0-99 mpg for a diesel truck)
      data['instantMPG'] = instantMpg.clamp(0.0, 99.0);
      _stats.putIfAbsent('instantMPG', () => _RunningStats());
      _stats['instantMPG']!.add(data['instantMPG']!);
    }

    // Estimated gear from speed and RPM
    final rpm = data['rpm'] ?? data['engineSpeed'];
    if (speed != null && rpm != null && speed > 5 && rpm > 300) {
      final ratio = rpm / speed;
      int gear;
      if (ratio > 32) {
        gear = 1;
      } else if (ratio > 19) {
        gear = 2;
      } else if (ratio > 12) {
        gear = 3;
      } else if (ratio > 8.5) {
        gear = 4;
      } else if (ratio > 6.5) {
        gear = 5;
      } else if (ratio > 5.0) {
        gear = 6;
      } else {
        gear = 6; // Overdrive or lockup
      }
      data['estimatedGear'] = gear.toDouble();
    }
  }

  void _trackAccumulators(Map<String, double> data) {
    final fuelRate = data['fuelRate'];
    final speed = data['speed'];

    // Use actual elapsed time between data emissions for accuracy.
    final now = DateTime.now();
    final dt = _lastDataTimestamp != null
        ? now.difference(_lastDataTimestamp!).inMilliseconds / 1000.0
        : 0.5; // First point: assume half-second
    // Clamp to prevent huge jumps from gaps (reconnects, pauses, etc.)
    final dtClamped = dt.clamp(0.05, 15.0);
    _lastDataTimestamp = now;

    // Accumulate fuel usage: gph x elapsed seconds / 3600 = gallons
    if (fuelRate != null && fuelRate > 0) {
      _totalFuelUsed += fuelRate / 3600.0 * dtClamped;
    }

    // Accumulate distance: mph x elapsed seconds / 3600 = miles
    if (speed != null && speed > 0) {
      _totalDistance += speed / 3600.0 * dtClamped;
    }
  }

  void _trackDpfRegen(Map<String, double> data) {
    final regenStatus = data['dpfRegenStatus'];
    if (regenStatus == null) return;

    final isActive = regenStatus >= 1 && regenStatus <= 2;

    if (isActive && !_dpfRegenActive) {
      // Regen just started
      _dpfRegenActive = true;
      _dpfRegenStart = DateTime.now();
      _dpfRegenCount++;
    } else if (!isActive && _dpfRegenActive) {
      // Regen just ended
      _dpfRegenActive = false;
      if (_dpfRegenStart != null) {
        _dpfRegenSeconds +=
            DateTime.now().difference(_dpfRegenStart!).inSeconds;
      }
    }
  }

  /// Canonical parameter resolution — defines which live data keys are
  /// preferred for each DataPoint field when multiple sources exist.
  static const _paramResolution = <String, List<String>>{
    'rpm': ['rpm'],
    'speed': ['speed'],
    'coolantTemp': ['coolantTemp'],
    'engineLoad': ['engineLoadObd2'],
    'egt': ['egtObd2'],
    'batteryVoltage': ['batteryVoltage'],
  };

  /// Resolve a canonical parameter from multiple possible source keys.
  static double? _resolve(Map<String, double> data, String canonical) {
    final sources = _paramResolution[canonical];
    if (sources == null) return data[canonical];
    for (final key in sources) {
      final v = data[key];
      if (v != null) return v;
    }
    return null;
  }

  DataPoint _createDataPoint(Map<String, double> data) {
    // Read latest GPS position (synchronous — updated by LocationService stream)
    final gpsPos = _locationService?.lastPosition;

    // Capture start coordinates from first GPS fix
    if (gpsPos != null && _gpsStartLat == null) {
      _gpsStartLat = gpsPos.latitude;
      _gpsStartLng = gpsPos.longitude;
      diag.info(_tag, 'GPS start position captured',
          'lat=${gpsPos.latitude.toStringAsFixed(5)} '
          'lng=${gpsPos.longitude.toStringAsFixed(5)}');
    }

    return DataPoint(
      id: '', // Assigned locally, not from Firestore
      timestamp: DateTime.now().millisecondsSinceEpoch,
      // Resolved (multi-source) parameters
      rpm: _resolve(data, 'rpm'),
      speed: _resolve(data, 'speed'),
      coolantTemp: _resolve(data, 'coolantTemp'),
      oilTemp: _resolve(data, 'oilTemp'),
      engineLoad: _resolve(data, 'engineLoad'),
      fuelRate: _resolve(data, 'fuelRate'),
      barometric: _resolve(data, 'barometric'),
      egt: _resolve(data, 'egt'),
      batteryVoltage: _resolve(data, 'batteryVoltage'),
      // Single-source parameters
      intakeTemp: data['intakeTemp'],
      maf: data['maf'],
      boostPressure: data['boostPressure'],
      egt2: data['egt2'],
      egt3: data['egt3'],
      egt4: data['egt4'],
      transTemp: data['transTemp'],
      oilPressure: data['oilPressure'],
      turboSpeed: data['turboSpeed'],
      vgtPosition: data['vgtPosition'],
      egrPosition: data['egrPosition'],
      dpfSootLoad: data['dpfSootLoad'],
      dpfRegenStatus: data['dpfRegenStatus'],
      dpfDiffPressure: data['dpfDiffPressure'],
      noxPreScr: data['noxPreScr'],
      noxPostScr: data['noxPostScr'],
      defLevel: data['defLevel'],
      defTemp: data['defTemp'],
      defDosingRate: data['defDosingRate'],
      defQuality: data['defQuality'],
      railPressure: data['railPressure'],
      crankcasePressure: data['crankcasePressure'],
      coolantLevel: data['coolantLevel'],
      intercoolerOutletTemp: data['intercoolerOutletTemp'],
      exhaustBackpressure: data['exhaustBackpressure'],
      fuelLevel: data['fuelLevel'],
      ambientTemp: data['ambientTemp'],
      odometer: data['odometer'],
      engineHours: data['engineHours'],
      gearRatio: data['gearRatio'],
      // New diesel-specific OBD2 parameters
      accelPedalD: data['accelPedalD'],
      demandTorque: data['demandTorque'],
      actualTorque: data['actualTorque'],
      referenceTorque: data['referenceTorque'],
      commandedEgr: data['commandedEgr'],
      commandedThrottle: data['commandedThrottle'],
      boostPressureCtrl: data['boostPressureCtrl'],
      vgtControlObd: data['vgtControlObd'],
      turboInletPressure: data['turboInletPressure'],
      turboInletTemp: data['turboInletTemp'],
      chargeAirTemp: data['chargeAirTemp'],
      egtObd2: data['egtObd2'],
      dpfTemp: data['dpfTemp'],
      runtimeExtended: data['runtimeExtended'],
      // GPS
      lat: gpsPos?.latitude,
      lng: gpsPos?.longitude,
      altitude: gpsPos?.altitude,
      gpsSpeed: gpsPos != null ? gpsPos.speed * 2.23694 : null, // m/s → mph
      heading: gpsPos?.heading,
      // Calculated
      instantMPG: data['instantMPG'],
      estimatedGear: data['estimatedGear'],
    );
  }

  // ─── Private: Firebase Storage Upload ───

  /// Upload timeseries file to Firebase Storage and update drive doc.
  /// Runs asynchronously — does not block stopRecording().
  Future<void> _uploadTimeseries(
      String driveId, File file, String storagePath) async {
    try {
      await _uploadTimeseriesFile(driveId, file, storagePath);

      // Update drive doc to mark upload complete
      await _driveDocCollection().doc(driveId).update({
        'timeseriesUploaded': true,
        'status': 'uploaded',
      });

      // Clean up local file after successful upload
      try {
        await file.delete();
      } catch (_) {}

      diag.info(_tag, 'Timeseries uploaded',
          'driveId=$driveId path=$storagePath');
    } catch (e) {
      diag.error(_tag, 'Timeseries upload failed (will retry on next launch)',
          'driveId=$driveId error=$e');
      // File stays on disk — _retryPendingUploads will pick it up
    }
  }

  /// Raw file upload to Firebase Storage.
  Future<void> _uploadTimeseriesFile(
      String driveId, File file, String storagePath) async {
    final ref = _storage.ref().child(storagePath);
    await ref.putFile(
      file,
      SettableMetadata(
        contentType: 'application/gzip',
        customMetadata: {'version': '1', 'driveId': driveId},
      ),
    );
  }

  // ─── Private: Firestore Paths ───

  CollectionReference _driveDocCollection() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(_userId)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(_vehicleId)
        .collection(AppConstants.drivesSubcollection);
  }
}

/// Running statistics tracker for a single parameter.
class _RunningStats {
  double min = double.infinity;
  double max = double.negativeInfinity;
  double _sum = 0.0;
  int count = 0;

  void add(double value) {
    if (value < min) min = value;
    if (value > max) max = value;
    _sum += value;
    count++;
  }

  double get average => count > 0 ? _sum / count : 0.0;
}
