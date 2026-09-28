import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';

class NearbyRadarWidget extends StatefulWidget {
  const NearbyRadarWidget({super.key});

  @override
  State<NearbyRadarWidget> createState() => _NearbyRadarWidgetState();
}

class _NearbyRadarWidgetState extends State<NearbyRadarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              progress: _controller.value,
              accentColor: AppColors.accent,
              primaryColor: context.colorScheme.primary,
              ringColor: context.convoColors.radarRingColor,
              fillColor: context.convoColors.radarFillColor,
            ),
            child: Center(child: _buildCenterBeacon(context)),
          );
        },
      ),
    );
  }

  Widget _buildCenterBeacon(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.meshGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.radar_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.accentColor,
    required this.primaryColor,
    required this.ringColor,
    required this.fillColor,
  });

  final double progress;
  final Color accentColor;
  final Color primaryColor;
  final Color ringColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Background concentric rings
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const ringCount = 3;
    for (int i = 1; i <= ringCount; i++) {
      final r = maxRadius * (i / ringCount);
      canvas.drawCircle(center, r, ringPaint);
    }

    // Outer subtle fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, fillPaint);

    // Expanding pulse ripple 1
    final pulseRadius1 = (progress * maxRadius);
    final pulseOpacity1 = (1.0 - progress).clamp(0.0, 1.0);
    final pulsePaint1 = Paint()
      ..color = accentColor.withValues(alpha: pulseOpacity1 * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, pulseRadius1, pulsePaint1);

    // Expanding pulse ripple 2 (offset)
    final progress2 = (progress + 0.5) % 1.0;
    final pulseRadius2 = (progress2 * maxRadius);
    final pulseOpacity2 = (1.0 - progress2).clamp(0.0, 1.0);
    final pulsePaint2 = Paint()
      ..color = primaryColor.withValues(alpha: pulseOpacity2 * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, pulseRadius2, pulsePaint2);

    // Rotating radar sweep beam
    final sweepAngle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.25),
        ],
        stops: const [0.8, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Simulated peer node points on the radar mesh
    _drawNode(canvas, center, maxRadius * 0.65, 0.7, accentColor);
    _drawNode(canvas, center, maxRadius * 0.85, 2.3, primaryColor);
    _drawNode(canvas, center, maxRadius * 0.48, 4.1, accentColor);
  }

  void _drawNode(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    Color color,
  ) {
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);
    final nodePos = Offset(x, y);

    // Node glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nodePos, 8, glowPaint);

    // Node core
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(nodePos, 4, corePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
