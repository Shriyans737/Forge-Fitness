import 'package:hive/hive.dart';

part 'workout_session.g.dart';

@HiveType(typeId: 1)
class ExerciseSet extends HiveObject {
  ExerciseSet({
    required this.weight,
    required this.reps,
    this.isWarmUp = false,
  });

  @HiveField(0)
  double weight;

  @HiveField(1)
  int reps;

  @HiveField(2, defaultValue: false)
  bool isWarmUp;
}

@HiveType(typeId: 2)
class LoggedExercise extends HiveObject {
  LoggedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  @HiveField(0)
  String exerciseId;

  @HiveField(1)
  String exerciseName;

  @HiveField(2)
  List<ExerciseSet> sets;
}

@HiveType(typeId: 3)
class WorkoutSession extends HiveObject {
  WorkoutSession({
    required this.id,
    required this.date,
    required this.name,
    required this.exercises,
    this.durationMinutes = 0,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String name;

  @HiveField(3)
  List<LoggedExercise> exercises;

  @HiveField(4, defaultValue: 0)
  int durationMinutes;

  double get totalVolume => exercises.fold(
        0,
        (total, exercise) => total +
            exercise.sets.fold(
              0,
              (exerciseTotal, set) => exerciseTotal + set.weight * set.reps,
            ),
      );
}