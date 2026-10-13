import 'package:hive_flutter/hive_flutter.dart';

class CoachHabitEntry {
  const CoachHabitEntry({
    required this.completed,
    required this.streak,
    this.waterMillilitres = 0,
  });

  final bool completed;
  final int streak;
  final int waterMillilitres;
}

class CoachRepository {
  CoachRepository()
    : _shown = Hive.box<dynamic>('coachShownInsights'),
      _dismissed = Hive.box<dynamic>('coachDismissedInsights'),
      _habits = Hive.box<dynamic>('coachHabitLogs'),
      _reviews = Hive.box<dynamic>('coachWeeklyReviews');

  final Box<dynamic> _shown;
  final Box<dynamic> _dismissed;
  final Box<dynamic> _habits;
  final Box<dynamic> _reviews;
  final Box<dynamic> _settings = Hive.box<dynamic>('settings');

  int? bedtimeMinutes() {
    final value = _settings.get('coachBedtimeMinutes');
    return value is num && value >= 0 && value < 1440 ? value.toInt() : null;
  }

  Future<void> saveBedtime(int minutes) =>
      _settings.put('coachBedtimeMinutes', minutes.clamp(0, 1439));

  Map<String, DateTime> shownTimestamps() {
    final timestamps = <String, DateTime>{};
    for (final key in _shown.keys) {
      final date = _date(_shown.get(key));
      if (date != null) timestamps[key.toString()] = date;
    }
    return timestamps;
  }

  bool wasDismissed(String id, DateTime now) {
    final at = _date(_dismissed.get(id));
    return at != null && now.difference(at) < const Duration(days: 7);
  }

  Future<void> markShown(String id, DateTime now) =>
      _shown.put(id, now.toIso8601String());

  Future<void> dismiss(String id, DateTime now) =>
      _dismissed.put(id, now.toIso8601String());

  CoachHabitEntry habit(String name, DateTime now) {
    final key = _habitKey(name, now);
    final raw = _habits.get(key);
    final map = raw is Map ? raw : const <dynamic, dynamic>{};
    return CoachHabitEntry(
      completed: map['completed'] == true,
      streak: map['streak'] is int ? map['streak'] as int : 0,
      waterMillilitres: map['waterMillilitres'] is int
          ? map['waterMillilitres'] as int
          : 0,
    );
  }

  Future<void> setHabit(String name, DateTime now, {int? waterDelta}) async {
    final key = _habitKey(name, now);
    final current = habit(name, now);
    final waterMillilitres = name == 'water'
        ? current.waterMillilitres + (waterDelta ?? 250)
        : current.waterMillilitres;
    final completed = name == 'water' ? waterMillilitres >= 2000 : true;
    final yesterday = _habitKey(name, now.subtract(const Duration(days: 1)));
    final yesterdayValue = _habits.get(yesterday);
    final previousStreak =
        yesterdayValue is Map && yesterdayValue['completed'] == true
        ? (yesterdayValue['streak'] is int
              ? yesterdayValue['streak'] as int
              : 0)
        : 0;
    final streak = current.completed
        ? current.streak
        : completed
        ? previousStreak + 1
        : previousStreak;
    await _habits.put(key, {
      'completed': completed,
      'streak': streak,
      'waterMillilitres': waterMillilitres,
    });
  }

  Future<void> saveWeeklyReview(String weekKey, Map<String, Object?> review) =>
      _reviews.put(weekKey, review);

  Map<String, Object?>? weeklyReview(String weekKey) {
    final value = _reviews.get(weekKey);
    return value is Map ? Map<String, Object?>.from(value) : null;
  }

  List<MapEntry<String, Map<String, Object?>>> weeklyReviews() {
    final entries = <MapEntry<String, Map<String, Object?>>>[];
    for (final key in _reviews.keys) {
      final review = weeklyReview(key.toString());
      if (review != null) entries.add(MapEntry(key.toString(), review));
    }
    entries.sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  static String _habitKey(String name, DateTime date) =>
      '$name:${date.year}-${date.month}-${date.day}';

  static DateTime? _date(Object? value) => switch (value) {
    DateTime date => date,
    String date => DateTime.tryParse(date),
    int date => DateTime.fromMillisecondsSinceEpoch(date),
    _ => null,
  };
}
