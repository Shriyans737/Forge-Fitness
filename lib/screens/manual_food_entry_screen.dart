import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/food_log_model.dart';

class ManualFoodEntryScreen extends StatefulWidget {
  const ManualFoodEntryScreen({super.key, this.initialFoodName = ''});

  final String initialFoodName;

  @override
  State<ManualFoodEntryScreen> createState() => _ManualFoodEntryScreenState();
}

class _ManualFoodEntryScreenState extends State<ManualFoodEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _servingController = TextEditingController(text: '1 serving');
  final _quantityController = TextEditingController(text: '1');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFoodName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingController.dispose();
    _quantityController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String? _validateNumber(String? value, {required bool mustBePositive}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0 || (mustBePositive && parsed == 0)) {
      return mustBePositive ? 'Enter a value greater than 0' : 'Enter a valid number';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final food = FoodLog(
      loggedAt: DateTime.now(),
      foodName: _nameController.text.trim(),
      caloriesPerServing: double.parse(_caloriesController.text.trim()),
      proteinGramsPerServing: double.parse(_proteinController.text.trim()),
      carbsGramsPerServing: double.parse(_carbsController.text.trim()),
      fatGramsPerServing: double.parse(_fatController.text.trim()),
      servingSize: _servingController.text.trim(),
      quantity: double.parse(_quantityController.text.trim()),
      source: FoodLogSource.manual,
    );
    await Hive.box<FoodLog>('foodLogs').put(food.id, food);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool mustBePositive = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: (value) =>
          _validateNumber(value, mustBePositive: mustBePositive),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter food manually')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Food name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a food name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _servingController,
                decoration: const InputDecoration(
                  labelText: 'Serving size',
                  hintText: 'e.g. 1 cup (240 ml)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a serving size'
                    : null,
              ),
              const SizedBox(height: 12),
              _numberField(_quantityController, 'Quantity', mustBePositive: true),
              const SizedBox(height: 20),
              Text(
                'Nutrition per serving',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _numberField(_caloriesController, 'Calories (kcal)'),
              const SizedBox(height: 12),
              _numberField(_proteinController, 'Protein (g)'),
              const SizedBox(height: 12),
              _numberField(_carbsController, 'Carbohydrates (g)'),
              const SizedBox(height: 12),
              _numberField(_fatController, 'Fat (g)'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Add to today'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}