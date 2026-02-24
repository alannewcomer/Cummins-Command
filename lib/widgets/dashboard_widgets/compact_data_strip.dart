import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../config/thresholds.dart';
import '../gauges/gauge_painters.dart';

/// Renders 3-4 PID values horizontally in one thin row (~45px).
/// Each value shows: label (shortName) + formatted number + unit,
/// color-coded by threshold. Vertical dividers between values.
class CompactDataStrip extends StatelessWidget {
  final List<String> paramIds;
  final Map<String, double> liveData;
  final void Function(String paramId)? onWidgetTap;

  const CompactDataStrip({
    super.key,
    required this.paramIds,
    required this.liveData,
    this.onWidgetTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < paramIds.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 24,
              color: AppColors.surfaceBorder,
            ),
          Expanded(
            child: _DataStripItem(
              paramId: paramIds[i],
              value: liveData[paramIds[i]] ?? 0.0,
              onTap: onWidgetTap != null
                  ? () => onWidgetTap!(paramIds[i])
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _DataStripItem extends StatelessWidget {
  final String paramId;
  final double value;
  final VoidCallback? onTap;

  const _DataStripItem({
    required this.paramId,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pid = PidRegistry.get(paramId);
    final state = DefaultThresholds.evaluate(paramId, value);
    final label = pid?.shortName ?? paramId.toUpperCase();
    final unit = pid?.unit ?? '';
    final color = state == ThresholdState.normal
        ? AppColors.dataAccent
        : stateColorFor(state);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatGaugeValue(value),
                  style: AppTypography.dataSmall.copyWith(
                    color: color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: AppTypography.labelSmall.copyWith(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
