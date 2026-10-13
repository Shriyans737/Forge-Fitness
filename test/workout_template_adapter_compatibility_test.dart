import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forge/models/workout_template.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'new template adapters read records written before added fields',
    () async {
      final directory = await Directory.systemTemp.createTemp();
      Hive.init(directory.path);
      Hive.registerAdapter(PlannedSetAdapter());
      Hive.registerAdapter(PlannedExerciseAdapter());
      Hive.registerAdapter(WorkoutTemplateAdapter());
      Hive.registerAdapter(_LegacyPlannedExerciseAdapter(), override: true);
      Hive.registerAdapter(_LegacyWorkoutTemplateAdapter(), override: true);

      final legacyBox = await Hive.openBox<WorkoutTemplate>('templates');
      await legacyBox.put(
        'with-plan',
        WorkoutTemplate(
          id: 'with-plan',
          name: 'Legacy plan',
          exerciseIds: const ['press'],
          plannedExercises: [
            PlannedExercise(exerciseId: 'press', sets: [PlannedSet(reps: 8)]),
          ],
        ),
      );
      await legacyBox.put(
        'without-plan',
        WorkoutTemplate(
          id: 'without-plan',
          name: 'Legacy ids only',
          exerciseIds: const ['squat'],
        ),
      );
      await Hive.close();

      Hive.registerAdapter(PlannedExerciseAdapter(), override: true);
      Hive.registerAdapter(WorkoutTemplateAdapter(), override: true);
      final currentBox = await Hive.openBox<WorkoutTemplate>('templates');
      final oldPlan = currentBox.get('with-plan')!;
      final oldTemplate = currentBox.get('without-plan')!;

      expect(oldPlan.plannedExercises.single.targetRepsMin, 10);
      expect(oldPlan.plannedExercises.single.targetRepsMax, 10);
      expect(oldPlan.plannedExercises.single.restSeconds, 75);
      expect(oldPlan.plannedExercises.single.sameForAllSets, isTrue);
      expect(oldTemplate.plannedExercises, isEmpty);

      await Hive.close();
      await directory.delete(recursive: true);
    },
  );
}

class _LegacyPlannedExerciseAdapter extends TypeAdapter<PlannedExercise> {
  @override
  int get typeId => 7;

  @override
  PlannedExercise read(BinaryReader reader) {
    final fields = <int, dynamic>{
      for (var index = 0, count = reader.readByte(); index < count; index++)
        reader.readByte(): reader.read(),
    };
    return PlannedExercise(
      exerciseId: fields[0] as String,
      sets: (fields[1] as List).cast<PlannedSet>(),
    );
  }

  @override
  void write(BinaryWriter writer, PlannedExercise obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.sets);
  }
}

class _LegacyWorkoutTemplateAdapter extends TypeAdapter<WorkoutTemplate> {
  @override
  int get typeId => 4;

  @override
  WorkoutTemplate read(BinaryReader reader) {
    final fields = <int, dynamic>{
      for (var index = 0, count = reader.readByte(); index < count; index++)
        reader.readByte(): reader.read(),
    };
    return WorkoutTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      exerciseIds: (fields[2] as List).cast<String>(),
      plannedExercises:
          (fields[3] as List?)?.cast<PlannedExercise>() ?? const [],
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutTemplate obj) {
    final hasPlan = obj.plannedExercises.isNotEmpty;
    writer
      ..writeByte(hasPlan ? 4 : 3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.exerciseIds);
    if (hasPlan) {
      writer
        ..writeByte(3)
        ..write(obj.plannedExercises);
    }
  }
}
