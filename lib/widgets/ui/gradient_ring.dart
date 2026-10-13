import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../theme.dart';
import 'shimmer_box.dart';

class GradientRing extends StatefulWidget {
  const GradientRing({
    super.key,
    required this.value,
    this.size = ForgeSpacing.xxxl * 2,
    this.strokeWidth = ForgeSpacing.xs,
    this.gradient,
    this.centerChild,
    this.animate = true,
    this.dashedTrack = false,
  });

  final double? value;
  final double size;
  final double strokeWidth;
  final LinearGradient? gradient;
  final Widget? centerChild;
  final bool animate;
  final bool dashedTrack;

  @override
  State<GradientRing> createState() => _GradientRingState();
}

class _GradientRingState extends State<GradientRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ForgeMotion.ring,
  );
  late Animation<double> _progress;
  bool _hasAnimatedInitialValue = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _progress = const AlwaysStoppedAnimation<double>(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion != _reduceMotion || !_hasAnimatedInitialValue) {
      _reduceMotion = reduceMotion;
      _setAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant GradientRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.animate != widget.animate) {
      _setAnimation();
    }
  }

  void _setAnimation() {
    final target = (widget.value ?? 0).clamp(0.0, 1.0);
    final shouldAnimate =
        widget.animate && !_reduceMotion && widget.value != null;
    final begin = _hasAnimatedInitialValue
        ? _progress.value
        : shouldAnimate
        ? 0.0
        : target;
    _progress = Tween<double>(
      begin: begin,
      end: target,
    ).animate(
      CurvedAnimation(parent: _controller, curve: ForgeMotion.referenceEase),
    );
    _hasAnimatedInitialValue = true;
    if (shouldAnimate) {
      _controller.forward(from: 0);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final gradient = widget.gradient ?? tokens.primaryGradient;
    final isLoading = widget.value == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child =
        widget.centerChild ??
        (isLoading
            ? ShimmerBox(
                width: widget.size / 3,
                height: widget.size / 3,
                borderRadius: tokens.pillRadius,
              )
            : const SizedBox.shrink());

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(
          painter: _GradientRingPainter(
            progress: isLoading ? 0 : _progress.value,
            strokeWidth: widget.strokeWidth,
            trackColor: isDark
                ? const Color.fromRGBO(255, 255, 255, 0.08)
                : tokens.surfaceVariant,
            gradient: gradient,
            dashedTrack: widget.dashedTrack,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  const _GradientRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.gradient,
    required this.dashedTrack,
  });

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final LinearGradient gradient;
  final bool dashedTrack;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    if (dashedTrack) {
      const segments = 23;
      const segmentSweep = math.pi * 2 / segments * 0.25;
      for (var index = 0; index < segments; index++) {
        canvas.drawArc(
          rect,
          index * math.pi * 2 / segments,
          segmentSweep,
          false,
          trackPaint,
        );
      }
    } else {
      canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    }
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) return;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: gradient.colors,
        stops: gradient.stops,
      ).createShader(rect);
    final sweep = math.max(
      2 * math.pi / 180,
      math.pi * 2 * clampedProgress,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep.clamp(0.0, math.pi * 2),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.gradient != gradient;
}
