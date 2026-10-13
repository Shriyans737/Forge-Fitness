import 'package:flutter/material.dart';

import '../services/health_service.dart';

class HealthScreenSection extends StatefulWidget {
  const HealthScreenSection({super.key});

  @override
  State<HealthScreenSection> createState() => _HealthScreenSectionState();
}

class _HealthScreenSectionState extends State<HealthScreenSection> {
  final HealthService _healthService = HealthService();
  late Future<HealthSummary?> _summaryFuture;
  late Future<List<HealthWorkoutEntry>> _workoutsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _summaryFuture = _healthService.fetchTodaySummary();
      _workoutsFuture = _healthService.fetchRecentWorkouts(7);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_rounded),
                const SizedBox(width: 8),
                Text(
                  'Health',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<HealthSummary?>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final summary =
                    snapshot.data ??
                    const HealthSummary(
                      hasPermissions: false,
                      errorMessage: 'Health data unavailable.',
                    );

                final hasData =
                    summary.hasPermissions || summary.errorMessage == null;

                if (!hasData && snapshot.hasError == false) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (summary.errorMessage != null)
                        Text(
                          summary.errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          debugPrint(
                            'HealthScreenSection: Connect Health tapped',
                          );
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          try {
                            final granted = await _healthService
                                .requestPermissions();
                            debugPrint(
                              'HealthScreenSection: requestPermissions() result after tap: $granted',
                            );
                            if (granted && mounted) {
                              _loadData();
                              return;
                            }
                            if (mounted && messenger != null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Health Connect permission request timed out or was denied.',
                                  ),
                                ),
                              );
                            }
                          } catch (error, stackTrace) {
                            debugPrint(
                              'HealthScreenSection: Connect Health failed: $error',
                            );
                            debugPrint(stackTrace.toString());
                            if (mounted && messenger != null) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Unable to connect Health: $error'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.connect_without_contact_rounded),
                        label: const Text('Connect Health'),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Steps',
                            value: summary.steps == null
                                ? '—'
                                : summary.steps!.toString(),
                            icon: Icons.directions_walk_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Heart',
                            value: summary.latestHeartRate == null
                                ? '—'
                                : '${summary.latestHeartRate!.toStringAsFixed(0)} bpm',
                            icon: Icons.monitor_heart_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Calories',
                            value: summary.activeCaloriesBurned == null
                                ? '—'
                                : '${summary.activeCaloriesBurned!.toStringAsFixed(0)} kcal',
                            icon: Icons.local_fire_department_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Avg HR',
                            value: summary.averageHeartRate == null
                                ? '—'
                                : '${summary.averageHeartRate!.toStringAsFixed(0)} bpm',
                            icon: Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent workouts',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (!summary.hasPermissions)
                          TextButton.icon(
                            onPressed: () async {
                              debugPrint(
                                'HealthScreenSection: Connect Health tapped from recent workouts header',
                              );
                              final messenger = ScaffoldMessenger.maybeOf(context);
                              try {
                                final granted = await _healthService
                                    .requestPermissions();
                                debugPrint(
                                  'HealthScreenSection: requestPermissions() result from header: $granted',
                                );
                                if (granted && mounted) {
                                  _loadData();
                                  return;
                                }
                                if (mounted && messenger != null) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Health Connect permission request timed out or was denied.',
                                      ),
                                    ),
                                  );
                                }
                              } catch (error, stackTrace) {
                                debugPrint(
                                  'HealthScreenSection: Connect Health failed from header: $error',
                                );
                                debugPrint(stackTrace.toString());
                                if (mounted && messenger != null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Unable to connect Health: $error',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.health_and_safety_outlined),
                            label: const Text('Connect Health'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<HealthWorkoutEntry>>(
                      future: _workoutsFuture,
                      builder: (context, workoutSnapshot) {
                        if (workoutSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final workouts =
                            workoutSnapshot.data ??
                            const <HealthWorkoutEntry>[];
                        if (workouts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No recent workouts from your health app were found.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }

                        return Column(
                          children: workouts.map((workout) {
                            final formattedDate = MaterialLocalizations.of(
                              context,
                            ).formatShortDate(workout.startTime);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.run_circle_outlined),
                              title: Text(workout.type),
                              subtitle: Text(
                                '$formattedDate • ${_formatDuration(workout.startTime, workout.endTime)}',
                              ),
                              trailing: Text(
                                '${workout.calories.toStringAsFixed(0)} kcal',
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final minutes = duration.inMinutes;
    if (minutes <= 0) {
      return '0 min';
    }
    return '$minutes min';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withAlpha(64),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
