import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../models/body_log_model.dart';
import '../../../theme.dart';
import '../../../widgets/ui/sparkline_chart.dart';
import 'dashboard_card.dart';

class DashboardBodyCard extends StatefulWidget {
  const DashboardBodyCard({
    required this.entries,
    required this.onTap,
    required this.reduceMotion,
    super.key,
  });

  final List<BodyLog> entries;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  State<DashboardBodyCard> createState() => _DashboardBodyCardState();
}

class _DashboardBodyCardState extends State<DashboardBodyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: ForgeMotion.sparklinePulse,
  );
  late final Animation<double> _dotScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 1.35).chain(
        CurveTween(curve: ForgeMotion.easeOut),
      ),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.35, end: 1).chain(
        CurveTween(curve: ForgeMotion.easeInOut),
      ),
      weight: 1,
    ),
  ]).animate(_pulse);

  List<BodyLog> get _withWeight =>
      widget.entries.where((item) => item.weightKg != null).toList();

  @override
  void initState() {
    super.initState();
    _playDotPulse();
  }

  @override
  void didUpdateWidget(covariant DashboardBodyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _playDotPulse();
    }
  }

  void _playDotPulse() {
    _pulse.stop();
    _pulse.value = 0;
    if (!widget.reduceMotion && _withWeight.length > 1) {
      _pulse.forward();
    } else {
      _pulse.value = 1;
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
    final withWeight = _withWeight;
    final latest = withWeight.isEmpty ? null : withWeight.first;
    final previous = withWeight.length < 2 ? null : withWeight[1];
    final weightValues = withWeight.reversed
        .map((entry) => entry.weightKg!)
        .toList(growable: false);
    final change = latest == null || previous == null
        ? null
        : latest.weightKg! - previous.weightKg!;

    return DashboardCard(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('BODY', style: Theme.of(context).textTheme.labelLarge),
              ),
              if (change != null)
                Text(
                  '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: change <= 0 ? tokens.success : tokens.warning,
                      ),
                ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.sm),
          if (latest == null)
            Text(
              'Log your first weigh-in to start tracking.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
            )
          else ...[
            Text(
              '${latest.weightKg!.toStringAsFixed(1)} kg',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              'Latest weigh-in',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
            ),
            const SizedBox(height: ForgeSpacing.sm),
            ClipRect(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: widget.reduceMotion ? 1 : 0, end: 1),
                duration: widget.reduceMotion
                    ? Duration.zero
                    : ForgeMotion.sparklineDraw,
                curve: ForgeMotion.easeOut,
                builder: (context, progress, _) => AnimatedBuilder(
                  animation: _dotScale,
                  builder: (context, _) => SparklineChart(
                    values: weightValues,
                    height: ForgeSpacing.xxl,
                    progress: progress,
                    showEndDot: true,
                    endDotScale: widget.reduceMotion ? 1 : _dotScale.value,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
