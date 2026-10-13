import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../widgets/template_plan_editor.dart';
import 'exercise_detail_screen.dart';
import 'template_detail_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  Future<void> _deleteTemplate(
    BuildContext context,
    WorkoutTemplate template,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('Delete “${template.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    Hive.box<WorkoutTemplate>('workoutTemplates').delete(template.id);
  }

  Future<void> _createTemplate(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = Hive.box<Exercise>('exercises');
    final exerciseEntries = box.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (exerciseEntries.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one exercise before creating a template.',
          ),
        ),
      );
      return;
    }

    final selectedIds = <String>{};
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text('Create template'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Template name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: exerciseEntries.length,
                        itemBuilder: (context, index) {
                          final exercise = exerciseEntries[index];
                          final isSelected = selectedIds.contains(exercise.id);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(exercise.name),
                            subtitle: Text(exercise.muscleGroup),
                            controlAffinity: ListTileControlAffinity.leading,
                            secondary: IconButton(
                              tooltip: 'View exercise details',
                              icon: const Icon(Icons.info_outline),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ExerciseDetailScreen(
                                      exercise: exercise,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedIds.add(exercise.id);
                                } else {
                                  selectedIds.remove(exercise.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
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
      },
    );

    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final trimmedName = nameController.text.trim();
    if (trimmedName.isEmpty || selectedIds.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Name the template and select at least one exercise.'),
        ),
      );
      return;
    }

    final selectedExercises = exerciseEntries
        .where((exercise) => selectedIds.contains(exercise.id))
        .toList(growable: false);
    final plannedExercises = await showTemplatePlanEditor(
      context: context,
      exercises: selectedExercises,
    );
    if (plannedExercises == null || !context.mounted) {
      return;
    }

    final template = WorkoutTemplate(
      id: const Uuid().v4(),
      name: trimmedName,
      exerciseIds: selectedIds.toList(),
      plannedExercises: plannedExercises,
    );

    Hive.box<WorkoutTemplate>('workoutTemplates').put(template.id, template);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved template “${template.name}”')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templateBox = Hive.box<WorkoutTemplate>('workoutTemplates');

    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: ValueListenableBuilder<Box<WorkoutTemplate>>(
        valueListenable: templateBox.listenable(),
        builder: (context, box, _) {
          final templates = box.values.toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          if (templates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No templates yet. Save a workout or create one from your exercise library.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    template.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${template.exerciseIds.length} exercises'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TemplateDetailScreen(template: template),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete template',
                    onPressed: () => _deleteTemplate(context, template),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTemplate(context),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
    );
  }
}
