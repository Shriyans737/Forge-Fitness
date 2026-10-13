import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/exercise.dart';

const _muscleGroupLookup = <String, String>{
  'biceps': 'Arms',
  'triceps': 'Arms',
  'forearms': 'Arms',
  'quadriceps': 'Legs',
  'hamstrings': 'Legs',
  'calves': 'Legs',
  'glutes': 'Legs',
  'chest': 'Chest',
  'lats': 'Back',
  'middle back': 'Back',
  'lower back': 'Back',
  'traps': 'Back',
  'shoulders': 'Shoulders',
  'abdominals': 'Core',
};

Future<List<Exercise>> loadPresetExercises() async {
  final jsonString = await rootBundle.loadString('assets/exercises.json');
  final exercises = await compute(_parseExercises, jsonString);

  for (var i = 0; i < exercises.length && i < 5; i++) {
    final exercise = exercises[i];
    debugPrint(
      'Parsed exercise ${exercise.id}: imagePaths.length=${exercise.imagePaths.length}',
    );
  }

  return exercises;
}

List<Exercise> _parseExercises(String jsonString) {
  final entries = jsonDecode(jsonString) as List<dynamic>;

  return entries.map((entry) {
    final data = entry as Map<String, dynamic>;
    final primaryMuscles = _stringList(data['primaryMuscles']);
    final instructions = _stringList(data['instructions']);
    final primaryMuscle = primaryMuscles.isEmpty
        ? null
        : primaryMuscles.first.toLowerCase();
    final muscleGroup = _muscleGroupLookup[primaryMuscle] ??
        (data['category']?.toString().toLowerCase() == 'cardio'
            ? 'Cardio'
            : 'Core');

    return Exercise(
      id: data['id'] as String,
      name: data['name'] as String,
      muscleGroup: muscleGroup,
      description: instructions.join(' '),
      videoUrl: null,
      videoId: null,
      isCustom: false,
      imagePaths: _stringList(data['images']),
      primaryMuscles: primaryMuscles,
      secondaryMuscles: _stringList(data['secondaryMuscles']),
      equipment: data['equipment'] as String?,
      level: data['level'] as String?,
      instructions: instructions,
    );
  }).toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value.whereType<String>().toList();
}
