import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/models/exercise.dart';
import 'package:forge/screens/ai_suggestion_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('strips markdown fences and parses strict workout JSON', () {
    const raw = '''```json
{
  "workoutName": "Upper Body Power",
  "exercises": [
    {"name": "Bench Press", "sets": 4, "repRange": "6-8", "reason": "Strength focus"},
    {"name": "Pull Ups", "sets": 3, "repRange": "8-10", "reason": "Back and biceps"}
  ]
}
```''';

    final parsed = parseGeminiWorkoutJson(raw);
    expect(parsed.workoutName, 'Upper Body Power');
    expect(parsed.exercises.length, 2);
    expect(parsed.exercises.first.name, 'Bench Press');
  });

  test('returns a clear parse failure for malformed JSON', () {
    const raw = '{"workoutName": "Broken"';

    expect(() => parseGeminiWorkoutJson(raw), throwsA(isA<FormatException>()));
  });

  test('normalizes and matches dataset-style exercise names', () {
    expect(normalizeExerciseName('Barbell Bench Press - Medium Grip'),
        'barbell bench press medium grip');
    expect(normalizeExerciseName('Close-Grip Barbell Bench Press'),
        'close grip barbell bench press');

    final dataset = [
      Exercise(
        id: '1',
        name: 'Barbell Bench Press - Medium Grip',
        muscleGroup: 'Chest',
        description: 'bench',
      ),
      Exercise(
        id: '2',
        name: 'Close-Grip Barbell Bench Press',
        muscleGroup: 'Chest',
        description: 'bench',
      ),
    ];

    final byExactName = findBestExerciseMatch(
      exercises: dataset,
      name: 'Barbell Bench Press',
    );
    expect(byExactName?.id, '1');

    final byVariant = findBestExerciseMatch(
      exercises: dataset,
      name: 'Barbell Bench Press - Medium Grip',
    );
    expect(byVariant?.id, '1');

    final byCloseGrip = findBestExerciseMatch(
      exercises: dataset,
      name: 'Close-Grip Barbell Bench Press',
    );
    expect(byCloseGrip?.id, '2');
  });

  test('matches real dataset names using normalized matching', () async {
    final jsonString = await rootBundle.loadString('assets/exercises.json');
    final rawEntries = jsonDecode(jsonString) as List<dynamic>;
    final dataset = rawEntries
        .map((entry) => Exercise(
              id: (entry as Map<String, dynamic>)['id'] as String,
              name: (entry)['name'] as String,
              muscleGroup: 'Strength',
              description: 'Seed data',
            ))
        .toList();

    final benchMatch = findBestExerciseMatch(
      exercises: dataset,
      name: 'Barbell Bench Press',
    );
    expect(benchMatch?.name, contains('Barbell'));
    expect(benchMatch?.name, contains('Bench'));

    final inclineMatch = findBestExerciseMatch(
      exercises: dataset,
      name: 'Incline Barbell Bench Press',
    );
    expect(inclineMatch?.name, contains('Incline'));
    expect(inclineMatch?.name, contains('Bench'));

    final pressMatch = findBestExerciseMatch(
      exercises: dataset,
      name: 'Barbell Overhead Press',
    );
    expect(pressMatch?.name, contains('Barbell'));
    expect(pressMatch?.name, contains('Press'));
  });
}
