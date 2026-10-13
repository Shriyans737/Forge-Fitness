import '../coach_copy.dart';

enum CoachCategory {
  training,
  recovery,
  sleep,
  nutrition,
  progress,
  habit,
}

enum CoachTone { positive, neutral, caution }

enum ReadinessVerdict { push, maintain, recover }

class CoachInsight {
  const CoachInsight({
    required this.id,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    required this.tone,
    required this.expiresAt,
    this.action,
  });

  final String id;
  final CoachCategory category;
  final int priority;
  final String title;
  final String body;
  final String? action;
  final CoachTone tone;
  final DateTime expiresAt;
}

class CoachDayScore {
  const CoachDayScore({
    required this.date,
    this.recovery,
    this.strain,
    this.sleepMinutes,
    this.restingHeartRate,
    this.hrv,
    this.hrvBaseline,
  });

  final DateTime date;
  final double? recovery;
  final double? strain;
  final double? sleepMinutes;
  final double? restingHeartRate;
  final double? hrv;
  final double? hrvBaseline;
}

class CoachExerciseHistory {
  const CoachExerciseHistory({
    required this.exercise,
    required this.estimatedOneRepMax,
    required this.volume,
  });

  final String exercise;
  final double estimatedOneRepMax;
  final double volume;
}

class CoachWorkout {
  const CoachWorkout({
    required this.date,
    this.muscles = const {},
    this.volume = 0,
    this.exerciseHistory = const [],
    this.personalRecords = const [],
  });

  final DateTime date;
  final Set<String> muscles;
  final double volume;
  final List<CoachExerciseHistory> exerciseHistory;
  final List<String> personalRecords;
}

class CoachTemplate {
  const CoachTemplate({required this.name, required this.muscles});

  final String name;
  final Set<String> muscles;
}

class CoachBodyWeight {
  const CoachBodyWeight({required this.date, required this.kilograms});

  final DateTime date;
  final double kilograms;
}

class CoachContext {
  const CoachContext({
    required this.now,
    this.recovery,
    this.strain,
    this.sleepMinutes,
    this.sleepGoalMinutes,
    this.steps,
    this.stepsGoal,
    this.proteinGrams,
    this.proteinGoalGrams,
    this.calories,
    this.calorieGoal,
    this.workoutsPerWeekGoal,
    this.weeklyWorkoutCount,
    this.todayScores,
    this.last14Days = const [],
    this.workouts = const [],
    this.templates = const [],
    this.last7DaysSleepMinutes = const [],
    this.bodyWeights = const [],
    this.targetWeightKg,
    this.targetWeightDate,
    this.proteinGoalHitDays,
    this.stepsAverage7Days,
    this.bedtimeMinutes,
    this.trainingStreakDays = 0,
    this.hitGoals = const [],
    this.streakMilestones = const {},
  });

  final DateTime now;
  final double? recovery;
  final double? strain;
  final double? sleepMinutes;
  final double? sleepGoalMinutes;
  final int? steps;
  final int? stepsGoal;
  final double? proteinGrams;
  final double? proteinGoalGrams;
  final double? calories;
  final double? calorieGoal;
  final int? workoutsPerWeekGoal;
  final int? weeklyWorkoutCount;
  final CoachDayScore? todayScores;
  final List<CoachDayScore> last14Days;
  final List<CoachWorkout> workouts;
  final List<CoachTemplate> templates;
  final List<double> last7DaysSleepMinutes;
  final List<CoachBodyWeight> bodyWeights;
  final double? targetWeightKg;
  final DateTime? targetWeightDate;
  final int? proteinGoalHitDays;
  final int? stepsAverage7Days;
  final int? bedtimeMinutes;
  final int trainingStreakDays;
  final List<String> hitGoals;
  final Set<int> streakMilestones;
}

class CoachEngine {
  const CoachEngine();

  List<CoachInsight> generate(CoachContext context) {
    final insights = <CoachInsight>[
      ?readiness(context),
      ?muscleFreshness(context),
      ?sleepDebt(context),
      ?nutritionGap(context),
      ?weeklyConsistency(context),
      ?plateau(context),
      ?overreaching(context),
      ?goalPace(context),
      ...positiveReinforcement(context),
      ?safety(context),
    ];
    final byCategory = <CoachCategory, CoachInsight>{};
    for (final insight in insights) {
      final previous = byCategory[insight.category];
      if (previous == null || insight.priority > previous.priority) {
        byCategory[insight.category] = insight;
      }
    }
    return byCategory.values.toList()
      ..sort((a, b) {
        final priorityOrder = b.priority.compareTo(a.priority);
        return priorityOrder != 0
            ? priorityOrder
            : a.category.index.compareTo(b.category.index);
      });
  }

  List<CoachInsight> withoutRecentlyShown(
    Iterable<CoachInsight> insights,
    Map<String, DateTime> shownAt, {
    required DateTime now,
    Duration repeatAfter = const Duration(hours: 24),
  }) {
    return insights
        .where((item) {
          final shown = shownAt[item.id];
          return shown == null ||
              now.difference(shown) >= repeatAfter ||
              now.isBefore(shown);
        })
        .toList(growable: false);
  }

  CoachInsight? readiness(CoachContext context) {
    final score = context.recovery;
    final sleep = context.sleepMinutes;
    final sleepGoal = context.sleepGoalMinutes;
    if (score == null || (sleep != null && sleepGoal == null)) return null;
    final verdict = score < 34
        ? ReadinessVerdict.recover
        : score < 67
        ? ReadinessVerdict.maintain
        : sleep != null && sleepGoal != null && sleep < sleepGoal
        ? ReadinessVerdict.maintain
        : ReadinessVerdict.push;
    final shortSleep =
        sleep != null && sleepGoal != null && sleep < sleepGoal;
    final detail = shortSleep
        ? CoachCopy.sleepDetail(_hours(sleep), _hours(sleepGoal))
        : CoachCopy.recoveryScoreDetail('${score.round()}');
    final recommendation = switch (verdict) {
      ReadinessVerdict.push => CoachCopy.push,
      ReadinessVerdict.maintain => CoachCopy.maintain,
      ReadinessVerdict.recover => CoachCopy.recover,
    };
    return _insight(
      context,
      'readiness',
      CoachCategory.recovery,
      verdict == ReadinessVerdict.recover ? 5 : 4,
      CoachCopy.readinessTitle,
      CoachCopy.readiness(_variant(context), recommendation, detail),
      verdict == ReadinessVerdict.recover
          ? CoachTone.caution
          : CoachTone.neutral,
      action: verdict == ReadinessVerdict.recover
          ? CoachCopy.takeRecoveryDay
          : null,
    );
  }

  CoachInsight? muscleFreshness(CoachContext context) {
    if (context.workouts.isEmpty || context.templates.isEmpty) return null;
    final candidates = <String>{};
    for (final muscle in context.workouts.expand((item) => item.muscles)) {
      final lastTrained = context.workouts
          .where((workout) => workout.muscles.contains(muscle))
          .map((workout) => workout.date)
          .fold<DateTime?>(null, (latest, date) {
            if (latest == null || date.isAfter(latest)) return date;
            return latest;
          });
      if (lastTrained != null &&
          context.now.difference(lastTrained) >= const Duration(hours: 48)) {
        candidates.add(muscle);
      }
    }
    if (candidates.isEmpty) return null;
    var best = context.templates.first;
    var overlap = -1;
    for (final template in context.templates) {
      final count = template.muscles.intersection(candidates).length;
      if (count > overlap) {
        best = template;
        overlap = count;
      }
    }
    if (overlap <= 0) return null;
    final readyMuscle = best.muscles.intersection(candidates).first;
    return _insight(
      context,
      'freshness-${_slug(readyMuscle)}',
      CoachCategory.training,
      3,
      CoachCopy.freshMuscleTitle,
      CoachCopy.muscleFreshness(_variant(context), readyMuscle, best.name),
      CoachTone.positive,
      action: best.name,
    );
  }

  CoachInsight? sleepDebt(CoachContext context) {
    final goal = context.sleepGoalMinutes;
    final nights = context.last7DaysSleepMinutes.take(3).toList();
    if (goal == null || goal <= 0 || nights.length < 3) return null;
    final average = nights.reduce((a, b) => a + b) / nights.length;
    if (average >= goal) return null;
    return _insight(
      context,
      'sleep-debt',
      CoachCategory.sleep,
      3,
      CoachCopy.sleepCheckInTitle,
      CoachCopy.sleepDebt(
        _variant(context),
        _hours(average),
        _hours(goal),
      ),
      CoachTone.neutral,
      action: CoachCopy.setWindDown,
    );
  }

  CoachInsight? nutritionGap(CoachContext context) {
    if (context.now.hour < 17) return null;
    final protein = context.proteinGrams;
    final proteinGoal = context.proteinGoalGrams;
    if (protein != null && proteinGoal != null && proteinGoal > 0) {
      final missing = proteinGoal - protein;
      if (protein < proteinGoal * 0.7 && missing > 0) {
        return _insight(
          context,
          'protein-gap',
          CoachCategory.nutrition,
          3,
          CoachCopy.proteinNudgeTitle,
          CoachCopy.proteinGap(_variant(context), missing.round().toString()),
          CoachTone.neutral,
          action: CoachCopy.logFood,
        );
      }
    }
    final calories = context.calories;
    final calorieGoal = context.calorieGoal;
    if (calories == null || calorieGoal == null || calorieGoal <= 0) return null;
    final gap = calorieGoal - calories;
    if (gap <= 0) return null;
    return _insight(
      context,
      'calorie-gap',
      CoachCategory.nutrition,
      2,
      CoachCopy.nutritionCheckInTitle,
      CoachCopy.calorieGap(_variant(context), gap.round().toString()),
      CoachTone.neutral,
      action: CoachCopy.logFood,
    );
  }

  CoachInsight? weeklyConsistency(CoachContext context) {
    final goal = context.workoutsPerWeekGoal;
    final count = context.weeklyWorkoutCount;
    if (goal == null || count == null || goal <= count) return null;
    final remaining = goal - count;
    return _insight(
      context,
      'weekly-consistency',
      CoachCategory.habit,
      3,
      CoachCopy.weeklyRhythmTitle,
      CoachCopy.weeklyConsistency(_variant(context), remaining),
      CoachTone.neutral,
      action: CoachCopy.startWorkout,
    );
  }

  CoachInsight? plateau(CoachContext context) {
    final performances = <String, List<CoachExerciseHistory>>{};
    final workouts = context.workouts.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final workout in workouts) {
      for (final record in workout.exerciseHistory) {
        performances.putIfAbsent(record.exercise, () => []).add(record);
      }
    }
    for (final entry in performances.entries) {
      final recent = entry.value.take(3).toList();
      if (recent.length < 3) continue;
      final noBetterOneRm = !_improved(recent.map((item) => item.estimatedOneRepMax));
      final noBetterVolume = !_improved(recent.map((item) => item.volume));
      if (noBetterOneRm && noBetterVolume) {
        return _insight(
          context,
          'plateau-${_slug(entry.key)}',
          CoachCategory.training,
          2,
          CoachCopy.plateauTitle,
          CoachCopy.plateau(_variant(context), entry.key),
          CoachTone.neutral,
          action: CoachCopy.reviewWorkout,
        );
      }
    }
    return null;
  }

  CoachInsight? overreaching(CoachContext context) {
    final recent = context.last14Days
        .where(
          (day) =>
              !day.date.isAfter(context.now) &&
              context.now.difference(day.date) < const Duration(days: 5),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentFive = recent.take(5);
    final count = recentFive.where((day) => (day.strain ?? 0) > 14).length;
    if (count < 3) return null;
    return _insight(
      context,
      'high-strain',
      CoachCategory.recovery,
      4,
      CoachCopy.recoveryRoomTitle,
      CoachCopy.overreaching(_variant(context), count),
      CoachTone.caution,
      action: CoachCopy.planDeload,
    );
  }

  CoachInsight? goalPace(CoachContext context) {
    final target = context.targetWeightKg;
    final targetDate = context.targetWeightDate;
    final weights = context.bodyWeights.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (target == null || targetDate == null || weights.length < 2) return null;
    final current = weights.last.kilograms;
    final start = weights.first;
    final span = targetDate.difference(start.date).inDays;
    if (span <= 0 || context.now.isBefore(start.date)) return null;
    final elapsed = context.now.difference(start.date).inDays.clamp(0, span);
    final expected = start.kilograms +
        (target - start.kilograms) * elapsed / span;
    final delta = current - expected;
    final status = delta.abs() <= 0.5
        ? 'on pace for'
        : (target < start.kilograms
              ? delta < 0
                    ? 'ahead of'
                    : 'behind'
              : delta > 0
              ? 'ahead of'
              : 'behind');
    return _insight(
      context,
      'goal-pace',
      CoachCategory.progress,
      2,
      CoachCopy.weightPaceTitle,
      CoachCopy.goalPace(_variant(context), status, delta.abs().toStringAsFixed(1)),
      delta.abs() <= 0.5 ? CoachTone.positive : CoachTone.neutral,
    );
  }

  List<CoachInsight> positiveReinforcement(CoachContext context) {
    final insights = <CoachInsight>[];
    final prs = context.workouts
        .where(
          (workout) =>
              workout.date.year == context.now.year &&
              workout.date.month == context.now.month &&
              workout.date.day == context.now.day,
        )
        .expand((workout) => workout.personalRecords);
    if (prs.isNotEmpty) {
      final exercise = prs.first;
      insights.add(
        _insight(
          context,
          'pr-${_slug(exercise)}',
          CoachCategory.progress,
          5,
          CoachCopy.personalBestTitle,
          CoachCopy.personalRecord(_variant(context), exercise),
          CoachTone.positive,
        ),
      );
    }
    if (context.trainingStreakDays >= 7 &&
        context.streakMilestones.contains(context.trainingStreakDays)) {
      insights.add(
        _insight(
          context,
          'streak-${context.trainingStreakDays}',
          CoachCategory.habit,
          4,
          CoachCopy.consistencyMilestoneTitle,
          CoachCopy.streak(_variant(context), context.trainingStreakDays),
          CoachTone.positive,
        ),
      );
    }
    if (context.hitGoals.isNotEmpty) {
      final goal = context.hitGoals.first;
      insights.add(
        _insight(
          context,
          'goal-hit-${_slug(goal)}',
          CoachCategory.habit,
          4,
          CoachCopy.goalReachedTitle,
          CoachCopy.goalHit(goal),
          CoachTone.positive,
        ),
      );
    }
    return insights;
  }

  CoachInsight? safety(CoachContext context) {
    final scores = context.last14Days.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = scores.where(
      (day) =>
          !day.date.isAfter(context.now) &&
          context.now.difference(day.date) < const Duration(days: 3),
    );
    final heartRates = recent
        .where((day) => day.restingHeartRate != null)
        .toList(growable: false);
    final baselineRates = scores
        .where(
          (day) =>
              context.now.difference(day.date) >= const Duration(days: 3) &&
              context.now.difference(day.date) <= const Duration(days: 14),
        )
        .map((day) => day.restingHeartRate)
        .whereType<double>()
        .toList();
    if (heartRates.length >= 3 && baselineRates.isNotEmpty) {
      final baseline = baselineRates.reduce((a, b) => a + b) / baselineRates.length;
      if (heartRates.every((day) => day.restingHeartRate! >= baseline + 10)) {
        final current = heartRates.first.restingHeartRate!;
        return _safetyInsight(
          context,
          CoachCopy.restingHeartRateLabel,
          CoachCopy.replace(CoachCopy.bpmAboveBaseline, {
            'bpm': '${(current - baseline).round()}',
          }),
        );
      }
    }
    final latest = scores.firstOrNull;
    if (latest?.hrv != null && latest?.hrvBaseline != null) {
      final baseline = latest!.hrvBaseline!;
      final hrv = latest.hrv!;
      if (baseline > 0 && hrv <= baseline * 0.7) {
        final percent = ((baseline - hrv) / baseline * 100).round();
        return _safetyInsight(
          context,
          CoachCopy.hrvLabel,
          CoachCopy.replace(CoachCopy.percentBelowBaseline, {
            'percent': '$percent',
          }),
        );
      }
    }
    return null;
  }

  CoachInsight _safetyInsight(CoachContext context, String metric, String value) =>
      _insight(
        context,
        'safety-${_slug(metric)}',
        CoachCategory.recovery,
        5,
        CoachCopy.gentleCheckInTitle,
        CoachCopy.safety(_variant(context), metric, value),
        CoachTone.caution,
        action: CoachCopy.takeRecoveryDay,
      );

  static CoachInsight _insight(
    CoachContext context,
    String id,
    CoachCategory category,
    int priority,
    String title,
    String body,
    CoachTone tone, {
    String? action,
  }) => CoachInsight(
    id: id,
    category: category,
    priority: priority.clamp(1, 5),
    title: title,
    body: body.length > 140 ? '${body.substring(0, 137)}...' : body,
    tone: tone,
    action: action,
    expiresAt: DateTime(context.now.year, context.now.month, context.now.day + 1),
  );

  static String _variant(CoachContext context) {
    final day = context.now.year * 10000 + context.now.month * 100 + context.now.day;
    return switch (day % 3) {
      0 => 'a',
      1 => 'b',
      _ => 'c',
    };
  }

  static String _hours(double minutes) => (minutes / 60).toStringAsFixed(1);

  static String _slug(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  static bool _improved(Iterable<double> values) {
    final ordered = values.toList().reversed.toList();
    for (var index = 1; index < ordered.length; index++) {
      if (ordered[index] > ordered[index - 1]) return true;
    }
    return false;
  }
}
