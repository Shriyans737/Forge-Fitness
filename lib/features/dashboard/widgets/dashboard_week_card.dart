import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../theme.dart';
import 'dashboard_card.dart';

class DashboardWeekCard extends StatefulWidget {
  const DashboardWeekCard({
    required this.volumes,
    required this.workoutCount,
    required this.todayWeekday,
    required this.reduceMotion,
    this.onTap,
    super.key,
  });

  final List<double> volumes;
  final int workoutCount;
  final int todayWeekday;
  final bool reduceMotion;
  final VoidCallback? onTap;

  @override
  State<DashboardWeekCard> createState() => _DashboardWeekCardState();
}

class _DashboardWeekCardState extends State<DashboardWeekCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _todayGlow = AnimationController(
    vsync: this,
    duration: ForgeMotion.chartPulse,
  );
  Timer? _pulseDelay;

  @override
  void initState() {
    super.initState();
    _syncGlow();
  }

  @override
  void didUpdateWidget(covariant DashboardWeekCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion ||
        oldWidget.volumes != widget.volumes) {
      _syncGlow();
    }
  }

  void _syncGlow() {
    _todayGlow.stop();
    _todayGlow.value = 0;
    _pulseDelay?.cancel();
    final hasToday =
        widget.todayWeekday > 0 && widget.todayWeekday <= widget.volumes.length;
    if (!widget.reduceMotion && hasToday) {
      _pulseDelay = Timer(ForgeMotion.chartPulseDelay, () {
        if (mounted) _todayGlow.repeat();
      });
    }
  }

  @override
  void dispose() {
    _pulseDelay?.cancel();
    _todayGlow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final maxVolume = widget.volumes.isEmpty
        ? 0.0
        : widget.volumes.reduce((a, b) => a > b ? a : b);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return DashboardCard(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'THIS WEEK',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                '${widget.workoutCount} workout${widget.workoutCount == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.md),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final volume = index < widget.volumes.length
                    ? widget.volumes[index]
                    : 0.0;
                final fraction = maxVolume > 0 ? volume / maxVolume : 0.0;
                final isToday = index + 1 == widget.todayWeekday;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ForgeSpacing.xxs,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) => Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                width: double.infinity,
                                height: constraints.maxHeight,
                                child: _StaggeredWeekBar(
                                  value: fraction,
                                  maxHeight: constraints.maxHeight,
                                  index: index,
                                  reduceMotion: widget.reduceMotion,
                                  gradient: isToday
                                      ? LinearGradient(
                                          colors: [
                                            tokens.accentLime,
                                            tokens.accentTeal,
                                          ],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            tokens.accentTeal,
                                            tokens.accentTeal.withValues(
                                              alpha: 0.25,
                                            ),
                                          ],
                                        ),
                                  isToday: isToday,
                                  emptyColor: tokens.border,
                                  radius: tokens.pillRadius,
                                  glow: isToday ? _todayGlow : null,
                                  glowColor: tokens.accentTeal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: ForgeSpacing.xs),
                        Text(
                          days[index],
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isToday
                                    ? tokens.accentTeal
                                    : tokens.textMuted,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredWeekBar extends StatefulWidget {
  const _StaggeredWeekBar({
    required this.value,
    required this.maxHeight,
    required this.index,
    required this.reduceMotion,
    required this.gradient,
    required this.isToday,
    required this.emptyColor,
    required this.radius,
    required this.glowColor,
    this.glow,
  });

  final double value;
  final double maxHeight;
  final int index;
  final bool reduceMotion;
  final LinearGradient gradient;
  final bool isToday;
  final Color emptyColor;
  final double radius;
  final Animation<double>? glow;
  final Color glowColor;

  @override
  State<_StaggeredWeekBar> createState() => _StaggeredWeekBarState();
}

class _StaggeredWeekBarState extends State<_StaggeredWeekBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ForgeMotion.chartBar,
  );
  late Animation<double> _height = _makeHeight(begin: 0, end: widget.value);
  Timer? _delay;

  Animation<double> _makeHeight({required double begin, required double end}) =>
      Tween(begin: begin, end: end).animate(
        CurvedAnimation(parent: _controller, curve: ForgeMotion.easeOut),
      );

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _delay = Timer(ForgeMotion.tabCardStagger * widget.index, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _StaggeredWeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      final current = _height.value;
      _delay?.cancel();
      _controller.stop();
      _height = _makeHeight(begin: current, end: widget.value);
      if (widget.reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.value <= 0;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller,
        if (widget.glow != null) widget.glow!,
      ]),
      builder: (context, _) {
        final fraction = widget.reduceMotion ? widget.value : _height.value;
        final glow = widget.glow?.value ?? 0;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            height: isEmpty ? 4 : widget.maxHeight * fraction,
            decoration: BoxDecoration(
              color: isEmpty ? widget.emptyColor : null,
              gradient: isEmpty ? null : widget.gradient,
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: widget.glow == null
                  ? null
                  : [
                      BoxShadow(
                        color: widget.glowColor.withValues(
                          alpha: 0.12 + glow * 0.20,
                        ),
                        blurRadius: ForgeSpacing.xs + glow * ForgeSpacing.xs,
                      ),
                    ],
            ),
          ),
        );
      },
    );
  }
}
