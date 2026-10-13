// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 0;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise(
      id: fields[0] as String,
      name: fields[1] as String,
      muscleGroup: fields[2] as String,
      description: fields[3] as String,
      videoUrl: fields[4] as String?,
      isCustom: fields[5] == null ? false : fields[5] as bool,
      videoId: fields[6] as String?,
      imagePaths: fields[7] == null ? [] : (fields[7] as List).cast<String>(),
      primaryMuscles:
          fields[8] == null ? [] : (fields[8] as List).cast<String>(),
      secondaryMuscles:
          fields[9] == null ? [] : (fields[9] as List).cast<String>(),
      equipment: fields[10] as String?,
      level: fields[11] as String?,
      instructions:
          fields[12] == null ? [] : (fields[12] as List).cast<String>(),
      targetRepMin: fields[13] == null ? 8 : fields[13] as int,
      targetRepMax: fields[14] == null ? 12 : fields[14] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.muscleGroup)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.videoUrl)
      ..writeByte(5)
      ..write(obj.isCustom)
      ..writeByte(6)
      ..write(obj.videoId)
      ..writeByte(7)
      ..write(obj.imagePaths)
      ..writeByte(8)
      ..write(obj.primaryMuscles)
      ..writeByte(9)
      ..write(obj.secondaryMuscles)
      ..writeByte(10)
      ..write(obj.equipment)
      ..writeByte(11)
      ..write(obj.level)
      ..writeByte(12)
      ..write(obj.instructions)
      ..writeByte(13)
      ..write(obj.targetRepMin)
      ..writeByte(14)
      ..write(obj.targetRepMax);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
