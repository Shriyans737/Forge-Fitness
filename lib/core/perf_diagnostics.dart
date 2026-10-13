import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PerfDiagnostics {
  PerfDiagnostics._();

  static final Stopwatch _clock = Stopwatch();
  static bool _started = false;

  static bool get _enabled => kDebugMode || kProfileMode;
  static bool get inSplashWindow =>
      _clock.isRunning && _clock.elapsedMilliseconds <= 4600;

  static void start() {
    if (!_enabled || _started) return;
    _started = true;
    _clock.start();
    log('app start');
    SchedulerBinding.instance.addTimingsCallback(_logFrameTimings);
  }

  static void log(String message, {bool splashWindowOnly = false}) {
    if (!_enabled || (splashWindowOnly && !inSplashWindow)) return;
    final elapsedMs = _clock.isRunning ? _clock.elapsedMilliseconds : 0;
    debugPrint(
      '[Perf +${elapsedMs}ms ${DateTime.now().toIso8601String()}] $message',
    );
  }

  static void _logFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMicroseconds / 1000;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000;
      final totalSpanMs = timing.totalSpan.inMicroseconds / 1000;
      final slow = totalSpanMs > 16.7 || buildMs > 16.7 || rasterMs > 16.7;
      log(
        'frame build=${buildMs.toStringAsFixed(2)}ms '
        'raster=${rasterMs.toStringAsFixed(2)}ms '
        'totalSpan=${totalSpanMs.toStringAsFixed(2)}ms'
        '${slow ? ' SLOW (>16.7ms)' : ''}',
      );
    }
  }
}
