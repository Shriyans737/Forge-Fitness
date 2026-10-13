import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/workout_template.dart';
import 'workout_template_repository.dart';

Future<WorkoutTemplate?> saveWorkoutTemplate({
  required BuildContext context,
  required String name,
  required List<String> exerciseIds,
  List<PlannedExercise> plannedExercises = const [],
  String? notes,
}) async {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty || exerciseIds.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Give the workout a name and add at least one exercise.',
          ),
        ),
      );
    }
    return null;
  }

  final template = WorkoutTemplate(
    id: const Uuid().v4(),
    name: trimmedName,
    exerciseIds: exerciseIds,
    plannedExercises: plannedExercises,
    notes: notes,
  );

  await WorkoutTemplateRepository().save(template);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved template “${template.name}”')),
    );
  }

  return template;
}
