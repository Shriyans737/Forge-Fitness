import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:forge/models/food_log_model.dart';
import 'package:forge/services/open_food_facts_service.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('forge-food-search-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox<dynamic>('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('per-100-gram values stay labeled and stored as a 100 g serving', () {
    final nutriments = Nutriments.empty()
      ..setValue(Nutrient.energyKJ, PerSize.oneHundredGrams, 837)
      ..setValue(Nutrient.proteins, PerSize.oneHundredGrams, 10)
      ..setValue(Nutrient.carbohydrates, PerSize.oneHundredGrams, 20)
      ..setValue(Nutrient.fat, PerSize.oneHundredGrams, 5);

    final nutrition = FoodProductNutrition.fromProduct(
      Product()
        ..servingSize = '30 g'
        ..nutriments = nutriments,
    );
    final product = FoodProductResult(
      name: 'Test food',
      brand: null,
      barcode: '123',
      nutrition: nutrition,
    );
    final foodLog = product.toFoodLog(
      quantity: 0.5,
      source: FoodLogSource.offSearch,
    );

    expect(nutrition.basis, FoodNutritionBasis.oneHundredGrams);
    expect(nutrition.basisLabel, 'Per 100 g');
    expect(nutrition.servingSize, '100 g');
    expect(nutrition.values.caloriesKcal, closeTo(200, 0.1));
    expect(foodLog.servingSize, '100 g');
    expect(foodLog.caloriesPerServing, closeTo(200, 0.1));
    expect(foodLog.quantity, 0.5);
  });

  test('uses labeled serving values when coverage ties', () {
    final nutriments = Nutriments.empty()
      ..setValue(Nutrient.energyKCal, PerSize.serving, 120)
      ..setValue(Nutrient.proteins, PerSize.serving, 4)
      ..setValue(Nutrient.energyKCal, PerSize.oneHundredGrams, 300)
      ..setValue(Nutrient.proteins, PerSize.oneHundredGrams, 10);

    final nutrition = FoodProductNutrition.fromProduct(
      Product()
        ..servingSize = '40 g'
        ..nutriments = nutriments,
    );

    expect(nutrition.basis, FoodNutritionBasis.serving);
    expect(nutrition.servingSize, '40 g');
    expect(nutrition.values.caloriesKcal, 120);
  });

  test('normalizes plurals, filler words, and omelette spelling', () {
    expect(
      OpenFoodFactsFoodService.normalizeQuery('  Eggs with omelet and oats '),
      'egg omelette oat',
    );
    expect(
      OpenFoodFactsFoodService.normalizeQuery('egg omelette'),
      'egg omelette',
    );
  });

  test('bundled generic foods include at least 150 entries', () async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/data/common_foods.json'),
    ) as Map<String, dynamic>;
    expect((data['foods'] as List<dynamic>).length, greaterThanOrEqualTo(150));
  });

  test('egg omelette query finds the common omelette entry', () async {
    final service = OpenFoodFactsFoodService(
      transport: (_, _, _) async => _response(200),
    );

    final products = await service.getInitialResults('egg omelette');

    expect(
      products.any(
        (product) => product.isCommonFood && product.name == 'Omelette',
      ),
      isTrue,
    );
  });

  test(
    'retries 503 with exponential delays and returns packaged products',
    () async {
      var attempts = 0;
      var now = DateTime.utc(2025);
      final delays = <Duration>[];
      final service = OpenFoodFactsFoodService(
        transport: (_, _, _) async {
          attempts++;
          if (attempts < 3) return _response(503);
          return _response(200, hits: [_hit('Rolled oats', '0123')]);
        },
        delay: (duration) async {
          delays.add(duration);
          now = now.add(duration);
        },
        clock: () => now,
      );

      final result = await service.search('oats');

      expect(attempts, 3);
      expect(delays, const [
        Duration(milliseconds: 600),
        Duration(milliseconds: 400),
        Duration(milliseconds: 1500),
      ]);
      expect(result.failure, isNull);
      expect(
        result.products.any((product) => product.name == 'Rolled oats'),
        isTrue,
      );
    },
  );

  test('does not retry 404', () async {
    var attempts = 0;
    final service = OpenFoodFactsFoodService(
      transport: (_, _, _) async {
        attempts++;
        return _response(404);
      },
      delay: (_) async {},
    );

    final result = await service.search('unknown packaged product');

    expect(attempts, 1);
    expect(result.failure, FoodSearchFailure.requestFailed);
  });

  test('sends the application user agent and honors Retry-After', () async {
    var attempts = 0;
    var now = DateTime.utc(2025);
    final delays = <Duration>[];
    Map<String, String>? sentHeaders;
    Uri? sentUri;
    final service = OpenFoodFactsFoodService(
      transport: (uri, headers, _) async {
        sentHeaders = headers;
        sentUri = uri;
        attempts++;
        return attempts == 1
            ? _response(429, headers: const {'Retry-After': '2'})
            : _response(200);
      },
      delay: (duration) async {
        delays.add(duration);
        now = now.add(duration);
      },
      clock: () => now,
    );

    await service.search('Dosa');

    expect(
      sentHeaders?['User-Agent'],
      'Forge/1.0.0 (shriyans.singh0711@gmail.com)',
    );
    expect(sentUri?.queryParameters['q'], 'dosa');
    expect(sentUri?.queryParameters['page_size'], '20');
    expect(sentUri?.queryParameters['fields'], contains('nutriments'));
    expect(delays, const [Duration(seconds: 2)]);
    expect(attempts, 2);
  });

  test('barcode lookup sends the same application user agent', () async {
    Map<String, String>? sentHeaders;
    final service = OpenFoodFactsFoodService(
      transport: (uri, headers, _) async {
        sentHeaders = headers;
        expect(uri.host, 'world.openfoodfacts.org');
        expect(uri.path, '/api/v3/product/123.json');
        return FoodSearchHttpResponse(
          statusCode: 200,
          headers: const {},
          body: jsonEncode({
            'status': 1,
            'product': {
              'code': '123',
              'product_name': 'Test oats',
              'brands': 'Forge test',
              'serving_size': '40 g',
              'nutriments': {
                'energy-kcal_100g': 370,
                'proteins_100g': 10,
                'carbohydrates_100g': 60,
                'fat_100g': 7,
              },
            },
          }),
        );
      },
    );

    final product = await service.lookupBarcode('123');

    expect(
      sentHeaders?['User-Agent'],
      'Forge/1.0.0 (shriyans.singh0711@gmail.com)',
    );
    expect(product?.name, 'Test oats');
  });

  test('a newer search prevents stale results from replacing it', () async {
    final pending = <Completer<FoodSearchHttpResponse>>[];
    var now = DateTime.utc(2025);
    final service = OpenFoodFactsFoodService(
      transport: (_, _, _) {
        final completer = Completer<FoodSearchHttpResponse>();
        pending.add(completer);
        return completer.future;
      },
      delay: (duration) async => now = now.add(duration),
      clock: () => now,
    );

    final oldSearch = service.search('older query');
    await _waitFor(() => pending.length == 1);
    final newSearch = service.search('new query');
    await _waitFor(() => pending.length == 2);

    pending[1].complete(_response(200, hits: [_hit('Newest result', '2')]));
    final newResult = await newSearch;
    pending[0].complete(_response(200, hits: [_hit('Stale result', '1')]));
    final oldResult = await oldSearch;

    expect(
      newResult.products.map((product) => product.name),
      contains('Newest result'),
    );
    expect(
      oldResult.products.map((product) => product.name),
      isNot(contains('Stale result')),
    );
  });

  test('successful results persist in the seven-day query cache', () async {
    await Hive.box<dynamic>('settings').clear();
    final service = OpenFoodFactsFoodService(
      transport: (_, _, _) async =>
          _response(200, hits: [_hit('Packaged oats', '456')]),
      delay: (_) async {},
    );

    await service.search('  OATS ');
    final newService = OpenFoodFactsFoodService(
      transport: (_, _, _) async => fail('A cached query should not need this'),
    );
    final cached = await newService.getInitialResults('oats');

    expect(cached.any((product) => product.name == 'Packaged oats'), isTrue);
    final rawCache =
        Hive.box<dynamic>('settings').get('offSearchCacheV1') as String;
    final entries = jsonDecode(rawCache) as List<dynamic>;
    expect(entries.single['query'], 'oat');
    expect(
      DateTime.parse(entries.single['savedAt'] as String),
      isA<DateTime>(),
    );
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for async request');
}

FoodSearchHttpResponse _response(
  int status, {
  List<Map<String, dynamic>> hits = const [],
  Map<String, String> headers = const {},
}) {
  return FoodSearchHttpResponse(
    statusCode: status,
    headers: headers,
    body: jsonEncode({'hits': hits}),
  );
}

Map<String, dynamic> _hit(String name, String barcode) => {
  'code': barcode,
  'product_name': name,
  'brands': ['Forge test'],
  'serving_size': '40 g',
  'image_url': 'https://example.test/image.png',
  'nutriments': {
    'energy-kcal_100g': 380,
    'proteins_100g': 10,
    'carbohydrates_100g': 60,
    'fat_100g': 7,
  },
};
