import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/workout_context_builder.dart';
import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../services/gemini_api_key_resolver.dart';
import 'active_workout_screen.dart';
import 'exercise_detail_screen.dart';

const List<String> _muscleGroups = [
  'Any',
  'Chest',
  'Shoulders',
  'Back',
  'Biceps',
  'Triceps',
  'Abs',
  'Quads',
  'Hamstrings',
  'Glutes',
  'Calves',
  'Forearms',
];

const List<String> _equipmentOptions = [
  'Any',
  'Bodyweight',
  'Dumbbells',
  'Barbell',
  'Machines',
  'Kettlebell',
];

class GeminiWorkoutSuggestion {
  GeminiWorkoutSuggestion({required this.workoutName, required this.exercises});

  final String workoutName;
  final List<GeminiSuggestedExercise> exercises;
}

class GeminiSuggestedExercise {
  GeminiSuggestedExercise({
    required this.name,
    required this.sets,
    required this.repRange,
    required this.reason,
  });

  final String name;
  final int sets;
  final String repRange;
  final String reason;
}

GeminiWorkoutSuggestion parseGeminiWorkoutJson(String rawJson) {
  final trimmed = rawJson.trim();
  final withoutFence = trimmed
      .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*```$'), '');
  final jsonString = withoutFence.trim();
  if (jsonString.isEmpty) {
    throw const FormatException('Empty Gemini response');
  }

  final decoded = jsonDecode(jsonString);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'Workout suggestion payload is not a JSON object.',
    );
  }

  final name = (decoded['workoutName'] ?? 'Suggested Workout').toString();
  final list = decoded['exercises'];
  if (list is! List) {
    throw const FormatException(
      'Workout suggestion response is missing an exercise list.',
    );
  }

  final exercises = list.map((item) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Each exercise row must be an object.');
    }

    return GeminiSuggestedExercise(
      name: (item['name'] ?? 'Unknown exercise').toString(),
      sets: int.tryParse((item['sets'] ?? '0').toString()) ?? 0,
      repRange: (item['repRange'] ?? 'N/A').toString(),
      reason: (item['reason'] ?? 'Good fit for your current training pattern.')
          .toString(),
    );
  }).toList();

  return GeminiWorkoutSuggestion(workoutName: name, exercises: exercises);
}

String normalizeExerciseName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final withAnd = trimmed
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');

  final collapsed = withAnd
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return collapsed;
}

List<String> _exerciseTokens(String value) {
  return normalizeExerciseName(value)
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList();
}

int _exerciseNameMatchScore(String left, String right) {
  final normalizedLeft = normalizeExerciseName(left);
  final normalizedRight = normalizeExerciseName(right);

  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return 0;
  }

  if (normalizedLeft == normalizedRight) {
    return 100;
  }

  final leftTokens = _exerciseTokens(normalizedLeft).toSet();
  final rightTokens = _exerciseTokens(normalizedRight).toSet();
  final overlap = leftTokens.intersection(rightTokens).length;

  if (overlap == 0) {
    return 0;
  }

  final containsBonus =
      normalizedLeft.contains(normalizedRight) ||
          normalizedRight.contains(normalizedLeft)
      ? 2
      : 0;

  return overlap + containsBonus;
}

class ExerciseMatchInfo {
  ExerciseMatchInfo({required this.exercise, required this.score});

  final Exercise exercise;
  final int score;

  bool get isExact => score >= 100;
  bool get isUncertain => !isExact && score < 10;
}

ExerciseMatchInfo? findBestExerciseMatchInfo({
  required Iterable<Exercise> exercises,
  required String name,
}) {
  final target = normalizeExerciseName(name);
  if (target.isEmpty) {
    return null;
  }

  Exercise? bestMatch;
  var bestScore = 0;

  for (final exercise in exercises) {
    final candidate = exercise.name;
    final score = _exerciseNameMatchScore(target, candidate);
    if (score > bestScore) {
      bestScore = score;
      bestMatch = exercise;
    }
  }

  if (bestScore >= 2 && bestMatch != null) {
    return ExerciseMatchInfo(exercise: bestMatch, score: bestScore);
  }

  return null;
}

Exercise? findBestExerciseMatch({
  required Iterable<Exercise> exercises,
  required String name,
}) {
  return findBestExerciseMatchInfo(exercises: exercises, name: name)?.exercise;
}

class AiSuggestionScreen extends StatefulWidget {
  const AiSuggestionScreen({super.key});

  @override
  State<AiSuggestionScreen> createState() => _AiSuggestionScreenState();
}

class _AiSuggestionScreenState extends State<AiSuggestionScreen> {
  String? _selectedMuscleGroup = 'Any';
  String? _selectedEquipment = 'Any';
  bool _isLoading = false;
  String? _errorMessage;
  GeminiWorkoutSuggestion? _suggestion;

  ExerciseMatchInfo? _findLibraryExerciseInfo(String name) {
    return findBestExerciseMatchInfo(
      exercises: Hive.box<Exercise>('exercises').values,
      name: name,
    );
  }

  void _openExerciseDetail(Exercise exercise) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }

  List<String> _exampleExerciseNamesForPrompt() {
    final box = Hive.box<Exercise>('exercises');
    final allExercises = box.values.toList();
    if (allExercises.isEmpty) {
      return const [
        'Barbell Bench Press - Medium Grip',
        'Barbell Incline Bench Press - Medium Grip',
        'Barbell Shoulder Press',
        'Close-Grip Barbell Bench Press',
        'Lying Close-Grip Barbell Triceps Extension Behind The Head',
      ];
    }

    final filtered = allExercises.where((exercise) {
      final groupMatches =
          _selectedMuscleGroup == null ||
          _selectedMuscleGroup == 'Any' ||
          exercise.primaryMuscles.any(
            (muscle) => muscle.toLowerCase().contains(
              _selectedMuscleGroup!.toLowerCase(),
            ),
          ) ||
          exercise.muscleGroup.toLowerCase() ==
              _selectedMuscleGroup!.toLowerCase();

      final equipmentMatches =
          _selectedEquipment == null ||
          _selectedEquipment == 'Any' ||
          (exercise.equipment ?? '').toLowerCase() ==
              _selectedEquipment!.toLowerCase();

      return groupMatches && equipmentMatches;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    final chosen = filtered.isNotEmpty ? filtered : allExercises;
    return chosen
        .map((exercise) => exercise.name)
        .take(8)
        .toList(growable: false);
  }

  Future<void> _generateWorkout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestion = null;
    });

    final keyString = resolveGeminiApiKey(
      savedValue: Hive.box<dynamic>('settings').get('geminiApiKey'),
      compiledDefault: kGeminiApiKey,
    ).key;

    if (keyString == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No Gemini API key found. Add one in Settings or pass the code constant.';
      });
      return;
    }

    try {
      final model = GenerativeModel(model: kGeminiModelName, apiKey: keyString);
      final contextSummary = buildWorkoutContextSummary();
      final overrideText =
          _selectedMuscleGroup == 'Any' && _selectedEquipment == 'Any'
          ? 'No manual overrides; detect training gaps automatically.'
          : 'Manual priorities: muscle group ${_selectedMuscleGroup ?? 'Any'}, equipment ${_selectedEquipment ?? 'Any'}.';
      final exampleNames = _exampleExerciseNamesForPrompt();
      final prompt =
          '''
You are a fitness coach. Use the workout history below and produce strict JSON only with no markdown fences.

Workout history summary:
$contextSummary

$overrideText

Use the app's exercise naming convention exactly when possible. Prefer real names from this database style:
${exampleNames.map((name) => '- $name').join('\n')}

Instructions:
- Suggest a specific workout for the user.
- Keep it realistic and balanced.
- Use exercise names that match the library naming convention and avoid inventing new names.
- If a close match exists, prefer the exact name format from the examples above.
- Return strict JSON only in this format:
{"workoutName":"...","exercises":[{"name":"...","sets":3,"repRange":"8-12","reason":"..."}]}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final rawText = response.text;
      if (rawText == null || rawText.isEmpty) {
        throw const FormatException('Gemini returned an empty response.');
      }

      final parsed = parseGeminiWorkoutJson(rawText);
      setState(() {
        _suggestion = parsed;
        _isLoading = false;
      });
    } on SocketException {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No internet connection. Please check your connection and try again.';
      });
    } on GenerativeAIException catch (error) {
      final message = error.message;
      final normalized = message.toLowerCase();
      setState(() {
        _isLoading = false;
        _errorMessage =
            normalized.contains('model') && normalized.contains('not available')
            ? 'Gemini model is no longer available. Please update Settings to a supported model name and try again.'
            : 'Gemini request failed. Please check your API key or try again.\n$message';
      });
    } on FormatException catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gemini returned malformed JSON. Please retry.\n${error.message}';
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Something went wrong while generating the workout suggestion.';
      });
    }
  }

  Future<void> _startSuggestedWorkout() async {
    final suggestion = _suggestion;
    if (suggestion == null) {
      return;
    }

    final exercisesBox = Hive.box<Exercise>('exercises');
    final matchedIds = <String>[];
    final skippedNames = <String>[];

    for (final item in suggestion.exercises) {
      final match = findBestExerciseMatch(
        exercises: exercisesBox.values,
        name: item.name,
      );

      if (match != null && match.id.isNotEmpty) {
        matchedIds.add(match.id);
      } else {
        skippedNames.add(item.name);
      }
    }

    if (matchedIds.isEmpty) {
      setState(() {
        _errorMessage = 'No suggested exercise names matched the local library. Try again with a different prompt.';
      });
      return;
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(initialExerciseIds: matchedIds),
        ),
      );
    }

    if (skippedNames.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped unmatched exercises: ${skippedNames.join(', ')}',
          ),
        ),
      );
    }
  }

  int _parseRepTarget(String repRange) {
    final trimmed = repRange.trim();
    if (trimmed.isEmpty) {
      return 8;
    }

    final rangeMatch = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(trimmed);
    if (rangeMatch != null) {
      final upper = int.tryParse(rangeMatch.group(2) ?? '') ?? 0;
      final lower = int.tryParse(rangeMatch.group(1) ?? '') ?? 0;
      if (upper > 0) {
        return upper;
      }
      if (lower > 0) {
        return lower;
      }
    }

    final single = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
    return single ?? 8;
  }

  Future<void> _saveSuggestedTemplate() async {
    final suggestion = _suggestion;
    if (suggestion == null) {
      return;
    }

    final exercisesBox = Hive.box<Exercise>('exercises');
    final matchedExercises =
        <({String exerciseId, GeminiSuggestedExercise item})>[];
    final uncertainMatches = <String>[];

    for (final item in suggestion.exercises) {
      final matchInfo = findBestExerciseMatchInfo(
        exercises: exercisesBox.values,
        name: item.name,
      );
      final match = matchInfo?.exercise;

      if (match != null && match.id.isNotEmpty) {
        matchedExercises.add((exerciseId: match.id, item: item));
        if (matchInfo != null && matchInfo.isUncertain) {
          uncertainMatches.add(item.name);
        }
      }
    }

    if (matchedExercises.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No suggested exercises matched the library, so nothing can be saved yet.',
          ),
        ),
      );
      return;
    }

    final nameController = TextEditingController(text: suggestion.workoutName);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save as template'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Template name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true || !mounted) {
      return;
    }

    final trimmedName = nameController.text.trim();
    if (trimmedName.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template name cannot be blank.')),
      );
      return;
    }

    if (uncertainMatches.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uncertain matches detected: ${uncertainMatches.join(', ')}. Review before saving.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final template = WorkoutTemplate(
      id: const Uuid().v4(),
      name: trimmedName,
      exerciseIds: matchedExercises.map((entry) => entry.exerciseId).toList(),
      plannedExercises: matchedExercises.map((entry) {
        final plannedSets = List.generate(
          entry.item.sets,
          (_) => PlannedSet(reps: _parseRepTarget(entry.item.repRange)),
        );
        return PlannedExercise(exerciseId: entry.exerciseId, sets: plannedSets);
      }).toList(),
    );

    Hive.box<WorkoutTemplate>('workoutTemplates').put(template.id, template);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved template “${template.name}”')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Suggested Workout')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manual priorities',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BuildChipGroup(
                    label: 'Muscle group',
                    values: _muscleGroups,
                    selectedValue: _selectedMuscleGroup,
                    onSelected: (value) =>
                        setState(() => _selectedMuscleGroup = value),
                  ),
                  const SizedBox(height: 12),
                  _BuildChipGroup(
                    label: 'Equipment',
                    values: _equipmentOptions,
                    selectedValue: _selectedEquipment,
                    onSelected: (value) =>
                        setState(() => _selectedEquipment = value),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _generateWorkout,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isLoading ? 'Generating...' : 'Generate Workout',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_errorMessage!.contains('API key') ||
                          _errorMessage!.contains('malformed JSON'))
                        TextButton(
                          onPressed: _generateWorkout,
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (_suggestion != null) ...[
                Text(
                  _suggestion!.workoutName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._suggestion!.exercises.map((exercise) {
                  final matchInfo = _findLibraryExerciseInfo(exercise.name);
                  final libraryExercise = matchInfo?.exercise;
                  final isExact = matchInfo?.isExact ?? false;
                  final isUncertain = matchInfo?.isUncertain ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: libraryExercise == null
                          ? null
                          : () => _openExerciseDetail(libraryExercise),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    exercise.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (libraryExercise != null)
                                  const Icon(Icons.chevron_right),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${exercise.sets} sets • ${exercise.repRange} reps',
                            ),
                            const SizedBox(height: 8),
                            if (libraryExercise != null)
                              Row(
                                children: [
                                  Icon(
                                    isExact
                                        ? Icons.check_circle_rounded
                                        : isUncertain
                                        ? Icons.warning_amber_rounded
                                        : Icons.info_outline_rounded,
                                    size: 16,
                                    color: isExact
                                        ? Colors.green
                                        : isUncertain
                                        ? Colors.orange
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Matched to: ${libraryExercise.name}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isExact
                                                ? Colors.green
                                                : isUncertain
                                                ? Colors.orange
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                          ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              const Text(
                                'No reliable match found in the library.',
                              ),
                            if (libraryExercise != null && isUncertain) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Uncertain match — review before saving as a template.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.orange),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(exercise.reason),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _startSuggestedWorkout,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start This Workout'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saveSuggestedTemplate,
                        icon: const Icon(Icons.save_alt_rounded),
                        label: const Text('Save as Template'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildChipGroup extends StatelessWidget {
  const _BuildChipGroup({
    required this.label,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  final String label;
  final List<String> values;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) {
            final isSelected = selectedValue == value;
            return ChoiceChip(
              label: Text(value),
              selected: isSelected,
              onSelected: (_) => onSelected(value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
