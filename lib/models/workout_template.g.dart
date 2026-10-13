// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlannedSetAdapter extends TypeAdapter<PlannedSet> {
  @override
  final int typeId = 6;

  @override
  PlannedSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedSet(
      reps: fields[0] as int,
      weight: fields[1] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedSet obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.reps)
      ..writeByte(1)
      ..write(obj.weight);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlannedExerciseAdapter extends TypeAdapter<PlannedExercise> {
  @override
  final int typeId = 7;

  @override
  PlannedExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedExercise(
      exerciseId: fields[0] as String,
      sets: fields[1] == null ? [] : (fields[1] as List).cast<PlannedSet>(),
      targetRepsMin: fields[2] == null ? 10 : fields[2] as int,
      targetRepsMax: fields[3] == null ? 10 : fields[3] as int,
      targetWeight: fields[4] as double?,
      restSeconds: fields[5] == null ? 75 : fields[5] as int,
      note: fields[6] as String?,
      sameForAllSets: fields[7] == null ? true : fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedExercise obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.exerciseId)
      ..writeByte(1)
      ..write(obj.sets)
      ..writeByte(2)
      ..write(obj.targetRepsMin)
      ..writeByte(3)
      ..write(obj.targetRepsMax)
      ..writeByte(4)
      ..write(obj.targetWeight)
      ..writeByte(5)
      ..write(obj.restSeconds)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.sameForAllSets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutTemplateAdapter extends TypeAdapter<WorkoutTemplate> {
  @override
  final int typeId = 4;

  @override
  WorkoutTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      exerciseIds: (fields[2] as List).cast<String>(),
      plannedExercises:
          fields[3] == null ? [] : (fields[3] as List).cast<PlannedExercise>(),
      notes: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutTemplate obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.exerciseIds)
      ..writeByte(3)
      ..write(obj.plannedExercises)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
