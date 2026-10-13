import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_log_model.dart';
import '../services/gemini_food_detection_service.dart';
import 'manual_food_entry_screen.dart';

class PhotoFoodReviewScreen extends StatefulWidget {
  const PhotoFoodReviewScreen({super.key});

  @override
  State<PhotoFoodReviewScreen> createState() => _PhotoFoodReviewScreenState();
}

class _PhotoFoodReviewScreenState extends State<PhotoFoodReviewScreen> {
  final _picker = ImagePicker();
  final _foodDetectionService = GeminiFoodDetectionService();
  XFile? _photo;
  Uint8List? _photoBytes;
  List<_FoodDraft> _drafts = [];
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _disposeDrafts() {
    for (final draft in _drafts) {
      draft.quantityController.dispose();
    }
    _drafts = [];
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;

      final bytes = await photo.readAsBytes();
      if (!mounted) return;

      _disposeDrafts();
      setState(() {
        _photo = photo;
        _photoBytes = bytes;
        _errorMessage = null;
      });
      await _analyzePhoto();
    } catch (_) {
      _setError(
        'Could not capture the photo. You can enter the food manually.',
      );
    }
  }

  Future<void> _analyzePhoto() async {
    final photo = _photo;
    final bytes = _photoBytes;
    if (photo == null || bytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final items = await _foodDetectionService.detectFoods(
        imageBytes: bytes,
        mimeType: photo.mimeType ?? 'image/jpeg',
        savedApiKey: Hive.box<dynamic>('settings').get('geminiApiKey'),
      );
      if (!mounted) return;
      _disposeDrafts();
      setState(() {
        _drafts = items.map(_FoodDraft.new).toList();
        _isAnalyzing = false;
      });
    } on MissingGeminiApiKeyException {
      _setError(
        'No Gemini API key is available. Add one in Settings or log this food manually.',
      );
    } on SocketException {
      _setError('No internet connection. Try again or log this food manually.');
    } on FormatException catch (error) {
      _setError('Gemini returned no usable food list: ${error.message}');
    } catch (_) {
      _setError('Gemini food detection failed. Try again or log manually.');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _errorMessage = message;
    });
  }

  Future<void> _openManualEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ManualFoodEntryScreen()),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _removeDraft(_FoodDraft draft) {
    draft.quantityController.dispose();
    setState(() => _drafts.remove(draft));
  }

  Future<void> _saveReviewedFoods() async {
    if (_drafts.isEmpty) return;
    final quantities = <_FoodDraft, double>{};
    for (final draft in _drafts) {
      final quantity = double.tryParse(draft.quantityController.text.trim());
      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Each quantity must be greater than zero.'),
          ),
        );
        return;
      }
      quantities[draft] = quantity;
    }

    setState(() => _isSaving = true);
    final box = Hive.box<FoodLog>('foodLogs');
    for (final entry in quantities.entries) {
      final item = entry.key.item;
      final foodLog = FoodLog(
        loggedAt: DateTime.now(),
        foodName: item.name,
        caloriesPerServing: item.caloriesPerServing,
        proteinGramsPerServing: item.proteinGramsPerServing,
        carbsGramsPerServing: item.carbsGramsPerServing,
        fatGramsPerServing: item.fatGramsPerServing,
        servingSize: item.servingSize,
        quantity: entry.value,
        source: FoodLogSource.photoAi,
      );
      await box.put(foodLog.id, foodLog);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _draftCard(_FoodDraft draft) {
    final item = draft.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove food item',
                  onPressed: () => _removeDraft(draft),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Text('Nutrition per ${item.servingSize} (AI estimate)'),
            const SizedBox(height: 4),
            Text(
              '${item.caloriesPerServing.toStringAsFixed(0)} kcal  ·  '
              'P ${item.proteinGramsPerServing.toStringAsFixed(1)} g  ·  '
              'C ${item.carbsGramsPerServing.toStringAsFixed(1)} g  ·  '
              'F ${item.fatGramsPerServing.toStringAsFixed(1)} g',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity (${item.servingSize} servings)',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food from photo')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_photoBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _photoBytes!,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : _capturePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      _photo == null ? 'Take food photo' : 'Take another photo',
                    ),
                  ),
                  if (_isAnalyzing) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_errorMessage!),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (_photoBytes != null)
                                TextButton.icon(
                                  onPressed: _analyzePhoto,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              FilledButton.icon(
                                onPressed: _openManualEntry,
                                icon: const Icon(Icons.edit_note_rounded),
                                label: const Text('Log manually'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_drafts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Review detected foods',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nutrition values are estimates. Adjust quantities or remove incorrect items before saving.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ..._drafts.map(_draftCard),
                  ],
                ],
              ),
            ),
            if (_drafts.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveReviewedFoods,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Add reviewed foods to today'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FoodDraft {
  _FoodDraft(this.item)
    : quantityController = TextEditingController(
        text: item.quantity.toString(),
      );

  final DetectedFoodItem item;
  final TextEditingController quantityController;
}
