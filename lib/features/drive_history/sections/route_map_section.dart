import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../models/drive_stats.dart';

class RouteMapSection extends StatelessWidget {
  final DriveStats stats;

  const RouteMapSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final hasRoute = stats.hasGpsData;
    final points = hasRoute
        ? stats.routePoints.map((p) => LatLng(p.lat, p.lng)).toList()
        : <LatLng>[];

    // Camera: fit route bounds if GPS data, otherwise zoomed-out US center
    final MapOptions mapOptions;
    if (hasRoute) {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      mapOptions = MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
          padding: const EdgeInsets.all(24),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
        backgroundColor: AppColors.background,
      );
    } else {
      // Zoomed-out default — continental US center
      mapOptions = MapOptions(
        initialCenter: const LatLng(39.0, -98.0),
        initialZoom: 3.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
        backgroundColor: AppColors.background,
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: mapOptions,
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.cumminscommand.app',
              ),
              if (hasRoute) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      color: AppColors.dataAccent,
                      strokeWidth: 3,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points.first,
                      width: 12,
                      height: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Marker(
                      point: points.last,
                      width: 12,
                      height: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.critical,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          // Subtle label when no route data
          if (!hasRoute)
            Positioned(
              bottom: AppSpacing.sm,
              right: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  'No GPS route recorded',
                  style: AppTypography.labelSmall.copyWith(fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
