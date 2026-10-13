import 'dart:math' as math;

import 'package:flutter/material.dart';

class LockedDialGauge extends StatelessWidget {
  const LockedDialGauge({
    super.key,
    required this.progress,
    required this.locked,
    required this.valueText,
    this.size = 200,
    this.gradientColors = const [
      Color(0xFF14B8A6),
      Color(0xFF4ADE80),
      Color(0xFFA3E635),
    ],
    this.subtitleText,
    this.labelText,
  });

  final double progress;
  final bool locked;
  final String valueText;
  final double size;
  final List<Color> gradientColors;
  final String? subtitleText;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LockedDialPainter(
          progress: clamped,
          gradientColors: gradientColors,
          locked: locked,
          valueText: valueText,
          subtitleText: subtitleText,
          labelText: labelText,
        ),
      ),
    );
  }
}

class _LockedDialPainter extends CustomPainter {
  const _LockedDialPainter({
    required this.progress,
    required this.gradientColors,
    required this.locked,
    required this.valueText,
    required this.subtitleText,
    required this.labelText,
  });

  final double progress;
  final List<Color> gradientColors;
  final bool locked;
  final String valueText;
  final String? subtitleText;
  final String? labelText;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);

    if (!locked) {
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
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
        activePaint,
      );
    }

    final indicatorPaint = Paint()
      ..color = const Color(0xFF5EEAD4)
      ..style = PaintingStyle.fill;
    final indicatorCenter = center + Offset(0, -radius + 8);
    canvas.drawCircle(indicatorCenter, 6, indicatorPaint);

    if (locked) {
      final iconText = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.lock_outline.codePoint),
          style: TextStyle(
            fontSize: 54,
            fontFamily: Icons.lock_outline.fontFamily,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        center.dx - iconText.width / 2,
        center.dy - iconText.height / 2,
      );
      iconText.paint(canvas, offset);
      return;
    }

    final valuePainter = TextPainter(
      text: TextSpan(
        text: valueText,
        style: const TextStyle(
          fontSize: 42,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelPainter = (labelText == null || labelText!.isEmpty)
        ? null
        : TextPainter(
            text: TextSpan(
              text: labelText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            textDirection: TextDirection.ltr,
          );

    final subtitlePainter = (subtitleText == null || subtitleText!.isEmpty)
        ? null
        : TextPainter(
            text: TextSpan(
              text: subtitleText,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          );

    labelPainter?.layout();
    subtitlePainter?.layout();

    final totalHeight = valuePainter.height +
        (labelPainter?.height ?? 0) +
        (subtitlePainter?.height ?? 0) +
        18;
    final valueTop = center.dy - totalHeight / 2;

    valuePainter.paint(
      canvas,
      Offset(center.dx - valuePainter.width / 2, valueTop),
    );

    if (labelPainter != null) {
      labelPainter.paint(
        canvas,
        Offset(
          center.dx - labelPainter.width / 2,
          valueTop + valuePainter.height + 6,
        ),
      );
    }

    if (subtitlePainter != null) {
      subtitlePainter.paint(
        canvas,
        Offset(
          center.dx - subtitlePainter.width / 2,
          valueTop + valuePainter.height + (labelPainter?.height ?? 0) + 12,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LockedDialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.locked != locked ||
        oldDelegate.valueText != valueText ||
        oldDelegate.subtitleText != subtitleText ||
        oldDelegate.labelText != labelText;
  }
}

double cos(double angle) => math.cos(angle);
double sin(double angle) => math.sin(angle);
