// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'body_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BodyLogAdapter extends TypeAdapter<BodyLog> {
  @override
  final int typeId = 5;

  @override
  BodyLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BodyLog(
      id: fields[0] as String?,
      date: fields[1] as DateTime,
      weightKg: fields[2] as double?,
      measurements: (fields[3] as Map?)?.cast<String, double>(),
      notes: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BodyLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.weightKg)
      ..writeByte(3)
      ..write(obj.measurements)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
