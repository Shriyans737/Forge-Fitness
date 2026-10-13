import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion.dart';

class LiquidStartButton extends StatefulWidget {
  const LiquidStartButton({
    required this.onStartWorkout,
    this.hasActiveWorkout = false,
    this.nextTemplateName,
    this.reduceMotion = false,
    super.key,
  });

  final VoidCallback onStartWorkout;
  final bool hasActiveWorkout;
  final String? nextTemplateName;
  final bool reduceMotion;

  @override
  State<LiquidStartButton> createState() => _LiquidStartButtonState();
}

double _bobOffset(double height, double phase) {
  final progress = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  return -height *
      0.07 *
      ForgeMotion.easeInOut.transform(progress.clamp(0.0, 1.0));
}

class _LiquidStartButtonState extends State<LiquidStartButton>
    with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: ForgeMotion.liquidWave,
  );
  late final AnimationController _waveFront = AnimationController(
    vsync: this,
    duration: ForgeMotion.liquidWaveFront,
  );
  late final AnimationController _waveBack = AnimationController(
    vsync: this,
    duration: ForgeMotion.liquidWaveBack,
  );
  late final AnimationController _droplets = AnimationController(
    vsync: this,
    duration: ForgeMotion.liquidDroplets,
  );
  late final Listenable _liquidAnimations = Listenable.merge([
    _bob,
    _waveFront,
    _waveBack,
    _droplets,
  ]);
  late final _LiquidPainter _painter = _LiquidPainter();
  Timer? _fullTimer;
  Timer? _readyTimer;
  Timer? _drainTimer;
  DateTime? _holdBeganAt;
  DateTime? _quickFillBeganAt;
  DateTime? _drainBeganAt;
  double _drainFrom = ForgeMotion.liquidRestingLevel;
  bool _holding = false;
  bool _reachedFull = false;
  bool _ready = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant LiquidStartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.reduceMotion) {
      for (final controller in [_bob, _waveFront, _waveBack, _droplets]) {
        controller
          ..stop()
          ..value = 0;
      }
    } else {
      _bob.repeat();
      _waveFront.repeat();
      _waveBack.repeat();
      _droplets.repeat();
    }
  }

  @override
  void dispose() {
    _fullTimer?.cancel();
    _readyTimer?.cancel();
    _drainTimer?.cancel();
    _painter.disposeNotifier();
    _bob.dispose();
    _waveFront.dispose();
    _waveBack.dispose();
    _droplets.dispose();
    super.dispose();
  }

  void _startHold() {
    _fullTimer?.cancel();
    _readyTimer?.cancel();
    _drainTimer?.cancel();
    setState(() {
      _pressed = true;
      _holding = true;
      _reachedFull = false;
      _ready = false;
      _quickFillBeganAt = null;
      _drainBeganAt = null;
      _holdBeganAt = DateTime.now();
    });
    if (widget.reduceMotion) {
      setState(() => _reachedFull = true);
      return;
    }
    _fullTimer = Timer(ForgeMotion.liquidRise, () {
      if (!mounted || !_holding) return;
      HapticFeedback.lightImpact();
      setState(() => _reachedFull = true);
    });
  }

  void _endHold() {
    _fullTimer?.cancel();
    final level = _currentLevel();
    setState(() {
      _pressed = false;
      _holding = false;
      if (_reachedFull) {
        _ready = true;
        _holdBeganAt = null;
      } else {
        _beginDrain(level);
      }
    });
    if (_reachedFull) _scheduleStart(ForgeMotion.liquidReadyHold);
  }

  void _handlePointerUp(PointerEvent event) {
    final started = _holdBeganAt;
    if (!_holding || started == null) return;
    final heldFor = DateTime.now().difference(started);
    if (heldFor < ForgeMotion.liquidQuickTapThreshold) {
      _fullTimer?.cancel();
      setState(() {
        _holding = false;
        _pressed = false;
        _holdBeganAt = null;
        _reachedFull = false;
      });
      _quickStart();
    } else {
      _endHold();
    }
  }

  void _quickStart() {
    if (_holding || _ready) return;
    if (widget.reduceMotion) {
      widget.onStartWorkout();
      return;
    }
    _drainTimer?.cancel();
    setState(() {
      _pressed = true;
      _quickFillBeganAt = DateTime.now();
      _drainBeganAt = null;
    });
    _readyTimer = Timer(ForgeMotion.liquidQuickRise, () {
      if (!mounted) return;
      setState(() {
        _pressed = false;
        _ready = true;
      });
      _scheduleStart(ForgeMotion.liquidQuickReadyHold);
    });
  }

  void _scheduleStart(Duration delay) {
    _readyTimer?.cancel();
    _readyTimer = Timer(delay, () {
      if (!mounted) return;
      widget.onStartWorkout();
      final level = _currentLevel();
      setState(() {
        _ready = false;
        _beginDrain(level);
      });
    });
  }

  void _beginDrain(double currentLevel) {
    _holdBeganAt = null;
    _quickFillBeganAt = null;
    _drainFrom = currentLevel;
    _drainBeganAt = DateTime.now();
    _drainTimer?.cancel();
    _drainTimer = Timer(ForgeMotion.liquidDrain, () {
      if (!mounted) return;
      setState(() => _drainBeganAt = null);
    });
  }

  double _currentLevel() {
    final now = DateTime.now();
    final holdBeganAt = _holdBeganAt;
    if (_holding && holdBeganAt != null) {
      final progress =
          now.difference(holdBeganAt).inMicroseconds /
          ForgeMotion.liquidRise.inMicroseconds;
      return ForgeMotion.liquidRestingLevel +
          (1 - ForgeMotion.liquidRestingLevel) *
              ForgeMotion.liquidRiseCurve.transform(progress.clamp(0.0, 1.0));
    }
    final quickFillBeganAt = _quickFillBeganAt;
    if (quickFillBeganAt != null) {
      final progress =
          now.difference(quickFillBeganAt).inMicroseconds /
          ForgeMotion.liquidQuickRise.inMicroseconds;
      return ForgeMotion.liquidRestingLevel +
          (1 - ForgeMotion.liquidRestingLevel) *
              ForgeMotion.easeOut.transform(progress.clamp(0.0, 1.0));
    }
    if (_ready) return 1;
    final drainBeganAt = _drainBeganAt;
    if (drainBeganAt != null) {
      final progress =
          now.difference(drainBeganAt).inMicroseconds /
          ForgeMotion.liquidDrain.inMicroseconds;
      return ForgeMotion.liquidRestingLevel +
          (_drainFrom - ForgeMotion.liquidRestingLevel) *
              (1 -
                  ForgeMotion.liquidDrainCurve.transform(
                    progress.clamp(0.0, 1.0),
                  ));
    }
    if (widget.hasActiveWorkout) return 0.56;
    return ForgeMotion.liquidRestingLevel;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _liquidAnimations,
        builder: (context, _) {
          var level = widget.reduceMotion
              ? (widget.hasActiveWorkout
                    ? 0.56
                    : ForgeMotion.liquidRestingLevel)
              : _currentLevel();
          if (widget.hasActiveWorkout &&
              !_holding &&
              !_ready &&
              _drainBeganAt == null &&
              !widget.reduceMotion) {
            level += math.sin(_bob.value * math.pi * 2) * 0.025;
          }
          _painter.update(
            bobPhase: _bob.value,
            frontPhase: _waveFront.value,
            backPhase: _waveBack.value,
            dropletPhase: _droplets.value,
            level: level,
            holding: _holding,
            reducedMotion: widget.reduceMotion,
          );
          return Semantics(
            button: true,
            label: widget.hasActiveWorkout
                ? 'Resume workout'
                : 'Start a workout',
            onTap: _quickStart,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                if (!_holding && !_ready) _startHold();
              },
              onPointerUp: _handlePointerUp,
              onPointerCancel: (_) {
                if (_holding) _endHold();
              },
              child: AnimatedScale(
                scale: _pressed ? 0.985 : 1,
                duration: widget.reduceMotion
                    ? Duration.zero
                    : ForgeMotion.short,
                curve: ForgeMotion.streakPop,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF86ECD2),
                                Color(0xFFDCF67F),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        CustomPaint(painter: _painter),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.hasActiveWorkout
                                          ? 'SESSION IN PROGRESS'
                                          : 'READY WHEN YOU ARE',
                                      style: const TextStyle(
                                        color: Color(0xB304211C),
                                        fontSize: 11,
                                        letterSpacing: 1.54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _ready
                                            ? "Let's go"
                                            : widget.hasActiveWorkout
                                            ? 'Resume workout'
                                            : 'Start a workout',
                                        maxLines: 1,
                                        style: const TextStyle(
                                          color: Color(0xFF04211C),
                                          fontSize: 28,
                                          letterSpacing: -0.56,
                                          height: 1.05,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _ready
                                          ? widget.nextTemplateName ??
                                                "Let's go"
                                          : widget.hasActiveWorkout
                                          ? 'Pick up where you left off'
                                          : "Press and hold, or tap to begin",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xB304211C),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Transform.rotate(
                                angle: _reachedFull || _ready
                                    ? -math.pi / 4
                                    : 0,
                                child: AnimatedScale(
                                  scale: _reachedFull || _ready ? 1.15 : 1,
                                  duration: ForgeMotion.short,
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF04211C),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Color(0xFFDCF67F),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  factory _LiquidPainter() => _LiquidPainter._(_PainterNotifier());

  _LiquidPainter._(this._repaint) : super(repaint: _repaint);

  static final _surfacePaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static final _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static final _dropletPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static final _gooLayerPaint = Paint()
    ..filterQuality = FilterQuality.high
    ..imageFilter = ui.ImageFilter.blur(
      sigmaX: ForgeMotion.liquidMergeBlur,
      sigmaY: ForgeMotion.liquidMergeBlur,
    )
    ..colorFilter = const ColorFilter.matrix([
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      20,
      -9,
    ]);
  static final _sharpPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  double bobPhase = 0;
  double frontPhase = 0;
  double backPhase = 0;
  double dropletPhase = 0;
  double level = 0.4;
  bool holding = false;
  bool reducedMotion = false;
  final Path _liquidPath = Path();
  final Path _secondWavePath = Path();
  final _PainterNotifier _repaint;
  ui.Shader? _surfaceShader;
  Size? _shaderSize;

  void update({
    required double bobPhase,
    required double frontPhase,
    required double backPhase,
    required double dropletPhase,
    required double level,
    required bool holding,
    required bool reducedMotion,
  }) {
    final changed =
        this.bobPhase != bobPhase ||
        this.frontPhase != frontPhase ||
        this.backPhase != backPhase ||
        this.dropletPhase != dropletPhase ||
        this.level != level ||
        this.holding != holding ||
        this.reducedMotion != reducedMotion;
    this
      ..bobPhase = bobPhase
      ..frontPhase = frontPhase
      ..backPhase = backPhase
      ..dropletPhase = dropletPhase
      ..level = level
      ..holding = holding
      ..reducedMotion = reducedMotion;
    if (changed) _repaint.refresh();
  }

  void disposeNotifier() => _repaint.dispose();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final bob = reducedMotion ? 0.0 : _bobOffset(height, bobPhase);
    final surfaceY = height * (1 - level) + bob;
    _buildWave(
      _liquidPath,
      width,
      height,
      surfaceY,
      frontPhase,
      1,
      9,
      keepTextClear: true,
    );
    _buildWave(
      _secondWavePath,
      width,
      height,
      surfaceY + 8,
      backPhase,
      -1,
      6,
      keepTextClear: true,
    );

    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, _gooLayerPaint);
    _glowPaint.color = const Color(0xFF47D9A4).withValues(alpha: 0.42);
    canvas.drawPath(_liquidPath, _glowPaint);
    canvas.drawPath(_secondWavePath, _glowPaint);
    _drawDroplets(canvas, width, height, surfaceY, blurPass: true);
    canvas.restore();

    if (_shaderSize != size || _surfaceShader == null) {
      _shaderSize = size;
      _surfaceShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2FC9A8), Color(0xFF7FDC72)],
      ).createShader(bounds);
    }
    _surfacePaint.shader = _surfaceShader;
    canvas.drawPath(_liquidPath, _surfacePaint);
    _sharpPaint.color = const Color(0x8FFFFFFF);
    canvas.drawPath(_secondWavePath, _sharpPaint);
    _drawDroplets(canvas, width, height, surfaceY, blurPass: false);
  }

  void _buildWave(
    Path path,
    double width,
    double height,
    double y,
    double phase,
    double direction,
    double amplitude,
    {bool keepTextClear = false}
  ) {
    path
      ..reset()
      ..moveTo(0, y);
    for (var segment = 0; segment <= 64; segment++) {
      final x = width * segment / 64;
      final progress = (segment / 64 - 0.70) / 0.14;
      final eased = progress.clamp(0.0, 1.0);
      final smoothProgress = eased * eased * (3 - 2 * eased);
      final textClearance = keepTextClear
          ? ForgeMotion.liquidTextClearance * (1 - smoothProgress)
          : 0.0;
      final wave = math.sin(
        (segment / 64 * math.pi * 2) + direction * phase * math.pi * 2,
      );
      final secondary = math.sin(
        (segment / 64 * math.pi * 4) - direction * phase * math.pi,
      );
      path.lineTo(
        x,
        y +
            textClearance +
            wave * amplitude +
            secondary * amplitude * 0.16,
      );
    }
    path
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();
  }

  void _drawDroplets(
    Canvas canvas,
    double width,
    double height,
    double surfaceY, {
    required bool blurPass,
  }) {
    const positions = [0.82, 0.87, 0.92, 0.97];
    for (var index = 0; index < positions.length; index++) {
      const phaseOffsets = [0.0, 0.333, 0.583, 0.167];
      const diameters = [30.0, 22.0, 34.0, 20.0];
      final positionInLoop = (dropletPhase + phaseOffsets[index]) % 1;
      final rise = (1 - math.cos(positionInLoop * math.pi * 2)) / 2;
      final radius = diameters[index] * 0.5 * (0.5 + rise * 0.5);
      final y = surfaceY - 8 - rise * ForgeMotion.liquidDropletRise;
      _dropletPaint.color = blurPass
          ? const Color(0xFF2FC9A8)
          : const Color(0xFF2FC9A8);
      canvas.drawCircle(
        Offset(width * positions[index], y),
        blurPass ? radius : radius * 0.94,
        _dropletPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) => false;
}

class _PainterNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
