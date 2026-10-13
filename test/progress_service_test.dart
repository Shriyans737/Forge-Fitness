import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/progress_service.dart';

void main() {
  group('ProgressService', () {
    test('calculates Epley 1RM and handles one-rep and unreliable sets', () {
      expect(ProgressService.estimateOneRepMax(60, 8), closeTo(76, 0.001));
      expect(ProgressService.estimateOneRepMax(60, 1), 60);
      expect(ProgressService.estimateOneRepMax(60, 13), 0);
    });

    test('excludes warm-up sets and orders session history oldest first', () {
      final history = ProgressService.calculateHistory(
        exerciseId: 'bench',
        workouts: [
          _workout(
            DateTime(2026, 2, 1),
            const [ProgressSetRecord(weight: 50, reps: 8)],
          ),
          _workout(
            DateTime(2026, 1, 1),
            const [
              ProgressSetRecord(weight: 100, reps: 10, isWarmUp: true),
              ProgressSetRecord(weight: 40, reps: 10),
              ProgressSetRecord(weight: 50, reps: 8),
            ],
          ),
        ],
      );

      expect(history.sessions.map((session) => session.date.month), [1, 2]);
      expect(history.sessions.first.topSetWeight, 50);
      expect(history.sessions.first.totalVolume, 800);
      expect(history.sessions.first.totalReps, 18);
    });

    test('bodyweight sessions report reps without weight or volume metrics', () {
      final history = ProgressService.calculateHistory(
        exerciseId: 'pushup',
        workouts: [
          ProgressWorkoutRecord(
            date: DateTime(2026, 1, 1),
            exercises: const [
              ProgressExerciseRecord(
                exerciseId: 'pushup',
                exerciseName: 'Push Up',
                sets: [
                  ProgressSetRecord(weight: 0, reps: 12),
                  ProgressSetRecord(weight: null, reps: 15),
                ],
              ),
            ],
          ),
        ],
      );

      final session = history.sessions.single;
      expect(history.isBodyweight, isTrue);
      expect(session.bestReps, 15);
      expect(session.valueFor(ProgressMetric.bestReps), 15);
      expect(session.valueFor(ProgressMetric.estimatedOneRepMax), isNull);
      expect(session.valueFor(ProgressMetric.volume), isNull);
    });

    test('detects heaviest weight, best 1RM, and reps at a given weight', () {
      final history = ProgressService.calculateHistory(
        exerciseId: 'bench',
        workouts: [
          _workout(
            DateTime(2026, 1, 1),
            const [ProgressSetRecord(weight: 60, reps: 8)],
          ),
          _workout(
            DateTime(2026, 2, 1),
            const [
              ProgressSetRecord(weight: 70, reps: 6),
              ProgressSetRecord(weight: 60, reps: 10),
            ],
          ),
        ],
      );

      expect(
        history.personalRecords.map((record) => record.type),
        containsAll([
          ProgressPrType.heaviestWeight,
          ProgressPrType.estimatedOneRepMax,
          ProgressPrType.repsAtWeight,
        ]),
      );
      expect(
        history.personalRecords.singleWhere(
          (record) => record.type == ProgressPrType.heaviestWeight,
        ).value,
        70,
      );
      expect(
        history.personalRecords.singleWhere(
          (record) => record.type == ProgressPrType.repsAtWeight &&
              record.weight == 60,
        ).value,
        10,
      );
    });

    test('handles zero, one, and two sessions', () {
      final empty = ProgressService.calculateHistory(
        exerciseId: 'bench',
        workouts: const [],
      );
      final one = ProgressService.calculateHistory(
        exerciseId: 'bench',
        workouts: [
          _workout(
            DateTime(2026, 1, 1),
            const [ProgressSetRecord(weight: 50, reps: 8)],
          ),
        ],
      );
      final two = ProgressService.calculateHistory(
        exerciseId: 'bench',
        workouts: [
          _workout(
            DateTime(2026, 1, 1),
            const [ProgressSetRecord(weight: 50, reps: 8)],
          ),
          _workout(
            DateTime(2026, 2, 1),
            const [ProgressSetRecord(weight: 52.5, reps: 8)],
          ),
        ],
      );

      expect(empty.sessions, isEmpty);
      expect(one.sessions, hasLength(1));
      expect(two.sessions, hasLength(2));
    });
  });

  group('ProgressionRules', () {
    test('adds 2.5 kg and resets reps after all sets hit the top', () {
      final suggestion = ProgressionRules.suggest(
        history: _history('Bench Press', [
          _session(
            DateTime(2026, 1, 1),
            const [ProgressSetRecord(weight: 60, reps: 12)],
          ),
        ]),
        targetRepMin: 8,
        targetRepMax: 12,
      )!;

      expect(suggestion.type, ProgressionType.increaseWeight);
      expect(suggestion.summaryTarget!.weight, 62.5);
      expect(suggestion.summaryTarget!.reps, 8);
    });

    test('adds one rep on sets short of the top', () {
      final suggestion = ProgressionRules.suggest(
        history: _history('Bench Press', [
          _session(
            DateTime(2026, 1, 1),
            const [
              ProgressSetRecord(weight: 60, reps: 10),
              ProgressSetRecord(weight: 60, reps: 12),
            ],
          ),
        ]),
        targetRepMin: 8,
        targetRepMax: 12,
      )!;

      expect(suggestion.type, ProgressionType.addReps);
      expect(suggestion.targets.map((target) => target.reps), [11, 12]);
    });

    test('suggests a rounded deload after two consecutive bottom misses', () {
      final suggestion = ProgressionRules.suggest(
        history: _history('Bench Press', [
          _session(
            DateTime(2026, 1, 1),
            const [ProgressSetRecord(weight: 60, reps: 6)],
          ),
          _session(
            DateTime(2026, 2, 1),
            const [ProgressSetRecord(weight: 60, reps: 7)],
          ),
        ]),
        targetRepMin: 8,
        targetRepMax: 12,
      )!;

      expect(suggestion.type, ProgressionType.deload);
      expect(suggestion.summaryTarget!.weight, 55);
      expect(suggestion.summaryTarget!.reps, 8);
    });

    test('uses 5 kg for lower compound lifts and rounds to 1.25 kg', () {
      final suggestion = ProgressionRules.suggest(
        history: _history('Back Squat', [
          _session(
            DateTime(2026, 1, 1),
            const [ProgressSetRecord(weight: 60, reps: 12)],
          ),
        ]),
        targetRepMin: 8,
        targetRepMax: 12,
      )!;

      expect(suggestion.summaryTarget!.weight, 65);
      expect(ProgressionRules.roundWeightToStep(63.1), 62.5);
    });
  });
}

ProgressWorkoutRecord _workout(
  DateTime date,
  List<ProgressSetRecord> sets,
) =>
    ProgressWorkoutRecord(
      date: date,
      exercises: [
        ProgressExerciseRecord(
          exerciseId: 'bench',
          exerciseName: 'Bench Press',
          sets: sets,
        ),
      ],
    );

ExerciseProgressHistory _history(
  String exerciseName,
  List<ExerciseProgressSession> sessions,
) =>
    ExerciseProgressHistory(
      exerciseId: 'bench',
      exerciseName: exerciseName,
      sessions: sessions,
      personalRecords: const [],
      isBodyweight: false,
    );

ExerciseProgressSession _session(
  DateTime date,
  List<ProgressSetRecord> sets,
) =>
    ExerciseProgressSession(
      date: date,
      sets: sets,
      isBodyweight: sets.every((set) => set.weight == null || set.weight == 0),
      topSetWeight: null,
      estimatedOneRepMax: null,
      totalVolume: null,
      totalReps: sets.fold(0, (total, set) => total + set.reps),
      bestReps: sets.isEmpty
          ? null
          : sets.map((set) => set.reps).reduce((a, b) => a > b ? a : b),
    );