import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/sparkcharts.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../config/thresholds.dart';

/// Compact sparkline chart showing recent 10-minute trend.
/// Used in dashboard widgets and quick-glance displays.
class SparklineWidget extends StatelessWidget {
  final String paramId;
  final List<double> data;
  final bool showLabel;
  final Color? colorOverride;
  final VoidCallback? onTap;

  const SparklineWidget({
    super.key,
    required this.paramId,
    required this.data,
    this.showLabel = true,
    this.colorOverride,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pid = PidRegistry.get(paramId);
    final label = pid?.shortName ?? paramId.toUpperCase();
    final unit = pid?.unit ?? '';
    final currentValue = data.isNotEmpty ? data.last : 0.0;
    final state = DefaultThresholds.evaluate(paramId, currentValue);

    final color = colorOverride ??
        switch (state) {
          ThresholdState.normal => AppColors.dataAccent,
          ThresholdState.warning => AppColors.warning,
          ThresholdState.critical => AppColors.critical,
        };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppTypography.labelSmall),
                  Text(
                    '${currentValue.toStringAsFixed(currentValue >= 100 ? 0 : 1)} $unit',
                    style: AppTypography.dataSmall.copyWith(color: color),
                  ),
                ],
              ),
            if (showLabel) const SizedBox(height: 6),
            Expanded(
              child: data.length >= 2
                  ? SfSparkAreaChart(
                      data: data,
                      color: color.withValues(alpha: 0.3),
                      borderColor: color,
                      borderWidth: 2,
                      axisLineColor: Colors.transparent,
                      firstPointColor: Colors.transparent,
                      lastPointColor: color,
                    )
                  : Center(
                      child: Text(
                        'Waiting...',
                        style: AppTypography.labelSmall,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
