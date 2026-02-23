import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/drive_session.dart';
import '../../../models/drive_stats.dart';

/// 3x2 tile grid: Duration, Distance, Avg Speed, Avg MPG, Fuel Used, Idle %
class DriveOverviewSection extends StatelessWidget {
  final DriveSession drive;
  final DriveStats stats;

  const DriveOverviewSection({
    super.key,
    required this.drive,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drive Overview',
            style: AppTypography.displaySmall.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Tile(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: drive.formattedDuration,
                color: AppColors.dataAccent,
              ),
              const SizedBox(width: AppSpacing.sm),
              _Tile(
                icon: Icons.straighten,
                label: 'Distance',
                value: '${drive.distanceMiles.toStringAsFixed(1)} mi',
                color: AppColors.dataAccent,
              ),
              const SizedBox(width: AppSpacing.sm),
              _Tile(
                icon: Icons.speed,
                label: 'Avg Speed',
                value: '${stats.avgSpeedMph.toStringAsFixed(0)} mph',
                color: AppColors.dataAccent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _Tile(
                icon: Icons.local_gas_station,
                label: 'Avg MPG',
                value: drive.averageMPG.toStringAsFixed(1),
                color: drive.averageMPG >= 15
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              _Tile(
                icon: Icons.propane_tank_outlined,
                label: 'Fuel Used',
                value: '${drive.fuelUsedGallons.toStringAsFixed(1)} gal',
                color: AppColors.dataAccent,
              ),
              const SizedBox(width: AppSpacing.sm),
              _Tile(
                icon: Icons.pause_circle_outline,
                label: 'Idle',
                value: '${stats.idlePercent.toStringAsFixed(0)}%',
                color: stats.idlePercent > 30
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.dataSmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}
