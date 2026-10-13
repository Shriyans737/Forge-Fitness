import 'package:flutter/material.dart';

import '../../../theme.dart';
import '../../../widgets/muscle_map.dart';
import 'dashboard_card.dart';

class DashboardMusclesCard extends StatelessWidget {
  const DashboardMusclesCard({
    required this.muscles,
    required this.volume,
    required this.reps,
    this.onTap,
    super.key,
  });

  final Set<String> muscles;
  final double volume;
  final int reps;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final sorted = muscles.toList()..sort();
    return DashboardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "TODAY'S MUSCLES",
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                '${_compact(volume)} kg',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: tokens.accentTeal,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: ForgeSpacing.xxs),
          Text(
            '$reps reps · ${muscles.length} muscles targeted',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
          ),
          if (sorted.isEmpty) ...[
            const SizedBox(height: ForgeSpacing.md),
            Text(
              'Your workout muscles will appear here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
            ),
          ] else ...[
            const SizedBox(height: ForgeSpacing.md),
            MuscleMapWidget(
              primaryMuscles: sorted,
              secondaryMuscles: const [],
              primaryColor: tokens.accentTeal,
              secondaryColor: tokens.accentLime,
              untargetedColor: tokens.surfaceVariant,
            ),
          ],
        ],
      ),
    );
  }

  static String _compact(double value) {
    if (value >= 100000) return '${(value / 1000).toStringAsFixed(0)}k';
    if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }
}
