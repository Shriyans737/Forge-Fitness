// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_body_part_selector/flutter_body_part_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:forge/main.dart';
import 'package:forge/data/muscle_name_mapping.dart';
import 'package:forge/models/body_log_model.dart';
import 'package:forge/models/active_workout_draft.dart';
import 'package:forge/models/exercise.dart';
import 'package:forge/models/food_log_model.dart';
import 'package:forge/models/workout_session.dart';
import 'package:forge/models/workout_template.dart';
import 'package:forge/screens/active_workout_screen.dart';
import 'package:forge/screens/exercise_detail_screen.dart';
import 'package:forge/screens/exercise_progress_screen.dart';
import 'package:forge/screens/food_search_screen.dart';
import 'package:forge/screens/home_shell.dart';
import 'package:forge/screens/library_screen.dart';
import 'package:forge/features/splash/splash_screen.dart';
import 'package:forge/services/open_food_facts_service.dart';
import 'package:forge/services/progress_repository.dart';
import 'package:forge/theme.dart';
import 'package:forge/widgets/banner_ad_widget.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tempDirectory = await Directory.systemTemp.createTemp('forge_test_');
  Hive.init(tempDirectory.path);

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ExerciseAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ExerciseSetAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(LoggedExerciseAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(WorkoutSessionAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(WorkoutTemplateAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(BodyLogAdapter());
  }
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(FoodLogAdapter());
  }

  if (!Hive.isBoxOpen('exercises')) {
    await Hive.openBox<Exercise>('exercises');
  }
  if (!Hive.isBoxOpen('workoutSessions')) {
    await Hive.openBox<WorkoutSession>('workoutSessions');
  }
  if (!Hive.isBoxOpen('activeWorkout')) {
    await Hive.openBox<dynamic>('activeWorkout');
  }
  if (!Hive.isBoxOpen('workoutTemplates')) {
    await Hive.openBox<WorkoutTemplate>('workoutTemplates');
  }
  if (!Hive.isBoxOpen('bodyLogs')) {
    await Hive.openBox<BodyLog>('bodyLogs');
  }
  if (!Hive.isBoxOpen('foodLogs')) {
    await Hive.openBox<FoodLog>('foodLogs');
  }
  if (!Hive.isBoxOpen('settings')) {
    await Hive.openBox<dynamic>('settings');
  }
  for (final boxName in [
    'coachShownInsights',
    'coachDismissedInsights',
    'coachHabitLogs',
    'coachWeeklyReviews',
  ]) {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<dynamic>(boxName);
    }
  }

  await Hive.box<Exercise>('exercises').put(
    'test_exercise',
    Exercise(
      id: 'test_exercise',
      name: 'Test Exercise',
      muscleGroup: 'Core',
      description: 'Test description',
    ),
  );

  tearDownAll(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets('Active workout shows a live timer and muscle summary', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(
      () =>
          Hive.box<dynamic>('activeWorkout')
              .put('activeWorkout', <String, Object?>{}),
    );
    await tester.runAsync(
      () => Hive.box<Exercise>('exercises').put(
        'session_exercise',
        Exercise(
          id: 'session_exercise',
          name: 'Bench Press',
          muscleGroup: 'Chest',
          description: 'Press the bar upward.',
          primaryMuscles: const ['Chest'],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: ActiveWorkoutScreen(
          initialExerciseIds: const ['session_exercise'],
          resumeDraft: true,
        ),
      ),
    );

    expect(find.text('Elapsed'), findsOneWidget);
    expect(find.text('Target muscles'), findsOneWidget);
    expect(find.text('Chest'), findsOneWidget);
  });

  testWidgets('checking a set updates stats and the draft survives restore', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await Hive.box<dynamic>('activeWorkout').clear();
      await Hive.box<Exercise>('exercises').put(
        'session_exercise',
        Exercise(
          id: 'session_exercise',
          name: 'Bench Press',
          muscleGroup: 'Chest',
          description: '',
        ),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: const ActiveWorkoutScreen(
          initialExerciseIds: ['session_exercise'],
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add set'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '80');
    await tester.enterText(find.byType(TextField).at(1), '6');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.byTooltip('Done'));
    await tester.pump(const Duration(milliseconds: 350));

  expect(find.text('480kg'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await Hive.box<dynamic>('activeWorkout').flush();
    });
    final persisted = Hive.box<dynamic>('activeWorkout').get('activeWorkout');
    expect(persisted, isA<Map>());
    final restored = ActiveWorkoutDraft.fromMap(persisted as Map);
    expect(restored.exercises.single.sets.single.weight, 80);
    expect(restored.exercises.single.sets.single.reps, 6);
    expect(restored.completedSets.single.single, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Forge opens on the dashboard', (WidgetTester tester) async {
    await tester.runAsync(
      () => Hive.box<dynamic>('settings').put('displayName', 'Shriyans'),
    );
    await tester.pumpWidget(const ForgeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Hey Shriyans'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('Splash tap skips to the supplied home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.darkTheme,
        home: SplashScreen(
          preloadFuture: Future<void>.value(),
          homeBuilder: (_) =>
              const Scaffold(body: Center(child: Text('Splash home'))),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Splash home'), findsOneWidget);
  });

  testWidgets('Home shell has four tabs and Settings is on Dashboard', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await Hive.box<WorkoutSession>('workoutSessions').clear();
      await Hive.box<dynamic>('activeWorkout').clear();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.lightTheme,
        darkTheme: ForgeTheme.darkTheme,
        home: const HomeShell(),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);

    final dashboardSettingsButton = find.ancestor(
      of: find.byTooltip('Settings'),
      matching: find.byType(IconButton),
    );
    expect(dashboardSettingsButton, findsOneWidget);
    expect(
      tester.widget<IconButton>(dashboardSettingsButton).onPressed,
      isNotNull,
    );
    tester.widget<IconButton>(dashboardSettingsButton).onPressed!();
    expect(
      Navigator.of(tester.element(find.byType(HomeShell))).canPop(),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      Navigator.of(tester.element(find.byType(HomeShell))).canPop(),
      isTrue,
    );
    Navigator.of(tester.element(find.byType(HomeShell))).pop();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Workouts'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Workouts'), findsNWidgets(2));

    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Exercise Library'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));

    await tester.tap(find.text('Health').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Health'), findsNWidgets(2));
    final healthSettingsButton = find.descendant(
      of: find.byType(AppBar).last,
      matching: find.byTooltip('Settings'),
    );
    expect(healthSettingsButton, findsNothing);
  });

  testWidgets('Library renders in dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.lightTheme,
        darkTheme: ForgeTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const LibraryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Exercise Library'), findsOneWidget);
    expect(find.text('Search 800+ movements'), findsOneWidget);
    expect(find.text('No exercises match'), isNot(findsOneWidget));
  });

  testWidgets('Exercise library banner is hidden before 15 workouts', (
    WidgetTester tester,
  ) async {
    final workouts = Hive.box<WorkoutSession>('workoutSessions');
    await tester.runAsync(() async {
      await workouts.clear();
      for (var index = 0; index < 14; index++) {
        await workouts.put(
          'threshold_$index',
          WorkoutSession(
            id: 'threshold_$index',
            date: DateTime(2026, 1, 1),
            name: 'Test workout',
            exercises: const [],
          ),
        );
      }
    });

    await tester.pumpWidget(
      MaterialApp(theme: ForgeTheme.lightTheme, home: const LibraryScreen()),
    );

    expect(find.byType(BannerAdWidget), findsNothing);
  });

  testWidgets('Exercise library banner is shown at 15 workouts', (
    WidgetTester tester,
  ) async {
    final workouts = Hive.box<WorkoutSession>('workoutSessions');
    await tester.runAsync(() async {
      await workouts.clear();
      for (var index = 0; index < 15; index++) {
        await workouts.put(
          'threshold_$index',
          WorkoutSession(
            id: 'threshold_$index',
            date: DateTime(2026, 1, 1),
            name: 'Test workout',
            exercises: const [],
          ),
        );
      }
    });

    await tester.pumpWidget(
      MaterialApp(theme: ForgeTheme.lightTheme, home: const LibraryScreen()),
    );

    expect(find.byType(BannerAdWidget), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Exercise detail screen shows a fallback when instructions are missing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ForgeTheme.lightTheme,
          home: ExerciseDetailScreen(
            exercise: Exercise(
              id: 'missing_data',
              name: 'No Data Exercise',
              muscleGroup: 'Core',
              description: 'Placeholder description',
              primaryMuscles: const ['abdominals'],
              secondaryMuscles: const ['obliques'],
              equipment: 'body only',
              instructions: const [],
              imagePaths: const [],
            ),
          ),
        ),
      );

      expect(find.text('No Data Exercise'), findsNWidgets(2));
      expect(
        find.text('No instructions available for this exercise'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Exercise progress shows an empty state with no history', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await Hive.box<WorkoutSession>('workoutSessions').clear();
      final history = await ProgressRepository.historyFor(
        exerciseId: 'progress_empty',
        exerciseName: 'Progress Empty',
      );
      expect(history.sessions, isEmpty);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ForgeTheme.lightTheme,
        home: const ExerciseProgressScreen(
          exerciseId: 'progress_empty',
          exerciseName: 'Progress Empty',
        ),
      ),
    );
    await tester.runAsync(
      () => ProgressRepository.historyFor(
        exerciseId: 'progress_empty',
        exerciseName: 'Progress Empty',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Log this exercise a couple more times to see your progress'),
      findsOneWidget,
    );
    expect(find.text('Total sessions'), findsOneWidget);
  });

  testWidgets(
    'Exercise progress renders chart and selected sets in dark mode',
    (WidgetTester tester) async {
      final workouts = Hive.box<WorkoutSession>('workoutSessions');
      await tester.runAsync(() async {
        await workouts.clear();
        await workouts.put(
          'progress_first',
          WorkoutSession(
            id: 'progress_first',
            date: DateTime(2026, 1, 1),
            name: 'Workout 1',
            exercises: [
              LoggedExercise(
                exerciseId: 'progress_bench',
                exerciseName: 'Bench Press',
                sets: [
                  ExerciseSet(weight: 100, reps: 10, isWarmUp: true),
                  ExerciseSet(weight: 60, reps: 8),
                ],
              ),
            ],
          ),
        );
        await workouts.put(
          'progress_second',
          WorkoutSession(
            id: 'progress_second',
            date: DateTime(2026, 2, 1),
            name: 'Workout 2',
            exercises: [
              LoggedExercise(
                exerciseId: 'progress_bench',
                exerciseName: 'Bench Press',
                sets: [ExerciseSet(weight: 62.5, reps: 10)],
              ),
            ],
          ),
        );
        final history = await ProgressRepository.historyFor(
          exerciseId: 'progress_bench',
          exerciseName: 'Bench Press',
        );
        expect(history.sessions, hasLength(2));
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: ForgeTheme.lightTheme,
          darkTheme: ForgeTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const ExerciseProgressScreen(
            exerciseId: 'progress_bench',
            exerciseName: 'Bench Press',
          ),
        ),
      );
      await tester.runAsync(
        () => ProgressRepository.historyFor(
          exerciseId: 'progress_bench',
          exerciseName: 'Bench Press',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Personal records'), findsOneWidget);
      expect(find.textContaining('Set 1: 62.5 kg x 10 reps'), findsOneWidget);
      expect(find.text('3M'), findsOneWidget);
    },
  );

  test('free exercise dataset muscle names map to supported body parts', () {
    final mapped = resolveExerciseMuscles(['shoulders', 'chest', 'quadriceps']);

    expect(mapped.contains(Muscle.deltsLeft), isTrue);
    expect(mapped.contains(Muscle.deltsRight), isTrue);
    expect(mapped.contains(Muscle.chestLeft), isTrue);
    expect(mapped.contains(Muscle.chestRight), isTrue);
    expect(mapped.contains(Muscle.quadsLeft), isTrue);
    expect(mapped.contains(Muscle.quadsRight), isTrue);

    expect(getUnsupportedMuscleNames(['shoulders', 'neck', 'abductors']), {
      'neck',
      'abductors',
    });
  });

  testWidgets(
    'food confirmation dialog remains stable across repeated Add to today actions',
    (WidgetTester tester) async {
      final product = FoodProductResult(
        name: 'Apple',
        brand: 'Forge',
        barcode: '1234567890',
        nutrition: FoodProductNutrition(
          values: const FoodNutritionValues(
            caloriesKcal: 95,
            proteinGrams: 0.5,
            carbsGrams: 25,
            fatGrams: 0.2,
          ),
          basis: FoodNutritionBasis.serving,
          servingSize: '1 apple',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<double>(
                    context: context,
                    builder: (_) =>
                        FoodServingConfirmationDialog(product: product),
                  );
                  expect(result, 1.0);
                },
                child: const Text('Open dialog'),
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '1');
        await tester.tap(find.text('Add to today'));
        await tester.pumpAndSettle();
      }
    },
  );
}
