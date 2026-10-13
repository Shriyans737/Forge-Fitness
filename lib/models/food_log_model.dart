import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'food_log_model.g.dart';

abstract final class FoodLogSource {
  static const manual = 'manual';
  static const offSearch = 'off_search';
  static const barcode = 'barcode';
  static const photoAi = 'photo_ai';
}

@HiveType(typeId: 8)
class FoodLog extends HiveObject {
  FoodLog({
    String? id,
    required this.loggedAt,
    required this.foodName,
    this.caloriesPerServing,
    this.proteinGramsPerServing,
    this.carbsGramsPerServing,
    this.fatGramsPerServing,
    required this.servingSize,
    this.quantity = 1.0,
    this.source = FoodLogSource.manual,
  }) : id = id ?? const Uuid().v4();

  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime loggedAt;

  @HiveField(2)
  String foodName;

  @HiveField(3)
  double? caloriesPerServing;

  @HiveField(4)
  double? proteinGramsPerServing;

  @HiveField(5)
  double? carbsGramsPerServing;

  @HiveField(6)
  double? fatGramsPerServing;

  @HiveField(7)
  String servingSize;

  @HiveField(8, defaultValue: 1.0)
  double quantity;

  @HiveField(9, defaultValue: FoodLogSource.manual)
  String source;
}