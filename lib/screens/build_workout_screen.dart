import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/muscle_name_mapping.dart';
import '../data/workout_template_service.dart';
import '../models/exercise.dart';
import 'active_workout_screen.dart';
import 'exercise_detail_screen.dart';
import '../widgets/template_plan_editor.dart';

class BuildWorkoutScreen extends StatefulWidget {
  const BuildWorkoutScreen({super.key});

  @override
  State<BuildWorkoutScreen> createState() => _BuildWorkoutScreenState();
}

class _BuildWorkoutScreenState extends State<BuildWorkoutScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: 'New Workout',
  );
  final List<Exercise> _selectedExercises = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onExercisesSelected(Set<String> selectedIds) {
    final exercisesBox = Hive.box<Exercise>('exercises');
    final nextExercises = selectedIds
        .map((id) => exercisesBox.get(id))
        .whereType<Exercise>()
        .toList();

    setState(() {
      _selectedExercises
        ..clear()
        ..addAll(nextExercises);
    });
  }

  Future<void> _showAddExercisePicker() async {
    final exercisesBox = Hive.box<Exercise>('exercises');
    final allExercises = exercisesBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final selectedIds = _selectedExercises
        .map((exercise) => exercise.id)
        .toSet();

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _ExercisePickerSheet(
        allExercises: allExercises,
        initialSelection: selectedIds,
      ),
    );

    if (result == null) {
      return;
    }

    _onExercisesSelected(result);
  }

  void _removeExercise(int index) {
    setState(() {
      _selectedExercises.removeAt(index);
    });
  }

  void _startWorkout() {
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one exercise before starting a workout.'),
        ),
      );
      return;
    }

    final exerciseIds = _selectedExercises
        .map((exercise) => exercise.id)
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(initialExerciseIds: exerciseIds),
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one exercise before saving a template.'),
        ),
      );
      return;
    }

    final exerciseIds = _selectedExercises
        .map((exercise) => exercise.id)
        .toList();
    final plannedExercises = await showTemplatePlanEditor(
      context: context,
      exercises: _selectedExercises,
    );
    if (plannedExercises == null || !mounted) {
      return;
    }

    await saveWorkoutTemplate(
      context: context,
      name: _nameController.text,
      exerciseIds: exerciseIds,
      plannedExercises: plannedExercises,
    );
  }

  Set<Muscle> _combinedMuscles() {
    final primary = <Muscle>{};
    final secondary = <Muscle>{};

    for (final exercise in _selectedExercises) {
      final currentPrimary = resolveExerciseMuscles(exercise.primaryMuscles);
      final currentSecondary = resolveExerciseMuscles(
        exercise.secondaryMuscles,
      );

      primary.addAll(currentPrimary);
      for (final muscle in currentSecondary) {
        if (!primary.contains(muscle)) {
          secondary.add(muscle);
        }
      }
    }

    return {...primary, ...secondary};
  }

  @override
  Widget build(BuildContext context) {
    final hasTargetMuscles = _combinedMuscles().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Build Workout')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Workout name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showAddExercisePicker,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Exercise'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (_selectedExercises.isNotEmpty) ...[
                    Text(
                      'Muscles Targeted',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (hasTargetMuscles)
                      _CombinedMuscleDiagram(exercises: _selectedExercises),
                    if (!hasTargetMuscles)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No mapped muscles were detected for the selected exercises.',
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Exercises',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_selectedExercises.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No exercises added yet. Add a few and build your workout plan.',
                        ),
                      ),
                    )
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      buildDefaultDragHandles: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final exercise = _selectedExercises.removeAt(
                            oldIndex,
                          );
                          _selectedExercises.insert(newIndex, exercise);
                        });
                      },
                      children: [
                        for (
                          int index = 0;
                          index < _selectedExercises.length;
                          index++
                        )
                          Card(
                            key: ValueKey(_selectedExercises[index].id),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                _selectedExercises[index].name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: _MuscleGroupTag(
                                  muscleGroup:
                                      _selectedExercises[index].muscleGroup,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Delete exercise',
                                    onPressed: () => _removeExercise(index),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ExerciseDetailScreen(
                                      exercise: _selectedExercises[index],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveAsTemplate,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save as Template'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _startWorkout,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Workout'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({
    required this.allExercises,
    required this.initialSelection,
  });

  final List<Exercise> allExercises;
  final Set<String> initialSelection;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  static const muscleGroups = [
    'All',
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
    'Cardio',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedMuscleGroup = 'All';
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelection);
  }

  List<Exercise> _filteredExercises() {
    final query = _searchController.text.trim().toLowerCase();
    return widget.allExercises.where((exercise) {
      final matchesQuery =
          query.isEmpty || exercise.name.toLowerCase().contains(query);
      final matchesGroup =
          _selectedMuscleGroup == 'All' ||
          exercise.muscleGroup == _selectedMuscleGroup;
      return matchesQuery && matchesGroup;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredExercises = _filteredExercises();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select exercises',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selectedIds),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search exercises',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.clear),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: muscleGroups.length,
                separatorBuilder: (context, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final title = muscleGroups[index];
                  return FilterChip(
                    label: Text(title),
                    selected: _selectedMuscleGroup == title,
                    onSelected: (_) {
                      setState(() {
                        _selectedMuscleGroup = title;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredExercises.length,
                itemBuilder: (context, index) {
                  final exercise = filteredExercises[index];
                  final isSelected = _selectedIds.contains(exercise.id);
                  return ListTile(
                    key: ValueKey(exercise.id),
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedIds.add(exercise.id);
                          } else {
                            _selectedIds.remove(exercise.id);
                          }
                        });
                      },
                    ),
                    title: Text(exercise.name),
                    subtitle: Text(exercise.muscleGroup),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ExerciseDetailScreen(exercise: exercise),
                        ),
                      );
                    },
                    trailing: IconButton(
                      tooltip: 'View exercise details',
                      icon: const Icon(Icons.info_outline),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ExerciseDetailScreen(exercise: exercise),
                          ),
                        );
                      },
                    ),
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

class _CombinedMuscleDiagram extends StatelessWidget {
  const _CombinedMuscleDiagram({required this.exercises});

  final List<Exercise> exercises;

  Set<Muscle> get _targetMuscles {
    final primary = <Muscle>{};
    final secondary = <Muscle>{};

    for (final exercise in exercises) {
      final mappedPrimary = resolveExerciseMuscles(exercise.primaryMuscles);
      final mappedSecondary = resolveExerciseMuscles(exercise.secondaryMuscles);

      primary.addAll(mappedPrimary);
      for (final muscle in mappedSecondary) {
        if (!primary.contains(muscle)) {
          secondary.add(muscle);
        }
      }
    }

    return {...primary, ...secondary};
  }

  bool _isFrontMuscle(Muscle muscle) {
    switch (muscle) {
      case Muscle.trapsLeft:
      case Muscle.trapsRight:
      case Muscle.deltsLeft:
      case Muscle.deltsRight:
      case Muscle.chestLeft:
      case Muscle.chestRight:
      case Muscle.abs:
      case Muscle.tricepsLeft:
      case Muscle.tricepsRight:
      case Muscle.bicepsLeft:
      case Muscle.bicepsRight:
      case Muscle.forearmsLeft:
      case Muscle.forearmsRight:
      case Muscle.quadsLeft:
      case Muscle.quadsRight:
      case Muscle.calvesLeft:
      case Muscle.calvesRight:
        return true;
      case Muscle.latsBackLeft:
      case Muscle.latsBackRight:
      case Muscle.lowerLatsBackLeft:
      case Muscle.lowerLatsBackRight:
      case Muscle.glutesLeft:
      case Muscle.glutesRight:
      case Muscle.hamstringsLeft:
      case Muscle.hamstringsRight:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetMuscles = _targetMuscles;
    if (targetMuscles.isEmpty) {
      return const SizedBox.shrink();
    }

    final frontMuscles = targetMuscles.where(_isFrontMuscle).toSet();
    final backMuscles = targetMuscles
        .where((muscle) => !_isFrontMuscle(muscle))
        .toSet();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 12) / 2;
          return Row(
            children: [
              SizedBox(
                width: itemWidth,
                child: _BodySideView(
                  title: 'Front',
                  isFront: true,
                  selectedMuscles: frontMuscles,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: itemWidth,
                child: _BodySideView(
                  title: 'Back',
                  isFront: false,
                  selectedMuscles: backMuscles,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BodySideView extends StatelessWidget {
  const _BodySideView({
    required this.title,
    required this.isFront,
    required this.selectedMuscles,
  });

  final String title;
  final bool isFront;
  final Set<Muscle> selectedMuscles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: InteractiveBodySvg(
            isFront: isFront,
            selectedMuscles: selectedMuscles,
            enableSelection: false,
            highlightColor: isFront
                ? const Color(0xFF1FA39A)
                : const Color(0xFF2D6CDF),
            disabledColor: const Color(0xFFCAD6D9),
            selectedStrokeWidth: 2.5,
            unselectedStrokeWidth: 1.2,
            width: double.infinity,
            height: 180,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _MuscleGroupTag extends StatelessWidget {
  const _MuscleGroupTag({required this.muscleGroup});

  final String muscleGroup;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        muscleGroup,
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
