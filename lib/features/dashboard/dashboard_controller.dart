import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/perf_diagnostics.dart';
import '../../models/active_workout_draft.dart';
import '../../models/body_log_model.dart';
import '../../models/exercise.dart';
import '../../models/food_log_model.dart';
import '../../models/workout_session.dart';
import '../../models/workout_template.dart';
import '../../services/health_service.dart';
import '../../services/progress_repository.dart';
import '../../services/progress_service.dart';
import '../../services/workout_stats_service.dart';
import 'services/score_calculator.dart';

typedef RequestHealthPermissions = Future<bool> Function();
typedef FetchHealthSummary = Future<HealthSummary?> Function();

class DashboardPr {
  const DashboardPr({
    required this.exerciseName,
    required this.estimatedOneRepMax,
    required this.date,
  });

  final String exerciseName;
  final double estimatedOneRepMax;
  final DateTime date;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    this.isLoading = true,
    this.localError,
    this.healthLoading = true,
    this.healthError,
    this.healthSummary,
    this.hasHealthPermissions = false,
    this.displayName = '',
    this.lastHealthSync,
    this.activeDraft,
    this.hasActiveWorkout = false,
    this.sessions = const [],
    this.templates = const [],
    this.bodyLogs = const [],
    this.todayVolume = 0,
    this.todayReps = 0,
    this.todaySets = 0,
    this.todayMuscles = const {},
    this.weeklyVolumes = const [0, 0, 0, 0, 0, 0, 0],
    this.weeklyWorkoutCount = 0,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.carbsGoal = 250,
    this.fatGoal = 70,
    this.prs = const [],
    this.scores,
    this.scoreHistory = const [],
  });

  final bool isLoading;
  final String? localError;
  final bool healthLoading;
  final String? healthError;
  final HealthSummary? healthSummary;
  final bool hasHealthPermissions;
  final String displayName;
  final DateTime? lastHealthSync;
  final ActiveWorkoutDraft? activeDraft;
  final bool hasActiveWorkout;
  final List<WorkoutSession> sessions;
  final List<WorkoutTemplate> templates;
  final List<BodyLog> bodyLogs;
  final double todayVolume;
  final int todayReps;
  final int todaySets;
  final Set<String> todayMuscles;
  final List<double> weeklyVolumes;
  final int weeklyWorkoutCount;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double calorieGoal;
  final double proteinGoal;
  final double carbsGoal;
  final double fatGoal;
  final List<DashboardPr> prs;
  final ScoreSnapshot? scores;
  final List<ScoreSnapshot> scoreHistory;

  List<WorkoutSession> get recentWorkouts => sessions.take(3).toList();

  List<double> get recentWeights => bodyLogs
      .where((entry) => entry.weightKg != null)
      .toList()
      .reversed
      .map((entry) => entry.weightKg!)
      .toList(growable: false);

  BodyLog? get latestBodyLog =>
      bodyLogs.isEmpty ? null : bodyLogs.first;

  DashboardSnapshot copyWith({
    bool? isLoading,
    String? localError,
    bool clearLocalError = false,
    bool? healthLoading,
    String? healthError,
    bool clearHealthError = false,
    HealthSummary? healthSummary,
    bool? hasHealthPermissions,
    String? displayName,
    DateTime? lastHealthSync,
    ActiveWorkoutDraft? activeDraft,
    bool clearActiveDraft = false,
    bool? hasActiveWorkout,
    List<WorkoutSession>? sessions,
    List<WorkoutTemplate>? templates,
    List<BodyLog>? bodyLogs,
    double? todayVolume,
    int? todayReps,
    int? todaySets,
    Set<String>? todayMuscles,
    List<double>? weeklyVolumes,
    int? weeklyWorkoutCount,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? calorieGoal,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    List<DashboardPr>? prs,
    ScoreSnapshot? scores,
    List<ScoreSnapshot>? scoreHistory,
  }) =>
      DashboardSnapshot(
        isLoading: isLoading ?? this.isLoading,
        localError: clearLocalError ? null : localError ?? this.localError,
        healthLoading: healthLoading ?? this.healthLoading,
        healthError: clearHealthError ? null : healthError ?? this.healthError,
        healthSummary: healthSummary ?? this.healthSummary,
        hasHealthPermissions:
            hasHealthPermissions ?? this.hasHealthPermissions,
        displayName: displayName ?? this.displayName,
        lastHealthSync: lastHealthSync ?? this.lastHealthSync,
        activeDraft:
            clearActiveDraft ? null : activeDraft ?? this.activeDraft,
        hasActiveWorkout: hasActiveWorkout ?? this.hasActiveWorkout,
        sessions: sessions ?? this.sessions,
        templates: templates ?? this.templates,
        bodyLogs: bodyLogs ?? this.bodyLogs,
        todayVolume: todayVolume ?? this.todayVolume,
        todayReps: todayReps ?? this.todayReps,
        todaySets: todaySets ?? this.todaySets,
        todayMuscles: todayMuscles ?? this.todayMuscles,
        weeklyVolumes: weeklyVolumes ?? this.weeklyVolumes,
        weeklyWorkoutCount: weeklyWorkoutCount ?? this.weeklyWorkoutCount,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        calorieGoal: calorieGoal ?? this.calorieGoal,
        proteinGoal: proteinGoal ?? this.proteinGoal,
        carbsGoal: carbsGoal ?? this.carbsGoal,
        fatGoal: fatGoal ?? this.fatGoal,
        prs: prs ?? this.prs,
        scores: scores ?? this.scores,
        scoreHistory: scoreHistory ?? this.scoreHistory,
      );
}

class DashboardController extends ChangeNotifier {
  DashboardController({
    DashboardSnapshot? initialSnapshot,
    this.loadHive = true,
    RequestHealthPermissions? requestHealthPermissions,
    FetchHealthSummary? fetchHealthSummary,
  }) : _snapshot = initialSnapshot ?? const DashboardSnapshot(),
       _requestHealthPermissions =
           requestHealthPermissions ?? HealthService().requestPermissions,
       _fetchHealthSummary =
           fetchHealthSummary ?? HealthService().fetchTodaySummary {
    if (loadHive) {
      _bindHive();
      _readHive();
      unawaited(refreshHealth());
      unawaited(_loadPersonalRecords());
    }
  }

  final bool loadHive;
  final RequestHealthPermissions _requestHealthPermissions;
  final FetchHealthSummary _fetchHealthSummary;
  final List<Listenable> _hiveListenables = [];
  DashboardSnapshot _snapshot;
  bool _disposed = false;
  bool _healthSyncInFlight = false;

  DashboardSnapshot get snapshot => _snapshot;

  void _bindHive() {
    final listenables = <Listenable>[
      Hive.box<WorkoutSession>('workoutSessions').listenable(),
      Hive.box<dynamic>('activeWorkout').listenable(),
      Hive.box<WorkoutTemplate>('workoutTemplates').listenable(),
      Hive.box<Exercise>('exercises').listenable(),
      Hive.box<FoodLog>('foodLogs').listenable(),
      Hive.box<BodyLog>('bodyLogs').listenable(),
      Hive.box<dynamic>('settings').listenable(
        keys: const [
          'displayName',
          'healthLastSyncedAt',
          'nutritionGoalCalories',
          'nutritionGoalProtein',
          'nutritionGoalCarbs',
          'nutritionGoalFat',
          'sleepGoalMinutes',
          'age',
          'maxHeartRate',
          'workoutsPerWeekGoal',
          'stepsGoal',
          'targetWeightKg',
          'targetWeightDate',
          'coachBedtimeMinutes',
          'coachNudgesEnabled',
          'coachNudgeeveningProtein',
          'coachNudgemissedWorkout',
          'coachNudgebedtimeWindDown',
          'coachNudgeweeklyReview',
          'coachNudgestreakAtRisk',
          'coachQuietStartMinutes',
          'coachQuietEndMinutes',
        ],
      ),
    ];
    for (final listenable in listenables) {
      listenable.addListener(_onHiveChanged);
      _hiveListenables.add(listenable);
    }
  }

  void _onHiveChanged() {
    _readHive();
    unawaited(_loadPersonalRecords());
  }

  Future<bool> refresh() async {
    if (!loadHive) {
      return refreshHealth();
    }
    _readHive();
    final synced = await refreshHealth();
    await _loadPersonalRecords();
    return synced;
  }

  Future<bool> refreshHealth() async {
    if (_healthSyncInFlight) return false;
    _healthSyncInFlight = true;
    final fetchClock = Stopwatch()..start();
    PerfDiagnostics.log(
      'Dashboard health fetch started',
      splashWindowOnly: true,
    );
    _update(_snapshot.copyWith(healthLoading: true, clearHealthError: true));
    try {
      PerfDiagnostics.log(
        'Dashboard health permission request started',
        splashWindowOnly: true,
      );
      final permitted = await _requestHealthPermissions();
      PerfDiagnostics.log(
        'Dashboard health permission request finished: $permitted',
        splashWindowOnly: true,
      );
      if (!permitted) {
        _update(
          _snapshot.copyWith(
            healthLoading: false,
            hasHealthPermissions: false,
            healthError:
                'Health access could not be confirmed. Check permissions and try again.',
          ),
        );
        return false;
      }
      PerfDiagnostics.log(
        'Dashboard health summary fetch started',
        splashWindowOnly: true,
      );
      final summary = await _fetchHealthSummary();
      PerfDiagnostics.log(
        'Dashboard health summary fetch finished: '
        'steps=${summary?.steps ?? 'unavailable'} '
        'activeKcal=${summary?.activeCaloriesBurned ?? 'unavailable'}',
        splashWindowOnly: true,
      );
      final syncedAt = DateTime.now();
      if (loadHive && summary?.hasPermissions == true) {
        await Hive.box<dynamic>('settings').put(
          'healthLastSyncedAt',
          syncedAt,
        );
      }
      _update(
        _snapshot.copyWith(
          healthLoading: false,
          hasHealthPermissions: summary?.hasPermissions ?? false,
          healthSummary: summary,
          healthError: summary?.errorMessage,
          lastHealthSync:
              summary?.hasPermissions == true ? syncedAt : _snapshot.lastHealthSync,
        ),
      );
      if (loadHive) _readHive();
      if (kDebugMode) {
        debugPrint(
          'Dashboard health values reaching widgets: '
          'steps=${summary?.steps ?? 'unavailable'}/10000 '
          'activeCalories=${summary?.activeCaloriesBurned ?? 'unavailable'}/500 '
          'heartRate=${summary?.latestHeartRate ?? 'unavailable'} '
          'sleepMinutes=${summary?.sleepAsleepMinutes ?? 'unavailable'}',
        );
      }
      return summary?.hasPermissions == true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Dashboard health refresh failed: $error\n$stackTrace');
      }
      _update(
        _snapshot.copyWith(
          healthLoading: false,
          hasHealthPermissions: false,
          healthError: 'Health data could not be loaded.',
        ),
      );
      return false;
    } finally {
      _healthSyncInFlight = false;
      PerfDiagnostics.log(
        'Dashboard health fetch finished after '
        '${fetchClock.elapsedMilliseconds}ms',
        splashWindowOnly: true,
      );
    }
  }

  Future<void> refreshHealthIfDue() async {
    final lastSyncedAt = _snapshot.lastHealthSync;
    if (_healthSyncInFlight ||
        (lastSyncedAt != null &&
            DateTime.now().difference(lastSyncedAt) <
                const Duration(minutes: 1))) {
      return;
    }
    await refreshHealth();
  }

  void _readHive() {
    final readClock = Stopwatch()..start();
    PerfDiagnostics.log('Dashboard local Hive load started', splashWindowOnly: true);
    try {
      final now = DateTime.now();
      final sessions = Hive.box<WorkoutSession>('workoutSessions').values
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final exercisesBox = Hive.box<Exercise>('exercises');
      final startOfToday = DateTime(now.year, now.month, now.day);
      final weekStart = startOfToday.subtract(
        Duration(days: startOfToday.weekday - DateTime.monday),
      );
      final weeklyVolumes = List<double>.filled(7, 0);
      var weeklyWorkoutCount = 0;
      var todayVolume = 0.0;
      var todayReps = 0;
      var todaySets = 0;
      final todayMuscles = <String>{};

      for (final session in sessions) {
        final localDate = session.date.toLocal();
        final dayStart = DateTime(localDate.year, localDate.month, localDate.day);
        if (!dayStart.isBefore(weekStart) &&
            !dayStart.isAfter(weekStart.add(const Duration(days: 6)))) {
          weeklyVolumes[dayStart.weekday - DateTime.monday] +=
              session.totalVolume;
          weeklyWorkoutCount++;
        }
        if (dayStart != startOfToday) {
          continue;
        }
        todayVolume += session.totalVolume;
        for (final loggedExercise in session.exercises) {
          todaySets += loggedExercise.sets.length;
          todayReps += loggedExercise.sets.fold<int>(
            0,
            (sum, set) => sum + set.reps,
          );
          final exercise = exercisesBox.get(loggedExercise.exerciseId);
          if (exercise != null) {
            todayMuscles
              ..addAll(_nonEmpty(exercise.primaryMuscles))
              ..addAll(_nonEmpty(exercise.secondaryMuscles));
          }
        }
      }

      final loggedWorkoutVolume = todayVolume;
      final loggedWorkoutSets = todaySets;
      final activeWorkoutBox = Hive.box<dynamic>('activeWorkout');
      final rawDraft = activeWorkoutBox.get('activeWorkout');
      final hasActiveWorkout = activeWorkoutBox.containsKey('activeWorkout');
      ActiveWorkoutDraft? activeDraft;
      if (rawDraft is Map) {
        try {
          activeDraft = ActiveWorkoutDraft.fromMap(rawDraft);
          final stats = WorkoutStatsService.calculate(
            exercises: activeDraft.exercises,
            completedSets: activeDraft.completedSets,
            exerciseForId: exercisesBox.get,
          );
          todayVolume += stats.volume;
          todayReps += stats.reps;
          todaySets += stats.sets;
          todayMuscles.addAll(stats.plannedMuscles);
        } catch (error, stackTrace) {
          debugPrint('Dashboard active workout draft is malformed: $error\n$stackTrace');
        }
      }
      weeklyVolumes[now.weekday - DateTime.monday] = todayVolume;

      final foodEntries = Hive.box<FoodLog>('foodLogs').values.where(
        (entry) => _sameDay(entry.loggedAt, now),
      );
      final calories = _sumFood(foodEntries, (entry) => entry.caloriesPerServing);
      final protein = _sumFood(foodEntries, (entry) => entry.proteinGramsPerServing);
      final carbs = _sumFood(foodEntries, (entry) => entry.carbsGramsPerServing);
      final fat = _sumFood(foodEntries, (entry) => entry.fatGramsPerServing);
      final settings = Hive.box<dynamic>('settings');
      final displayName = settings.get('displayName');
      final lastHealthSyncValue = settings.get('healthLastSyncedAt');
      final lastHealthSync = switch (lastHealthSyncValue) {
        DateTime value => value,
        int value => DateTime.fromMillisecondsSinceEpoch(value),
        _ => null,
      };
      final bodyLogs = Hive.box<BodyLog>('bodyLogs').values
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      final thirtyDayLogs = bodyLogs
          .where(
            (entry) => !entry.date.isBefore(
              now.subtract(const Duration(days: 30)),
            ),
          )
          .toList(growable: false);
      final templates = Hive.box<WorkoutTemplate>('workoutTemplates').values
          .toList()
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      final nutrition = (
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
      final scoreData = _calculateAndCacheScores(
        settings: settings,
        healthSummary: _snapshot.healthSummary,
        today: now,
        todayVolume: loggedWorkoutVolume,
        todaySets: loggedWorkoutSets,
      );

      _update(
        _snapshot.copyWith(
          isLoading: false,
          clearLocalError: true,
          activeDraft: activeDraft,
          clearActiveDraft: activeDraft == null,
          hasActiveWorkout: hasActiveWorkout,
          displayName: displayName is String ? displayName.trim() : '',
          lastHealthSync: lastHealthSync,
          sessions: sessions,
          templates: templates,
          bodyLogs: thirtyDayLogs,
          todayVolume: todayVolume,
          todayReps: todayReps,
          todaySets: todaySets,
          todayMuscles: todayMuscles,
          weeklyVolumes: weeklyVolumes,
          weeklyWorkoutCount: weeklyWorkoutCount,
          calories: nutrition.calories,
          protein: nutrition.protein,
          carbs: nutrition.carbs,
          fat: nutrition.fat,
          calorieGoal: _readGoal(settings, 'nutritionGoalCalories', 2000),
          proteinGoal: _readGoal(settings, 'nutritionGoalProtein', 150),
          carbsGoal: _readGoal(settings, 'nutritionGoalCarbs', 250),
          fatGoal: _readGoal(settings, 'nutritionGoalFat', 70),
          scores: scoreData.today,
          scoreHistory: scoreData.history,
        ),
      );

      if (kDebugMode) {
        final weekAverage =
            weeklyVolumes.fold<double>(0, (sum, value) => sum + value) /
            weeklyVolumes.length;
        debugPrint(
          'Dashboard live values: volume=$todayVolume reps=$todayReps sets=$todaySets '
          'foodCalories=${nutrition.calories}/${_readGoal(settings, 'nutritionGoalCalories', 2000)} '
          'healthActiveCalories=${_snapshot.healthSummary?.activeCaloriesBurned ?? 'unavailable'} '
          'steps=${_snapshot.healthSummary?.steps ?? 'unavailable'}/10000 '
          'muscles=${todayMuscles.length}',
        );
        debugPrint(
          'Dashboard ring inputs: volume=$todayVolume/$weekAverage '
          'activeCalories=${_snapshot.healthSummary?.activeCaloriesBurned ?? 'unavailable'}/500 '
          'steps=${_snapshot.healthSummary?.steps ?? 'unavailable'}/10000',
        );
      }
      PerfDiagnostics.log(
        'Dashboard local Hive load finished after ${readClock.elapsedMilliseconds}ms',
        splashWindowOnly: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Dashboard local data refresh failed: $error\n$stackTrace');
      _update(
        _snapshot.copyWith(
          isLoading: false,
          localError: 'Dashboard data could not be loaded.',
        ),
      );
      PerfDiagnostics.log(
        'Dashboard local Hive load failed after '
        '${readClock.elapsedMilliseconds}ms: $error',
        splashWindowOnly: true,
      );
    }
  }

  ({ScoreSnapshot? today, List<ScoreSnapshot> history})
  _calculateAndCacheScores({
    required Box<dynamic> settings,
    required HealthSummary? healthSummary,
    required DateTime today,
    required double todayVolume,
    required int todaySets,
  }) {
    final dayKey = ScoreCalculator.dayKey(today);
    final vitalsMap = _stringKeyedMap(settings.get('scoreVitalsHistory'));
    final todayVitals = _stringKeyedMap(vitalsMap[dayKey]);
    if (healthSummary?.heartRateVariability != null ||
        healthSummary?.restingHeartRate != null) {
      vitalsMap[dayKey] = {
        'date': dayKey,
        'hrv': healthSummary?.heartRateVariability ?? todayVitals['hrv'],
        'restingHeartRate':
            healthSummary?.restingHeartRate ?? todayVitals['restingHeartRate'],
      };
      _putMapIfChanged(settings, 'scoreVitalsHistory', vitalsMap);
    }

    final scoreCache = _stringKeyedMap(settings.get('dailyScores'));
    if (healthSummary != null) {
      final vitalsHistory = <DailyVitals>[];
      for (final entry in vitalsMap.entries) {
        final date = DateTime.tryParse(entry.key);
        final values = _stringKeyedMap(entry.value);
        if (date == null) continue;
        vitalsHistory.add(
          DailyVitals(
            date: date,
            hrv: _positiveNumber(values['hrv']),
            restingHeartRate: _positiveNumber(values['restingHeartRate']),
          ),
        );
      }
      final age = _readGoal(settings, 'age', 0);
      final maxHeartRateOverride = _readGoal(settings, 'maxHeartRate', 0);
      final calculated = ScoreCalculator.calculate(
        ScoreInput(
          date: today,
          asleepMinutes: healthSummary.sleepAsleepMinutes,
          inBedMinutes: healthSummary.sleepInBedMinutes,
          deepMinutes: healthSummary.sleepDeepMinutes,
          remMinutes: healthSummary.sleepRemMinutes,
          lightMinutes: healthSummary.sleepLightMinutes,
          awakeMinutes: healthSummary.sleepAwakeMinutes,
          sleepGoalMinutes: _readGoal(settings, 'sleepGoalMinutes', 480),
          hrv: healthSummary.heartRateVariability,
          restingHeartRate: healthSummary.restingHeartRate,
          vitalsHistory: vitalsHistory,
          heartRateSamples: healthSummary.heartRateSamples,
          activeCalories: healthSummary.activeCaloriesBurned ?? 0,
          workoutVolume: todayVolume,
          workoutSets: todaySets,
          maxHeartRate: maxHeartRateOverride > 0
              ? maxHeartRateOverride.round()
              : age > 0
              ? 220 - age.round()
              : null,
        ),
      );
      final previous = ScoreSnapshot.fromMap(scoreCache[dayKey]);
      scoreCache[dayKey] = (previous == null
              ? calculated
              : _mergeAvailableScores(previous, calculated))
          .toMap();
      final oldest = today.subtract(const Duration(days: 29));
      scoreCache.removeWhere((key, _) {
        final date = DateTime.tryParse(key);
        return date == null || date.isBefore(oldest);
      });
      _putMapIfChanged(settings, 'dailyScores', scoreCache);
    }

    final allHistory = scoreCache.values
        .map(ScoreSnapshot.fromMap)
        .whereType<ScoreSnapshot>()
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    ScoreSnapshot? todayScore;
    for (final entry in allHistory) {
      if (ScoreCalculator.dayKey(entry.date) == dayKey) {
        todayScore = entry;
        break;
      }
    }
    return (
      today: todayScore,
      history: allHistory.length <= 7
          ? allHistory
          : allHistory.sublist(allHistory.length - 7),
    );
  }

  ScoreSnapshot _mergeAvailableScores(
    ScoreSnapshot previous,
    ScoreSnapshot next,
  ) => ScoreSnapshot(
    date: next.date,
    sleepScore: next.sleepScore ?? previous.sleepScore,
    recoveryScore: next.recoveryScore ?? previous.recoveryScore,
    strainScore: next.hasStrainData ? next.strainScore : previous.strainScore,
    hasStrainData: next.hasStrainData || previous.hasStrainData,
    calibrationDays: next.calibrationDays,
    asleepMinutes: next.asleepMinutes ?? previous.asleepMinutes,
    inBedMinutes: next.inBedMinutes ?? previous.inBedMinutes,
    sleepEfficiency: next.sleepEfficiency ?? previous.sleepEfficiency,
    hrv: next.hrv ?? previous.hrv,
    hrvBaseline: next.hrvBaseline ?? previous.hrvBaseline,
    restingHeartRate: next.restingHeartRate ?? previous.restingHeartRate,
    restingHeartRateBaseline:
        next.restingHeartRateBaseline ?? previous.restingHeartRateBaseline,
    deepMinutes: next.deepMinutes ?? previous.deepMinutes,
    remMinutes: next.remMinutes ?? previous.remMinutes,
    lightMinutes: next.lightMinutes ?? previous.lightMinutes,
    awakeMinutes: next.awakeMinutes ?? previous.awakeMinutes,
    zoneMinutes: next.zoneMinutes.values.any((minutes) => minutes > 0)
        ? next.zoneMinutes
        : previous.zoneMinutes,
    workoutVolume: next.workoutVolume,
    workoutSets: next.workoutSets,
  );

  Map<String, Object?> _stringKeyedMap(Object? value) {
    if (value is! Map) return {};
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  double? _positiveNumber(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toDouble() : null;

  void _putMapIfChanged(
    Box<dynamic> box,
    String key,
    Map<String, Object?> value,
  ) {
    final existing = box.get(key);
    if (jsonEncode(existing) != jsonEncode(value)) {
      unawaited(box.put(key, value));
    }
  }

  Future<void> _loadPersonalRecords() async {
    if (!loadHive || _disposed) {
      return;
    }
    final loadClock = Stopwatch()..start();
    PerfDiagnostics.log(
      'Dashboard personal-record fetch started',
      splashWindowOnly: true,
    );
    try {
      final histories = await ProgressRepository.loadAll();
      final prs = histories.values
          .map((history) {
            ProgressPr? best;
            for (final record in history.personalRecords) {
              if (record.type != ProgressPrType.estimatedOneRepMax) {
                continue;
              }
              if (best == null || record.value > best.value) {
                best = record;
              }
            }
            final record = best;
            if (record == null) {
              return null;
            }
            return DashboardPr(
              exerciseName: history.exerciseName,
              estimatedOneRepMax: record.value,
              date: record.date,
            );
          })
          .whereType<DashboardPr>()
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (!_disposed) {
        _update(_snapshot.copyWith(prs: prs));
      }
      PerfDiagnostics.log(
        'Dashboard personal-record fetch finished after '
        '${loadClock.elapsedMilliseconds}ms (${prs.length} records)',
        splashWindowOnly: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Dashboard PR history refresh failed: $error\n$stackTrace');
      PerfDiagnostics.log(
        'Dashboard personal-record fetch failed after '
        '${loadClock.elapsedMilliseconds}ms: $error',
        splashWindowOnly: true,
      );
    }
  }

  void _update(DashboardSnapshot next) {
    if (_disposed) {
      return;
    }
    _snapshot = next;
    PerfDiagnostics.log(
      'Dashboard notifyListeners: isLoading=${next.isLoading} '
      'healthLoading=${next.healthLoading}',
      splashWindowOnly: true,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final listenable in _hiveListenables) {
      listenable.removeListener(_onHiveChanged);
    }
    _hiveListenables.clear();
    super.dispose();
  }
}

Set<String> _nonEmpty(List<String> values) => values
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toSet();

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

double _sumFood(
  Iterable<FoodLog> entries,
  double? Function(FoodLog entry) valueFor,
) =>
    entries.fold<double>(
      0,
      (total, entry) => total + (valueFor(entry) ?? 0) * entry.quantity,
    );

double _readGoal(Box<dynamic> settings, String key, double fallback) {
  final value = settings.get(key);
  if (value is num && value > 0) {
    return value.toDouble();
  }
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  return fallback;
}
