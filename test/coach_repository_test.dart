import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:forge/features/coach/services/coach_repository.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('forge_coach_test_');
    Hive.init(directory.path);
    for (final name in [
      'coachShownInsights',
      'coachDismissedInsights',
      'coachHabitLogs',
      'coachWeeklyReviews',
      'settings',
    ]) {
      await Hive.openBox<dynamic>(name);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('shown ids and dismissals persist with their timestamps', () async {
    final repository = CoachRepository();
    final now = DateTime(2026, 10, 10, 12);

    await repository.markShown('readiness', now);
    await repository.dismiss('sleep-debt', now);

    expect(repository.shownTimestamps()['readiness'], now);
    expect(repository.wasDismissed('sleep-debt', now), isTrue);
    expect(
      repository.wasDismissed('sleep-debt', now.add(const Duration(days: 7))),
      isFalse,
    );
  });

  test('habit completion increments a streak only once per day', () async {
    final repository = CoachRepository();
    final yesterday = DateTime(2026, 10, 9, 12);
    final today = DateTime(2026, 10, 10, 12);
    await repository.setHabit('stretch', yesterday);
    await repository.setHabit('stretch', today);
    await repository.setHabit('stretch', today);

    expect(repository.habit('stretch', today).streak, 2);
    expect(repository.habit('stretch', today).completed, isTrue);
  });

  test(
    'water is added in 250 ml steps and weekly reviews are retrievable',
    () async {
      final repository = CoachRepository();
      final now = DateTime(2026, 10, 10, 12);
      await repository.setHabit('water', now);
      await repository.setHabit('water', now, waterDelta: 250);
      await repository.saveWeeklyReview('2026-10-05', {
        'workouts': 3,
        'prs': 1,
      });

      expect(repository.habit('water', now).waterMillilitres, 500);
      expect(repository.weeklyReviews().single.key, '2026-10-05');
    },
  );
}
