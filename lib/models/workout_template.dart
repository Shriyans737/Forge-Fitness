import 'package:hive/hive.dart';

part 'workout_template.g.dart';

@HiveType(typeId: 6)
class PlannedSet extends HiveObject {
  PlannedSet({required this.reps, this.weight});

  @HiveField(0)
  int reps;

  @HiveField(1)
  double? weight;
}

@HiveType(typeId: 7)
class PlannedExercise extends HiveObject {
  PlannedExercise({
    required this.exerciseId,
    this.sets = const [],
    this.targetRepsMin = 10,
    this.targetRepsMax = 10,
    this.targetWeight,
    this.restSeconds = 75,
    this.note,
    this.sameForAllSets = true,
  });

  @HiveField(0)
  String exerciseId;

  @HiveField(1, defaultValue: [])
  List<PlannedSet> sets;

  @HiveField(2, defaultValue: 10)
  int targetRepsMin;

  @HiveField(3, defaultValue: 10)
  int targetRepsMax;

  @HiveField(4)
  double? targetWeight;

  @HiveField(5, defaultValue: 75)
  int restSeconds;

  @HiveField(6)
  String? note;

  @HiveField(7, defaultValue: true)
  bool sameForAllSets;
}

@HiveType(typeId: 4)
class WorkoutTemplate extends HiveObject {
  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exerciseIds,
    this.plannedExercises = const [],
    this.notes,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> exerciseIds;

  @HiveField(3, defaultValue: [])
  List<PlannedExercise> plannedExercises;

  @HiveField(4)
  String? notes;
}
