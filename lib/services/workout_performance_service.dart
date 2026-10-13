class WorkoutPerformanceService {
  const WorkoutPerformanceService._();

  static double estimatedOneRepMax(double weightKg, int reps) {
    if (weightKg <= 0 || reps <= 0) return 0;
    return weightKg * (1 + reps / 30);
  }

  static bool isPersonalRecord({
    required double weightKg,
    required int reps,
    required double previousBest,
  }) =>
      estimatedOneRepMax(weightKg, reps) > previousBest;
}

class WorkoutRestTimer {
  const WorkoutRestTimer({required this.endsAt});

  final DateTime endsAt;

  int remainingAt(DateTime now) {
    final seconds = endsAt.difference(now).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  WorkoutRestTimer adjust(Duration amount, DateTime now) {
    final remaining = remainingAt(now) + amount.inSeconds;
    return WorkoutRestTimer(
      endsAt: now.add(Duration(seconds: remaining < 0 ? 0 : remaining)),
    );
  }
}
