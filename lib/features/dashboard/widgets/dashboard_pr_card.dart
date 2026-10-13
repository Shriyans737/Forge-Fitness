import 'package:flutter/material.dart';

import '../dashboard_controller.dart';
import '../../../theme.dart';
import 'dashboard_card.dart';

class DashboardPrCard extends StatelessWidget {
  const DashboardPrCard({
    required this.records,
    this.onTap,
    super.key,
  });

  final List<DashboardPr> records;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return DashboardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: tokens.accentLime),
              const SizedBox(width: ForgeSpacing.xs),
              Text('PERSONAL RECORDS', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: ForgeSpacing.sm),
          for (final record in records.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ForgeSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: ForgeSpacing.xs),
                  Text(
                    '${record.estimatedOneRepMax.toStringAsFixed(1)} kg',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
