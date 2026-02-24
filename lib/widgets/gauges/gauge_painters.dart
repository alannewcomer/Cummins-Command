import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../config/thresholds.dart';

/// Data class representing a colored zone on a gauge arc.
class ThresholdZone {
  final double startFraction; // 0.0–1.0
  final double endFraction;
  final Color color;

  const ThresholdZone({
    required this.startFraction,
    required this.endFraction,
    required this.color,
  });
}

/// Converts a ThresholdLevel into ordered colored zones for gauge rendering.
class ThresholdZoneBuilder {
  ThresholdZoneBuilder._();

  static List<ThresholdZone> build({
    required double min,
    required double max,
    ThresholdLevel? threshold,
  }) {
    final range = max - min;
    if (range <= 0) return [const ThresholdZone(startFraction: 0, endFraction: 1, color: AppColors.success)];

    double toFraction(double value) => ((value - min) / range).clamp(0.0, 1.0);

    if (threshold == null) {
      return [ThresholdZone(startFraction: 0, endFraction: 1, color: AppColors.success.withValues(alpha: 0.3))];
    }

    final zones = <ThresholdZone>[];
    double cursor = 0.0;

    // Critical low zone
    if (threshold.critLow != null && threshold.critLow! > min) {
      final end = toFraction(threshold.critLow!);
      zones.add(ThresholdZone(startFraction: cursor, endFraction: end, color: AppColors.critical));
      cursor = end;
    }

    // Warning low zone
    if (threshold.warnLow != null && threshold.warnLow! > min) {
      final end = toFraction(threshold.warnLow!);
      if (end > cursor) {
        zones.add(ThresholdZone(startFraction: cursor, endFraction: end, color: AppColors.warning));
        cursor = end;
      }
    }

    // Normal zone
    final normalEnd = threshold.warnHigh != null
        ? toFraction(threshold.warnHigh!)
        : threshold.critHigh != null
            ? toFraction(threshold.critHigh!)
            : 1.0;
    if (normalEnd > cursor) {
      zones.add(ThresholdZone(startFraction: cursor, endFraction: normalEnd, color: AppColors.success));
      cursor = normalEnd;
    }

    // Warning high zone
    if (threshold.warnHigh != null && threshold.critHigh != null && threshold.critHigh! > threshold.warnHigh!) {
      final end = toFraction(threshold.critHigh!);
      if (end > cursor) {
        zones.add(ThresholdZone(startFraction: cursor, endFraction: end, color: AppColors.warning));
        cursor = end;
      }
    }

    // Critical high zone
    if (cursor < 1.0) {
      if (threshold.critHigh != null || threshold.warnHigh != null) {
        zones.add(ThresholdZone(startFraction: cursor, endFraction: 1.0, color: AppColors.critical));
      } else {
        zones.add(ThresholdZone(startFraction: cursor, endFraction: 1.0, color: AppColors.success));
      }
    }

    return zones;
  }
}

/// Shared painting utilities for all gauge CustomPainters.
class GaugePaintUtils {
  GaugePaintUtils._();

  /// Draws a metallic bezel ring using a SweepGradient.
  static void drawBezelRing(Canvas canvas, Offset center, double radius, double width) {
    final paint = Paint()
      ..shader = SweepGradient(
        colors: const [
          AppColors.gaugeBezelDark,
          AppColors.gaugeBezelLight,
          AppColors.gaugeBezelDark,
          AppColors.gaugeBezelLight,
          AppColors.gaugeBezelDark,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    canvas.drawCircle(center, radius, paint);
  }

  /// Draws the gauge face with a radial gradient for depth.
  static void drawGaugeFace(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF10101E),
          AppColors.gaugeFace,
          Color(0xFF060610),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  /// Draws threshold-colored arc segments.
  static void drawThresholdArc(
    Canvas canvas,
    Offset center,
    double radius,
    double arcWidth,
    double startAngle,
    double sweepAngle,
    List<ThresholdZone> zones,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (final zone in zones) {
      final zoneStart = startAngle + sweepAngle * zone.startFraction;
      final zoneSweep = sweepAngle * (zone.endFraction - zone.startFraction);

      final paint = Paint()
        ..color = zone.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, zoneStart, zoneSweep, false, paint);
    }
  }

  /// Draws graduated tick marks (major + minor).
  static void drawTickMarks(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double startAngle,
    double sweepAngle, {
    required int majorCount,
    int minorPerMajor = 4,
    double majorLength = 10,
    double minorLength = 5,
    double majorWidth = 1.5,
    double minorWidth = 0.8,
    bool skipMinor = false,
  }) {
    final majorPaint = Paint()
      ..color = AppColors.textTertiary
      ..strokeWidth = majorWidth
      ..strokeCap = StrokeCap.round;

    final minorPaint = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.4)
      ..strokeWidth = minorWidth
      ..strokeCap = StrokeCap.round;

    final totalTicks = majorCount * minorPerMajor;
    for (int i = 0; i <= totalTicks; i++) {
      final isMajor = i % minorPerMajor == 0;
      if (!isMajor && skipMinor) continue;

      final angle = startAngle + (sweepAngle * i / totalTicks);
      final length = isMajor ? majorLength : minorLength;
      final paint = isMajor ? majorPaint : minorPaint;

      final outerPoint = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final innerPoint = Offset(
        center.dx + (outerRadius - length) * math.cos(angle),
        center.dy + (outerRadius - length) * math.sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  /// Draws scale labels at arc positions using TextPainter.
  static void drawScaleLabels(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle, {
    required double minValue,
    required double maxValue,
    required int labelCount,
    required double fontSize,
    String? fontFamily,
  }) {
    for (int i = 0; i <= labelCount; i++) {
      final value = minValue + (maxValue - minValue) * i / labelCount;
      final angle = startAngle + sweepAngle * i / labelCount;

      final text = value >= 1000
          ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
          : value == value.roundToDouble()
              ? value.toInt().toString()
              : value.toStringAsFixed(1);

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: fontSize,
            fontFamily: fontFamily ?? 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelPoint = Offset(
        center.dx + radius * math.cos(angle) - tp.width / 2,
        center.dy + radius * math.sin(angle) - tp.height / 2,
      );

      tp.paint(canvas, labelPoint);
    }
  }

  /// Draws a glass overlay (subtle reflection illusion).
  static void drawGlassOverlay(Canvas canvas, Offset center, double radius) {
    // Top highlight arc
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final path = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius * 0.92),
        -math.pi,
        math.pi,
      )
      ..close();

    canvas.drawPath(path, highlightPaint);

    // Subtle edge ring
    final edgePaint = Paint()
      ..color = AppColors.gaugeGlassHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.93, edgePaint);
  }

  /// Draws a glow effect around the gauge for warning/critical states.
  static void drawGlowEffect(Canvas canvas, Offset center, double radius, Color color) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius + 4, glowPaint);

    final innerGlow = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius + 2, innerGlow);
  }

  /// Draws the metallic center hub / pivot point.
  static void drawCenterHub(Canvas canvas, Offset center, double radius) {
    // Outer ring
    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.gaugeBezelLight,
          AppColors.gaugeBezelDark,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outerPaint);

    // Inner dot
    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3A3A55),
          AppColors.gaugeBezelDark,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));
    canvas.drawCircle(center, radius * 0.6, innerPaint);
  }

  /// Draws a tapered needle with glow.
  static void drawNeedle(
    Canvas canvas,
    Offset center,
    double length,
    double angle,
    Color color, {
    double baseWidth = 3.5,
    double tailLength = 0.15,
  }) {
    final tipX = center.dx + length * math.cos(angle);
    final tipY = center.dy + length * math.sin(angle);

    final tailX = center.dx - (length * tailLength) * math.cos(angle);
    final tailY = center.dy - (length * tailLength) * math.sin(angle);

    final perpAngle = angle + math.pi / 2;
    final halfBase = baseWidth / 2;

    final baseLeft = Offset(
      center.dx + halfBase * math.cos(perpAngle),
      center.dy + halfBase * math.sin(perpAngle),
    );
    final baseRight = Offset(
      center.dx - halfBase * math.cos(perpAngle),
      center.dy - halfBase * math.sin(perpAngle),
    );

    // Needle shadow
    final shadowPath = Path()
      ..moveTo(tipX + 1, tipY + 1)
      ..lineTo(baseLeft.dx + 1, baseLeft.dy + 1)
      ..lineTo(tailX + 1, tailY + 1)
      ..lineTo(baseRight.dx + 1, baseRight.dy + 1)
      ..close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Needle body
    final needlePath = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(tailX, tailY)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();

    final needlePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(tailX, tailY),
        Offset(tipX, tipY),
        [color.withValues(alpha: 0.6), color],
      );

    canvas.drawPath(needlePath, needlePaint);

    // Needle glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(needlePath, glowPaint);
  }
}

/// Shared value formatting for gauge displays.
String formatGaugeValue(double val) {
  if (val.abs() >= 10000) return '${(val / 1000).toStringAsFixed(0)}k';
  if (val.abs() >= 1000) return val.toStringAsFixed(0);
  if (val.abs() >= 100) return val.toStringAsFixed(0);
  return val.toStringAsFixed(1);
}

/// Returns the state color for a given threshold state.
Color stateColorFor(ThresholdState state) {
  return switch (state) {
    ThresholdState.normal => AppColors.success,
    ThresholdState.warning => AppColors.warning,
    ThresholdState.critical => AppColors.critical,
  };
}
