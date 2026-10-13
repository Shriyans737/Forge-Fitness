import 'workout_session.dart';

class ActiveWorkoutDraft {
  const ActiveWorkoutDraft({
    required this.id,
    required this.startedAt,
    required this.name,
    required this.exercises,
    required this.completedSets,
    this.weightInputs = const [],
    this.repsInputs = const [],
    this.initialDurationMinutes = 0,
    this.notes = '',
    this.exerciseNotes = const [],
    this.setTypes = const [],
    this.restEndsAt,
    this.restDurationSeconds = 0,
  });

  final String id;
  final DateTime startedAt;
  final String name;
  final List<LoggedExercise> exercises;
  final List<List<bool>> completedSets;
  final List<List<String>> weightInputs;
  final List<List<String>> repsInputs;
  final int initialDurationMinutes;
  final String notes;
  final List<String> exerciseNotes;
  final List<List<String>> setTypes;
  final DateTime? restEndsAt;
  final int restDurationSeconds;

  int get completedSetCount =>
      completedSets.fold(0, (count, sets) => count + sets.where((done) => done).length);

  Map<String, Object?> toMap() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'name': name,
        'initialDurationMinutes': initialDurationMinutes,
        'notes': notes,
        'exerciseNotes': exerciseNotes,
        'setTypes': setTypes,
        'restEndsAt': restEndsAt?.millisecondsSinceEpoch,
        'restDurationSeconds': restDurationSeconds,
        'exercises': exercises.asMap().entries.map((entry) {
          final exerciseIndex = entry.key;
          return {
                  'exerciseId': entry.value.exerciseId,
                  'exerciseName': entry.value.exerciseName,
                  'sets': entry.value.sets.asMap().entries.map((setEntry) {
                    final setIndex = setEntry.key;
                    final set = setEntry.value;
                    return {
                            'weight': set.weight,
                            'reps': set.reps,
                            'isWarmUp': set.isWarmUp,
                            'weightInput': _inputAt(
                              weightInputs,
                              exerciseIndex,
                              setIndex,
                              set.weight > 0 ? set.weight.toString() : '',
                            ),
                            'repsInput': _inputAt(
                              repsInputs,
                              exerciseIndex,
                              setIndex,
                              set.reps > 0 ? set.reps.toString() : '',
                            ),
                          };
                  }).toList(growable: false),
                  'completed': exerciseIndex < completedSets.length
                      ? List<bool>.of(completedSets[exerciseIndex])
                      : List<bool>.filled(entry.value.sets.length, false),
                };
        }).toList(growable: false),
      };

  static String _inputAt(
    List<List<String>> values,
    int exerciseIndex,
    int setIndex,
    String fallback,
  ) {
    if (exerciseIndex >= values.length ||
        setIndex >= values[exerciseIndex].length) {
      return fallback;
    }
    return values[exerciseIndex][setIndex];
  }

  factory ActiveWorkoutDraft.fromMap(Map<dynamic, dynamic> value) {
    final id = value['id'];
    final startedAtMillis = value['startedAt'];
    final name = value['name'];
    final rawExercises = value['exercises'];
    if (id is! String ||
        startedAtMillis is! num ||
        name is! String ||
        rawExercises is! List) {
      throw const FormatException('Active workout draft is malformed.');
    }

    final exercises = <LoggedExercise>[];
    final completedSets = <List<bool>>[];
    final weightInputs = <List<String>>[];
    final repsInputs = <List<String>>[];
    for (final rawExercise in rawExercises) {
      if (rawExercise is! Map) {
        throw const FormatException('Active workout exercise is malformed.');
      }
      final exerciseId = rawExercise['exerciseId'];
      final exerciseName = rawExercise['exerciseName'];
      final rawSets = rawExercise['sets'];
      if (exerciseId is! String ||
          exerciseName is! String ||
          rawSets is! List) {
        throw const FormatException('Active workout exercise is malformed.');
      }

      final sets = <ExerciseSet>[];
      final exerciseWeightInputs = <String>[];
      final exerciseRepsInputs = <String>[];
      for (final rawSet in rawSets) {
        if (rawSet is! Map ||
            rawSet['weight'] is! num ||
            rawSet['reps'] is! num) {
          throw const FormatException('Active workout set is malformed.');
        }
        sets.add(
          ExerciseSet(
            weight: (rawSet['weight'] as num).toDouble(),
            reps: (rawSet['reps'] as num).toInt(),
            isWarmUp: rawSet['isWarmUp'] == true,
          ),
        );
        exerciseWeightInputs.add(
          rawSet['weightInput'] is String
              ? rawSet['weightInput'] as String
              : (rawSet['weight'] as num).toDouble() > 0
                  ? (rawSet['weight'] as num).toDouble().toString()
                  : '',
        );
        exerciseRepsInputs.add(
          rawSet['repsInput'] is String
              ? rawSet['repsInput'] as String
              : (rawSet['reps'] as num).toInt() > 0
                  ? (rawSet['reps'] as num).toInt().toString()
                  : '',
        );
      }

      final rawCompleted = rawExercise['completed'];
      final completed = rawCompleted is List
          ? List<bool>.generate(
              sets.length,
              (index) => index < rawCompleted.length &&
                  rawCompleted[index] == true,
              growable: false,
            )
          : List<bool>.filled(sets.length, false);
      exercises.add(
        LoggedExercise(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          sets: sets,
        ),
      );
      completedSets.add(completed);
      weightInputs.add(exerciseWeightInputs);
      repsInputs.add(exerciseRepsInputs);
    }

    final initialDuration = value['initialDurationMinutes'];
    final notes = value['notes'];
    final rawExerciseNotes = value['exerciseNotes'];
    final exerciseNotes = rawExerciseNotes is List
        ? rawExerciseNotes.map((item) => item is String ? item : '').toList()
        : <String>[];
    final rawSetTypes = value['setTypes'];
    final setTypes = rawSetTypes is List
        ? rawSetTypes
              .map(
                (row) => row is List
                    ? row.map((item) => item is String ? item : 'working').toList()
                    : <String>[],
              )
              .toList()
        : <List<String>>[];
    final restEndsAt = value['restEndsAt'];
    final restDurationSeconds = value['restDurationSeconds'];
    return ActiveWorkoutDraft(
      id: id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        startedAtMillis.toInt(),
      ),
      name: name,
      exercises: exercises,
      completedSets: completedSets,
      weightInputs: weightInputs,
      repsInputs: repsInputs,
      initialDurationMinutes:
          initialDuration is num ? initialDuration.toInt() : 0,
      notes: notes is String ? notes : '',
      exerciseNotes: exerciseNotes,
      setTypes: setTypes,
      restEndsAt: restEndsAt is num
          ? DateTime.fromMillisecondsSinceEpoch(restEndsAt.toInt())
          : null,
      restDurationSeconds: restDurationSeconds is num
          ? restDurationSeconds.toInt()
          : 0,
    );
  }
}
