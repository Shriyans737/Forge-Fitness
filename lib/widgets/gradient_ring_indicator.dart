import 'dart:math' as math;

import 'package:flutter/material.dart';

class GradientRingIndicator extends StatelessWidget {
  const GradientRingIndicator({
    super.key,
    required this.progress,
    required this.gradientColors,
    required this.size,
    this.strokeWidth = 14,
    this.backgroundTrackColor = const Color(0xFF2B2D31),
    this.child,
  });

  final double progress;
  final List<Color> gradientColors;
  final double size;
  final double strokeWidth;
  final Color backgroundTrackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(
            painter: _GradientRingPainter(
              progress: clampedProgress,
              gradientColors: gradientColors,
              strokeWidth: strokeWidth,
              backgroundTrackColor: backgroundTrackColor,
            ),
            child: const SizedBox.expand(),
          ),
          if (child != null)
            Positioned.fill(
              child: Center(
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter({
    required this.progress,
    required this.gradientColors,
    required this.strokeWidth,
    required this.backgroundTrackColor,
  });

  final double progress;
  final List<Color> gradientColors;
  final double strokeWidth;
  final Color backgroundTrackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final backgroundPaint = Paint()
      ..color = backgroundTrackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, backgroundPaint);

    if (progress <= 0) {
      return;
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..color = gradientColors.first.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      glowPaint,
    );

    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: gradientColors,
        tileMode: TileMode.clamp,
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundTrackColor != backgroundTrackColor ||
        oldDelegate.gradientColors != gradientColors;
  }
}
