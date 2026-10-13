// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodLogAdapter extends TypeAdapter<FoodLog> {
  @override
  final int typeId = 8;

  @override
  FoodLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodLog(
      id: fields[0] as String?,
      loggedAt: fields[1] as DateTime,
      foodName: fields[2] as String,
      caloriesPerServing: fields[3] as double?,
      proteinGramsPerServing: fields[4] as double?,
      carbsGramsPerServing: fields[5] as double?,
      fatGramsPerServing: fields[6] as double?,
      servingSize: fields[7] as String,
      quantity: fields[8] == null ? 1.0 : fields[8] as double,
      source: fields[9] == null ? 'manual' : fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FoodLog obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.loggedAt)
      ..writeByte(2)
      ..write(obj.foodName)
      ..writeByte(3)
      ..write(obj.caloriesPerServing)
      ..writeByte(4)
      ..write(obj.proteinGramsPerServing)
      ..writeByte(5)
      ..write(obj.carbsGramsPerServing)
      ..writeByte(6)
      ..write(obj.fatGramsPerServing)
      ..writeByte(7)
      ..write(obj.servingSize)
      ..writeByte(8)
      ..write(obj.quantity)
      ..writeByte(9)
      ..write(obj.source);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
