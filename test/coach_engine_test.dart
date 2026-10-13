import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/coach/services/coach_engine.dart';

void main() {
  const engine = CoachEngine();
  final now = DateTime(2026, 10, 10, 18);
  CoachContext context({
    double? recovery,
    double? sleep,
    double? sleepGoal = 480,
    double? protein,
    double? proteinGoal = 120,
    double? calories,
    double? calorieGoal,
    int? workouts = 2,
    int? workoutGoal = 3,
    List<CoachDayScore> days = const [],
    List<CoachWorkout> sessions = const [],
    List<CoachTemplate> templates = const [],
    List<double> sleepDays = const [],
    List<CoachBodyWeight> weights = const [],
    double? targetWeight,
    DateTime? targetDate,
    int streakDays = 0,
    List<String> hits = const [],
    Set<int> milestones = const {},
    DateTime? time,
  }) => CoachContext(
    now: time ?? now,
    recovery: recovery,
    sleepMinutes: sleep,
    sleepGoalMinutes: sleepGoal,
    proteinGrams: protein,
    proteinGoalGrams: proteinGoal,
    calories: calories,
    calorieGoal: calorieGoal,
    weeklyWorkoutCount: workouts,
    workoutsPerWeekGoal: workoutGoal,
    last14Days: days,
    workouts: sessions,
    templates: templates,
    last7DaysSleepMinutes: sleepDays,
    bodyWeights: weights,
    targetWeightKg: targetWeight,
    targetWeightDate: targetDate,
    trainingStreakDays: streakDays,
    hitGoals: hits,
    streakMilestones: milestones,
  );

  test(
    'readiness handles recovery bands, sleep deficit and missing inputs',
    () {
      expect(
        engine.readiness(context(recovery: 33))?.body,
        contains('Recover'),
      );
      expect(
        engine.readiness(context(recovery: 34))?.body,
        contains('Maintain'),
      );
      expect(engine.readiness(context(recovery: 67))?.body, contains('Push'));
      expect(
        engine.readiness(context(recovery: 90, sleep: 400))?.body,
        contains('Maintain'),
      );
      expect(engine.readiness(context()), isNull);
      expect(
        engine.readiness(context(recovery: 80, sleep: 400, sleepGoal: null)),
        isNull,
      );
    },
  );

  test('fresh muscles match a saved workout template after 48 hours', () {
    final today = CoachWorkout(date: now, muscles: {'Chest'});
    final ready = context(
      sessions: [
        today,
        CoachWorkout(
          date: now.subtract(const Duration(hours: 48)),
          muscles: {'Back'},
        ),
      ],
      templates: const [
        CoachTemplate(name: 'Pull Day', muscles: {'Back'}),
      ],
    );
    expect(engine.muscleFreshness(ready)?.action, 'Pull Day');
    expect(
      engine.muscleFreshness(
        context(
          sessions: [
            CoachWorkout(
              date: now.subtract(const Duration(hours: 47)),
              muscles: {'Back'},
            ),
          ],
          templates: const [
            CoachTemplate(name: 'Pull Day', muscles: {'Back'}),
          ],
        ),
      ),
      isNull,
    );
    expect(engine.muscleFreshness(context()), isNull);
  });

  test('sleep debt compares recent average with goal', () {
    expect(
      engine.sleepDebt(context(sleepDays: [420, 420, 420]))?.body,
      contains('7.0 h'),
    );
    expect(engine.sleepDebt(context(sleepDays: [480, 480, 480])), isNull);
    expect(engine.sleepDebt(context()), isNull);
    expect(engine.sleepDebt(context(sleepDays: [420, 420])), isNull);
  });

  test(
    'protein and calories only prompt after 5 PM and avoid missing data',
    () {
      expect(engine.nutritionGap(context(protein: 83))?.body, contains('37 g'));
      expect(engine.nutritionGap(context(protein: 84)), isNull);
      expect(
        engine.nutritionGap(
          context(protein: 20, time: DateTime(2026, 10, 10, 16)),
        ),
        isNull,
      );
      expect(
        engine
            .nutritionGap(
              context(
                protein: null,
                proteinGoal: null,
                calories: 1400,
                calorieGoal: 2000,
              ),
            )
            ?.body,
        contains('600 kcal'),
      );
      expect(
        engine.nutritionGap(context(protein: null, proteinGoal: null)),
        isNull,
      );
    },
  );

  test('weekly consistency reports the exact remaining count', () {
    expect(
      engine.weeklyConsistency(context())?.body,
      contains('1 more workout'),
    );
    expect(engine.weeklyConsistency(context(workouts: 3)), isNull);
    expect(engine.weeklyConsistency(context(workouts: null)), isNull);
  });

  test(
    'plateau needs three sessions without improved estimated 1RM or volume',
    () {
      final plateauSessions = [
        for (var day = 0; day < 3; day++)
          CoachWorkout(
            date: now.subtract(Duration(days: day)),
            exerciseHistory: const [
              CoachExerciseHistory(
                exercise: 'Bench Press',
                estimatedOneRepMax: 100,
                volume: 2400,
              ),
            ],
          ),
      ];
      expect(engine.plateau(context(sessions: plateauSessions)), isNotNull);
      final progressing = [
        CoachWorkout(
          date: now,
          exerciseHistory: const [
            CoachExerciseHistory(
              exercise: 'Bench Press',
              estimatedOneRepMax: 101,
              volume: 2400,
            ),
          ],
        ),
        ...plateauSessions.skip(1),
      ];
      expect(engine.plateau(context(sessions: progressing)), isNull);
      expect(engine.plateau(context()), isNull);
    },
  );

  test('overreaching requires strain above 14 on three of five days', () {
    final highStrain = [
      for (var day = 0; day < 5; day++)
        CoachDayScore(
          date: now.subtract(Duration(days: day)),
          strain: day < 3 ? 14.1 : 14,
        ),
    ];
    expect(engine.overreaching(context(days: highStrain)), isNotNull);
    expect(
      engine.overreaching(
        context(
          days: [
            for (final day in highStrain)
              CoachDayScore(date: day.date, strain: 14),
          ],
        ),
      ),
      isNull,
    );
  });

  test('goal pace compares logged weight with scheduled target path', () {
    final weights = [
      CoachBodyWeight(
        date: now.subtract(const Duration(days: 10)),
        kilograms: 80,
      ),
      CoachBodyWeight(date: now, kilograms: 78),
    ];
    expect(
      engine
          .goalPace(
            context(
              weights: weights,
              targetWeight: 70,
              targetDate: now.add(const Duration(days: 40)),
            ),
          )
          ?.body,
      contains('on pace'),
    );
    expect(
      engine.goalPace(context(weights: weights, targetWeight: 70)),
      isNull,
    );
  });

  test('positive reinforcement surfaces PR, milestone and goal hits', () {
    final result = engine.positiveReinforcement(
      context(
        sessions: [
          CoachWorkout(date: now, personalRecords: const ['Deadlift']),
        ],
        streakDays: 7,
        milestones: const {7},
        hits: const ['steps'],
      ),
    );
    expect(
      result.map((item) => item.id),
      containsAll(['pr-deadlift', 'streak-7', 'goal-hit-steps']),
    );
    expect(engine.positiveReinforcement(context()), isEmpty);
  });

  test('safety flags persistent elevated resting HR and low HRV calmly', () {
    final days = [
      for (var day = 0; day < 3; day++)
        CoachDayScore(
          date: now.subtract(Duration(days: day)),
          restingHeartRate: 72,
        ),
      for (var day = 3; day < 14; day++)
        CoachDayScore(
          date: now.subtract(Duration(days: day)),
          restingHeartRate: 60,
        ),
    ];
    final hrWarning = engine.safety(context(days: days));
    expect(hrWarning?.body, contains('If you feel unwell, talk to a doctor.'));
    expect(hrWarning?.body, contains('12 bpm'));
    expect(
      engine
          .safety(
            context(days: [CoachDayScore(date: now, hrv: 20, hrvBaseline: 50)]),
          )
          ?.body,
      contains('60% below baseline'),
    );
    expect(engine.safety(context()), isNull);
  });

  test(
    'generation limits categories, prioritizes higher value and expires daily',
    () {
      final insights = engine.generate(
        context(
          recovery: 20,
          days: [
            CoachDayScore(date: now, strain: 15),
            CoachDayScore(
              date: now.subtract(const Duration(days: 1)),
              strain: 15,
            ),
            CoachDayScore(
              date: now.subtract(const Duration(days: 2)),
              strain: 15,
            ),
          ],
        ),
      );
      expect(
        insights.map((item) => item.category).toSet().length,
        insights.length,
      );
      expect(insights.first.priority, 5);
      expect(insights.first.expiresAt, DateTime(2026, 10, 11));
      expect(insights.every((item) => item.body.length <= 140), isTrue);
    },
  );

  test('deduplication excludes insights shown in the last 24 hours', () {
    final insight = engine.generate(
      context(recovery: 20),
    ).firstWhere((item) => item.id == 'readiness');
    expect(
      engine.withoutRecentlyShown(
        [insight],
        {insight.id: now.subtract(const Duration(hours: 23))},
        now: now,
      ),
      isEmpty,
    );
    expect(
      engine.withoutRecentlyShown(
        [insight],
        {insight.id: now.subtract(const Duration(hours: 24))},
        now: now,
      ),
      hasLength(1),
    );
  });
}
