import 'package:flutter/material.dart';

import '../../theme.dart';

class VerticalPillGauge extends StatelessWidget {
  const VerticalPillGauge({
    super.key,
    required this.value,
    required this.label,
    this.height = ForgeSpacing.xxxl * 2,
    this.width = ForgeSpacing.md,
    this.labelWidth,
    this.gradient,
  });

  final double value;
  final String label;
  final double height;
  final double width;
  final double? labelWidth;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final progress = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

    return Semantics(
      label: label,
      value: '${(progress * 100).round()}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            width: width,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.pillRadius),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: tokens.surfaceVariant),
                    ),
                    FractionallySizedBox(
                      heightFactor: progress,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: gradient ?? tokens.primaryGradient,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: ForgeSpacing.xs),
          SizedBox(
            width: labelWidth ?? ForgeSpacing.xxxl,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              softWrap: true,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
