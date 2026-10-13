import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../dashboard/dashboard_controller.dart';
import '../../dashboard/services/score_calculator.dart';
import '../../../models/exercise.dart';
import '../../../models/food_log_model.dart';
import '../../../models/workout_session.dart';
import 'coach_engine.dart';

class CoachContextProvider extends ChangeNotifier {
  CoachContextProvider(this._dashboard) {
    _dashboard.addListener(_dashboardChanged);
    _settings.addListener(_settingsChanged);
    _context = buildContext(_dashboard.snapshot, now: DateTime.now());
  }

  final DashboardController _dashboard;
  final _settings = Hive.box<dynamic>('settings').listenable(
    keys: const [
      'workoutsPerWeekGoal',
      'stepsGoal',
      'targetWeightKg',
      'targetWeightDate',
      'coachBedtimeMinutes',
    ],
  );
  late CoachContext _context;

  CoachContext get context => _context;

  void _dashboardChanged() {
    _context = buildContext(_dashboard.snapshot, now: DateTime.now());
    notifyListeners();
  }

  void _settingsChanged() => _dashboardChanged();

  @override
  void dispose() {
    _dashboard.removeListener(_dashboardChanged);
    _settings.removeListener(_settingsChanged);
    super.dispose();
  }

  static CoachContext buildContext(
    DashboardSnapshot snapshot, {
    required DateTime now,
  }) {
    final settings = Hive.box<dynamic>('settings');
    final exercises = Hive.box<Exercise>('exercises');
    final sessions = snapshot.sessions;
    final scoresByDay = <String, ScoreSnapshot>{
      for (final score in snapshot.scoreHistory) _dayKey(score.date): score,
    };
    final rawScores = settings.get('dailyScores');
    if (rawScores is Map) {
      for (final entry in rawScores.entries) {
        final score = ScoreSnapshot.fromMap(entry.value);
        if (score != null) scoresByDay[_dayKey(score.date)] = score;
      }
    }
    if (snapshot.scores case final current?) {
      scoresByDay[_dayKey(current.date)] = current;
    }
    final scores = scoresByDay.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final scoreDays = <CoachDayScore>[
      for (final score in scores)
        CoachDayScore(
          date: score.date,
          recovery: score.recoveryScore,
          strain: score.hasStrainData ? score.strainScore : null,
          sleepMinutes: score.asleepMinutes,
          restingHeartRate: score.restingHeartRate,
          hrv: score.hrv,
          hrvBaseline: score.hrvBaseline,
        ),
    ];
    final workouts = <CoachWorkout>[
      for (final session in sessions)
        CoachWorkout(
          date: session.date,
          muscles: _musclesForSession(session, exercises),
          volume: session.totalVolume,
          exerciseHistory: [
            for (final logged in session.exercises)
              CoachExerciseHistory(
                exercise: logged.exerciseName,
                estimatedOneRepMax: _estimatedOneRepMax(logged),
                volume: logged.sets.fold<double>(
                  0,
                  (sum, set) => sum + set.weight * set.reps,
                ),
              ),
          ],
          personalRecords: [
            for (final pr in snapshot.prs)
              if (pr.date.year == session.date.year &&
                  pr.date.month == session.date.month &&
                  pr.date.day == session.date.day)
                pr.exerciseName,
          ],
        ),
    ];
    final templates = <CoachTemplate>[
      for (final template in snapshot.templates)
        CoachTemplate(
          name: template.name,
          muscles: {
            for (final id in template.exerciseIds)
              ..._musclesForExercise(exercises.get(id)),
          },
        ),
    ];
    final sleepMinutes = scoreDays
        .where((score) => !score.date.isAfter(now))
        .where((score) => score.sleepMinutes != null)
        .take(7)
        .map((score) => score.sleepMinutes!)
        .toList(growable: false);
    final todayHasFood = Hive.box<FoodLog>('foodLogs').values
        .any((entry) => _sameDay(entry.loggedAt, now));
    final rawTargetWeight = settings.get('targetWeightKg');
    final targetWeight = rawTargetWeight is num && rawTargetWeight > 0
        ? rawTargetWeight.toDouble()
        : null;
    final rawTargetDate = settings.get('targetWeightDate');
    final targetDate = switch (rawTargetDate) {
      DateTime date => date,
      String date => DateTime.tryParse(date),
      int date => DateTime.fromMillisecondsSinceEpoch(date),
      _ => null,
    };
    final weeklyGoal = _positiveInt(settings.get('workoutsPerWeekGoal'));
    final stepsGoal = _positiveInt(settings.get('stepsGoal')) ?? 10000;
    final proteinGoal = snapshot.proteinGoal > 0 ? snapshot.proteinGoal : null;
    final caloriesGoal = snapshot.calorieGoal > 0 ? snapshot.calorieGoal : null;
    final latestWeights = snapshot.bodyLogs
        .where((log) => log.weightKg != null)
        .map((log) => CoachBodyWeight(date: log.date, kilograms: log.weightKg!))
        .toList(growable: false);
    final todaysHits = <String>[
      if (snapshot.healthSummary?.steps case final int steps?
          when steps >= stepsGoal)
        'steps',
      if (proteinGoal != null &&
          todayHasFood &&
          snapshot.protein >= proteinGoal)
        'protein',
      if (caloriesGoal != null &&
          todayHasFood &&
          snapshot.calories >= caloriesGoal)
        'calories',
      if (snapshot.weeklyWorkoutCount > 0 &&
          sessions.any((session) => _sameDay(session.date, now)))
        'workout',
    ];
    final proteinGoalHitDays = proteinGoal == null
        ? null
        : _proteinGoalHitDays(now, proteinGoal);
    return CoachContext(
      now: now,
      recovery: snapshot.scores?.recoveryScore,
      strain: snapshot.scores?.hasStrainData == true
          ? snapshot.scores?.strainScore
          : null,
      sleepMinutes: snapshot.healthSummary?.sleepAsleepMinutes,
      sleepGoalMinutes:
          _positiveNumber(settings.get('sleepGoalMinutes')) ?? 480,
      steps: snapshot.healthSummary?.steps,
      stepsGoal: stepsGoal,
      proteinGrams: todayHasFood ? snapshot.protein : null,
      proteinGoalGrams: proteinGoal,
      calories: todayHasFood ? snapshot.calories : null,
      calorieGoal: caloriesGoal,
      workoutsPerWeekGoal: weeklyGoal,
      weeklyWorkoutCount: snapshot.weeklyWorkoutCount,
      todayScores: scoreDays.isEmpty ? null : scoreDays.first,
      last14Days: scoreDays
          .where(
            (score) =>
                !score.date.isAfter(now) &&
                now.difference(score.date).inDays < 14,
          )
          .toList(growable: false),
      workouts: workouts,
      templates: templates,
      last7DaysSleepMinutes: sleepMinutes,
      bodyWeights: latestWeights,
      targetWeightKg: targetWeight,
      targetWeightDate: targetDate,
      proteinGoalHitDays: proteinGoalHitDays,
      stepsAverage7Days: null,
      bedtimeMinutes: _minuteOfDay(settings.get('coachBedtimeMinutes')),
      trainingStreakDays: _trainingStreak(sessions, now),
      hitGoals: todaysHits,
      streakMilestones: const {7, 14, 30, 60, 100},
    );
  }

  static Set<String> _musclesForSession(
    WorkoutSession session,
    Box<Exercise> exercises,
  ) => {
    for (final logged in session.exercises)
      ..._musclesForExercise(exercises.get(logged.exerciseId)),
  };

  static Set<String> _musclesForExercise(Exercise? exercise) {
    if (exercise == null) return const {};
    final muscles = {
      ...exercise.primaryMuscles,
      ...exercise.secondaryMuscles,
    }.where((muscle) => muscle.trim().isNotEmpty).toSet();
    if (muscles.isEmpty && exercise.muscleGroup.trim().isNotEmpty) {
      muscles.add(exercise.muscleGroup);
    }
    return muscles;
  }

  static double _estimatedOneRepMax(LoggedExercise exercise) {
    var best = 0.0;
    for (final set in exercise.sets) {
      if (set.isWarmUp || set.weight <= 0 || set.reps <= 0) continue;
      final estimate = set.weight * (1 + set.reps / 30);
      if (estimate > best) best = estimate;
    }
    return best;
  }

  static DateTime _dateAtMidnight(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _sameDay(DateTime first, DateTime second) =>
      _dateAtMidnight(first) == _dateAtMidnight(second);

  static int _trainingStreak(List<WorkoutSession> sessions, DateTime now) {
    final days = sessions
        .map((session) => _dateAtMidnight(session.date))
        .toSet();
    var day = _dateAtMidnight(now);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static double? _positiveNumber(Object? value) =>
      value is num && value > 0 ? value.toDouble() : null;

  static int? _positiveInt(Object? value) =>
      value is num && value > 0 ? value.toInt() : null;

  static int? _minuteOfDay(Object? value) =>
      value is num && value >= 0 && value < 1440 ? value.toInt() : null;

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static int? _proteinGoalHitDays(DateTime now, double goal) {
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final dailyTotals = <DateTime, double>{};
    for (final item in Hive.box<FoodLog>('foodLogs').values) {
      if (item.loggedAt.isBefore(start) ||
          item.loggedAt.isAfter(now) ||
          item.proteinGramsPerServing == null) {
        continue;
      }
      final date = _dateAtMidnight(item.loggedAt);
      dailyTotals.update(
        date,
        (value) => value + item.proteinGramsPerServing! * item.quantity,
        ifAbsent: () => item.proteinGramsPerServing! * item.quantity,
      );
    }
    return dailyTotals.values.where((value) => value >= goal).length;
  }
}
