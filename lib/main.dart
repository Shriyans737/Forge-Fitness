import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'core/motion.dart';
import 'core/perf_diagnostics.dart';
import 'data/exercise_seed_data.dart';
import 'firebase_options.dart';
import 'services/ads_service.dart';
import 'services/auth_service.dart';
import 'services/challenge_score_service.dart';
import 'models/body_log_model.dart';
import 'models/exercise.dart';
import 'models/food_log_model.dart';
import 'models/workout_session.dart';
import 'models/workout_template.dart';
import 'screens/home_shell.dart';
import 'screens/floating_chat_overlay.dart';
import 'screens/name_onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'services/health_service.dart';
import 'services/share_sync_service.dart';
import 'theme.dart';

const _currentSchemaVersion = 1;
const _appBackgroundColor = Color(0xFF070C0B);
late String _hiveDirectoryPath;

class StartupResult {
  const StartupResult({
    this.recoveredBoxes = const [],
    this.error,
    this.stackTrace,
  });

  final List<String> recoveredBoxes;
  final Object? error;
  final StackTrace? stackTrace;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AuthService.isFirebaseInitialized = true;
  } catch (error, stackTrace) {
    AuthService.isFirebaseInitialized = false;
    debugPrint(
      'Firebase initialization failed; Friends will be offline: $error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }
  PerfDiagnostics.start();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PerfDiagnostics.log('first Flutter frame rendered');
  });
  final startupFuture = Future<StartupResult>.delayed(
    const Duration(seconds: 1),
    _initializeLocalStorage,
  );
  runApp(ForgeApp(startupFuture: startupFuture));
  startupFuture.then((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AdsService.initialize());
    });
  });
}

Future<StartupResult> _initializeLocalStorage() async {
  final startupClock = Stopwatch()..start();
  PerfDiagnostics.log('preload started: local storage initialization');
  if (kDebugMode) {
    debugPrint(
      '[Startup ${DateTime.now().toIso8601String()}] '
      'local storage initialization started',
    );
  }
  final recoveredBoxes = <String>[];
  try {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    _hiveDirectoryPath = documentsDirectory.path;
    PerfDiagnostics.log('Hive init started', splashWindowOnly: true);
    await Hive.initFlutter();
    PerfDiagnostics.log('Hive init finished', splashWindowOnly: true);

    // Register every adapter before opening any typed box.
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
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(PlannedSetAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(PlannedExerciseAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(FoodLogAdapter());
    }

    await _openBoxSafely<Exercise>('exercises', recoveredBoxes);
    await _openBoxSafely<WorkoutSession>('workoutSessions', recoveredBoxes);
    await _openBoxSafely<dynamic>('activeWorkout', recoveredBoxes);
    final templatesBox = await _openBoxSafely<WorkoutTemplate>(
      'workoutTemplates',
      recoveredBoxes,
    );
    await _openBoxSafely<BodyLog>('bodyLogs', recoveredBoxes);
    await _openBoxSafely<FoodLog>('foodLogs', recoveredBoxes);
    final settingsBox = await _openBoxSafely<dynamic>(
      'settings',
      recoveredBoxes,
    );
    await _openBoxSafely<dynamic>('coachShownInsights', recoveredBoxes);
    await _openBoxSafely<dynamic>('coachDismissedInsights', recoveredBoxes);
    await _openBoxSafely<dynamic>('coachHabitLogs', recoveredBoxes);
    await _openBoxSafely<dynamic>('coachWeeklyReviews', recoveredBoxes);
    final coachStorageVersion = settingsBox.get(
      'coachStorageVersion',
      defaultValue: 0,
    );
    if (coachStorageVersion is! int || coachStorageVersion < 1) {
      await settingsBox.put('coachStorageVersion', 1);
    }
    if (!settingsBox.containsKey('defaultRestSeconds')) {
      await settingsBox.put('defaultRestSeconds', 90);
    }
    if (!settingsBox.containsKey('themeMode')) {
      await settingsBox.put('themeMode', 'system');
    }
    await _runSchemaMigrations(settingsBox, templatesBox);
    final exercisesBox = Hive.box<Exercise>('exercises');
    if (exercisesBox.isEmpty) {
      final exercises = await loadPresetExercises();
      PerfDiagnostics.log(
        'seed insertion started: ${exercises.length} exercises',
        splashWindowOnly: true,
      );
      for (var start = 0; start < exercises.length; start += 32) {
        final end = (start + 32).clamp(0, exercises.length);
        await exercisesBox.putAll({
          for (final exercise in exercises.sublist(start, end))
            exercise.id: exercise,
        });
        await Future<void>.delayed(Duration.zero);
      }
      PerfDiagnostics.log('seed insertion finished', splashWindowOnly: true);
    } else {
      PerfDiagnostics.log(
        'seed insertion skipped: ${exercisesBox.length} exercises already present',
        splashWindowOnly: true,
      );
    }
    try {
      PerfDiagnostics.log('Health service initialization started');
      await HealthService.initialize();
      PerfDiagnostics.log('Health service initialization finished');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Apple Health initialization failed: $error\n$stackTrace');
      }
    }
    unawaited(ShareSyncService.instance.initialize());
    unawaited(ChallengeScoreService.instance.initialize());
  } catch (error, stackTrace) {
    debugPrint(
      '[Startup ${DateTime.now().toIso8601String()}] '
      'local storage initialization failed at '
      '+${startupClock.elapsedMilliseconds}ms: $error\n$stackTrace',
    );
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Forge startup',
      ),
    );
    return StartupResult(
      recoveredBoxes: List.unmodifiable(recoveredBoxes),
      error: error,
      stackTrace: stackTrace,
    );
  }

  if (kDebugMode) {
    debugPrint(
      '[Startup ${DateTime.now().toIso8601String()}] '
      'local storage initialization completed at '
      '+${startupClock.elapsedMilliseconds}ms',
    );
  }
  return StartupResult(recoveredBoxes: List.unmodifiable(recoveredBoxes));
}

Future<Box<T>> _openBoxSafely<T>(
  String name,
  List<String> recoveredBoxes,
) async {
  final openClock = Stopwatch()..start();
  if (kDebugMode) {
    debugPrint(
      '[Startup ${DateTime.now().toIso8601String()}] opening Hive box "$name"',
    );
  }
  try {
    final box = await Hive.openBox<T>(name);
    await _validateBoxReadable<T>(box);
    if (kDebugMode) {
      debugPrint(
        '[Startup ${DateTime.now().toIso8601String()}] Hive box "$name" '
        'ready after ${openClock.elapsedMilliseconds}ms',
      );
    }
    return box;
  } catch (error, stackTrace) {
    debugPrint('Failed to open/read Hive box "$name": $error\n$stackTrace');

    if (Hive.isBoxOpen(name)) {
      try {
        await Hive.box<T>(name).close();
      } catch (closeError, closeStackTrace) {
        debugPrint(
          'Failed to close Hive box "$name" after read error: '
          '$closeError\n$closeStackTrace',
        );
      }
    }

    final backedUpFiles = await _backupHiveBoxFiles(name);
    await Hive.deleteBoxFromDisk(name, path: _hiveDirectoryPath);
    final replacement = await Hive.openBox<T>(name);
    await _validateBoxReadable<T>(replacement);
    recoveredBoxes.add(name);
    debugPrint(
      'Recreated failed Hive box "$name"; backup: '
      '${backedUpFiles.join(', ')}',
    );
    return replacement;
  }
}

Future<void> _validateBoxReadable<T>(Box<T> box) async {
  var count = 0;
  for (final _ in box.values) {
    if (++count % 16 == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

Future<List<String>> _backupHiveBoxFiles(String name) async {
  final backedUpFiles = <String>[];
  for (final extension in ['.hive', '.hivec']) {
    final source = File(
      '$_hiveDirectoryPath${Platform.pathSeparator}$name$extension',
    );
    if (!await source.exists()) {
      continue;
    }
    var backup = File('${source.path}.bak');
    if (await backup.exists()) {
      backup = File(
        '${source.path}.bak.${DateTime.now().microsecondsSinceEpoch}',
      );
    }
    await source.copy(backup.path);
    backedUpFiles.add(backup.path);
  }
  return backedUpFiles;
}

Future<void> _runSchemaMigrations(
  Box<dynamic> settingsBox,
  Box<WorkoutTemplate> templatesBox,
) async {
  final storedVersion = settingsBox.get('schemaVersion', defaultValue: 0);
  final schemaVersion = storedVersion is num ? storedVersion.toInt() : 0;
  if (schemaVersion >= _currentSchemaVersion) {
    return;
  }

  if (schemaVersion < 1) {
    var migrated = 0;
    for (final template in templatesBox.values) {
      if (template.exerciseIds.isEmpty ||
          template.plannedExercises.isNotEmpty) {
        if (++migrated % 16 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        continue;
      }
      await templatesBox.put(
        template.id,
        WorkoutTemplate(
          id: template.id,
          name: template.name,
          exerciseIds: List<String>.of(template.exerciseIds),
          plannedExercises: template.exerciseIds
              .map(
                (exerciseId) => PlannedExercise(
                  exerciseId: exerciseId,
                  sets: List<PlannedSet>.generate(
                    3,
                    (_) => PlannedSet(reps: 10),
                    growable: false,
                  ),
                  targetRepsMin: 10,
                  targetRepsMax: 10,
                ),
              )
              .toList(growable: false),
          notes: template.notes,
        ),
      );
      if (++migrated % 16 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  await settingsBox.put('schemaVersion', _currentSchemaVersion);
}

class ForgeApp extends StatefulWidget {
  const ForgeApp({
    this.recoveredBoxes = const [],
    this.startupFuture,
    super.key,
  });

  final List<String> recoveredBoxes;
  final Future<StartupResult>? startupFuture;

  @override
  State<ForgeApp> createState() => _ForgeAppState();
}

class _ForgeAppState extends State<ForgeApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ForgeRouteObserver _routeObserver = ForgeRouteObserver();
  late final Future<StartupResult> _startupFuture =
      widget.startupFuture ??
      Future<StartupResult>.value(
        StartupResult(recoveredBoxes: widget.recoveredBoxes),
      );
  late final Future<void> _preloadFuture = _startupFuture.then((_) {});
  Box<dynamic>? _settingsBox;
  StartupResult? _startupResult;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    if (widget.startupFuture == null) {
      _applyStartupResult(StartupResult(recoveredBoxes: widget.recoveredBoxes));
    } else {
      _startupFuture.then((result) {
        if (!mounted) return;
        PerfDiagnostics.log(
          'ForgeApp setState: startup data loaded',
          splashWindowOnly: true,
        );
        setState(() => _applyStartupResult(result));
      });
    }
  }

  @override
  void dispose() {
    _settingsBox?.listenable().removeListener(_onThemeSettingChanged);
    _routeObserver.currentRoute.dispose();
    super.dispose();
  }

  void _applyStartupResult(StartupResult result) {
    _startupResult = result;
    if (result.error != null) return;
    final settingsBox = Hive.box<dynamic>('settings');
    _settingsBox = settingsBox;
    _themeMode = ForgeTheme.themeModeFromStorageValue(
      settingsBox.get('themeMode', defaultValue: 'system'),
    );
    settingsBox.listenable().addListener(_onThemeSettingChanged);
  }

  void _onThemeSettingChanged() {
    final settingsBox = _settingsBox;
    if (settingsBox == null) return;
    final nextMode = ForgeTheme.themeModeFromStorageValue(
      settingsBox.get('themeMode', defaultValue: 'system'),
    );
    if (mounted && nextMode != _themeMode) {
      setState(() {
        _themeMode = nextMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child ?? const SizedBox.shrink(),
          FloatingChatOverlay(
            navigatorKey: _navigatorKey,
            routeObserver: _routeObserver,
          ),
        ],
      ),
      title: 'Forge',
      color: _appBackgroundColor,
      theme: ForgeTheme.lightTheme,
      darkTheme: ForgeTheme.darkTheme,
      themeMode: _themeMode,
      themeAnimationDuration: disableAnimations
          ? Duration.zero
          : ForgeMotion.cardEntry,
      themeAnimationCurve: ForgeMotion.easeInOut,
      home: SplashScreen(
        preloadFuture: _preloadFuture,
        homeBuilder: (context) {
          final startup = _startupResult;
          if (startup?.error != null) {
            return _StartupFailureScreen(
              error: startup!.error!,
              stackTrace: startup.stackTrace,
            );
          }
          final settingsBox = _settingsBox;
          if (settingsBox == null) return const SizedBox.shrink();
          return _StartupRecoveryNotice(
            recoveredBoxes: startup?.recoveredBoxes ?? widget.recoveredBoxes,
            child: _NameGate(
              settingsBox: settingsBox,
              child: const HomeShell(),
            ),
          );
        },
      ),
    );
  }
}

class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({required this.error, this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Forge could not initialize local storage.'),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                SelectableText('$error\n${stackTrace ?? ''}'),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _NameGate extends StatelessWidget {
  const _NameGate({required this.settingsBox, required this.child});

  final Box<dynamic> settingsBox;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Box<dynamic>>(
    valueListenable: settingsBox.listenable(keys: const ['displayName']),
    builder: (context, settings, _) {
      final savedName = settings.get('displayName');
      if (savedName is String && savedName.trim().isNotEmpty) {
        return child;
      }
      return NameOnboardingScreen(
        onContinue: (name) {
          settings.put('displayName', name);
        },
      );
    },
  );
}

class _StartupRecoveryNotice extends StatefulWidget {
  const _StartupRecoveryNotice({
    required this.recoveredBoxes,
    required this.child,
  });

  final List<String> recoveredBoxes;
  final Widget child;

  @override
  State<_StartupRecoveryNotice> createState() => _StartupRecoveryNoticeState();
}

class _StartupRecoveryNoticeState extends State<_StartupRecoveryNotice> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown || widget.recoveredBoxes.isEmpty) {
      return;
    }
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A local data box was repaired (${widget.recoveredBoxes.join(', ')}). '
            'Any existing box data was backed up in app storage.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
