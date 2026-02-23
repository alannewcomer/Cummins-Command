import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/drive_session.dart';
import '../../../models/drive_stats.dart';
import '../../../widgets/common/glass_card.dart';

/// Emissions & DPF section: DPF soot/regen, NOx, SCR efficiency, DEF.
class EmissionsSection extends StatelessWidget {
  final DriveSession drive;
  final DriveStats stats;

  const EmissionsSection({
    super.key,
    required this.drive,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final hasDpf = stats.avgDpfSootLoad > 0 || stats.maxDpfSootLoad > 0 ||
        drive.dpfRegenOccurred;
    final hasNox = stats.avgNoxPreScr > 0 || stats.avgNoxPostScr > 0;
    final hasDef = stats.defLevelStart > 0 || stats.defLevelEnd > 0 ||
        stats.defConsumedMl > 0;

    if (!hasDpf && !hasNox && !hasDef) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt, size: 16, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Emissions & DPF',
                style: AppTypography.displaySmall.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            borderColor: drive.dpfRegenOccurred
                ? AppColors.warning.withValues(alpha: 0.25)
                : null,
            child: Column(
              children: [
                // DPF row
                if (hasDpf) ...[
                  Row(
                    children: [
                      _MetricTile(
                        label: 'DPF Soot',
                        value:
                            '${stats.maxDpfSootLoad.toStringAsFixed(0)}%',
                        sub: 'avg ${stats.avgDpfSootLoad.toStringAsFixed(0)}%',
                        color: stats.maxDpfSootLoad > 80
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                      if (stats.avgDpfDiffPressure > 0)
                        _MetricTile(
                          label: 'Backpressure',
                          value:
                              stats.avgDpfDiffPressure.toStringAsFixed(1),
                          sub: 'kPa avg',
                          color: AppColors.textSecondary,
                        ),
                      if (drive.dpfRegenOccurred)
                        _MetricTile(
                          label: 'DPF Regen',
                          value: '${drive.dpfRegenCount}x',
                          sub:
                              '${(drive.dpfRegenDurationSeconds / 60).toStringAsFixed(0)}m total',
                          color: AppColors.warning,
                        ),
                    ],
                  ),
                ],

                // NOx / SCR row
                if (hasNox) ...[
                  if (hasDpf) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Divider(
                        color: AppColors.surfaceBorder, height: 1),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      _MetricTile(
                        label: 'NOx Pre-SCR',
                        value: stats.avgNoxPreScr.toStringAsFixed(0),
                        sub: 'ppm avg',
                        color: AppColors.textSecondary,
                      ),
                      _MetricTile(
                        label: 'NOx Post-SCR',
                        value: stats.avgNoxPostScr.toStringAsFixed(0),
                        sub: 'ppm avg',
                        color: AppColors.textSecondary,
                      ),
                      if (stats.scrEfficiencyPercent > 0)
                        _MetricTile(
                          label: 'SCR Eff.',
                          value:
                              '${stats.scrEfficiencyPercent.toStringAsFixed(0)}%',
                          sub: '',
                          color: stats.scrEfficiencyPercent > 90
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                    ],
                  ),
                ],

                // DEF row
                if (hasDef) ...[
                  if (hasDpf || hasNox) ...[
                    const SizedBox(height: AppSpacing.md),
                    const Divider(
                        color: AppColors.surfaceBorder, height: 1),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      if (stats.defLevelStart > 0)
                        _MetricTile(
                          label: 'DEF Level',
                          value:
                              '${stats.defLevelStart.toStringAsFixed(0)}%',
                          sub:
                              '-> ${stats.defLevelEnd.toStringAsFixed(0)}%',
                          color: stats.defLevelEnd < 15
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                      if (stats.defConsumedMl > 0)
                        _MetricTile(
                          label: 'DEF Used',
                          value: stats.defConsumedMl > 1000
                              ? '${(stats.defConsumedMl / 1000).toStringAsFixed(1)}L'
                              : '${stats.defConsumedMl.toStringAsFixed(0)}mL',
                          sub: '',
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTypography.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.dataMedium.copyWith(
              fontSize: 16,
              color: color,
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: AppTypography.labelSmall.copyWith(fontSize: 9),
            ),
        ],
      ),
    );
  }
}
