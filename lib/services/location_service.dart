import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:myapp/services/diagnostic_service.dart';

const _tag = 'GPS';

/// Wraps the `geolocator` package to provide a position stream for drive
/// recording. Reads device GPS at ~1 Hz with a 5 m distance filter.
///
/// [DriveRecorder] reads [lastPosition] synchronously on each OBD data tick
/// to populate GPS fields on datapoints.
class LocationService {
  Position? _lastPosition;
  StreamSubscription<Position>? _positionSubscription;
  bool _tracking = false;

  /// Most recent GPS fix — read synchronously by DriveRecorder.
  Position? get lastPosition => _lastPosition;

  /// Whether the position stream is currently active.
  bool get isTracking => _tracking;

  /// Request location permission and start the position stream.
  ///
  /// Returns `true` if GPS is active, `false` if permission was denied or
  /// location services are unavailable. Drive recording continues without
  /// GPS in that case — no error is thrown.
  Future<bool> startTracking() async {
    if (_tracking) return true;

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      diag.warn(_tag, 'Location services disabled',
          'Drive will record without GPS. Enable GPS in device settings.');
      return false;
    }

    // Check / request permission (should already be granted at app startup,
    // but handle edge case where user revoked it)
    var permission = await Geolocator.checkPermission();
    diag.info(_tag, 'GPS permission check', '$permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        diag.warn(_tag, 'Location permission denied',
            'Drive will record without GPS');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      diag.warn(_tag, 'Location permission permanently denied',
          'Open Settings > Apps > Cummins Command > Permissions to grant location');
      return false;
    }

    // Get an initial position fix before starting the stream so the first
    // datapoint has GPS data immediately
    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 5));
      diag.info(_tag, 'Initial GPS fix acquired',
          'lat=${_lastPosition!.latitude.toStringAsFixed(5)} '
          'lng=${_lastPosition!.longitude.toStringAsFixed(5)}');
    } catch (e) {
      diag.warn(_tag, 'Initial GPS fix timed out', '$e — will use stream');
    }

    // Start position stream
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (position) {
        _lastPosition = position;
      },
      onError: (Object error) {
        diag.warn(_tag, 'Position stream error', '$error');
      },
    );

    _tracking = true;
    diag.info(_tag, 'GPS tracking started',
        'accuracy=high distanceFilter=5m permission=$permission');
    return true;
  }

  /// Stop the position stream and clear the last known position.
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _lastPosition = null;
    _tracking = false;
    diag.info(_tag, 'GPS tracking stopped');
  }

  /// Release resources.
  void dispose() {
    stopTracking();
  }
}
