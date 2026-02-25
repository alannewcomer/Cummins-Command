import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/drive_stats.dart';

/// 2x4 mini sparkline grid: Speed, Boost, EGT, Trans Temp,
/// RPM, Throttle, Oil Temp, Load.
class SparklineSection extends StatelessWidget {
  final DriveStats stats;
  final void Function(String paramId)? onParamTap;

  const SparklineSection({super.key, required this.stats, this.onParamTap});

  @override
  Widget build(BuildContext context) {
    final sparklines = <_SparklineData>[
      if (stats.speedSeries.length >= 2)
        _SparklineData('Speed', 'mph', stats.speedSeries, AppColors.dataAccent, 'speed'),
      if (stats.boostSeries.length >= 2)
        _SparklineData('Boost', 'PSI', stats.boostSeries, AppColors.primary, 'boostPressure'),
      if (stats.egtSeries.length >= 2)
        _SparklineData('EGT', '\u00B0F', stats.egtSeries, AppColors.critical, 'egt'),
      if (stats.transTempSeries.length >= 2)
        _SparklineData(
            'Trans', '\u00B0F', stats.transTempSeries, AppColors.warning, 'transTemp'),
      if (stats.rpmSeries.length >= 2)
        _SparklineData('RPM', '', stats.rpmSeries, AppColors.dataAccent, 'rpm'),
      if (stats.throttleSeries.length >= 2)
        _SparklineData(
            'Throttle', '%', stats.throttleSeries, AppColors.primary, 'throttlePos'),
      if (stats.oilTempSeries.length >= 2)
        _SparklineData(
            'Oil Temp', '\u00B0F', stats.oilTempSeries, AppColors.warning, 'oilTemp'),
      if (stats.loadSeries.length >= 2)
        _SparklineData('Load', '%', stats.loadSeries, AppColors.success, 'engineLoad'),
    ];

    if (sparklines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drive Trends',
            style: AppTypography.displaySmall.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.0,
            ),
            itemCount: sparklines.length,
            itemBuilder: (context, i) => _MiniSparkline(
              data: sparklines[i],
              onTap: onParamTap != null
                  ? () => onParamTap!(sparklines[i].paramId)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklineData {
  final String label;
  final String unit;
  final List<TimeSeriesPoint> series;
  final Color color;
  final String paramId;

  const _SparklineData(this.label, this.unit, this.series, this.color, this.paramId);
}

class _MiniSparkline extends StatelessWidget {
  final _SparklineData data;
  final VoidCallback? onTap;

  const _MiniSparkline({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Compute min/max for series
    double min = double.infinity, max = double.negativeInfinity;
    for (final p in data.series) {
      if (p.v < min) min = p.v;
      if (p.v > max) max = p.v;
    }
    if (min == max) {
      min -= 1;
      max += 1;
    }

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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  data.label,
                  style: AppTypography.labelSmall.copyWith(
                    color: data.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${max.toStringAsFixed(0)}${data.unit}',
                      style: AppTypography.labelSmall.copyWith(fontSize: 9),
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
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: _SparklinePainter(
                  points: data.series,
                  min: min,
                  max: max,
                  color: data.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<TimeSeriesPoint> points;
  final double min;
  final double max;
  final Color color;

  _SparklinePainter({
    required this.points,
    required this.min,
    required this.max,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final range = max - min;
    final w = size.width;
    final h = size.height;

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = points[i].t * w;
      final y = h - ((points[i].v - min) / range) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Fill gradient beneath
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.t * w, h);
    fillPath.lineTo(points.first.t * w, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}
