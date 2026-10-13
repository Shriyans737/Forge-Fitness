import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/food_log_model.dart';
import '../services/open_food_facts_service.dart';
import '../theme.dart';
import 'barcode_scanner_screen.dart';
import 'manual_food_entry_screen.dart';
import 'photo_food_review_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _searchController = TextEditingController();
  final _foodService = OpenFoodFactsFoodService();
  List<FoodProductResult> _products = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  int _searchRequestId = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _foodService.cancelInFlightSearch();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _products = [];
        _hasSearched = false;
        _errorMessage = 'Enter a food or product name to search.';
      });
      return;
    }

    final requestId = ++_searchRequestId;
    _foodService.cancelInFlightSearch();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final initialResults = await _foodService.getInitialResults(query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _products = initialResults);
      final outcome = await _foodService.search(
        query,
        onRetrying: (failure) {
          if (!mounted || requestId != _searchRequestId) return;
          setState(() {
            _errorMessage = failure == FoodSearchFailure.databaseBusy
                ? 'The food database is busy, retrying...'
                : 'Search timed out, retrying...';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        if (requestId != _searchRequestId) return;
        _products = outcome.products;
        _isLoading = false;
        _errorMessage = switch (outcome.failure) {
          FoodSearchFailure.noInternet => 'No internet connection.',
          FoodSearchFailure.databaseBusy =>
            'The food database is busy. Try again shortly.',
          FoodSearchFailure.requestFailed =>
            'Food search failed. Try again or enter it manually.',
          null when outcome.products.isEmpty =>
            'No results for "$query". Try a simpler name or enter it manually.',
          null => null,
        };
      });
    } on Exception catch (error, stackTrace) {
      if (requestId != _searchRequestId) return;
      debugPrint(
        '[FoodSearch] Search screen exception=${error.runtimeType}: $error\n'
        '$stackTrace',
      );
      _setSearchError('Food search failed. Try again or enter it manually.');
    }
  }

  void _setSearchError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;

    ++_searchRequestId;
    _foodService.cancelInFlightSearch();
    setState(() {
      _isLoading = true;
      _hasSearched = false;
      _errorMessage = null;
      _products = [];
    });

    try {
      final product = await _foodService.lookupBarcode(barcode);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (product == null) {
        _showManualFallback(
          'No Open Food Facts product found for this barcode.',
        );
        return;
      }
      await _confirmAndLog(product, source: FoodLogSource.barcode);
    } on SocketException catch (error, stackTrace) {
      debugPrint(
        '[FoodSearch] Barcode exception=${error.runtimeType}: $error\n'
        '$stackTrace',
      );
      _setSearchError(
        'No internet connection. Enter this food manually instead.',
      );
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[FoodSearch] Barcode exception=${error.runtimeType}: $error\n'
        '$stackTrace',
      );
      _setSearchError(
        'Barcode lookup failed. Try again or enter food manually.',
      );
    }
  }

  Future<void> _openManualEntry({String initialFoodName = ''}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManualFoodEntryScreen(initialFoodName: initialFoodName),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food added to today’s log.')),
      );
    }
  }

  Future<void> _openPhotoEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhotoFoodReviewScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo-detected food added to today’s log.'),
        ),
      );
    }
  }

  void _showManualFallback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Enter manually',
          onPressed: () => _openManualEntry(),
        ),
      ),
    );
  }

  Future<void> _confirmAndLog(
    FoodProductResult product, {
    required String source,
  }) async {
    if (!product.nutrition.hasAnyValues) {
      await _openManualEntry(initialFoodName: product.name);
      return;
    }

    final quantity = await showDialog<double>(
      context: context,
      builder: (_) => FoodServingConfirmationDialog(product: product),
    );

    if (quantity == null || !mounted) return;
    final foodLog = product.toFoodLog(quantity: quantity, source: source);
    await Hive.box<FoodLog>('foodLogs').put(foodLog.id, foodLog);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to today’s log.')),
      );
    }
  }

  Widget _productCard(FoodProductResult product) {
    final values = product.nutrition.values;
    final palette = Theme.of(context).extension<AppThemePalette>() ?? AppThemePalette.dark;
    final title = Text(
      product.name,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: palette.primaryText,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(palette.cardPadding),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        border: Border.all(
          color: palette.secondaryText.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: palette.secondaryText.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                product.isCommonFood ? 'Common food' : 'Packaged product',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (product.imageUrl?.isNotEmpty == true)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.fastfood_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: title),
              ],
            )
          else
            title,
          if (product.brand?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              product.brand!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            product.nutrition.hasAnyValues
                ? '${product.nutrition.basisLabel} (${product.nutrition.servingSize})'
                : 'Nutrition data unavailable from Open Food Facts',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Calories ${_compactValue(values.caloriesKcal, 'kcal')}  ·  '
            'Protein ${_compactValue(values.proteinGrams, 'g')}  ·  '
            'Carbs ${_compactValue(values.carbsGrams, 'g')}  ·  '
            'Fat ${_compactValue(values.fatGrams, 'g')}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  _confirmAndLog(product, source: FoodLogSource.offSearch),
              icon: Icon(
                product.nutrition.hasAnyValues
                    ? Icons.add_rounded
                    : Icons.edit_note_rounded,
                color: palette.primaryText,
              ),
              label: Text(
                product.nutrition.hasAnyValues
                    ? 'Choose quantity'
                    : 'Enter nutrition manually',
                style: TextStyle(color: palette.primaryText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _compactValue(double? value, String unit) =>
      value == null ? '—' : '${value.toStringAsFixed(1)} $unit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add food')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: 'Search foods or packaged products',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          ++_searchRequestId;
                          _foodService.cancelInFlightSearch();
                          _searchController.clear();
                          setState(() {
                            _products = [];
                            _hasSearched = false;
                            _isLoading = false;
                            _errorMessage = null;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _search,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _scanBarcode,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan barcode'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _openPhotoEntry,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Photo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openManualEntry(),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Enter manually'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: _products.isNotEmpty
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    if (_hasSearched && !_isLoading) ...[
                      TextButton(onPressed: _search, child: const Text('Retry')),
                      TextButton(
                        onPressed: () => _openManualEntry(
                          initialFoodName: _searchController.text.trim(),
                        ),
                        child: const Text('Enter manually'),
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: _products.isEmpty
                  ? Center(
                      child: Text(
                        _isLoading
                            ? 'Searching...'
                            : _hasSearched && _errorMessage != null
                            ? ''
                            : 'Search for a common food or packaged product.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final previous = index > 0 ? _products[index - 1] : null;
                        final startsGroup = previous == null ||
                            previous.isCommonFood != product.isCommonFood;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (startsGroup)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 4,
                                ),
                                child: Text(
                                  product.isCommonFood
                                      ? 'COMMON FOODS'
                                      : 'PACKAGED PRODUCTS',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            _productCard(product),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FoodServingConfirmationDialog extends StatefulWidget {
  const FoodServingConfirmationDialog({super.key, required this.product});

  final FoodProductResult product;

  @override
  State<FoodServingConfirmationDialog> createState() =>
      _FoodServingConfirmationDialogState();
}

class _FoodServingConfirmationDialogState
    extends State<FoodServingConfirmationDialog> {
  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Widget _nutritionLine(String label, double? value, String unit) {
    final formatted = value == null
        ? 'Not listed'
        : '${value.toStringAsFixed(1)} $unit';
    return Text('$label: $formatted');
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return AlertDialog(
      title: Text(product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nutrition basis: ${product.nutrition.basisLabel}.'),
          Text('Stored serving size: ${product.nutrition.servingSize}.'),
          const SizedBox(height: 8),
          _nutritionLine(
            'Calories',
            product.nutrition.values.caloriesKcal,
            'kcal',
          ),
          _nutritionLine(
            'Protein',
            product.nutrition.values.proteinGrams,
            'g',
          ),
          _nutritionLine(
            'Carbohydrates',
            product.nutrition.values.carbsGrams,
            'g',
          ),
          _nutritionLine('Fat', product.nutrition.values.fatGrams, 'g'),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            autofocus: true,
            decoration: InputDecoration(
              labelText:
                  'Quantity (${product.nutrition.servingSize} servings)',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          Text(
            'Values shown are stored per ${product.nutrition.servingSize}; logged totals scale by quantity.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = double.tryParse(_quantityController.text.trim());
            if (parsed == null || parsed <= 0) return;
            Navigator.of(context).pop(parsed);
          },
          child: const Text('Add to today'),
        ),
      ],
    );
  }
}
