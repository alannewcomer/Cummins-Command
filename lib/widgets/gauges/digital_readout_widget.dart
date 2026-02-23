import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../config/thresholds.dart';
import 'gauge_painters.dart';

/// Premium digital readout with LED-panel aesthetics: scan lines,
/// grid dots, inset depth, and threshold glow. Counting animation
/// on value changes.
class DigitalReadoutWidget extends StatefulWidget {
  final String paramId;
  final double value;
  final bool showLabel;
  final bool large;
  final VoidCallback? onTap;

  const DigitalReadoutWidget({
    super.key,
    required this.paramId,
    required this.value,
    this.showLabel = true,
    this.large = false,
    this.onTap,
  });

  @override
  State<DigitalReadoutWidget> createState() => _DigitalReadoutWidgetState();
}

class _DigitalReadoutWidgetState extends State<DigitalReadoutWidget>
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
  void didUpdateWidget(DigitalReadoutWidget oldWidget) {
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
    final state = DefaultThresholds.evaluate(widget.paramId, widget.value);

    final label = pid?.shortName ?? widget.paramId.toUpperCase();
    final unit = pid?.unit ?? '';

    final stateColor = switch (state) {
      ThresholdState.normal => AppColors.dataAccent,
      ThresholdState.warning => AppColors.warning,
      ThresholdState.critical => AppColors.critical,
    };

    return GestureDetector(
      onTap: widget.onTap,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return CustomPaint(
              painter: _DigitalPanelPainter(
                stateColor: stateColor,
                state: state,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showLabel)
                      Text(
                        label,
                        style: AppTypography.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.showLabel) const SizedBox(height: 4),
                    Text(
                      formatGaugeValue(_animation.value),
                      style: (widget.large
                              ? AppTypography.dataHuge
                              : AppTypography.dataLarge)
                          .copyWith(
                        color: stateColor,
                        shadows: [
                          Shadow(
                            color: stateColor.withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit,
                      style: AppTypography.labelSmall.copyWith(
                        color: stateColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DigitalPanelPainter extends CustomPainter {
  final Color stateColor;
  final ThresholdState state;

  _DigitalPanelPainter({
    required this.stateColor,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.medium));

    // 1. Panel background with radial gradient depth
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: const [
          Color(0xFF141426),
          AppColors.surface,
          Color(0xFF0E0E1A),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // 2. Scan line overlay (horizontal lines every 3px for CRT/LCD effect)
    final scanPaint = Paint()
      ..color = AppColors.gaugeScanLine
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 3. Grid dots overlay (8px grid, LED matrix backplane)
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015);
    for (double x = 4; x < size.width; x += 8) {
      for (double y = 4; y < size.height; y += 8) {
        canvas.drawCircle(Offset(x, y), 0.5, dotPaint);
      }
    }

    // 4. Threshold glow border (colored blur on warning/critical)
    if (state != ThresholdState.normal) {
      final glowPaint = Paint()
        ..color = stateColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(rrect, glowPaint);
    }

    // Border
    final borderPaint = Paint()
      ..color = state != ThresholdState.normal
          ? stateColor.withValues(alpha: 0.3)
          : AppColors.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);

    // 5. Inner bevel (top-to-bottom subtle gradient)
    final bevelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.03),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, bevelPaint);
  }

  @override
  bool shouldRepaint(_DigitalPanelPainter oldDelegate) {
    return oldDelegate.stateColor != stateColor || oldDelegate.state != state;
  }
}
