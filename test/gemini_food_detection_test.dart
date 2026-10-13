import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/gemini_food_detection_service.dart';

void main() {
  test('parses strict food JSON with editable quantities', () {
    const response = '''
{"items":[{"name":"Rice","servingSize":"1 cup","quantity":1.5,"caloriesPerServing":205,"proteinGramsPerServing":4.3,"carbsGramsPerServing":44.5,"fatGramsPerServing":0.4}]}
''';

    final items = parseDetectedFoodJson(response);

    expect(items, hasLength(1));
    expect(items.single.name, 'Rice');
    expect(items.single.servingSize, '1 cup');
    expect(items.single.quantity, 1.5);
    expect(items.single.caloriesPerServing, 205);
  });

  test('rejects empty and malformed food output', () {
    expect(
      () => parseDetectedFoodJson('{"items":[]}'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseDetectedFoodJson('{"items":[{"name":"Rice"}]}'),
      throwsA(isA<FormatException>()),
    );
  });
}
