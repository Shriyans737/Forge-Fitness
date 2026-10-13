import 'dart:math' as math;

class HeartRateSample {
  const HeartRateSample({required this.time, required this.bpm});

  final DateTime time;
  final double bpm;
}

class DailyVitals {
  const DailyVitals({
    required this.date,
    this.hrv,
    this.restingHeartRate,
  });

  final DateTime date;
  final double? hrv;
  final double? restingHeartRate;
}

class ScoreInput {
  const ScoreInput({
    required this.date,
    this.asleepMinutes,
    this.inBedMinutes,
    this.deepMinutes,
    this.remMinutes,
    this.lightMinutes,
    this.awakeMinutes,
    this.sleepGoalMinutes = 480,
    this.hrv,
    this.restingHeartRate,
    this.vitalsHistory = const [],
    this.heartRateSamples = const [],
    this.activeCalories = 0,
    this.workoutVolume = 0,
    this.workoutSets = 0,
    this.maxHeartRate,
  });

  final DateTime date;
  final double? asleepMinutes;
  final double? inBedMinutes;
  final double? deepMinutes;
  final double? remMinutes;
  final double? lightMinutes;
  final double? awakeMinutes;
  final double sleepGoalMinutes;
  final double? hrv;
  final double? restingHeartRate;
  final List<DailyVitals> vitalsHistory;
  final List<HeartRateSample> heartRateSamples;
  final double activeCalories;
  final double workoutVolume;
  final int workoutSets;
  final int? maxHeartRate;
}

class ScoreSnapshot {
  const ScoreSnapshot({
    required this.date,
    required this.sleepScore,
    required this.recoveryScore,
    required this.strainScore,
    required this.hasStrainData,
    required this.calibrationDays,
    required this.asleepMinutes,
    required this.inBedMinutes,
    required this.sleepEfficiency,
    required this.hrv,
    required this.hrvBaseline,
    required this.restingHeartRate,
    required this.restingHeartRateBaseline,
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.awakeMinutes,
    required this.zoneMinutes,
    required this.workoutVolume,
    required this.workoutSets,
  });

  final DateTime date;
  final double? sleepScore;
  final double? recoveryScore;
  final double strainScore;
  final bool hasStrainData;
  final int calibrationDays;
  final double? asleepMinutes;
  final double? inBedMinutes;
  final double? sleepEfficiency;
  final double? hrv;
  final double? hrvBaseline;
  final double? restingHeartRate;
  final double? restingHeartRateBaseline;
  final double? deepMinutes;
  final double? remMinutes;
  final double? lightMinutes;
  final double? awakeMinutes;
  final Map<int, double> zoneMinutes;
  final double workoutVolume;
  final int workoutSets;

  String get recoveryZone => ScoreCalculator.zoneForScore(recoveryScore);
  String get strainLabel => ScoreCalculator.strainLabelFor(strainScore);

  Map<String, Object?> toMap() => {
    'date': date.toIso8601String(),
    'sleepScore': sleepScore,
    'recoveryScore': recoveryScore,
    'strainScore': strainScore,
    'hasStrainData': hasStrainData,
    'calibrationDays': calibrationDays,
    'asleepMinutes': asleepMinutes,
    'inBedMinutes': inBedMinutes,
    'sleepEfficiency': sleepEfficiency,
    'hrv': hrv,
    'hrvBaseline': hrvBaseline,
    'restingHeartRate': restingHeartRate,
    'restingHeartRateBaseline': restingHeartRateBaseline,
    'deepMinutes': deepMinutes,
    'remMinutes': remMinutes,
    'lightMinutes': lightMinutes,
    'awakeMinutes': awakeMinutes,
    'zoneMinutes': {
      for (final entry in zoneMinutes.entries) '${entry.key}': entry.value,
    },
    'workoutVolume': workoutVolume,
    'workoutSets': workoutSets,
  };

  static ScoreSnapshot? fromMap(Object? value) {
    if (value is! Map) return null;
    final dateValue = value['date'];
    final date = dateValue is String ? DateTime.tryParse(dateValue) : null;
    if (date == null) return null;
    final rawZones = value['zoneMinutes'];
    final zones = <int, double>{};
    if (rawZones is Map) {
      for (final entry in rawZones.entries) {
        final zone = int.tryParse(entry.key.toString());
        final minutes = _number(entry.value);
        if (zone != null && minutes != null) zones[zone] = minutes;
      }
    }
    return ScoreSnapshot(
      date: date,
      sleepScore: _number(value['sleepScore']),
      recoveryScore: _number(value['recoveryScore']),
      strainScore: _number(value['strainScore']) ?? 0,
      hasStrainData: value['hasStrainData'] == true,
      calibrationDays: _number(value['calibrationDays'])?.round() ?? 0,
      asleepMinutes: _number(value['asleepMinutes']),
      inBedMinutes: _number(value['inBedMinutes']),
      sleepEfficiency: _number(value['sleepEfficiency']),
      hrv: _number(value['hrv']),
      hrvBaseline: _number(value['hrvBaseline']),
      restingHeartRate: _number(value['restingHeartRate']),
      restingHeartRateBaseline: _number(value['restingHeartRateBaseline']),
      deepMinutes: _number(value['deepMinutes']),
      remMinutes: _number(value['remMinutes']),
      lightMinutes: _number(value['lightMinutes']),
      awakeMinutes: _number(value['awakeMinutes']),
      zoneMinutes: zones,
      workoutVolume: _number(value['workoutVolume']) ?? 0,
      workoutSets: _number(value['workoutSets'])?.round() ?? 0,
    );
  }
}

class ScoreCalculator {
  const ScoreCalculator._();

  static ScoreSnapshot calculate(ScoreInput input) {
    final sleep = _sleep(input);
    final baselines = _baselinesFor(input);
    final calibrationDays = baselines.days;
    final recovery = calibrationDays < 4
        ? null
        : _recoveryScore(
            sleepScore: sleep.score,
            hrv: input.hrv,
            hrvBaseline: baselines.hrv,
            restingHeartRate: input.restingHeartRate,
            restingHeartRateBaseline: baselines.restingHeartRate,
          );
    final zones = _zoneMinutes(input);
    final hasHeartRateData = zones.values.any((minutes) => minutes > 0);
    final workoutVolume = _nonNegative(input.workoutVolume);
    final activeCalories = _nonNegative(input.activeCalories);
    final workoutSets = math.max(0, input.workoutSets);
    final hasActivityData =
        hasHeartRateData ||
        activeCalories > 0 ||
        workoutVolume > 0 ||
        workoutSets > 0;
    final workoutLoad =
        workoutSets * 0.6 + math.sqrt(workoutVolume) / 20;
    final activityLoad = hasHeartRateData
        ? zones.entries.fold<double>(
            0,
            (load, entry) => load + entry.value * _zoneWeight(entry.key),
          )
        : activeCalories / 25;
    final totalLoad = activityLoad + workoutLoad;
    final strain = hasActivityData
        ? (21 *
                  math.log(1 + totalLoad / 10) /
                  math.log(1 + 180 / 10))
              .clamp(0.0, 21.0)
        : 0.0;

    return ScoreSnapshot(
      date: _day(input.date),
      sleepScore: sleep.score,
      recoveryScore: recovery,
      strainScore: strain,
      hasStrainData: hasActivityData,
      calibrationDays: calibrationDays,
      asleepMinutes: _positive(input.asleepMinutes),
      inBedMinutes: _positive(input.inBedMinutes),
      sleepEfficiency: sleep.efficiency,
      hrv: _positive(input.hrv),
      hrvBaseline: baselines.hrv,
      restingHeartRate: _positive(input.restingHeartRate),
      restingHeartRateBaseline: baselines.restingHeartRate,
      deepMinutes: _positive(input.deepMinutes),
      remMinutes: _positive(input.remMinutes),
      lightMinutes: _positive(input.lightMinutes),
      awakeMinutes: _positive(input.awakeMinutes),
      zoneMinutes: zones,
      workoutVolume: workoutVolume,
      workoutSets: workoutSets,
    );
  }

  static String zoneForScore(double? score) {
    if (score == null) return 'Calibrating';
    if (score <= 33) return 'Low';
    if (score <= 66) return 'Moderate';
    return 'High';
  }

  static String strainLabelFor(double score) {
    final value = score.clamp(0.0, 21.0);
    if (value < 10) return 'Light';
    if (value < 14) return 'Moderate';
    if (value < 18) return 'High';
    return 'All out';
  }

  static String dayKey(DateTime date) {
    final day = _day(date);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  static _SleepResult _sleep(ScoreInput input) {
    final asleep = _positive(input.asleepMinutes);
    if (asleep == null) return const _SleepResult();
    final goal = input.sleepGoalMinutes.isFinite &&
            input.sleepGoalMinutes > 0
        ? input.sleepGoalMinutes
        : 480;
    final duration = (asleep / goal * 100).clamp(0.0, 100.0);
    final inBed = _positive(input.inBedMinutes);
    final efficiency = inBed == null
        ? null
        : (asleep / inBed).clamp(0.0, 1.0);
    final stageMinutes = (input.deepMinutes ?? 0) + (input.remMinutes ?? 0);
    final hasStageData =
        (input.deepMinutes ?? 0) > 0 || (input.remMinutes ?? 0) > 0;
    final stageShare = stageMinutes / asleep;
    final stageScore = hasStageData ? _stageScore(stageShare) : null;
    final parts = <(double, double)>[(duration, 0.6)];
    if (efficiency != null) parts.add((efficiency * 100, 0.25));
    if (stageScore != null) parts.add((stageScore, 0.15));
    final availableWeight = parts.fold<double>(
      0,
      (sum, part) => sum + part.$2,
    );
    final weighted = parts.fold<double>(
      0,
      (sum, part) => sum + part.$1 * part.$2,
    );
    return _SleepResult(
      score: (weighted / availableWeight).clamp(0.0, 100.0),
      efficiency: efficiency,
    );
  }

  static double _stageScore(double share) {
    if (share >= 0.35 && share <= 0.45) return 100;
    if (share < 0.35) {
      return ((share / 0.35) * 100).clamp(0.0, 100.0);
    }
    return ((1 - (share - 0.45) / 0.55) * 100).clamp(0.0, 100.0);
  }

  static double? _recoveryScore({
    required double? sleepScore,
    required double? hrv,
    required double? hrvBaseline,
    required double? restingHeartRate,
    required double? restingHeartRateBaseline,
  }) {
    final parts = <(double, double)>[];
    if (hrv != null && hrvBaseline != null && hrvBaseline > 0) {
      final relativeDeviation = (hrv - hrvBaseline) / hrvBaseline;
      parts.add(((60 + relativeDeviation * 80).clamp(0.0, 100.0), 0.5));
    }
    if (restingHeartRate != null &&
        restingHeartRateBaseline != null &&
        restingHeartRateBaseline > 0) {
      final relativeDeviation =
          (restingHeartRate - restingHeartRateBaseline) /
          restingHeartRateBaseline;
      parts.add(((60 - relativeDeviation * 150).clamp(0.0, 100.0), 0.25));
    }
    if (sleepScore != null) parts.add((sleepScore, 0.25));
    if (parts.isEmpty) return null;
    final weight = parts.fold<double>(0, (sum, part) => sum + part.$2);
    return parts.fold<double>(0, (sum, part) => sum + part.$1 * part.$2) /
        weight;
  }

  static _BaselineValues _baselinesFor(ScoreInput input) {
    final today = _day(input.date);
    final recent = input.vitalsHistory
        .where((vitals) => _day(vitals.date).isBefore(today))
        .where((vitals) => today.difference(_day(vitals.date)).inDays <= 14)
        .toList();
    final hrv = recent
        .map((item) => item.hrv)
        .whereType<double>()
        .where((value) => value.isFinite && value > 0)
        .toList();
    final resting = recent
        .map((item) => item.restingHeartRate)
        .whereType<double>()
        .where((value) => value.isFinite && value > 0)
        .toList();
    final days = recent
        .where((item) => item.hrv != null || item.restingHeartRate != null)
        .map((item) => dayKey(item.date))
        .toSet()
        .length;
    return _BaselineValues(
      days: days,
      hrv: _mean(hrv),
      restingHeartRate: _mean(resting),
    );
  }

  static Map<int, double> _zoneMinutes(ScoreInput input) {
    final maxHeartRate =
        input.maxHeartRate != null &&
            input.maxHeartRate! >= 80 &&
            input.maxHeartRate! <= 250
        ? input.maxHeartRate!.toDouble()
        : 190.0;
    final today = _day(input.date);
    final samples = input.heartRateSamples
        .where(
          (sample) =>
              sample.bpm.isFinite &&
              sample.bpm > 0 &&
              !_day(sample.time).isBefore(today) &&
              !_day(sample.time).isAfter(today),
        )
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final result = <int, double>{for (var zone = 1; zone <= 5; zone++) zone: 0};
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final minutes = index + 1 < samples.length
          ? (samples[index + 1].time.difference(sample.time).inSeconds / 60)
                .clamp(0.0, 5.0)
          : 1.0;
      final ratio = sample.bpm / maxHeartRate;
      final zone = ratio < 0.6
          ? (ratio >= 0.5 ? 1 : 0)
          : ratio < 0.7
          ? 2
          : ratio < 0.8
          ? 3
          : ratio < 0.9
          ? 4
          : 5;
      if (zone > 0) result[zone] = result[zone]! + minutes;
    }
    return result;
  }

  static double _zoneWeight(int zone) => switch (zone) {
    1 => 0.5,
    2 => 1,
    3 => 2,
    4 => 3.5,
    _ => 5,
  };

  static double? _mean(List<double> values) {
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double? _positive(double? value) =>
      value != null && value.isFinite && value > 0 ? value : null;

  static double _nonNegative(double value) =>
      value.isFinite ? math.max(0, value) : 0;

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _SleepResult {
  const _SleepResult({this.score, this.efficiency});

  final double? score;
  final double? efficiency;
}

class _BaselineValues {
  const _BaselineValues({
    required this.days,
    required this.hrv,
    required this.restingHeartRate,
  });

  final int days;
  final double? hrv;
  final double? restingHeartRate;
}

double? _number(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;