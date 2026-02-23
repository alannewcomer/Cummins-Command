import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/drive_stats.dart';
import '../../../widgets/common/glass_card.dart';

/// Engine Performance section: two-column Avg/Max table for RPM, Boost,
/// Load, Throttle, Turbo, Rail Pressure, Est. HP/Torque.
class EngineSection extends StatelessWidget {
  final DriveStats stats;

  const EngineSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = <_EngineRow>[
      if (stats.avgRpm > 0 || stats.maxRpm > 0)
        _EngineRow('RPM', stats.avgRpm.toStringAsFixed(0),
            stats.maxRpm.toStringAsFixed(0), ''),
      if (stats.avgBoostPsi > 0 || stats.maxBoostPsi > 0)
        _EngineRow('Boost', stats.avgBoostPsi.toStringAsFixed(1),
            stats.maxBoostPsi.toStringAsFixed(1), 'PSI'),
      if (stats.avgLoadPercent > 0 || stats.maxLoadPercent > 0)
        _EngineRow('Load', stats.avgLoadPercent.toStringAsFixed(0),
            stats.maxLoadPercent.toStringAsFixed(0), '%'),
      if (stats.avgThrottlePercent > 0 || stats.maxThrottlePercent > 0)
        _EngineRow('Throttle', stats.avgThrottlePercent.toStringAsFixed(0),
            stats.maxThrottlePercent.toStringAsFixed(0), '%'),
      if (stats.maxTurboSpeedRpm > 0)
        _EngineRow('Turbo', '-',
            '${(stats.maxTurboSpeedRpm / 1000).toStringAsFixed(0)}k', 'RPM'),
      if (stats.maxRailPressurePsi > 0)
        _EngineRow(
            'Rail Press.',
            '-',
            '${(stats.maxRailPressurePsi / 1000).toStringAsFixed(1)}k',
            'PSI'),
      if (stats.maxEstimatedHp > 0)
        _EngineRow('Est. HP', '-',
            stats.maxEstimatedHp.toStringAsFixed(0), ''),
      if (stats.maxEstimatedTorque > 0)
        _EngineRow('Est. Torque', '-',
            stats.maxEstimatedTorque.toStringAsFixed(0), 'ft-lb'),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Engine Performance',
                style: AppTypography.displaySmall.copyWith(fontSize: 14),
              ),
              if (stats.highLoadPercent > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stats.highLoadPercent > 50
                        ? AppColors.warningDim
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    '${stats.highLoadPercent.toStringAsFixed(0)}% high load',
                    style: AppTypography.labelSmall.copyWith(
                      color: stats.highLoadPercent > 50
                          ? AppColors.warning
                          : AppColors.textTertiary,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text('Parameter',
                            style: AppTypography.labelSmall),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('AVG',
                            style: AppTypography.labelSmall,
                            textAlign: TextAlign.right),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('MAX',
                            style: AppTypography.labelSmall,
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ),
                // Rows
                ...rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: i.isEven
                          ? Colors.transparent
                          : AppColors.surfaceLight.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            row.label,
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            row.avg == '-'
                                ? '-'
                                : '${row.avg}${row.unit.isNotEmpty ? ' ${row.unit}' : ''}',
                            style: AppTypography.dataSmall.copyWith(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${row.max}${row.unit.isNotEmpty ? ' ${row.unit}' : ''}',
                            style: AppTypography.dataSmall.copyWith(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineRow {
  final String label;
  final String avg;
  final String max;
  final String unit;

  const _EngineRow(this.label, this.avg, this.max, this.unit);
}
