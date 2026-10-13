import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/features/dashboard/dashboard_controller.dart';
import 'package:forge/features/dashboard/dashboard_screen.dart';
import 'package:forge/features/dashboard/services/score_calculator.dart';
import 'package:forge/features/dashboard/widgets/dashboard_header.dart';
import 'package:forge/features/dashboard/widgets/dashboard_scores_card.dart';
import 'package:forge/services/health_service.dart';
import 'package:forge/theme.dart';
import 'package:forge/widgets/ui/gradient_ring.dart';

void main() {
  testWidgets('dashboard displays real ring progress and starts a workout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var startTapped = false;
    final controller = DashboardController(
      loadHive: false,
      initialSnapshot: DashboardSnapshot(
        isLoading: false,
        healthLoading: false,
        hasHealthPermissions: true,
        healthSummary: HealthSummary(
          hasPermissions: true,
          steps: 4200,
          activeCaloriesBurned: 320,
          latestHeartRate: 72,
          sleepAsleepMinutes: 450,
        ),
        displayName: 'Mira',
        todayVolume: 1200,
        todayReps: 32,
        weeklyVolumes: [600, 900, 300, 0, 0, 0, 0],
        weeklyWorkoutCount: 3,
        calories: 800,
        calorieGoal: 2000,
        scores: ScoreCalculator.calculate(
          ScoreInput(
            date: DateTime.now(),
            asleepMinutes: 450,
            inBedMinutes: 490,
            deepMinutes: 95,
            remMinutes: 100,
            activeCalories: 320,
            workoutVolume: 1200,
            workoutSets: 12,
            vitalsHistory: [
              DailyVitals(
                date: DateTime.now().subtract(const Duration(days: 1)),
                hrv: 50,
                restingHeartRate: 60,
              ),
              DailyVitals(
                date: DateTime.now().subtract(const Duration(days: 2)),
                hrv: 52,
                restingHeartRate: 61,
              ),
            ],
          ),
        ),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: DashboardScreen(
            controller: controller,
            onStartWorkout: () {
              startTapped = true;
              Navigator.of(tester.element(find.byType(DashboardScreen))).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Workout route')),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.text('Start a workout'), findsOneWidget);
    expect(find.text('Hey Mira'), findsOneWidget);
    expect(find.textContaining('Calibrating 2/4'), findsOneWidget);
    expect(
      tester
          .widget<GradientRing>(
            find.byKey(const ValueKey('dashboard-score-strain-ring')),
          )
          .value,
      greaterThan(0),
    );
    expect(
      tester
          .widget<GradientRing>(
            find.byKey(const ValueKey('dashboard-score-sleep-ring')),
          )
          .value,
      greaterThan(0),
    );

    await tester.scrollUntilVisible(
      find.text("TODAY'S PROGRESS"),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<GradientRing>(
            find.byKey(const ValueKey('dashboard-volume-ring')),
          )
          .value,
      greaterThan(0),
    );
    expect(
      tester
          .widget<GradientRing>(
            find.byKey(const ValueKey('dashboard-calorie-ring')),
          )
          .value,
      greaterThan(0),
    );

    await tester.scrollUntilVisible(
      find.text('HEALTH'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('320'), findsOneWidget);
    expect(find.text('72 bpm'), findsOneWidget);
    expect(find.text('7h 30m'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pump();
    await tester.tap(find.text('Start a workout'));
    await tester.pumpAndSettle();
    expect(startTapped, isTrue);
    expect(find.text('Workout route'), findsOneWidget);
  });

  testWidgets('empty score card stays compact at narrow phone widths', (
    tester,
  ) async {
    final scores = ScoreCalculator.calculate(
      ScoreInput(date: DateTime(2026, 10, 10)),
    );
    for (final width in [360.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 780));
      await tester.pumpWidget(
        MaterialApp(
          theme: ForgeTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SingleChildScrollView(
                child: DashboardScoresCard(
                  scores: scores,
                  history: const [],
                  reduceMotion: true,
                  isRefreshing: false,
                  hasHealthData: false,
                  onOpenHealth: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No Health data yet'), findsOneWidget);
      expect(find.text('Open Health'), findsOneWidget);
      expect(find.text("TODAY'S SCORES"), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('score rings replay their fill animation on trigger changes', (
    tester,
  ) async {
    final replayTrigger = ValueNotifier<int>(0);
    addTearDown(replayTrigger.dispose);
    final scores = ScoreCalculator.calculate(
      ScoreInput(
        date: DateTime(2026, 10, 10),
        asleepMinutes: 450,
        inBedMinutes: 490,
        deepMinutes: 100,
        remMinutes: 90,
        activeCalories: 320,
        workoutVolume: 1200,
        workoutSets: 12,
        vitalsHistory: [
          for (var day = 1; day <= 4; day++)
            DailyVitals(
              date: DateTime(2026, 10, 10).subtract(Duration(days: day)),
              hrv: 50 + day.toDouble(),
              restingHeartRate: 60 + day.toDouble(),
            ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: DashboardScoresCard(
              scores: scores,
              history: const [],
              replayTrigger: replayTrigger,
              reduceMotion: false,
              isRefreshing: false,
              hasHealthData: true,
              onOpenHealth: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 900));
    final ringFinder = find.byKey(const ValueKey('dashboard-score-sleep-ring'));
    final target = scores.sleepScore! / 100;
    expect(
      tester.widget<GradientRing>(ringFinder).value,
      closeTo(target, 0.01),
    );

    replayTrigger.value++;
    await tester.pump();
    expect(tester.widget<GradientRing>(ringFinder).value, closeTo(0, 0.01));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 450));
    final halfway = tester.widget<GradientRing>(ringFinder).value!;
    expect(halfway, greaterThan(0));
    expect(halfway, lessThan(target));
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      tester.widget<GradientRing>(ringFinder).value,
      closeTo(target, 0.01),
    );
  });

  testWidgets('long dashboard greeting stays on one line at phone widths', (
    tester,
  ) async {
    for (final width in [360.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 780));
      await tester.pumpWidget(
        MaterialApp(
          theme: ForgeTheme.darkTheme,
          home: Scaffold(
            body: DashboardHeader(
              date: DateTime(2026, 10, 10, 9),
              streak: 4,
              displayName: 'AlexandriaVeryLongDisplayName',
              isSyncing: false,
              onSync: () {},
              onSettings: () {},
              reduceMotion: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final greeting = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && (widget.data?.startsWith('Hey ') ?? false),
        ),
      );
      expect(greeting.maxLines, 1);
      expect(greeting.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
