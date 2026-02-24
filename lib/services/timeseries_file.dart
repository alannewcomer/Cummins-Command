import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:myapp/models/datapoint.dart';
import 'package:myapp/services/diagnostic_service.dart';
import 'package:path_provider/path_provider.dart';

const _tag = 'TS';

/// All DataPoint fields that can be stored as timeseries columns.
/// Order must be stable — used for both writing and reading.
const _columnFields = [
  'rpm', 'speed', 'coolantTemp', 'intakeTemp', 'maf', 'throttlePos',
  'boostPressure', 'egt', 'egt2', 'egt3', 'egt4', 'transTemp', 'oilTemp',
  'oilPressure', 'engineLoad', 'turboSpeed', 'vgtPosition', 'egrPosition',
  'dpfSootLoad', 'dpfRegenStatus', 'dpfDiffPressure', 'noxPreScr',
  'noxPostScr', 'defLevel', 'defTemp', 'defDosingRate', 'defQuality',
  'railPressure', 'crankcasePressure', 'coolantLevel', 'intercoolerOutletTemp',
  'exhaustBackpressure', 'fuelRate', 'fuelLevel', 'batteryVoltage',
  'ambientTemp', 'barometric', 'odometer', 'engineHours', 'gearRatio',
  'accelPedalD', 'demandTorque', 'actualTorque', 'referenceTorque',
  'commandedEgr', 'commandedThrottle', 'boostPressureCtrl', 'vgtControlObd',
  'turboInletPressure', 'turboInletTemp', 'chargeAirTemp', 'egtObd2',
  'dpfTemp', 'runtimeExtended', 'lat', 'lng', 'altitude', 'gpsSpeed',
  'heading', 'instantMPG', 'estimatedGear', 'estimatedHP', 'estimatedTorque',
];

/// Extract a named field value from a DataPoint.
double? _getField(DataPoint dp, String field) {
  switch (field) {
    case 'rpm': return dp.rpm;
    case 'speed': return dp.speed;
    case 'coolantTemp': return dp.coolantTemp;
    case 'intakeTemp': return dp.intakeTemp;
    case 'maf': return dp.maf;
    case 'throttlePos': return dp.throttlePos;
    case 'boostPressure': return dp.boostPressure;
    case 'egt': return dp.egt;
    case 'egt2': return dp.egt2;
    case 'egt3': return dp.egt3;
    case 'egt4': return dp.egt4;
    case 'transTemp': return dp.transTemp;
    case 'oilTemp': return dp.oilTemp;
    case 'oilPressure': return dp.oilPressure;
    case 'engineLoad': return dp.engineLoad;
    case 'turboSpeed': return dp.turboSpeed;
    case 'vgtPosition': return dp.vgtPosition;
    case 'egrPosition': return dp.egrPosition;
    case 'dpfSootLoad': return dp.dpfSootLoad;
    case 'dpfRegenStatus': return dp.dpfRegenStatus;
    case 'dpfDiffPressure': return dp.dpfDiffPressure;
    case 'noxPreScr': return dp.noxPreScr;
    case 'noxPostScr': return dp.noxPostScr;
    case 'defLevel': return dp.defLevel;
    case 'defTemp': return dp.defTemp;
    case 'defDosingRate': return dp.defDosingRate;
    case 'defQuality': return dp.defQuality;
    case 'railPressure': return dp.railPressure;
    case 'crankcasePressure': return dp.crankcasePressure;
    case 'coolantLevel': return dp.coolantLevel;
    case 'intercoolerOutletTemp': return dp.intercoolerOutletTemp;
    case 'exhaustBackpressure': return dp.exhaustBackpressure;
    case 'fuelRate': return dp.fuelRate;
    case 'fuelLevel': return dp.fuelLevel;
    case 'batteryVoltage': return dp.batteryVoltage;
    case 'ambientTemp': return dp.ambientTemp;
    case 'barometric': return dp.barometric;
    case 'odometer': return dp.odometer;
    case 'engineHours': return dp.engineHours;
    case 'gearRatio': return dp.gearRatio;
    case 'accelPedalD': return dp.accelPedalD;
    case 'demandTorque': return dp.demandTorque;
    case 'actualTorque': return dp.actualTorque;
    case 'referenceTorque': return dp.referenceTorque;
    case 'commandedEgr': return dp.commandedEgr;
    case 'commandedThrottle': return dp.commandedThrottle;
    case 'boostPressureCtrl': return dp.boostPressureCtrl;
    case 'vgtControlObd': return dp.vgtControlObd;
    case 'turboInletPressure': return dp.turboInletPressure;
    case 'turboInletTemp': return dp.turboInletTemp;
    case 'chargeAirTemp': return dp.chargeAirTemp;
    case 'egtObd2': return dp.egtObd2;
    case 'dpfTemp': return dp.dpfTemp;
    case 'runtimeExtended': return dp.runtimeExtended;
    case 'lat': return dp.lat;
    case 'lng': return dp.lng;
    case 'altitude': return dp.altitude;
    case 'gpsSpeed': return dp.gpsSpeed;
    case 'heading': return dp.heading;
    case 'instantMPG': return dp.instantMPG;
    case 'estimatedGear': return dp.estimatedGear;
    case 'estimatedHP': return dp.estimatedHP;
    case 'estimatedTorque': return dp.estimatedTorque;
    default: return null;
  }
}

// ─── Writer ──────────────────────────────────────────────────────────────────

/// Accumulates DataPoints in memory during a drive, then writes a
/// column-oriented gzip'd JSON file to local storage.
class TimeseriesWriter {
  final List<int> _timestamps = [];
  final Map<String, List<double?>> _columns = {};
  String? _filePath;

  /// Create local file path for this drive.
  Future<void> open(String driveId) async {
    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/timeseries_$driveId.json.gz';
    _timestamps.clear();
    _columns.clear();
    diag.debug(_tag, 'TimeseriesWriter opened', 'path=$_filePath');
  }

  /// Append a single DataPoint to the in-memory columns.
  void addDatapoint(DataPoint dp) {
    _timestamps.add(dp.timestamp);

    for (final field in _columnFields) {
      final value = _getField(dp, field);
      // Only create column list if we've seen at least one non-null value
      final col = _columns[field];
      if (col != null) {
        col.add(value);
      } else if (value != null) {
        // First non-null value for this column — backfill with nulls
        _columns[field] = List<double?>.filled(_timestamps.length - 1, null, growable: true)
          ..add(value);
      }
    }
  }

  /// Encode to column-oriented JSON, gzip, and write to local file.
  /// Returns the file for upload.
  Future<File> finalize() async {
    if (_filePath == null) {
      throw StateError('TimeseriesWriter not opened — call open() first');
    }

    // Pad any short columns to match timestamp length
    for (final col in _columns.values) {
      while (col.length < _timestamps.length) {
        col.add(null);
      }
    }

    // Build column-oriented JSON
    final payload = <String, dynamic>{
      'v': 1,
      'count': _timestamps.length,
      'columns': <String, dynamic>{
        'timestamp': _timestamps,
        for (final entry in _columns.entries) entry.key: entry.value,
      },
    };

    final jsonBytes = utf8.encode(jsonEncode(payload));
    final compressed = gzip.encode(jsonBytes);

    final file = File(_filePath!);
    await file.writeAsBytes(compressed);

    final ratio = jsonBytes.isNotEmpty
        ? (compressed.length / jsonBytes.length * 100).toStringAsFixed(1)
        : '0';
    diag.info(_tag, 'Timeseries finalized',
        'rows=${_timestamps.length} cols=${_columns.length} '
        'json=${jsonBytes.length}B gz=${compressed.length}B ($ratio%)');

    return file;
  }

  int get rowCount => _timestamps.length;

  /// Column names that had at least one non-null value.
  List<String> get sensorList => _columns.keys.toList()..sort();
}

// ─── Reader ──────────────────────────────────────────────────────────────────

/// Reads and decodes column-oriented gzip'd JSON timeseries files.
class TimeseriesReader {
  /// Download from Firebase Storage, decompress, decode to DataPoints.
  /// Caches the downloaded file in temp directory.
  static Future<List<DataPoint>> fromStorage(String storagePath) async {
    final tempDir = await getTemporaryDirectory();
    final cacheFile = File(
        '${tempDir.path}/ts_${storagePath.hashCode.toRadixString(16)}.json.gz');

    if (await cacheFile.exists()) {
      diag.debug(_tag, 'Reading cached timeseries', cacheFile.path);
      return fromLocalFile(cacheFile.path);
    }

    diag.info(_tag, 'Downloading timeseries', storagePath);
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    await ref.writeToFile(cacheFile);
    return fromLocalFile(cacheFile.path);
  }

  /// Read from a local gzip'd JSON file.
  static Future<List<DataPoint>> fromLocalFile(String filePath) async {
    final file = File(filePath);
    final compressed = await file.readAsBytes();
    return _decode(compressed);
  }

  /// Decompress + decode column-oriented JSON into a list of DataPoints.
  static List<DataPoint> _decode(List<int> compressed) {
    final decompressed = gzip.decode(compressed);
    final decoded = jsonDecode(utf8.decode(decompressed));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Timeseries root is not a JSON object');
    }
    final count = decoded['count'];
    if (count is! int || count < 0) {
      throw const FormatException('Timeseries count is missing or invalid');
    }
    final columns = decoded['columns'];
    if (columns is! Map<String, dynamic>) {
      throw const FormatException('Timeseries columns is missing or invalid');
    }
    final rawTimestamps = columns['timestamp'];
    if (rawTimestamps is! List) {
      throw const FormatException('Timeseries timestamps is missing or invalid');
    }
    final timestamps = <int>[];
    for (final v in rawTimestamps) {
      if (v is int) {
        timestamps.add(v);
      } else if (v is num) {
        timestamps.add(v.toInt());
      } else {
        throw FormatException('Non-numeric timestamp value: $v');
      }
    }

    final points = <DataPoint>[];
    for (int i = 0; i < count; i++) {
      final map = <String, dynamic>{
        'timestamp': timestamps[i],
      };
      for (final field in _columnFields) {
        final col = columns[field];
        if (col is List && i < col.length && col[i] != null) {
          final val = col[i];
          if (val is num) {
            map[field] = val.toDouble();
          }
        }
      }
      points.add(DataPoint.fromMap('ts_$i', map));
    }

    diag.debug(_tag, 'Decoded timeseries', '${points.length} datapoints');
    return points;
  }
}

/// Returns the local timeseries directory for orphan recovery.
Future<String> get timeseriesLocalDir async {
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}
