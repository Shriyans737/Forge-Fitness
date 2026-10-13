import '../models/exercise.dart';
import '../models/workout_session.dart';

class WorkoutStatsSnapshot {
  WorkoutStatsSnapshot({
    required this.volume,
    required this.reps,
    required this.sets,
    required Set<String> plannedMuscles,
    required Map<String, double> muscleLoad,
  }) : plannedMuscles = Set.unmodifiable(plannedMuscles),
       muscleLoad = Map.unmodifiable(muscleLoad);

  final double volume;
  final int reps;
  final int sets;
  final Set<String> plannedMuscles;
  final Map<String, double> muscleLoad;

  static final empty = WorkoutStatsSnapshot(
    volume: 0,
    reps: 0,
    sets: 0,
    plannedMuscles: const {},
    muscleLoad: const {},
  );
}

class WorkoutStatsService {
  const WorkoutStatsService._();

  static WorkoutStatsSnapshot calculate({
    required List<LoggedExercise> exercises,
    required List<List<bool>> completedSets,
    required Exercise? Function(String exerciseId) exerciseForId,
  }) {
    var volume = 0.0;
    var reps = 0;
    var sets = 0;
    final plannedMuscles = <String>{};
    final muscleLoad = <String, double>{};

    for (var exerciseIndex = 0;
        exerciseIndex < exercises.length;
        exerciseIndex++) {
      final loggedExercise = exercises[exerciseIndex];
      final libraryExercise = exerciseForId(loggedExercise.exerciseId);
      if (libraryExercise != null) {
        final primary = _normalizedMuscles(libraryExercise.primaryMuscles);
        final secondary = _normalizedMuscles(libraryExercise.secondaryMuscles)
          ..removeAll(primary);
        plannedMuscles
          ..addAll(primary)
          ..addAll(secondary);

        for (var setIndex = 0;
            setIndex < loggedExercise.sets.length;
            setIndex++) {
          if (!_isCompleted(completedSets, exerciseIndex, setIndex)) {
            continue;
          }
          final set = loggedExercise.sets[setIndex];
          if (set.isWarmUp) {
            continue;
          }
          final load = set.weight * set.reps;
          for (final muscle in primary) {
            muscleLoad.update(
              muscle,
              (current) => current + load,
              ifAbsent: () => load,
            );
          }
          for (final muscle in secondary) {
            muscleLoad.update(
              muscle,
              (current) => current + load * 0.5,
              ifAbsent: () => load * 0.5,
            );
          }
        }
      }

      for (var setIndex = 0;
          setIndex < loggedExercise.sets.length;
          setIndex++) {
        if (!_isCompleted(completedSets, exerciseIndex, setIndex)) {
          continue;
        }
        final set = loggedExercise.sets[setIndex];
        sets++;
        reps += set.reps;
        if (!set.isWarmUp) {
          volume += set.weight * set.reps;
        }
      }
    }

    return WorkoutStatsSnapshot(
      volume: volume,
      reps: reps,
      sets: sets,
      plannedMuscles: plannedMuscles,
      muscleLoad: muscleLoad,
    );
  }

  static bool _isCompleted(
    List<List<bool>> completedSets,
    int exerciseIndex,
    int setIndex,
  ) =>
      exerciseIndex < completedSets.length &&
      setIndex < completedSets[exerciseIndex].length &&
      completedSets[exerciseIndex][setIndex];

  static Set<String> _normalizedMuscles(List<String> values) => values
      .map((muscle) => muscle.trim())
      .where((muscle) => muscle.isNotEmpty)
      .toSet();
}
