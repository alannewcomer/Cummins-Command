import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/drive_stats.dart';
import '../../../widgets/common/glass_card.dart';

/// System Health section: Battery, Oil Pressure, Crankcase, Coolant Level.
class SystemSection extends StatelessWidget {
  final DriveStats stats;
  final void Function(String paramId)? onParamTap;

  const SystemSection({super.key, required this.stats, this.onParamTap});

  @override
  Widget build(BuildContext context) {
    final hasBattery = stats.avgBatteryVoltage > 0;
    final hasOil = stats.avgOilPressure > 0;
    final hasCrankcase = stats.avgCrankcasePressure > 0;
    final hasCoolantLevel =
        stats.coolantLevelStart > 0 || stats.coolantLevelEnd > 0;

    if (!hasBattery && !hasOil && !hasCrankcase && !hasCoolantLevel) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined,
                  size: 16, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'System Health',
                style: AppTypography.displaySmall.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    if (hasBattery)
                      _SystemTile(
                        icon: Icons.battery_charging_full,
                        label: 'Battery',
                        primary:
                            '${stats.avgBatteryVoltage.toStringAsFixed(1)}V',
                        secondary:
                            'min ${stats.minBatteryVoltage.toStringAsFixed(1)}V',
                        color: stats.minBatteryVoltage < 11.5
                            ? AppColors.warning
                            : AppColors.success,
                        onTap: onParamTap != null ? () => onParamTap!('batteryVoltage') : null,
                      ),
                    if (hasOil)
                      _SystemTile(
                        icon: Icons.oil_barrel,
                        label: 'Oil Press.',
                        primary:
                            '${stats.avgOilPressure.toStringAsFixed(0)} PSI',
                        secondary:
                            'min ${stats.minOilPressure.toStringAsFixed(0)}',
                        color: stats.minOilPressure < 25
                            ? AppColors.warning
                            : AppColors.success,
                        onTap: onParamTap != null ? () => onParamTap!('oilPressure') : null,
                      ),
                  ],
                ),
                if (hasCrankcase || hasCoolantLevel) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (hasCrankcase)
                        _SystemTile(
                          icon: Icons.air,
                          label: 'Crankcase',
                          primary:
                              stats.avgCrankcasePressure.toStringAsFixed(1),
                          secondary: 'inH2O avg',
                          color: stats.avgCrankcasePressure > 7
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          onTap: onParamTap != null ? () => onParamTap!('crankcasePressure') : null,
                        ),
                      if (hasCoolantLevel)
                        _SystemTile(
                          icon: Icons.water_drop,
                          label: 'Coolant Lvl',
                          primary:
                              '${stats.coolantLevelStart.toStringAsFixed(0)}%',
                          secondary:
                              '-> ${stats.coolantLevelEnd.toStringAsFixed(0)}%',
                          color: stats.coolantLevelEnd < 50
                              ? AppColors.warning
                              : AppColors.textSecondary,
                          onTap: onParamTap != null ? () => onParamTap!('coolantLevel') : null,
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

class _SystemTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String primary;
  final String secondary;
  final Color color;
  final VoidCallback? onTap;

  const _SystemTile({
    required this.icon,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.labelSmall),
                  Text(
                    primary,
                    style: AppTypography.dataSmall.copyWith(
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    secondary,
                    style: AppTypography.labelSmall.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
