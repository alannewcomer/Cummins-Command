import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../config/thresholds.dart';
import 'gauge_painters.dart';

/// Premium radial gauge with metallic bezel, animated needle, threshold arcs,
/// and glass depth effects. Pure CustomPainter — no Syncfusion dependency.
class RadialGaugeWidget extends StatefulWidget {
  final String paramId;
  final double value;
  final double? minOverride;
  final double? maxOverride;
  final bool showLabel;
  final bool compact;
  final VoidCallback? onTap;

  const RadialGaugeWidget({
    super.key,
    required this.paramId,
    required this.value,
    this.minOverride,
    this.maxOverride,
    this.showLabel = true,
    this.compact = false,
    this.onTap,
  });

  @override
  State<RadialGaugeWidget> createState() => _RadialGaugeWidgetState();
}

class _RadialGaugeWidgetState extends State<RadialGaugeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: widget.value, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(RadialGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _animation.value;
      _animation = Tween<double>(begin: _previousValue, end: widget.value)
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
    final threshold = DefaultThresholds.forPid(widget.paramId);
    final state = DefaultThresholds.evaluate(widget.paramId, widget.value);

    final min = widget.minOverride ?? pid?.minValue ?? 0;
    final max = widget.maxOverride ?? pid?.maxValue ?? 100;
    final label = pid?.shortName ?? widget.paramId.toUpperCase();
    final unit = pid?.unit ?? '';
    final stateColor = stateColorFor(state);

    final zones = ThresholdZoneBuilder.build(min: min, max: max, threshold: threshold);

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _RadialGaugePainter(
                      value: _animation.value,
                      min: min,
                      max: max,
                      unit: unit,
                      stateColor: stateColor,
                      state: state,
                      zones: zones,
                      compact: widget.compact,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: stateColor.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final String unit;
  final Color stateColor;
  final ThresholdState state;
  final List<ThresholdZone> zones;
  final bool compact;

  // Arc geometry: 270° sweep from 135° to 45° (bottom-left to bottom-right)
  static const _startAngle = 135 * math.pi / 180; // 135°
  static const _sweepAngle = 270 * math.pi / 180; // 270°

  _RadialGaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.stateColor,
    required this.state,
    required this.zones,
    required this.compact,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final side = math.min(size.width, size.height);
    final outerRadius = side / 2 - 4;
    final bezelWidth = compact ? 4.0 : 6.0;
    final faceRadius = outerRadius - bezelWidth;
    final arcRadius = faceRadius * 0.82;
    final arcWidth = compact ? 6.0 : 10.0;
    final tickRadius = faceRadius * 0.82 - arcWidth / 2 - 2;
    final needleLength = faceRadius * 0.65;
    final hubRadius = compact ? side * 0.04 : side * 0.05;

    // Clamp value
    final clampedValue = value.clamp(min, max);
    final fraction = (clampedValue - min) / (max - min);
    final needleAngle = _startAngle + _sweepAngle * fraction;

    // 1. Outer glow (warning/critical only)
    if (state != ThresholdState.normal) {
      GaugePaintUtils.drawGlowEffect(canvas, center, outerRadius, stateColor);
    }

    // 2. Metallic bezel ring
    GaugePaintUtils.drawBezelRing(canvas, center, outerRadius - bezelWidth / 2, bezelWidth);

    // 3. Gauge face
    GaugePaintUtils.drawGaugeFace(canvas, center, faceRadius);

    // 4. Threshold-colored arc segments
    GaugePaintUtils.drawThresholdArc(
      canvas, center, arcRadius, arcWidth, _startAngle, _sweepAngle, zones,
    );

    // 5. Graduated tick marks
    GaugePaintUtils.drawTickMarks(
      canvas, center, tickRadius,
      _startAngle, _sweepAngle,
      majorCount: compact ? 5 : 10,
      minorPerMajor: 4,
      majorLength: compact ? 5 : 8,
      minorLength: compact ? 0 : 4,
      majorWidth: 1.5,
      minorWidth: 0.8,
      skipMinor: compact,
    );

    // 6. Scale labels (skip in compact)
    if (!compact) {
      GaugePaintUtils.drawScaleLabels(
        canvas, center, faceRadius * 0.62,
        _startAngle, _sweepAngle,
        minValue: min, maxValue: max,
        labelCount: 5,
        fontSize: side * 0.055,
      );
    }

    // 7. Glowing needle with shadow
    GaugePaintUtils.drawNeedle(
      canvas, center, needleLength, needleAngle, stateColor,
      baseWidth: compact ? 2.5 : 3.5,
    );

    // 8. Center hub
    GaugePaintUtils.drawCenterHub(canvas, center, hubRadius);

    // 9. Glass overlay
    GaugePaintUtils.drawGlassOverlay(canvas, center, faceRadius);

    // 10. Value text + unit
    _drawValueText(canvas, center, side);
  }

  void _drawValueText(Canvas canvas, Offset center, double side) {
    final valueText = formatGaugeValue(value);
    final valueFontSize = compact ? side * 0.16 : side * 0.18;
    final unitFontSize = compact ? 0.0 : side * 0.065;

    final valueTP = TextPainter(
      text: TextSpan(
        text: valueText,
        style: GoogleFonts.orbitron(
          fontSize: valueFontSize,
          fontWeight: FontWeight.w700,
          color: stateColor,
          shadows: [
            Shadow(color: stateColor.withValues(alpha: 0.5), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final valueOffset = Offset(
      center.dx - valueTP.width / 2,
      center.dy - valueTP.height / 2 + (compact ? 0 : side * 0.02),
    );
    valueTP.paint(canvas, valueOffset);

    if (!compact && unit.isNotEmpty) {
      final unitTP = TextPainter(
        text: TextSpan(
          text: unit,
          style: GoogleFonts.jetBrainsMono(
            fontSize: unitFontSize,
            fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final unitOffset = Offset(
        center.dx - unitTP.width / 2,
        valueOffset.dy + valueTP.height + 2,
      );
      unitTP.paint(canvas, unitOffset);
    }
  }

  @override
  bool shouldRepaint(_RadialGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.stateColor != stateColor ||
        oldDelegate.state != state ||
        oldDelegate.compact != compact;
  }
}
