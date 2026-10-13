import 'package:flutter/material.dart';

import '../../theme.dart';

class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.values,
    this.width,
    this.height = ForgeSpacing.xxxl,
    this.gradient,
    this.showArea = true,
    this.progress = 1,
    this.showEndDot = false,
    this.endDotScale = 1,
  });

  final List<double> values;
  final double? width;
  final double height;
  final LinearGradient? gradient;
  final bool showArea;
  final double progress;
  final bool showEndDot;
  final double endDotScale;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          gradient: gradient ?? tokens.chartGradient,
          areaGradient: tokens.primaryGradient,
          trackColor: tokens.surfaceVariant,
          showArea: showArea,
          progress: progress,
          showEndDot: showEndDot,
          endDotScale: endDotScale,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.gradient,
    required this.areaGradient,
    required this.trackColor,
    required this.showArea,
    required this.progress,
    required this.showEndDot,
    required this.endDotScale,
  });

  final List<double> values;
  final LinearGradient gradient;
  final LinearGradient areaGradient;
  final Color trackColor;
  final bool showArea;
  final double progress;
  final bool showEndDot;
  final double endDotScale;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final points = values.where((value) => value.isFinite).toList();
    if (points.isEmpty) {
      final trackPaint = Paint()
        ..color = trackColor
        ..strokeWidth = ForgeSpacing.xxs
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        trackPaint,
      );
      return;
    }

    final minValue = points.reduce((a, b) => a < b ? a : b);
    final maxValue = points.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final inset = ForgeSpacing.xs;
    final drawableHeight = (size.height - inset * 2).clamp(0.0, size.height);
    final coordinates = List.generate(points.length, (index) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * index / (points.length - 1);
      final normalized = range == 0 ? 0.5 : (points[index] - minValue) / range;
      final y = inset + (1 - normalized) * drawableHeight;
      return Offset(x, y);
    });

    if (coordinates.length == 1) {
      canvas.drawCircle(
        coordinates.single,
        ForgeSpacing.xxs,
        Paint()..color = gradient.colors.first,
      );
      return;
    }

    final linePath = Path()..moveTo(coordinates.first.dx, coordinates.first.dy);
    for (final point in coordinates.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }

    final metric = linePath.computeMetrics().first;
    final drawProgress = progress.clamp(0.0, 1.0);
    if (showArea && drawProgress >= 1) {
      final areaPath = Path.from(linePath)
        ..lineTo(coordinates.last.dx, size.height)
        ..lineTo(coordinates.first.dx, size.height)
        ..close();
      final areaColors = areaGradient.colors
          .map((color) => color.withValues(alpha: 0.18))
          .toList();
      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: areaGradient.begin,
            end: areaGradient.end,
            colors: areaColors,
          ).createShader(Offset.zero & size),
      );
    }

    final visiblePath = metric.extractPath(0, metric.length * drawProgress);
    canvas.drawPath(
      visiblePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ForgeSpacing.xxs
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = gradient.createShader(Offset.zero & size),
    );
    if (showEndDot && drawProgress >= 1) {
      canvas.drawCircle(
        coordinates.last,
        ForgeSpacing.xs * endDotScale,
        Paint()..color = gradient.colors.last,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.gradient != gradient ||
      oldDelegate.areaGradient != areaGradient ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.showArea != showArea ||
      oldDelegate.progress != progress ||
      oldDelegate.showEndDot != showEndDot ||
      oldDelegate.endDotScale != endDotScale;
}
