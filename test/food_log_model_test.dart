import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forge/models/food_log_model.dart';
import 'package:hive/hive.dart';

void main() {
  test('FoodLog adapter preserves values and nullable nutrients', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp();
    Hive.init(temporaryDirectory.path);
    Hive.registerAdapter(FoodLogAdapter());

    final foodLog = FoodLog(
      id: 'food-1',
      loggedAt: DateTime(2026, 9, 26, 12, 30),
      foodName: 'Oatmeal',
      caloriesPerServing: 150,
      proteinGramsPerServing: null,
      carbsGramsPerServing: 27,
      fatGramsPerServing: 3,
      servingSize: '1 cup (40 g)',
      quantity: 1.5,
      source: FoodLogSource.offSearch,
    );
    final box = await Hive.openBox<FoodLog>('foodLogs');
    await box.put(foodLog.id, foodLog);
    final restored = box.get(foodLog.id)!;

    expect(restored.id, foodLog.id);
    expect(restored.loggedAt, foodLog.loggedAt);
    expect(restored.foodName, foodLog.foodName);
    expect(restored.caloriesPerServing, foodLog.caloriesPerServing);
    expect(restored.proteinGramsPerServing, isNull);
    expect(restored.carbsGramsPerServing, foodLog.carbsGramsPerServing);
    expect(restored.fatGramsPerServing, foodLog.fatGramsPerServing);
    expect(restored.servingSize, foodLog.servingSize);
    expect(restored.quantity, foodLog.quantity);
    expect(restored.source, FoodLogSource.offSearch);

    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });
}