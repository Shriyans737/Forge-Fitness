import 'package:flutter_test/flutter_test.dart';
import 'package:forge/models/workout_session.dart';
import 'package:forge/services/challenge_score_service.dart';
import 'package:forge/services/challenge_service.dart';

void main() {
  final challenge = FitnessChallenge(
    id: 'challenge',
    name: 'Date range test',
    metric: ChallengeMetric.workouts,
    startDate: DateTime(2026, 1, 2),
    endDate: DateTime(2026, 1, 4),
    creatorUid: 'me',
    memberUids: const ['me'],
    memberNames: const {'me': 'tester'},
    status: 'active',
  );

  final sessions = [
    _workout('before', DateTime(2026, 1, 1, 23, 59), 10),
    _workout('inside-a', DateTime(2026, 1, 2, 12), 20),
    _workout('inside-b', DateTime(2026, 1, 3, 10), 30),
    _workout('after', DateTime(2026, 1, 4), 40),
  ];

  group('ChallengeScoreService.calculate', () {
    test('counts only workouts inside the challenge date range', () {
      final score = ChallengeScoreService.calculate(
        challenge: challenge,
        sessions: sessions,
      );

      expect(score.score, 2);
      expect(score.perDay, {'2026-01-02': 1, '2026-01-03': 1});
    });

    test('sums volume only inside the challenge date range', () {
      final score = ChallengeScoreService.calculate(
        challenge: _withMetric(ChallengeMetric.volume),
        sessions: sessions,
      );

      expect(score.score, 50);
      expect(score.perDay, {'2026-01-02': 20, '2026-01-03': 30});
    });

    test('counts each active day only once in the challenge range', () {
      final score = ChallengeScoreService.calculate(
        challenge: _withMetric(ChallengeMetric.activeDays),
        sessions: [
          ...sessions,
          _workout('inside-c', DateTime(2026, 1, 2, 20), 5),
        ],
      );

      expect(score.score, 2);
      expect(score.perDay, {'2026-01-02': 1, '2026-01-03': 1});
    });

    test('sums steps only for days inside the challenge range', () {
      final score = ChallengeScoreService.calculate(
        challenge: _withMetric(ChallengeMetric.steps),
        sessions: sessions,
        stepsByDay: {
          DateTime(2026, 1, 1): 9000,
          DateTime(2026, 1, 2): 5000,
          DateTime(2026, 1, 3): 6000,
          DateTime(2026, 1, 4): 7000,
        },
      );

      expect(score.score, 11000);
      expect(score.perDay, {'2026-01-02': 5000, '2026-01-03': 6000});
    });
  });

  group('ChallengeService.rankScores', () {
    test('sorts descending and shares ranks for ties', () {
      final ranked = ChallengeService.rankScores([
        _entry('low', 'low', 4),
        _entry('first', 'first', 9),
        _entry('tied', 'tied', 9),
        _entry('middle', 'middle', 6),
      ]);

      expect(ranked.map((item) => item.uid), [
        'first',
        'tied',
        'middle',
        'low',
      ]);
      expect(ranked.map((item) => item.rank), [1, 1, 3, 4]);
    });
  });
}

FitnessChallenge _withMetric(ChallengeMetric metric) => FitnessChallenge(
  id: 'challenge',
  name: 'Date range test',
  metric: metric,
  startDate: DateTime(2026, 1, 2),
  endDate: DateTime(2026, 1, 4),
  creatorUid: 'me',
  memberUids: const ['me'],
  memberNames: const {'me': 'tester'},
  status: 'active',
);

WorkoutSession _workout(String id, DateTime date, double volume) =>
    WorkoutSession(
      id: id,
      date: date,
      name: id,
      exercises: [
        LoggedExercise(
          exerciseId: 'exercise',
          exerciseName: 'Exercise',
          sets: [ExerciseSet(weight: volume, reps: 1)],
        ),
      ],
    );

ChallengeScoreEntry _entry(String uid, String username, double score) =>
    ChallengeScoreEntry(
      uid: uid,
      username: username,
      score: score,
      perDay: const {},
    );
