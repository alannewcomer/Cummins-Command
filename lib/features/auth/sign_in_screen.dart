import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../providers/auth_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Router redirect handles navigation once authStateProvider fires.
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        setState(() {
          _error = msg.toLowerCase().contains('cancel') ? null : msg;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo / Branding ──
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primaryDim,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: const _TurboIcon(size: 48),
              ),
              const SizedBox(height: 24),
              Text('CUMMINS COMMAND', style: AppTypography.displayMedium),
              const SizedBox(height: 8),
              Text(
                'AI-First Diesel Intelligence',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(flex: 2),

              // ── Error message ──
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.criticalDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.critical, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: AppTypography.bodySmall.copyWith(color: AppColors.critical)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Google Sign-In Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _GoogleLogo(),
                  label: Text(
                    _loading ? 'Signing in...' : 'Continue with Google',
                    style: AppTypography.button,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Your data is stored privately in your account.',
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Red arc (top-right)
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        -1.3, 2.4, false, red);

    // Blue arc (bottom-right + bottom)
    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        1.1, 1.5, false, blue);

    // Green arc (bottom-left)
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        2.6, 0.9, false, green);

    // Yellow arc (top-left)
    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75),
        3.5, 0.9, false, yellow);

    // Horizontal bar (right side of the G)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.72, cy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Turbocharger icon ─────────────────────────────────────────────────────────
// Compressor wheel viewed head-on: outer housing ring, 8 curved impeller blades,
// center shaft cap. Unmistakably diesel performance.

class _TurboIcon extends StatelessWidget {
  final double size;
  const _TurboIcon({this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TurboIconPainter()),
    );
  }
}

class _TurboIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const color = AppColors.primary;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final ringR   = size.width * 0.46;  // outer housing ring radius
    final hubR    = size.width * 0.10;  // center shaft cap radius
    final bladeOR = size.width * 0.38;  // blade tip radius
    final bladeIR = size.width * 0.13;  // blade root radius

    // ── Outer housing ring ──
    canvas.drawCircle(
      Offset(cx, cy),
      ringR,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.07
        ..strokeCap = StrokeCap.round,
    );

    // ── 8 curved impeller blades ──
    const bladeCount = 8;
    final bladePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < bladeCount; i++) {
      final baseAngle = i * (2 * pi / bladeCount);
      // Blade sweeps ~30° forward (like a real compressor wheel)
      final sweep = 2 * pi / bladeCount * 0.42;

      final rootAngle = baseAngle;
      final tipAngle  = baseAngle + sweep;

      // Blade root (near hub)
      final rx1 = cx + bladeIR * cos(rootAngle);
      final ry1 = cy + bladeIR * sin(rootAngle);

      // Blade tip (at outer radius, swept forward)
      final tx = cx + bladeOR * cos(tipAngle);
      final ty = cy + bladeOR * sin(tipAngle);

      // Trailing edge of blade root
      final rx2 = cx + bladeIR * cos(rootAngle + sweep * 0.15);
      final ry2 = cy + bladeIR * sin(rootAngle + sweep * 0.15);

      // Control point for the curved leading edge
      final cpx = cx + bladeOR * 0.55 * cos(baseAngle + sweep * 0.2);
      final cpy = cy + bladeOR * 0.55 * sin(baseAngle + sweep * 0.2);

      final path = Path()
        ..moveTo(rx1, ry1)
        ..quadraticBezierTo(cpx, cpy, tx, ty)
        ..lineTo(rx2, ry2)
        ..close();

      canvas.drawPath(path, bladePaint);
    }

    // ── Center shaft cap (solid circle) ──
    canvas.drawCircle(Offset(cx, cy), hubR, bladePaint);
    // Inner dark recess
    canvas.drawCircle(
      Offset(cx, cy),
      hubR * 0.5,
      Paint()..color = AppColors.primaryDim,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
