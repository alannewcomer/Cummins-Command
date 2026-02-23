import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../gauges/radial_gauge_widget.dart';
import '../gauges/linear_gauge_widget.dart';
import '../gauges/digital_readout_widget.dart';
import '../gauges/gauge_painters.dart';
import '../charts/sparkline_widget.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../config/thresholds.dart';

/// Factory that creates dashboard widgets from configuration maps.
/// Pluggable: register new widget types here, they're instantly available.
class DashboardWidgetFactory {
  DashboardWidgetFactory._();

  /// Build a widget from a dashboard configuration entry.
  static Widget build({
    required Map<String, dynamic> config,
    required Map<String, double> liveData,
    required Map<String, List<double>> sparklineData,
    void Function(String paramId)? onWidgetTap,
  }) {
    final type = config['type'] as String? ?? 'digital';
    final param = config['param'] as String? ?? '';
    final value = liveData[param] ?? 0.0;

    switch (type) {
      case 'radialGauge':
        return RadialGaugeWidget(
          paramId: param,
          value: value,
          onTap: onWidgetTap != null ? () => onWidgetTap(param) : null,
        );

      case 'linearBar':
        return LinearGaugeWidget(
          paramId: param,
          value: value,
          onTap: onWidgetTap != null ? () => onWidgetTap(param) : null,
        );

      case 'digital':
        return DigitalReadoutWidget(
          paramId: param,
          value: value,
          onTap: onWidgetTap != null ? () => onWidgetTap(param) : null,
        );

      case 'sparkline':
        return SparklineWidget(
          paramId: param,
          data: sparklineData[param] ?? [],
          onTap: onWidgetTap != null ? () => onWidgetTap(param) : null,
        );

      case 'progressRing':
        return _ProgressRingWidget(
          paramId: param,
          value: value,
          onTap: onWidgetTap != null ? () => onWidgetTap(param) : null,
        );

      case 'statusIndicator':
        return _StatusIndicatorWidget(
          paramId: param,
          value: value,
          onTap: onWidgetTap != null ? () => onWidgetTap(param) : null,
        );

      default:
        return DigitalReadoutWidget(
          paramId: param,
          value: value,
          onTap: onWidgetTap != null ? () => onWidgetTap(param) : null,
        );
    }
  }
}

/// Premium progress ring with segmented arc, tick marks, endpoint glow,
/// and ambient inner glow. Pure CustomPainter.
class _ProgressRingWidget extends StatefulWidget {
  final String paramId;
  final double value;
  final VoidCallback? onTap;

  const _ProgressRingWidget({
    required this.paramId,
    required this.value,
    this.onTap,
  });

  @override
  State<_ProgressRingWidget> createState() => _ProgressRingWidgetState();
}

class _ProgressRingWidgetState extends State<_ProgressRingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousFraction = 0;

  @override
  void initState() {
    super.initState();
    _previousFraction = _computeFraction();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: _previousFraction, end: _previousFraction)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  double _computeFraction() {
    final pid = PidRegistry.get(widget.paramId);
    final max = pid?.maxValue ?? 100;
    return (widget.value / max).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(_ProgressRingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousFraction = _animation.value;
      final newFraction = _computeFraction();
      _animation = Tween<double>(begin: _previousFraction, end: newFraction)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pid = PidRegistry.get(widget.paramId);
    final state = DefaultThresholds.evaluate(widget.paramId, widget.value);
    final label = pid?.shortName ?? widget.paramId.toUpperCase();
    final unit = pid?.unit ?? '%';

    final color = stateColorFor(state);

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          painter: _ProgressRingPainter(
                            fraction: _animation.value,
                            color: color,
                            state: state,
                          ),
                          size: Size.infinite,
                        ),
                        child!,
                      ],
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.value.toStringAsFixed(0),
                        style: AppTypography.dataLarge.copyWith(
                          color: color,
                          shadows: [
                            Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
                          ],
                        ),
                      ),
                      Text(unit, style: AppTypography.labelSmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text(label, style: AppTypography.labelMedium),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final ThresholdState state;

  static const _startAngle = -math.pi / 2; // top
  static const _fullSweep = 2 * math.pi;
  static const _tickCount = 40;

  _ProgressRingPainter({
    required this.fraction,
    required this.color,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = math.min(size.width, size.height);
    final radius = side / 2 - 6;
    final strokeWidth = side * 0.06;

    // 1. Outer glow (warning/critical)
    if (state != ThresholdState.normal) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, radius + 3, glowPaint);
    }

    // 2. Background track
    final trackPaint = Paint()
      ..color = AppColors.gaugeArc
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _fullSweep,
      false,
      trackPaint,
    );

    // 3. Segmented tick marks (40 marks around circle)
    for (int i = 0; i < _tickCount; i++) {
      final angle = _startAngle + (_fullSweep * i / _tickCount);
      final isMajor = i % 10 == 0;
      final outerR = radius + strokeWidth / 2 + 1;
      final innerR = radius + strokeWidth / 2 - (isMajor ? 5 : 3);

      final outer = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      final inner = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );

      final tickPaint = Paint()
        ..color = AppColors.textTertiary.withValues(alpha: isMajor ? 0.3 : 0.12)
        ..strokeWidth = isMajor ? 1.2 : 0.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, tickPaint);
    }

    // 4. Value arc with SweepGradient
    if (fraction > 0.005) {
      final sweep = _fullSweep * fraction;
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: _startAngle,
          endAngle: _startAngle + sweep,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.7),
            color,
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(_startAngle),
        ).createShader(arcRect);

      canvas.drawArc(arcRect, _startAngle, sweep, false, arcPaint);

      // 5. Arc endpoint glow dot
      final endAngle = _startAngle + sweep;
      final dotCenter = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      final dotGlow = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(dotCenter, 4, dotGlow);

      final dotPaint = Paint()..color = color;
      canvas.drawCircle(dotCenter, 2.5, dotPaint);
    }

    // 6. Inner ambient glow
    final innerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));
    canvas.drawCircle(center, radius * 0.7, innerGlow);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.color != color ||
        oldDelegate.state != state;
  }
}

/// Status indicator for enum/binary parameters (like DPF regen status).
class _StatusIndicatorWidget extends StatelessWidget {
  final String paramId;
  final double value;
  final VoidCallback? onTap;

  const _StatusIndicatorWidget({
    required this.paramId,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pid = PidRegistry.get(paramId);
    final label = pid?.shortName ?? paramId.toUpperCase();

    // DPF Regen Status mapping
    final statusMap = <int, (String, Color, IconData)>{
      0: ('Inactive', AppColors.success, Icons.check_circle_outline),
      1: ('Active', AppColors.warning, Icons.local_fire_department),
      2: ('Forced', AppColors.critical, Icons.warning_amber),
      3: ('Fault', AppColors.critical, Icons.error_outline),
    };

    final entry = statusMap[value.toInt()] ??
        ('Unknown', AppColors.textTertiary, Icons.help_outline);

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.$3, size: 28, color: entry.$2),
            const SizedBox(height: 6),
            Text(
              entry.$1,
              style: AppTypography.dataSmall.copyWith(color: entry.$2),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.labelSmall),
          ],
        ),
      ),
    );
  }
}
