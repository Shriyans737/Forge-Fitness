import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:forge/screens/health_screen.dart';
import 'package:forge/services/health_service.dart';
import 'package:forge/theme.dart';

void main() {
  test('iOS health types contain only package-supported sleep types', () {
    final types = HealthService.typesForPlatform(
      HealthPlatformType.appleHealth,
    );
    final sleepTypes = types.where((type) => type.name.startsWith('SLEEP_'));

    expect(sleepTypes.toSet(), {
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
    });
    expect(types, isNot(contains(HealthDataType.SLEEP_AWAKE_IN_BED)));
    expect(types, isNot(contains(HealthDataType.SLEEP_SESSION)));
    expect(types, isNot(contains(HealthDataType.SLEEP_OUT_OF_BED)));
  });

  test('a failed health type does not discard other type results', () async {
    final result = await queryHealthTypesIndependently<String, int>(
      types: const ['steps', 'sleep', 'active energy'],
      query: (type) async {
        if (type == 'sleep') throw StateError('sleep provider unavailable');
        return type == 'steps' ? [4200] : [320];
      },
    );

    expect(result.pointsByType, {
      'steps': [4200],
      'active energy': [320],
    });
    expect(result.failures.keys, {'sleep'});
    expect(result.failures['sleep'], isA<StateError>());
  });

  testWidgets(
    'Health overview keeps steps and active energy when sleep query fails',
    (tester) async {
      final summary = HealthSummary(
        hasPermissions: true,
        steps: 6543,
        activeCaloriesBurned: 321,
        failedTypes: const {HealthDataType.SLEEP_AWAKE},
        syncErrors: const ['SLEEP_AWAKE query failed: provider error'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ForgeTheme.darkTheme,
          home: Scaffold(
            body: HealthOverviewRings(
              summaryFuture: Future.value(summary),
              lastSyncedAt: DateTime(2026, 10, 10, 12),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today at a glance'), findsOneWidget);
      expect(find.text('6.5k'), findsOneWidget);
      expect(find.text('321'), findsOneWidget);
      expect(find.textContaining('Last synced at'), findsOneWidget);
      expect(find.textContaining('SLEEP_AWAKE query failed'), findsNothing);
    },
  );
}
