import 'package:flutter/material.dart';

import '../../../models/workout_session.dart';
import '../../../theme.dart';
import 'dashboard_card.dart';

class DashboardRecentCard extends StatelessWidget {
  const DashboardRecentCard({
    required this.sessions,
    required this.onSessionTap,
    required this.onSeeAll,
    super.key,
  });

  final List<WorkoutSession> sessions;
  final ValueChanged<WorkoutSession> onSessionTap;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RECENT WORKOUTS',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
          if (sessions.isEmpty)
            Text(
              'Completed workouts will show up here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
            )
          else
            for (final session in sessions)
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () => onSessionTap(session),
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: ForgeSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: tokens.surfaceVariant,
                            borderRadius: BorderRadius.circular(
                              tokens.controlRadius,
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(ForgeSpacing.sm),
                            child: Icon(Icons.fitness_center_rounded),
                          ),
                        ),
                        const SizedBox(width: ForgeSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                _dateLabel(session.date),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: tokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: ForgeSpacing.xs),
                        Text(
                          '${session.totalVolume.round()} kg',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
