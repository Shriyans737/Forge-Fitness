import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/body_log_model.dart';
import '../models/exercise.dart';
import '../models/food_log_model.dart';
import '../models/workout_session.dart';
import 'auth_service.dart';
import 'health_service.dart';

class ShareSyncService with WidgetsBindingObserver {
  ShareSyncService._();

  static final ShareSyncService instance = ShareSyncService._();
  static const categories = ['workouts', 'food', 'health', 'body'];
  static const _minimumSyncInterval = Duration(minutes: 5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();
  final HealthService _health = HealthService();
  final List<Listenable> _observedBoxes = [];
  bool _initialized = false;
  bool _syncInProgress = false;
  DateTime? _lastAttempt;

  static String localSettingKey(String category) => 'sharing_$category';

  static String firestoreFlag(String category) =>
      category == 'body' ? 'body' : category;

  bool isEnabled(String category) =>
      Hive.box<dynamic>('settings').get(localSettingKey(category)) == true;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _lastAttempt = _asDateTime(
      Hive.box<dynamic>('settings').get('sharingLastAttemptAt'),
    );
    _observe(Hive.box<WorkoutSession>('workoutSessions').listenable());
    _observe(Hive.box<FoodLog>('foodLogs').listenable());
    _observe(Hive.box<BodyLog>('bodyLogs').listenable());
    _observe(
      Hive.box<dynamic>('settings')
          .listenable(keys: const ['healthLastSyncedAt']),
    );
    await sync();
  }

  void _observe(Listenable listenable) {
    listenable.addListener(_onLocalDataChanged);
    _observedBoxes.add(listenable);
  }

  void _onLocalDataChanged() {
    unawaited(sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  Future<void> setCategory(String category, bool enabled) async {
    _requireCategory(category);
    await Hive.box<dynamic>('settings').put(localSettingKey(category), enabled);
    unawaited(_applyCategoryChange(category, enabled));
  }

  Future<void> _applyCategoryChange(String category, bool enabled) async {
    await _writeSharingSettings();
    if (enabled) {
      unawaited(sync(manual: true));
    } else {
      await deleteCategoryData(category);
    }
  }

  Future<void> _writeSharingSettings() async {
    try {
      final uid = await _auth.signInAnonymouslyIfNeeded();
      _queueFirebaseOperation(
        'Sharing settings upload failed',
        _firestore.collection('sharing').doc(uid).set({
          for (final category in categories)
            firestoreFlag(category): isEnabled(category),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    } catch (error, stackTrace) {
      debugPrint('Sharing settings upload failed: $error\n$stackTrace');
    }
  }

  Future<bool> sync({bool manual = false}) async {
    if (_syncInProgress) return false;
    final now = DateTime.now();
    if (!manual &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < _minimumSyncInterval) {
      return false;
    }
    _lastAttempt = now;
    await Hive.box<dynamic>('settings').put('sharingLastAttemptAt', now);
    _syncInProgress = true;
    try {
      final enabledCategories = categories
          .where(isEnabled)
          .toList(growable: false);
      if (enabledCategories.isEmpty) return true;

      final uid = await _auth.signInAnonymouslyIfNeeded();
      await _writeSharingSettings();
      final cutoff = _dateKey(
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6)),
      );
      for (final category in categories) {
        unawaited(_deleteOlderThan(uid, category, cutoff));
      }

      final healthByDay = enabledCategories.contains('health')
          ? await _health.fetchRecentDailyShareData(7)
          : const <DateTime, HealthDailyShareData>{};
      final days = List.generate(
        7,
        (index) => DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: 6 - index)),
      );
      for (final day in days) {
        for (final category in enabledCategories) {
          final data = await _buildDayDocument(category, day, healthByDay);
          final dayKey = _dateKey(day);
          final dayDocument = _firestore
              .collection('userData')
              .doc(uid)
              .collection(category)
              .doc(dayKey);
          if (data == null) {
            if (category != 'health' &&
                _trackedDays(category).contains(dayKey)) {
              _queueFirebaseOperation(
                'Shared $category day deletion failed',
                dayDocument.delete(),
              );
              await _forgetDay(category, dayKey);
            }
            continue;
          }
          _queueFirebaseOperation(
            'Shared $category upload failed for $dayKey',
            dayDocument.set({
              ...data,
              'updatedAt': FieldValue.serverTimestamp(),
            }),
          );
          await _rememberDay(category, dayKey);
        }
      }
      await Hive.box<dynamic>('settings')
          .put('sharingLastSyncedAt', DateTime.now());
      return true;
    } catch (error, stackTrace) {
      debugPrint('Friends data sync failed: $error\n$stackTrace');
      return false;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<Map<String, Object?>?> _buildDayDocument(
    String category,
    DateTime day,
    Map<DateTime, HealthDailyShareData> healthByDay,
  ) async {
    final dayKey = _dateKey(day);
    switch (category) {
      case 'workouts':
        final sessions = Hive.box<WorkoutSession>('workoutSessions').values
            .where((session) => _dateKey(session.date) == dayKey)
            .toList();
        if (sessions.isEmpty) return null;
        final exerciseBox = Hive.box<Exercise>('exercises');
        final workoutData = sessions
            .map((session) {
              final musclesTargeted = <String>{};
              final exercises = session.exercises
                  .map((exercise) {
                    final libraryEntry = exerciseBox.get(exercise.exerciseId);
                    final muscles = <String>[];
                    if (libraryEntry != null) {
                      if (libraryEntry.muscleGroup.isNotEmpty) {
                        muscles.add(libraryEntry.muscleGroup);
                      }
                      muscles
                        ..addAll(libraryEntry.primaryMuscles)
                        ..addAll(libraryEntry.secondaryMuscles);
                    }
                    musclesTargeted.addAll(muscles);
                    return <String, Object?>{
                      'name': exercise.exerciseName,
                      'muscles': muscles.toSet().toList(),
                      'sets': exercise.sets
                          .map(
                            (set) => {'reps': set.reps, 'weight': set.weight},
                          )
                          .toList(growable: false),
                    };
                  })
                  .toList(growable: false);
              final allSets = session.exercises.expand((item) => item.sets);
              return <String, Object?>{
                'name': session.name,
                'sport': 'strength',
                'durationMinutes': session.durationMinutes,
                'totalVolume': session.totalVolume,
                'totalReps': allSets.fold<int>(
                  0,
                  (total, set) => total + set.reps,
                ),
                'musclesTargeted': musclesTargeted.toList(),
                'exercises': exercises,
              };
            })
            .toList(growable: false);
        final volume = sessions.fold<double>(
          0,
          (total, session) => total + session.totalVolume,
        );
        final reps = sessions.fold<int>(
          0,
          (total, session) =>
              total +
              session.exercises
                  .expand((exercise) => exercise.sets)
                  .fold<int>(0, (totalReps, set) => totalReps + set.reps),
        );
        return {
          'workouts': workoutData,
          'dailyTotals': {
            'workoutCount': sessions.length,
            'durationMinutes': sessions.fold<int>(
              0,
              (total, session) => total + session.durationMinutes,
            ),
            'totalVolume': volume,
            'totalReps': reps,
          },
        };
      case 'food':
        final foods = Hive.box<FoodLog>('foodLogs').values
            .where((food) => _dateKey(food.loggedAt) == dayKey)
            .toList();
        if (foods.isEmpty) return null;
        double total(double? Function(FoodLog) value) => foods.fold<double>(
          0,
          (totalValue, food) => totalValue + (value(food) ?? 0) * food.quantity,
        );
        final settings = Hive.box<dynamic>('settings');
        return {
          'calories': total((food) => food.caloriesPerServing),
          'protein': total((food) => food.proteinGramsPerServing),
          'carbs': total((food) => food.carbsGramsPerServing),
          'fat': total((food) => food.fatGramsPerServing),
          'goals': {
            if (_numberSetting(settings.get('nutritionGoalCalories')) != null)
              'calories': _numberSetting(settings.get('nutritionGoalCalories')),
            if (_numberSetting(settings.get('nutritionGoalProtein')) != null)
              'protein': _numberSetting(settings.get('nutritionGoalProtein')),
            if (_numberSetting(settings.get('nutritionGoalCarbs')) != null)
              'carbs': _numberSetting(settings.get('nutritionGoalCarbs')),
            if (_numberSetting(settings.get('nutritionGoalFat')) != null)
              'fat': _numberSetting(settings.get('nutritionGoalFat')),
          },
          'foods': foods
              .map(
                (food) => {
                  'name': food.foodName,
                  'calories': (food.caloriesPerServing ?? 0) * food.quantity,
                  'meal': 'Unspecified',
                },
              )
              .toList(growable: false),
        };
      case 'health':
        final data = healthByDay[DateTime(day.year, day.month, day.day)];
        return data == null || !data.hasData ? null : data.toFirestoreMap();
      case 'body':
        final logs = Hive.box<BodyLog>('bodyLogs').values
            .where((entry) => _dateKey(entry.date) == dayKey)
            .toList();
        if (logs.isEmpty) return null;
        final weight = logs
            .where((entry) => entry.weightKg != null)
            .map((entry) => entry.weightKg)
            .lastOrNull;
        final measurements = <String, double>{};
        for (final log in logs) {
          measurements.addAll(log.measurements ?? const {});
        }
        return {
          ...?(weight == null ? null : {'weightKg': weight}),
          ...?(measurements.isEmpty ? null : {'measurements': measurements}),
        };
    }
    return null;
  }

  Future<void> deleteCategoryData(String category) async {
    _requireCategory(category);
    try {
      final uid = await _auth.signInAnonymouslyIfNeeded();
      await _deleteAllForCategory(uid, category);
    } catch (error, stackTrace) {
      debugPrint('Shared $category data deletion failed: $error\n$stackTrace');
    }
  }

  Future<void> stopSharingAndDelete() async {
    for (final category in categories) {
      await Hive.box<dynamic>('settings').put(localSettingKey(category), false);
    }
    unawaited(_stopSharingRemotely());
  }

  Future<void> _stopSharingRemotely() async {
    await _writeSharingSettings();
    try {
      final uid = await _auth.signInAnonymouslyIfNeeded();
      for (final category in categories) {
        await _deleteAllForCategory(uid, category);
      }
    } catch (error, stackTrace) {
      debugPrint('Delete all shared data failed: $error\n$stackTrace');
    }
  }

  Future<void> _deleteOlderThan(
    String uid,
    String category,
    String cutoffDay,
  ) async {
    final collection = _firestore
        .collection('userData')
        .doc(uid)
        .collection(category);
    final tracked = _trackedDays(category);
    final staleDays = tracked.where((day) => day.compareTo(cutoffDay) < 0);
    _queueDeleteReferences(
      staleDays.map((day) => collection.doc(day)),
    );
    await Hive.box<dynamic>('settings').put(
      _trackedDaysKey(category),
      tracked.where((day) => day.compareTo(cutoffDay) >= 0).toList(),
    );
    unawaited(_deleteExpiredFromServer(collection, category, cutoffDay));
  }

  Future<void> _deleteExpiredFromServer(
    CollectionReference<Map<String, dynamic>> collection,
    String category,
    String cutoffDay,
  ) async {
    try {
      final oldDocs = await collection
          .where(FieldPath.documentId, isLessThan: cutoffDay)
          .get();
      _queueDeleteReferences(
        oldDocs.docs.map((document) => document.reference),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Could not check for expired shared $category data: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _deleteAllForCategory(String uid, String category) async {
    final collection = _firestore
        .collection('userData')
        .doc(uid)
        .collection(category);
    final now = DateTime.now();
    final knownDays = <String>{
      ..._trackedDays(category),
      for (var offset = 0; offset < 7; offset++)
        _dateKey(
          DateTime(now.year, now.month, now.day).subtract(
            Duration(days: offset),
          ),
        ),
    };
    _queueDeleteReferences(knownDays.map(collection.doc));
    await Hive.box<dynamic>('settings').put(_trackedDaysKey(category), []);
    unawaited(_deleteAllFromServer(collection, category));
  }

  Future<void> _deleteAllFromServer(
    CollectionReference<Map<String, dynamic>> collection,
    String category,
  ) async {
    try {
      final docs = await collection.get();
      _queueDeleteReferences(
        docs.docs.map((document) => document.reference),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Could not check for additional shared $category data: '
        '$error\n$stackTrace',
      );
    }
  }

  void _queueDeleteReferences(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) {
    final documents = references.toList(growable: false);
    for (var offset = 0; offset < documents.length; offset += 450) {
      final batch = _firestore.batch();
      for (final reference in documents.skip(offset).take(450)) {
        batch.delete(reference);
      }
      _queueFirebaseOperation(
        'Shared data batch deletion failed',
        batch.commit(),
      );
    }
  }

  void _queueFirebaseOperation(String action, Future<void> operation) {
    unawaited(
      operation.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('$action: $error\n$stackTrace');
        },
      ),
    );
  }

  List<String> _trackedDays(String category) {
    final value = Hive.box<dynamic>('settings').get(_trackedDaysKey(category));
    return value is List ? value.whereType<String>().toList() : [];
  }

  Future<void> _rememberDay(String category, String day) async {
    final days = _trackedDays(category);
    if (!days.contains(day)) {
      days.add(day);
      await Hive.box<dynamic>('settings').put(_trackedDaysKey(category), days);
    }
  }

  Future<void> _forgetDay(String category, String day) async {
    final days = _trackedDays(category)..remove(day);
    await Hive.box<dynamic>('settings').put(_trackedDaysKey(category), days);
  }

  String _trackedDaysKey(String category) => 'sharingUploadedDays_$category';

  void _requireCategory(String category) {
    if (!categories.contains(category)) {
      throw ArgumentError.value(category, 'category', 'Unknown share category');
    }
  }

  static double? _numberSetting(Object? value) =>
      value is num ? value.toDouble() : null;

  static DateTime? _asDateTime(Object? value) => switch (value) {
    DateTime dateTime => dateTime,
    Timestamp timestamp => timestamp.toDate(),
    _ => null,
  };

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
