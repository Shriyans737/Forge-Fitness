import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/perf_diagnostics.dart';
import '../../theme.dart';
import 'splash_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    required this.homeBuilder,
    required this.preloadFuture,
    super.key,
  });

  final WidgetBuilder homeBuilder;
  final Future<void> preloadFuture;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class SplashAnimationScope extends InheritedWidget {
  const SplashAnimationScope({
    required this.animation,
    required super.child,
    super.key,
  });

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SplashAnimationScope>()
      ?.animation;

  @override
  bool updateShouldNotify(SplashAnimationScope oldWidget) =>
      oldWidget.animation != animation;
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashBackground = Color(0xFF070C0B);
  static const _duration = Duration(milliseconds: 4600);
  static const _burstTime = 2100;
  static const _homeBuildTimeMs = 1900;
  static const _homeFadeStart = 2950 / 4600;
  static const _homeFadeEnd = 3450 / 4600;
  static const _splashFadeStart = 3150 / 4600;
  static const _splashFadeEnd = 3650 / 4600;

  late final AnimationController _controller;
  late final SplashPainter _painter;
  final Stopwatch _diagnosticClock = Stopwatch();
  Timer? _watchdog;
  int _nextProgressLogMs = 250;
  bool _preloadComplete = false;
  bool _homeMounted = false;
  bool _splashFinished = false;
  bool _splashTimedOut = false;
  bool _hapticPlayed = false;
  bool _animationsDisabled = false;
  bool _loggedRealHomeBuild = false;
  Object? _preloadError;

  @override
  void initState() {
    super.initState();
    _diagnosticClock.start();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onAnimationChanged)
      ..addStatusListener(_onAnimationStatusChanged);
    _painter = SplashPainter(
      _controller,
      wordmarkStyle: const TextStyle(),
    );
    _controller.forward();
    PerfDiagnostics.log(
      'splash controller started; duration=${_duration.inMilliseconds}ms',
    );
    if (kDebugMode) {
      debugPrint(
        '[Splash ${DateTime.now().toIso8601String()}] '
        'controller.forward() called immediately in initState',
      );
    }
    _watchdog = Timer(const Duration(seconds: 6), _onWatchdog);
    unawaited(_waitForPreload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && !_animationsDisabled) {
      _animationsDisabled = true;
      _controller
        ..stop()
        ..value = 1;
      _homeMounted = _preloadComplete;
      _splashFinished = _preloadComplete;
    }
  }

  Future<void> _waitForPreload() async {
    try {
      await widget.preloadFuture;
      PerfDiagnostics.log(
        'splash preload completed at local +${_diagnosticClock.elapsedMilliseconds}ms '
        '(controller=${_controller.value.toStringAsFixed(3)})',
        splashWindowOnly: true,
      );
      if (kDebugMode) {
        debugPrint(
          '[Splash ${DateTime.now().toIso8601String()}] '
          'preloadFuture completed at +${_diagnosticClock.elapsedMilliseconds}ms '
          '(controller=${_controller.value.toStringAsFixed(3)})',
        );
      }
    } catch (error, stackTrace) {
      _preloadError = error;
      debugPrint(
        '[Splash ${DateTime.now().toIso8601String()}] '
        'preloadFuture threw at +${_diagnosticClock.elapsedMilliseconds}ms: '
        '$error\n$stackTrace',
      );
    }

    if (!mounted) return;
    PerfDiagnostics.log(
      'SplashScreen setState: preload complete; '
      'controller=${_controller.value.toStringAsFixed(3)}',
      splashWindowOnly: true,
    );
    setState(() {
      _preloadComplete = true;
      if ((_controller.value * _duration.inMilliseconds).round() >=
          _homeBuildTimeMs) {
        _homeMounted = true;
      }
      if (_splashTimedOut || _animationsDisabled) {
        _homeMounted = true;
        _splashFinished = true;
      }
    });
    _finishIfReady();
  }

  void _onAnimationChanged() {
    final animationMs = (_controller.value * _duration.inMilliseconds).round();
    if (animationMs >= _nextProgressLogMs) {
      PerfDiagnostics.log(
        'splash controller.value=${_controller.value.toStringAsFixed(3)} '
        'animation=${animationMs}ms elapsed=${_diagnosticClock.elapsedMilliseconds}ms',
        splashWindowOnly: true,
      );
      if (kDebugMode) {
        debugPrint(
          '[Splash ${DateTime.now().toIso8601String()}] '
          'controller.value=${_controller.value.toStringAsFixed(3)} '
          't=${animationMs}ms elapsed=${_diagnosticClock.elapsedMilliseconds}ms',
        );
      }
      _nextProgressLogMs = (animationMs ~/ 250 + 1) * 250;
    }

    if (!_homeMounted &&
        _preloadComplete &&
        animationMs >= _homeBuildTimeMs) {
      PerfDiagnostics.log(
        'SplashScreen setState: mounting real home at animation=${animationMs}ms',
        splashWindowOnly: true,
      );
      setState(() => _homeMounted = true);
    }
    if (!_animationsDisabled &&
        !_hapticPlayed &&
        animationMs >= _burstTime) {
      _hapticPlayed = true;
      unawaited(HapticFeedback.lightImpact());
    }
    if (_controller.isCompleted) _finishIfReady();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (kDebugMode) {
        debugPrint(
          '[Splash ${DateTime.now().toIso8601String()}] '
          'controller status completed; preload=$_preloadComplete '
          'homeMounted=$_homeMounted',
        );
      }
      _finishIfReady();
    }
  }

  void _finishIfReady() {
    if (!mounted ||
        _animationsDisabled ||
        !_controller.isCompleted ||
        !_preloadComplete ||
        _splashFinished) {
      if (kDebugMode && _controller.isCompleted) {
        debugPrint(
          '[Splash ${DateTime.now().toIso8601String()}] '
          'finish deferred: animationsDisabled=$_animationsDisabled '
          'preload=$_preloadComplete homeMounted=$_homeMounted '
          'finished=$_splashFinished',
        );
      }
      return;
    }
    if (kDebugMode) {
      debugPrint(
        '[Splash ${DateTime.now().toIso8601String()}] '
        'splash finished; showing real home',
      );
    }
    PerfDiagnostics.log(
      'SplashScreen setState: splash finished; showing real home',
      splashWindowOnly: true,
    );
    setState(() => _splashFinished = true);
  }

  void _onWatchdog() {
    if (!mounted || _splashFinished) return;
    debugPrint(
      '[Splash ${DateTime.now().toIso8601String()}] '
      '6-second watchdog fired; controller=${_controller.value.toStringAsFixed(3)}, '
      'preloadComplete=$_preloadComplete',
    );
    _controller
      ..stop()
      ..value = 1;
    setState(() {
      _splashTimedOut = true;
      if (_preloadComplete) {
        _homeMounted = true;
        _splashFinished = true;
      }
    });
  }

  void _skipSplash() {
    if (_splashFinished || _animationsDisabled) return;
    unawaited(
      _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildRealHome(BuildContext context) {
    if (!_loggedRealHomeBuild) {
      _loggedRealHomeBuild = true;
      PerfDiagnostics.log(
        'real home first build; splash elapsed=${_diagnosticClock.elapsedMilliseconds}ms',
      );
    }
    return widget.homeBuilder(context);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _controller
      ..removeListener(_onAnimationChanged)
      ..removeStatusListener(_onAnimationStatusChanged)
      ..dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationsDisabled && _preloadComplete) {
      return _buildRealHome(context);
    }
    if (_splashFinished && _preloadComplete) {
      final home = _buildRealHome(context);
      if (_preloadError == null) return home;
      return Stack(
        fit: StackFit.expand,
        children: [
          home,
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(ForgeSpacing.md),
              child: Material(
                color: Theme.of(context).extension<ForgeTokens>()?.surface,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(ForgeSpacing.sm),
                  child: Text('Forge could not finish loading startup data.'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_splashTimedOut) return const _SplashTimeoutScreen();

    final tokens = Theme.of(context).extension<ForgeTokens>();
    final wordmarkStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: tokens?.textPrimary ?? Colors.white,
      fontWeight: FontWeight.w800,
    );
    _painter.updateWordmarkStyle(wordmarkStyle ?? const TextStyle());
    final home = _homeMounted && _preloadComplete
        ? _buildRealHome(context)
        : const SizedBox.expand();

    return Scaffold(
      backgroundColor: _splashBackground,
      body: AnimatedBuilder(
        animation: _controller,
        child: SplashAnimationScope(animation: _controller, child: home),
        builder: (context, child) {
          final progress = _controller.value;
          final homeOpacity = _interval(progress, _homeFadeStart, _homeFadeEnd);
          final splashOpacity =
              1 - _interval(progress, _splashFadeStart, _splashFadeEnd);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skipSplash,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: _splashBackground,
                  child: Opacity(opacity: homeOpacity, child: child),
                ),
                if (!_controller.isCompleted)
                  Opacity(
                    opacity: splashOpacity,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _painter,
                        willChange: true,
                      ),
                    ),
                  ),
                if (_controller.isCompleted && !_preloadComplete)
                  Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens?.accentTeal ?? const Color(0xFF2EE6C5),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _interval(double value, double start, double end) {
    if (value <= start) return 0;
    if (value >= end) return 1;
    return (value - start) / (end - start);
  }
}

class _SplashTimeoutScreen extends StatelessWidget {
  const _SplashTimeoutScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070C0B),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top_rounded, size: 34),
                SizedBox(height: 16),
                Text(
                  'Forge is taking longer than expected to load.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Your data is safe. Please close and reopen Forge to retry.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
