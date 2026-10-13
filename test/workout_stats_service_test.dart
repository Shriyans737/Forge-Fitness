import 'package:flutter_test/flutter_test.dart';
import 'package:forge/models/exercise.dart';
import 'package:forge/models/workout_session.dart';
import 'package:forge/services/workout_stats_service.dart';

void main() {
  test('checking a set updates live volume and reps', () {
    final exercise = LoggedExercise(
      exerciseId: 'deadlift',
      exerciseName: 'Deadlift',
      sets: [
        ExerciseSet(weight: 80, reps: 5),
        ExerciseSet(weight: 85, reps: 4),
      ],
    );
    var checkedSets = <List<bool>>[
      [false, false],
    ];
    WorkoutStatsSnapshot stats() => WorkoutStatsService.calculate(
      exercises: [exercise],
      completedSets: checkedSets,
      exerciseForId: (_) => null,
    );

    expect(stats().volume, 0);
    expect(stats().reps, 0);
    checkedSets = [
      [true, false],
    ];
    expect(stats().volume, 400);
    expect(stats().reps, 5);
    checkedSets = [
      [true, true],
    ];
    expect(stats().volume, 740);
    expect(stats().reps, 9);
  });

  test('calculates stats only from checked sets and excludes warm-up load', () {
    final exercises = [
      LoggedExercise(
        exerciseId: 'press',
        exerciseName: 'Press',
        sets: [
          ExerciseSet(weight: 40, reps: 10),
          ExerciseSet(weight: 50, reps: 8, isWarmUp: true),
          ExerciseSet(weight: 60, reps: 5),
        ],
      ),
    ];
    final libraryExercise = Exercise(
      id: 'press',
      name: 'Press',
      muscleGroup: 'Chest',
      description: '',
      primaryMuscles: const ['Chest'],
      secondaryMuscles: const ['Triceps'],
    );

    final stats = WorkoutStatsService.calculate(
      exercises: exercises,
      completedSets: const [
        [true, true, false],
      ],
      exerciseForId: (id) => id == libraryExercise.id ? libraryExercise : null,
    );

    expect(stats.sets, 2);
    expect(stats.reps, 18);
    expect(stats.volume, 400);
    expect(stats.plannedMuscles, {'Chest', 'Triceps'});
    expect(stats.muscleLoad, {'Chest': 400, 'Triceps': 200});
  });

  test('includes planned muscles before any sets are completed', () {
    final exercise = Exercise(
      id: 'squat',
      name: 'Squat',
      muscleGroup: 'Legs',
      description: '',
      primaryMuscles: const ['Quadriceps'],
    );
    final stats = WorkoutStatsService.calculate(
      exercises: [
        LoggedExercise(
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          sets: [ExerciseSet(weight: 0, reps: 0)],
        ),
      ],
      completedSets: const [
        [false],
      ],
      exerciseForId: (_) => exercise,
    );

    expect(stats.sets, 0);
    expect(stats.reps, 0);
    expect(stats.volume, 0);
    expect(stats.plannedMuscles, {'Quadriceps'});
    expect(stats.muscleLoad, isEmpty);
  });
}
