import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/workout_template.dart';

class WorkoutShareData {
  const WorkoutShareData._({
    required this.title,
    required this.label,
    required this.date,
    required this.durationMinutes,
    required this.totalVolume,
    required this.exercises,
  });

  factory WorkoutShareData.completed(WorkoutSession session) {
    return WorkoutShareData._(
      title: session.name,
      label: 'Completed workout',
      date: session.date,
      durationMinutes: session.durationMinutes,
      totalVolume: session.totalVolume,
      exercises: session.exercises
          .map(
            (exercise) => WorkoutShareExercise(
              name: exercise.exerciseName,
              sets: exercise.sets
                  .map(
                    (set) =>
                        WorkoutShareSet(reps: set.reps, weight: set.weight),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  factory WorkoutShareData.template({
    required WorkoutTemplate template,
    required List<Exercise> exercises,
  }) {
    final plannedById = {
      for (final planned in template.plannedExercises)
        planned.exerciseId: planned,
    };

    return WorkoutShareData._(
      title: template.name,
      label: 'Template',
      date: null,
      durationMinutes: null,
      totalVolume: null,
      exercises: template.exerciseIds
          .map((exerciseId) {
            final exercise = exercises.firstWhere(
              (item) => item.id == exerciseId,
              orElse: () => Exercise(
                id: exerciseId,
                name: 'Unknown exercise',
                muscleGroup: '',
                description: '',
              ),
            );
            final planned = plannedById[exerciseId];
            return WorkoutShareExercise(
              name: exercise.name,
              sets: planned == null
                  ? const []
                  : planned.sets
                        .map((set) => WorkoutShareSet(reps: set.reps))
                        .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
  }

  final String title;
  final String label;
  final DateTime? date;
  final int? durationMinutes;
  final double? totalVolume;
  final List<WorkoutShareExercise> exercises;

  String get textSummary {
    final lines = <String>[title, label];
    if (date != null) {
      lines.add('Date: ${_formatDate(date!)}');
    }
    if (durationMinutes != null) {
      lines.add('Duration: $durationMinutes min');
    }
    if (totalVolume != null) {
      lines.add('Total volume: ${_formatNumber(totalVolume!)} kg');
    }
    lines.add('');
    lines.addAll(exercises.map((exercise) => exercise.text));
    lines.add('');
    lines.add('Forge');
    return lines.join('\n');
  }
}

class WorkoutShareExercise {
  const WorkoutShareExercise({required this.name, required this.sets});

  final String name;
  final List<WorkoutShareSet> sets;

  String get text {
    if (sets.isEmpty) {
      return '$name - planned sets not configured';
    }
    return '$name - ${sets.map((set) => set.label).join(', ')}';
  }
}

class WorkoutShareSet {
  const WorkoutShareSet({required this.reps, this.weight});

  final int reps;
  final double? weight;

  String get label {
    if (weight == null) {
      return '$reps reps';
    }
    return '${_formatNumber(weight!)}kg x $reps reps';
  }
}

class ShareableWorkoutCard extends StatelessWidget {
  const ShareableWorkoutCard({required this.data, super.key});

  final WorkoutShareData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (data.date != null)
              Text(
                _formatDate(data.date!),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (data.durationMinutes != null || data.totalVolume != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (data.durationMinutes != null)
                    _SummaryPill(
                      icon: Icons.timelapse,
                      text: '${data.durationMinutes} min',
                    ),
                  if (data.totalVolume != null)
                    _SummaryPill(
                      icon: Icons.fitness_center,
                      text: '${_formatNumber(data.totalVolume!)} kg',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            ...data.exercises.map(
              (exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExerciseSummary(exercise: exercise),
              ),
            ),
            const Divider(height: 12),
            Row(
              children: [
                Icon(Icons.local_fire_department, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Forge',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseSummary extends StatelessWidget {
  const _ExerciseSummary({required this.exercise});

  final WorkoutShareExercise exercise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.name,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          exercise.sets.isEmpty
              ? 'Planned sets not configured'
              : exercise.sets.map((set) => set.label).join('  •  '),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(text));
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

String _formatNumber(double value) {
  return value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
