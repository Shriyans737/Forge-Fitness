import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/workout_template.dart';

class WorkoutTemplateRepository {
  WorkoutTemplateRepository({Box<WorkoutTemplate>? box})
      : _box = box ?? Hive.box<WorkoutTemplate>('workoutTemplates');

  final Box<WorkoutTemplate> _box;

  List<WorkoutTemplate> getAll() {
    final templates = _box.values.toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return templates;
  }

  WorkoutTemplate? getById(String id) => _box.get(id);

  Future<void> save(WorkoutTemplate template) =>
      _box.put(template.id, template);

  Future<WorkoutTemplate> duplicate(WorkoutTemplate source) async {
    final copy = WorkoutTemplate(
      id: const Uuid().v4(),
      name: '${source.name} copy',
      exerciseIds: List<String>.of(source.exerciseIds),
      plannedExercises: source.plannedExercises
          .map(
            (exercise) => PlannedExercise(
              exerciseId: exercise.exerciseId,
              sets: exercise.sets
                  .map(
                    (set) => PlannedSet(reps: set.reps, weight: set.weight),
                  )
                  .toList(growable: false),
              targetRepsMin: exercise.targetRepsMin,
              targetRepsMax: exercise.targetRepsMax,
              targetWeight: exercise.targetWeight,
              restSeconds: exercise.restSeconds,
              note: exercise.note,
              sameForAllSets: exercise.sameForAllSets,
            ),
          )
          .toList(growable: false),
      notes: source.notes,
    );
    await save(copy);
    return copy;
  }

  Future<void> delete(String id) => _box.delete(id);

  List<PlannedExercise> effectivePlan(WorkoutTemplate template) {
    final byExerciseId = {
      for (final exercise in template.plannedExercises)
        exercise.exerciseId: exercise,
    };
    return template.exerciseIds
        .map(
          (id) =>
              byExerciseId[id] ??
              PlannedExercise(
                exerciseId: id,
                sets: List<PlannedSet>.generate(
                  3,
                  (_) => PlannedSet(reps: 10),
                  growable: false,
                ),
              ),
        )
        .toList(growable: false);
  }

  int estimateDurationMinutes(WorkoutTemplate template) {
    final plan = effectivePlan(template);
    if (plan.isEmpty) {
      return 0;
    }

    final seconds = plan.fold<int>(0, (total, exercise) {
      final setCount = exercise.sets.isEmpty ? 3 : exercise.sets.length;
      final restSeconds = exercise.restSeconds.clamp(0, 3600);
      final setTime = setCount * 45;
      final restTime = (setCount - 1).clamp(0, setCount) * restSeconds;
      return total + setTime + restTime + 60;
    });
    return (seconds / 60).ceil();
  }
}
