import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/drive_stats.dart';
import '../../../widgets/common/glass_card.dart';

/// Thermal Profile section — color-coded range bars for each temperature
/// parameter with avg marker and time-at-warning/critical.
class ThermalSection extends StatelessWidget {
  final DriveStats stats;
  final void Function(String paramId)? onParamTap;

  const ThermalSection({super.key, required this.stats, this.onParamTap});

  @override
  Widget build(BuildContext context) {
    final params = <_ThermalParam>[
      if (stats.egt.hasData)
        _ThermalParam('EGT 1', stats.egt, 0, 1500, 900, 1100, 'egt'),
      if (stats.egt2.hasData)
        _ThermalParam('EGT 2', stats.egt2, 0, 1500, 900, 1100, 'egt2'),
      if (stats.egt3.hasData)
        _ThermalParam('EGT 3', stats.egt3, 0, 1500, 900, 1100, 'egt3'),
      if (stats.egt4.hasData)
        _ThermalParam('EGT 4', stats.egt4, 0, 1500, 900, 1100, 'egt4'),
      if (stats.trans.hasData)
        _ThermalParam('Trans', stats.trans, 100, 280, 200, 220, 'transTemp'),
      if (stats.coolant.hasData)
        _ThermalParam('Coolant', stats.coolant, 100, 260, 210, 220, 'coolantTemp'),
      if (stats.oilTemp.hasData)
        _ThermalParam('Oil', stats.oilTemp, 100, 280, 230, 240, 'oilTemp'),
      if (stats.intakeTemp.hasData)
        _ThermalParam('Intake', stats.intakeTemp, 0, 220, 120, 160, 'intakeTemp'),
      if (stats.intercoolerTemp.hasData)
        _ThermalParam('IC Outlet', stats.intercoolerTemp, 0, 250, 150, 180, 'intercoolerOutletTemp'),
    ];

    if (params.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat, size: 16, color: AppColors.critical),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Thermal Profile',
                style: AppTypography.displaySmall.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                for (int i = 0; i < params.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  _ThermalBar(
                    param: params[i],
                    onTap: onParamTap != null
                        ? () => onParamTap!(params[i].paramId)
                        : null,
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

class _ThermalParam {
  final String label;
  final ThermalStats thermal;
  final double scaleMin;
  final double scaleMax;
  final double warnThresh;
  final double critThresh;
  final String paramId;

  const _ThermalParam(
    this.label,
    this.thermal,
    this.scaleMin,
    this.scaleMax,
    this.warnThresh,
    this.critThresh,
    this.paramId,
  );
}

class _ThermalBar extends StatelessWidget {
  final _ThermalParam param;
  final VoidCallback? onTap;

  const _ThermalBar({required this.param, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = param.thermal;
    final range = param.scaleMax - param.scaleMin;
    if (range <= 0) return const SizedBox.shrink();

    // Normalize positions to 0..1
    double norm(double v) =>
        ((v - param.scaleMin) / range).clamp(0, 1);

    final minPos = norm(t.min);
    final maxPos = norm(t.max);
    final avgPos = norm(t.avg);
    final warnPos = norm(param.warnThresh);
    final critPos = norm(param.critThresh);

    // Color for the max value
    Color maxColor;
    if (t.max >= param.critThresh) {
      maxColor = AppColors.critical;
    } else if (t.max >= param.warnThresh) {
      maxColor = AppColors.warning;
    } else {
      maxColor = AppColors.success;
    }

    final deg = String.fromCharCode(0x00B0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              param.label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${t.min.toStringAsFixed(0)}$deg',
                  style: AppTypography.labelSmall,
                ),
                Text(
                  ' / ',
                  style: AppTypography.labelSmall,
                ),
                Text(
                  '${t.avg.toStringAsFixed(0)}$deg',
                  style: AppTypography.dataSmall.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  ' / ',
                  style: AppTypography.labelSmall,
                ),
                Text(
                  '${t.max.toStringAsFixed(0)}${deg}F',
                  style: AppTypography.dataSmall.copyWith(
                    fontSize: 11,
                    color: maxColor,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 10,
                      color: AppColors.textTertiary),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Range bar
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  // Background track
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.surfaceLight,
                      ),
                    ),
                  ),
                  // Green zone (0 → warn)
                  Positioned(
                    left: 0,
                    width: w * warnPos,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.horizontal(
                          left: const Radius.circular(8),
                          right: warnPos >= 1
                              ? const Radius.circular(8)
                              : Radius.zero,
                        ),
                        color: AppColors.success.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  // Amber zone (warn → crit)
                  Positioned(
                    left: w * warnPos,
                    width: w * (critPos - warnPos),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      color: AppColors.warning.withValues(alpha: 0.15),
                    ),
                  ),
                  // Red zone (crit → end)
                  Positioned(
                    left: w * critPos,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8),
                        ),
                        color: AppColors.critical.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  // Min→Max range bar
                  Positioned(
                    left: w * minPos,
                    width: (w * (maxPos - minPos)).clamp(2, w),
                    top: 3,
                    bottom: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.success.withValues(alpha: 0.7),
                            maxColor.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Avg marker
                  Positioned(
                    left: (w * avgPos - 1).clamp(0, w - 2),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Time at threshold
        if (t.timeAboveWarnSeconds > 0 || t.timeAboveCritSeconds > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (t.timeAboveWarnSeconds > 0)
                _TimeChip(
                  label: 'Warn',
                  seconds: t.timeAboveWarnSeconds,
                  color: AppColors.warning,
                ),
              if (t.timeAboveWarnSeconds > 0 && t.timeAboveCritSeconds > 0)
                const SizedBox(width: AppSpacing.sm),
              if (t.timeAboveCritSeconds > 0)
                _TimeChip(
                  label: 'Crit',
                  seconds: t.timeAboveCritSeconds,
                  color: AppColors.critical,
                ),
            ],
          ),
        ],
      ],
    ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final int seconds;
  final Color color;

  const _TimeChip({
    required this.label,
    required this.seconds,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final text = m > 0 ? '${m}m ${s}s' : '${s}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $text',
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
