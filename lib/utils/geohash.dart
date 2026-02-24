const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Encode a latitude/longitude pair into a geohash string.
///
/// [precision] controls the length of the returned hash:
/// - 5 chars ~ 5km box (good for route matching)
/// - 6 chars ~ 1.2km box
/// - 7 chars ~ 150m box
String encodeGeohash(double latitude, double longitude, {int precision = 5}) {
  double minLat = -90, maxLat = 90;
  double minLng = -180, maxLng = 180;

  final buffer = StringBuffer();
  var bits = 0;
  var charIndex = 0;
  var isLng = true;

  while (buffer.length < precision) {
    if (isLng) {
      final mid = (minLng + maxLng) / 2;
      if (longitude >= mid) {
        charIndex = (charIndex << 1) | 1;
        minLng = mid;
      } else {
        charIndex = charIndex << 1;
        maxLng = mid;
      }
    } else {
      final mid = (minLat + maxLat) / 2;
      if (latitude >= mid) {
        charIndex = (charIndex << 1) | 1;
        minLat = mid;
      } else {
        charIndex = charIndex << 1;
        maxLat = mid;
      }
    }

    isLng = !isLng;
    bits++;

    if (bits == 5) {
      buffer.write(_base32[charIndex]);
      bits = 0;
      charIndex = 0;
    }
  }

  return buffer.toString();
}
