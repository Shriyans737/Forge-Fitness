import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

import '../models/food_log_model.dart';

enum FoodNutritionBasis { serving, oneHundredGrams }

enum FoodSearchFailure { noInternet, databaseBusy, requestFailed }

class FoodSearchHttpResponse {
  const FoodSearchHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

typedef FoodSearchTransport = Future<FoodSearchHttpResponse> Function(
  Uri uri,
  Map<String, String> headers,
  Duration timeout,
);
typedef FoodSearchDelay = Future<void> Function(Duration duration);
typedef FoodAssetLoader = Future<String> Function();

class FoodSearchOutcome {
  const FoodSearchOutcome({required this.products, this.failure});

  final List<FoodProductResult> products;
  final FoodSearchFailure? failure;
}

class FoodNutritionValues {
  const FoodNutritionValues({
    required this.caloriesKcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  final double? caloriesKcal;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;

  int get populatedCount => [
    caloriesKcal,
    proteinGrams,
    carbsGrams,
    fatGrams,
  ].where((value) => value != null).length;

  factory FoodNutritionValues.fromNutriments(
    Nutriments? nutriments,
    PerSize perSize,
  ) {
    final source = nutriments ?? Nutriments.empty();
    final caloriesKcal =
        source.getValue(Nutrient.energyKCal, perSize) ??
        ((source.getValue(Nutrient.energyKJ, perSize) ?? 0) / 4.184);

    return FoodNutritionValues(
      caloriesKcal:
          source.getValue(Nutrient.energyKCal, perSize) != null ||
              source.getValue(Nutrient.energyKJ, perSize) != null
          ? caloriesKcal
          : null,
      proteinGrams: source.getValue(Nutrient.proteins, perSize),
      carbsGrams: source.getValue(Nutrient.carbohydrates, perSize),
      fatGrams: source.getValue(Nutrient.fat, perSize),
    );
  }
}

class FoodProductNutrition {
  const FoodProductNutrition({
    required this.values,
    required this.basis,
    required this.servingSize,
  });

  final FoodNutritionValues values;
  final FoodNutritionBasis basis;
  final String servingSize;

  String get basisLabel =>
      basis == FoodNutritionBasis.oneHundredGrams ? 'Per 100 g' : 'Per serving';

  bool get hasAnyValues => values.populatedCount > 0;

  factory FoodProductNutrition.fromProduct(Product product) {
    final perServing = FoodNutritionValues.fromNutriments(
      product.nutriments,
      PerSize.serving,
    );
    final perHundredGrams = FoodNutritionValues.fromNutriments(
      product.nutriments,
      PerSize.oneHundredGrams,
    );
    final usePerServing =
        perServing.populatedCount >= perHundredGrams.populatedCount;

    if (usePerServing) {
      final servingSize = product.servingSize?.trim();
      return FoodProductNutrition(
        values: perServing,
        basis: FoodNutritionBasis.serving,
        servingSize: servingSize == null || servingSize.isEmpty
            ? '1 serving'
            : servingSize,
      );
    }

    return FoodProductNutrition(
      values: perHundredGrams,
      basis: FoodNutritionBasis.oneHundredGrams,
      servingSize: '100 g',
    );
  }
}

class FoodProductResult {
  const FoodProductResult({
    required this.name,
    required this.brand,
    required this.barcode,
    required this.nutrition,
    this.isCommonFood = false,
    this.imageUrl,
  });

  final String name;
  final String? brand;
  final String? barcode;
  final FoodProductNutrition nutrition;
  final bool isCommonFood;
  final String? imageUrl;

  factory FoodProductResult.fromProduct(Product product) {
    final name = product.productName?.trim().isNotEmpty == true
        ? product.productName!.trim()
        : product.genericName?.trim() ?? '';

    return FoodProductResult(
      name: name,
      brand: product.brands?.trim(),
      barcode: product.barcode,
      nutrition: FoodProductNutrition.fromProduct(product),
    );
  }

  factory FoodProductResult.fromLocalFood(Map<String, dynamic> food) {
    final servingGrams = (food['serving_g'] as num).toDouble();
    final per100g = FoodNutritionValues(
      caloriesKcal: (food['calories'] as num).toDouble(),
      proteinGrams: (food['protein'] as num).toDouble(),
      carbsGrams: (food['carbs'] as num).toDouble(),
      fatGrams: (food['fat'] as num).toDouble(),
    );
    final servingScale = servingGrams / 100;

    return FoodProductResult(
      name: food['name'] as String,
      brand: null,
      barcode: null,
      isCommonFood: true,
      nutrition: FoodProductNutrition(
        values: FoodNutritionValues(
          caloriesKcal: per100g.caloriesKcal! * servingScale,
          proteinGrams: per100g.proteinGrams! * servingScale,
          carbsGrams: per100g.carbsGrams! * servingScale,
          fatGrams: per100g.fatGrams! * servingScale,
        ),
        basis: FoodNutritionBasis.serving,
        servingSize: '${food['serving']} ($servingGrams g)',
      ),
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'name': name,
    'brand': brand,
    'barcode': barcode,
    'isCommonFood': isCommonFood,
    'imageUrl': imageUrl,
    'basis': nutrition.basis.name,
    'servingSize': nutrition.servingSize,
    'calories': nutrition.values.caloriesKcal,
    'protein': nutrition.values.proteinGrams,
    'carbs': nutrition.values.carbsGrams,
    'fat': nutrition.values.fatGrams,
  };

  factory FoodProductResult.fromCacheJson(Map<String, dynamic> json) {
    return FoodProductResult(
      name: json['name'] as String,
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
      isCommonFood: json['isCommonFood'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      nutrition: FoodProductNutrition(
        values: FoodNutritionValues(
          caloriesKcal: (json['calories'] as num?)?.toDouble(),
          proteinGrams: (json['protein'] as num?)?.toDouble(),
          carbsGrams: (json['carbs'] as num?)?.toDouble(),
          fatGrams: (json['fat'] as num?)?.toDouble(),
        ),
        basis: FoodNutritionBasis.values.firstWhere(
          (basis) => basis.name == json['basis'],
          orElse: () => FoodNutritionBasis.oneHundredGrams,
        ),
        servingSize: json['servingSize'] as String? ?? '100 g',
      ),
    );
  }

  FoodLog toFoodLog({required double quantity, required String source}) {
    return FoodLog(
      loggedAt: DateTime.now(),
      foodName: name,
      caloriesPerServing: nutrition.values.caloriesKcal,
      proteinGramsPerServing: nutrition.values.proteinGrams,
      carbsGramsPerServing: nutrition.values.carbsGrams,
      fatGramsPerServing: nutrition.values.fatGrams,
      servingSize: nutrition.servingSize,
      quantity: quantity,
      source: source,
    );
  }
}

class OpenFoodFactsFoodService {
  OpenFoodFactsFoodService({
    this.transport,
    FoodSearchDelay? delay,
    FoodAssetLoader? assetLoader,
    DateTime Function()? clock,
  }) : _delay = delay ?? Future<void>.delayed,
       _assetLoader =
           assetLoader ??
           (() => rootBundle.loadString('assets/data/common_foods.json')),
       _clock = clock ?? DateTime.now;

  static const _userAgent =
      'Forge/1.0.0 (shriyans.singh0711@gmail.com)';
  static const _cacheKey = 'offSearchCacheV1';
  static const _cacheTtl = Duration(days: 7);
  static const _requestTimeout = Duration(seconds: 12);
  static const _searchGap = Duration(seconds: 1);
  static const _requestWindow = Duration(minutes: 1);
  static const _maxRequestsPerWindow = 10;
  static const _requestedFields =
      'code,product_name,brands,serving_size,nutriments,image_url';

  final FoodSearchTransport? transport;
  final FoodSearchDelay _delay;
  final FoodAssetLoader _assetLoader;
  final DateTime Function() _clock;
  final Map<String, List<FoodProductResult>> _sessionCache = {};
  final List<DateTime> _requestTimes = [];
  Future<List<Map<String, dynamic>>>? _foodsFuture;
  DateTime? _lastRequestAt;
  int _requestId = 0;
  HttpClient? _activeHttpClient;

  static String normalizeQuery(String query) {
    var normalized = query.toLowerCase().trim().replaceAll(
      RegExp(r'\bomelet\b'),
      'omelette',
    );
    normalized = normalized.replaceAll(RegExp(r'\b(with|and)\b'), ' ');
    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) {
          if (token.endsWith('ies') && token.length > 4) {
            return '${token.substring(0, token.length - 3)}y';
          }
          if (token.endsWith('s') && token.length > 3) {
            return token.substring(0, token.length - 1);
          }
          return token;
        })
        .join(' ')
        .trim();
  }

  Future<List<FoodProductResult>> getInitialResults(String query) async {
    final local = await _findLocalFoods(query);
    final cached = await _readCachedResults(normalizeQuery(query));
    return _mergeResults(local, cached);
  }

  void cancelInFlightSearch() {
    _requestId++;
    _activeHttpClient?.close(force: true);
    _activeHttpClient = null;
  }

  Future<FoodSearchOutcome> search(
    String query, {
    void Function(FoodSearchFailure failure)? onRetrying,
  }) async {
    final requestId = ++_requestId;
    _activeHttpClient?.close(force: true);
    _activeHttpClient = null;
    final normalized = normalizeQuery(query);
    final local = await _findLocalFoods(query);
    if (requestId != _requestId) {
      return FoodSearchOutcome(products: local);
    }
    final cached = await _readCachedResults(normalized);
    final visibleResults = _mergeResults(local, cached);
    if (normalized.isEmpty) {
      return FoodSearchOutcome(products: visibleResults);
    }

    final uri = Uri.https('search.openfoodfacts.org', '/search', {
      'q': normalized,
      'langs': 'en',
      'page_size': '20',
      'fields': _requestedFields,
    });
    final requestHeaders = const {
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    };
    var retries = 0;
    while (true) {
      await _waitForRequestSlot(requestId);
      if (requestId != _requestId) {
        return FoodSearchOutcome(products: visibleResults);
      }
      final stopwatch = Stopwatch()..start();
      try {
        final response = await _send(uri, requestHeaders, requestId);
        stopwatch.stop();
        _logRequest(
          uri,
          query,
          status: response.statusCode,
          elapsed: stopwatch.elapsed,
        );
        if (requestId != _requestId) {
          return FoodSearchOutcome(products: visibleResults);
        }
        if (response.statusCode != 200) {
          final status = response.statusCode;
          final retryAfter = _header(response.headers, 'retry-after');
          if (_shouldRetryStatus(status) && retries < 2) {
            onRetrying?.call(FoodSearchFailure.databaseBusy);
            await _delay(_retryDelay(retries++, retryAfter));
            if (requestId != _requestId) {
              return FoodSearchOutcome(products: visibleResults);
            }
            continue;
          }
          return FoodSearchOutcome(
            products: visibleResults,
            failure: _isBusyStatus(status)
                ? FoodSearchFailure.databaseBusy
                : FoodSearchFailure.requestFailed,
          );
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final hits = decoded['hits'] as List<dynamic>? ?? const [];
        final packaged = hits
            .whereType<Map<String, dynamic>>()
            .map(_productFromSearchHit)
            .where((product) => product.name.isNotEmpty)
            .toList(growable: false);
        if (requestId != _requestId) {
          return FoodSearchOutcome(products: visibleResults);
        }
        _sessionCache[normalized] = packaged;
        await _writeCachedResults(normalized, packaged);
        return FoodSearchOutcome(products: _mergeResults(local, packaged));
      } on TimeoutException catch (error) {
        stopwatch.stop();
        _logException(uri, query, stopwatch.elapsed, error);
        if (requestId != _requestId) {
          return FoodSearchOutcome(products: visibleResults);
        }
        if (retries < 2) {
          onRetrying?.call(FoodSearchFailure.requestFailed);
          await _delay(_retryDelay(retries++, null));
          if (requestId != _requestId) {
            return FoodSearchOutcome(products: visibleResults);
          }
          continue;
        }
        return FoodSearchOutcome(
          products: visibleResults,
          failure: FoodSearchFailure.requestFailed,
        );
      } on SocketException catch (error) {
        stopwatch.stop();
        _logException(uri, query, stopwatch.elapsed, error);
        return FoodSearchOutcome(
          products: visibleResults,
          failure: FoodSearchFailure.noInternet,
        );
      } on HandshakeException catch (error) {
        stopwatch.stop();
        _logException(uri, query, stopwatch.elapsed, error);
        return FoodSearchOutcome(
          products: visibleResults,
          failure: FoodSearchFailure.requestFailed,
        );
      } on FormatException catch (error) {
        stopwatch.stop();
        _logException(uri, query, stopwatch.elapsed, error);
        return FoodSearchOutcome(
          products: visibleResults,
          failure: FoodSearchFailure.requestFailed,
        );
      } on Exception catch (error) {
        stopwatch.stop();
        _logException(uri, query, stopwatch.elapsed, error);
        return FoodSearchOutcome(
          products: visibleResults,
          failure: FoodSearchFailure.requestFailed,
        );
      }
    }
  }

  Future<List<FoodProductResult>> searchByName(String query) async {
    return (await search(query)).products;
  }

  Future<FoodProductResult?> lookupBarcode(String barcode) async {
    final code = barcode.trim();
    final requestId = ++_requestId;
    _activeHttpClient?.close(force: true);
    _activeHttpClient = null;
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v3/product/$code.json',
      {
        'fields':
            'code,product_name,brands,serving_size,nutriments,image_front_url',
      },
    );
    final headers = const {
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    };
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _send(uri, headers, requestId);
      stopwatch.stop();
      _logRequest(
        uri,
        'barcode:$code',
        status: response.statusCode,
        elapsed: stopwatch.elapsed,
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final productJson = decoded['product'];
      if (productJson is! Map<String, dynamic>) return null;
      return FoodProductResult.fromProduct(Product.fromJson(productJson));
    } on HttpException {
      rethrow;
    } on Exception catch (error) {
      stopwatch.stop();
      _logException(uri, 'barcode:$code', stopwatch.elapsed, error);
      rethrow;
    }
  }

  Future<List<FoodProductResult>> _findLocalFoods(String query) async {
    final normalizedQuery = normalizeQuery(query);
    if (normalizedQuery.isEmpty) return const [];
    final tokens = normalizedQuery.split(' ');
    final foods = await (_foodsFuture ??= _loadFoods());
    final matches = foods.where((food) {
      final searchable = normalizeQuery(
        '${food['name']} ${(food['aliases'] as List<dynamic>).join(' ')}',
      );
      return searchable.contains(normalizedQuery) ||
          tokens.every(searchable.contains);
    });
    return matches
        .take(12)
        .map(FoodProductResult.fromLocalFood)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadFoods() async {
    final decoded = jsonDecode(await _assetLoader()) as Map<String, dynamic>;
    return (decoded['foods'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  FoodProductResult _productFromSearchHit(Map<String, dynamic> hit) {
    final nutriments = hit['nutriments'] as Map<String, dynamic>? ?? const {};
    final values = FoodNutritionValues(
      caloriesKcal: _number(nutriments['energy-kcal_100g']),
      proteinGrams: _number(nutriments['proteins_100g']),
      carbsGrams: _number(nutriments['carbohydrates_100g']),
      fatGrams: _number(nutriments['fat_100g']),
    );
    final brands = (hit['brands'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map((brand) => brand.trim())
        .where((brand) => brand.isNotEmpty)
        .join(', ');

    return FoodProductResult(
      name: hit['product_name'] as String? ?? '',
      brand: brands.isEmpty ? null : brands,
      barcode: hit['code'] as String?,
      imageUrl: hit['image_url'] as String?,
      nutrition: FoodProductNutrition(
        values: values,
        basis: FoodNutritionBasis.oneHundredGrams,
        servingSize: hit['serving_size'] as String? ?? '100 g',
      ),
    );
  }

  Future<FoodSearchHttpResponse> _send(
    Uri uri,
    Map<String, String> headers,
    int requestId,
  ) async {
    final injectedTransport = transport;
    if (injectedTransport != null) {
      return injectedTransport(
        uri,
        headers,
        _requestTimeout,
      ).timeout(_requestTimeout);
    }

    final client = HttpClient();
    _activeHttpClient = client;
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        headers.forEach((name, value) => request.headers.set(name, value));
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        if (requestId != _requestId) {
          return FoodSearchHttpResponse(
            statusCode: response.statusCode,
            headers: const {},
            body: '',
          );
        }
        final responseHeaders = <String, String>{};
        response.headers.forEach(
          (name, values) => responseHeaders[name] = values.join(','),
        );
        return FoodSearchHttpResponse(
          statusCode: response.statusCode,
          headers: responseHeaders,
          body: body,
        );
      })().timeout(_requestTimeout);
    } finally {
      client.close(force: true);
      if (identical(_activeHttpClient, client)) {
        _activeHttpClient = null;
      }
    }
  }

  Future<void> _waitForRequestSlot(int requestId) async {
    while (requestId == _requestId) {
      final now = _clock();
      _requestTimes.removeWhere(
        (requestedAt) => now.difference(requestedAt) >= _requestWindow,
      );
      var wait = Duration.zero;
      final lastRequestAt = _lastRequestAt;
      if (lastRequestAt != null) {
        final sinceLast = now.difference(lastRequestAt);
        if (sinceLast < _searchGap) wait = _searchGap - sinceLast;
      }
      if (_requestTimes.length >= _maxRequestsPerWindow) {
        final windowWait =
            _requestTimes.first.add(_requestWindow).difference(now);
        if (windowWait > wait) wait = windowWait;
      }
      if (wait <= Duration.zero) {
        _lastRequestAt = now;
        _requestTimes.add(now);
        return;
      }
      await _delay(wait);
    }
  }

  Future<List<FoodProductResult>> _readCachedResults(String query) async {
    final inMemory = _sessionCache[query];
    if (inMemory != null) return inMemory;
    final box = _settingsBox;
    if (box == null) return const [];
    final raw = box.get(_cacheKey);
    if (raw is! String) return const [];
    final cached = jsonDecode(raw) as List<dynamic>;
    final now = _clock();
    final retained = <Map<String, dynamic>>[];
    List<FoodProductResult>? found;
    for (final entry in cached.whereType<Map<String, dynamic>>()) {
      final timestamp = DateTime.tryParse(entry['savedAt'] as String? ?? '');
      if (timestamp == null || now.difference(timestamp) >= _cacheTtl) continue;
      retained.add(entry);
      if (entry['query'] == query) {
        found = (entry['products'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(FoodProductResult.fromCacheJson)
            .toList(growable: false);
      }
    }
    if (retained.length != cached.length) {
      await box.put(_cacheKey, jsonEncode(retained));
    }
    if (found != null) _sessionCache[query] = found;
    return found ?? const [];
  }

  Future<void> _writeCachedResults(
    String query,
    List<FoodProductResult> products,
  ) async {
    final box = _settingsBox;
    if (box == null) return;
    final raw = box.get(_cacheKey);
    final cached = raw is String
        ? (jsonDecode(raw) as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .toList()
        : <Map<String, dynamic>>[];
    final now = _clock();
    cached.removeWhere((entry) {
      final timestamp = DateTime.tryParse(entry['savedAt'] as String? ?? '');
      return timestamp == null || now.difference(timestamp) >= _cacheTtl;
    });
    cached.removeWhere((entry) => entry['query'] == query);
    cached.add({
      'query': query,
      'savedAt': _clock().toIso8601String(),
      'products': products.map((product) => product.toCacheJson()).toList(),
    });
    await box.put(
      _cacheKey,
      jsonEncode(
        cached.length > 30 ? cached.sublist(cached.length - 30) : cached,
      ),
    );
  }

  Box<dynamic>? get _settingsBox =>
      Hive.isBoxOpen('settings') ? Hive.box<dynamic>('settings') : null;

  List<FoodProductResult> _mergeResults(
    List<FoodProductResult> first,
    List<FoodProductResult> second,
  ) {
    final seen = <String>{};
    return [...first, ...second]
        .where((product) {
          final key = product.barcode?.isNotEmpty == true
              ? product.barcode!
              : '${normalizeQuery(product.name)}|${product.brand ?? ''}';
          return seen.add(key);
        })
        .toList(growable: false);
  }

  Duration _retryDelay(int retryIndex, String? retryAfter) {
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter.trim());
      if (seconds != null) {
        return Duration(seconds: seconds < 0 ? 0 : seconds);
      }
      try {
        final date = HttpDate.parse(retryAfter);
        final duration = date.difference(_clock());
        if (duration > Duration.zero) return duration;
      } on FormatException {
        // Use the normal backoff for malformed Retry-After values.
      }
    }
    return retryIndex == 0
        ? const Duration(milliseconds: 600)
        : const Duration(milliseconds: 1500);
  }

  bool _shouldRetryStatus(int status) =>
      status == 429 || (status >= 500 && status <= 599);

  bool _isBusyStatus(int status) =>
      status == 429 || (status >= 500 && status <= 599);

  String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }

  double? _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  void _logRequest(
    Uri uri,
    String query, {
    required int status,
    required Duration elapsed,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[FoodSearch] GET $uri query="$query" status=$status '
      'elapsed=${elapsed.inMilliseconds}ms',
    );
  }

  void _logException(Uri uri, String query, Duration elapsed, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[FoodSearch] GET $uri query="$query" exception='
      '${error.runtimeType}: $error elapsed=${elapsed.inMilliseconds}ms',
    );
  }
}
