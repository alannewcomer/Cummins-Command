import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../config/thresholds.dart';
import 'gauge_painters.dart';

/// Premium linear bar gauge with inner shadow, threshold markers, fill glow,
/// tick marks, and glass highlight. Pure CustomPainter.
class LinearGaugeWidget extends StatefulWidget {
  final String paramId;
  final double value;
  final double? minOverride;
  final double? maxOverride;
  final bool showLabel;
  final bool horizontal;
  final VoidCallback? onTap;

  const LinearGaugeWidget({
    super.key,
    required this.paramId,
    required this.value,
    this.minOverride,
    this.maxOverride,
    this.showLabel = true,
    this.horizontal = true,
    this.onTap,
  });

  @override
  State<LinearGaugeWidget> createState() => _LinearGaugeWidgetState();
}

class _LinearGaugeWidgetState extends State<LinearGaugeWidget>
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
    final min = widget.minOverride ?? pid?.minValue ?? 0;
    final max = widget.maxOverride ?? pid?.maxValue ?? 100;
    return ((widget.value - min) / (max - min)).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(LinearGaugeWidget oldWidget) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLabel)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppTypography.labelMedium),
                  Text(
                    '${widget.value.toStringAsFixed(widget.value >= 100 ? 0 : 1)} $unit',
                    style: AppTypography.dataSmall.copyWith(
                      color: stateColor,
                      shadows: [
                        Shadow(color: stateColor.withValues(alpha: 0.4), blurRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          RepaintBoundary(
            child: SizedBox(
              height: 20,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _LinearGaugePainter(
                      fraction: _animation.value,
                      stateColor: stateColor,
                      state: state,
                      zones: zones,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinearGaugePainter extends CustomPainter {
  final double fraction;
  final Color stateColor;
  final ThresholdState state;
  final List<ThresholdZone> zones;

  _LinearGaugePainter({
    required this.fraction,
    required this.stateColor,
    required this.state,
    required this.zones,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = h / 2;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(radius),
    );

    // 1. Background track with inner shadow
    final trackPaint = Paint()..color = AppColors.gaugeArc;
    canvas.drawRRect(trackRect, trackPaint);

    // Inner shadow gradient (top darker)
    final innerShadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h / 2));
    canvas.drawRRect(trackRect, innerShadow);

    // 2. Threshold zone markers
    for (final zone in zones) {
      if (zone.endFraction < 1.0 && zone.endFraction > 0.0) {
        final x = w * zone.endFraction;
        final markerPaint = Paint()
          ..color = zone.color.withValues(alpha: 0.5)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(x, h * 0.1), Offset(x, h * 0.9), markerPaint);
      }
    }

    // 3. Fill bar with gradient
    if (fraction > 0.005) {
      final fillWidth = (w * fraction).clamp(h, w); // at least pill-shaped
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillWidth, h),
        Radius.circular(radius),
      );

      // 4. Fill glow (behind fill)
      if (state != ThresholdState.normal) {
        final glowPaint = Paint()
          ..color = stateColor.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawRRect(fillRect, glowPaint);
      }

      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            stateColor.withValues(alpha: 0.4),
            stateColor.withValues(alpha: 0.8),
            stateColor,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, fillWidth, h));
      canvas.drawRRect(fillRect, fillPaint);

      // Bright tip glow
      final tipGlow = Paint()
        ..color = stateColor.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(fillWidth - 2, h / 2), 3, tipGlow);
    }

    // 5. Tick marks along bottom edge (every 10%)
    for (int i = 1; i < 10; i++) {
      final x = w * i / 10;
      final isMajor = i % 5 == 0;
      final tickPaint = Paint()
        ..color = AppColors.textTertiary.withValues(alpha: isMajor ? 0.3 : 0.15)
        ..strokeWidth = isMajor ? 1.0 : 0.5;
      final tickHeight = isMajor ? h * 0.35 : h * 0.2;
      canvas.drawLine(Offset(x, h - tickHeight), Offset(x, h), tickPaint);
    }

    // 6. Glass highlight (thin line near top)
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.1, 0.5, 0.9],
      ).createShader(Rect.fromLTWH(0, 1, w, 2))
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(radius, 2), Offset(w - radius, 2), highlightPaint);

    // 7. Edge glow (warning/critical border)
    if (state != ThresholdState.normal) {
      final edgeGlow = Paint()
        ..color = stateColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawRRect(trackRect, edgeGlow);
    }
  }

  @override
  bool shouldRepaint(_LinearGaugePainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.stateColor != stateColor ||
        oldDelegate.state != state;
  }
}
