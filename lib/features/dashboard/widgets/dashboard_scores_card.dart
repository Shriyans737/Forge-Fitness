import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/motion.dart';
import '../../../theme.dart';
import '../../../widgets/ui/gradient_ring.dart';
import '../../../widgets/ui/shimmer_box.dart';
import '../services/score_calculator.dart';
import 'dashboard_card.dart';

enum _ScoreKind { recovery, strain, sleep }

class DashboardScoresCard extends StatelessWidget {
  const DashboardScoresCard({
    required this.scores,
    required this.history,
    this.replayTrigger,
    required this.reduceMotion,
    required this.isRefreshing,
    required this.onOpenHealth,
    required this.hasHealthData,
    super.key,
  });

  final ScoreSnapshot? scores;
  final List<ScoreSnapshot> history;
  final ValueListenable<int>? replayTrigger;
  final bool reduceMotion;
  final bool isRefreshing;
  final VoidCallback onOpenHealth;
  final bool hasHealthData;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final sleepMinutes = scores?.asleepMinutes;
    final sleepLabel = sleepMinutes == null
        ? 'No data'
        : _duration(sleepMinutes);
    return DashboardCard(
      surfaceGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tokens.accentTeal.withValues(alpha: 0.09),
          tokens.surface,
          tokens.surface,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "TODAY'S SCORES",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    letterSpacing: 1.56,
                    fontWeight: FontWeight.w600,
                    color: tokens.textMuted,
                  ),
                ),
              ),
              Tooltip(
                message:
                    'Forge estimates based on Apple Health and your '
                    'logged workouts; these are not Whoop scores.',
                child: IconButton(
                  tooltip: 'Estimated scores: how this works',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showEstimateInfo(context),
                  icon: Icon(
                    Icons.info_outline_rounded,
                    color: tokens.textSecondary,
                    size: 19,
                  ),
                ),
              ),
              Text(
                'Estimated',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.cardGap),
          Row(
            children: [
              Expanded(
                child: _ScoreRing(
                  kind: _ScoreKind.recovery,
                  index: 0,
                  replayTrigger: replayTrigger,
                  title: 'RECOVERY',
                  value: scores?.recoveryScore,
                  maxValue: 100,
                  subtitle: scores?.recoveryScore == null
                      ? 'Calibrating ${scores?.calibrationDays ?? 0}/4'
                      : ScoreCalculator.zoneForScore(scores?.recoveryScore),
                  tokens: tokens,
                  reduceMotion: reduceMotion,
                  isRefreshing: isRefreshing,
                  onTap: () => _showDetails(context, _ScoreKind.recovery),
                ),
              ),
              Expanded(
                child: _ScoreRing(
                  kind: _ScoreKind.strain,
                  index: 1,
                  replayTrigger: replayTrigger,
                  title: 'STRAIN',
                  value: scores?.strainScore,
                  maxValue: 21,
                  subtitle: scores?.hasStrainData == true
                      ? ScoreCalculator.strainLabelFor(scores!.strainScore)
                      : 'No activity data',
                  tokens: tokens,
                  reduceMotion: reduceMotion,
                  isRefreshing: isRefreshing,
                  onTap: () => _showDetails(context, _ScoreKind.strain),
                ),
              ),
              Expanded(
                child: _ScoreRing(
                  kind: _ScoreKind.sleep,
                  index: 2,
                  replayTrigger: replayTrigger,
                  title: 'SLEEP',
                  value: scores?.sleepScore,
                  maxValue: 100,
                  subtitle: sleepLabel,
                  tokens: tokens,
                  reduceMotion: reduceMotion,
                  isRefreshing: isRefreshing,
                  onTap: () => _showDetails(context, _ScoreKind.sleep),
                ),
              ),
            ],
          ),
          if (!hasHealthData || scores?.asleepMinutes == null) ...[
            const SizedBox(height: ForgeSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasHealthData ? 'No sleep data yet' : 'No Health data yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                ),
                const SizedBox(width: ForgeSpacing.xs),
                TextButton(
                  onPressed: onOpenHealth,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: ForgeSpacing.sm,
                      vertical: ForgeSpacing.xxs,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: tokens.accentTeal.withValues(alpha: 0.12),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Open Health'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEstimateInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => const _EstimateInfoSheet(),
    );
  }

  void _showDetails(BuildContext context, _ScoreKind kind) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _ScoreDetailSheet(
        kind: kind,
        scores: scores,
        history: history,
        onOpenHealth: onOpenHealth,
      ),
    );
  }
}

class _ScoreRing extends StatefulWidget {
  const _ScoreRing({
    required this.kind,
    required this.index,
    required this.replayTrigger,
    required this.title,
    required this.value,
    required this.maxValue,
    required this.subtitle,
    required this.tokens,
    required this.reduceMotion,
    required this.isRefreshing,
    required this.onTap,
  });

  final _ScoreKind kind;
  final int index;
  final ValueListenable<int>? replayTrigger;
  final String title;
  final double? value;
  final double maxValue;
  final String subtitle;
  final ForgeTokens tokens;
  final bool reduceMotion;
  final bool isRefreshing;
  final VoidCallback onTap;

  @override
  State<_ScoreRing> createState() => _ScoreRingState();
}

class _ScoreRingState extends State<_ScoreRing> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ForgeMotion.scoreRing,
  );
  late final AnimationController _breathing = AnimationController(
    vsync: this,
    duration: ForgeMotion.strainGlow,
  );
  late Animation<double> _valueAnimation;
  Timer? _entryDelay;
  int? _lastReplayValue;
  bool _pendingReplay = false;
  bool _pendingDataChange = false;
  double get _target =>
      widget.value?.clamp(0.0, widget.maxValue).toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    _lastReplayValue = widget.replayTrigger?.value;
    widget.replayTrigger?.addListener(_replayTriggerChanged);
    _valueAnimation = AlwaysStoppedAnimation<double>(
      widget.reduceMotion ? _target : 0,
    );
    if (widget.isRefreshing) {
      _pendingReplay = true;
    } else {
      _animateTo(_target, first: true);
    }
    _syncBreathing();
  }

  @override
  void didUpdateWidget(covariant _ScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayTrigger != widget.replayTrigger) {
      oldWidget.replayTrigger?.removeListener(_replayTriggerChanged);
      _lastReplayValue = widget.replayTrigger?.value;
      widget.replayTrigger?.addListener(_replayTriggerChanged);
    }

    final valueChanged = oldWidget.value != widget.value;
    final reduceMotionChanged = oldWidget.reduceMotion != widget.reduceMotion;
    if (widget.isRefreshing) {
      if (valueChanged) _pendingDataChange = true;
      if (!oldWidget.isRefreshing) {
        final hadEntryDelay = _entryDelay != null;
        _entryDelay?.cancel();
        _entryDelay = null;
        if (_controller.isAnimating || hadEntryDelay) {
          _controller.stop();
          _pendingDataChange = true;
        }
      }
    } else if (oldWidget.isRefreshing) {
      if (_pendingReplay) {
        _animateTo(_target, fromZero: true);
      } else if (_pendingDataChange || valueChanged || reduceMotionChanged) {
        _animateTo(_target);
      }
      _pendingReplay = false;
      _pendingDataChange = false;
    } else if (valueChanged || reduceMotionChanged) {
      _animateTo(_target);
    }
    if (valueChanged || reduceMotionChanged) {
      _syncBreathing();
    }
  }

  void _replayTriggerChanged() {
    final replayValue = widget.replayTrigger?.value;
    if (replayValue == null || replayValue == _lastReplayValue) return;
    _lastReplayValue = replayValue;
    if (widget.isRefreshing) {
      _pendingReplay = true;
    } else {
      _animateTo(_target, fromZero: true);
    }
  }

  void _animateTo(double target, {bool first = false, bool fromZero = false}) {
    _entryDelay?.cancel();
    _entryDelay = null;
    _controller.stop();
    final current = first || fromZero
        ? (widget.reduceMotion ? target : 0.0)
        : _valueAnimation.value;
    final immediate = widget.reduceMotion || widget.value == null;
    _valueAnimation = Tween<double>(
      begin: immediate ? target : current,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: ForgeMotion.easeOut));
    if (immediate) {
      _controller.value = 1;
    } else {
      _entryDelay?.cancel();
      final delay = ForgeMotion.scoreRingStagger * widget.index;
      if (delay == Duration.zero) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 0;
        _entryDelay = Timer(delay, () {
          _entryDelay = null;
          if (mounted) _controller.forward(from: 0);
        });
      }
    }
  }

  void _syncBreathing() {
    _breathing.stop();
    _breathing.value = 0;
    if (widget.kind == _ScoreKind.strain &&
        !widget.reduceMotion &&
        (widget.value ?? 0) > 14) {
      _breathing.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _entryDelay?.cancel();
    widget.replayTrigger?.removeListener(_replayTriggerChanged);
    _controller.dispose();
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRefreshing) {
      return Column(
        children: [
          GradientRing(
            value: null,
            size: 92,
            strokeWidth: 9,
            gradient: _gradient(0),
            animate: false,
            dashedTrack: widget.kind == _ScoreKind.recovery,
          ),
          const SizedBox(height: ForgeSpacing.xs),
          Text(widget.title, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: ForgeSpacing.xxs),
          const ShimmerBox(width: 52, height: 12),
        ],
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _breathing]),
      builder: (context, _) {
        final score = _valueAnimation.value;
        final progress = (score / widget.maxValue).clamp(0.0, 1.0).toDouble();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glow = widget.kind == _ScoreKind.strain && score > 14
            ? 0.10 + _breathing.value * 0.14
            : 0.11;
        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: RepaintBoundary(
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: _gradient(score).colors.first
                                  .withValues(alpha: glow),
                              blurRadius: 7,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: GradientRing(
                    key: ValueKey('dashboard-score-${widget.kind.name}-ring'),
                    value: progress,
                    size: 92,
                    strokeWidth: 9,
                    gradient: _gradient(score),
                    animate: false,
                    dashedTrack:
                        widget.kind == _ScoreKind.recovery &&
                        widget.value == null,
                    centerChild: Text(
                      widget.value == null ? '—' : _formatScore(score),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: widget.tokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ForgeSpacing.xs),
                Text(
                  widget.title,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.tokens.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ForgeSpacing.xxs),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    widget.subtitle,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: widget.tokens.textMuted,
                      fontSize: 13,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  LinearGradient _gradient(double score) {
    if (widget.kind != _ScoreKind.recovery) {
      return widget.kind == _ScoreKind.strain
          ? widget.tokens.strainGradient
          : widget.tokens.recoveryGradient;
    }
    final red = widget.tokens.error;
    final yellow = widget.tokens.warning;
    final green = widget.tokens.success;
    final Color color;
    if (score <= 33) {
      color = Color.lerp(red, yellow, score / 33) ?? red;
    } else if (score <= 66) {
      color = Color.lerp(yellow, green, (score - 33) / 33) ?? yellow;
    } else {
      color = green;
    }
    return LinearGradient(
      colors: [color, Color.lerp(color, green, 0.24) ?? color],
    );
  }

  String _formatScore(double score) {
    if (widget.value == null) return '—';
    return widget.kind == _ScoreKind.strain
        ? score.toStringAsFixed(1)
        : score.round().toString();
  }
}

class _ScoreDetailSheet extends StatelessWidget {
  const _ScoreDetailSheet({
    required this.kind,
    required this.scores,
    required this.history,
    required this.onOpenHealth,
  });

  final _ScoreKind kind;
  final ScoreSnapshot? scores;
  final List<ScoreSnapshot> history;
  final VoidCallback onOpenHealth;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final score = scores;
    final (title, value, meaning) = switch (kind) {
      _ScoreKind.recovery => (
        'Recovery',
        score?.recoveryScore == null
            ? 'Calibrating · ${score?.calibrationDays ?? 0}/4 days'
            : '${score!.recoveryScore!.round()} · ${score.recoveryZone}',
        'Recovery estimates how ready your body may be, using personal heart-rate baselines and sleep.',
      ),
      _ScoreKind.strain => (
        'Strain',
        score == null
            ? '0 · Light'
            : '${score.strainScore.toStringAsFixed(1)} · ${score.strainLabel}',
        'Strain estimates today’s cardiovascular and logged workout load. It is not a medical measure.',
      ),
      _ScoreKind.sleep => (
        'Sleep',
        score?.asleepMinutes == null
            ? 'No sleep data'
            : '${_duration(score!.asleepMinutes!)} · ${score.sleepScore?.round() ?? '—'} score',
        'Sleep summarizes time asleep, time in bed, and available sleep-stage data.',
      ),
    };

    return _SpringSlideIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ForgeSpacing.lg,
          ForgeSpacing.md,
          ForgeSpacing.lg,
          ForgeSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: ForgeSpacing.xxs,
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(tokens.pillRadius),
                  ),
                ),
              ),
              const SizedBox(height: ForgeSpacing.md),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: ForgeSpacing.xs),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tokens.accentTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: ForgeSpacing.xs),
              Text(
                meaning,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: tokens.textSecondary),
              ),
              const SizedBox(height: ForgeSpacing.lg),
              if (kind == _ScoreKind.recovery) ...[
                _detailMetric(
                  context,
                  'HRV',
                  _compare(score?.hrv, score?.hrvBaseline, 'ms'),
                ),
                _detailMetric(
                  context,
                  'Resting heart rate',
                  _compare(
                    score?.restingHeartRate,
                    score?.restingHeartRateBaseline,
                    'bpm',
                  ),
                ),
                _MiniScoreChart(
                  title: '7-day recovery',
                  history: history,
                  valueFor: (day) => day.recoveryScore,
                  today: scores?.date,
                ),
              ] else if (kind == _ScoreKind.strain) ...[
                Text(
                  'Minutes in heart-rate zones',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: ForgeSpacing.xs),
                for (var zone = 1; zone <= 5; zone++)
                  _detailMetric(
                    context,
                    'Zone $zone',
                    '${(score?.zoneMinutes[zone] ?? 0).round()} min',
                  ),
                _detailMetric(
                  context,
                  'Forge workout contribution',
                  '${score?.workoutSets ?? 0} sets · ${(score?.workoutVolume ?? 0).round()} kg volume',
                ),
                _MiniScoreChart(
                  title: '7-day strain',
                  history: history,
                  valueFor: (day) => day.strainScore,
                  maxValue: 21,
                  today: scores?.date,
                ),
              ] else if (score?.asleepMinutes == null) ...[
                Text(
                  'No sleep data. Wear your watch to bed or log sleep in Apple Health.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tokens.textSecondary),
                ),
                TextButton(
                  onPressed: onOpenHealth,
                  child: const Text('Open Health tab'),
                ),
              ] else ...[
                _detailMetric(
                  context,
                  'Asleep',
                  _duration(score!.asleepMinutes!),
                ),
                _detailMetric(
                  context,
                  'In bed',
                  score.inBedMinutes == null
                      ? 'Not available'
                      : _duration(score.inBedMinutes!),
                ),
                _detailMetric(
                  context,
                  'Efficiency',
                  score.sleepEfficiency == null
                      ? 'Not available'
                      : '${(score.sleepEfficiency! * 100).round()}%',
                ),
                if (_hasStages(score))
                  _SleepStageBar(score: score, tokens: tokens),
                _MiniScoreChart(
                  title: '7-day sleep score',
                  history: history,
                  valueFor: (day) => day.sleepScore,
                  today: scores?.date,
                ),
              ],
              const SizedBox(height: ForgeSpacing.md),
              Text(
                'Estimated · Based on Apple Health and Forge data',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailMetric(BuildContext context, String label, String value) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ForgeSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }

  static String _compare(double? value, double? baseline, String unit) {
    if (value == null) return 'No data';
    final current = '${value.round()} $unit';
    return baseline == null
        ? '$current · baseline not available'
        : '$current · baseline ${baseline.round()} $unit';
  }

  static bool _hasStages(ScoreSnapshot score) =>
      (score.deepMinutes ?? 0) > 0 ||
      (score.remMinutes ?? 0) > 0 ||
      (score.lightMinutes ?? 0) > 0 ||
      (score.awakeMinutes ?? 0) > 0;
}

class _SleepStageBar extends StatelessWidget {
  const _SleepStageBar({required this.score, required this.tokens});

  final ScoreSnapshot score;
  final ForgeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final stages = [
      (score.deepMinutes ?? 0, tokens.accentTeal, 'Deep'),
      (score.remMinutes ?? 0, tokens.recoveryGradient.colors.last, 'REM'),
      (score.lightMinutes ?? 0, tokens.accentLime, 'Light'),
      (score.awakeMinutes ?? 0, tokens.warning, 'Awake'),
    ];
    final total = stages.fold<double>(0, (sum, stage) => sum + stage.$1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ForgeSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sleep stages', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: ForgeSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.pillRadius),
            child: SizedBox(
              height: ForgeSpacing.sm,
              child: Row(
                children: [
                  for (final (minutes, color, _) in stages)
                    if (minutes > 0)
                      Expanded(
                        flex: math
                            .max(1, (minutes / total * 100).round())
                            .toInt(),
                        child: ColoredBox(color: color),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ForgeSpacing.xs),
          Wrap(
            spacing: ForgeSpacing.sm,
            runSpacing: ForgeSpacing.xxs,
            children: [
              for (final (minutes, color, label) in stages)
                if (minutes > 0)
                  Text(
                    '$label ${_duration(minutes)}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: color),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniScoreChart extends StatefulWidget {
  const _MiniScoreChart({
    required this.title,
    required this.history,
    required this.valueFor,
    required this.today,
    this.maxValue = 100,
  });

  final String title;
  final List<ScoreSnapshot> history;
  final double? Function(ScoreSnapshot) valueFor;
  final DateTime? today;
  final double maxValue;

  @override
  State<_MiniScoreChart> createState() => _MiniScoreChartState();
}

class _MiniScoreChartState extends State<_MiniScoreChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ForgeMotion.sparklinePulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  void _syncPulse() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final days = widget.history.take(7).toList(growable: false);
    if (days.every((day) => widget.valueFor(day) == null)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: ForgeSpacing.md),
        child: Text(
          'Your 7-day chart will appear as Forge collects daily scores.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: tokens.textSecondary),
        ),
      );
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: ForgeSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: ForgeSpacing.sm),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < days.length; index++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: LayoutBuilder(
                        builder: (context, _) {
                          final score = widget.valueFor(days[index]);
                          final fraction = score == null
                              ? 0.0
                              : (score / widget.maxValue).clamp(0.0, 1.0);
                          final isToday =
                              widget.today != null &&
                              ScoreCalculator.dayKey(days[index].date) ==
                                  ScoreCalculator.dayKey(widget.today!);
                          return AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) {
                              final pulse = isToday && !reduceMotion
                                  ? 0.96 + _pulse.value * 0.04
                                  : 1.0;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    score?.round().toString() ?? '—',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                  const SizedBox(height: ForgeSpacing.xxs),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: fraction),
                                        duration: reduceMotion
                                            ? Duration.zero
                                            : ForgeMotion.chartBar +
                                                  ForgeMotion.cardStagger *
                                                      index,
                                        curve: ForgeMotion.easeOut,
                                        builder: (context, value, _) =>
                                            Transform.scale(
                                              scale: pulse,
                                              alignment: Alignment.bottomCenter,
                                              child: FractionallySizedBox(
                                                heightFactor: value,
                                                widthFactor: 0.76,
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        tokens.primaryGradient,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          tokens.pillRadius,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: ForgeSpacing.xxs),
                                  Text(
                                    _weekday(days[index].date.weekday),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weekday(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _EstimateInfoSheet extends StatelessWidget {
  const _EstimateInfoSheet();

  @override
  Widget build(BuildContext context) {
    return _SpringSlideIn(
      child: const Padding(
        padding: EdgeInsets.all(ForgeSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forge estimates',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: ForgeSpacing.sm),
            Text(
              'These scores are Forge estimates calculated from Apple Health '
              'measurements and workouts logged in Forge. They are not Whoop’s '
              'proprietary scores and are not medical advice. Recovery needs at '
              'least four days of personal heart-rate history to calibrate.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SpringSlideIn extends StatefulWidget {
  const _SpringSlideIn({required this.child});

  final Widget child;

  @override
  State<_SpringSlideIn> createState() => _SpringSlideInState();
}

class _SpringSlideInState extends State<_SpringSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 1;
    } else {
      _controller.value = 0;
      _controller.animateWith(
        SpringSimulation(ForgeMotion.sheetSpring, 0, 1, 0),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, (1 - _controller.value) * ForgeMotion.entryOffset),
      child: child,
    ),
  );
}

String _duration(double minutes) {
  final rounded = minutes.round();
  final hours = rounded ~/ 60;
  final remainingMinutes = rounded % 60;
  return hours > 0 ? '${hours}h ${remainingMinutes}m' : '${remainingMinutes}m';
}
