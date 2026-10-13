class ProgressSetRecord {
  const ProgressSetRecord({
    required this.weight,
    required this.reps,
    this.isWarmUp = false,
  });

  final double? weight;
  final int reps;
  final bool isWarmUp;
}

class ProgressExerciseRecord {
  const ProgressExerciseRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;
  final List<ProgressSetRecord> sets;
}

class ProgressWorkoutRecord {
  const ProgressWorkoutRecord({required this.date, required this.exercises});

  final DateTime date;
  final List<ProgressExerciseRecord> exercises;
}

enum ProgressMetric { estimatedOneRepMax, topSet, volume, bestReps }

class ExerciseProgressSession {
  const ExerciseProgressSession({
    required this.date,
    required this.sets,
    required this.isBodyweight,
    required this.topSetWeight,
    required this.estimatedOneRepMax,
    required this.totalVolume,
    required this.totalReps,
    required this.bestReps,
  });

  final DateTime date;
  final List<ProgressSetRecord> sets;
  final bool isBodyweight;
  final double? topSetWeight;
  final double? estimatedOneRepMax;
  final double? totalVolume;
  final int totalReps;
  final int? bestReps;

  double? valueFor(ProgressMetric metric) {
    if (isBodyweight) {
      return metric == ProgressMetric.bestReps ? bestReps?.toDouble() : null;
    }

    return switch (metric) {
      ProgressMetric.estimatedOneRepMax => estimatedOneRepMax,
      ProgressMetric.topSet => topSetWeight,
      ProgressMetric.volume => totalVolume,
      ProgressMetric.bestReps => bestReps?.toDouble(),
    };
  }
}

enum ProgressPrType { heaviestWeight, estimatedOneRepMax, repsAtWeight }

class ProgressPr {
  const ProgressPr({
    required this.type,
    required this.value,
    required this.date,
    this.weight,
  });

  final ProgressPrType type;
  final double value;
  final DateTime date;
  final double? weight;
}

class ExerciseProgressHistory {
  const ExerciseProgressHistory({
    required this.exerciseId,
    required this.exerciseName,
    required this.sessions,
    required this.personalRecords,
    required this.isBodyweight,
  });

  final String exerciseId;
  final String exerciseName;
  final List<ExerciseProgressSession> sessions;
  final List<ProgressPr> personalRecords;
  final bool isBodyweight;
}

enum ProgressionType { increaseWeight, addReps, deload }

class ProgressionTarget {
  const ProgressionTarget({required this.weight, required this.reps});

  final double weight;
  final int reps;
}

class ProgressionSuggestion {
  const ProgressionSuggestion({required this.type, required this.targets});

  final ProgressionType type;
  final List<ProgressionTarget> targets;

  ProgressionTarget? get summaryTarget => targets.isEmpty ? null : targets.first;
}

class ProgressionRules {
  const ProgressionRules._();

  static const double weightStepKg = 1.25;

  static ProgressionSuggestion? suggest({
    required ExerciseProgressHistory history,
    required int targetRepMin,
    required int targetRepMax,
  }) {
    if (history.sessions.isEmpty || targetRepMin <= 0 || targetRepMax < targetRepMin) {
      return null;
    }

    final latest = history.sessions.last;
    final latestWorkingSets = _workingSets(latest.sets);
    if (latestWorkingSets.isEmpty) {
      return null;
    }

    final missedBottomTwice = history.sessions.length >= 2 &&
        _missedBottom(history.sessions[history.sessions.length - 2], targetRepMin) &&
        _missedBottom(latest, targetRepMin);

    if (missedBottomTwice) {
      return ProgressionSuggestion(
        type: ProgressionType.deload,
        targets: latestWorkingSets
            .map(
              (set) => ProgressionTarget(
                weight: roundWeightToStep(set.weight! * 0.925),
                reps: targetRepMin,
              ),
            )
            .toList(growable: false),
      );
    }

    final hitTopOnAllSets = latestWorkingSets.every(
      (set) => set.reps >= targetRepMax,
    );
    if (hitTopOnAllSets) {
      final increment = _isBigLowerBodyCompound(history.exerciseName) ? 5.0 : 2.5;
      return ProgressionSuggestion(
        type: ProgressionType.increaseWeight,
        targets: latestWorkingSets
            .map(
              (set) => ProgressionTarget(
                weight: roundWeightToStep(set.weight! + increment),
                reps: targetRepMin,
              ),
            )
            .toList(growable: false),
      );
    }

    return ProgressionSuggestion(
      type: ProgressionType.addReps,
      targets: latestWorkingSets
          .map(
            (set) => ProgressionTarget(
              weight: roundWeightToStep(set.weight!),
              reps: set.reps < targetRepMax ? set.reps + 1 : set.reps,
            ),
          )
          .toList(growable: false),
    );
  }

  static double roundWeightToStep(double weight) =>
      (weight / weightStepKg).round() * weightStepKg;

  static List<ProgressSetRecord> _workingSets(
    List<ProgressSetRecord> sets,
  ) => sets
      .where((set) => !set.isWarmUp && set.reps > 0 && set.weight != null)
      .toList(growable: false);

  static bool _missedBottom(ExerciseProgressSession session, int targetRepMin) {
    final sets = _workingSets(session.sets);
    return sets.isNotEmpty && sets.any((set) => set.reps < targetRepMin);
  }

  static bool _isBigLowerBodyCompound(String name) {
    final normalized = name.toLowerCase();
    return normalized.contains('squat') ||
        normalized.contains('deadlift') ||
        normalized.contains('leg press');
  }
}

class ProgressService {
  const ProgressService._();

  static double estimateOneRepMax(double weight, int reps) {
    if (reps <= 0 || reps > 12 || weight <= 0) {
      return 0;
    }
    if (reps == 1) {
      return weight;
    }
    return weight * (1 + reps / 30);
  }

  static ExerciseProgressHistory calculateHistory({
    required String exerciseId,
    required Iterable<ProgressWorkoutRecord> workouts,
  }) {
    final sessions = <ExerciseProgressSession>[];
    var exerciseName = exerciseId;

    for (final workout in workouts) {
      final matchingExercises = workout.exercises
          .where((exercise) => exercise.exerciseId == exerciseId)
          .toList(growable: false);
      if (matchingExercises.isEmpty) {
        continue;
      }

      exerciseName = matchingExercises.last.exerciseName;
      final sets = matchingExercises.expand((exercise) => exercise.sets).toList();
      final workingSets = sets
          .where((set) => !set.isWarmUp && set.reps > 0)
          .toList(growable: false);
      if (workingSets.isEmpty) {
        continue;
      }

      final isBodyweight = workingSets.every(
        (set) => set.weight == null || set.weight! <= 0,
      );
      final loadedSets = workingSets
          .where((set) => set.weight != null && set.weight! > 0)
          .toList(growable: false);
      final topSetWeight = loadedSets.isEmpty
          ? null
          : loadedSets.map((set) => set.weight!).reduce(_maxDouble);
      final oneRepMaxes = loadedSets
          .where((set) => set.reps <= 12)
          .map((set) => estimateOneRepMax(set.weight!, set.reps))
          .toList(growable: false);
      final estimatedOneRepMax = oneRepMaxes.isEmpty
          ? null
          : oneRepMaxes.reduce(_maxDouble);

      sessions.add(
        ExerciseProgressSession(
          date: workout.date,
          sets: List.unmodifiable(sets),
          isBodyweight: isBodyweight,
          topSetWeight: topSetWeight,
          estimatedOneRepMax: estimatedOneRepMax,
          totalVolume: isBodyweight
              ? null
              : workingSets.fold<double>(
                  0,
                  (total, set) => total + (set.weight ?? 0) * set.reps,
                ),
          totalReps: workingSets.fold<int>(0, (total, set) => total + set.reps),
          bestReps: workingSets.map((set) => set.reps).reduce(_maxInt),
        ),
      );
    }

    sessions.sort((a, b) => a.date.compareTo(b.date));
    final isBodyweight = sessions.isNotEmpty && sessions.every((session) => session.isBodyweight);

    return ExerciseProgressHistory(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      sessions: List.unmodifiable(sessions),
      personalRecords: _personalRecords(sessions),
      isBodyweight: isBodyweight,
    );
  }

  static List<ProgressPr> _personalRecords(
    List<ExerciseProgressSession> sessions,
  ) {
    final records = <ProgressPr>[];
    final loadedSessions = sessions.where((session) => !session.isBodyweight);
    ExerciseProgressSession? heaviestSession;
    ExerciseProgressSession? oneRepMaxSession;
    for (final session in loadedSessions) {
      if (session.topSetWeight != null &&
          (heaviestSession == null ||
              session.topSetWeight! > heaviestSession.topSetWeight!)) {
        heaviestSession = session;
      }
      if (session.estimatedOneRepMax != null &&
          (oneRepMaxSession == null ||
              session.estimatedOneRepMax! > oneRepMaxSession.estimatedOneRepMax!)) {
        oneRepMaxSession = session;
      }
    }
    if (heaviestSession != null) {
      records.add(
        ProgressPr(
          type: ProgressPrType.heaviestWeight,
          value: heaviestSession.topSetWeight!,
          date: heaviestSession.date,
        ),
      );
    }
    if (oneRepMaxSession != null) {
      records.add(
        ProgressPr(
          type: ProgressPrType.estimatedOneRepMax,
          value: oneRepMaxSession.estimatedOneRepMax!,
          date: oneRepMaxSession.date,
        ),
      );
    }

    final bestRepsAtWeight = <double, ProgressPr>{};
    for (final session in sessions) {
      for (final set in _workingSets(session.sets)) {
        final weight = set.weight ?? 0;
        final current = bestRepsAtWeight[weight];
        if (current == null || set.reps > current.value) {
          bestRepsAtWeight[weight] = ProgressPr(
            type: ProgressPrType.repsAtWeight,
            value: set.reps.toDouble(),
            weight: weight,
            date: session.date,
          );
        }
      }
    }
    records.addAll(bestRepsAtWeight.values);
    records.sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(records);
  }

  static List<ProgressSetRecord> _workingSets(
    List<ProgressSetRecord> sets,
  ) => sets
      .where((set) => !set.isWarmUp && set.reps > 0)
      .toList(growable: false);

  static double _maxDouble(double first, double second) =>
      first > second ? first : second;

  static int _maxInt(int first, int second) => first > second ? first : second;
}