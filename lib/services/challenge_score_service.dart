import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/workout_session.dart';
import 'auth_service.dart';
import 'health_service.dart';
import 'challenge_service.dart';

class ChallengeScore {
  const ChallengeScore({required this.score, required this.perDay});

  final double score;
  final Map<String, double> perDay;
}

class ChallengeScoreService with WidgetsBindingObserver {
  ChallengeScoreService._();

  static final ChallengeScoreService instance = ChallengeScoreService._();
  static const _minimumInterval = Duration(minutes: 2);

  final HealthService _health = HealthService();
  DateTime? _lastAttempt;
  bool _running = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    Hive.box<WorkoutSession>('workoutSessions')
        .listenable()
        .addListener(_onLocalDataChanged);
    Hive.box<dynamic>('settings')
        .listenable(keys: const ['healthLastSyncedAt'])
        .addListener(_onLocalDataChanged);
    _lastAttempt = _dateTime(
      Hive.box<dynamic>('settings').get('challengeScoreLastAttemptAt'),
    );
    unawaited(recomputeAndUpload());
  }

  void _onLocalDataChanged() => unawaited(recomputeAndUpload());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(recomputeAndUpload());
  }

  Future<void> recomputeAndUpload({
    bool manual = false,
    String? onlyChallengeId,
  }) async {
    if (_running) return;
    final now = DateTime.now();
    if (!manual &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < _minimumInterval) {
      return;
    }
    _running = true;
    _lastAttempt = now;
    try {
      await Hive.box<dynamic>('settings')
          .put('challengeScoreLastAttemptAt', now);
      final uid = AuthService().currentUid;
      if (uid == null) return;
      final List<FitnessChallenge> challenges;
      if (onlyChallengeId == null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('challenges')
            .where('memberUids', arrayContains: uid)
            .get();
        challenges = snapshot.docs.map(FitnessChallenge.fromDocument).toList();
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('challenges')
            .doc(onlyChallengeId)
            .get();
        challenges = snapshot.exists
            ? [FitnessChallenge.fromDocument(snapshot)]
            : const <FitnessChallenge>[];
      }

      final sessions = Hive.box<WorkoutSession>('workoutSessions').values
          .toList();
      for (final challenge in challenges) {
        if (!challenge.isActiveAt(now) || !challenge.memberUids.contains(uid)) {
          continue;
        }
        final start = challenge.startDate.toLocal();
        final end = challenge.endDate.toLocal();
        Map<DateTime, int> steps = const {};
        if (challenge.metric == ChallengeMetric.steps) {
          final days = end.difference(start).inDays.clamp(1, 60);
          final daily = await _health.fetchRecentDailyShareData(days);
          steps = {
            for (final entry in daily.entries)
              DateTime(entry.key.year, entry.key.month, entry.key.day):
                  entry.value.steps ?? 0,
          };
        }
        final score = calculate(
          challenge: challenge,
          sessions: sessions,
          stepsByDay: steps,
        );
        final username =
            challenge.memberNames[uid] ??
            (await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get())
                    .data()?['username']
                as String? ??
            'friend';
        await FirebaseFirestore.instance
            .collection('challenges')
            .doc(challenge.id)
            .collection('scores')
            .doc(uid)
            .set({
              'score': score.score,
              'perDay': score.perDay,
              'username': username,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (error, stackTrace) {
      debugPrint('Challenge score sync failed: $error\n$stackTrace');
    } finally {
      _running = false;
    }
  }

  static ChallengeScore calculate({
    required FitnessChallenge challenge,
    required Iterable<WorkoutSession> sessions,
    Map<DateTime, int> stepsByDay = const {},
  }) {
    final start = _day(challenge.startDate.toLocal());
    final end = _day(challenge.endDate.toLocal());
    final perDay = <String, double>{};
    for (
      var day = start;
      day.isBefore(end);
      day = day.add(const Duration(days: 1))
    ) {
      final key = ChallengeService.dayId(day);
      switch (challenge.metric) {
        case ChallengeMetric.workouts:
          perDay[key] = sessions
              .where((session) => _day(session.date).isAtSameMomentAs(day))
              .length
              .toDouble();
        case ChallengeMetric.volume:
          perDay[key] = sessions
              .where((session) => _day(session.date).isAtSameMomentAs(day))
              .fold<double>(0, (total, session) => total + session.totalVolume);
        case ChallengeMetric.activeDays:
          perDay[key] =
              sessions.any(
                (session) => _day(session.date).isAtSameMomentAs(day),
              )
              ? 1
              : 0;
        case ChallengeMetric.steps:
          perDay[key] = (stepsByDay[_day(day)] ?? 0).toDouble();
      }
    }
    return ChallengeScore(
      score: perDay.values.fold<double>(0, (total, value) => total + value),
      perDay: Map.unmodifiable(perDay),
    );
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? _dateTime(Object? value) => value is DateTime
      ? value
      : value is String
      ? DateTime.tryParse(value)
      : null;
}
