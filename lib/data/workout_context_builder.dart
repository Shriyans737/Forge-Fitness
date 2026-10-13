import 'package:hive/hive.dart';

import '../models/exercise.dart';
import '../models/workout_session.dart';

String buildWorkoutContextSummary() {
  final sessionsBox = Hive.box<WorkoutSession>('workoutSessions');
  final exercisesBox = Hive.box<Exercise>('exercises');
  final recentSessions = sessionsBox.values.toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final lastTen = recentSessions.take(10).toList();
  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 7));

  final summaryBuffer = StringBuffer();
  summaryBuffer.writeln('Workout history summary:');

  if (lastTen.isEmpty) {
    summaryBuffer.writeln('No prior workout history.');
  } else {
    summaryBuffer.writeln('Recent workouts (last 10):');

    for (final session in lastTen) {
      final exerciseSummary = <String>[];
      for (final item in session.exercises) {
        final setCount = item.sets.length;
        if (setCount > 0) {
          exerciseSummary.add('${item.exerciseName} ($setCount sets)');
        }
      }

      if (exerciseSummary.isEmpty) {
        exerciseSummary.add('No logged sets');
      }

      final date = session.date.toLocal().toString().split(' ')[0];
      summaryBuffer.writeln('- $date: ${exerciseSummary.join(', ')}');
    }
  }

  final trainedInLast7Days = <String>{};
  for (final session in recentSessions) {
    if (session.date.isBefore(sevenDaysAgo)) {
      continue;
    }

    for (final item in session.exercises) {
      final exercise = exercisesBox.get(item.exerciseId);
      final names = exercise?.primaryMuscles ?? <String>[];
      trainedInLast7Days.addAll(names.map((name) => name.trim().toLowerCase()));
    }
  }

  final allMuscleGroups = <String>{
    'chest',
    'shoulders',
    'back',
    'biceps',
    'triceps',
    'abs',
    'quads',
    'hamstrings',
    'glutes',
    'calves',
    'forearms',
    'traps',
    'lats',
    'middle back',
    'lower back',
  };

  final notTrained = allMuscleGroups.where((group) => !trainedInLast7Days.contains(group)).toList()..sort();

  summaryBuffer.writeln('\nMuscle groups not trained in the last 7 days:');
  if (notTrained.isEmpty) {
    summaryBuffer.writeln('None.');
  } else {
    summaryBuffer.writeln(notTrained.join(', '));
  }

  final text = summaryBuffer.toString();
  return text.length > 500 ? text.substring(0, 500) : text;
}
