import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../models/did_scan_result.dart';
import '../../providers/did_scanner_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/did_scanner_service.dart';
import '../../services/diagnostic_service.dart';
import '../../widgets/common/glass_card.dart';

/// Mode $22 DID Scanner — dev tool for discovering enhanced parameters.
class DidScannerScreen extends ConsumerStatefulWidget {
  const DidScannerScreen({super.key});

  @override
  ConsumerState<DidScannerScreen> createState() => _DidScannerScreenState();
}

class _DidScannerScreenState extends ConsumerState<DidScannerScreen> {
  // Range toggles — all enabled by default
  final _rangeEnabled = <String, bool>{
    'powertrain': true,
    'enhanced': true,
    'bodyChassis': true,
    'udsStandard': true,
    'manufacturer': true,
  };

  DidScanSummary? _summary;
  bool _saving = false;
  String? _saveError;

  List<(int, int)> get _selectedRanges {
    final ranges = <(int, int)>[];
    if (_rangeEnabled['powertrain']!) ranges.add(DidRanges.powertrain);
    if (_rangeEnabled['enhanced']!) ranges.add(DidRanges.enhanced);
    if (_rangeEnabled['bodyChassis']!) ranges.add(DidRanges.bodyChassis);
    if (_rangeEnabled['udsStandard']!) ranges.add(DidRanges.udsStandard);
    if (_rangeEnabled['manufacturer']!) ranges.add(DidRanges.manufacturer);
    return ranges;
  }

  Future<void> _startScan() async {
    final scanner = ref.read(didScannerServiceProvider);
    final ranges = _selectedRanges;
    if (ranges.isEmpty) return;

    setState(() => _summary = null);

    try {
      final summary = await scanner.startScan(ranges: ranges);
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
      }
    }
  }

  void _stopScan() {
    ref.read(didScannerServiceProvider).stopScan();
  }

  Future<void> _saveToFirestore() async {
    final summary = _summary;
    if (summary == null) return;

    final uid = ref.read(userIdProvider);
    final vehicle = ref.read(activeVehicleProvider);
    if (uid == null || vehicle == null) {
      setState(() => _saveError = 'No user or vehicle selected');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      // Build found DIDs map — full detail for decoding later
      final foundMap = <String, Map<String, dynamic>>{};
      for (final r in summary.foundResults) {
        foundMap[r.didHex] = {
          'bytes': r.dataBytes?.length ?? 0,
          'hex': r.dataBytesHex,
          'raw': r.rawHex,
          if (r.ecuAddress != null) 'ecu': r.ecuAddress,
        };
      }

      // DIDs that exist but need specific conditions (NRC 0x22)
      final conditionsNotCorrect = <String>[];
      for (final r in summary.conditionsNotCorrectResults) {
        conditionsNotCorrect.add(r.didHex);
      }

      // DIDs that exist but are security-locked (NRC 0x33)
      final securityDenied = <String>[];
      for (final r in summary.securityDeniedResults) {
        securityDenied.add(r.didHex);
      }

      // Build NRC distribution (string keys for Firestore)
      final nrcDist = <String, int>{};
      for (final entry in summary.nrcDistribution.entries) {
        nrcDist[entry.key.toString()] = entry.value;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('vehicles')
          .doc(vehicle.id)
          .collection('didScans')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'adapterName': 'OBDLink MX+',
        'totalScanned': summary.totalScanned,
        'foundCount': summary.foundCount,
        'negativeCount': summary.negativeCount,
        'timeoutCount': summary.timeoutCount,
        'errorCount': summary.errorCount,
        'durationSeconds': summary.duration.inSeconds,
        'ranges': summary.ranges,
        'wasStopped': summary.wasStopped,
        'found': foundMap,
        'conditionsNotCorrect': conditionsNotCorrect,
        'securityDenied': securityDenied,
        'nrcDistribution': nrcDist,
        // Engine conditions for cross-referencing DID values
        'conditionsAtStart': summary.conditionsAtStart,
        'conditionsAtEnd': summary.conditionsAtEnd,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan results saved to Firestore')),
        );
      }
    } catch (e) {
      diag.error('DID-SCAN', 'Firestore save failed', e.toString());
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(didScannerServiceProvider);
    final progressAsync = ref.watch(didScanProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Mode \$22 DID Scanner', style: AppTypography.displaySmall),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Info banner — scanner auto-manages polling ──
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.dataAccentDim,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.dataAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.dataAccent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'OBD polling will auto-pause during scan and resume after.',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.dataAccent),
                  ),
                ),
              ],
            ),
          ),

          // ── Range Selection ──
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DID Ranges', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                _RangeCheckbox(
                  label: 'Powertrain (0x0100-0x02FF)',
                  count: 512,
                  value: _rangeEnabled['powertrain']!,
                  onChanged: scanner.isScanning ? null : (v) {
                    setState(() => _rangeEnabled['powertrain'] = v ?? true);
                  },
                ),
                _RangeCheckbox(
                  label: 'Enhanced (0xA000-0xA0FF)',
                  count: 256,
                  value: _rangeEnabled['enhanced']!,
                  onChanged: scanner.isScanning ? null : (v) {
                    setState(() => _rangeEnabled['enhanced'] = v ?? true);
                  },
                ),
                _RangeCheckbox(
                  label: 'Body/Chassis (0xB000-0xB0FF)',
                  count: 256,
                  value: _rangeEnabled['bodyChassis']!,
                  onChanged: scanner.isScanning ? null : (v) {
                    setState(() => _rangeEnabled['bodyChassis'] = v ?? true);
                  },
                ),
                _RangeCheckbox(
                  label: 'UDS Standard (0xF100-0xF2FF)',
                  count: 512,
                  value: _rangeEnabled['udsStandard']!,
                  onChanged: scanner.isScanning ? null : (v) {
                    setState(() => _rangeEnabled['udsStandard'] = v ?? true);
                  },
                ),
                _RangeCheckbox(
                  label: 'Manufacturer (0xFD00-0xFDFF)',
                  count: 256,
                  value: _rangeEnabled['manufacturer']!,
                  onChanged: scanner.isScanning ? null : (v) {
                    setState(() => _rangeEnabled['manufacturer'] = v ?? true);
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${DidRanges.totalDids(_selectedRanges)} DIDs selected',
                  style: AppTypography.labelSmall,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Start/Stop Button ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: scanner.isScanning
                  ? _stopScan
                  : (_selectedRanges.isEmpty ? null : _startScan),
              style: ElevatedButton.styleFrom(
                backgroundColor: scanner.isScanning
                    ? AppColors.critical
                    : AppColors.primary,
                disabledBackgroundColor: AppColors.surfaceLight,
              ),
              icon: Icon(
                scanner.isScanning ? Icons.stop : Icons.radar,
                size: 20,
              ),
              label: Text(
                scanner.isScanning ? 'Stop Scan' : 'Start Scan',
                style: AppTypography.button,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Progress (during scan) ──
          if (scanner.isScanning)
            progressAsync.when(
              data: (progress) => _ProgressCard(progress: progress),
              loading: () => _ProgressCard(
                progress: DidScanProgress(
                  current: 0,
                  total: DidRanges.totalDids(_selectedRanges),
                  currentDid: 0,
                  foundCount: 0,
                  negativeCount: 0,
                  timeoutCount: 0,
                  errorCount: 0,
                  elapsed: Duration.zero,
                ),
              ),
              error: (e, _) => Text('Error: $e', style: AppTypography.bodySmall),
            ),

          // ── Results (after scan) ──
          if (_summary != null) ...[
            _SummaryCard(summary: _summary!),
            const SizedBox(height: AppSpacing.lg),
            if (_summary!.conditionsAtStart.isNotEmpty)
              _ConditionsCard(
                conditionsAtStart: _summary!.conditionsAtStart,
                conditionsAtEnd: _summary!.conditionsAtEnd,
              ),
            if (_summary!.conditionsAtStart.isNotEmpty)
              const SizedBox(height: AppSpacing.lg),
            if (_summary!.nrcDistribution.isNotEmpty) ...[
              _NrcDistributionCard(distribution: _summary!.nrcDistribution),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_summary!.foundResults.isNotEmpty) ...[
              _FoundDidsCard(results: _summary!.foundResults),
              const SizedBox(height: AppSpacing.lg),
            ],
            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveToFirestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dataAccent,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload, size: 20),
                label: Text(
                  _saving ? 'Saving...' : 'Save to Firestore',
                  style: AppTypography.button,
                ),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _saveError!,
                style: AppTypography.labelSmall.copyWith(color: AppColors.critical),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }
}

// ─── Range Checkbox ───

class _RangeCheckbox extends StatelessWidget {
  final String label;
  final int count;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  const _RangeCheckbox({
    required this.label,
    required this.count,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 32,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            side: const BorderSide(color: AppColors.textTertiary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: AppTypography.labelMedium),
        ),
        Text(
          '$count',
          style: AppTypography.labelSmall,
        ),
      ],
    );
  }
}

// ─── Progress Card ───

class _ProgressCard extends StatelessWidget {
  final DidScanProgress progress;

  const _ProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final didHex = progress.currentDid > 0
        ? '0x${progress.currentDid.toRadixString(16).toUpperCase().padLeft(4, '0')}'
        : '...';
    final remaining = progress.estimatedRemaining;
    final remainStr = remaining.inSeconds > 0
        ? '${remaining.inMinutes}m ${remaining.inSeconds % 60}s remaining'
        : '';

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.current} / ${progress.total}',
                style: AppTypography.labelLarge,
              ),
              Text(
                'Scanning $didHex',
                style: AppTypography.labelMedium.copyWith(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.dataAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 8,
              backgroundColor: AppColors.surfaceBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _CountChip(label: 'Found', count: progress.foundCount, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              _CountChip(label: 'Neg', count: progress.negativeCount, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              _CountChip(label: 'Timeout', count: progress.timeoutCount, color: AppColors.textTertiary),
              const Spacer(),
              if (remainStr.isNotEmpty)
                Text(remainStr, style: AppTypography.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Count Chip ───

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Summary Card ───

class _SummaryCard extends StatelessWidget {
  final DidScanSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      glowColor: summary.foundCount > 0 ? AppColors.primary : null,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                summary.wasStopped ? 'Scan Stopped' : 'Scan Complete',
                style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _CountChip(label: 'Found', count: summary.foundCount, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              _CountChip(label: 'Negative', count: summary.negativeCount, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              _CountChip(label: 'Timeout', count: summary.timeoutCount, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${summary.totalScanned} DIDs in ${summary.duration.inMinutes}m ${summary.duration.inSeconds % 60}s',
            style: AppTypography.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ─── NRC Distribution Card ───

class _NrcDistributionCard extends StatelessWidget {
  final Map<int, int> distribution;

  const _NrcDistributionCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final sorted = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NRC Distribution', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      '0x${entry.key.toRadixString(16).toUpperCase().padLeft(2, '0')} '
                      '${DidScanResult.nrcName(entry.key)}',
                      style: AppTypography.labelSmall.copyWith(
                        fontFamily: 'JetBrains Mono',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${entry.value}',
                      style: AppTypography.labelMedium.copyWith(
                        fontFamily: 'JetBrains Mono',
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Found DIDs Card ───

class _FoundDidsCard extends StatelessWidget {
  final List<DidScanResult> results;

  const _FoundDidsCard({required this.results});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Found DIDs (${results.length})',
            style: AppTypography.labelLarge.copyWith(color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final r in results) _FoundDidRow(result: r),
        ],
      ),
    );
  }
}

class _FoundDidRow extends StatelessWidget {
  final DidScanResult result;

  const _FoundDidRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: result.rawHex));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied DID 0x${result.didHex} raw hex'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // DID hex
            SizedBox(
              width: 56,
              child: Text(
                '0x${result.didHex}',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dataAccent,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // ECU source
            if (result.ecuAddress != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  result.ecuAddress!,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9,
                    color: AppColors.primary,
                  ),
                ),
              ),
            // Byte count
            SizedBox(
              width: 28,
              child: Text(
                '${result.dataBytes?.length ?? 0}B',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Data hex
            Expanded(
              child: Text(
                result.dataBytesHex,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.copy, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Engine Conditions Card ───

class _ConditionsCard extends StatelessWidget {
  final Map<String, double> conditionsAtStart;
  final Map<String, double> conditionsAtEnd;

  const _ConditionsCard({
    required this.conditionsAtStart,
    required this.conditionsAtEnd,
  });

  // Key parameters to highlight for decoding reference
  static const _keyParams = [
    ('rpm', 'RPM', ''),
    ('speed', 'Speed', 'mph'),
    ('coolantTemp', 'Coolant', '\u00B0F'),
    ('intakeTemp', 'Intake', '\u00B0F'),
    ('ambientTemp', 'Ambient', '\u00B0F'),
    ('batteryVoltage', 'Battery', 'V'),
    ('maf', 'MAF', 'g/s'),
    ('egtObd2', 'EGT', '\u00B0F'),
    ('dpfTemp', 'DPF Temp', '\u00B0F'),
    ('engineLoadObd2', 'Load', '%'),
    ('boostPressureCtrl', 'Boost', 'PSI'),
    ('accelPedalD', 'Pedal', '%'),
    ('actualTorque', 'Torque', '%'),
    ('runTime', 'Runtime', 's'),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.thermostat, color: AppColors.dataAccent, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Text('Engine Conditions During Scan',
                  style: AppTypography.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Header row
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text('Param', style: AppTypography.labelSmall),
              ),
              Expanded(
                child: Text('Start', style: AppTypography.labelSmall),
              ),
              Expanded(
                child: Text('End', style: AppTypography.labelSmall),
              ),
            ],
          ),
          const Divider(color: AppColors.surfaceBorder, height: 8),
          for (final param in _keyParams)
            if (conditionsAtStart.containsKey(param.$1) ||
                conditionsAtEnd.containsKey(param.$1))
              _ConditionRow(
                label: param.$2,
                unit: param.$3,
                startVal: conditionsAtStart[param.$1],
                endVal: conditionsAtEnd[param.$1],
              ),
        ],
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  final String label;
  final String unit;
  final double? startVal;
  final double? endVal;

  const _ConditionRow({
    required this.label,
    required this.unit,
    this.startVal,
    this.endVal,
  });

  String _fmt(double? v) {
    if (v == null) return '-';
    if (v == v.roundToDouble()) return '${v.round()}$unit';
    return '${v.toStringAsFixed(1)}$unit';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _fmt(startVal),
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _fmt(endVal),
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
