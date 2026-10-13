import 'package:flutter_test/flutter_test.dart';
import 'package:forge/services/workout_performance_service.dart';

void main() {
  group('WorkoutPerformanceService', () {
    test('calculates Epley estimated one rep max', () {
      expect(WorkoutPerformanceService.estimatedOneRepMax(60, 8), 76);
      expect(WorkoutPerformanceService.estimatedOneRepMax(0, 8), 0);
    });

    test('flags a set only when estimated one rep max improves', () {
      expect(
        WorkoutPerformanceService.isPersonalRecord(
          weightKg: 60,
          reps: 8,
          previousBest: 75,
        ),
        isTrue,
      );
      expect(
        WorkoutPerformanceService.isPersonalRecord(
          weightKg: 60,
          reps: 8,
          previousBest: 76,
        ),
        isFalse,
      );
    });
  });

  group('WorkoutRestTimer', () {
    test('remaining time derives from deadline after backgrounding', () {
      final startedAt = DateTime(2026, 10, 10, 12);
      final timer = WorkoutRestTimer(
        endsAt: startedAt.add(const Duration(seconds: 120)),
      );

      expect(timer.remainingAt(startedAt.add(const Duration(seconds: 47))), 73);
      expect(timer.remainingAt(startedAt.add(const Duration(seconds: 121))), 0);
    });

    test('adjusts the persisted end timestamp', () {
      final now = DateTime(2026, 10, 10, 12);
      final timer = WorkoutRestTimer(
        endsAt: now.add(const Duration(seconds: 60)),
      ).adjust(const Duration(seconds: 15), now);

      expect(timer.remainingAt(now), 75);
    });
  });
}
