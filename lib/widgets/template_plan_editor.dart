import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/workout_template.dart';

Future<List<PlannedExercise>?> showTemplatePlanEditor({
  required BuildContext context,
  required List<Exercise> exercises,
  List<PlannedExercise> initialPlans = const [],
}) {
  return showDialog<List<PlannedExercise>>(
    context: context,
    builder: (_) =>
        _TemplatePlanDialog(exercises: exercises, initialPlans: initialPlans),
  );
}

class _TemplatePlanDialog extends StatefulWidget {
  const _TemplatePlanDialog({
    required this.exercises,
    required this.initialPlans,
  });

  final List<Exercise> exercises;
  final List<PlannedExercise> initialPlans;

  @override
  State<_TemplatePlanDialog> createState() => _TemplatePlanDialogState();
}

class _TemplatePlanDialogState extends State<_TemplatePlanDialog> {
  late final Map<String, List<int?>> _repsByExercise;

  @override
  void initState() {
    super.initState();
    final initialById = {
      for (final plan in widget.initialPlans)
        plan.exerciseId: plan.sets.map((set) => set.reps).toList(),
    };
    _repsByExercise = {
      for (final exercise in widget.exercises)
        exercise.id: List<int?>.from(initialById[exercise.id] ?? const []),
    };
  }

  void _addSet(String exerciseId) {
    setState(() {
      _repsByExercise[exerciseId]!.add(null);
    });
  }

  void _removeSet(String exerciseId, int index) {
    setState(() {
      _repsByExercise[exerciseId]!.removeAt(index);
    });
  }

  void _save() {
    final plans = <PlannedExercise>[];
    for (final exercise in widget.exercises) {
      final sets = _repsByExercise[exercise.id]!
          .whereType<int>()
          .where((reps) => reps > 0)
          .map((reps) => PlannedSet(reps: reps))
          .toList();
      plans.add(PlannedExercise(exerciseId: exercise.id, sets: sets));
    }
    Navigator.of(context).pop(plans);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Planned sets and reps'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.exercises.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, exerciseIndex) {
            final exercise = widget.exercises[exerciseIndex];
            final reps = _repsByExercise[exercise.id]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ...reps.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text('Set ${entry.key + 1}'),
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue: entry.value?.toString() ?? '',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reps',
                              isDense: true,
                            ),
                            onChanged: (value) {
                              reps[entry.key] = int.tryParse(value);
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove set',
                          onPressed: () => _removeSet(exercise.id, entry.key),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addSet(exercise.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Add set'),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
