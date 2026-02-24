import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../models/drive_session.dart';
import '../../models/drive_stats.dart';
import '../../providers/drive_stats_provider.dart';
import '../../providers/drives_provider.dart';
import '../../widgets/common/glass_card.dart';

class AllStatsScreen extends ConsumerWidget {
  final String driveId;

  const AllStatsScreen({super.key, required this.driveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveAsync = ref.watch(driveDetailProvider(driveId));
    final statsAsync = ref.watch(driveStatsProvider(driveId));

    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Icon(Icons.arrow_back, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: driveAsync.when(
          data: (drive) {
            if (drive == null) return const Text('All Stats');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Stats',
                  style: AppTypography.displaySmall.copyWith(fontSize: 14),
                ),
                Text(
                  '${dateFormat.format(drive.startTime)} ${timeFormat.format(drive.startTime)}',
                  style: AppTypography.labelSmall,
                ),
              ],
            );
          },
          loading: () => Text('All Stats',
              style: AppTypography.displaySmall.copyWith(fontSize: 14)),
          error: (_, __) => Text('All Stats',
              style: AppTypography.displaySmall.copyWith(fontSize: 14)),
        ),
      ),
      body: statsAsync.when(
        data: (stats) => driveAsync.when(
          data: (drive) {
            if (drive == null) {
              return const Center(child: Text('Drive not found'));
            }
            return _StatsBody(stats: stats, drive: drive);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final DriveStats stats;
  final DriveSession drive;

  const _StatsBody({required this.stats, required this.drive});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildSection('Overview', _overviewRows()),
        const SizedBox(height: AppSpacing.lg),
        _buildSection('Fuel', _fuelRows()),
        const SizedBox(height: AppSpacing.lg),
        _buildSection('Engine', _engineRows()),
        const SizedBox(height: AppSpacing.lg),
        _buildSection('Temperatures', _thermalRows()),
        const SizedBox(height: AppSpacing.lg),
        _buildSection('Emissions', _emissionsRows()),
        const SizedBox(height: AppSpacing.lg),
        _buildSection('System', _systemRows()),
        SizedBox(
            height: MediaQuery.of(context).padding.bottom + AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildSection(String title, List<_StatRow> rows) {
    final validRows = rows.where((r) => r.hasData).toList();
    if (validRows.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: title),
            const SizedBox(height: AppSpacing.md),
            Text('No data recorded',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textTertiary)),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          const SizedBox(height: AppSpacing.md),
          // Column headers
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('PARAMETER',
                      style: AppTypography.labelSmall
                          .copyWith(fontSize: 8, letterSpacing: 1.0)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('MIN',
                      style: AppTypography.labelSmall
                          .copyWith(fontSize: 8, letterSpacing: 1.0),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: Text('AVG',
                      style: AppTypography.labelSmall
                          .copyWith(fontSize: 8, letterSpacing: 1.0),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: Text('MAX',
                      style: AppTypography.labelSmall
                          .copyWith(fontSize: 8, letterSpacing: 1.0),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: Text('% LMT',
                      style: AppTypography.labelSmall
                          .copyWith(fontSize: 8, letterSpacing: 1.0),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: AppColors.surfaceBorder,
          ),
          ...validRows.map((row) => _StatRowWidget(row: row)),
        ],
      ),
    );
  }

  List<_StatRow> _overviewRows() {
    return [
      _StatRow(
        name: 'Speed',
        unit: 'mph',
        min: null,
        avg: stats.avgSpeedMph,
        max: stats.maxSpeedMph,
        hasData: stats.avgSpeedMph > 0 || stats.maxSpeedMph > 0,
      ),
      _StatRow(
        name: 'Idle Time',
        unit: '%',
        min: null,
        avg: stats.idlePercent,
        max: null,
        hasData: true,
      ),
      _StatRow(
        name: 'Moving Time',
        unit: 'min',
        min: null,
        avg: stats.movingTimeSeconds / 60.0,
        max: null,
        hasData: stats.movingTimeSeconds > 0,
      ),
    ];
  }

  List<_StatRow> _fuelRows() {
    return [
      _StatRow(
        name: 'MPG',
        unit: '',
        min: drive.instantMPGMin,
        avg: drive.averageMPG > 0 ? drive.averageMPG : null,
        max: drive.instantMPGMax,
        hasData: drive.averageMPG > 0,
      ),
      _StatRow(
        name: 'Fuel Used',
        unit: 'gal',
        min: null,
        avg: drive.fuelUsedGallons > 0 ? drive.fuelUsedGallons : null,
        max: null,
        hasData: drive.fuelUsedGallons > 0,
      ),
    ];
  }

  List<_StatRow> _engineRows() {
    return [
      _StatRow(
        name: 'RPM',
        unit: '',
        min: null,
        avg: stats.avgRpm,
        max: stats.maxRpm,
        hasData: stats.avgRpm > 0 || stats.maxRpm > 0,
      ),
      _StatRow(
        name: 'Boost',
        unit: 'PSI',
        min: null,
        avg: stats.avgBoostPsi,
        max: stats.maxBoostPsi,
        hasData: stats.avgBoostPsi > 0 || stats.maxBoostPsi > 0,
      ),
      _StatRow(
        name: 'Load',
        unit: '%',
        min: null,
        avg: stats.avgLoadPercent,
        max: stats.maxLoadPercent,
        hasData: stats.avgLoadPercent > 0 || stats.maxLoadPercent > 0,
      ),
      _StatRow(
        name: 'Throttle',
        unit: '%',
        min: null,
        avg: stats.avgThrottlePercent,
        max: stats.maxThrottlePercent,
        hasData: stats.avgThrottlePercent > 0 || stats.maxThrottlePercent > 0,
      ),
      _StatRow(
        name: 'Turbo Speed',
        unit: 'RPM',
        min: null,
        avg: null,
        max: stats.maxTurboSpeedRpm,
        hasData: stats.maxTurboSpeedRpm > 0,
      ),
      _StatRow(
        name: 'Rail Pressure',
        unit: 'PSI',
        min: null,
        avg: null,
        max: stats.maxRailPressurePsi,
        hasData: stats.maxRailPressurePsi > 0,
      ),
      _StatRow(
        name: 'Est. HP',
        unit: '',
        min: null,
        avg: null,
        max: stats.maxEstimatedHp,
        hasData: stats.maxEstimatedHp > 0,
      ),
      _StatRow(
        name: 'Est. Torque',
        unit: 'ft-lb',
        min: null,
        avg: null,
        max: stats.maxEstimatedTorque,
        hasData: stats.maxEstimatedTorque > 0,
      ),
    ];
  }

  List<_StatRow> _thermalRows() {
    return [
      _thermalStatRow('Coolant', stats.coolant, 220),
      _thermalStatRow('Trans', stats.trans, 220),
      _thermalStatRow('EGT 1', stats.egt, 1100),
      _thermalStatRow('EGT 2', stats.egt2, 1100),
      _thermalStatRow('EGT 3', stats.egt3, 1100),
      _thermalStatRow('EGT 4', stats.egt4, 1100),
      _thermalStatRow('Oil', stats.oilTemp, 240),
      _thermalStatRow('Intake', stats.intakeTemp, 160),
      _thermalStatRow('IC Outlet', stats.intercoolerTemp, 180),
    ];
  }

  _StatRow _thermalStatRow(
      String name, ThermalStats thermal, double critLimit) {
    return _StatRow(
      name: name,
      unit: '\u00B0F',
      min: thermal.hasData ? thermal.min : null,
      avg: thermal.hasData ? thermal.avg : null,
      max: thermal.hasData ? thermal.max : null,
      hasData: thermal.hasData,
      limitThreshold: critLimit,
    );
  }

  List<_StatRow> _emissionsRows() {
    return [
      _StatRow(
        name: 'DPF Soot',
        unit: '%',
        min: null,
        avg: stats.avgDpfSootLoad,
        max: stats.maxDpfSootLoad,
        hasData: stats.avgDpfSootLoad > 0 || stats.maxDpfSootLoad > 0,
      ),
      _StatRow(
        name: 'NOx Pre-SCR',
        unit: 'ppm',
        min: null,
        avg: stats.avgNoxPreScr,
        max: null,
        hasData: stats.avgNoxPreScr > 0,
      ),
      _StatRow(
        name: 'NOx Post-SCR',
        unit: 'ppm',
        min: null,
        avg: stats.avgNoxPostScr,
        max: null,
        hasData: stats.avgNoxPostScr > 0,
      ),
      _StatRow(
        name: 'SCR Eff.',
        unit: '%',
        min: null,
        avg: stats.scrEfficiencyPercent,
        max: null,
        hasData: stats.scrEfficiencyPercent > 0,
      ),
      _StatRow(
        name: 'DEF Used',
        unit: 'mL',
        min: null,
        avg: stats.defConsumedMl,
        max: null,
        hasData: stats.defConsumedMl > 0,
      ),
      _StatRow(
        name: 'DEF Level',
        unit: '%',
        min: stats.defLevelEnd > 0
            ? (stats.defLevelStart < stats.defLevelEnd
                ? stats.defLevelStart
                : stats.defLevelEnd)
            : null,
        avg: null,
        max: stats.defLevelStart > 0
            ? (stats.defLevelStart > stats.defLevelEnd
                ? stats.defLevelStart
                : stats.defLevelEnd)
            : null,
        hasData: stats.defLevelStart > 0 || stats.defLevelEnd > 0,
      ),
    ];
  }

  List<_StatRow> _systemRows() {
    return [
      _StatRow(
        name: 'Battery',
        unit: 'V',
        min: stats.minBatteryVoltage < double.infinity
            ? stats.minBatteryVoltage
            : null,
        avg: stats.avgBatteryVoltage,
        max: null,
        hasData: stats.avgBatteryVoltage > 0,
      ),
      _StatRow(
        name: 'Oil Pressure',
        unit: 'PSI',
        min: stats.minOilPressure < double.infinity
            ? stats.minOilPressure
            : null,
        avg: stats.avgOilPressure,
        max: null,
        hasData: stats.avgOilPressure > 0,
      ),
      _StatRow(
        name: 'Crankcase',
        unit: 'inHg',
        min: null,
        avg: stats.avgCrankcasePressure,
        max: null,
        hasData: stats.avgCrankcasePressure > 0,
      ),
      _StatRow(
        name: 'Coolant Lvl',
        unit: '%',
        min: stats.coolantLevelEnd > 0
            ? (stats.coolantLevelStart < stats.coolantLevelEnd
                ? stats.coolantLevelStart
                : stats.coolantLevelEnd)
            : null,
        avg: null,
        max: stats.coolantLevelStart > 0
            ? (stats.coolantLevelStart > stats.coolantLevelEnd
                ? stats.coolantLevelStart
                : stats.coolantLevelEnd)
            : null,
        hasData: stats.coolantLevelStart > 0 || stats.coolantLevelEnd > 0,
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.displaySmall.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

class _StatRow {
  final String name;
  final String unit;
  final double? min;
  final double? avg;
  final double? max;
  final bool hasData;
  final double? limitThreshold;

  const _StatRow({
    required this.name,
    required this.unit,
    this.min,
    this.avg,
    this.max,
    this.hasData = true,
    this.limitThreshold,
  });

  double? get percentOfLimit {
    if (limitThreshold == null || limitThreshold == 0 || max == null) {
      return null;
    }
    return (max! / limitThreshold!) * 100;
  }
}

class _StatRowWidget extends StatelessWidget {
  final _StatRow row;

  const _StatRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    final pct = row.percentOfLimit;
    Color? pctColor;
    if (pct != null) {
      if (pct >= 100) {
        pctColor = AppColors.critical;
      } else if (pct >= 80) {
        pctColor = AppColors.warning;
      } else {
        pctColor = AppColors.success;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.surfaceBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Parameter name
          Expanded(
            flex: 3,
            child: Text(
              row.name,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          // MIN
          Expanded(
            flex: 2,
            child: Text(
              _formatValue(row.min, row.unit),
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // AVG
          Expanded(
            flex: 2,
            child: Text(
              _formatValue(row.avg, row.unit),
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.dataAccent,
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // MAX
          Expanded(
            flex: 2,
            child: Text(
              _formatValue(row.max, row.unit),
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // % Limit
          Expanded(
            flex: 2,
            child: Text(
              pct != null ? '${pct.toStringAsFixed(0)}%' : '--',
              style: AppTypography.labelMedium.copyWith(
                color: pctColor ?? AppColors.textTertiary,
                fontSize: 11,
                fontWeight: pct != null && pct >= 80
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double? value, String unit) {
    if (value == null) return '--';
    // Large numbers: no decimals
    if (value.abs() >= 1000) {
      return value.toStringAsFixed(0);
    }
    // Percentage or small: 1 decimal
    if (value.abs() >= 100) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
