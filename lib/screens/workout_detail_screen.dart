import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../services/workout_share_service.dart';
import '../widgets/shareable_workout_card.dart';
import 'exercise_detail_screen.dart';

class WorkoutDetailScreen extends StatelessWidget {
  WorkoutDetailScreen({required this.session, super.key});

  final WorkoutSession session;
  final GlobalKey _cardKey = GlobalKey();

  Future<void> _share(BuildContext context) {
    return WorkoutShareService.share(
      context: context,
      cardKey: _cardKey,
      data: WorkoutShareData.completed(session),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  Future<void> _deleteWorkout(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text(
          'This workout will be permanently removed from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    await Hive.box<WorkoutSession>('workoutSessions').delete(session.id);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        actions: [
          IconButton(
            tooltip: 'Share workout',
            onPressed: () => _share(context),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Delete workout',
            onPressed: () => _deleteWorkout(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.calendar_today, size: 18),
                            label: Text(_formatDate(session.date)),
                          ),
                          Chip(
                            avatar: const Icon(Icons.timelapse, size: 18),
                            label: Text('${session.durationMinutes} min'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.fitness_center, size: 18),
                            label: Text(
                              '${session.totalVolume.toStringAsFixed(0)} kg',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _cardKey,
                child: ShareableWorkoutCard(
                  data: WorkoutShareData.completed(session),
                ),
              ),
              const SizedBox(height: 20),
              if (session.exercises.isEmpty)
                const Center(
                  child: Text('This workout has no logged exercises.'),
                )
              else ...[
                ...session.exercises.map((exercise) {
                  final libraryExercise = Hive.box<Exercise>('exercises')
                      .get(exercise.exerciseId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: libraryExercise == null
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ExerciseDetailScreen(
                                            exercise: libraryExercise,
                                            showAddToWorkout: false,
                                          ),
                                        ),
                                      );
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exercise.exerciseName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (libraryExercise != null)
                                      const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (exercise.sets.isEmpty)
                              const Text('No sets logged.')
                            else ...[
                              ...exercise.sets.asMap().entries.map((entry) {
                                final setIndex = entry.key;
                                final set = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'Set ${setIndex + 1}: ${set.weight.toStringAsFixed(set.weight.truncateToDouble() == set.weight ? 0 : 1)}kg x ${set.reps} reps',
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
