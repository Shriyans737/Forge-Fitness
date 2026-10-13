import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/motion.dart';
import '../controllers/exercise_library_controller.dart';
import '../models/active_workout_draft.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import '../models/workout_template.dart';
import '../services/progress_repository.dart';
import '../services/progress_service.dart';
import '../services/workout_performance_service.dart';
import '../services/workout_stats_service.dart';
import '../theme.dart';
import 'exercise_detail_screen.dart';
import 'workout_summary_screen.dart';
import '../widgets/exercise_video_section.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({
    this.initialExerciseIds = const [],
    this.initialWorkoutName,
    this.initialDurationMinutes = 0,
    this.sessionId,
    this.resumeDraft = false,
    super.key,
  });

  final List<String> initialExerciseIds;
  final String? initialWorkoutName;
  final int initialDurationMinutes;
  final String? sessionId;
  final bool resumeDraft;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  late DateTime _startTime;
  late String _sessionId;
  late String _workoutName;
  late final ValueNotifier<WorkoutStatsSnapshot> _liveStats;
  late final Future<Map<String, ExerciseProgressHistory>>
  _progressHistoriesFuture;
  final List<LoggedExercise> _loggedExercises = [];
  final List<List<bool>> _completedSets = [];
  final Map<ExerciseSet, _SetInputControllers> _setInputControllers = {};
  final Map<ExerciseSet, ({String weight, String reps})> _restoredSetInputs =
      {};
  final Map<ExerciseSet, String> _setTypes = {};
  final Map<ExerciseSet, bool> _personalRecordSets = {};
  final List<String> _exerciseNotes = [];
  int _expandedExerciseIndex = 0;
  bool _muscleMapExpanded = false;
  bool _showFrontMuscles = true;
  int _defaultRestSeconds = 90;
  int _restSecondsRemaining = 0;
  int _restTotalSeconds = 0;
  DateTime? _restEndsAt;
  Timer? _restTimer;
  Timer? _elapsedTimer;
  Timer? _draftDebounce;
  Future<void> _draftWrites = Future<void>.value();
  bool _draftCleared = false;
  bool _canPersistDraft = true;
  String _workoutNotes = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final activeWorkoutBox = Hive.box<dynamic>('activeWorkout');
    ActiveWorkoutDraft? restoredDraft;
    if (widget.resumeDraft) {
      final rawDraft = activeWorkoutBox.get('activeWorkout');
      if (rawDraft is Map) {
        try {
          restoredDraft = ActiveWorkoutDraft.fromMap(rawDraft);
        } catch (error, stackTrace) {
          _canPersistDraft = false;
          debugPrint('Failed to restore active workout: $error\n$stackTrace');
        }
      }
    }
    _startTime = restoredDraft?.startedAt ?? DateTime.now();
    _sessionId = restoredDraft?.id ?? widget.sessionId ?? const Uuid().v4();
    _workoutName =
        restoredDraft?.name ??
        widget.initialWorkoutName ??
        _defaultWorkoutName(_startTime);
    _workoutNotes = restoredDraft?.notes ?? '';
    final restored = restoredDraft;
    if (restored != null) {
      _loggedExercises.addAll(restored.exercises);
      _completedSets.addAll(restored.completedSets.map(List<bool>.of));
      _exerciseNotes.addAll(
        List<String>.generate(
          restored.exercises.length,
          (index) => index < restored.exerciseNotes.length
              ? restored.exerciseNotes[index]
              : '',
        ),
      );
      _restEndsAt = restored.restEndsAt;
      _restTotalSeconds = restored.restDurationSeconds;
      for (
        var exerciseIndex = 0;
        exerciseIndex < restored.exercises.length;
        exerciseIndex++
      ) {
        final exercise = restored.exercises[exerciseIndex];
        for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
          final types = exerciseIndex < restored.setTypes.length
              ? restored.setTypes[exerciseIndex]
              : const <String>[];
          _setTypes[exercise.sets[setIndex]] = setIndex < types.length
              ? types[setIndex]
              : 'working';
        }
      }
      if (_restEndsAt != null) {
        _restSecondsRemaining = WorkoutRestTimer(endsAt: _restEndsAt!)
            .remainingAt(DateTime.now());
        if (_restSecondsRemaining > 0) _startRestTimer(_restSecondsRemaining);
      }
      for (
        var exerciseIndex = 0;
        exerciseIndex < restored.exercises.length;
        exerciseIndex++
      ) {
        final exercise = restored.exercises[exerciseIndex];
        for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
          _restoredSetInputs[exercise.sets[setIndex]] = (
            weight: restored.weightInputs[exerciseIndex][setIndex],
            reps: restored.repsInputs[exerciseIndex][setIndex],
          );
        }
      }
    }
    unawaited(_setScreenAwake(true));
    _progressHistoriesFuture = ProgressRepository.loadAll();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        // Elapsed time is derived from the persisted start timestamp.
      });
    });
    final settingsBox = Hive.box<dynamic>('settings');
    _defaultRestSeconds =
        (settingsBox.get('defaultRestSeconds', defaultValue: 90) as num?)
            ?.toInt() ??
        90;
    settingsBox.listenable().addListener(_settingsChanged);

    if (restoredDraft == null && widget.initialExerciseIds.isNotEmpty) {
      final exercisesBox = Hive.box<Exercise>('exercises');
      final templateExercises = widget.initialExerciseIds
          .map((id) => exercisesBox.get(id))
          .whereType<Exercise>()
          .toList();

      for (final exercise in templateExercises) {
        _loggedExercises.add(
          LoggedExercise(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            sets: [],
          ),
        );
        _completedSets.add([]);
        _exerciseNotes.add('');
      }
    }
    if (restoredDraft == null && _canPersistDraft) {
      _queueDraftSave();
    }
    _liveStats = ValueNotifier(WorkoutStatsSnapshot.empty);
    _recomputeLiveStats();
  }

  void _recomputeLiveStats() {
    _liveStats.value = WorkoutStatsService.calculate(
      exercises: _loggedExercises,
      completedSets: _completedSets,
      exerciseForId: Hive.box<Exercise>('exercises').get,
    );
  }

  Future<void> _setScreenAwake(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } on PlatformException catch (error) {
      if (kDebugMode) debugPrint('Could not update workout wakelock: $error');
    } on MissingPluginException catch (error) {
      if (kDebugMode) debugPrint('Workout wakelock plugin unavailable: $error');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftDebounce?.cancel();
    if (!_draftCleared && _canPersistDraft) {
      unawaited(_flushDraft());
    }
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    for (final controllers in _setInputControllers.values) {
      controllers.dispose();
    }
    _liveStats.dispose();
    Hive.box<dynamic>('settings').listenable().removeListener(_settingsChanged);
    unawaited(_setScreenAwake(false));
    super.dispose();
  }

  static String _defaultWorkoutName(DateTime startedAt) =>
      'Workout ${startedAt.toLocal().day}/${startedAt.toLocal().month}';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _draftDebounce?.cancel();
      unawaited(_flushDraft());
    } else if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        final restEnd = _restEndsAt;
        if (restEnd == null) return;
        _restSecondsRemaining = WorkoutRestTimer(endsAt: restEnd)
            .remainingAt(DateTime.now());
        if (_restSecondsRemaining == 0) {
          _restTimer?.cancel();
          _restTimer = null;
          _restEndsAt = null;
        } else if (_restTimer == null) {
          _startRestTimer(_restSecondsRemaining);
        }
      });
    }
  }

  int get _elapsedSeconds =>
      DateTime.now().difference(_startTime).inSeconds.clamp(0, 1 << 31);

  ActiveWorkoutDraft _currentDraft() => ActiveWorkoutDraft(
    id: _sessionId,
    startedAt: _startTime,
    name: _workoutName,
    exercises: _loggedExercises
        .map(
          (exercise) => LoggedExercise(
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.exerciseName,
            sets: exercise.sets
                .map(
                  (set) => ExerciseSet(
                    weight: set.weight,
                    reps: set.reps,
                    isWarmUp: set.isWarmUp,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
    completedSets: _completedSets
        .map((sets) => List<bool>.of(sets))
        .toList(growable: false),
    weightInputs: _loggedExercises
        .map(
          (exercise) => exercise.sets
              .map((set) => _controllersFor(set).weight.text)
              .toList(growable: false),
        )
        .toList(growable: false),
    repsInputs: _loggedExercises
        .map(
          (exercise) => exercise.sets
              .map((set) => _controllersFor(set).reps.text)
              .toList(growable: false),
        )
        .toList(growable: false),
    initialDurationMinutes: widget.initialDurationMinutes,
    notes: _workoutNotes,
    exerciseNotes: List<String>.of(_exerciseNotes),
    setTypes: _loggedExercises
        .map(
          (exercise) => exercise.sets
              .map((set) => _setTypes[set] ?? 'working')
              .toList(growable: false),
        )
        .toList(growable: false),
    restEndsAt: _restEndsAt,
    restDurationSeconds: _restTotalSeconds,
  );

  void _queueDraftSave({bool debounce = false}) {
    if (_draftCleared || !_canPersistDraft) {
      return;
    }
    _draftDebounce?.cancel();
    if (debounce) {
      _draftDebounce = Timer(
        const Duration(milliseconds: 300),
        () => unawaited(_writeDraft()),
      );
    } else {
      unawaited(_writeDraft());
    }
  }

  Future<void> _writeDraft() {
    if (_draftCleared || !_canPersistDraft) {
      return _draftWrites;
    }
    final snapshot = _currentDraft().toMap();
    _draftWrites = _draftWrites.then((_) async {
      try {
        await Hive.box<dynamic>('activeWorkout').put('activeWorkout', snapshot);
      } catch (error, stackTrace) {
        debugPrint('Failed to autosave active workout: $error\n$stackTrace');
      }
    });
    return _draftWrites;
  }

  Future<void> _flushDraft() async {
    if (_draftCleared || !_canPersistDraft) {
      return;
    }
    _draftDebounce?.cancel();
    await _writeDraft();
    try {
      await Hive.box<dynamic>('activeWorkout').flush();
    } catch (error, stackTrace) {
      debugPrint('Failed to flush active workout draft: $error\n$stackTrace');
    }
  }

  Future<void> _clearDraft() async {
    _draftCleared = true;
    _draftDebounce?.cancel();
    await _draftWrites;
    try {
      final box = Hive.box<dynamic>('activeWorkout');
      await box.delete('activeWorkout');
      await box.flush();
    } catch (error, stackTrace) {
      debugPrint('Failed to clear active workout draft: $error\n$stackTrace');
      rethrow;
    }
  }

  void _settingsChanged() {
    final settingsBox = Hive.box<dynamic>('settings');
    final nextValue =
        (settingsBox.get('defaultRestSeconds', defaultValue: 90) as num?)
            ?.toInt() ??
        90;
    if (!mounted) {
      return;
    }
    setState(() {
      _defaultRestSeconds = nextValue;
      if (_restTimer != null &&
          _restSecondsRemaining > 0 &&
          _restSecondsRemaining < 15) {
        _restSecondsRemaining = _restSecondsRemaining.clamp(
          0,
          _defaultRestSeconds,
        );
      }
    });
  }

  bool _isSetComplete(int exerciseIndex, int setIndex) =>
      exerciseIndex < _completedSets.length &&
      setIndex < _completedSets[exerciseIndex].length &&
      _completedSets[exerciseIndex][setIndex];

  bool get _isRestActive => _restTimer != null && _restSecondsRemaining > 0;

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  List<String> get _targetMuscles {
    final muscles =
        _loggedExercises
            .map(
              (exercise) =>
                  Hive.box<Exercise>('exercises').get(exercise.exerciseId),
            )
            .whereType<Exercise>()
            .expand((exercise) => exercise.primaryMuscles)
            .map((muscle) => muscle.trim())
            .where((muscle) => muscle.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return muscles;
  }

  bool _markSetComplete(LoggedExercise exercise, int setIndex) {
    if (exercise.sets.isEmpty ||
        setIndex < 0 ||
        setIndex >= exercise.sets.length) {
      return false;
    }

    final set = exercise.sets[setIndex];
    if (set.weight <= 0 || set.reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter weight and reps before ending the rest timer.'),
        ),
      );
      return false;
    }

    final details = Hive.box<Exercise>('exercises').get(exercise.exerciseId);
    final isCompound =
        (details?.equipment ?? '').toLowerCase().contains('barbell') ||
        (details?.muscleGroup ?? '').toLowerCase() == 'legs' ||
        (details?.muscleGroup ?? '').toLowerCase() == 'back';
    final restSeconds =
        (Hive.box<dynamic>('settings').get(
          isCompound ? 'compoundRestSeconds' : 'isolationRestSeconds',
          defaultValue: isCompound ? 120 : 75,
        ) as num?)?.toInt() ??
        _defaultRestSeconds;
    _startRestTimer(restSeconds);
    return true;
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();

    final initialSeconds = seconds.clamp(0, 300);
    setState(() {
      _restSecondsRemaining = initialSeconds;
      _restTotalSeconds = initialSeconds;
      _restEndsAt = DateTime.now().add(Duration(seconds: initialSeconds));
      _restTimer = null;
    });

    final timer = Timer.periodic(const Duration(seconds: 1), (tick) {
      if (!mounted) {
        tick.cancel();
        _restTimer = null;
        return;
      }

      final nextValue = WorkoutRestTimer(endsAt: _restEndsAt ?? DateTime.now())
          .remainingAt(DateTime.now());
      if (nextValue <= 0) {
        tick.cancel();
        if (mounted) {
          unawaited(HapticFeedback.vibrate());
          Future<void>.delayed(const Duration(milliseconds: 140), () {
            if (mounted) unawaited(HapticFeedback.vibrate());
          });
          setState(() {
            _restTimer = null;
            _restSecondsRemaining = 0;
            _restEndsAt = null;
          });
          _queueDraftSave();
        }
        return;
      }

      setState(() {
        _restSecondsRemaining = nextValue;
      });
    });

    setState(() {
      _restTimer = timer;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _restTimer = null;
    setState(() {
      _restSecondsRemaining = 0;
      _restEndsAt = null;
    });
    _queueDraftSave();
  }

  void _adjustRest(int adjustment) {
    if (_restSecondsRemaining <= 0 && adjustment < 0) {
      return;
    }

    final adjusted = WorkoutRestTimer(endsAt: _restEndsAt ?? DateTime.now())
        .adjust(Duration(seconds: adjustment), DateTime.now());
    _restEndsAt = adjusted.endsAt;
    _restSecondsRemaining = adjusted.remainingAt(DateTime.now());
    if (_restSecondsRemaining == 0) {
      _skipRest();
    } else {
      setState(() {});
      _queueDraftSave();
    }
  }

  Future<void> _saveAsTemplate() async {
    final templateName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save as template'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Template name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (templateName == null || templateName.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    final exerciseIds = _loggedExercises
        .map((exercise) => exercise.exerciseId)
        .toSet()
        .toList();

    if (exerciseIds.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one exercise before saving a template.'),
        ),
      );
      return;
    }

    final template = WorkoutTemplate(
      id: const Uuid().v4(),
      name: templateName,
      exerciseIds: exerciseIds,
      plannedExercises: _loggedExercises
          .where((exercise) => exercise.sets.isNotEmpty)
          .map(
            (exercise) => PlannedExercise(
              exerciseId: exercise.exerciseId,
              sets: exercise.sets
                  .map((set) => PlannedSet(reps: set.reps))
                  .toList(),
            ),
          )
          .toList(),
    );

    Hive.box<WorkoutTemplate>('workoutTemplates').put(template.id, template);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template “${template.name}” saved.')),
      );
    }
  }

  Future<void> _confirmLeave() async {
    await _flushDraft();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmFinish() async {
    final total = _loggedExercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    final unchecked = (total - _liveStats.value.sets).clamp(0, total);
    final shouldFinish = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final tokens = Theme.of(sheetContext).extension<ForgeTokens>()!;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(ForgeSpacing.lg),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finish workout?',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: ForgeSpacing.xs),
                Text(
                  unchecked == 0
                      ? 'All sets are checked. Ready to save your session?'
                      : '$unchecked ${unchecked == 1 ? 'set is' : 'sets are'} still unchecked.',
                  style: Theme.of(sheetContext).textTheme.bodyLarge,
                ),
                const SizedBox(height: ForgeSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Keep training'),
                      ),
                    ),
                    const SizedBox(width: ForgeSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('Finish'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (shouldFinish == true) await _saveWorkout();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ForgeSpacing.md),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(ForgeSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discard workout?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: ForgeSpacing.xs),
                  const Text(
                    'This will remove the saved draft and cannot be undone.',
                  ),
                  const SizedBox(height: ForgeSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('Keep workout'),
                        ),
                      ),
                      const SizedBox(width: ForgeSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('Discard'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (discard != true || !mounted) return;
    if (await _discardDraftSession() && mounted) Navigator.of(context).pop();
  }

  Future<bool> _discardDraftSession() async {
    try {
      await _clearDraft();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to discard active workout: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to discard this workout. Please try again.'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _saveWorkout() async {
    final validExercises = _loggedExercises
        .where(
          (exercise) =>
              exercise.sets.any((set) => set.weight > 0 && set.reps > 0),
        )
        .map(
          (exercise) => LoggedExercise(
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.exerciseName,
            sets: exercise.sets
                .where((set) => set.weight > 0 && set.reps > 0)
                .toList(),
          ),
        )
        .toList();

    if (validExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one exercise with a completed set before saving.',
          ),
        ),
      );
      return;
    }

    final box = Hive.box<WorkoutSession>('workoutSessions');
    final session = WorkoutSession(
      id: _sessionId,
      date: _startTime,
      name: _workoutName,
      exercises: validExercises,
      durationMinutes: widget.initialDurationMinutes > 0
          ? widget.initialDurationMinutes
          : _elapsedSeconds ~/ 60,
    );

    try {
      await box.put(session.id, session);
    } catch (error, stackTrace) {
      debugPrint('Failed to finish active workout: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save this workout.')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    try {
      await _clearDraft();
    } catch (error, stackTrace) {
      debugPrint('Workout saved but draft cleanup failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout saved, but its recovery draft remains.'),
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WorkoutSummaryScreen(session: session)),
    );
  }

  Future<void> _addExerciseDialog() async {
    final exercisesBox = Hive.box<Exercise>('exercises');
    final exerciseEntries = exercisesBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (exerciseEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exercises are available yet.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ActiveExerciseSearchSheet(exercises: exerciseEntries),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _loggedExercises.add(
        LoggedExercise(
          exerciseId: selected.id,
          exerciseName: selected.name,
          sets: [],
        ),
      );
      _completedSets.add([]);
      _exerciseNotes.add('');
      _expandedExerciseIndex = _loggedExercises.length - 1;
    });
    _recomputeLiveStats();
    _queueDraftSave();
  }

  void _addSet(LoggedExercise exercise) {
    setState(() {
      final previous = exercise.sets.isEmpty ? null : exercise.sets.last;
      final set = ExerciseSet(
        weight: previous?.weight ?? 0,
        reps: previous?.reps ?? 0,
        isWarmUp: previous?.isWarmUp ?? false,
      );
      exercise.sets.add(set);
      _setTypes[set] = previous == null
          ? 'working'
          : _setTypes[previous] ?? 'working';
      final exerciseIndex = _loggedExercises.indexOf(exercise);
      if (exerciseIndex >= 0) {
        _completedSets[exerciseIndex].add(false);
      }
      _controllersFor(set);
    });
    _queueDraftSave();
  }

  void _removeExercise(int index) {
    setState(() {
      final exercise = _loggedExercises.removeAt(index);
      if (index < _exerciseNotes.length) _exerciseNotes.removeAt(index);
      if (index < _completedSets.length) {
        _completedSets.removeAt(index);
      }
      for (final set in exercise.sets) {
        _setInputControllers.remove(set)?.dispose();
        _setTypes.remove(set);
        _personalRecordSets.remove(set);
      }
      _expandedExerciseIndex = _loggedExercises.isEmpty
          ? 0
          : _expandedExerciseIndex.clamp(0, _loggedExercises.length - 1);
    });
    _recomputeLiveStats();
    _queueDraftSave();
  }

  _SetInputControllers _controllersFor(ExerciseSet set) =>
      _setInputControllers.putIfAbsent(set, () {
        final input = _restoredSetInputs.remove(set);
        return _SetInputControllers(
          set,
          weightText: input?.weight,
          repsText: input?.reps,
        );
      });

  void _fillSetFromHint(ExerciseSet set, ProgressionTarget target) {
    final controllers = _controllersFor(set);
    setState(() {
      if (controllers.weight.text.trim().isEmpty) {
        set.weight = target.weight;
        controllers.weight.text = _formatWeight(target.weight);
      }
      if (controllers.reps.text.trim().isEmpty) {
        set.reps = target.reps;
        controllers.reps.text = target.reps.toString();
      }
    });
    _recomputeLiveStats();
    _queueDraftSave();
  }

  static const List<String> _setTypeCycle = [
    'working',
    'warm-up',
    'drop',
    'failure',
  ];

  void _cycleSetType(ExerciseSet set) {
    final currentIndex = _setTypeCycle.indexOf(_setTypes[set] ?? 'working');
    final next = _setTypeCycle[(currentIndex + 1) % _setTypeCycle.length];
    setState(() {
      _setTypes[set] = next;
      set.isWarmUp = next == 'warm-up';
    });
    _recomputeLiveStats();
    _queueDraftSave();
  }

  void _removeSet(LoggedExercise exercise, int setIndex) {
    if (setIndex < 0 || setIndex >= exercise.sets.length) return;
    final exerciseIndex = _loggedExercises.indexOf(exercise);
    final set = exercise.sets[setIndex];
    setState(() {
      exercise.sets.removeAt(setIndex);
      if (exerciseIndex >= 0 &&
          setIndex < _completedSets[exerciseIndex].length) {
        _completedSets[exerciseIndex].removeAt(setIndex);
      }
      _setInputControllers.remove(set)?.dispose();
      _setTypes.remove(set);
      _personalRecordSets.remove(set);
    });
    _recomputeLiveStats();
    _queueDraftSave();
  }

  void _restoreRemovedSet(
    LoggedExercise exercise,
    int setIndex,
    ExerciseSet set,
    bool wasComplete,
    String type,
  ) {
    final exerciseIndex = _loggedExercises.indexOf(exercise);
    if (exerciseIndex < 0) return;
    setState(() {
      exercise.sets.insert(setIndex.clamp(0, exercise.sets.length), set);
      final completed = _completedSets[exerciseIndex];
      completed.insert(setIndex.clamp(0, completed.length), wasComplete);
      _setTypes[set] = type;
      _controllersFor(set);
    });
    _recomputeLiveStats();
    _queueDraftSave();
  }

  void _moveExercise(int index, int direction) {
    final nextIndex = index + direction;
    if (nextIndex < 0 || nextIndex >= _loggedExercises.length) return;
    setState(() {
      final exercise = _loggedExercises.removeAt(index);
      final completions = _completedSets.removeAt(index);
      final note = _exerciseNotes.removeAt(index);
      _loggedExercises.insert(nextIndex, exercise);
      _completedSets.insert(nextIndex, completions);
      _exerciseNotes.insert(nextIndex, note);
      _expandedExerciseIndex = nextIndex;
    });
    _queueDraftSave();
  }

  Future<void> _editExerciseNote(int index) async {
    final controller = TextEditingController(text: _exerciseNotes[index]);
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.md,
            ForgeSpacing.md,
            ForgeSpacing.md,
            MediaQuery.viewInsetsOf(sheetContext).bottom + ForgeSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Exercise note',
                  hintText: 'Technique, setup, or cues',
                ),
              ),
              const SizedBox(height: ForgeSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, controller.text),
                child: const Text('Save note'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;
    setState(() => _exerciseNotes[index] = note.trim());
    _queueDraftSave();
  }

  void _toggleSetDone(LoggedExercise exercise, int setIndex) {
    final exerciseIndex = _loggedExercises.indexOf(exercise);
    if (exerciseIndex < 0 || setIndex >= exercise.sets.length) {
      return;
    }
    if (_isSetComplete(exerciseIndex, setIndex)) {
      setState(() {
        _completedSets[exerciseIndex][setIndex] = false;
        _personalRecordSets.remove(exercise.sets[setIndex]);
      });
      _recomputeLiveStats();
      _queueDraftSave();
      return;
    }
    if (!_markSetComplete(exercise, setIndex)) {
      return;
    }
    while (_completedSets.length <= exerciseIndex) {
      _completedSets.add([]);
    }
    while (_completedSets[exerciseIndex].length < exercise.sets.length) {
      _completedSets[exerciseIndex].add(false);
    }
    setState(() {
      _completedSets[exerciseIndex][setIndex] = true;
    });
    unawaited(HapticFeedback.lightImpact());
    _updatePersonalRecord(exercise, exercise.sets[setIndex]);
    _recomputeLiveStats();
    _queueDraftSave();
  }

  void _updatePersonalRecord(LoggedExercise exercise, ExerciseSet set) {
    final settings = Hive.box<dynamic>('settings');
    final existing = settings.get('exercisePr1rm');
    final personalBests = <String, double>{
      if (existing is Map)
        for (final entry in existing.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: (entry.value as num).toDouble(),
    };
    final estimated = WorkoutPerformanceService.estimatedOneRepMax(
      set.weight,
      set.reps,
    );
    final oldBest = personalBests[exercise.exerciseId] ?? 0;
    final isRecord = estimated > oldBest;
    setState(() => _personalRecordSets[set] = isRecord);
    if (isRecord) {
      personalBests[exercise.exerciseId] = estimated;
      unawaited(settings.put('exercisePr1rm', personalBests));
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  Future<void> _swapExercise(int index) async {
    final exercises = Hive.box<Exercise>('exercises').values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ActiveExerciseSearchSheet(exercises: exercises),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _loggedExercises[index].exerciseId = selected.id;
      _loggedExercises[index].exerciseName = selected.name;
    });
    _recomputeLiveStats();
    _queueDraftSave();
  }

  String _previousSetLabel(String exerciseId) {
    final sessions =
        Hive.box<WorkoutSession>('workoutSessions').values
            .where((session) => session.date.isBefore(_startTime))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        if (exercise.exerciseId == exerciseId && exercise.sets.isNotEmpty) {
          final best = exercise.sets.reduce(
            (a, b) => a.weight * a.reps >= b.weight * b.reps ? a : b,
          );
          return '${_formatWeight(best.weight)} x ${best.reps}';
        }
      }
    }
    return '—';
  }

  static void _selectAll(TextEditingController controller) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  static String _setTypeName(String type) => switch (type) {
    'warm-up' => 'Warm-up',
    'drop' => 'Drop',
    'failure' => 'Failure',
    _ => 'Work',
  };

  static Color _setTypeColor(String type, ForgeTokens tokens) => switch (type) {
    'warm-up' => tokens.warning,
    'drop' => const Color(0xFFB897FF),
    'failure' => tokens.error,
    _ => tokens.accentTeal,
  };

  void _openExerciseDetail(LoggedExercise loggedExercise) {
    final exercise = Hive.box<Exercise>('exercises')
        .get(loggedExercise.exerciseId);
    if (exercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exercise details are no longer available.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).extension<ForgeTokens>()!.background,
        appBar: AppBar(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _workoutName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            tooltip: 'Minimize workout',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: _confirmLeave,
          ),
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .extension<ForgeTokens>()!
                    .surfaceVariant,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'save_template') {
                  _saveAsTemplate();
                } else if (value == 'discard') {
                  _confirmDiscard();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'save_template',
                  child: Text('Save as template'),
                ),
                const PopupMenuItem(
                  value: 'discard',
                  child: Text('Discard workout'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: tokens.primaryGradient,
                  borderRadius: BorderRadius.circular(tokens.pillRadius),
                ),
                child: TextButton(
                  onPressed: _confirmFinish,
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.background,
                    minimumSize: const Size(76, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Finish',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context)
                    .extension<ForgeTokens>()!
                    .accentTeal
                    .withValues(alpha: 0.08),
                Theme.of(context).extension<ForgeTokens>()!.background,
                Theme.of(context)
                    .extension<ForgeTokens>()!
                    .accentLime
                    .withValues(alpha: 0.035),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _loggedExercises.isEmpty
                              ? 'Ready to train'
                              : _loggedExercises[_expandedExerciseIndex
                                        .clamp(0, _loggedExercises.length - 1)
                                        .toInt()]
                                    .exerciseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: tokens.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _addExerciseDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add exercise'),
                      ),
                    ],
                  ),
                ),
                _WorkoutSummaryBar(
                  elapsedTime: _formatTime(_elapsedSeconds),
                  stats: _liveStats.value,
                  totalSets: _loggedExercises.fold<int>(
                    0,
                    (sum, exercise) => sum + exercise.sets.length,
                  ),
                ),
                _MuscleLoadCard(
                  expanded: _muscleMapExpanded,
                  showFront: _showFrontMuscles,
                  muscles: _targetMuscles,
                  loads: _liveStats.value.muscleLoad,
                  onToggle: () =>
                      setState(() => _muscleMapExpanded = !_muscleMapExpanded),
                  onSideChanged: (showFront) =>
                      setState(() => _showFrontMuscles = showFront),
                ),
                Expanded(
                  child: _loggedExercises.isEmpty
                      ? const Center(
                          child: Text(
                            'No exercises added yet. Pick one to begin logging.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _loggedExercises.length,
                          itemBuilder: (context, exerciseIndex) {
                            final exercise = _loggedExercises[exerciseIndex];
                            final expanded =
                                exerciseIndex == _expandedExerciseIndex;
                            final completedCount =
                                exerciseIndex < _completedSets.length
                                ? _completedSets[exerciseIndex]
                                      .where((done) => done)
                                      .length
                                : 0;
                            if (!expanded) {
                              return Card(
                                color: tokens.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    tokens.cardRadius,
                                  ),
                                  side: BorderSide(color: tokens.border),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  minVerticalPadding: 14,
                                  title: Text(
                                    exercise.exerciseName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$completedCount/${exercise.sets.length} sets',
                                    style: TextStyle(
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                  trailing: _MiniProgressRing(
                                    value: exercise.sets.isEmpty
                                        ? 0
                                        : completedCount / exercise.sets.length,
                                    color: tokens.accentTeal,
                                  ),
                                  onTap: () => setState(
                                    () =>
                                        _expandedExerciseIndex = exerciseIndex,
                                  ),
                                ),
                              );
                            }

                            return Card(
                              color: tokens.surfaceVariant.withValues(
                                alpha: 0.72,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  tokens.cardRadius,
                                ),
                                side: BorderSide(color: tokens.border),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            onTap: () => setState(
                                              () => _expandedExerciseIndex = -1,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    exercise.exerciseName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Last time  ${_previousSetLabel(exercise.exerciseId)}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: tokens
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Exercise options',
                                          onSelected: (value) {
                                            switch (value) {
                                              case 'note':
                                                _editExerciseNote(
                                                  exerciseIndex,
                                                );
                                                break;
                                              case 'swap':
                                                _swapExercise(exerciseIndex);
                                                break;
                                              case 'skip':
                                                setState(
                                                  () => _expandedExerciseIndex =
                                                      (exerciseIndex + 1) %
                                                      _loggedExercises.length,
                                                );
                                                break;
                                              case 'up':
                                                _moveExercise(
                                                  exerciseIndex,
                                                  -1,
                                                );
                                                break;
                                              case 'down':
                                                _moveExercise(exerciseIndex, 1);
                                                break;
                                              case 'history':
                                                _openExerciseDetail(exercise);
                                                break;
                                              case 'remove':
                                                _removeExercise(exerciseIndex);
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'note',
                                              child: Text('Add note'),
                                            ),
                                            PopupMenuItem(
                                              value: 'swap',
                                              child: Text('Swap exercise'),
                                            ),
                                            PopupMenuItem(
                                              value: 'skip',
                                              child: Text('Skip'),
                                            ),
                                            PopupMenuItem(
                                              value: 'up',
                                              child: Text('Move up'),
                                            ),
                                            PopupMenuItem(
                                              value: 'down',
                                              child: Text('Move down'),
                                            ),
                                            PopupMenuItem(
                                              value: 'history',
                                              child: Text('View history'),
                                            ),
                                            PopupMenuItem(
                                              value: 'remove',
                                              child: Text('Remove exercise'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (Hive.box<Exercise>('exercises')
                                            .get(exercise.exerciseId)
                                        case final details?)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: ExerciseVideoSection(
                                            exerciseId: details.id,
                                            exerciseName: details.name,
                                          ),
                                        ),
                                      ),
                                    if (_exerciseNotes.elementAtOrNull(
                                          exerciseIndex,
                                        )
                                        case final note? when note.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          note,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: tokens.textSecondary,
                                              ),
                                        ),
                                      ),
                                    ...exercise.sets.asMap().entries.map((
                                      entry,
                                    ) {
                                      final setIndex = entry.key;
                                      final set = entry.value;
                                      final controllers = _controllersFor(set);
                                      final workingSetIndex =
                                          exercise.sets
                                              .take(setIndex + 1)
                                              .where((item) => !item.isWarmUp)
                                              .length -
                                          1;

                                      return Dismissible(
                                        key: ObjectKey(set),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(
                                            right: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.error,
                                            borderRadius: BorderRadius.circular(
                                              tokens.pillRadius,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                          ),
                                        ),
                                        onDismissed: (_) {
                                          final wasDone = _isSetComplete(
                                            exerciseIndex,
                                            setIndex,
                                          );
                                          final type =
                                              _setTypes[set] ?? 'working';
                                          _removeSet(exercise, setIndex);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'Set removed.',
                                                  ),
                                                  action: SnackBarAction(
                                                    label: 'UNDO',
                                                    onPressed: () =>
                                                        _restoreRemovedSet(
                                                          exercise,
                                                          setIndex,
                                                          set,
                                                          wasDone,
                                                          type,
                                                        ),
                                                  ),
                                                ),
                                              );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 72,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      onTap: () =>
                                                          _cycleSetType(set),
                                                      child: Container(
                                                        constraints:
                                                            const BoxConstraints(
                                                              minHeight: 44,
                                                            ),
                                                        alignment:
                                                            Alignment.center,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: _setTypeColor(
                                                            _setTypes[set] ??
                                                                (set.isWarmUp
                                                                    ? 'warm-up'
                                                                    : 'working'),
                                                            tokens,
                                                          ).withValues(alpha: 0.16),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          '${setIndex + 1} ${_setTypeName(_setTypes[set] ?? (set.isWarmUp ? 'warm-up' : 'working'))}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                color: _setTypeColor(
                                                                  _setTypes[set] ??
                                                                      (set.isWarmUp
                                                                          ? 'warm-up'
                                                                          : 'working'),
                                                                  tokens,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (_personalRecordSets[set] ==
                                                      true)
                                                    const _PrBadge(),
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          controllers.weight,
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Weight (kg)',
                                                            isDense: true,
                                                          ),
                                                      onTap: () => _selectAll(
                                                        controllers.weight,
                                                      ),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          set.weight =
                                                              double.tryParse(
                                                                value,
                                                              ) ??
                                                              0;
                                                        });
                                                        _queueDraftSave(
                                                          debounce: true,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          controllers.reps,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Reps',
                                                            isDense: true,
                                                          ),
                                                      onTap: () => _selectAll(
                                                        controllers.reps,
                                                      ),
                                                      onChanged: (value) {
                                                        setState(() {
                                                          set.reps =
                                                              int.tryParse(
                                                                value,
                                                              ) ??
                                                              0;
                                                        });
                                                        _queueDraftSave(
                                                          debounce: true,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              FutureBuilder<
                                                Map<
                                                  String,
                                                  ExerciseProgressHistory
                                                >
                                              >(
                                                future:
                                                    _progressHistoriesFuture,
                                                builder: (context, snapshot) {
                                                  if (!snapshot.hasData ||
                                                      set.isWarmUp ||
                                                      workingSetIndex < 0) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  final history =
                                                      snapshot.data![exercise
                                                          .exerciseId];
                                                  final exerciseDetails =
                                                      Hive.box<Exercise>(
                                                        'exercises',
                                                      ).get(
                                                        exercise.exerciseId,
                                                      );
                                                  if (history == null) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  final suggestion =
                                                      ProgressionRules.suggest(
                                                        history: history,
                                                        targetRepMin:
                                                            exerciseDetails
                                                                ?.targetRepMin ??
                                                            8,
                                                        targetRepMax:
                                                            exerciseDetails
                                                                ?.targetRepMax ??
                                                            12,
                                                      );
                                                  if (suggestion == null ||
                                                      workingSetIndex >=
                                                          suggestion
                                                              .targets
                                                              .length) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  final target = suggestion
                                                      .targets[workingSetIndex];
                                                  final load =
                                                      target.weight <= 0
                                                      ? 'bodyweight'
                                                      : '${_formatWeight(target.weight)} kg';
                                                  return Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      onTap: () =>
                                                          _fillSetFromHint(
                                                            set,
                                                            target,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 4,
                                                              vertical: 6,
                                                            ),
                                                        child: Text(
                                                          'Try $load x ${target.reps}',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.onSurfaceVariant,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Done',
                                                    constraints:
                                                        const BoxConstraints.tightFor(
                                                          width: 44,
                                                          height: 44,
                                                        ),
                                                    onPressed: () =>
                                                        _toggleSetDone(
                                                          exercise,
                                                          setIndex,
                                                        ),
                                                    icon: Icon(
                                                      _isSetComplete(
                                                            exerciseIndex,
                                                            setIndex,
                                                          )
                                                          ? Icons.check_rounded
                                                          : Icons.check,
                                                      color:
                                                          _isSetComplete(
                                                            exerciseIndex,
                                                            setIndex,
                                                          )
                                                          ? tokens.background
                                                          : tokens
                                                                .textSecondary,
                                                    ),
                                                    style: IconButton.styleFrom(
                                                      backgroundColor:
                                                          _isSetComplete(
                                                            exerciseIndex,
                                                            setIndex,
                                                          )
                                                          ? tokens.accentTeal
                                                          : tokens
                                                                .surfaceVariant,
                                                      shape:
                                                          const CircleBorder(),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Remove set',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () => _removeSet(
                                                      exercise,
                                                      setIndex,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.close,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => _addSet(exercise),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        label: const Text('Add set'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_isRestActive)
                  _LiquidRestPill(
                    remainingSeconds: _restSecondsRemaining,
                    totalSeconds: _restTotalSeconds,
                    reduceMotion: reduceMotion,
                    onMinus: () => _adjustRest(-15),
                    onPlus: () => _adjustRest(15),
                    onSkip: _skipRest,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetInputControllers {
  _SetInputControllers(ExerciseSet set, {String? weightText, String? repsText})
    : weight = TextEditingController(
        text: weightText ?? (set.weight > 0 ? _formatWeight(set.weight) : ''),
      ),
      reps = TextEditingController(
        text: repsText ?? (set.reps > 0 ? set.reps.toString() : ''),
      );

  final TextEditingController weight;
  final TextEditingController reps;

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

String _formatWeight(double weight) =>
    weight.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String _formatWorkoutTime(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
      : '$minutes:$seconds';
}

class _WorkoutSummaryBar extends StatelessWidget {
  const _WorkoutSummaryBar({
    required this.elapsedTime,
    required this.stats,
    required this.totalSets,
  });

  final String elapsedTime;
  final WorkoutStatsSnapshot stats;
  final int totalSets;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            _WorkoutStat(
              label: 'VOLUME',
              value: stats.volume.round().toString(),
              suffix: 'kg',
            ),
            _WorkoutStat(label: 'REPS', value: stats.reps.toString()),
            _WorkoutStat(label: 'SETS', value: '${stats.sets}/$totalSets'),
            _WorkoutStat(label: 'Elapsed', value: elapsedTime),
          ],
        ),
      ),
    );
  }
}

class _WorkoutStat extends StatelessWidget {
  const _WorkoutStat({
    required this.label,
    required this.value,
    this.suffix = '',
  });

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final numericValue = double.tryParse(value);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: tokens.textMuted, letterSpacing: 0.7),
            ),
            const SizedBox(height: 3),
            if (numericValue == null || value.contains('/'))
              Text(
                '$value$suffix',
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            else
              TweenAnimationBuilder<double>(
                tween: Tween(end: numericValue),
                duration: const Duration(milliseconds: 350),
                curve: ForgeMotion.easeOut,
                builder: (context, current, _) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${current.toStringAsFixed(0)}$suffix',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MuscleLoadCard extends StatelessWidget {
  const _MuscleLoadCard({
    required this.expanded,
    required this.showFront,
    required this.muscles,
    required this.loads,
    required this.onToggle,
    required this.onSideChanged,
  });

  final bool expanded;
  final bool showFront;
  final List<String> muscles;
  final Map<String, double> loads;
  final VoidCallback onToggle;
  final ValueChanged<bool> onSideChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final peak = loads.values.fold<double>(
      0,
      (largest, value) => math.max(largest, value).toDouble(),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.accessibility_new_rounded,
                      color: tokens.accentTeal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target muscles'),
                          Text(
                            muscles.isEmpty
                                ? 'Add exercises to see today’s focus'
                                : muscles.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: ForgeMotion.easeOut,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.accessibility_new_rounded,
                                size: 42,
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text('Front'),
                                selected: showFront,
                                onSelected: (_) => onSideChanged(true),
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('Back'),
                                selected: !showFront,
                                onSelected: (_) => onSideChanged(false),
                              ),
                            ],
                          ),
                          if (muscles.isEmpty)
                            Text(
                              'No muscle load yet',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            ...muscles.map((muscle) {
                              final value = loads[muscle] ?? 0;
                              final factor = peak <= 0
                                  ? 0.0
                                  : (value / peak).clamp(0, 1).toDouble();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 88,
                                      child: Text(
                                        muscle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: factor,
                                          minHeight: 6,
                                          backgroundColor:
                                              tokens.surfaceVariant,
                                          valueColor: AlwaysStoppedAnimation(
                                            tokens.accentTeal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniProgressRing extends StatelessWidget {
  const _MiniProgressRing({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: CircularProgressIndicator(
      value: value.clamp(0, 1),
      strokeWidth: 3,
      backgroundColor: color.withValues(alpha: 0.16),
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}

class _PrBadge extends StatelessWidget {
  const _PrBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFC857).withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
    ),
    child: const Text(
      'PR',
      style: TextStyle(
        color: Color(0xFFFFC857),
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _LiquidRestPill extends StatelessWidget {
  const _LiquidRestPill({
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.reduceMotion,
    required this.onMinus,
    required this.onPlus,
    required this.onSkip,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final bool reduceMotion;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.border),
              boxShadow: [
                BoxShadow(
                  color: tokens.accentTeal.withValues(alpha: 0.14),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 500),
                      curve: ForgeMotion.easeOut,
                      widthFactor:
                          (remainingSeconds /
                                  (totalSeconds <= 0 ? 1 : totalSeconds))
                              .clamp(0, 1)
                              .toDouble(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: tokens.primaryGradient,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.timer_rounded, color: tokens.background),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'REST  ${_formatWorkoutTime(remainingSeconds)}',
                        maxLines: 1,
                        style: TextStyle(
                          color: tokens.background,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    _RestButton(label: '-15', onPressed: onMinus),
                    _RestButton(label: '+15', onPressed: onPlus),
                    _RestButton(label: 'Skip', onPressed: onSkip),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestButton extends StatelessWidget {
  const _RestButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      foregroundColor: Theme.of(context).extension<ForgeTokens>()!.background,
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
    child: Text(label),
  );
}

class _ActiveExerciseSearchSheet extends StatefulWidget {
  const _ActiveExerciseSearchSheet({required this.exercises});

  final List<Exercise> exercises;

  @override
  State<_ActiveExerciseSearchSheet> createState() =>
      _ActiveExerciseSearchSheetState();
}

class _ActiveExerciseSearchSheetState
    extends State<_ActiveExerciseSearchSheet> {
  late final ExerciseLibraryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ExerciseLibraryController(exercises: widget.exercises);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final exercises = _controller.filteredExercises;
        final muscleGroups = _controller.availableMuscleGroups;

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add exercise',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: true,
                    onChanged: _controller.setSearch,
                    decoration: const InputDecoration(
                      hintText: 'Search exercises',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: muscleGroups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final muscle = muscleGroups[index];
                      return FilterChip(
                        label: Text(muscle),
                        selected: _controller.selectedMuscleGroups.contains(
                          muscle,
                        ),
                        onSelected: (_) =>
                            _controller.toggleMuscleGroup(muscle),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: exercises.isEmpty
                      ? const Center(child: Text('No exercises match'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = exercises[index];
                            return ListTile(
                              title: Text(exercise.name),
                              subtitle: Text(exercise.muscleGroup),
                              trailing: const Icon(Icons.add),
                              onTap: () => Navigator.of(context).pop(exercise),
                              onLongPress: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ExerciseDetailScreen(
                                      exercise: exercise,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
