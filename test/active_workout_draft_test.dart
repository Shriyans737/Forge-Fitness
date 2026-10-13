import 'package:flutter_test/flutter_test.dart';
import 'package:forge/models/active_workout_draft.dart';
import 'package:forge/models/workout_session.dart';

void main() {
  test('active workout draft preserves start time, sets, and completion', () {
    final startedAt = DateTime(2026, 10, 5, 12, 30);
    final draft = ActiveWorkoutDraft(
      id: 'draft-id',
      startedAt: startedAt,
      name: 'Upper body',
      exercises: [
        LoggedExercise(
          exerciseId: 'bench-press',
          exerciseName: 'Bench Press',
          sets: [
            ExerciseSet(weight: 40, reps: 10),
            ExerciseSet(weight: 45, reps: 8, isWarmUp: true),
          ],
        ),
      ],
      completedSets: [
        [true, false],
      ],
      weightInputs: [
        ['40', '45.'],
      ],
      repsInputs: [
        ['10', '8'],
      ],
      notes: 'Controlled tempo',
      exerciseNotes: ['Pause at the bottom'],
      setTypes: [
        ['working', 'drop'],
      ],
      restEndsAt: DateTime(2026, 10, 5, 12, 32),
      restDurationSeconds: 120,
    );

    final restored = ActiveWorkoutDraft.fromMap(draft.toMap());

    expect(restored.id, draft.id);
    expect(restored.startedAt, startedAt);
    expect(restored.name, draft.name);
    expect(restored.exercises.single.sets, hasLength(2));
    expect(restored.exercises.single.sets.first.weight, 40);
    expect(restored.exercises.single.sets.last.isWarmUp, isTrue);
    expect(restored.completedSets.single, [true, false]);
    expect(restored.completedSetCount, 1);
    expect(restored.weightInputs.single, ['40', '45.']);
    expect(restored.repsInputs.single, ['10', '8']);
    expect(restored.notes, draft.notes);
    expect(restored.exerciseNotes, ['Pause at the bottom']);
    expect(restored.setTypes, [
      ['working', 'drop'],
    ]);
    expect(restored.restEndsAt, DateTime(2026, 10, 5, 12, 32));
    expect(restored.restDurationSeconds, 120);
  });

  test('active workout draft defaults optional fields for older drafts', () {
    final restored = ActiveWorkoutDraft.fromMap({
      'id': 'old-draft',
      'startedAt': DateTime(2026, 10, 5).millisecondsSinceEpoch,
      'name': 'Workout',
      'exercises': [
        {
          'exerciseId': 'squat',
          'exerciseName': 'Squat',
          'sets': [
            {'weight': 0.0, 'reps': 0},
          ],
        },
      ],
    });

    expect(restored.completedSetCount, 0);
    expect(restored.exercises.single.sets.single.isWarmUp, isFalse);
    expect(restored.notes, isEmpty);
  });
}
