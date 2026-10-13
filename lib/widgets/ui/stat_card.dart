import 'package:flutter/material.dart';

import '../../theme.dart';

enum StatTrend { up, down, steady }

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.number,
    this.unit,
    this.trend,
    this.delta,
    this.icon,
  });

  final String label;
  final String number;
  final String? unit;
  final StatTrend? trend;
  final String? delta;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final textTheme = Theme.of(context).textTheme;
    final trendColor = switch (trend) {
      StatTrend.up => tokens.success,
      StatTrend.down => tokens.warning,
      StatTrend.steady || null => tokens.textMuted,
    };
    final trendIcon = switch (trend) {
      StatTrend.up => Icons.trending_up,
      StatTrend.down => Icons.trending_down,
      StatTrend.steady || null => Icons.trending_flat,
    };

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: textTheme.labelLarge?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: ForgeSpacing.xs),
                Icon(icon, size: ForgeSpacing.lg, color: tokens.textSecondary),
              ],
            ],
          ),
          const SizedBox(height: ForgeSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    number,
                    style: textTheme.headlineLarge?.copyWith(
                      color: tokens.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (unit != null && unit!.isNotEmpty) ...[
                const SizedBox(width: ForgeSpacing.xs),
                Flexible(
                  child: Text(
                    unit!,
                    maxLines: 1,
                    softWrap: false,
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (trend != null || delta != null) ...[
            const SizedBox(height: ForgeSpacing.xs),
            Row(
              children: [
                if (trend != null) ...[
                  Icon(trendIcon, size: ForgeSpacing.md, color: trendColor),
                  const SizedBox(width: ForgeSpacing.xxs),
                ],
                if (delta != null)
                  Flexible(
                    child: Text(
                      delta!,
                      maxLines: 1,
                      softWrap: false,
                      style: textTheme.labelSmall?.copyWith(color: trendColor),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
