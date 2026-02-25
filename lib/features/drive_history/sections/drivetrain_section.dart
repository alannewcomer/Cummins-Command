import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/drive_stats.dart';
import '../../../widgets/common/glass_card.dart';

/// Drivetrain section: gear distribution bar chart, TC lock %, VGT/EGR avg.
class DrivetrainSection extends StatelessWidget {
  final DriveStats stats;
  final void Function(String paramId)? onParamTap;

  const DrivetrainSection({super.key, required this.stats, this.onParamTap});

  @override
  Widget build(BuildContext context) {
    final hasGears = stats.gearDistribution.isNotEmpty;
    final hasTc = stats.tcLockedPercent > 0;
    final hasVgt = stats.avgVgtPercent > 0;
    final hasEgr = stats.avgEgrPercent > 0;

    if (!hasGears && !hasTc && !hasVgt && !hasEgr) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, size: 16, color: AppColors.dataAccent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Drivetrain',
                style: AppTypography.displaySmall.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gear distribution
                if (hasGears) ...[
                  Text(
                    'Gear Distribution',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _GearDistChart(gears: stats.gearDistribution),
                ],

                // Stats row
                if (hasTc || hasVgt || hasEgr) ...[
                  if (hasGears) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(
                        color: AppColors.surfaceBorder, height: 1),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Row(
                    children: [
                      if (hasTc)
                        _StatItem(
                          label: 'TC Locked',
                          value:
                              '${stats.tcLockedPercent.toStringAsFixed(0)}%',
                          color: AppColors.dataAccent,
                        ),
                      if (hasVgt)
                        _StatItem(
                          label: 'Avg VGT',
                          value:
                              '${stats.avgVgtPercent.toStringAsFixed(0)}%',
                          color: AppColors.textSecondary,
                          onTap: onParamTap != null ? () => onParamTap!('vgtPosition') : null,
                        ),
                      if (hasEgr)
                        _StatItem(
                          label: 'Avg EGR',
                          value:
                              '${stats.avgEgrPercent.toStringAsFixed(0)}%',
                          color: AppColors.textSecondary,
                          onTap: onParamTap != null ? () => onParamTap!('egrPosition') : null,
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

class _GearDistChart extends StatelessWidget {
  final Map<int, double> gears;

  const _GearDistChart({required this.gears});

  @override
  Widget build(BuildContext context) {
    if (gears.isEmpty) return const SizedBox.shrink();

    final sorted = gears.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxSeconds = sorted.fold<double>(
        0, (m, e) => e.value > m ? e.value : m);
    if (maxSeconds <= 0) return const SizedBox.shrink();

    return Column(
      children: sorted.map((entry) {
        final pct = entry.value / maxSeconds;
        final m = entry.value ~/ 60;
        final s = (entry.value % 60).toInt();
        final timeStr = m > 0 ? '${m}m ${s}s' : '${s}s';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${entry.key}',
                  style: AppTypography.dataSmall.copyWith(
                    fontSize: 12,
                    color: AppColors.dataAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.02, 1),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.dataAccent.withValues(alpha: 0.6),
                              AppColors.dataAccent.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 48,
                child: Text(
                  timeStr,
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
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
          ],
        ),
      ),
    );
  }
}
