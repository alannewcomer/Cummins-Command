import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/drive_session.dart';
import '../common/glass_card.dart';

/// Drive history card showing key drive metrics with AI health score.
class DriveCard extends StatelessWidget {
  final DriveSession drive;
  final VoidCallback? onTap;

  const DriveCard({
    super.key,
    required this.drive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final healthScore = drive.aiHealthScore;
    final healthColor = _healthColor(healthScore);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      glowColor: healthColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: date + health score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(drive.startTime),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    timeFormat.format(drive.startTime),
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              if (healthScore != null) _buildHealthRing(healthScore, healthColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.timer_outlined,
                value: drive.formattedDuration,
                label: 'Duration',
              ),
              const SizedBox(width: AppSpacing.md),
              _StatChip(
                icon: Icons.straighten,
                value: '${drive.distanceMiles.toStringAsFixed(1)} mi',
                label: 'Distance',
              ),
              const SizedBox(width: AppSpacing.md),
              _StatChip(
                icon: Icons.local_gas_station,
                value: drive.averageMPG.toStringAsFixed(1),
                label: 'Avg MPG',
              ),
              if (drive.durationSeconds > 0 && drive.distanceMiles > 0) ...[
                const SizedBox(width: AppSpacing.md),
                _StatChip(
                  icon: Icons.speed,
                  value: (drive.distanceMiles / (drive.durationSeconds / 3600.0)).toStringAsFixed(0),
                  label: 'Avg mph',
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Peak values
          if (drive.maxBoostPsi != null || drive.maxEgtF != null || drive.maxTransTempF != null)
            Row(
              children: [
                if (drive.maxBoostPsi != null)
                  _PeakBadge(
                    label: 'BOOST',
                    value: '${drive.maxBoostPsi!.toStringAsFixed(0)} PSI',
                  ),
                if (drive.maxEgtF != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _PeakBadge(
                    label: 'EGT',
                    value: '${drive.maxEgtF!.toStringAsFixed(0)}°F',
                  ),
                ],
                if (drive.maxTransTempF != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _PeakBadge(
                    label: 'TRANS',
                    value: '${drive.maxTransTempF!.toStringAsFixed(0)}°F',
                    valueColor: drive.maxTransTempF! >= 220
                        ? AppColors.critical
                        : drive.maxTransTempF! >= 200
                            ? AppColors.warning
                            : null,
                  ),
                ],
              ],
            ),

          // Tags
          if (drive.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              children: drive.tags.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.dataAccentDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.dataAccent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // AI Summary
          if (drive.aiSummary != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.diamond_outlined,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    drive.aiSummary!,
                    style: AppTypography.aiText.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthRing(int score, Color color) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100.0,
            strokeWidth: 3,
            backgroundColor: AppColors.gaugeArc,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '$score',
            style: AppTypography.dataSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Color _healthColor(int? score) {
    if (score == null) return AppColors.textTertiary;
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.critical;
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTypography.dataSmall),
              Text(label, style: AppTypography.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeakBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PeakBadge({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? AppColors.dataAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: AppTypography.labelSmall,
          ),
          Text(
            value,
            style: AppTypography.dataSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
