import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/workout_session.dart';
import 'progress_service.dart';

class ProgressRepository {
  ProgressRepository._();

  static Box<WorkoutSession>? _workoutBox;
  static ValueListenable<Box<WorkoutSession>>? _workoutListenable;
  static Future<Map<String, ExerciseProgressHistory>>? _cachedHistories;
  static int _generation = 0;

  static Future<Map<String, ExerciseProgressHistory>> loadAll() {
    final box = Hive.box<WorkoutSession>('workoutSessions');
    _bind(box);
    final cached = _cachedHistories;
    if (cached != null) {
      return cached;
    }

    final generation = _generation;
    final snapshot = box.values.map(_snapshotWorkout).toList(growable: false);
    final calculation = compute(_calculateHistories, snapshot);
    late final Future<Map<String, ExerciseProgressHistory>> result;
    result = calculation.then((histories) {
      if (generation != _generation) {
        return loadAll();
      }
      return histories;
    });
    _cachedHistories = result;
    return result;
  }

  static Future<ExerciseProgressHistory> historyFor({
    required String exerciseId,
    required String exerciseName,
  }) async {
    final histories = await loadAll();
    return histories[exerciseId] ??
        ExerciseProgressHistory(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          sessions: const [],
          personalRecords: const [],
          isBodyweight: false,
        );
  }

  static void _bind(Box<WorkoutSession> box) {
    if (identical(_workoutBox, box)) {
      return;
    }
    _workoutListenable?.removeListener(_invalidate);
    _workoutBox = box;
    _workoutListenable = box.listenable()..addListener(_invalidate);
  }

  static void _invalidate() {
    _generation++;
    _cachedHistories = null;
  }
}

Map<String, Object?> _snapshotWorkout(WorkoutSession workout) => {
  'date': workout.date,
  'exercises': workout.exercises
      .map(
        (exercise) => {
          'id': exercise.exerciseId,
          'name': exercise.exerciseName,
          'sets': exercise.sets
              .map(
                (set) => {
                  'weight': set.weight,
                  'reps': set.reps,
                  'isWarmUp': set.isWarmUp,
                },
              )
              .toList(growable: false),
        },
      )
      .toList(growable: false),
};

Map<String, ExerciseProgressHistory> _calculateHistories(
  List<Map<String, Object?>> snapshots,
) {
  final workouts = snapshots
      .map((snapshot) {
        final exerciseRecords = (snapshot['exercises']! as List)
            .map((exercise) {
              final exerciseMap = exercise as Map;
              final sets = (exerciseMap['sets']! as List)
                  .map((set) {
                    final setMap = set as Map;
                    return ProgressSetRecord(
                      weight: setMap['weight'] as double?,
                      reps: setMap['reps']! as int,
                      isWarmUp: setMap['isWarmUp'] as bool? ?? false,
                    );
                  })
                  .toList(growable: false);
              return ProgressExerciseRecord(
                exerciseId: exerciseMap['id']! as String,
                exerciseName: exerciseMap['name']! as String,
                sets: sets,
              );
            })
            .toList(growable: false);
        return ProgressWorkoutRecord(
          date: snapshot['date']! as DateTime,
          exercises: exerciseRecords,
        );
      })
      .toList(growable: false);

  final exerciseIds = workouts
      .expand((workout) => workout.exercises)
      .map((exercise) => exercise.exerciseId)
      .toSet();
  return {
    for (final exerciseId in exerciseIds)
      exerciseId: ProgressService.calculateHistory(
        exerciseId: exerciseId,
        workouts: workouts,
      ),
  };
}
