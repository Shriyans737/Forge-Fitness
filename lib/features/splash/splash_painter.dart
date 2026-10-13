import 'dart:math' as math;

import 'package:flutter/material.dart';

class SplashPainter extends CustomPainter {
  SplashPainter(this.animation, {required this.wordmarkStyle})
    : super(repaint: animation);

  static const _durationMs = 4600.0;
  static const _burstStartMs = 2100.0;
  static const _ringRadii = [32.0, 52.0, 72.0, 92.0];
  static const _ringStarts = [0.0, 170.0, 340.0, 510.0];
  static const _ringColors = [
    Color(0xFFFF6B57),
    Color(0xFFC8F23D),
    Color(0xFF2EE6C5),
    Color(0xFF8B7BFF),
  ];
  static const _glyphs = ['F', 'o', 'r', 'g', 'e'];
  static const _tau = math.pi * 2;

  final Animation<double> animation;
  final List<Paint> _ringPaints = List<Paint>.generate(
    _ringColors.length,
    (index) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true,
    growable: false,
  );
  final List<List<Paint>> _ringGlowPaints = List<List<Paint>>.generate(
    _ringColors.length,
    (_) => List<Paint>.generate(
      2,
      (_) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
      growable: false,
    ),
    growable: false,
  );
  final Paint _trackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Paint _tickPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Paint _headPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 26)
    ..isAntiAlias = true;
  final Paint _sparkPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final Paint _centerPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final Paint _centerGlowPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final Paint _shockwavePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _bloomPaint = Paint();
  final RadialGradient _bloomGradient = const RadialGradient(
    colors: [
      Color(0x522EE6C5),
      Color(0x248B7BFF),
      Color(0x00000000),
    ],
    stops: [0, 0.5, 1],
  );
  final List<TextPainter> _glyphPainters = List<TextPainter>.generate(
    _glyphs.length,
    (_) => TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    ),
    growable: false,
  );
  final List<double> _glyphWidths = List<double>.filled(_glyphs.length, 0);
  List<Rect> _ringRects = const [];
  List<Offset> _tickStartVectors = const [];
  List<Offset> _tickEndVectors = const [];
  Size? _geometrySize;
  double _unit = 1;
  double _letterSpacing = 1.2;
  Rect _canvasRect = Rect.zero;
  Rect _bloomRect = Rect.zero;
  Offset _center = Offset.zero;
  TextStyle wordmarkStyle;

  void updateWordmarkStyle(TextStyle value) {
    if (wordmarkStyle == value) return;
    wordmarkStyle = value;
    final size = _geometrySize;
    if (size != null) {
      _layoutWordmark();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _configureGeometry(size);
    final t = animation.value * _durationMs;
    final beforeBurst = t < _burstStartMs;
    final anticipation = _easeOutCubic((t - 1750) / 350);
    final initialScale = beforeBurst ? 1 - 0.07 * anticipation : 0.93;
    final glowBoost = _clamp((t - 1700) / 400);

    _drawBloom(canvas, t);
    canvas.save();
    canvas.translate(_center.dx, _center.dy);

    _drawTracks(canvas, t, initialScale);
    _drawTicks(canvas, t, initialScale);
    _drawCenterDot(canvas, t);

    for (var index = 0; index < _ringRadii.length; index++) {
      if (beforeBurst) {
        final progress = _easeOutCubic((t - _ringStarts[index]) / 1000);
        if (progress > 0) {
          _drawRing(
            canvas,
            index: index,
            scale: initialScale,
            alpha: 1,
            progress: progress,
            glowBoost: glowBoost,
            enableGlow: true,
            showHead: progress > 0 && progress < 0.999,
            t: t,
          );
        }
      } else {
        final delay = _burstStartMs + (3 - index) * 90;
        final progress = _clamp((t - delay) / 1100);
        final scale = 0.93 + 16 * math.pow(progress, 2.4).toDouble();
        if (scale < 2.2 && progress > 0 && progress < 1) {
          for (var ghost = 3; ghost >= 1; ghost--) {
            final ghostProgress = _clamp((t - ghost * 38 - delay) / 1100);
            if (ghostProgress <= 0) continue;
            final ghostScale =
                0.93 + 16 * math.pow(ghostProgress, 2.4).toDouble();
            if (ghostScale >= 2.2) continue;
            _drawRing(
              canvas,
              index: index,
              scale: ghostScale,
              alpha: 0.2 / ghost,
              progress: 1,
              glowBoost: 0,
              enableGlow: false,
              showHead: false,
              t: t,
            );
          }
        }
        _drawRing(
          canvas,
          index: index,
          scale: scale,
          alpha: 1,
          progress: 1,
          glowBoost: 0,
          enableGlow: false,
          showHead: false,
          t: t,
        );
      }
    }

    _drawWordmark(canvas, t, initialScale);
    _drawShockwave(canvas, t);
    canvas.restore();
  }

  void _configureGeometry(Size size) {
    if (_geometrySize == size) return;
    _geometrySize = size;
    _unit = size.width / 230;
    _center = Offset(size.width / 2, size.height * 0.47);
    _canvasRect = Offset.zero & size;
    _bloomRect = Rect.fromCircle(center: _center, radius: 1.1 * size.width);
    _bloomPaint.shader = _bloomGradient.createShader(_bloomRect);
    _ringRects = List<Rect>.generate(
      _ringRadii.length,
      (index) => Rect.fromCircle(
        center: Offset.zero,
        radius: _ringRadii[index] * _unit,
      ),
      growable: false,
    );
    _trackPaint
      ..strokeWidth = 11 * _unit
      ..color = Colors.white;
    _tickPaint
      ..strokeWidth = 1.6
      ..color = Colors.white;

    _tickStartVectors = List<Offset>.generate(72, (index) {
      final angle = -math.pi / 2 + index / 72 * _tau;
      final radius = (index % 6 == 0 ? 99.0 : 101.0) * _unit;
      return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }, growable: false);
    _tickEndVectors = List<Offset>.generate(72, (index) {
      final angle = -math.pi / 2 + index / 72 * _tau;
      final radius = 105 * _unit;
      return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }, growable: false);
    _layoutWordmark();
  }

  void _layoutWordmark() {
    _letterSpacing = 1.2 * _unit;
    final style = wordmarkStyle.copyWith(
      fontSize: 14 * _unit,
      fontWeight: FontWeight.w800,
      color: wordmarkStyle.color ?? Colors.white,
    );
    for (var index = 0; index < _glyphs.length; index++) {
      final painter = _glyphPainters[index]
        ..text = TextSpan(text: _glyphs[index], style: style);
      painter.layout();
      _glyphWidths[index] = painter.width;
    }
  }

  void _drawBloom(Canvas canvas, double t) {
    final bloom = math.sin(_clamp((t - 2250) / 1100) * math.pi);
    if (bloom <= 0) return;
    _bloomPaint.color = Colors.white.withValues(alpha: bloom);
    canvas.drawRect(_canvasRect, _bloomPaint);
  }

  void _drawTracks(Canvas canvas, double t, double scale) {
    if (t >= 2200) return;
    final alpha = _clamp(t / 400) * 0.09 * (1 - _clamp((t - 2000) / 200));
    if (alpha <= 0) return;
    _trackPaint.color = Colors.white.withValues(alpha: alpha);
    canvas.save();
    canvas.scale(scale);
    for (final radius in _ringRadii) {
      canvas.drawCircle(Offset.zero, radius * _unit, _trackPaint);
    }
    canvas.restore();
  }

  void _drawTicks(Canvas canvas, double t, double scale) {
    final fade = 1 - _clamp((t - 1800) / 250);
    if (fade <= 0) return;
    final outerProgress = _easeOutCubic((t - _ringStarts.last) / 1000);
    canvas.save();
    canvas.scale(scale);
    for (var index = 0; index < 72; index++) {
      final progress = _clamp((outerProgress * 72 - index) / 3);
      if (progress <= 0) continue;
      final tickFactor = index % 6 == 0 ? 0.45 : 0.2;
      _tickPaint.color = Colors.white.withValues(
        alpha: progress * fade * tickFactor,
      );
      canvas.drawLine(
        _tickStartVectors[index],
        _tickEndVectors[index],
        _tickPaint,
      );
    }
    canvas.restore();
  }

  void _drawCenterDot(Canvas canvas, double t) {
    final alpha = 1 - _clamp((t - 700) / 300);
    if (alpha <= 0 || t <= 0) return;
    final radius = 5 * _unit * Curves.easeOutBack.transform(_clamp(t / 450));
    _centerGlowPaint.color = Colors.white.withValues(alpha: alpha * 0.16);
    _centerPaint.color = Colors.white.withValues(alpha: alpha);
    canvas.drawCircle(Offset.zero, radius * 2.2, _centerGlowPaint);
    canvas.drawCircle(Offset.zero, radius, _centerPaint);
  }

  void _drawRing(
    Canvas canvas, {
    required int index,
    required double scale,
    required double alpha,
    required double progress,
    required double glowBoost,
    required bool enableGlow,
    required bool showHead,
    required double t,
  }) {
    final color = _ringColors[index];
    final paint = _ringPaints[index]
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 11 * _unit
      ..maskFilter = null;
    final drawProgress = progress >= 0.999 ? 1.0 : progress;
    final startAngle = -math.pi / 2 - (1 - drawProgress) * 1.3;
    final sweepAngle = drawProgress * _tau;

    canvas.save();
    canvas.scale(scale);
    if (enableGlow && scale <= 2.2) {
      for (var glow = 0; glow < 2; glow++) {
        _ringGlowPaints[index][glow]
          ..color = color.withValues(
            alpha:
                alpha *
                ((glow == 0 ? 0.12 : 0.06) + glowBoost * 0.04),
          )
          ..strokeWidth =
              11 *
              _unit *
              (glow == 0 ? 1.6 : 2.4) *
              (1 + glowBoost * 0.2);
        canvas.drawArc(
          _ringRects[index],
          startAngle,
          sweepAngle,
          false,
          _ringGlowPaints[index][glow],
        );
      }
    }
    canvas.drawArc(_ringRects[index], startAngle, sweepAngle, false, paint);
    if (showHead && progress > 0 && progress < 0.999) {
      final endAngle = startAngle + sweepAngle;
      final radius = _ringRadii[index] * _unit;
      final head = Offset(
        math.cos(endAngle) * radius,
        math.sin(endAngle) * radius,
      );
      final fade = 1 - math.pow(progress, 4).toDouble();
      _headPaint.color = Colors.white.withValues(alpha: fade);
      canvas.drawCircle(head, 11 * _unit * 0.42, _headPaint);

      for (var spark = 1; spark <= 7; spark++) {
        final angle = endAngle - spark * 0.075;
        final jitter =
            math.sin(t / 55 + spark * 2.7 + index * 1.3) * (11 * _unit) * 0.85;
        final sparkRadius = radius + jitter;
        _sparkPaint.color = _ringColors[index].withValues(
          alpha: alpha * fade * 0.8 * (1 - spark / 8),
        );
        canvas.drawCircle(
          Offset(math.cos(angle) * sparkRadius, math.sin(angle) * sparkRadius),
          1.8 * _unit * (1 - spark / 9),
          _sparkPaint,
        );
      }
    }
    canvas.restore();
  }

  void _drawWordmark(Canvas canvas, double t, double scale) {
    final fade = 1 - _clamp((t - 1800) / 200);
    if (fade <= 0 || t >= _burstStartMs) return;
    final spacing = _letterSpacing;
    final totalWidth =
        _glyphWidths.reduce((sum, width) => sum + width) +
        spacing * (_glyphs.length - 1);
    var x = -totalWidth / 2;
    for (var index = 0; index < _glyphs.length; index++) {
      final progress = _easeOutCubic((t - (850 + index * 75)) / 450);
      final opacity = progress * fade;
      if (opacity > 0) {
        final rise = (1 - progress) * 7 * _unit * scale;
        canvas.save();
        canvas.translate(x, -_glyphPainters[index].height / 2 + rise);
        _glyphPainters[index].text = TextSpan(
          text: _glyphs[index],
          style: wordmarkStyle.copyWith(
            fontSize: 14 * _unit,
            fontWeight: FontWeight.w800,
            color: (wordmarkStyle.color ?? Colors.white).withValues(
              alpha: opacity,
            ),
          ),
        );
        _glyphPainters[index].layout();
        _glyphPainters[index].paint(canvas, Offset.zero);
        canvas.restore();
      }
      x += _glyphWidths[index] + spacing;
    }
  }

  void _drawShockwave(Canvas canvas, double t) {
    final elapsed = t - _burstStartMs;
    if (elapsed <= 0 || elapsed >= 1000) return;
    _shockwavePaint
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: 0.55 * (1 - elapsed / 1000));
    canvas.drawCircle(Offset.zero, elapsed * 0.77 * _unit, _shockwavePaint);
  }

  void dispose() {
    for (final painter in _glyphPainters) {
      painter.dispose();
    }
    _bloomPaint.shader = null;
  }

  static double _clamp(double value) => value.clamp(0.0, 1.0);

  static double _easeOutCubic(double value) =>
      Curves.easeOutCubic.transform(_clamp(value));

  @override
  bool shouldRepaint(covariant SplashPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.wordmarkStyle != wordmarkStyle;
}
