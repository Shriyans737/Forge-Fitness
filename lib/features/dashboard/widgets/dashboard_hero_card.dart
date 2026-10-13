import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../theme.dart';

class DashboardHeroCard extends StatefulWidget {
  const DashboardHeroCard({
    required this.hasActiveWorkout,
    required this.onTap,
    this.reduceMotion = false,
    super.key,
  });

  final bool hasActiveWorkout;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  State<DashboardHeroCard> createState() => _DashboardHeroCardState();
}

class _DashboardHeroCardState extends State<DashboardHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gradientController = AnimationController(
    vsync: this,
    duration: ForgeMotion.heroLoop,
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      _gradientController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant DashboardHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      if (widget.reduceMotion) {
        _gradientController.stop();
        _gradientController.value = 0;
      } else {
        _gradientController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, _) {
          final value = widget.reduceMotion ? 0.5 : _gradientController.value;
          final gradient = LinearGradient(
            begin: Alignment(-1 + value, -0.7),
            end: Alignment(1 - value, 0.7),
            colors: tokens.primaryGradient.colors,
          );
          return AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: widget.reduceMotion ? Duration.zero : ForgeMotion.short,
            curve: ForgeMotion.streakPop,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(tokens.heroRadius),
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                borderRadius: BorderRadius.circular(tokens.heroRadius),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(tokens.heroRadius),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accentTeal.withValues(
                          alpha: widget.hasActiveWorkout
                              ? 0.20 + value * 0.08
                              : 0.12,
                        ),
                        blurRadius: widget.hasActiveWorkout ? 28 : 18,
                        offset: const Offset(0, ForgeSpacing.xs),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(ForgeSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(ForgeSpacing.sm),
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              border: Border.all(color: tokens.border),
                              borderRadius: BorderRadius.circular(
                                tokens.controlRadius,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.hasActiveWorkout
                                      ? 'PICK UP WHERE YOU LEFT OFF'
                                      : 'READY WHEN YOU ARE',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: tokens.textSecondary,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: ForgeSpacing.xs),
                                Text(
                                  widget.hasActiveWorkout
                                      ? 'Resume workout'
                                      : 'Start a workout',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: tokens.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: ForgeSpacing.xxs),
                                Text(
                                  widget.hasActiveWorkout
                                      ? 'Your session is saved on this device'
                                      : 'Make today count',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: tokens.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: ForgeSpacing.sm),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            border: Border.all(color: tokens.border),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(ForgeSpacing.sm),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: ForgeSpacing.lg,
                              color: tokens.accentTeal,
                            ),
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
