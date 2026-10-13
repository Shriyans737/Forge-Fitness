import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise.dart';

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  static const muscleGroups = [
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
    'Cardio',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoUrlController = TextEditingController();
  String? _muscleGroup;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  String? _validateVideoUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a valid http or https URL';
    }
    return null;
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final exercise = Exercise(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      muscleGroup: _muscleGroup!,
      description: _descriptionController.text.trim(),
      videoUrl: _videoUrlController.text.trim().isEmpty
          ? null
          : _videoUrlController.text.trim(),
      isCustom: true,
    );
    await Hive.box<Exercise>('exercises').put(exercise.id, exercise);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Custom Exercise'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveExercise,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an exercise name'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _muscleGroup,
              decoration: const InputDecoration(
                labelText: 'Muscle Group',
                border: OutlineInputBorder(),
              ),
              items: muscleGroups
                  .map(
                    (muscleGroup) => DropdownMenuItem(
                      value: muscleGroup,
                      child: Text(muscleGroup),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _muscleGroup = value;
                });
              },
              validator: (value) => value == null ? 'Select a muscle group' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter form instructions'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _videoUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Video URL (optional)',
                border: OutlineInputBorder(),
              ),
              validator: _validateVideoUrl,
            ),
          ],
        ),
      ),
    );
  }
}