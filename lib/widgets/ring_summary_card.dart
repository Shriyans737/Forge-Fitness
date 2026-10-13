import 'package:flutter/material.dart';

import '../theme.dart';
import 'gradient_ring_indicator.dart';

class RingData {
  const RingData({
    required this.label,
    required this.progress,
    required this.valueText,
    required this.gradientColors,
    this.secondaryText,
  });

  final String label;
  final double progress;
  final String valueText;
  final List<Color> gradientColors;
  final String? secondaryText;
}

class RingSummaryCard extends StatelessWidget {
  const RingSummaryCard({
    super.key,
    required this.rings,
    this.coachingMessage,
  }) : assert(rings.length == 3, 'RingSummaryCard requires exactly 3 ring items.');

  final List<RingData> rings;
  final String? coachingMessage;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;

    return Container(
      padding: EdgeInsets.all(palette.cardPadding),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(palette.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(rings.length, (index) {
              final ring = rings[index];

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: ring.progress),
                        builder: (context, animatedProgress, child) {
                          return GradientRingIndicator(
                            progress: animatedProgress,
                            gradientColors: ring.gradientColors,
                            size: 150,
                            strokeWidth: 11,
                            backgroundTrackColor: Colors.white.withValues(alpha: 0.12),
                            child: Text(
                              ring.valueText,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        ring.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (ring.secondaryText != null && ring.secondaryText!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ring.secondaryText!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
          if (coachingMessage != null && coachingMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'COACHING',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: palette.secondaryText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              coachingMessage!,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
