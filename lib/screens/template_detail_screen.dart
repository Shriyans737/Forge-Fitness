import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/exercise.dart';
import '../models/workout_template.dart';
import '../services/workout_share_service.dart';
import '../widgets/shareable_workout_card.dart';
import 'active_workout_screen.dart';

class TemplateDetailScreen extends StatelessWidget {
  TemplateDetailScreen({required this.template, super.key});

  final WorkoutTemplate template;
  final GlobalKey _cardKey = GlobalKey();

  Future<void> _share(BuildContext context, List<Exercise> exercises) {
    return WorkoutShareService.share(
      context: context,
      cardKey: _cardKey,
      data: WorkoutShareData.template(template: template, exercises: exercises),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercisesBox = Hive.box<Exercise>('exercises');
    final exercises = template.exerciseIds
        .map((id) => exercisesBox.get(id))
        .whereType<Exercise>()
        .toList(growable: false);
    final data = WorkoutShareData.template(
      template: template,
      exercises: exercises,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(template.name),
        actions: [
          IconButton(
            tooltip: 'Share template',
            onPressed: () => _share(context, exercises),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                key: _cardKey,
                child: ShareableWorkoutCard(data: data),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ActiveWorkoutScreen(
                        initialExerciseIds: template.exerciseIds,
                        initialWorkoutName: template.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Workout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
