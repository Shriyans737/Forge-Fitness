import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/dashboard/services/score_calculator.dart';

void main() {
  final today = DateTime(2026, 10, 9, 10);

  group('ScoreCalculator', () {
    test('empty data has no sleep or recovery score and zero strain', () {
      final result = ScoreCalculator.calculate(ScoreInput(date: today));

      expect(result.sleepScore, isNull);
      expect(result.recoveryScore, isNull);
      expect(result.calibrationDays, 0);
      expect(result.strainScore, 0);
      expect(result.hasStrainData, isFalse);
    });

    test('partial sleep redistributes unavailable stage and efficiency weights', () {
      final result = ScoreCalculator.calculate(
        ScoreInput(date: today, asleepMinutes: 480),
      );

      expect(result.sleepScore, 100);
      expect(result.sleepEfficiency, isNull);
      expect(result.recoveryScore, isNull);
    });

    test('normal day calculates sleep, calibrated recovery, and HR strain', () {
      final history = [
        for (var day = 1; day <= 4; day++)
          DailyVitals(
            date: today.subtract(Duration(days: day)),
            hrv: 50,
            restingHeartRate: 60,
          ),
      ];
      final result = ScoreCalculator.calculate(
        ScoreInput(
          date: today,
          asleepMinutes: 420,
          inBedMinutes: 480,
          deepMinutes: 90,
          remMinutes: 90,
          lightMinutes: 240,
          awakeMinutes: 60,
          hrv: 55,
          restingHeartRate: 58,
          vitalsHistory: history,
          heartRateSamples: [
            HeartRateSample(
              time: DateTime(2026, 10, 9, 8),
              bpm: 135,
            ),
            HeartRateSample(
              time: DateTime(2026, 10, 9, 8, 5),
              bpm: 160,
            ),
          ],
          workoutVolume: 2400,
          workoutSets: 12,
        ),
      );

      expect(result.sleepScore, inInclusiveRange(0, 100));
      expect(result.sleepEfficiency, closeTo(0.875, 0.001));
      expect(result.calibrationDays, 4);
      expect(result.recoveryScore, inInclusiveRange(0, 100));
      expect(result.recoveryZone, isNot('Calibrating'));
      expect(result.zoneMinutes[3], 5);
      expect(result.zoneMinutes[4], 1);
      expect(result.strainScore, greaterThan(0));
      expect(result.strainScore, lessThan(21));
    });

    test('extreme values stay within the score ranges', () {
      final result = ScoreCalculator.calculate(
        ScoreInput(
          date: today,
          asleepMinutes: 100000,
          sleepGoalMinutes: 1,
          inBedMinutes: 1,
          deepMinutes: 100000,
          remMinutes: 100000,
          hrv: 100000,
          restingHeartRate: 1,
          activeCalories: 1000000000,
          workoutVolume: 1e100,
          workoutSets: 1000000,
          heartRateSamples: [
            HeartRateSample(
              time: DateTime(2026, 10, 9, 8),
              bpm: 250,
            ),
            HeartRateSample(
              time: DateTime(2026, 10, 9, 8, 5),
              bpm: 250,
            ),
          ],
          vitalsHistory: [
            for (var day = 1; day <= 4; day++)
              DailyVitals(
                date: today.subtract(Duration(days: day)),
                hrv: 1,
                restingHeartRate: 250,
              ),
          ],
        ),
      );

      expect(result.sleepScore, inInclusiveRange(0, 100));
      expect(result.recoveryScore, inInclusiveRange(0, 100));
      expect(result.strainScore, 21);
      expect(result.zoneMinutes[5], 6);
    });

    test('recovery remains calibrating with fewer than four baseline days', () {
      final result = ScoreCalculator.calculate(
        ScoreInput(
          date: today,
          asleepMinutes: 430,
          hrv: 51,
          restingHeartRate: 59,
          vitalsHistory: [
            DailyVitals(
              date: today.subtract(const Duration(days: 1)),
              hrv: 50,
              restingHeartRate: 60,
            ),
            DailyVitals(
              date: today.subtract(const Duration(days: 2)),
              restingHeartRate: 61,
            ),
          ],
        ),
      );

      expect(result.calibrationDays, 2);
      expect(result.recoveryScore, isNull);
      expect(result.recoveryZone, 'Calibrating');
    });
  });
}