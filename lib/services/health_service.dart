import 'dart:async';
import 'dart:io';

import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/perf_diagnostics.dart';
import '../features/dashboard/services/score_calculator.dart';

class HealthTypeQueryResult<TType, TValue> {
  const HealthTypeQueryResult({
    required this.pointsByType,
    required this.failures,
  });

  final Map<TType, List<TValue>> pointsByType;
  final Map<TType, Object> failures;
}

Future<HealthTypeQueryResult<TType, TValue>>
queryHealthTypesIndependently<TType, TValue>({
  required Iterable<TType> types,
  required Future<List<TValue>> Function(TType type) query,
}) async {
  final pointsByType = <TType, List<TValue>>{};
  final failures = <TType, Object>{};
  await Future.wait(
    types.map((type) async {
      try {
        pointsByType[type] = await query(type);
      } catch (error) {
        failures[type] = error;
      }
    }),
  );
  return HealthTypeQueryResult(pointsByType: pointsByType, failures: failures);
}

class HealthSummary {
  const HealthSummary({
    required this.hasPermissions,
    this.steps,
    this.averageHeartRate,
    this.latestHeartRate,
    this.activeCaloriesBurned,
    this.distanceMeters,
    this.flightsClimbed,
    this.restingHeartRate,
    this.heartRateVariability,
    this.bloodOxygen,
    this.weightKg,
    this.sleepAsleepMinutes,
    this.sleepInBedMinutes,
    this.sleepAwakeMinutes,
    this.sleepDeepMinutes,
    this.sleepLightMinutes,
    this.sleepRemMinutes,
    this.heartRateSamples = const [],
    this.errorMessage,
    this.syncErrors = const [],
    this.failedTypes = const {},
  });

  final bool hasPermissions;
  final int? steps;
  final double? averageHeartRate;
  final double? latestHeartRate;
  final double? activeCaloriesBurned;
  final double? distanceMeters;
  final double? flightsClimbed;
  final double? restingHeartRate;
  final double? heartRateVariability;
  final double? bloodOxygen;
  final double? weightKg;
  final double? sleepAsleepMinutes;
  final double? sleepInBedMinutes;
  final double? sleepAwakeMinutes;
  final double? sleepDeepMinutes;
  final double? sleepLightMinutes;
  final double? sleepRemMinutes;
  final List<HeartRateSample> heartRateSamples;
  final String? errorMessage;
  final List<String> syncErrors;
  final Set<HealthDataType> failedTypes;

  bool get fetchSucceeded => hasPermissions;

  HealthSummary withSyncErrors(List<String> errors) => HealthSummary(
    hasPermissions: hasPermissions,
    steps: steps,
    averageHeartRate: averageHeartRate,
    latestHeartRate: latestHeartRate,
    activeCaloriesBurned: activeCaloriesBurned,
    distanceMeters: distanceMeters,
    flightsClimbed: flightsClimbed,
    restingHeartRate: restingHeartRate,
    heartRateVariability: heartRateVariability,
    bloodOxygen: bloodOxygen,
    weightKg: weightKg,
    sleepAsleepMinutes: sleepAsleepMinutes,
    sleepInBedMinutes: sleepInBedMinutes,
    sleepAwakeMinutes: sleepAwakeMinutes,
    sleepDeepMinutes: sleepDeepMinutes,
    sleepLightMinutes: sleepLightMinutes,
    sleepRemMinutes: sleepRemMinutes,
    heartRateSamples: heartRateSamples,
    errorMessage: errorMessage,
    syncErrors: [...syncErrors, ...errors],
    failedTypes: failedTypes,
  );

  bool get hasAnyData =>
      (steps ?? 0) > 0 ||
      (activeCaloriesBurned ?? 0) > 0 ||
      latestHeartRate != null ||
      restingHeartRate != null ||
      heartRateVariability != null ||
      weightKg != null ||
      bloodOxygen != null ||
      (distanceMeters ?? 0) > 0 ||
      (flightsClimbed ?? 0) > 0 ||
      (sleepAsleepMinutes ?? 0) > 0;
}

class HealthWorkoutEntry {
  const HealthWorkoutEntry({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.calories,
  });

  final String type;
  final DateTime startTime;
  final DateTime endTime;
  final double calories;
}

class HealthDailyShareData {
  const HealthDailyShareData({
    this.steps,
    this.activeCalories,
    this.sleepHours,
    this.restingHeartRate,
    this.averageHeartRate,
    this.workouts = const [],
  });

  final int? steps;
  final double? activeCalories;
  final double? sleepHours;
  final double? restingHeartRate;
  final double? averageHeartRate;
  final List<HealthWorkoutEntry> workouts;

  bool get hasData =>
      steps != null ||
      activeCalories != null ||
      sleepHours != null ||
      restingHeartRate != null ||
      averageHeartRate != null ||
      workouts.isNotEmpty;

  Map<String, Object> toFirestoreMap() => {
    ...?(steps == null ? null : {'steps': steps!}),
    ...?(activeCalories == null ? null : {'activeCalories': activeCalories!}),
    ...?(sleepHours == null ? null : {'sleepHours': sleepHours!}),
    ...?(restingHeartRate == null
        ? null
        : {'restingHeartRate': restingHeartRate!}),
    ...?(averageHeartRate == null
        ? null
        : {'averageHeartRate': averageHeartRate!}),
    'workouts': workouts
        .map(
          (workout) => {
            'sport': workout.type,
            'durationMinutes': workout.endTime
                .difference(workout.startTime)
                .inMinutes,
            'calories': workout.calories,
          },
        )
        .toList(growable: false),
  };
}

class HealthService {
  static final Health _health = Health();
  static Future<void>? _configuration;

  static const List<HealthDataType> _commonTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.WEIGHT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataType> _iosSleepTypes = [
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
  ];

  static const List<HealthDataType> _androidSleepTypes = [
    ..._iosSleepTypes,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_OUT_OF_BED,
    HealthDataType.SLEEP_UNKNOWN,
  ];

  static const Set<HealthDataType> _allSleepTypes = {..._androidSleepTypes};

  static List<HealthDataType> typesForPlatform(HealthPlatformType platform) {
    final availableTypes = switch (platform) {
      HealthPlatformType.appleHealth => dataTypeKeysIOS,
      HealthPlatformType.googleHealthConnect => dataTypeKeysAndroid,
    };
    final sleepTypes = switch (platform) {
      HealthPlatformType.appleHealth => _iosSleepTypes,
      HealthPlatformType.googleHealthConnect => _androidSleepTypes,
    };
    return [
      ..._commonTypes,
      ...sleepTypes,
    ].where(availableTypes.contains).toSet().toList(growable: false);
  }

  static final List<(HealthDataType, HealthDataAccess)> _requestedAccess =
      typesForPlatform(
        Platform.isIOS
            ? HealthPlatformType.appleHealth
            : HealthPlatformType.googleHealthConnect,
      ).map((type) => (type, HealthDataAccess.READ)).toList(growable: false);

  static List<HealthDataType> get _readTypes =>
      _requestedAccess.map((entry) => entry.$1).toList(growable: false);

  static List<HealthDataAccess> get _readPermissions =>
      _requestedAccess.map((entry) => entry.$2).toList(growable: false);

  static Future<void> initialize() => _configuration ??= _health.configure();

  Future<void> _ensureConfigured() => initialize();

  void _log(String message) {
    PerfDiagnostics.log(message, splashWindowOnly: true);
  }

  Future<bool> hasPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      await _ensureConfigured();
      final granted = await _health.hasPermissions(
        _readTypes,
        permissions: _readPermissions,
      );
      _log('Health read permission status: ${granted ?? 'unknown on iOS'}');
      // HealthKit deliberately does not disclose read authorization status.
      return granted ?? Platform.isIOS;
    } catch (error, stackTrace) {
      _log('Health permission check failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    final permissionClock = Stopwatch()..start();
    _log('Health permission fetch started');
    try {
      await _ensureConfigured();
      if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
        _log('Health Connect is unavailable.');
        return false;
      }

      final types = _readTypes;
      final permissions = _readPermissions;
      if (types.length != permissions.length) {
        throw StateError('Health type and permission counts do not match.');
      }
      _log(
        'Health requestAuthorization types(${types.length})=$types; '
        'access(${permissions.length})=$permissions; '
        'lengthsMatch=${types.length == permissions.length}',
      );
      final result = await _health
          .requestAuthorization(types, permissions: permissions)
          .timeout(const Duration(seconds: 15), onTimeout: () => false);
      _log('Health requestAuthorization returned: $result');
      return result;
    } catch (error, stackTrace) {
      _log('Health authorization failed: $error\n$stackTrace');
      return false;
    } finally {
      _log(
        'Health permission fetch finished after '
        '${permissionClock.elapsedMilliseconds}ms',
      );
    }
  }

  Future<HealthSummary?> syncTodaySummary() async {
    final authorized = await requestPermissions();
    var summary = await fetchTodaySummary();
    if (summary == null) return null;
    if (!authorized) {
      summary = summary.withSyncErrors([
        'Health authorization request did not succeed.',
      ]);
    }
    if (summary.fetchSucceeded) {
      final settings = Hive.box<dynamic>('settings');
      await settings.put('healthLastSyncedAt', DateTime.now());
    }
    return summary;
  }

  Future<HealthSummary?> fetchTodaySummary() async {
    final fetchClock = Stopwatch()..start();
    _log('Health fetchTodaySummary started');
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        return const HealthSummary(
          hasPermissions: false,
          errorMessage: 'Health tracking is unavailable on this device.',
          syncErrors: ['Health tracking is unavailable on this device.'],
        );
      }

      await _ensureConfigured();
      if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
        return const HealthSummary(
          hasPermissions: false,
          errorMessage: 'Health Connect is not installed on this device.',
          syncErrors: ['Health Connect is not installed on this device.'],
        );
      }

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final sleepStart = yesterday.add(const Duration(hours: 18));
      final todayNoon = DateTime(now.year, now.month, now.day, 12);
      final sleepEnd = now.isBefore(todayNoon) ? now : todayNoon;
      final heartStart = now.subtract(const Duration(hours: 24));
      final weightStart = now.subtract(const Duration(days: 365));
      final errors = <String>[];
      DateTime queryStart(HealthDataType type) => switch (type) {
        HealthDataType.RESTING_HEART_RATE => heartStart,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN => sleepStart,
        HealthDataType.SLEEP_ASLEEP ||
        HealthDataType.SLEEP_AWAKE ||
        HealthDataType.SLEEP_AWAKE_IN_BED ||
        HealthDataType.SLEEP_DEEP ||
        HealthDataType.SLEEP_IN_BED ||
        HealthDataType.SLEEP_LIGHT ||
        HealthDataType.SLEEP_OUT_OF_BED ||
        HealthDataType.SLEEP_REM ||
        HealthDataType.SLEEP_SESSION ||
        HealthDataType.SLEEP_UNKNOWN => sleepStart,
        HealthDataType.WEIGHT || HealthDataType.BLOOD_OXYGEN => weightStart,
        _ => startOfToday,
      };
      DateTime queryEnd(HealthDataType type) =>
          type == HealthDataType.HEART_RATE_VARIABILITY_SDNN ||
              _allSleepTypes.contains(type)
          ? sleepEnd
          : now;
      final requestedTypes = _readTypes;
      final queryResult = await queryHealthTypesIndependently(
        types: requestedTypes,
        query: (type) async {
          final typeClock = Stopwatch()..start();
          _log(
            'Health ${type.name} query started: '
            '${queryStart(type)} -> ${queryEnd(type)}',
          );
          try {
            final points = _health.removeDuplicates(
              await _health.getHealthDataFromTypes(
                types: [type],
                startTime: queryStart(type),
                endTime: queryEnd(type),
              ),
            );
            _log(
              'Health ${type.name} query finished after '
              '${typeClock.elapsedMilliseconds}ms: ${points.length} points',
            );
            return points;
          } catch (error) {
            _log(
              'Health ${type.name} query threw after '
              '${typeClock.elapsedMilliseconds}ms: $error',
            );
            rethrow;
          }
        },
      );
      for (final type in requestedTypes) {
        final failure = queryResult.failures[type];
        if (failure != null) {
          errors.add('${type.name} query failed: $failure');
          _log('Health ${type.name} query failed independently: $failure');
        } else {
          final points = queryResult.pointsByType[type] ?? const [];
          _log(
            'Health ${type.name} query returned ${points.length} data points',
          );
        }
      }
      _log(
        'Health sync type results: '
        '${requestedTypes.map((type) => '${type.name}=${queryResult.pointsByType[type]?.length ?? 0}').join(', ')}; '
        'failures=${queryResult.failures.entries.map((entry) => '${entry.key.name}: ${entry.value}').join('; ')}',
      );
      List<HealthDataPoint> pointsFor(HealthDataType type) =>
          queryResult.pointsByType[type] ?? const [];

      final stepsPoints = pointsFor(HealthDataType.STEPS);
      final sumStepsFromSamples = _sumNumericValuesForType(
        stepsPoints,
        HealthDataType.STEPS,
      )?.round();
      int? steps;
      try {
        steps = await _health.getTotalStepsInInterval(startOfToday, now);
        _log(
          'Health ${HealthDataType.STEPS.name} aggregate $startOfToday -> '
          '$now: total=${steps ?? 'no samples'}; '
          'sources=${_sourceNames(stepsPoints)}',
        );
      } catch (error, stackTrace) {
        _recordQueryError(
          HealthDataType.STEPS,
          startOfToday,
          now,
          error,
          stackTrace,
          errors,
        );
      }
      if (steps == null && sumStepsFromSamples != null) {
        steps = sumStepsFromSamples;
        _log(
          'Health ${HealthDataType.STEPS.name} aggregate unavailable; '
          'falling back to raw sample total: $steps',
        );
      }

      final distanceType = Platform.isIOS
          ? HealthDataType.DISTANCE_WALKING_RUNNING
          : HealthDataType.DISTANCE_DELTA;
      final activeEnergyPoints = pointsFor(HealthDataType.ACTIVE_ENERGY_BURNED);
      final distancePoints = pointsFor(distanceType);
      final flightsPoints = pointsFor(HealthDataType.FLIGHTS_CLIMBED);
      final heartRatePoints = pointsFor(HealthDataType.HEART_RATE);
      final restingHeartPoints = pointsFor(HealthDataType.RESTING_HEART_RATE);
      final hrvPoints = pointsFor(HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      final heartPoints = [...heartRatePoints, ...restingHeartPoints];
      final weightPoints = [
        ...pointsFor(HealthDataType.WEIGHT),
        ...pointsFor(HealthDataType.BLOOD_OXYGEN),
      ];

      final sleepTypes = requestedTypes
          .where(_allSleepTypes.contains)
          .toList(growable: false);
      final sleepPointsByType = {
        for (final type in sleepTypes) type: pointsFor(type),
      };
      final sleepPoints = _health.removeDuplicates(
        sleepPointsByType.values.expand((points) => points).toList(),
      );
      final stageSleepMinutes = _sumSleepIntervals(
        sleepPoints,
        const [
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
        ],
        sleepStart,
        sleepEnd,
      );
      final asleepMinutes =
          stageSleepMinutes ??
          _sumSleepIntervals(
            sleepPoints,
            const [HealthDataType.SLEEP_ASLEEP],
            sleepStart,
            sleepEnd,
          ) ??
          _sumSleepIntervals(
            sleepPoints,
            const [
              HealthDataType.SLEEP_IN_BED,
              HealthDataType.SLEEP_AWAKE_IN_BED,
              HealthDataType.SLEEP_SESSION,
            ],
            sleepStart,
            sleepEnd,
          );
      final activeCalories = _sumNumericValuesForType(
        _dedupeEnergyPoints(activeEnergyPoints),
        HealthDataType.ACTIVE_ENERGY_BURNED,
      );
      final distanceMeters = _sumNumericValuesForType(
        distancePoints,
        distanceType,
      );
      _log(
        'Health active-energy fetch -> dashboard input: '
        'points=${activeEnergyPoints.length}, activeKcal=$activeCalories',
      );

      final summary = HealthSummary(
        hasPermissions: true,
        steps: steps,
        averageHeartRate: _averageNumericValue(
          heartPoints,
          HealthDataType.HEART_RATE,
        ),
        latestHeartRate: _latestNumericValueForType(
          heartPoints,
          HealthDataType.HEART_RATE,
        ),
        restingHeartRate: _latestNumericValueForType(
          restingHeartPoints,
          HealthDataType.RESTING_HEART_RATE,
        ),
        heartRateVariability: _latestNumericValueForType(
          hrvPoints,
          HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        ),
        activeCaloriesBurned: activeCalories,
        distanceMeters: distanceMeters,
        flightsClimbed: _sumNumericValuesForType(
          flightsPoints,
          HealthDataType.FLIGHTS_CLIMBED,
        ),
        bloodOxygen: _latestNumericValueForType(
          weightPoints,
          HealthDataType.BLOOD_OXYGEN,
        ),
        weightKg: _latestNumericValueForType(
          weightPoints,
          HealthDataType.WEIGHT,
        ),
        sleepAsleepMinutes: asleepMinutes,
        sleepInBedMinutes: _sumSleepIntervals(
          sleepPoints,
          const [HealthDataType.SLEEP_IN_BED, HealthDataType.SLEEP_SESSION],
          sleepStart,
          sleepEnd,
        ),
        sleepAwakeMinutes: _sumSleepIntervals(
          sleepPoints,
          const [HealthDataType.SLEEP_AWAKE, HealthDataType.SLEEP_AWAKE_IN_BED],
          sleepStart,
          sleepEnd,
        ),
        sleepDeepMinutes: _sumSleepIntervals(
          sleepPoints,
          [HealthDataType.SLEEP_DEEP],
          sleepStart,
          sleepEnd,
        ),
        sleepLightMinutes: _sumSleepIntervals(
          sleepPoints,
          [HealthDataType.SLEEP_LIGHT],
          sleepStart,
          sleepEnd,
        ),
        sleepRemMinutes: _sumSleepIntervals(
          sleepPoints,
          [HealthDataType.SLEEP_REM],
          sleepStart,
          sleepEnd,
        ),
        heartRateSamples: [
          for (final point in heartRatePoints)
            if (_numericValue(point.value) case final bpm?)
              HeartRateSample(time: point.dateTo, bpm: bpm),
        ],
        syncErrors: errors,
        errorMessage: null,
        failedTypes: _failedTypes(errors),
      );
      _log(
        'Health values delivered: steps=${summary.steps}, '
        'activeKcal=${summary.activeCaloriesBurned}, '
        'heartRate=${summary.latestHeartRate}, '
        'flights=${summary.flightsClimbed}, '
        'sleepMinutes=${summary.sleepAsleepMinutes}; '
        'sleepPoints=${sleepPoints.length}',
      );
      return summary;
    } catch (error, stackTrace) {
      _log('Health data query failed: $error\n$stackTrace');
      return HealthSummary(
        hasPermissions: false,
        errorMessage: 'Unable to read health data right now. Please try again.',
        syncErrors: ['Health data query failed: $error'],
      );
    } finally {
      _log(
        'Health fetchTodaySummary finished after '
        '${fetchClock.elapsedMilliseconds}ms',
      );
    }
  }

  void _recordQueryError(
    HealthDataType type,
    DateTime start,
    DateTime end,
    Object error,
    StackTrace stackTrace,
    List<String> errors,
  ) {
    errors.add('${type.name} query failed: $error');
    _log('Health ${type.name} $start -> $end: ERROR $error\n$stackTrace');
  }

  String _sourceNames(List<HealthDataPoint> points) {
    final names =
        points
            .map((point) => point.sourceName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names.isEmpty ? '(none)' : names.join(', ');
  }

  Set<HealthDataType> _failedTypes(List<String> errors) => HealthDataType.values
      .where(
        (type) => errors.any(
          (error) => error.startsWith('${type.name} query failed:'),
        ),
      )
      .toSet();

  List<HealthDataPoint> _dedupeEnergyPoints(List<HealthDataPoint> points) {
    final energyPoints =
        points
            .where((point) => point.type == HealthDataType.ACTIVE_ENERGY_BURNED)
            .toList()
          ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    final uniqueIntervals = <String, HealthDataPoint>{};
    for (final point in energyPoints) {
      final key =
          '${point.dateFrom.microsecondsSinceEpoch}:${point.dateTo.microsecondsSinceEpoch}';
      final previous = uniqueIntervals[key];
      if (previous == null ||
          (_numericValue(point.value) ?? 0) >
              (_numericValue(previous.value) ?? 0)) {
        uniqueIntervals[key] = point;
      }
    }
    return uniqueIntervals.values.toList(growable: false);
  }

  List<double> _numericValuesForType(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) => points
      .where((point) => point.type == type)
      .map((point) => _numericValue(point.value))
      .whereType<double>()
      .toList(growable: false);

  double? _averageNumericValue(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    final values = _numericValuesForType(points, type);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _latestNumericValueForType(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    final matching = points.where((point) => point.type == type).toList()
      ..sort((a, b) => a.dateTo.compareTo(b.dateTo));
    for (final point in matching.reversed) {
      final value = _numericValue(point.value);
      if (value != null) {
        if (type == HealthDataType.BLOOD_OXYGEN && value <= 1) {
          return value * 100;
        }
        return value;
      }
    }
    return null;
  }

  double? _sumNumericValuesForType(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    final values = _numericValuesForType(points, type);
    if (values.isEmpty) return null;
    return values.fold<double>(0, (total, value) => total + value);
  }

  double? _sumSleepIntervals(
    List<HealthDataPoint> points,
    List<HealthDataType> types,
    DateTime startLimit,
    DateTime endLimit,
  ) {
    final intervals =
        points
            .where((point) => types.contains(point.type))
            .map(
              (point) => (
                start: point.dateFrom.isBefore(startLimit)
                    ? startLimit
                    : point.dateFrom,
                end: point.dateTo.isAfter(endLimit) ? endLimit : point.dateTo,
              ),
            )
            .where((interval) => interval.end.isAfter(interval.start))
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    if (intervals.isEmpty) return null;

    var start = intervals.first.start;
    var end = intervals.first.end;
    var total = Duration.zero;
    for (final interval in intervals.skip(1)) {
      if (!interval.start.isAfter(end)) {
        if (interval.end.isAfter(end)) end = interval.end;
      } else {
        total += end.difference(start);
        start = interval.start;
        end = interval.end;
      }
    }
    total += end.difference(start);
    return total.inSeconds / 60;
  }

  Future<List<HealthWorkoutEntry>> fetchRecentWorkouts(
    int days, {
    int? limit = 8,
  }) async {
    if (days <= 0 || (!Platform.isAndroid && !Platform.isIOS)) {
      return const [];
    }
    try {
      await _ensureConfigured();
      if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
        return const [];
      }
      if (!_readTypes.contains(HealthDataType.WORKOUT)) return const [];
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));
      final points = await _health.getHealthDataFromTypes(
        types: _readTypes
            .where((type) => type == HealthDataType.WORKOUT)
            .toList(growable: false),
        startTime: start,
        endTime: now,
      );
      _log('Health WORKOUT $start -> $now: ${points.length} data points');
      final workouts = points.map((point) {
        final summary = point.workoutSummary;
        return HealthWorkoutEntry(
          type: summary?.workoutType.isNotEmpty == true
              ? summary!.workoutType
              : point.type.name,
          startTime: point.dateFrom,
          endTime: point.dateTo,
          calories: summary?.totalEnergyBurned is num
              ? summary!.totalEnergyBurned.toDouble()
              : 0.0,
        );
      }).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
      return limit == null
          ? workouts
          : workouts.take(limit).toList(growable: false);
    } catch (error, stackTrace) {
      _log('Health workout query failed: $error\n$stackTrace');
      return const [];
    }
  }

  Future<Map<DateTime, HealthDailyShareData>> fetchRecentDailyShareData(
    int days,
  ) async {
    if (days <= 0 || (!Platform.isAndroid && !Platform.isIOS)) {
      return const {};
    }
    try {
      await _ensureConfigured();
      if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
        return const {};
      }
      final types = [
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        ...(Platform.isIOS ? _iosSleepTypes : _androidSleepTypes),
      ].where(_readTypes.contains).toSet().toList(growable: false);
      final workouts = await fetchRecentWorkouts(days, limit: null);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final results = <DateTime, HealthDailyShareData>{};
      for (var offset = days - 1; offset >= 0; offset--) {
        final day = today.subtract(Duration(days: offset));
        final dayEnd = day.add(const Duration(days: 1));
        final end = dayEnd.isAfter(now) ? now : dayEnd;
        if (!end.isAfter(day)) continue;
        final points = _health.removeDuplicates(
          await _health.getHealthDataFromTypes(
            types: types,
            startTime: day,
            endTime: end,
          ),
        );
        final dayWorkouts = workouts
            .where(
              (workout) =>
                  !workout.startTime.isBefore(day) &&
                  workout.startTime.isBefore(dayEnd),
            )
            .toList(growable: false);
        final sleepMinutes = _sumSleepIntervals(
          points,
          _iosSleepTypes,
          day,
          end,
        );
        results[day] = HealthDailyShareData(
          steps: _sumNumericValuesForType(
            points,
            HealthDataType.STEPS,
          )?.round(),
          activeCalories: _sumNumericValuesForType(
            _dedupeEnergyPoints(points),
            HealthDataType.ACTIVE_ENERGY_BURNED,
          ),
          sleepHours: sleepMinutes == null ? null : sleepMinutes / 60,
          restingHeartRate: _averageNumericValue(
            points,
            HealthDataType.RESTING_HEART_RATE,
          ),
          averageHeartRate: _averageNumericValue(
            points,
            HealthDataType.HEART_RATE,
          ),
          workouts: dayWorkouts,
        );
      }
      return results;
    } catch (error, stackTrace) {
      _log('Health share history fetch failed: $error\n$stackTrace');
      return const {};
    }
  }

  double? _numericValue(HealthValue value) =>
      value is NumericHealthValue ? value.numericValue.toDouble() : null;
}
