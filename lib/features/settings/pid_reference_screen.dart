import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../config/thresholds.dart';
import '../../widgets/common/glass_card.dart';

/// PID Reference Guide — cheat sheet for all monitored parameters.
/// Groups PIDs by system, shows OBD2 hex codes, ranges, normal values
/// for the 2026 6.7L Cummins, and alert thresholds.
class PidReferenceScreen extends StatefulWidget {
  const PidReferenceScreen({super.key});

  @override
  State<PidReferenceScreen> createState() => _PidReferenceScreenState();
}

class _PidReferenceScreenState extends State<PidReferenceScreen> {
  String _searchQuery = '';
  int _expandedGroup = -1;

  // ── PID groupings by system ──
  static const _groups = <_PidGroup>[
    _PidGroup(
      title: 'Engine Core',
      icon: Icons.engineering,
      color: AppColors.primary,
      pidIds: ['rpm', 'engineLoadObd2', 'coolantTemp', 'speed', 'runTime', 'runtimeExtended'],
    ),
    _PidGroup(
      title: 'Torque & Power',
      icon: Icons.speed,
      color: AppColors.dataAccent,
      pidIds: ['accelPedalD', 'demandTorque', 'actualTorque', 'referenceTorque', 'commandedThrottle'],
    ),
    _PidGroup(
      title: 'Turbo & Boost',
      icon: Icons.air,
      color: Color(0xFF7C4DFF),
      pidIds: ['boostPressureCtrl', 'vgtControlObd', 'turboInletPressure', 'turboInletTemp'],
    ),
    _PidGroup(
      title: 'Air & Intake',
      icon: Icons.wind_power,
      color: Color(0xFF00BFA5),
      pidIds: ['maf', 'intakeTemp', 'intercoolerOutletTemp', 'chargeAirTemp', 'barometric'],
    ),
    _PidGroup(
      title: 'Fuel System',
      icon: Icons.local_gas_station,
      color: AppColors.warning,
      pidIds: ['railPressure', 'fuelLevel'],
    ),
    _PidGroup(
      title: 'Exhaust & Emissions',
      icon: Icons.whatshot,
      color: AppColors.critical,
      pidIds: ['egtObd2', 'dpfTemp', 'exhaustBackpressure', 'commandedEgr'],
    ),
    _PidGroup(
      title: 'Electrical & Environment',
      icon: Icons.battery_charging_full,
      color: AppColors.success,
      pidIds: ['batteryVoltage', 'ambientTemp'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('PID Reference', style: AppTypography.displaySmall),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md,
            ),
            child: TextField(
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search PIDs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),

          // ── Summary strip ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                _ChipBadge(
                  label: '${PidRegistry.all.length} PIDs',
                  color: AppColors.dataAccent,
                ),
                const SizedBox(width: AppSpacing.sm),
                _ChipBadge(
                  label: '${PidRegistry.critical.length} Critical',
                  color: AppColors.critical,
                ),
                const SizedBox(width: AppSpacing.sm),
                _ChipBadge(
                  label: 'Mode \$01',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Grouped PID list ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl,
              ),
              itemCount: _groups.length,
              itemBuilder: (context, groupIndex) {
                final group = _groups[groupIndex];
                final pids = group.pidIds
                    .map((id) => PidRegistry.get(id))
                    .whereType<PidDefinition>()
                    .where((p) => _searchQuery.isEmpty ||
                        p.name.toLowerCase().contains(_searchQuery) ||
                        p.shortName.toLowerCase().contains(_searchQuery) ||
                        p.id.toLowerCase().contains(_searchQuery) ||
                        '0x${p.code.toRadixString(16)}'.contains(_searchQuery))
                    .toList();

                if (pids.isEmpty) return const SizedBox.shrink();

                final isExpanded = _expandedGroup == groupIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    borderColor: isExpanded
                        ? group.color.withValues(alpha: 0.4)
                        : null,
                    child: Column(
                      children: [
                        // ── Group header ──
                        GestureDetector(
                          onTap: () => setState(() {
                            _expandedGroup = isExpanded ? -1 : groupIndex;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: group.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(group.icon, color: group.color, size: 20),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(group.title, style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary)),
                                      Text('${pids.length} parameters', style: AppTypography.labelSmall),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Expanded PID cards ──
                        if (isExpanded)
                          ...pids.map((pid) => _PidDetailCard(pid: pid)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Group definition ──

class _PidGroup {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> pidIds;

  const _PidGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.pidIds,
  });
}

// ── Individual PID detail card ──

class _PidDetailCard extends StatelessWidget {
  final PidDefinition pid;
  const _PidDetailCard({required this.pid});

  @override
  Widget build(BuildContext context) {
    final threshold = DefaultThresholds.forPid(pid.id);
    final hexCode = '0x${pid.code.toRadixString(16).toUpperCase().padLeft(2, '0')}';
    final cumminsNotes = _cumminsNotes[pid.id];

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + short name + hex ──
          Row(
            children: [
              Expanded(
                child: Text(pid.name, style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary)),
              ),
              if (pid.isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: AppColors.criticalDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('CRITICAL', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.critical, fontSize: 8, fontWeight: FontWeight.w700,
                  )),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _TagChip(label: pid.shortName, color: AppColors.dataAccent),
              const SizedBox(width: 6),
              _TagChip(label: 'PID $hexCode', color: AppColors.textTertiary),
              const SizedBox(width: 6),
              _TagChip(label: pid.unit, color: AppColors.primary),
              const SizedBox(width: 6),
              _TagChip(label: _tierLabel(pid.tier), color: _tierColor(pid.tier)),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Range bar ──
          _RangeBar(pid: pid, threshold: threshold),

          const SizedBox(height: AppSpacing.md),

          // ── Stats grid ──
          Row(
            children: [
              _StatBox(label: 'Min', value: _fmt(pid.minValue), unit: pid.unit),
              const SizedBox(width: AppSpacing.sm),
              if (pid.normalMin != null)
                _StatBox(label: 'Normal Low', value: _fmt(pid.normalMin!), unit: pid.unit),
              if (pid.normalMin != null)
                const SizedBox(width: AppSpacing.sm),
              if (pid.normalMax != null)
                _StatBox(label: 'Normal High', value: _fmt(pid.normalMax!), unit: pid.unit),
              if (pid.normalMax != null)
                const SizedBox(width: AppSpacing.sm),
              _StatBox(label: 'Max', value: _fmt(pid.maxValue), unit: pid.unit),
            ],
          ),

          // ── Alert thresholds ──
          if (threshold != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (threshold.warnLow != null || threshold.warnHigh != null)
                  _AlertBox(
                    label: 'WARN',
                    value: _thresholdText(threshold.warnLow, threshold.warnHigh, pid.unit),
                    color: AppColors.warning,
                  ),
                if (threshold.warnLow != null || threshold.warnHigh != null)
                  const SizedBox(width: AppSpacing.sm),
                if (threshold.critLow != null || threshold.critHigh != null)
                  _AlertBox(
                    label: 'CRIT',
                    value: _thresholdText(threshold.critLow, threshold.critHigh, pid.unit),
                    color: AppColors.critical,
                  ),
              ],
            ),
          ],

          // ── Cummins notes ──
          if (cumminsNotes != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryDim.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('6.7L CUMMINS NOTES', style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 4),
                  Text(cumminsNotes, style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary, height: 1.4,
                  )),
                ],
              ),
            ),
          ],

          // ── AI context ──
          const SizedBox(height: AppSpacing.sm),
          Text(pid.aiContext, style: AppTypography.bodySmall.copyWith(
            fontStyle: FontStyle.italic,
          )),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  static String _tierLabel(PollTier tier) {
    switch (tier) {
      case PollTier.fast:
        return 'FAST';
      case PollTier.medium:
        return 'MED';
      case PollTier.slow:
        return 'SLOW';
      case PollTier.background:
        return 'BG';
    }
  }

  static Color _tierColor(PollTier tier) {
    switch (tier) {
      case PollTier.fast:
        return AppColors.success;
      case PollTier.medium:
        return AppColors.dataAccent;
      case PollTier.slow:
        return AppColors.warning;
      case PollTier.background:
        return AppColors.textTertiary;
    }
  }

  static String _thresholdText(double? low, double? high, String unit) {
    if (low != null && high != null) return '< ${_fmt(low)} / > ${_fmt(high)} $unit';
    if (low != null) return '< ${_fmt(low)} $unit';
    if (high != null) return '> ${_fmt(high)} $unit';
    return '';
  }

  // ── 2026 6.7L Cummins-specific notes per PID ──
  static const _cumminsNotes = <String, String>{
    'rpm': 'The 6.7L Cummins idles at 650-750 RPM. Governed speed is ~3,200 RPM. '
        'High idle (defrost/AC) runs ~1,000 RPM. During regen, idle may climb to ~1,100 RPM. '
        'Most highway cruising sits at 1,500-1,800 RPM.',

    'engineLoadObd2': 'At cruise on flat ground, expect 15-35%. Towing a heavy trailer uphill can push '
        '80-100%. Idle load is typically 5-15%. Sustained 100% indicates full rated power (~370 HP).',

    'coolantTemp': 'Thermostat opens at ~195°F. Normal operating is 190-210°F. '
        'Towing in summer may push 210-215°F. Over 220°F triggers a warning. '
        'Over 240°F is critical — pull over immediately. Cold start will read ambient until warmup.',

    'speed': 'Stock speed limiter is typically 95-100 mph (electronically governed). '
        'Most Ram 3500 owners see 65-75 mph cruising. Speed is read from the ABS wheel speed sensors.',

    'intakeTemp': 'After the intercooler, intake air should be within 20-40°F of ambient on a '
        'well-functioning system. Readings consistently over 150°F under load may indicate '
        'a clogged intercooler or air leak.',

    'maf': 'At idle expect ~15-30 g/s. Under full load the 6.7L can pull 300-400+ g/s. '
        'A dirty air filter or intake leak will show lower-than-expected MAF at higher loads.',

    'runTime': 'Seconds since engine start. Resets each key cycle. Useful for tracking warmup time — '
        'the 6.7L typically reaches operating temp in 5-10 minutes depending on ambient.',

    'runtimeExtended': 'Extended runtime counter. Same as runTime but uses the multi-frame extended PID. '
        'Rolls over at 65,535 seconds (~18 hours).',

    'fuelLevel': 'The 2019+ Ram 3500 has a 32-gallon tank. 15% is ~4.8 gallons remaining. '
        'Diesel fuel gauges can be inaccurate below 1/4 tank. DEF consumption is roughly 2-3% of fuel usage.',

    'barometric': 'Sea level is ~101 kPa. Denver (~5,280 ft) reads ~84 kPa. '
        'The ECM uses this to adjust fueling and turbo boost targets. '
        'Lower pressure = less available power.',

    'batteryVoltage': 'The dual-battery system should read 13.8-14.5V with engine running. '
        'Below 12.6V with engine off may indicate a weak battery. '
        'Below 11.5V can cause ECM communication issues and hard starts.',

    'ambientTemp': 'Used by the ECM for fuel trim, glow plug timing, and fan control. '
        'Below 0°F the Cummins extends glow plug cycle time. '
        'Block heater recommended below 0°F for reliable starts.',

    'intercoolerOutletTemp': 'Should be within 30-50°F of ambient under light load. Under heavy towing, '
        'may climb to 150-180°F. Over 200°F indicates the intercooler is struggling — check for debris '
        'on the intercooler fins.',

    'railPressure': 'At idle, expect 5,000-8,000 PSI. Under load, 20,000-29,000 PSI is normal. '
        'Full load peak is ~29,000 PSI. Below 4,000 PSI at idle suggests a fuel filter restriction, '
        'CP4.2 pump wear, or injector leak-back. Rapid pressure drops are serious.',

    'exhaustBackpressure': 'Normal is 1-5 kPa at idle, 8-15 kPa under load. '
        'Over 20 kPa suggests DPF loading or exhaust restriction. '
        'During active regen, backpressure will rise as DPF temps climb. '
        'Sustained >30 kPa indicates a severely loaded DPF.',

    'accelPedalD': 'Driver demand input. 0% at rest, 100% at floor. '
        'The ECM uses this plus engine load, boost, and EGT to determine actual fueling. '
        'If pedal reads >0% at rest, check the APP sensor.',

    'demandTorque': 'What the ECM is requesting from the engine as a percentage of reference torque. '
        'Can go negative during engine braking / exhaust brake. '
        'Towing uphill at full throttle should approach 90-100%.',

    'actualTorque': 'What the engine is actually producing. Compare to demandTorque — '
        'a large gap means the engine can\'t meet demand (boost leak, fuel restriction, derating). '
        'Negative values indicate engine braking.',

    'referenceTorque': 'The base torque value in Nm that the percentages are calculated from. '
        'For the 6.7L Cummins (2019+), this is typically ~1,180-1,356 Nm (~870-1,000 lb-ft). '
        'Multiply by actualTorque% to get real torque output.',

    'commandedEgr': 'EGR recirculates exhaust back into intake to lower NOx. '
        'Expect 0% at idle/cold and 10-40% at cruise. EGR is disabled during regen '
        'and at high load. A stuck EGR valve can cause rough idle and excess soot.',

    'commandedThrottle': 'The 6.7L uses an electronic throttle for EGR flow control and engine braking, '
        'NOT for power control like a gas engine. Normally 80-100% open. '
        'Closes during exhaust brake activation.',

    'boostPressureCtrl': 'Commanded boost target. At idle, near 0 PSI (atmospheric). '
        'Under full load, the 6.7L targets 30-45 PSI depending on altitude and conditions. '
        'Towing at altitude will show lower targets.',

    'vgtControlObd': 'Variable Geometry Turbo vane position. 0% = fully open (low boost, high flow), '
        '100% = fully closed (max boost, spool). At idle the VGT is mostly open. '
        'Under load it closes to build boost. Sticky vanes cause poor spool or overboost.',

    'turboInletPressure': 'Pressure at the turbo compressor inlet (pre-turbo). Should be near barometric '
        'at idle. Readings significantly below ambient indicate a restricted air filter. '
        'Check filter if >2 PSI below baro under load.',

    'turboInletTemp': 'Air temperature entering the turbo compressor. Should be close to ambient. '
        'If significantly higher than ambient, check for hot air recirculation '
        'or underhood heat soak issues.',

    'chargeAirTemp': 'Post-intercooler air temperature heading into the intake manifold. '
        'Ideally within 20-50°F of ambient. High readings reduce power and increase EGT. '
        'Compare with turboInletTemp to assess intercooler efficiency.',

    'egtObd2': 'Pre-turbo exhaust gas temperature. Normal driving 400-800°F. '
        'Towing uphill can reach 900-1,100°F. Over 1,100°F is a warning — back off throttle. '
        'Over 1,400°F risks turbo and manifold damage. During active regen, DPF temps (not this sensor) '
        'reach 1,000-1,200°F.',

    'dpfTemp': 'DPF inlet temperature. During normal driving, 300-600°F. '
        'During active regeneration, 1,000-1,200°F is normal and expected. '
        'If you see regen-level temps without a regen in progress, investigate. '
        'Excessive temps can damage the DPF substrate.',
  };
}

// ── Range bar visualization ──

class _RangeBar extends StatelessWidget {
  final PidDefinition pid;
  final ThresholdLevel? threshold;

  const _RangeBar({required this.pid, this.threshold});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: CustomPaint(
        size: const Size(double.infinity, 20),
        painter: _RangeBarPainter(pid: pid, threshold: threshold),
      ),
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  final PidDefinition pid;
  final ThresholdLevel? threshold;

  _RangeBarPainter({required this.pid, this.threshold});

  @override
  void paint(Canvas canvas, Size size) {
    final range = pid.maxValue - pid.minValue;
    if (range <= 0) return;

    double toX(double value) =>
        ((value - pid.minValue) / range * size.width).clamp(0, size.width);

    // Background track
    final bgPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 6, size.width, 8),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // Normal range (green zone)
    if (pid.normalMin != null && pid.normalMax != null) {
      final normalPaint = Paint()
        ..color = AppColors.success.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      final left = toX(pid.normalMin!);
      final right = toX(pid.normalMax!);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 6, right - left, 8),
          const Radius.circular(4),
        ),
        normalPaint,
      );
    }

    // Warning zones
    if (threshold != null) {
      final warnPaint = Paint()
        ..color = AppColors.warning.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final critPaint = Paint()
        ..color = AppColors.critical.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;

      if (threshold!.warnHigh != null) {
        final x = toX(threshold!.warnHigh!);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 6, size.width - x, 8),
            const Radius.circular(4),
          ),
          warnPaint,
        );
      }
      if (threshold!.critHigh != null) {
        final x = toX(threshold!.critHigh!);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 6, size.width - x, 8),
            const Radius.circular(4),
          ),
          critPaint,
        );
      }
      if (threshold!.warnLow != null) {
        final x = toX(threshold!.warnLow!);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 6, x, 8),
            const Radius.circular(4),
          ),
          warnPaint,
        );
      }
      if (threshold!.critLow != null) {
        final x = toX(threshold!.critLow!);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 6, x, 8),
            const Radius.circular(4),
          ),
          critPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Small UI components ──

class _ChipBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(
        color: color, fontWeight: FontWeight.w600,
      )),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(
        color: color, fontSize: 9, fontWeight: FontWeight.w600,
      )),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatBox({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(label, style: AppTypography.labelSmall.copyWith(fontSize: 8)),
            const SizedBox(height: 2),
            Text(value, style: AppTypography.dataSmall.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AlertBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AlertBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.labelSmall.copyWith(
                    color: color, fontSize: 8, fontWeight: FontWeight.w700,
                  )),
                  Text(value, style: AppTypography.labelSmall.copyWith(
                    color: color.withValues(alpha: 0.8), fontSize: 9,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
