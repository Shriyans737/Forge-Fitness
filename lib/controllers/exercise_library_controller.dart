import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/exercise.dart';

class ExerciseLibraryController extends ChangeNotifier {
  ExerciseLibraryController({required List<Exercise> exercises})
      : _allExercises = List<Exercise>.from(exercises);

  List<Exercise> _allExercises;
  final Set<String> _selectedMuscleGroups = <String>{};
  String _searchText = '';
  String _selectedEquipment = 'Any';
  String _selectedLevel = 'Any';
  Timer? _debounce;

  List<Exercise> get allExercises => _allExercises;

  String get searchText => _searchText;

  Set<String> get selectedMuscleGroups => Set<String>.from(_selectedMuscleGroups);

  String get selectedEquipment => _selectedEquipment;

  String get selectedLevel => _selectedLevel;

  List<String> get availableMuscleGroups {
    final muscles = _allExercises
        .expand((exercise) => exercise.primaryMuscles)
        .map((muscle) => muscle.trim())
        .where((muscle) => muscle.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return muscles;
  }

  List<String> get availableEquipment {
    final equipment = _allExercises
        .map((exercise) => exercise.equipment?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return equipment;
  }

  static const List<String> levelOptions = ['Any', 'Beginner', 'Intermediate', 'Expert'];

  bool get hasActiveFilters => activeFilterCount > 0;

  int get activeFilterCount {
    var count = 0;
    if (_searchText.trim().isNotEmpty) {
      count += 1;
    }
    if (_selectedMuscleGroups.isNotEmpty) {
      count += 1;
    }
    if (_selectedEquipment != 'Any') {
      count += 1;
    }
    if (_selectedLevel != 'Any') {
      count += 1;
    }
    return count;
  }

  List<Exercise> get filteredExercises {
    var results = _allExercises;

    final normalizedQuery = _searchText.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      results = results.where((exercise) {
        return exercise.name.toLowerCase().contains(normalizedQuery);
      }).toList();
    }

    if (_selectedMuscleGroups.isNotEmpty) {
      final selectedMuscles = _selectedMuscleGroups.map((muscle) => muscle.toLowerCase()).toSet();
      results = results.where((exercise) {
        final exerciseMuscles = exercise.primaryMuscles
            .map((muscle) => muscle.trim().toLowerCase())
            .toSet();
        return exerciseMuscles.any(selectedMuscles.contains);
      }).toList();
    }

    if (_selectedEquipment != 'Any') {
      final selectedEquipment = _selectedEquipment.trim().toLowerCase();
      results = results.where((exercise) {
        final equipment = (exercise.equipment ?? '').trim().toLowerCase();
        return equipment == selectedEquipment;
      }).toList();
    }

    if (_selectedLevel != 'Any') {
      final selectedLevel = _selectedLevel.trim().toLowerCase();
      results = results.where((exercise) {
        final level = (exercise.level ?? '').trim().toLowerCase();
        return level == selectedLevel;
      }).toList();
    }

    return results;
  }

  void setSearch(String value) {
    _searchText = value.trim();

    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(const Duration(milliseconds: 300), notifyListeners);
  }

  void setExercises(List<Exercise> exercises) {
    final updated = List<Exercise>.from(exercises);
    _allExercises = updated;
    notifyListeners();
  }

  void toggleMuscleGroup(String muscle) {
    if (_selectedMuscleGroups.contains(muscle)) {
      _selectedMuscleGroups.remove(muscle);
    } else {
      _selectedMuscleGroups.add(muscle);
    }
    notifyListeners();
  }

  void setEquipment(String? equipment) {
    _selectedEquipment = equipment ?? 'Any';
    notifyListeners();
  }

  void setLevel(String? level) {
    _selectedLevel = level ?? 'Any';
    notifyListeners();
  }

  void clearFilters() {
    _searchText = '';
    _selectedMuscleGroups.clear();
    _selectedEquipment = 'Any';
    _selectedLevel = 'Any';
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
