import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../features/splash/splash_screen.dart';
import '../../../theme.dart';
import '../../../widgets/ui/gradient_ring.dart';
import '../../../widgets/ui/shimmer_box.dart';
import 'dashboard_card.dart';

class DashboardRingMetric {
  const DashboardRingMetric({
    required this.keyName,
    required this.label,
    required this.value,
    required this.goal,
    required this.gradient,
  });

  final String keyName;
  final String label;
  final double value;
  final double goal;
  final LinearGradient gradient;

  double get progress => goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0;
}

class DashboardRingsCard extends StatelessWidget {
  const DashboardRingsCard({
    required this.metrics,
    required this.reduceMotion,
    required this.isRefreshing,
    this.onTap,
    super.key,
  });

  final List<DashboardRingMetric> metrics;
  final bool reduceMotion;
  final bool isRefreshing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return DashboardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S PROGRESS",
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: ForgeSpacing.cardGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 0; index < metrics.length; index++)
                Expanded(
                  child: _AnimatedDashboardRing(
                    metric: metrics[index],
                    index: index,
                    reduceMotion: reduceMotion,
                    isRefreshing: isRefreshing,
                    tokens: tokens,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedDashboardRing extends StatefulWidget {
  const _AnimatedDashboardRing({
    required this.metric,
    required this.index,
    required this.reduceMotion,
    required this.isRefreshing,
    required this.tokens,
  });

  final DashboardRingMetric metric;
  final int index;
  final bool reduceMotion;
  final bool isRefreshing;
  final ForgeTokens tokens;

  @override
  State<_AnimatedDashboardRing> createState() => _AnimatedDashboardRingState();
}

class _AnimatedDashboardRingState extends State<_AnimatedDashboardRing> {
  late double _displayedValue = widget.reduceMotion ? widget.metric.value : 0;
  bool _entryActive = false;
  Timer? _entryDelay;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _entryActive = true;
    } else {
      _entryDelay = Timer(
        ForgeMotion.ringEntryDelay + ForgeMotion.ringStagger * (widget.index + 3),
        () {
          if (mounted) setState(() => _entryActive = true);
        },
      );
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedDashboardRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.reduceMotion && widget.reduceMotion) {
      _entryDelay?.cancel();
      _entryActive = true;
      _displayedValue = widget.metric.value;
    }
  }

  @override
  void dispose() {
    _entryDelay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRefreshing) {
      if (!_entryActive) {
        return _metricContent(context, 0);
      }

      return Column(
        children: [
          _ringGlow(
            context,
            GradientRing(
              value: null,
              size: 88,
              strokeWidth: 9,
              gradient: widget.metric.gradient,
              centerChild: ShimmerBox(
                width: 30,
                height: 18,
                borderRadius: widget.tokens.pillRadius,
              ),
            ),
          ),
          const SizedBox(height: ForgeSpacing.xs),
          Text(
            widget.metric.label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: widget.tokens.textSecondary),
          ),
        ],
      );
    }

    final splashAnimation = SplashAnimationScope.maybeOf(context);
    if (splashAnimation != null && !widget.reduceMotion) {
      return AnimatedBuilder(
        animation: splashAnimation,
        builder: (context, _) {
          final elapsed =
              splashAnimation.value *
              ForgeMotion.dashboardSplashTimeline.inMilliseconds;
          final progress = ForgeMotion.easeOut.transform(
            ((elapsed - ForgeMotion.dashboardRingIntroDelay.inMilliseconds) /
                    ForgeMotion.ring.inMilliseconds)
                .clamp(0.0, 1.0),
          );
          final displayedValue = widget.metric.value * progress;
          _displayedValue = displayedValue;
          return _metricContent(context, displayedValue);
        },
      );
    }

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: _displayedValue,
            end: widget.metric.value,
          ),
          duration: widget.reduceMotion ? Duration.zero : ForgeMotion.ringCount,
          curve: ForgeMotion.referenceEase,
          builder: (context, displayedValue, _) {
            _displayedValue = displayedValue;
            return _ring(context, displayedValue);
          },
        ),
        const SizedBox(height: ForgeSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.metric.label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: widget.tokens.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _metricContent(BuildContext context, double displayedValue) => Column(
    children: [
      _ring(context, displayedValue),
      const SizedBox(height: ForgeSpacing.xs),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.metric.label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: widget.tokens.textSecondary),
        ),
      ),
    ],
  );

  Widget _ring(BuildContext context, double displayedValue) {
    final progress = widget.metric.goal > 0
        ? (displayedValue / widget.metric.goal).clamp(0.0, 1.0)
        : 0.0;
    return _ringGlow(
      context,
      GradientRing(
        key: ValueKey(widget.metric.keyName),
        value: progress,
        size: 76,
        strokeWidth: 9,
        gradient: widget.metric.gradient,
        animate: false,
        centerChild: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatRingValue(displayedValue),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: widget.tokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
        ),
      ),
    );
  }

  String _formatRingValue(double value) {
    if (!value.isFinite) value = widget.metric.value;
    return NumberFormat.decimalPattern('en_US').format(value.round());
  }

  Widget _ringGlow(BuildContext context, Widget ring) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: widget.metric.gradient.colors.first.withValues(
                    alpha: 0.4,
                  ),
                  blurRadius: 7,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: ring,
    );
  }
}
